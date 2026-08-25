/* org.freedesktop.portal.Screenshot.PickColor. CORE.md section 6.1.
 *
 * The call is asynchronous in an unusual way: PickColor returns an object path
 * immediately and the answer arrives later as a Response signal on that path.
 * The path is constructed rather than returned, which is what lets us subscribe
 * before making the call. Subscribing afterwards races the portal and loses the
 * answer on a fast backend.
 *
 * Written straight against GIO's D-Bus client. CORE.md section 3 rules out
 * libportal for this: two calls is not enough work to justify a dependency.
 */

namespace Aventurine {

    public class PortalSource : Object, ColourSource {

        public const string BUS_NAME    = "org.freedesktop.portal.Desktop";
        public const string OBJECT_PATH = "/org/freedesktop/portal/desktop";
        public const string SCREENSHOT  = "org.freedesktop.portal.Screenshot";
        public const string REQUEST     = "org.freedesktop.portal.Request";

        /* Probing must stay cheap: it runs on the startup path. */
        private const int PROBE_TIMEOUT_MS = 1000;

        /* The portal call itself returns at once; this only guards against a
         * bus that never answers at all. */
        private const int CALL_TIMEOUT_MS = 10000;

        /* How long to wait for the user to click. Treated as a cancellation,
         * not an error: a stuck request must not wedge the button forever. */
        private const uint PICK_TIMEOUT_SECONDS = 300;

        public string id { get { return "portal"; } }
        public string label { get { return "Desktop portal (PickColor)"; } }

        private static uint token_counter = 0;

        /* State for one in-flight pick. */
        private SourceFunc? resume = null;
        private Rgb? result = null;
        private Error? failure = null;
        private bool finished = false;

        /* --- probing ---------------------------------------------------- */

        public bool probe () {
            return screenshot_version () > 0;
        }

        public bool owner_present () {
            try {
                var bus = Bus.get_sync (BusType.SESSION, null);
                var reply = bus.call_sync ("org.freedesktop.DBus",
                                           "/org/freedesktop/DBus",
                                           "org.freedesktop.DBus",
                                           "NameHasOwner",
                                           new Variant ("(s)", BUS_NAME),
                                           new VariantType ("(b)"),
                                           DBusCallFlags.NONE,
                                           PROBE_TIMEOUT_MS,
                                           null);
                return reply.get_child_value (0).get_boolean ();
            } catch (Error e) {
                return false;
            }
        }

        /* Zero means the interface is not there, which is also how a missing
         * session bus and a missing portal both present. */
        public uint32 screenshot_version () {
            try {
                var bus = Bus.get_sync (BusType.SESSION, null);
                var reply = bus.call_sync (BUS_NAME,
                                           OBJECT_PATH,
                                           "org.freedesktop.DBus.Properties",
                                           "Get",
                                           new Variant ("(ss)", SCREENSHOT, "version"),
                                           new VariantType ("(v)"),
                                           DBusCallFlags.NONE,
                                           PROBE_TIMEOUT_MS,
                                           null);
                return reply.get_child_value (0).get_variant ().get_uint32 ();
            } catch (Error e) {
                return 0;
            }
        }

        /* --- picking ---------------------------------------------------- */

        public async Rgb? pick () throws Error {
            if (resume != null) {
                throw new IOError.BUSY ("a pick is already in flight");
            }

            var bus = yield Bus.get (BusType.SESSION, null);

            /* SENDER is the unique name with the leading colon dropped and
             * every dot turned into an underscore. TOKEN is ours to choose. */
            string sender = bus.unique_name.substring (1).replace (".", "_");
            string token = "aventurine_%u".printf (++token_counter);
            string request_path = "/org/freedesktop/portal/desktop/request/%s/%s"
                                  .printf (sender, token);

            result = null;
            failure = null;
            finished = false;
            resume = pick.callback;

            /* Subscribe first. This is the whole reason the path is built by
             * hand instead of taken from the reply. */
            uint sub = bus.signal_subscribe (BUS_NAME, REQUEST, "Response",
                                             request_path, null,
                                             DBusSignalFlags.NONE, on_response);
            uint fallback_sub = 0;
            uint timeout_id = 0;

            try {
                var options = new VariantBuilder (new VariantType ("a{sv}"));
                options.add ("{sv}", "handle_token", new Variant.string (token));
                Variant[] arguments = { new Variant.string (""), options.end () };

                var reply = yield bus.call (BUS_NAME, OBJECT_PATH, SCREENSHOT,
                                            "PickColor",
                                            new Variant.tuple (arguments),
                                            new VariantType ("(o)"),
                                            DBusCallFlags.NONE,
                                            CALL_TIMEOUT_MS,
                                            null);

                /* A portal old enough to ignore handle_token hands back a path
                 * of its own choosing. Cover that too rather than hanging. */
                string handle = reply.get_child_value (0).get_string ();
                if (handle != request_path) {
                    fallback_sub = bus.signal_subscribe (BUS_NAME, REQUEST, "Response",
                                                         handle, null,
                                                         DBusSignalFlags.NONE, on_response);
                }

                timeout_id = Timeout.add_seconds (PICK_TIMEOUT_SECONDS, () => {
                    complete (null, null);
                    return Source.REMOVE;
                });

                /* Parked until on_response or the timeout resumes us. */
                yield;
            } finally {
                if (timeout_id != 0) {
                    Source.remove (timeout_id);
                }
                bus.signal_unsubscribe (sub);
                if (fallback_sub != 0) {
                    bus.signal_unsubscribe (fallback_sub);
                }
                resume = null;
            }

            if (failure != null) {
                throw failure;
            }
            return result;
        }

        private void on_response (DBusConnection connection,
                                  string? sender_name,
                                  string object_path,
                                  string interface_name,
                                  string signal_name,
                                  Variant parameters) {
            uint32 code = parameters.get_child_value (0).get_uint32 ();

            /* 1 is the user cancelling, which is a null answer, not a failure. */
            if (code == 1) {
                complete (null, null);
                return;
            }
            if (code != 0) {
                complete (null, new IOError.FAILED (
                    "the portal reported failure (response code %u)".printf (code)));
                return;
            }

            Variant results = parameters.get_child_value (1);
            Variant? colour = results.lookup_value ("color", new VariantType ("(ddd)"));
            if (colour == null) {
                complete (null, new IOError.INVALID_DATA (
                    "the portal returned success with no colour"));
                return;
            }

            Rgb picked = {
                colour.get_child_value (0).get_double (),
                colour.get_child_value (1).get_double (),
                colour.get_child_value (2).get_double ()
            };
            complete (picked, null);
        }

        /* Resumes the parked pick() exactly once. Resumption is deferred to an
         * idle callback so the signal subscription is torn down outside the
         * signal handler that is tearing it down. */
        private void complete (Rgb? value, Error? error) {
            if (finished) {
                return;
            }
            finished = true;
            result = value;
            failure = error;

            if (resume != null) {
                SourceFunc waiting = (owned) resume;
                resume = null;
                Idle.add ((owned) waiting);
            }
        }
    }
}
