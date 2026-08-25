/* Assertions for the pure-logic units: conversions, contrast, ramp, names.
 *
 * Reference values are published constants, not values this implementation
 * produced. If a change here starts failing, the conversion is wrong, not the
 * expectation.
 */

using Aventurine;

private int failures = 0;
private int checks = 0;

private void check (bool ok, string what) {
    checks++;
    if (!ok) {
        failures++;
        stdout.printf ("  FAIL  %s\n", what);
    }
}

private void near (double got, double want, double tol, string what) {
    checks++;
    if (Math.fabs (got - want) > tol) {
        failures++;
        stdout.printf ("  FAIL  %s: got %.10f want %.10f (tolerance %g)\n",
                       what, got, want, tol);
    }
}

private void same (string got, string want, string what) {
    checks++;
    if (got != want) {
        failures++;
        stdout.printf ("  FAIL  %s: got \"%s\" want \"%s\"\n", what, got, want);
    }
}

private Rgb hex (string s) {
    Rgb c;
    if (!Convert.parse_hex (s, out c)) {
        failures++;
        stdout.printf ("  FAIL  unparseable hex literal in test: %s\n", s);
    }
    return c;
}

private void section (string name) {
    stdout.printf ("%s\n", name);
}

/* --- 1. luminance ---------------------------------------------------- */

private void test_luminance () {
    section ("luminance");
    near (Convert.luminance (hex ("#FFFFFF")), 1.0, 1e-12, "white luminance is exactly 1");
    near (Convert.luminance (hex ("#000000")), 0.0, 1e-12, "black luminance is exactly 0");
    /* Mid grey. If this reads about 0.2159 the gamma function is on the right
     * side; if it reads about 0.5 it is being skipped entirely. */
    near (Convert.luminance (hex ("#808080")), 0.2158605001, 1e-9, "#808080 luminance");
    near (Convert.luminance (hex ("#808080")), 0.2159, 1e-4, "#808080 luminance to four places");

    /* Luminance is monotonic in each channel. */
    check (Convert.luminance (hex ("#00FF00")) > Convert.luminance (hex ("#FF0000")),
           "green is more luminous than red");
    check (Convert.luminance (hex ("#FF0000")) > Convert.luminance (hex ("#0000FF")),
           "red is more luminous than blue");
}

/* --- 2. CIELAB at D65 ------------------------------------------------ */

private void test_lab () {
    section ("CIELAB and LCH");
    Lab red = Convert.to_lab (hex ("#FF0000"));
    near (red.l, 53.2408, 1e-3, "sRGB red L*");
    near (red.a, 80.0925, 1e-3, "sRGB red a*");
    near (red.b, 67.2032, 1e-3, "sRGB red b*");

    Lab white = Convert.to_lab (hex ("#FFFFFF"));
    /* The published sRGB->XYZ rows sum to 1.0000001, not 1, so white lands
     * on L* 100.000004. CORE.md section 8.3 is transcribed exactly rather
     * than renormalised, so this tolerance is the matrix, not slop. */
    near (white.l, 100.0, 1e-4, "white L* is 100");
    near (white.a, 0.0, 1e-3, "white a* is 0");
    near (white.b, 0.0, 1e-3, "white b* is 0");

    Lab black = Convert.to_lab (hex ("#000000"));
    near (black.l, 0.0, 1e-12, "black L* is 0");

    /* LCH is the polar form of the same numbers. */
    Lch lch = Convert.to_lch (hex ("#FF0000"));
    near (lch.l, red.l, 1e-12, "LCH lightness matches LAB");
    near (lch.c, Math.sqrt (red.a * red.a + red.b * red.b), 1e-12, "LCH chroma");
    check (lch.h >= 0.0 && lch.h < 360.0, "LCH hue is normalised to 0..360");

    /* Hue must wrap into the positive range, not come back negative. */
    Lch blue = Convert.to_lch (hex ("#0000FF"));
    check (blue.h >= 0.0 && blue.h < 360.0, "blue LCH hue is normalised");
}

/* --- 3. OKLab and OKLCH ---------------------------------------------- */

