/* A stand-in for xdg-desktop-portal's Screenshot interface.
 *
 * Enough of it to exercise src/source/portal-source.vala end to end without a
 * desktop: it owns the well-known name, reports a Screenshot version, answers
 * PickColor with a request path built the way a real portal builds it, and then
 * emits Response on that path a moment later.
 *
 * The delay matters. Answering synchronously would let a client that subscribes
 * AFTER calling still pass, which is exactly the bug CORE.md section 6.1 warns
 * about. Responding late means only a correctly ordered client succeeds.
 *
 *   --mode success   respond 0 with a colour   (default)
 *   --mode cancel    respond 1, user cancelled
 *   --mode error     respond 2, failure
 *   --colour R G B   doubles in 0..1, default 0.784314 0.588235 0.243137
 */

[DBus (name = "org.freedesktop.portal.Screenshot")]
public class MockScreenshot : Object {

    [DBus (name = "version")]
    public uint version { get { return 2; } }

    private DBusConnection conn;
    private double r;
    private double g;
    private double b;
    private uint32 code;

    /* Long enough that a client which subscribes after calling has already
     * lost the race, short enough not to slow the suite down. */
    private const uint RESPONSE_DELAY_MS = 350;

    public MockScreenshot (DBusConnection conn, double r, double g, double b, uint32 code) {
        this.conn = conn;
        this.r = r;
        this.g = g;
        this.b = b;
        this.code = code;
    }

    public ObjectPath pick_color (string parent_window,
                                  HashTable<string, Variant> options,
                                  GLib.BusName sender) throws Error {
        string token = "unset";
        Variant? handed = options.lookup ("handle_token");
        if (handed != null) {
            token = handed.get_string ();
        }

        string path = "/org/freedesktop/portal/desktop/request/%s/%s"
                      .printf (sender.substring (1).replace (".", "_"), token);
        stdout.printf ("mock: PickColor from %s token %s\n", sender, token);
        stdout.printf ("mock: request path %s\n", path);
        stdout.flush ();

        double rr = r, gg = g, bb = b;
        uint32 cc = code;
        DBusConnection c = conn;

        Timeout.add (RESPONSE_DELAY_MS, () => {
            var results = new VariantBuilder (new VariantType ("a{sv}"));
            if (cc == 0) {
                Variant[] triple = {
                    new Variant.double (rr), new Variant.double (gg), new Variant.double (bb)
                };
                results.add ("{sv}", "color", new Variant.tuple (triple));
            }
            Variant[] response = { new Variant.uint32 (cc), results.end () };
            try {
                c.emit_signal (null, path, "org.freedesktop.portal.Request",
                               "Response", new Variant.tuple (response));
                stdout.printf ("mock: Response %u emitted\n", cc);
                stdout.flush ();
            } catch (Error e) {
                stderr.printf ("mock: emit failed: %s\n", e.message);
            }
            return Source.REMOVE;
        });

        return new ObjectPath (path);
    }
}

int main (string[] args) {
    double r = 0.784314, g = 0.588235, b = 0.243137;   /* #C8963E */
    uint32 code = 0;

    for (int i = 1; i < args.length; i++) {
        if (args[i] == "--mode" && i + 1 < args.length) {
            switch (args[++i]) {
                case "success": code = 0; break;
                case "cancel":  code = 1; break;
                case "error":   code = 2; break;
                default:
                    stderr.printf ("mock: unknown mode\n");
                    return 2;
            }
        } else if (args[i] == "--colour" && i + 3 < args.length) {
            r = double.parse (args[++i]);
            g = double.parse (args[++i]);
            b = double.parse (args[++i]);
        } else {
            stderr.printf ("mock: unknown argument '%s'\n", args[i]);
            return 2;
        }
    }

    var loop = new MainLoop ();
    Bus.own_name (BusType.SESSION, "org.freedesktop.portal.Desktop",
                  BusNameOwnerFlags.NONE,
        (conn) => {
            try {
                conn.register_object ("/org/freedesktop/portal/desktop",
                                      new MockScreenshot (conn, r, g, b, code));
            } catch (Error e) {
                error ("mock: register failed: %s", e.message);
            }
        },
        () => {
            stdout.printf ("mock: owns org.freedesktop.portal.Desktop\n");
            stdout.flush ();
        },
        () => { error ("mock: could not own the name"); });

    loop.run ();
    return 0;
}
