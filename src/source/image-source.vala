/* Pick a pixel out of an image. CORE.md section 6.2.
 *
 * No platform interface is involved, so probe() is unconditionally true. This
 * is the rung that guarantees the application is never completely useless, and
 * it earns its place on its own: pulling a colour out of a screenshot or a
 * photograph is a real use, not just a fallback.
 *
 * Display goes through Cairo with nearest-neighbour filtering, so a magnified
 * pixel is the pixel that gets picked. The click coordinate arrives in the
 * widget's logical coordinates and is mapped back through the fit transform —
 * the scale and centring offsets this widget chose — before indexing the
 * pixbuf. The display's own scale factor never enters the arithmetic: GDK
 * reports both the allocation and the pointer in the same logical space, so it
 * has already cancelled out, and reapplying it would double-count.
 */

namespace Aventurine {

    public class ImageSource : Object, ColourSource {

        public string id { get { return "image"; } }
        public string label { get { return "Image file or clipboard"; } }

        /* Set by the window so the picker can be transient for it. */
        public Gtk.Window? parent { get; set; default = null; }

        /* Nothing to probe. This backend cannot be unavailable. */
        public bool probe () {
            return true;
        }

        public async Rgb? pick () throws Error {
            var picker = new ImagePicker (parent);
            picker.set_resume (pick.callback);
            picker.present ();
            yield;
            return picker.picked;
        }
    }

    /* The picker window. Internal to this file: nothing else needs it. */
    private class ImagePicker : Gtk.Window {

        public Rgb? picked = null;

        private Gdk.Pixbuf? pixbuf = null;
        private Gtk.DrawingArea area;
        private Gtk.Label status;
        private Gtk.Stack stack;

        /* Fit transform from source pixels to widget coordinates, recomputed
         * on every draw and read back by the click handler. */
        private double scale = 1.0;
        private double off_x = 0.0;
        private double off_y = 0.0;

        private bool done = false;
        private SourceFunc? resume = null;

        public ImagePicker (Gtk.Window? parent) {
            Object (transient_for: parent, modal: parent != null);

            this.title = "Pick from an image";
            this.set_default_size (760, 580);

            var header = new Gtk.HeaderBar ();
            var open_button = new Gtk.Button.with_label ("Open…");
            open_button.clicked.connect (() => { choose_file.begin (); });
            header.pack_start (open_button);

            var paste_button = new Gtk.Button.with_label ("Paste");
            paste_button.tooltip_text = "Paste an image from the clipboard";
            paste_button.clicked.connect (() => { paste_clipboard.begin (); });
            header.pack_start (paste_button);
            this.set_titlebar (header);

            area = new Gtk.DrawingArea ();
            area.hexpand = true;
            area.vexpand = true;
            area.set_draw_func (draw);

            var click = new Gtk.GestureClick ();
            click.pressed.connect (on_pressed);
            area.add_controller (click);

            var motion = new Gtk.EventControllerMotion ();
            motion.motion.connect (on_motion);
            motion.leave.connect (() => { status.label = default_status (); });
            area.add_controller (motion);

            var placeholder = new Gtk.Label (
                "Open a PNG or JPEG, or paste an image from the clipboard,\n"
                + "then click any pixel to pick its colour.");
            placeholder.justify = Gtk.Justification.CENTER;
            placeholder.add_css_class ("dim-label");

            stack = new Gtk.Stack ();
            stack.add_named (placeholder, "empty");
            stack.add_named (area, "image");
            stack.visible_child_name = "empty";
            stack.vexpand = true;

            status = new Gtk.Label (default_status ());
            status.add_css_class ("dim-label");
            status.margin_top = 6;
            status.margin_bottom = 6;

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.append (stack);
            box.append (status);
            this.set_child (box);

            /* Escape closes without picking. */
            var keys = new Gtk.EventControllerKey ();
            keys.key_pressed.connect ((keyval, keycode, state) => {
                if (keyval == Gdk.Key.Escape) {
                    this.close ();
                    return true;
                }
                return false;
            });
            ((Gtk.Widget) this).add_controller (keys);

            this.close_request.connect (() => {
                finish ();
                return false;
            });
        }

        /* close_request is not emitted for a window that is destroyed rather
         * than closed, and a picker that disappears without resuming pick()
         * would leave the caller suspended forever with its busy flag set. */
        public override void dispose () {
            finish ();
            base.dispose ();
        }

        public void set_resume (owned SourceFunc callback) {
            resume = (owned) callback;
        }

        private void finish () {
            if (done) {
                return;
            }
            done = true;
            if (resume != null) {
                SourceFunc waiting = (owned) resume;
                resume = null;
                Idle.add ((owned) waiting);
            }
        }

        private string default_status () {
            if (pixbuf == null) {
                return "No image loaded";
            }
            return "%d × %d — click a pixel to pick it"
                   .printf (pixbuf.get_width (), pixbuf.get_height ());
        }

        /* --- loading ---------------------------------------------------- */

