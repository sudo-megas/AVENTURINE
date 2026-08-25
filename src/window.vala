/* The single application window. CORE.md section 14.
 *
 * Vertical order: header swatch, pick button, then a scrolling list holding the
 * fourteen format rows, the contrast block and the tint and shade ramp.
 *
 * Copying is always explicit. Clicking a row copies that row and raises a toast
 * naming what was copied; nothing reaches the clipboard without a click.
 */

namespace Aventurine {

    /* A flat rectangle of one colour, optionally rounded. Used for the header,
     * the ramp strip and the history swatches. */
    private class Swatch : Gtk.DrawingArea {

        private Rgb colour = { 0.5, 0.5, 0.5 };
        private bool filled = false;
        private double radius;

        public Swatch (double radius = 0.0) {
            this.radius = radius;
            set_draw_func (render);
        }

        public void set_colour (Rgb value) {
            colour = value;
            filled = true;
            queue_draw ();
        }

        public void clear () {
            filled = false;
            queue_draw ();
        }

        private void rounded_path (Cairo.Context cr, int width, int height) {
            double r = double.min (radius, double.min (width, height) / 2.0);
            if (r <= 0.0) {
                cr.rectangle (0, 0, width, height);
                return;
            }
            cr.new_sub_path ();
            cr.arc (width - r, r, r, -Math.PI / 2, 0);
            cr.arc (width - r, height - r, r, 0, Math.PI / 2);
            cr.arc (r, height - r, r, Math.PI / 2, Math.PI);
            cr.arc (r, r, r, Math.PI, 3 * Math.PI / 2);
            cr.close_path ();
        }

        private void render (Gtk.DrawingArea widget, Cairo.Context cr, int width, int height) {
            rounded_path (cr, width, height);
            if (filled) {
                cr.set_source_rgb (colour.r, colour.g, colour.b);
                cr.fill ();
                return;
            }

            /* Empty state: a neutral field that follows the theme rather than
             * a black rectangle pretending to be a picked colour. */
            var fg = widget.get_color ();
            cr.set_source_rgba (fg.red, fg.green, fg.blue, 0.10);
            cr.fill ();
        }
    }

    /* One of the fourteen format rows: a flat button carrying a label and a
     * monospace value. */
    private class FormatRow : Gtk.Button {

        public int index { get; private set; }
        private Gtk.Label value_label;

        public FormatRow (int index) {
            this.index = index;

            var name = new Gtk.Label (Colour.row_label (index));
            name.xalign = 0.0f;
            name.add_css_class ("dim-label");

            value_label = new Gtk.Label ("");
            value_label.xalign = 1.0f;
            value_label.hexpand = true;
            value_label.ellipsize = Pango.EllipsizeMode.END;
            value_label.add_css_class ("format-value");

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            box.append (name);
            box.append (value_label);

            this.child = box;
            this.add_css_class ("flat");
            this.add_css_class ("format-row");
        }

        public string value {
            get { return value_label.label; }
            set { value_label.label = value; }
        }
    }

    /* One contrast row: a ratio and the four WCAG verdicts. */
    private class ContrastRow : Gtk.Box {

        private Gtk.Label ratio_label;
        private Gtk.Label[] badges;

        private const string[] BADGE_NAMES = { "AA", "AA L", "AAA", "AAA L" };
        private const string[] BADGE_TIPS = {
            "AA, normal text — needs 4.5:1",
            "AA, large text — needs 3:1",
            "AAA, normal text — needs 7:1",
            "AAA, large text — needs 4.5:1"
        };

        public ContrastRow (string against) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 8);

            var name = new Gtk.Label (against);
            name.xalign = 0.0f;
            name.width_chars = 8;
            name.add_css_class ("dim-label");
            this.append (name);

            ratio_label = new Gtk.Label ("");
            ratio_label.xalign = 0.0f;
            ratio_label.width_chars = 6;
            ratio_label.add_css_class ("format-value");
            this.append (ratio_label);

            var spacer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            spacer.hexpand = true;
            this.append (spacer);