private void test_oklab () {
    section ("OKLab and OKLCH");
    Lch white = Convert.to_oklch (hex ("#FFFFFF"));
    near (white.l, 1.0, 1e-6, "white OKLCH lightness is 1");
    near (white.c, 0.0, 1e-6, "white OKLCH chroma is 0");

    Lch black = Convert.to_oklch (hex ("#000000"));
    near (black.l, 0.0, 1e-12, "black OKLCH lightness is 0");

    /* Grey is achromatic in OKLab. */
    Lab grey = Convert.to_oklab (hex ("#808080"));
    near (grey.a, 0.0, 1e-6, "mid grey OKLab a is 0");
    near (grey.b, 0.0, 1e-6, "mid grey OKLab b is 0");
}

/* --- 4. round trip --------------------------------------------------- */

private void test_round_trip () {
    section ("sRGB -> OKLCH -> sRGB round trip, 20 colours");
    string[] samples = {
        "#000000", "#FFFFFF", "#FF0000", "#00FF00", "#0000FF",
        "#FFFF00", "#00FFFF", "#FF00FF", "#808080", "#A1B2C3",
        "#4E6E5D", "#123456", "#FEDCBA", "#0F0F0F", "#F0F0F0",
        "#2E8B57", "#B0C4DE", "#8B0000", "#191970", "#DEB887"
    };
    foreach (string s in samples) {
        Rgb original = hex (s);
        Rgb back = Convert.from_oklch (Convert.to_oklch (original));
        near (back.r, original.r, 1e-6, s + " round trip red");
        near (back.g, original.g, 1e-6, s + " round trip green");
        near (back.b, original.b, 1e-6, s + " round trip blue");
        /* The hex string itself must survive unchanged. */
        same (Convert.to_hex (back), s, s + " round trip hex");
    }
}

/* --- 5. hex ---------------------------------------------------------- */

private void test_hex () {
    section ("hex");
    same (Convert.to_hex (hex ("#a1b2c3")), "#A1B2C3", "hex output is uppercase");
    same (Convert.to_hex (hex ("#abc")), "#AABBCC", "three-digit hex expands");
    same (Convert.to_hex (hex ("A1B2C3")), "#A1B2C3", "hash is optional on input");
    same (Convert.to_hex (Convert.from_bytes (161, 178, 195)), "#A1B2C3", "bytes to hex");

    Rgb ignored;
    check (!Convert.parse_hex ("#12345", out ignored), "five digits is rejected");
    check (!Convert.parse_hex ("#GGGGGG", out ignored), "non-hex digits are rejected");
    check (!Convert.parse_hex ("", out ignored), "empty string is rejected");
    check (Convert.parse_hex ("  #FFF  ", out ignored), "surrounding space is tolerated");
}

/* --- 6. the hexcone spaces ------------------------------------------- */

private void test_hexcone () {
    section ("HSL, HSV, HWB, CMYK");
    Rgb c = hex ("#A1B2C3");

    Hsl hsl = Convert.to_hsl (c);
    near (hsl.h, 210.0, 0.5, "#A1B2C3 HSL hue");
    near (hsl.s * 100.0, 22.0, 0.5, "#A1B2C3 HSL saturation");
    near (hsl.l * 100.0, 69.8, 0.5, "#A1B2C3 HSL lightness");

    Hsv hsv = Convert.to_hsv (c);
    near (hsv.h, 210.0, 0.5, "#A1B2C3 HSV hue");
    near (hsv.s * 100.0, 17.4, 0.5, "#A1B2C3 HSV saturation");
    near (hsv.v * 100.0, 76.5, 0.5, "#A1B2C3 HSV value");

    Hwb hwb = Convert.to_hwb (c);
    near (hwb.w * 100.0, 63.1, 0.5, "#A1B2C3 HWB whiteness");
    near (hwb.b * 100.0, 23.5, 0.5, "#A1B2C3 HWB blackness");

    Cmyk cmyk = Convert.to_cmyk (c);
    near (cmyk.c * 100.0, 17.4, 0.5, "#A1B2C3 CMYK cyan");
    near (cmyk.m * 100.0, 8.7, 0.5, "#A1B2C3 CMYK magenta");
    near (cmyk.y * 100.0, 0.0, 0.5, "#A1B2C3 CMYK yellow");
    near (cmyk.k * 100.0, 23.5, 0.5, "#A1B2C3 CMYK key");

    /* Pure black: the undefined channels are zero, not NaN. */
    Cmyk black = Convert.to_cmyk (hex ("#000000"));
    near (black.c, 0.0, 1e-12, "black CMYK cyan is 0 not NaN");
    near (black.m, 0.0, 1e-12, "black CMYK magenta is 0 not NaN");
    near (black.y, 0.0, 1e-12, "black CMYK yellow is 0 not NaN");
    near (black.k, 1.0, 1e-12, "black CMYK key is 1");

    /* Achromatic input has zero saturation and a defined hue. */
    Hsl grey = Convert.to_hsl (hex ("#808080"));
    near (grey.s, 0.0, 1e-12, "grey HSL saturation is 0");
    near (grey.h, 0.0, 1e-12, "grey HSL hue is 0 not NaN");

    /* Red sits at hue 0, and the wrap does not push it to 360. */
    near (Convert.to_hsl (hex ("#FF0000")).h, 0.0, 1e-9, "red hue is 0");
    near (Convert.to_hsl (hex ("#00FF00")).h, 120.0, 1e-9, "green hue is 120");
    near (Convert.to_hsl (hex ("#0000FF")).h, 240.0, 1e-9, "blue hue is 240");
    /* Magenta exercises the negative branch of the red sector. */
    near (Convert.to_hsl (hex ("#FF00FF")).h, 300.0, 1e-9, "magenta hue is 300");
}

