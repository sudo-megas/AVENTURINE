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
 *
 * Two ordering hazards shape the code below, both of them real:
 *
 *   1. A resume handle taken from `pick.callback` re-enters the coroutine at
 *      whichever suspension point it is parked on *at the time it is called*,
 *      not the one it was taken at. Taking it before the PickColor call and
 *      then having Response arrive while that call is still in flight resumes
 *      the wrong await, with a GAsyncResult that has already been finished.
 *      That is a segfault, and a portal answering before its own method reply
 *      is legal. So the handle is taken only after the reply is in hand, and
 *      an answer that arrived first is picked up without parking at all.
 *
 *   2. Subscribing to one object path means a portal that ignores handle_token
 *      and answers somewhere else is never heard. So the subscription carries
 *      no path filter and the handler does the matching, which also removes
 *      the window where a late second subscription would miss the signal.
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

        /* How long to wait for the user to click before giving up on a request
         * the portal has stopped talking about. Reported as an error, not as a
         * cancellation, so the ladder re-probes instead of leaving the user
         * with a button that quietly does nothing. */
        private const uint PICK_TIMEOUT_SECONDS = 300;

        public string id { get { return "portal"; } }
        public string label { get { return "Desktop portal (PickColor)"; } }

        private static uint token_counter = 0;

        /* State for one in-flight pick. `busy` is set synchronously on entry,
         * before any yield, so it actually excludes a second caller. */
        private bool busy = false;
        private SourceFunc? resume = null;
        private Rgb? result = null;
        private Error? failure = null;
        private bool finished = false;

        private string request_prefix = "";
        private string request_path = "";
        private string? handle_path = null;

        /* A Response that arrived on a path we could not attribute yet, held
         * until the reply tells us which path the portal actually chose. */
        private string? early_path = null;
        private Variant? early_parameters = null;

        /* --- probing ---------------------------------------------------- */

        /* CORE.md section 6.1: the name must be owned AND Screenshot must
         * report a non-zero version. Checking ownership first also keeps this
         * cheap, because it cannot trigger D-Bus activation of a portal that
         * is merely installed. */
        public bool probe () {
            return owner_present () && screenshot_version () > 0;
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
         * session bus and a missing portal both present. DO_NOT_AUTO_START
         * keeps a probe from starting a service and then timing out on it. */
        public uint32 screenshot_version () {
            try {
                var bus = Bus.get_sync (BusType.SESSION, null);
                var reply = bus.call_sync (BUS_NAME,
                                           OBJECT_PATH,
                                           "org.freedesktop.DBus.Properties",
                                           "Get",
                                           new Variant ("(ss)", SCREENSHOT, "version"),
                                           new VariantType ("(v)"),
                                           DBusCallFlags.NO_AUTO_START,
                                           PROBE_TIMEOUT_MS,
                                           null);
                Variant inner = reply.get_child_value (0).get_variant ();
                if (!inner.is_of_type (VariantType.UINT32)) {
                    return 0;
                }
                return inner.get_uint32 ();
            } catch (Error e) {
                return 0;
            }
        }

        /* --- picking ---------------------------------------------------- */

        public async Rgb? pick () throws Error {
            if (busy) {
                throw new IOError.BUSY ("a pick is already in flight");
            }
            busy = true;

            result = null;
            failure = null;
            finished = false;
            handle_path = null;
            early_path = null;
            early_parameters = null;

            DBusConnection? bus = null;
            uint sub = 0;
            uint timeout_id = 0;

            try {
                bus = yield Bus.get (BusType.SESSION, null);

                string? unique = bus.unique_name;
                if (unique == null || !unique.has_prefix (":")) {
                    throw new IOError.FAILED (
                        "the session bus did not give this process a unique name");
                }

                /* SENDER is the unique name with the leading colon dropped and
                 * every dot turned into an underscore. TOKEN is ours to choose,
                 * and is always a valid object-path element. */
                string sender = unique.substring (1).replace (".", "_");
                string token = "aventurine_%u".printf (++token_counter);
                request_prefix = "/org/freedesktop/portal/desktop/request/%s/".printf (sender);
                request_path = request_prefix + token;

                /* Subscribe first. This is the whole reason the path is built
                 * by hand instead of taken from the reply. No path filter: see
                 * hazard 2 in the file header. */
                sub = bus.signal_subscribe (BUS_NAME, REQUEST, "Response",
                                            null, null,
                                            DBusSignalFlags.NONE, on_response);

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

                handle_path = reply.get_child_value (0).get_string ();

                /* A portal that ignored handle_token may already have answered
                 * on its own path while the reply was in flight. */
                if (!finished && early_path != null && early_path == handle_path) {
                    consume (early_parameters);
                }
                early_path = null;
                early_parameters = null;

                /* Only now is it safe to take a resume handle: see hazard 1.
                 * If the answer is already in, do not park at all. */
                if (!finished) {
                    resume = pick.callback;

                    timeout_id = Timeout.add_seconds (PICK_TIMEOUT_SECONDS, () => {
                        /* Cleared here so the finally below does not try to
                         * remove a source that has already removed itself. */
                        timeout_id = 0;
                        close_request (bus);
                        complete (null, new IOError.TIMED_OUT (
                            "the portal did not answer within %u seconds"
                            .printf (PICK_TIMEOUT_SECONDS)));
                        return Source.REMOVE;
                    });

                    yield;
                }
            } finally {
                if (timeout_id != 0) {
                    Source.remove (timeout_id);
                }
                if (sub != 0 && bus != null) {
                    bus.signal_unsubscribe (sub);
                }
                resume = null;
                busy = false;
            }

            if (failure != null) {
                throw failure;
            }
            return result;
        }

        /* Tells the portal we have stopped listening, so it can drop the
         * request and take its crosshair off the screen. Best effort. */
        private void close_request (DBusConnection? bus) {
            if (bus == null) {
                return;
            }
            string path = handle_path ?? request_path;
            bus.call.begin (BUS_NAME, path, REQUEST, "Close",
                            new Variant.tuple (new Variant[0]),
                            null, DBusCallFlags.NONE, 2000, null);
        }

        private void on_response (DBusConnection connection,
                                  string? sender_name,
                                  string object_path,
                                  string interface_name,
                                  string signal_name,
                                  Variant parameters) {
            if (finished) {
                return;
            }

            if (object_path == request_path
                || (handle_path != null && object_path == handle_path)) {
                consume (parameters);
                return;
            }

            /* Under our own sender prefix but not a path we can attribute yet:
             * hold it until the reply names the path the portal chose. */
            if (handle_path == null
                && request_prefix != ""
                && object_path.has_prefix (request_prefix)) {
                early_path = object_path;
                early_parameters = parameters;
            }
        }

        private void consume (Variant? parameters) {
            if (parameters == null) {
                return;
            }

            /* A malformed payload must not walk off the end of the tuple. */
            if (!parameters.is_of_type (new VariantType ("(ua{sv})"))) {
                complete (null, new IOError.INVALID_DATA (
                    "the portal sent a Response with an unexpected signature"));
                return;
            }

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

            /* CORE.md section 8 states the contract: three doubles in 0..1.
             * A portal that sends NaN or an out-of-range channel is refused
             * here rather than allowed to reach the conversions, where a
             * non-finite value turns into nonsense in every row at once. */
            if (!Convert.is_valid (picked)) {
                complete (null, new IOError.INVALID_DATA (
                    "the portal returned a colour outside 0..1"));
                return;
            }

            complete (picked, null);
        }

        /* Records the answer once, and resumes a parked pick() if there is one.
         * Resumption is deferred to an idle callback so the subscription is
         * torn down outside the signal handler that is tearing it down. */
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
