/* --doctor. CORE.md section 7.
 *
 * Prints the ladder with a verdict per rung and exits. Every value is
 * discovered live: nothing here is cached from startup, because the point of
 * the command is to answer "what does this machine actually offer right now".
 */

namespace Aventurine {

    namespace Doctor {

        /* Labels sit in a fifteen column field, values start at column 16. */
        private void row (string label, string value) {
            stdout.printf ("%-15s%s\n", label, value);
        }

        public int run () {
            var ladder = new SourceLadder ();

            stdout.printf ("aventurine %s\n", VERSION);

            string session = Environment.get_variable ("XDG_SESSION_TYPE") ?? "unknown";
            row ("session type", session);

            var portal = ladder.portal;
            row ("portal owner", "%s %s".printf (PortalSource.BUS_NAME,
                                                 portal.owner_present () ? "present" : "absent"));

            uint32 version = portal.screenshot_version ();
            row ("Screenshot", version > 0 ? "version %u".printf (version) : "unavailable");

            foreach (var source in ladder.sources ()) {
                row ("  " + source.id, source.probe () ? "ok" : "unavailable");
            }

            /* Only mentioned when it is actually set, so the normal output
             * stays exactly as section 7 documents it. */
            string? forced = Environment.get_variable ("AVENTURINE_SOURCE");
            if (forced != null && forced != "") {
                row ("forced", forced + (ladder.forced_is_valid () ? "" : " (unknown, ignored)"));
            }

            var chosen = ladder.selected ();
            row ("selected", chosen != null ? chosen.id : "none");

            return 0;
        }
    }
}