        private async void choose_file () {
            var dialog = new Gtk.FileDialog ();
            dialog.title = "Open an image";
            dialog.modal = true;

            var images = new Gtk.FileFilter ();
            images.name = "Images";
            images.add_pixbuf_formats ();

            var filters = new ListStore (typeof (Gtk.FileFilter));
            filters.append (images);
            dialog.set_filters (filters);

            try {
                var file = yield dialog.open (this, null);
                if (file != null) {
                    load_file (file);
                }
            } catch (Error e) {
                /* Cancelling the dialog arrives here as an error. */
            }
        }

        private void load_file (File file) {
            try {
                var loaded = new Gdk.Pixbuf.from_stream (file.read (null), null);
                adopt (loaded, file.get_basename () ?? "image");
            } catch (Error e) {
                status.label = "Could not read that image: " + e.message;
            }
        }

        private async void paste_clipboard () {
            var display = Gdk.Display.get_default ();
            if (display == null) {
                status.label = "No display, so no clipboard";
                return;
            }
            try {
                var texture = yield display.get_clipboard ().read_texture_async (null);
                if (texture == null) {
                    status.label = "The clipboard does not hold an image";
                    return;
                }
                /* gdk_pixbuf_get_from_texture is deprecated from 4.12, so go
                 * through PNG bytes instead. It is lossless, and it keeps
                 * GdkPixbuf as the single pixel accessor. */
                var stream = new MemoryInputStream.from_bytes (texture.save_to_png_bytes ());
                adopt (new Gdk.Pixbuf.from_stream (stream, null), "clipboard");
            } catch (Error e) {
                status.label = "The clipboard does not hold an image";
            }
        }

        private void adopt (Gdk.Pixbuf loaded, string what) {
            /* Pixel reads below assume eight bits per sample, which is what
             * every GdkPixbuf loader produces. Refuse anything else rather
             * than index past the end of a row. */
            if (loaded.get_bits_per_sample () != 8 || loaded.get_n_channels () < 3) {
                status.label = "Unsupported image format";
                return;
            }
            pixbuf = loaded;
            stack.visible_child_name = "image";
            status.label = default_status ();
            area.queue_draw ();
        }

        /* --- drawing ---------------------------------------------------- */

        /* Contain, never crop. Small images are magnified so single pixels stay
         * clickable. Recomputed from the allocation on demand rather than left
         * over from the last draw, so a click that arrives before the first
         * frame of a newly loaded image still maps through that image's
         * transform and not the previous one's. */
        private void fit_transform (int width, int height) {
            if (pixbuf == null) {
                scale = 1.0;
                off_x = 0.0;
                off_y = 0.0;
                return;
            }
            double iw = pixbuf.get_width ();
            double ih = pixbuf.get_height ();
            scale = double.min (width / iw, height / ih);
            off_x = (width - iw * scale) / 2.0;
            off_y = (height - ih * scale) / 2.0;
        }

        private void draw (Gtk.DrawingArea widget, Cairo.Context cr, int width, int height) {
            if (pixbuf == null) {
                return;
            }

            double iw = pixbuf.get_width ();
            double ih = pixbuf.get_height ();
            fit_transform (width, height);

            cr.save ();
            cr.translate (off_x, off_y);
            cr.scale (scale, scale);
            Gdk.cairo_set_source_pixbuf (cr, pixbuf, 0, 0);
            /* What is shown must be exactly what is picked. */
            cr.get_source ().set_filter (Cairo.Filter.NEAREST);
            cr.rectangle (0, 0, iw, ih);
            cr.fill ();
            cr.restore ();
        }

        /* --- picking ---------------------------------------------------- */

        /* Maps a widget coordinate back to a source pixel. False if the point
         * is outside the image. */
        private bool locate (double x, double y, out int px, out int py) {
            px = 0;
            py = 0;
            if (pixbuf == null) {
                return false;
            }
            fit_transform (area.get_width (), area.get_height ());
            if (scale <= 0.0) {
                return false;
            }
            px = (int) Math.floor ((x - off_x) / scale);
            py = (int) Math.floor ((y - off_y) / scale);
            return px >= 0 && py >= 0
                && px < pixbuf.get_width () && py < pixbuf.get_height ();
        }

        private Rgb read_pixel (int px, int py) {
            unowned uint8[] data = pixbuf.get_pixels ();
            int offset = py * pixbuf.get_rowstride () + px * pixbuf.get_n_channels ();
            return Convert.from_bytes (data[offset], data[offset + 1], data[offset + 2]);
        }

        private void on_motion (double x, double y) {
            int px, py;
            if (!locate (x, y, out px, out py)) {
                status.label = default_status ();
                return;
            }
            status.label = "%s at %d, %d".printf (Convert.to_hex (read_pixel (px, py)), px, py);
        }

        private void on_pressed (int n_press, double x, double y) {
            int px, py;
            if (!locate (x, y, out px, out py)) {
                return;
            }
            picked = read_pixel (px, py);
            finish ();
            this.destroy ();
        }
    }
}