/* --- 7. linear RGB --------------------------------------------------- */

private void test_linear () {
    section ("linear RGB");
    Rgb lin = Convert.to_linear (hex ("#A1B2C3"));
    near (lin.r, 0.356, 1e-3, "#A1B2C3 linear red");
    near (lin.g, 0.445, 1e-3, "#A1B2C3 linear green");
    near (lin.b, 0.546, 1e-3, "#A1B2C3 linear blue");

    /* Both halves of the piecewise curve, each exercised on its own side of
     * the threshold and checked against an independently written formula.
     * Comparing linearise(0.04045) against 0.04045/12.92 was a tautology: it
     * restates the branch it is testing, and survived replacing the entire
     * power branch with a constant. */
    near (Convert.linearise (0.02), 0.02 / 12.92, 1e-12,
          "below the threshold, linearise is the linear branch");
    near (Convert.linearise (0.04046), Math.pow ((0.04046 + 0.055) / 1.055, 2.4), 1e-12,
          "above the threshold, linearise is the power branch");
    near (Convert.encode (0.002), 0.002 * 12.92, 1e-12,
          "below the threshold, encode is the linear branch");
    near (Convert.encode (0.005), 1.055 * Math.pow (0.005, 1.0 / 2.4) - 0.055, 1e-12,
          "above the threshold, encode is the power branch");

    /* The two branches very nearly meet. They do not meet exactly, because
     * 0.04045 is a rounded form of the true crossover (0.0404482...), so the
     * published sRGB constants leave a step of about 2.3e-9 at the join. That
     * is the spec's discontinuity, transcribed faithfully per CORE.md 8.1,
     * not an error here. */
    near (Convert.linearise (0.04045), Math.pow ((0.04045 + 0.055) / 1.055, 2.4), 1e-8,
          "the two gamma branches meet at the threshold to within the spec's own step");
    near (Convert.encode (Convert.linearise (0.5)), 0.5, 1e-12, "encode undoes linearise");
    near (Convert.linearise (Convert.encode (0.5)), 0.5, 1e-12, "linearise undoes encode");
}

/* --- 8. contrast ----------------------------------------------------- */

