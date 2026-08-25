/* Palette export. CORE.md section 13.
 *
 * Two formats, both writing the current history. The destination goes through
 * Gtk.FileDialog, which routes via the FileChooser portal, so no assumption is
 * made about the user's file manager or where they keep things.
 */

namespace Aventurine {

    namespace Export {

        public const string GPL_SUFFIX = ".gpl";
        public const string CSS_SUFFIX = ".css";

        /* GIMP palette. Channels are byte values, right aligned in three
         * columns, then a tab and the hex — which is what GIMP itself writes. */
        public string to_gpl (History history) {
            var builder = new StringBuilder ();
            builder.append ("GIMP Palette\n");
            builder.append ("Name: AVENTURINE\n");
            builder.append ("Columns: 8\n");
            builder.append ("#\n");

            for (int i = 0; i < history.size; i++) {
                var entry = history.get_at (i);
                Rgb? colour = entry.to_rgb ();
                if (colour == null) {
                    continue;
                }
                builder.append_printf ("%3d %3d %3d\t%s\n",
                                       Convert.to_byte (colour.r),
                                       Convert.to_byte (colour.g),
                                       Convert.to_byte (colour.b),
                                       entry.hex);
            }
            return builder.str;
        }

        /* CSS custom properties, numbered from the newest entry. */
        public string to_css (History history) {
            var builder = new StringBuilder ();
            builder.append (":root {\n");

            int n = 0;
            for (int i = 0; i < history.size; i++) {
                var entry = history.get_at (i);
                if (entry.to_rgb () == null) {
                    continue;
                }
                n++;
                builder.append_printf ("  --aventurine-%d: %s;\n", n, entry.hex);
            }

            builder.append ("}\n");
            return builder.str;
        }

        /* The suffix decides the format, so one dialog covers both. */
        public string render (History history, string filename) {
            if (filename.down ().has_suffix (CSS_SUFFIX)) {
                return to_css (history);
            }
            return to_gpl (history);
        }

        /* Returns the written path, or null if the user dismissed the dialog.
         * A failure to choose a destination or to write one throws. */
        public async string? run (Gtk.Window parent, History history) throws Error {
            var dialog = new Gtk.FileDialog ();
            dialog.title = "Export palette";
            dialog.modal = true;
            dialog.initial_name = "aventurine.gpl";

            var palette = new Gtk.FileFilter ();
            palette.name = "GIMP palette (*.gpl)";
            palette.add_pattern ("*.gpl");

            var stylesheet = new Gtk.FileFilter ();
            stylesheet.name = "CSS custom properties (*.css)";
            stylesheet.add_pattern ("*.css");

            var filters = new ListStore (typeof (Gtk.FileFilter));
            filters.append (palette);
            filters.append (stylesheet);
            dialog.set_filters (filters);

            File? target;
            try {
                target = yield dialog.save (parent, null);
            } catch (Gtk.DialogError e) {
                /* Dismissing the dialog arrives as an error and is not one.
                 * A genuine DialogError.FAILED is, and must not be swallowed
                 * as though the user had simply changed their mind. */
                if (e is Gtk.DialogError.FAILED) {
                    throw e;
                }
                return null;
            }
            if (target == null) {
                return null;
            }

            string name = target.get_basename () ?? "aventurine.gpl";
            string body = render (history, name);

            target.replace_contents (body.data, null, false,
                                     FileCreateFlags.REPLACE_DESTINATION,
                                     null, null);
            return target.get_path () ?? name;
        }
    }
}
