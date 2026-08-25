/* AVENTURINE — screen colour picker.
 * Entry point, application object and the source ladder.
 */

namespace Aventurine {

    public const string VERSION = "1.0";
    public const string APP_ID  = "io.github.sudomegas.aventurine";

    public class App : Gtk.Application {

        public App () {
            Object (application_id: APP_ID,
                    flags: ApplicationFlags.FLAGS_NONE);
        }

        protected override void activate () {
            var win = this.active_window;
            if (win == null) {
                win = new Window (this);
            }
            win.present ();
        }
    }

    private static void print_help () {
        stdout.printf ("""aventurine %s — screen colour picker

usage:
  aventurine            open the window
  aventurine --doctor   report the capture backend ladder and exit
  aventurine --version  print the version and exit
  aventurine --help     print this text and exit

environment:
  AVENTURINE_SOURCE=portal|image
                        force one capture backend, skipping probing
""", VERSION);
    }

    public static int main (string[] args) {
        for (int i = 1; i < args.length; i++) {
            switch (args[i]) {
                case "--doctor":
                    return 0;
                case "--version":
                case "-v":
                    stdout.printf ("aventurine %s\n", VERSION);
                    return 0;
                case "--help":
                case "-h":
                    print_help ();
                    return 0;
                default:
                    stderr.printf ("aventurine: unknown option '%s'\n", args[i]);
                    return 2;
            }
        }

        return new App ().run (new string[] { args[0] });
    }
}