private void test_contrast () {
    section ("WCAG contrast");
    double white = Convert.luminance (hex ("#FFFFFF"));
    double black = Convert.luminance (hex ("#000000"));
    double grey  = Convert.luminance (hex ("#808080"));

    near (Contrast.ratio (white, black), 21.0, 1e-9, "white on black is 21:1");
    near (Contrast.ratio (white, white), 1.0, 1e-12, "a colour against itself is 1:1");
    near (Contrast.ratio (black, white), 21.0, 1e-9, "ratio is symmetric");

    ContrastResult vs_white = Contrast.against_white (grey);
    near (vs_white.ratio, 3.9494, 1e-3, "#808080 against white");
    check (!vs_white.aa_normal, "#808080 on white fails AA normal");
    check (vs_white.aa_large, "#808080 on white passes AA large");
    check (!vs_white.aaa_normal, "#808080 on white fails AAA normal");
    check (!vs_white.aaa_large, "#808080 on white fails AAA large");

    ContrastResult vs_black = Contrast.against_black (grey);
    near (vs_black.ratio, 5.3172, 1e-3, "#808080 against black");
    check (vs_black.aa_normal, "#808080 on black passes AA normal");
    check (vs_black.aaa_large, "#808080 on black passes AAA large");
    check (!vs_black.aaa_normal, "#808080 on black fails AAA normal");

    /* Black text on white passes everything. */
    ContrastResult best = Contrast.against_white (black);
    check (best.aa_normal && best.aa_large && best.aaa_normal && best.aaa_large,
           "black on white passes all four");
}

/* --- 9. ramp --------------------------------------------------------- */

private void test_ramp () {
    section ("tint and shade ramp");
    Rgb base_colour = hex ("#A1B2C3");
    Rgb[] strip = Ramp.build (base_colour);

    check (strip.length == 11, "the strip is eleven swatches");
    /* Indexed literally, not via Ramp.MIDDLE: using the constant to check
     * itself cannot detect an off-by-one in the constant. */
    same (Convert.to_hex (strip[5]), "#A1B2C3", "the picked colour is at index 5");
    check (Ramp.MIDDLE == 5, "the middle constant is 5");

    /* Lightness rises monotonically across the strip. */
    bool rising = true;
    for (int i = 1; i < strip.length; i++) {
        if (Convert.to_oklch (strip[i]).l < Convert.to_oklch (strip[i - 1]).l - 1e-9) {
            rising = false;
        }
    }
    check (rising, "lightness rises from darkest to lightest");

    /* Hue is held on every swatch the gamut clamp did not touch. Where a
     * swatch does leave sRGB, section 8.7 clamps per channel and accepts the
     * hue shift that causes; that is the documented v1.0 trade-off, not a bug.
     * A swatch that needed clamping is one sitting exactly on a channel bound. */
    double base_hue = Convert.to_oklch (base_colour).h;
    bool hue_held = true;
    int clamped = 0;
    for (int i = 0; i < strip.length; i++) {
        bool on_bound = strip[i].r <= 0.0 || strip[i].r >= 1.0
                     || strip[i].g <= 0.0 || strip[i].g >= 1.0
                     || strip[i].b <= 0.0 || strip[i].b >= 1.0;
        if (on_bound) {
            clamped++;
            continue;
        }
        Lch s = Convert.to_oklch (strip[i]);
        double delta = Math.fabs (s.h - base_hue);
        if (delta > 180.0) {
            delta = 360.0 - delta;   /* the short way round the wheel */
        }
        if (s.c > 1e-6 && delta > 1.0) {
            hue_held = false;
        }
    }
    check (hue_held, "hue is held on every unclamped swatch");
    check (clamped < strip.length, "not every swatch is clamped");

    /* Every swatch is inside sRGB after the clamp. */
    bool in_gamut = true;
    for (int i = 0; i < strip.length; i++) {
        if (strip[i].r < 0.0 || strip[i].r > 1.0
            || strip[i].g < 0.0 || strip[i].g > 1.0
            || strip[i].b < 0.0 || strip[i].b > 1.0) {
            in_gamut = false;
        }
    }
    check (in_gamut, "every swatch is clamped into sRGB");

    /* A fully saturated colour is the case most likely to leave the gamut. */
    Rgb[] hot = Ramp.build (hex ("#FF0000"));
    bool hot_ok = true;
    for (int i = 0; i < hot.length; i++) {
        if (hot[i].r < 0.0 || hot[i].r > 1.0 || hot[i].g < 0.0
            || hot[i].g > 1.0 || hot[i].b < 0.0 || hot[i].b > 1.0) {
            hot_ok = false;
        }
    }
    check (hot_ok, "a saturated ramp stays inside sRGB");
    check (hot.length == 11, "a saturated ramp is still eleven swatches");
}

/* --- 10. names ------------------------------------------------------- */