            badges = new Gtk.Label[4];
            for (int i = 0; i < 4; i++) {
                badges[i] = new Gtk.Label (BADGE_NAMES[i]);
                badges[i].tooltip_text = BADGE_TIPS[i];
                badges[i].add_css_class ("badge");
                this.append (badges[i]);
            }
        }

        public void update (ContrastResult result) {
            ratio_label.label = "%.2f".printf (result.ratio);
            bool[] passes = {
                result.aa_normal, result.aa_large, result.aaa_normal, result.aaa_large
            };
            for (int i = 0; i < 4; i++) {
                /* The mark carries the verdict as well as the colour: encoding
                 * pass and fail in hue alone would be a poor look on a tool
                 * whose whole job is contrast. */
                badges[i].label = "%s %s".printf (BADGE_NAMES[i], passes[i] ? "✓" : "✗");
                badges[i].remove_css_class (passes[i] ? "badge-fail" : "badge-pass");
                badges[i].add_css_class (passes[i] ? "badge-pass" : "badge-fail");
            }
        }
    }

    /* One history entry: swatch, hex, relative time, and a delete control that
     * appears on hover. Opacity rather than visibility, so the row does not
     * change size under the pointer. */
    private class HistoryRow : Gtk.Box {

        public signal void copy_requested ();
        public signal void delete_requested ();

        private Gtk.Button remove_button;

        public HistoryRow (HistoryEntry entry) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);

            var swatch = new Swatch (4.0);
            swatch.width_request = 28;
            swatch.height_request = 22;
            swatch.valign = Gtk.Align.CENTER;
            Rgb? colour = entry.to_rgb ();
            if (colour != null) {
                swatch.set_colour (colour);
            }

            var hex = new Gtk.Label (entry.hex);
            hex.xalign = 0.0f;
            hex.add_css_class ("format-value");

            var when = new Gtk.Label (entry.relative_time ());
            when.xalign = 1.0f;
            when.hexpand = true;
            when.ellipsize = Pango.EllipsizeMode.END;
            when.add_css_class ("dim-label");

            var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            content.append (swatch);
            content.append (hex);
            content.append (when);

            var open = new Gtk.Button ();
            open.set_child (content);
            open.add_css_class ("flat");
            open.add_css_class ("format-row");
            open.hexpand = true;
            open.tooltip_text = "Click to copy " + entry.hex;
            open.clicked.connect (() => { copy_requested (); });

            remove_button = new Gtk.Button.from_icon_name ("user-trash-symbolic");
            remove_button.add_css_class ("flat");
            remove_button.valign = Gtk.Align.CENTER;
            remove_button.tooltip_text = "Remove this entry";
            remove_button.opacity = 0.0;
            remove_button.sensitive = false;
            remove_button.clicked.connect (() => { delete_requested (); });

            this.append (open);
            this.append (remove_button);

            var motion = new Gtk.EventControllerMotion ();
            motion.enter.connect ((x, y) => { reveal (true); });
            motion.leave.connect (() => { reveal (false); });
            this.add_controller (motion);

            /* Hover is not the only way to reach a row. Revealing on focus too
             * keeps the delete control usable from the keyboard, where an
             * insensitive button would be skipped in the tab order entirely. */
            var focus = new Gtk.EventControllerFocus ();
            focus.enter.connect (() => { reveal (true); });
            focus.leave.connect (() => { reveal (false); });
            this.add_controller (focus);
        }

        private void reveal (bool shown) {
            remove_button.opacity = shown ? 1.0 : 0.0;
            remove_button.sensitive = shown;
        }
    }

    public class Window : Gtk.ApplicationWindow {

        private App app;

        private Colour? current = null;

        /* Header */
        private Swatch header_swatch;
        private Gtk.Label header_hex;
        private Gtk.Button pick_button;
        private Gtk.Revealer banner;

        /* Sections */
        private Gtk.Box formats_section;
        private FormatRow[] rows;
        private Gtk.Box contrast_section;
        private ContrastRow contrast_white;
        private ContrastRow contrast_black;
        private Gtk.Box ramp_section;
        private Swatch[] ramp_swatches;
        private Rgb[] ramp_colours;

        /* History */
        private History history;
        private Gtk.Box history_section;
        private Gtk.Box history_list;
        private Gtk.Label history_empty;

        /* Toast */
        private Gtk.Revealer toast_revealer;
        private Gtk.Label toast_label;
        private uint toast_timeout = 0;

        private bool picking = false;

        public Window (Gtk.Application application) {
            Object (application: application);
            this.app = (App) application;

            this.title = "Aventurine";
            this.set_default_size (420, 640);

            history = new History ();
            history.load ();

            load_style ();
            build_header_bar ();

            var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            root.append (build_banner ());
            root.append (build_header ());
            root.append (build_pick_button ());
            root.append (build_scroller ());

            var overlay = new Gtk.Overlay ();
            overlay.set_child (root);
            overlay.add_overlay (build_toast ());
            this.set_child (overlay);

            install_actions ();
            show_empty_state ();
            update_backend_hints ();

            /* A portal that was still starting when the window opened would
             * otherwise leave the button reading "Pick from an image" until
             * the first press discovered otherwise. Re-checking when the
             * window becomes active corrects the label before it can mislead. */
            this.notify["is-active"].connect (() => {
                if (this.is_active && app.ladder.selected () != null
                    && app.ladder.selected ().id != "portal") {
                    app.ladder.reprobe ();
                    update_backend_hints ();
                }
            });
        }

        /* --- chrome ------------------------------------------------------ */

        private void build_header_bar () {
            var bar = new Gtk.HeaderBar ();

            var menu = new Menu ();
            menu.append ("Export…", "win.export");
            menu.append ("Clear history", "win.clear-history");
            menu.append ("About Aventurine", "win.about");

            var button = new Gtk.MenuButton ();
            button.icon_name = "open-menu-symbolic";
            button.tooltip_text = "Menu";
            button.menu_model = menu;
            bar.pack_end (button);

            this.set_titlebar (bar);
        }

        private Gtk.Widget build_banner () {
            var label = new Gtk.Label (
                "No screen-capture backend answered. Run aventurine --doctor for "
                + "details — picking from an image still works.");
            label.wrap = true;
            label.xalign = 0.0f;
            label.margin_start = 12;
            label.margin_end = 12;
            label.margin_top = 8;
            label.margin_bottom = 8;

            var holder = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            holder.append (label);
            holder.add_css_class ("banner");

            banner = new Gtk.Revealer ();
            banner.set_child (holder);
            banner.reveal_child = false;
            return banner;
        }

        private Gtk.Widget build_header () {
            header_swatch = new Swatch ();
            /* Roughly 30% of the 640 point default height. */
            header_swatch.height_request = 190;
            header_swatch.hexpand = true;

            header_hex = new Gtk.Label ("");
            header_hex.add_css_class ("header-hex");
            header_hex.halign = Gtk.Align.CENTER;
            header_hex.valign = Gtk.Align.CENTER;

            var overlay = new Gtk.Overlay ();
            overlay.set_child (header_swatch);
            overlay.add_overlay (header_hex);
            return overlay;
        }

        private Gtk.Widget build_pick_button () {
            pick_button = new Gtk.Button.with_label ("Pick a colour");
            pick_button.add_css_class ("suggested-action");
            pick_button.add_css_class ("pick-button");
            pick_button.margin_start = 12;
            pick_button.margin_end = 12;
            pick_button.margin_top = 12;
            pick_button.margin_bottom = 6;
            pick_button.clicked.connect (() => { start_pick.begin (); });
            return pick_button;
        }

        private Gtk.Widget build_scroller () {
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.margin_start = 12;
            content.margin_end = 12;
            content.margin_bottom = 12;

            content.append (build_formats ());
            content.append (build_contrast ());
            content.append (build_ramp ());
            content.append (build_history ());

            var scroller = new Gtk.ScrolledWindow ();
            scroller.hscrollbar_policy = Gtk.PolicyType.NEVER;
            scroller.vexpand = true;
            scroller.set_child (content);
            return scroller;
        }

        private Gtk.Widget section_title (string text) {
            var label = new Gtk.Label (text);
            label.xalign = 0.0f;
            label.margin_top = 12;
            label.margin_bottom = 4;
            label.add_css_class ("section-title");
            return label;
        }

        private Gtk.Widget build_formats () {
            formats_section = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            rows = new FormatRow[Colour.ROW_COUNT];
            for (int i = 0; i < Colour.ROW_COUNT; i++) {
                var row = new FormatRow (i);
                int captured = i;
                row.clicked.connect (() => { copy_row (captured); });
                rows[i] = row;
                formats_section.append (row);
            }
            return formats_section;
        }

        private Gtk.Widget build_contrast () {
            contrast_section = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            contrast_section.append (section_title ("CONTRAST"));

            contrast_white = new ContrastRow ("vs white");
            contrast_black = new ContrastRow ("vs black");
            contrast_section.append (contrast_white);
            contrast_section.append (contrast_black);
            return contrast_section;
        }

        private Gtk.Widget build_ramp () {
            ramp_section = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            ramp_section.append (section_title ("TINTS AND SHADES"));

            var strip = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
            strip.homogeneous = true;
            strip.height_request = 44;

            ramp_swatches = new Swatch[Ramp.LENGTH];
            ramp_colours = new Rgb[Ramp.LENGTH];

            for (int i = 0; i < Ramp.LENGTH; i++) {
                var swatch = new Swatch (4.0);
                swatch.hexpand = true;
                swatch.tooltip_text = "Click to copy";

                int captured = i;
                var click = new Gtk.GestureClick ();
                /* Only a release still inside the swatch counts. GestureClick
                 * reports a release wherever it happens, so without this a
                 * press dragged off the strip and let go still copied — and
                 * CORE.md section 14 is explicit that nothing reaches the
                 * clipboard without a click. Every other clickable here is a
                 * GtkButton, which cancels on release-outside by itself. */
                click.released.connect ((n_press, x, y) => {
                    if (x < 0 || y < 0
                        || x > swatch.get_width () || y > swatch.get_height ()) {
                        return;
                    }
                    copy_ramp (captured);
                });
                swatch.add_controller (click);

                ramp_swatches[i] = swatch;
                strip.append (swatch);
            }

            ramp_section.append (strip);
            return ramp_section;
        }

        private Gtk.Widget build_history () {
            history_section = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            history_section.append (section_title ("HISTORY"));

            history_empty = new Gtk.Label ("Nothing picked yet.");
            history_empty.xalign = 0.0f;
            history_empty.margin_top = 4;
            history_empty.margin_bottom = 4;
            history_empty.add_css_class ("dim-label");
            history_section.append (history_empty);

            history_list = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            history_section.append (history_list);

            history.changed.connect (rebuild_history);
            rebuild_history ();
            return history_section;
        }

        /* Newest first, which is the order History already keeps. */
        private void rebuild_history () {
            Gtk.Widget? child = history_list.get_first_child ();
            while (child != null) {
                Gtk.Widget? next = child.get_next_sibling ();
                history_list.remove (child);
                child = next;
            }

            history_empty.visible = history.size == 0;

            for (int i = 0; i < history.size; i++) {
                var entry = history.get_at (i);
                var row = new HistoryRow (entry);
                int captured = i;
                row.copy_requested.connect (() => {
                    copy_text (entry.hex, "history entry");
                });
                row.delete_requested.connect (() => {
                    if (!history.remove_at (captured)) {
                        toast ("Could not write the history file");
                    }
                });
                history_list.append (row);
            }
        }

        private Gtk.Widget build_toast () {
            toast_label = new Gtk.Label ("");
            toast_label.margin_start = 16;
            toast_label.margin_end = 16;
            toast_label.margin_top = 8;
            toast_label.margin_bottom = 8;

            var holder = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            holder.append (toast_label);
            holder.add_css_class ("toast");
            holder.halign = Gtk.Align.CENTER;

            toast_revealer = new Gtk.Revealer ();
            toast_revealer.set_child (holder);
            toast_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
            toast_revealer.halign = Gtk.Align.CENTER;
            toast_revealer.valign = Gtk.Align.END;
            toast_revealer.margin_bottom = 24;
            toast_revealer.can_target = false;
            toast_revealer.reveal_child = false;
            return toast_revealer;
        }

        /* --- style ------------------------------------------------------- */

        /* data/style.css is looked up where make install puts it, then beside
         * the binary for a build tree. Missing CSS costs appearance, never
         * function, so a failure here is silent by design. */
        private void load_style () {
            string[] candidates = {};
            foreach (string dir in Environment.get_system_data_dirs ()) {
                candidates += Path.build_filename (dir, "aventurine", "style.css");
            }
            candidates += Path.build_filename (
                Environment.get_current_dir (), "data", "style.css");

            foreach (string path in candidates) {
                if (!FileUtils.test (path, FileTest.EXISTS)) {
                    continue;
                }
                var provider = new Gtk.CssProvider ();
                provider.load_from_path (path);
                var display = Gdk.Display.get_default ();
                if (display != null) {
                    Gtk.StyleContext.add_provider_for_display (
                        display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                }
                return;
            }
        }

        /* --- actions and keyboard, CORE.md section 16 -------------------- */

        private void install_actions () {
            var pick = new SimpleAction ("pick", null);
            pick.activate.connect (() => { start_pick.begin (); });
            this.add_action (pick);

            var copy_hex = new SimpleAction ("copy-hex", null);
            copy_hex.activate.connect (() => { copy_row (0); });
            this.add_action (copy_hex);

            var copy_row_action = new SimpleAction ("copy-row", VariantType.INT32);
            copy_row_action.activate.connect ((parameter) => {
                copy_row (parameter.get_int32 () - 1);
            });
            this.add_action (copy_row_action);

            var close_action = new SimpleAction ("close", null);
            close_action.activate.connect (() => { this.close (); });
            this.add_action (close_action);

            var export_action = new SimpleAction ("export", null);
            export_action.activate.connect (() => { run_export.begin (); });
            this.add_action (export_action);

            var clear_action = new SimpleAction ("clear-history", null);
            clear_action.activate.connect (() => { confirm_clear_history (); });
            this.add_action (clear_action);

            var about = new SimpleAction ("about", null);
            about.activate.connect (() => { show_about (); });
            this.add_action (about);

            /* Ctrl+P is a plain accelerator. Space is not: accelerators run
             * before the focused widget sees the key, so registering Space
             * here took it away from every button in the window — tabbing to a
             * format row and pressing Space started a pick instead of copying
             * the row. It is handled in the bubble phase below instead, which
             * fires only once the focused widget has declined it. */
            app.set_accels_for_action ("win.pick", { "<Control>p" });
            app.set_accels_for_action ("win.copy-hex", { "<Control>c" });
            app.set_accels_for_action ("win.close", { "Escape" });
            app.set_accels_for_action ("win.export", { "<Control>e" });
            app.set_accels_for_action ("win.clear-history", { "<Control><Shift>c" });
            /* Both the top row and the keypad, so the shortcut works on a
             * full-size keyboard with NumLock on. */
            for (int i = 1; i <= 9; i++) {
                app.set_accels_for_action (
                    "win.copy-row(%d)".printf (i),
                    { "%d".printf (i), "KP_%d".printf (i) });
            }

            /* CORE.md section 16 gives Space to Pick. Bubble phase, so a
             * focused button still gets Space first and activates normally. */
            var space = new Gtk.EventControllerKey ();
            space.set_propagation_phase (Gtk.PropagationPhase.BUBBLE);
            space.key_pressed.connect ((keyval, keycode, state) => {
                if (keyval == Gdk.Key.space
                    && (state & Gdk.ModifierType.CONTROL_MASK) == 0
                    && (state & Gdk.ModifierType.ALT_MASK) == 0) {
                    start_pick.begin ();
                    return true;
                }
                return false;
            });
            ((Gtk.Widget) this).add_controller (space);
        }

        private async void run_export () {
            if (history.size == 0) {
                toast ("Nothing to export yet");
                return;
            }
            try {
                string? written = yield Export.run (this, history);
                if (written != null) {
                    toast ("Exported to " + Path.get_basename (written));
                }
            } catch (Error e) {
                toast ("Export failed: " + e.message);
            }
        }

        /* CORE.md section 12: clearing everything asks first. */
        private void confirm_clear_history () {
            if (history.size == 0) {
                toast ("The history is already empty");
                return;
            }

            var dialog = new Gtk.AlertDialog ("Clear the history?");
            dialog.detail = "%u picked colours will be removed. This cannot be undone."
                            .printf (history.size);
            dialog.buttons = { "Cancel", "Clear" };
            dialog.cancel_button = 0;
            dialog.default_button = 0;
            dialog.modal = true;

            dialog.choose.begin (this, null, (source, result) => {
                try {
                    if (dialog.choose.end (result) == 1) {
                        toast (history.clear () ? "History cleared"
                                                : "Could not write the history file");
                    }
                } catch (Error e) {
                    /* dismissed */
                }
            });
        }

        protected virtual void show_about () {
            var about = new About (this, app.ladder);
            about.present ();
        }

        /* --- picking ----------------------------------------------------- */

        private void update_backend_hints () {
            var selected = app.ladder.selected ();

            /* CORE.md section 7: the banner is about screen capture. The image
             * rung cannot fail, so it is the portal being unavailable that the
             * user needs telling about. */
            banner.reveal_child = !app.ladder.portal.probe ();

            if (selected != null && selected.id == "image") {
                pick_button.label = "Pick from an image…";
            } else {
                pick_button.label = "Pick a colour";
            }
        }

        private async void start_pick () {
            if (picking) {
                return;
            }

            /* The ladder caches its winner for the session. If that winner is
             * not the portal, re-probe before picking: a portal that was still
             * starting up when the window opened would otherwise never be
             * found, and the only other route back to a re-probe is a failed
             * pick, which the image rung never produces. One NameHasOwner call
             * is cheap enough to spend per press. */
            var source = app.ladder.selected ();
            if (source != null && source.id != "portal") {
                app.ladder.reprobe ();
                source = app.ladder.selected ();
                update_backend_hints ();
            }
            if (source == null) {
                toast ("No capture backend is available");
                return;
            }

            picking = true;
            pick_button.sensitive = false;

            var image_source = source as ImageSource;
            if (image_source != null) {
                image_source.parent = this;
            }

            try {
                Rgb? picked = yield source.pick ();
                if (picked != null) {
                    var colour = new Colour (picked);
                    colour.source_id = source.id;
                    apply (colour);
                }
            } catch (Error e) {
                /* A backend that fails is dropped, so the next attempt probes
                 * the ladder again rather than retrying something broken. */
                app.ladder.reprobe ();
                update_backend_hints ();
                toast ("Pick failed: " + e.message);
            } finally {
                picking = false;
                pick_button.sensitive = true;
            }
        }

        /* --- rendering a colour ------------------------------------------ */

        public void apply (Colour colour) {
            current = colour;

            header_swatch.set_colour (colour.rgb);
            header_hex.label = colour.hex;
            header_hex.remove_css_class ("placeholder");
            header_hex.remove_css_class (colour.wants_dark_text ? "on-dark" : "on-light");
            header_hex.add_css_class (colour.wants_dark_text ? "on-light" : "on-dark");

            for (int i = 0; i < Colour.ROW_COUNT; i++) {
                rows[i].value = colour.row_value (i);
            }

            contrast_white.update (Contrast.against_white (colour.luminance));
            contrast_black.update (Contrast.against_black (colour.luminance));

            ramp_colours = Ramp.build (colour.rgb);
            for (int i = 0; i < Ramp.LENGTH; i++) {
                ramp_swatches[i].set_colour (ramp_colours[i]);
                ramp_swatches[i].tooltip_text = Convert.to_hex (ramp_colours[i]);
            }

            formats_section.visible = true;
            contrast_section.visible = true;
            ramp_section.visible = true;

            /* A history that cannot be written is worth saying out loud: the
             * colour is on screen either way, but it will not be there after a
             * restart, and silently pretending otherwise loses the user's work. */
            if (!history.add (colour)) {
                toast ("Could not write the history file");
            }
        }

        /* CORE.md section 14: before anything is picked the header shows a
         * neutral placeholder and the format rows are absent rather than
         * showing zeros. */
        private void show_empty_state () {
            current = null;
            header_swatch.clear ();
            header_hex.label = "Nothing picked yet";
            header_hex.remove_css_class ("on-dark");
            header_hex.remove_css_class ("on-light");
            header_hex.add_css_class ("placeholder");

            formats_section.visible = false;
            contrast_section.visible = false;
            ramp_section.visible = false;
        }

        /* --- copying ------------------------------------------------------ */

        protected void toast (string message) {
            toast_label.label = message;
            toast_revealer.reveal_child = true;

            if (toast_timeout != 0) {
                Source.remove (toast_timeout);
            }
            toast_timeout = Timeout.add_seconds (2, () => {
                toast_revealer.reveal_child = false;
                toast_timeout = 0;
                return Source.REMOVE;
            });
        }

        protected void copy_text (string value, string what) {
            var display = Gdk.Display.get_default ();
            if (display == null) {
                return;
            }
            display.get_clipboard ().set_text (value);
            toast ("Copied %s — %s".printf (what, value));
        }

        private void copy_row (int index) {
            if (current == null || index < 0 || index >= Colour.ROW_COUNT) {
                return;
            }
            copy_text (current.row_value (index), Colour.row_label (index));
        }

        /* Clicking a ramp swatch copies its hex. It does not become the
         * current colour. */
        private void copy_ramp (int index) {
            if (current == null || index < 0 || index >= Ramp.LENGTH) {
                return;
            }
            string hex = Convert.to_hex (ramp_colours[index]);
            var display = Gdk.Display.get_default ();
            if (display == null) {
                return;
            }
            display.get_clipboard ().set_text (hex);
            toast ("Copied " + hex);
        }
    }
}
