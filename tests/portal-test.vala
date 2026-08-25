/* Assertions for the portal capture backend, run against tests/mock-portal.
 *
 * This covers the part of the application that cannot be reached from the
 * conversion suite: the D-Bus conversation of CORE.md section 6.1. The mock
 * answers late on purpose, so a client that subscribed after calling would
 * time out here rather than quietly pass.
 *
 * Invoked by tests/run-portal-test.sh with one expectation per run.
 */

using Aventurine;

private int failures = 0;
private int checks = 0;

private void check (bool ok, string what) {
    checks++;
    if (ok) {
        stdout.printf ("  ok    %s\n", what);
    } else {
        failures++;
        stdout.printf ("  FAIL  %s\n", what);
    }
}

private MainLoop loop;

private async void run (string expectation) {
    var source = new PortalSource ();

    check (source.id == "portal", "the backend identifies itself as 'portal'");
    check (source.label.length > 0, "the backend has a label");

    if (expectation == "expect-absent") {
        check (!source.owner_present (), "no owner is reported when the portal is absent");
        check (source.screenshot_version () == 0, "version is 0 when the portal is absent");
        check (!source.probe (), "probe fails when the portal is absent");
        loop.quit ();
        return;
    }

    check (source.owner_present (), "the portal name is owned");
    check (source.screenshot_version () == 2, "the Screenshot version is read");
    check (source.probe (), "probe succeeds");

    try {
        Rgb? picked = yield source.pick ();

        switch (expectation) {
            case "expect-cancel":
                /* Response code 1 is the user cancelling. CORE.md section 5 is
                 * explicit that this is a null answer, not an error. */
                check (picked == null, "a cancelled pick returns null");
                break;

            case "expect-error":
                check (false, "an error response should have thrown");
                break;

            default:
                check (picked != null, "a successful pick returns a colour");
                if (picked != null) {
                    Rgb colour = picked;
                    string hex = Convert.to_hex (colour);
                    check (hex == expectation,
                           "the picked colour survives the round trip (%s)".printf (hex));
                }
                break;
        }
    } catch (Error e) {
        if (expectation == "expect-error") {
            check (true, "an error response throws");
        } else {
            check (false, "unexpected error: " + e.message);
        }
    }

    /* The backend must be reusable: a second pick after the first completed
     * has to work, which it cannot if the busy guard leaked. */
    if (expectation != "expect-error") {
        try {
            yield source.pick ();
            check (true, "the backend accepts a second pick");
        } catch (Error e) {
            check (expectation == "expect-error", "second pick: " + e.message);
        }
    }

    loop.quit ();
}

public static int main (string[] args) {
    if (args.length < 2) {
        stderr.printf ("usage: portal-test <expect-absent|expect-cancel|expect-error|HEX>\n");
        return 2;
    }

    stdout.printf ("portal backend test (%s)\n", args[1]);

    loop = new MainLoop ();
    /* Started from an idle callback, not directly. The absent-portal case
     * finishes without ever yielding, and calling quit() on a loop that has
     * not started yet would leave run() blocking forever. */
    Idle.add (() => {
        run.begin (args[1]);
        return Source.REMOVE;
    });
    loop.run ();

    stdout.printf ("%d checks, %d failures\n\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