private void test_names () {
    section ("named colours");
    check (Names.CSS_COUNT == 148, "the CSS table has 148 entries");
    check (Names.XKCD_COUNT == 949, "the xkcd table has 949 entries");

    /* An exact table colour must name itself. */
    same (Names.nearest_css (hex ("#B0C4DE")), "lightsteelblue", "exact CSS match names itself");
    same (Names.nearest_css (hex ("#FF0000")), "red", "pure red is red");
    same (Names.nearest_css (hex ("#000000")), "black", "pure black is black");
    same (Names.nearest_css (hex ("#663399")), "rebeccapurple", "rebeccapurple is present");
    same (Names.exact_css (hex ("#FFFFFF")), "white", "exact lookup finds white");

    /* A near miss must land on the neighbour, not somewhere across the wheel. */
    same (Names.nearest_css (hex ("#B0C4DF")), "lightsteelblue", "a one-step miss still names lightsteelblue");
    /* The xkcd survey's own "red" is #E50000, so pure #FF0000 is genuinely
     * nearer to "fire engine red" (#FE0002). Both directions are pinned so a
     * regression in the table or the metric shows up here. */
    same (Names.nearest_xkcd (hex ("#E50000")), "red", "xkcd names its own red");
    same (Names.nearest_xkcd (hex ("#FF0000")), "fire engine red", "pure red is nearest fire engine red");
    same (Names.nearest_xkcd (hex ("#9DBCD4")), "light grey blue", "xkcd exact match names itself");

    /* Every lookup returns something non-empty for a spread of inputs. */
    string[] spread = { "#000000", "#FFFFFF", "#A1B2C3", "#4E6E5D", "#123456", "#DEB887" };
    foreach (string s in spread) {
        check (Names.nearest_css (hex (s)).length > 0, "CSS name for " + s);
        check (Names.nearest_xkcd (hex (s)).length > 0, "xkcd name for " + s);
    }
}

/* --- 11. the Colour wrapper ------------------------------------------ */

private void test_colour () {
    section ("Colour");
    var c = Colour.from_hex ("#A1B2C3");
    check (c != null, "Colour parses a hex string");
    same (c.hex, "#A1B2C3", "Colour reports uppercase hex");
    check (c.red == 161 && c.green == 178 && c.blue == 195, "Colour reports byte channels");
    near (c.luminance, 0.4336, 1e-3, "Colour luminance");

    /* Comparing a getter to itself passes for any stale or mis-keyed cache.
     * Compare against a freshly computed value instead, and read the getters
     * in an interleaved order so a cache keyed onto the wrong flag shows up. */
    near (c.luminance, Convert.luminance (c.rgb), 1e-12, "cached luminance matches a fresh one");
    var fresh = Colour.from_hex ("#A1B2C3");
    check (fresh.oklch.h == c.oklch.h, "OKLCH hue is cached independently of LCH");
    near (c.lch.l, Convert.to_lch (c.rgb).l, 1e-12, "cached LCH matches a fresh one");
    near (c.oklch.c, Convert.to_oklch (c.rgb).c, 1e-12, "cached OKLCH matches a fresh one");
    same (c.hex, Convert.to_hex (c.rgb), "cached hex matches a fresh one");

    check (Colour.from_hex ("nonsense") == null, "Colour rejects a bad string");

    /* The text-colour switch of CORE.md section 14. */
    check (Colour.from_hex ("#FFFFFF").wants_dark_text, "white wants dark text");
    check (!Colour.from_hex ("#000000").wants_dark_text, "black wants light text");
}

/* --- 12. the fourteen format rows ------------------------------------ */

