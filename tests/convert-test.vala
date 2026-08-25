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

    /* The two halves of the piecewise curve must meet. */
    near (Convert.linearise (0.04045), 0.04045 / 12.92, 1e-9, "gamma curve is continuous");
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
    same (Convert.to_hex (strip[Ramp.MIDDLE]), "#A1B2C3", "the picked colour is in the middle");

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
        if (s.c > 1e-6 && Math.fabs (s.h - base_hue) > 1.0) {
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

    /* Asking twice must give the same answer: the lazy caches must not drift. */
    near (c.luminance, c.luminance, 0.0, "luminance is stable across calls");
    same (c.hex, c.hex, "hex is stable across calls");

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
    same (black.row_value (8),  "lab(0.00 0.00 0.00)",      "black LAB has no negative zero");
    same (black.row_value (11), "0.0000",                   "black luminance");
    same (black.row_value (6),  "cmyk(0%, 0%, 0%, 100%)",   "black CMYK");
}

public static int main (string[] args) {
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

    stdout.printf ("\n%d checks, %d failures\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
