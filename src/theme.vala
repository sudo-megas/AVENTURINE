/* Follow the desktop's light or dark preference. CORE.md section 15.
 *
 * Reads org.freedesktop.appearance color-scheme from the Settings portal and
 * subscribes to SettingChanged so a live switch is picked up without a restart.
 * If the portal is absent, this does nothing and GTK's own default stands.
 */

namespace Aventurine {

    public class Theme : Object {

        private const string BUS_NAME  = "org.freedesktop.portal.Desktop";
        private const string PATH      = "/org/freedesktop/portal/desktop";
        private const string IFACE     = "org.freedesktop.portal.Settings";
        private const string NAMESPACE = "org.freedesktop.appearance";
        private const string KEY       = "color-scheme";

        private const int TIMEOUT_MS = 1000;

        /* 0 no preference, 1 prefer dark, 2 prefer light. */
        public const uint32 NO_PREFERENCE = 0;
        public const uint32 PREFER_DARK   = 1;
        public const uint32 PREFER_LIGHT  = 2;

        private DBusConnection? bus = null;
        private uint subscription = 0;

        /* Idempotent, and does not block. Getting the bus and reading the
         * setting are done asynchronously: this runs from App.startup(), and
         * a portal that owns its name but answers slowly would otherwise stall
         * the first frame behind two one-second timeouts. */
        public void start () {
            if (bus != null || starting) {
                return;
            }
            starting = true;
            begin_start.begin ();
        }

        private bool starting = false;

        private async void begin_start () {
            try {
                bus = yield Bus.get (BusType.SESSION, null);
            } catch (Error e) {
                starting = false;
                return;
            }

            subscription = bus.signal_subscribe (BUS_NAME, IFACE, "SettingChanged",
                                                 PATH, null, DBusSignalFlags.NONE,
                                                 on_setting_changed);
            apply (read ());
            starting = false;
        }

        /* Not a destructor. signal_subscribe takes an owned delegate, so the
         * subscription holds a strong reference to this object, which the
         * destructor could only release by running — which it cannot, because
         * the reference keeps it alive. That cycle makes ~Theme dead code, so
         * teardown is explicit and the App calls it on shutdown. */
        public void stop () {
            if (bus != null && subscription != 0) {
                bus.signal_unsubscribe (subscription);
                subscription = 0;
            }
            bus = null;
        }

        /* ReadOne arrived with Settings version 2. Older portals only have
         * Read, which wraps the value one layer deeper. Unwrapping in a loop
         * covers both without version sniffing. */
        private uint32 read () {
            if (bus == null) {
                return NO_PREFERENCE;
            }
            try {
                var reply = bus.call_sync (BUS_NAME, PATH, IFACE, "ReadOne",
                                           new Variant ("(ss)", NAMESPACE, KEY),
                                           new VariantType ("(v)"),
                                           DBusCallFlags.NONE, TIMEOUT_MS, null);
                return unwrap (reply.get_child_value (0));
            } catch (Error e) {
                /* fall through to Read */
            }
            try {
                var reply = bus.call_sync (BUS_NAME, PATH, IFACE, "Read",
                                           new Variant ("(ss)", NAMESPACE, KEY),
                                           new VariantType ("(v)"),
                                           DBusCallFlags.NONE, TIMEOUT_MS, null);
                return unwrap (reply.get_child_value (0));
            } catch (Error e) {
                return NO_PREFERENCE;
            }
        }

        private static uint32 unwrap (Variant value) {
            Variant current = value;
            while (current.is_of_type (VariantType.VARIANT)) {
                current = current.get_variant ();
            }
            if (!current.is_of_type (VariantType.UINT32)) {
                return NO_PREFERENCE;
            }
            return current.get_uint32 ();
        }

        private void on_setting_changed (DBusConnection connection,
                                         string? sender_name,
                                         string object_path,
                                         string interface_name,
                                         string signal_name,
                                         Variant parameters) {
            /* Anything that owns the portal name can emit this. Check the
             * shape before indexing it, or a payload that is not (ssv) turns
             * into a GLib critical and, under fatal-criticals, an abort. */
            if (!parameters.is_of_type (new VariantType ("(ssv)"))) {
                return;
            }
            if (parameters.get_child_value (0).get_string () != NAMESPACE) {
                return;
            }
            if (parameters.get_child_value (1).get_string () != KEY) {
                return;
            }
            apply (unwrap (parameters.get_child_value (2)));
        }

        private void apply (uint32 scheme) {
            /* CORE.md section 15: with no preference, fall back to the GTK
             * default and do nothing clever. Writing false here would clobber
             * a user who set gtk-application-prefer-dark-theme themselves,
             * flipping a dark desktop to light on any session whose portal
             * does not answer. */
            if (scheme != PREFER_DARK && scheme != PREFER_LIGHT) {
                return;
            }
            var settings = Gtk.Settings.get_default ();
            if (settings == null) {
                return;
            }
            settings.gtk_application_prefer_dark_theme = (scheme == PREFER_DARK);
        }
    }
}
