/* AVENTURINE — screen colour picker.
 * Entry point, application object and the source ladder.
 */

namespace Aventurine {

    public const string VERSION      = "1.0";
    public const string APP_ID       = "io.github.sudomegas.aventurine";
    public const string RELEASE_DATE = "2026-08-25";
    public const string SOURCE_URL   = "https://github.com/sudo-megas/AVENTURINE";

    /* The ordered list of capture backends. CORE.md section 5.
     *
     * probe() runs on each in order at startup, the first to answer is cached
     * for the session, and a pick() that fails drops the cache so the next
     * attempt probes again. Moving between desktops changes which rung answers
     * and nothing else in the application notices.
     */
    public class SourceLadder : Object {

        private ColourSource[] rungs;
        private ColourSource? cached = null;
        private bool probed = false;

        /* CORE.md section 7: the only environment variable the app reads. */
        private string? forced;

        public PortalSource portal { get; private set; }

        public SourceLadder () {
            portal = new PortalSource ();
            rungs = { portal, new ImageSource () };

            string? requested = Environment.get_variable ("AVENTURINE_SOURCE");
            forced = (requested != null && requested != "") ? requested : null;
        }

        public unowned ColourSource[] sources () {
            return rungs;
        }

        public bool forced_is_valid () {
            if (forced == null) {
                return false;
            }
            foreach (var rung in rungs) {
                if (rung.id == forced) {
                    return true;
                }
            }
            return false;
        }

        /* The backend in use, or null when nothing passed. Forcing skips
         * probing entirely, which is the point of it. */
        public ColourSource? selected () {
            if (forced != null) {
                foreach (var rung in rungs) {
                    if (rung.id == forced) {
                        return rung;
                    }
                }
                /* An unrecognised value falls through to normal probing rather
                 * than leaving the app with no backend at all. */
            }

            if (!probed) {
                probed = true;
                cached = null;
                foreach (var rung in rungs) {
                    if (rung.probe ()) {
                        cached = rung;
                        break;
                    }
                }
            }
            return cached;
        }

        /* Drops the cached winner so the next selected() probes the ladder
         * again. It does not blacklist anything: a rung that still probes
         * clean is chosen again, which is what CORE.md section 5 asks for. */
        public void reprobe () {
            probed = false;
            cached = null;
        }

        public ColourSource? by_id (string wanted) {
            foreach (var rung in rungs) {
                if (rung.id == wanted) {
                    return rung;
                }
            }
            return null;
        }
    }

    public class App : Gtk.Application {

        public SourceLadder ladder { get; private set; }

        private Theme theme;

        public App () {
            Object (application_id: APP_ID,
                    flags: ApplicationFlags.FLAGS_NONE);
            ladder = new SourceLadder ();
        }

        protected override void startup () {
            base.startup ();
            /* Follow the desktop's light or dark preference, and keep
             * following it: CORE.md section 15. */
            theme = new Theme ();
            theme.start ();
        }

        protected override void shutdown () {
            /* Theme cannot tear itself down in a destructor: its D-Bus
             * subscription holds a strong reference to it, so the destructor
             * would have to run to release the reference that keeps it from
             * running. Teardown is explicit for that reason. */
            if (theme != null) {
                theme.stop ();
            }
            base.shutdown ();
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
        /* POSIX allows argc to be 0, in which case there is no argv[0] to
         * read and nothing to hand to GApplication. */
        if (args.length < 1) {
            return 2;
        }

        for (int i = 1; i < args.length; i++) {
            switch (args[i]) {
                case "--doctor":
                    return Doctor.run ();
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
