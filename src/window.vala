/* The single application window. */

namespace Aventurine {

    public class Window : Gtk.ApplicationWindow {

        public Window (Gtk.Application app) {
            Object (application: app);

            this.title = "Aventurine";
            this.set_default_size (420, 640);
        }
    }
}