private void test_rows () {
    section ("format rows (CORE.md section 9)");
    var c = Colour.from_hex ("#A1B2C3");
    check (Colour.ROW_COUNT == 14, "there are fourteen rows");

    same (c.row_value (0),  "#A1B2C3",                   "row 1 HEX");
    same (c.row_value (1),  "rgb(161, 178, 195)",        "row 2 RGB");
    same (c.row_value (2),  "rgb(63.1%, 69.8%, 76.5%)",  "row 3 RGB percent");
    same (c.row_value (3),  "hsl(210, 22%, 70%)",        "row 4 HSL");
    same (c.row_value (4),  "hsv(210, 17%, 76%)",        "row 5 HSV");
    same (c.row_value (5),  "hwb(210 63% 24%)",          "row 6 HWB");
    same (c.row_value (6),  "cmyk(17%, 9%, 0%, 24%)",    "row 7 CMYK");
    same (c.row_value (7),  "0.356 0.445 0.546",         "row 8 linear RGB");
    same (c.row_value (8),  "lab(71.80 -2.29 -10.62)",   "row 9 LAB");
    same (c.row_value (9),  "lch(71.80 10.86 257.8)",    "row 10 LCH");
    same (c.row_value (10), "oklch(0.756 0.031 248.2)",  "row 11 OKLCH");
    same (c.row_value (11), "0.4336",                    "row 12 luminance");
    same (c.row_value (12), "darkgray",                  "row 13 nearest CSS name");
    same (c.row_value (13), "light grey blue",           "row 14 nearest xkcd name");

    /* Every row must have a label and a non-empty value for any colour. */
    foreach (string s in new string[] { "#000000", "#FFFFFF", "#FF0000" }) {
        var probe = Colour.from_hex (s);
        for (int i = 0; i < Colour.ROW_COUNT; i++) {
            check (Colour.row_label (i).length > 0, "row %d has a label".printf (i + 1));
            check (probe.row_value (i).length > 0, "row %d has a value for %s".printf (i + 1, s));
        }
    }

    /* Black is the row set most likely to produce -0.00 or NaN. */
    var black = Colour.from_hex ("#000000");
    same (black.row_value (8),  "lab(0.00 0.00 0.00)",      "black LAB is all zeroes");
    /* Black has a* and b* of exactly +0.0, so it cannot catch a missing
     * negative-zero fold. This one has a a* that rounds to zero from below. */
    same (Colour.from_hex ("#003C65").row_value (8), "lab(24.23 0.00 -28.88)",
          "a negative a* that rounds to zero prints as 0.00, not -0.00");
    same (black.row_value (11), "0.0000",                   "black luminance");
    same (black.row_value (6),  "cmyk(0%, 0%, 0%, 100%)",   "black CMYK");
}

/* --- 13. history ------------------------------------------------------ */

private string test_config_dir () {
    return Path.build_filename (Environment.get_tmp_dir (), "aventurine-test-config");
}

private void write_history_file (string contents) {
    string dir = Path.build_filename (test_config_dir (), "aventurine");
    DirUtils.create_with_parents (dir, 0755);
    try {
        FileUtils.set_contents (Path.build_filename (dir, "history.toml"), contents);
    } catch (Error e) {
        failures++;
        stdout.printf ("  FAIL  could not stage a history file: %s\n", e.message);
    }
}

private void test_history () {
    section ("history");

    /* A file with several kinds of damage in it. What parses is kept, what
     * does not is skipped, and the app must not treat any of it as fatal. */
    write_history_file ("""# aventurine history
this line is not a key/value pair at all

[[entry]]
hex = "#A1B2C3"
at = "2026-08-25T14:03:11+03:00"
source = "portal"

[[entry]]
hex = "#ZZZZZZ"
at = "unparseable colour, must be skipped"
source = "portal"

[[entry]]
hex = "#4E6E5D"
at = "2026-08-24T09:12:00+03:00"

[[entry
hex = "#123456"
garbage ===== nonsense
[[entry]]
hex = "#DEB887"
at = "2026-08-23T08:00:00+03:00"
source = "image"
""");

    var history = new History ();
    history.load ();

    check (history.size == 3, "three of the five entries survive a malformed file");
    if (history.size == 3) {
        same (history.get_at (0).hex, "#A1B2C3", "first surviving entry");
        same (history.get_at (1).hex, "#4E6E5D", "second surviving entry");
        same (history.get_at (2).hex, "#DEB887", "third surviving entry");
        /* A missing source field must not lose the entry. */
        same (history.get_at (1).source, "unknown", "a missing source becomes unknown");
        same (history.get_at (0).source, "portal", "the source field is kept");
    }

    /* The written form must be exactly the schema of CORE.md section 12. */
    string toml = history.to_toml ();
    check (toml.contains ("[[entry]]"), "entries are written as [[entry]] tables");
    check (toml.contains ("hex = \"#A1B2C3\""), "hex is written quoted and uppercase");
    check (toml.contains ("source = \"portal\""), "source is written");

    /* A save must round trip through the parser unchanged. */
    check (history.save (), "history saves");
    var reloaded = new History ();
    reloaded.load ();
    check (reloaded.size == 3, "a saved history reloads with the same count");
    if (reloaded.size == 3) {
        same (reloaded.get_at (0).hex, "#A1B2C3", "round trip keeps order");
        same (reloaded.get_at (0).at, "2026-08-25T14:03:11+03:00", "round trip keeps the timestamp");
    }

    /* The cap evicts oldest first. */
    var big = new StringBuilder ();
    for (int i = 0; i < 130; i++) {
        big.append_printf ("[[entry]]\nhex = \"#%06X\"\nat = \"\"\nsource = \"image\"\n\n", i);
    }
    write_history_file (big.str);
    var capped = new History ();
    capped.load ();
    check (capped.size == 130, "load itself does not cap");

    capped.add (Colour.from_hex ("#FFFFFF"));
    check (capped.size == History.CAP, "adding past the cap evicts down to 100");
    same (capped.get_at (0).hex, "#FFFFFF", "the newest entry is first");

    /* Deleting and clearing. */
    capped.remove_at (0);
    check (capped.size == History.CAP - 1, "removing an entry drops the count");
    capped.clear ();
    check (capped.size == 0, "clear empties the history");

    /* An absent file is not an error. */
    FileUtils.remove (Path.build_filename (test_config_dir (), "aventurine", "history.toml"));
    var fresh = new History ();
    fresh.load ();
    check (fresh.size == 0, "a missing history file loads as empty");
}

