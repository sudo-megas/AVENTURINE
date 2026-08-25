/* The picked-colour history. CORE.md section 12.
 *
 * TOML, hand-written and hand-parsed, because the schema is three fields and a
 * parser dependency for that would be absurd. Writes are atomic: temp file in
 * the same directory, fsync, rename. A malformed file is tolerated rather than
 * fatal — what parses is kept, what does not is skipped, and nothing is
 * overwritten until the user picks something new.
 */

namespace Aventurine {

    public class HistoryEntry : Object {
        public string hex { get; set; }
        public string at { get; set; }
        public string source { get; set; }

        public HistoryEntry (string hex, string at, string source) {
            this.hex = hex;
            this.at = at;
            this.source = source;
        }

        public Rgb? to_rgb () {
            Rgb parsed;
            if (!Convert.parse_hex (hex, out parsed)) {
                return null;
            }
            return parsed;
        }

        /* "3 minutes ago" and friends, for the history list. */
        public string relative_time () {
            var when = new DateTime.from_iso8601 (at, null);
            if (when == null) {
                return at;
            }
            var now = new DateTime.now_local ();
            double seconds = now.difference (when) / (double) TimeSpan.SECOND;

            if (seconds < 0) {
                return "just now";
            }
            if (seconds < 60) {
                return "just now";
            }
            if (seconds < 3600) {
                int minutes = (int) (seconds / 60);
                return minutes == 1 ? "1 minute ago" : "%d minutes ago".printf (minutes);
            }
            if (seconds < 86400) {
                int hours = (int) (seconds / 3600);
                return hours == 1 ? "1 hour ago" : "%d hours ago".printf (hours);
            }
            if (seconds < 86400 * 30) {
                int days = (int) (seconds / 86400);
                return days == 1 ? "yesterday" : "%d days ago".printf (days);
            }
            return when.format ("%e %b %Y").strip ();
        }
    }

    public class History : Object {

        public const int CAP = 100;


        /* Newest first. */
        private GenericArray<HistoryEntry> items = new GenericArray<HistoryEntry> ();

        public signal void changed ();

        public uint size {
            get { return items.length; }
        }

        public HistoryEntry get_at (int index) {
            return items.get (index);
        }

        public static string directory () {
            return Path.build_filename (Environment.get_user_config_dir (), "aventurine");
        }

        public static string path () {
            return Path.build_filename (directory (), "history.toml");
        }

        /* --- reading ----------------------------------------------------- */

        public void load () {
            items = new GenericArray<HistoryEntry> ();

            string contents;
            try {
                if (!FileUtils.test (path (), FileTest.EXISTS)) {
                    return;
                }
                FileUtils.get_contents (path (), out contents);
            } catch (Error e) {
                /* Unreadable is treated exactly like empty: the app opens. */
                return;
            }

            string? hex = null;
            string? at = null;
            string? source = null;

            foreach (string raw in contents.split ("\n")) {
                string line = raw.strip ();

                if (line == "[[entry]]") {
                    commit (ref hex, ref at, ref source);
                    continue;
                }
                if (line == "" || line.has_prefix ("#")) {
                    continue;
                }

                int equals = line.index_of_char ('=');
                if (equals <= 0) {
                    continue;   /* not a key/value line; skip it, do not abort */
                }

                string key = line.substring (0, equals).strip ();
                string value = unquote (line.substring (equals + 1).strip ());

                /* First occurrence wins. TOML forbids duplicate keys in a
                 * table, and letting a later one overwrite means a damaged
                 * table header silently swallows the entry above it. */
                switch (key) {
                    case "hex":
                        if (hex == null) {
                            hex = value;
                        }
                        break;
                    case "at":
                        if (at == null) {
                            at = value;
                        }
                        break;
                    case "source":
                        if (source == null) {
                            source = value;
                        }
                        break;
                    default:
                        break;
                }
            }
            commit (ref hex, ref at, ref source);
        }

        /* Accepts an entry only if the hex actually parses. A row with a broken
         * colour is worse than no row. */
        private void commit (ref string? hex, ref string? at, ref string? source) {
            if (hex != null) {
                Rgb ignored;
                if (Convert.parse_hex (hex, out ignored)) {
                    items.add (new HistoryEntry (hex.up (),
                                                 at ?? "",
                                                 source ?? "unknown"));
                }
            }
            hex = null;
            at = null;
            source = null;
        }

        private static string unquote (string value) {
            string s = value.strip ();
            /* Strip a trailing inline comment only outside quotes. */
            if (s.length >= 2 && s.has_prefix ("\"") && s.last_index_of_char ('"') > 0) {
                int closing = s.last_index_of_char ('"');
                return s.substring (1, closing - 1);
            }
            return s;
        }

        /* --- writing ----------------------------------------------------- */

        public void add (Colour colour) {
            var entry = new HistoryEntry (
                colour.hex,
                new DateTime.now_local ().format ("%Y-%m-%dT%H:%M:%S%:z"),
                colour.source_id);

            items.insert (0, entry);
            while (items.length > CAP) {
                items.remove_index (items.length - 1);
            }

            save ();
            changed ();
        }

        public void remove_at (int index) {
            if (index < 0 || index >= items.length) {
                return;
            }
            items.remove_index (index);
            save ();
            changed ();
        }

        public void clear () {
            items = new GenericArray<HistoryEntry> ();
            save ();
            changed ();
        }

        public string to_toml () {
            var builder = new StringBuilder ();
            builder.append ("# aventurine history\n");
            for (int i = 0; i < items.length; i++) {
                var entry = items.get (i);
                builder.append ("\n[[entry]]\n");
                builder.append_printf ("hex = \"%s\"\n", entry.hex);
                builder.append_printf ("at = \"%s\"\n", entry.at);
                builder.append_printf ("source = \"%s\"\n", entry.source);
            }
            return builder.str;
        }

        /* Temp file in the same directory, fsync, rename. Anything less and a
         * crash mid-write costs the user their whole history. */
        public bool save () {
            DirUtils.create_with_parents (directory (), 0755);

            string target = path ();
            string temporary = target + ".tmp";

            var stream = FileStream.open (temporary, "w");
            if (stream == null) {
                return false;
            }
            if (stream.puts (to_toml ()) < 0) {
                return false;
            }
            stream.flush ();
            Posix.fsync (stream.fileno ());
            stream = null;

            return FileUtils.rename (temporary, target) == 0;
        }
    }
}
