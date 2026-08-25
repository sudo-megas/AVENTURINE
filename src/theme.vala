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

        public void start () {
            try {
                bus = Bus.get_sync (BusType.SESSION, null);
            } catch (Error e) {
                return;
            }

            apply (read ());

            subscription = bus.signal_subscribe (BUS_NAME, IFACE, "SettingChanged",
                                                 PATH, null, DBusSignalFlags.NONE,
                                                 on_setting_changed);
        }

        ~Theme () {
            if (bus != null && subscription != 0) {
                bus.signal_unsubscribe (subscription);
            }
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
            if (parameters.n_children () < 3) {
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
            var settings = Gtk.Settings.get_default ();
            if (settings == null) {
                return;
            }
            /* Only "prefer dark" is a positive instruction. No preference and
             * prefer light both mean: leave the light theme alone. */
            settings.gtk_application_prefer_dark_theme = (scheme == PREFER_DARK);
        }
    }
}