/* --- 14. export ------------------------------------------------------- */

private void test_export () {
    section ("export (CORE.md section 13)");

    write_history_file ("""[[entry]]
hex = "#A1B2C3"
at = "2026-08-25T14:03:11+03:00"
source = "portal"

[[entry]]
hex = "#4E6E5D"
at = "2026-08-24T09:12:00+03:00"
source = "portal"
""");
    var history = new History ();
    history.load ();

    string gpl = Export.to_gpl (history);
    check (gpl.has_prefix ("GIMP Palette\nName: AVENTURINE\nColumns: 8\n#\n"),
           "the .gpl header is exactly as specified");
    check (gpl.contains ("161 178 195\t#A1B2C3"), "a .gpl row is 'r g b<tab>hex'");
    check (gpl.contains ("#4E6E5D"), "every entry is exported");

    string css = Export.to_css (history);
    check (css.has_prefix (":root {\n"), "the .css opens with :root");
    check (css.contains ("  --aventurine-1: #A1B2C3;"), "the first custom property");
    check (css.contains ("  --aventurine-2: #4E6E5D;"), "the second custom property");
    check (css.has_suffix ("}\n"), "the .css closes the block");

    /* The suffix picks the format. */
    check (Export.render (history, "palette.css").has_prefix (":root"), ".css chooses CSS");
    check (Export.render (history, "palette.gpl").has_prefix ("GIMP"), ".gpl chooses GIMP");
    check (Export.render (history, "palette").has_prefix ("GIMP"), "no suffix defaults to GIMP");
    check (Export.render (history, "PALETTE.CSS").has_prefix (":root"), "the suffix test is case insensitive");
}

/* --- 15. regressions found by audit -------------------------------------- */

