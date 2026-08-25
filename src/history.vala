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
            if (at.strip () == "") {
                return "unknown time";
            }
            var when = new DateTime.from_iso8601 (at, null);
            if (when == null) {
                return at;
            }
            var now = new DateTime.now_local ();
            double seconds = now.difference (when) / (double) TimeSpan.SECOND;

            /* A timestamp in the future reads as now rather than as a negative
             * age. Clock skew and a config copied between machines both make
             * them, and neither is worth an error. */
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

                /* Any table header starts a new entry, including a damaged
                 * one. Treating "[[entry" as an ordinary unreadable line meant
                 * it never flushed the entry above it, so the fields below it
                 * were folded into the previous entry and silently dropped by
                 * the first-wins rule. */
                if (line.has_prefix ("[[")) {
                    commit (ref hex, ref at, ref source);
                    /* Newest first, so once the cap is full the rest of the
                     * file is older than anything that would survive it. A
                     * tampered or oversized file therefore costs bounded work
                     * on the startup path instead of parsing megabytes. */
                    if (items.length >= CAP) {
                        return;
                    }
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
                string? value = unquote (line.substring (equals + 1).strip ());
                if (value == null) {
                    continue;   /* unreadable value: skip the field, keep the entry */
                }

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

            /* CORE.md section 12 caps the history at 100 with the oldest
             * evicted first. A file holding more — hand edited, or written by
             * some later version — is trimmed here, so the cap holds in the
             * window too and not only after the next pick. The file itself is
             * left alone until the user picks something new. */
            while (items.length > CAP) {
                items.remove_index (items.length - 1);
            }
        }

        /* Accepts an entry only if the hex actually parses. A row with a broken
         * colour is worse than no row. */
        private void commit (ref string? hex, ref string? at, ref string? source) {
            if (hex != null) {
                Rgb parsed;
                if (Convert.parse_hex (hex, out parsed)) {
                    /* Normalised, not stored as written. A hand-edited file may
                     * hold "abc" or "  #A1B2C3  "; both are valid input, and
                     * both would otherwise reach the exporters verbatim and
                     * produce a CSS custom property that is not a colour. */
                    items.add (new HistoryEntry (Convert.to_hex (parsed),
                                                 at ?? "",
                                                 source ?? "unknown"));
                }
            }
            hex = null;
            at = null;
            source = null;
        }

        /* Returns null for a value that is not readable, so the caller can
         * skip the field rather than store something half parsed. */
        private static string? unquote (string value) {
            string s = value.strip ();

            if (s.has_prefix ("\"")) {
                /* The FIRST closing quote ends the value. Taking the last one
                 * swallowed any quote inside a trailing comment, and an
                 * unterminated value kept its opening quote and was written
                 * back out as invalid TOML. */
                int closing = s.index_of_char ('"', 1);
                if (closing < 0) {
                    return null;
                }
                return s.substring (1, closing - 1);
            }

            /* A bare value may carry a trailing comment. A hash in the first
             * position is not one: that is how an unquoted hex looks. */
            int hash = s.index_of_char ('#', 1);
            if (hash > 0) {
                s = s.substring (0, hash).strip ();
            }
            return s;
        }

        /* --- writing ----------------------------------------------------- */

        public bool add (Colour colour) {
            var entry = new HistoryEntry (
                colour.hex,
                new DateTime.now_local ().format ("%Y-%m-%dT%H:%M:%S%:z"),
                colour.source_id);

            items.insert (0, entry);
            while (items.length > CAP) {
                items.remove_index (items.length - 1);
            }

            bool written = save ();
            changed ();
            return written;
        }

        public bool remove_at (int index) {
            if (index < 0 || index >= items.length) {
                return true;
            }
            items.remove_index (index);
            bool written = save ();
            changed ();
            return written;
        }

        public bool clear () {
            items = new GenericArray<HistoryEntry> ();
            bool written = save ();
            changed ();
            return written;
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

            /* Every step is checked. puts() on a small write usually only
             * fills the stdio buffer and reports success even when the disk is
             * full; the real error does not surface until flush(). Ignoring it
             * meant renaming a truncated file over a good one and reporting
             * success, which silently destroyed history entries. */
            bool ok = stream.puts (to_toml ()) >= 0
                   && stream.flush () == 0
                   && Posix.fsync (stream.fileno ()) == 0;

            /* Closes the stream, before the rename either way. */
            stream = null;

            if (!ok) {
                FileUtils.unlink (temporary);
                return false;
            }
            if (FileUtils.rename (temporary, target) != 0) {
                FileUtils.unlink (temporary);
                return false;
            }
            return true;
        }
    }
}