private void test_regressions () {
    section ("regressions");

    /* An achromatic colour has no hue. The published matrices do not sum to
     * exactly 1, so a grey lands a hair off the neutral axis and atan2 used to
     * turn that residue into a confident, meaningless angle printed next to a
     * chroma of 0.00. */
    same (Colour.from_hex ("#FFFFFF").row_value (9),  "lch(100.00 0.00 0.0)",
          "white has no LCH hue");
    same (Colour.from_hex ("#FFFFFF").row_value (10), "oklch(1.000 0.000 0.0)",
          "white has no OKLCH hue");
    same (Colour.from_hex ("#808080").row_value (10), "oklch(0.600 0.000 0.0)",
          "mid grey has no OKLCH hue");
    near (Convert.to_lch (hex ("#404040")).h, 0.0, 1e-12, "a dark grey has hue 0");

    /* Hue is normalised to [0,360) and then rounded, and rounding could push
     * it back to 360 — the same angle as 0, printed as though it were not. */
    same (Colour.from_hex ("#FF0001").row_value (3), "hsl(0, 100%, 50%)",
          "a hue that rounds up wraps to 0, not 360");
    same (Colour.from_hex ("#FF0001").row_value (4), "hsv(0, 100%, 100%)",
          "HSV hue wraps too");
    same (Colour.from_hex ("#FF0001").row_value (5), "hwb(0 0% 0%)",
          "HWB hue wraps too");
    check (!Colour.from_hex ("#200B12").row_value (9).contains ("360.0"),
           "LCH hue never prints 360");
    check (!Colour.from_hex ("#251218").row_value (10).contains ("360.0"),
           "OKLCH hue never prints 360");

    /* K at 100% means "no ink but black", so it must not sit beside a nonzero
     * cyan. Only a colour whose K is exactly 1 may print 100%. */
    same (Colour.from_hex ("#000001").row_value (6), "cmyk(100%, 100%, 0%, 99%)",
          "a near-black does not claim K of 100%");
    same (Colour.from_hex ("#000000").row_value (6), "cmyk(0%, 0%, 0%, 100%)",
          "true black does claim K of 100%");

    /* A non-finite channel used to cast to INT_MIN and escape into every row,
     * including the hex written to the history file. */
    check (!Convert.is_valid ({ double.NAN, 0.5, 0.5 }), "NaN is not a valid channel");
    check (!Convert.is_valid ({ 1.4, 0.5, 0.5 }), "above 1 is not a valid channel");
    check (!Convert.is_valid ({ -0.2, 0.5, 0.5 }), "below 0 is not a valid channel");
    check (Convert.is_valid ({ 0.0, 0.5, 1.0 }), "the closed unit range is valid");

    var poisoned = new Colour ({ double.NAN, -0.2, 1.4 });
    check (poisoned.hex.length == 7, "a poisoned colour still yields a 7 character hex");
    check (poisoned.row_value (1) == "rgb(0, 0, 255)", "a poisoned colour clamps to bytes");
    check (Convert.to_byte (double.NAN) == 0, "NaN converts to byte 0");
    check (Convert.to_byte (2.0) == 255, "an over-range double clamps to 255");
    check (Convert.to_byte (-1.0) == 0, "an under-range double clamps to 0");

    /* Contrast must not turn a NaN luminance into a plausible 1.00 ratio. */
    check (Contrast.ratio (double.NAN, 1.0).is_nan (), "NaN propagates through contrast");
    check (Contrast.ratio (1.0, double.NAN).is_nan (), "NaN propagates whichever side it is on");

    /* The ramp at the extremes: black and white have nowhere to go in one
     * direction, which must not produce a short strip or a NaN. */
    Rgb[] from_black = Ramp.build (hex ("#000000"));
    check (from_black.length == 11, "a ramp from black is still eleven swatches");
    same (Convert.to_hex (from_black[0]), "#000000", "shades of black are black");
    check (Convert.to_hex (from_black[10]) != "#000000", "tints of black are not black");

    Rgb[] from_white = Ramp.build (hex ("#FFFFFF"));
    check (from_white.length == 11, "a ramp from white is still eleven swatches");
    same (Convert.to_hex (from_white[10]), "#FFFFFF", "tints of white are white");
    check (Convert.to_hex (from_white[0]) != "#FFFFFF", "shades of white are not white");

    /* Out-of-range row indices must not read past the label table. */
    same (Colour.row_label (14), "", "a row index past the end has no label");
    same (Colour.row_label (-1), "", "a negative row index has no label");
    same (Colour.from_hex ("#A1B2C3").row_value (14), "", "a row index past the end has no value");
}

public static int main (string[] args) {
    /* History reads XDG_CONFIG_HOME through GLib, which caches on first use,
     * so it has to be redirected before anything else touches it. */
    Environment.set_variable ("XDG_CONFIG_HOME", test_config_dir (), true);

    stdout.printf ("aventurine conversion tests\n\n");

    test_luminance ();
    test_lab ();
    test_oklab ();
    test_round_trip ();
    test_hex ();
    test_hexcone ();
    test_linear ();
    test_contrast ();
    test_ramp ();
    test_names ();
    test_colour ();
    test_rows ();
    test_history ();
    test_export ();
    test_regressions ();

    stdout.printf ("\n%d checks, %d failures\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
