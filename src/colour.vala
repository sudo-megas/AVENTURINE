/* One picked colour, and its lazily computed derived values.
 *
 * Rgb is the canonical carrier: three doubles in 0..1, non-linear sRGB.
 * Colour wraps one Rgb and computes everything else on first request, because
 * the nearest-name searches walk a thousand-entry table and the window asks
 * for the same values repeatedly while it redraws.
 */

namespace Aventurine {

    public struct Rgb {
        public double r;
        public double g;
        public double b;
    }

    public class Colour : Object {

        public Rgb rgb { get; private set; }

        /* Which backend captured this colour. Carried into the history file. */
        public string source_id { get; set; default = "unknown"; }

        public Colour (Rgb rgb) {
            this.rgb = rgb;
        }

        public Colour.from_bytes (int r, int g, int b) {
            this (Convert.from_bytes (r, g, b));
        }

        public static Colour? from_hex (string text) {
            Rgb parsed;
            if (!Convert.parse_hex (text, out parsed)) {
                return null;
            }
            return new Colour (parsed);
        }

        /* --- lazy caches ------------------------------------------------ */

        private string? _hex = null;
        public string hex {
            get {
                if (_hex == null) {
                    _hex = Convert.to_hex (rgb);
                }
                return _hex;
            }
        }

        private bool _has_luminance = false;
        private double _luminance;
        public double luminance {
            get {
                if (!_has_luminance) {
                    _luminance = Convert.luminance (rgb);
                    _has_luminance = true;
                }
                return _luminance;
            }
        }

        private bool _has_linear = false;
        private Rgb _linear;
        public Rgb linear {
            get {
                if (!_has_linear) {
                    _linear = Convert.to_linear (rgb);
                    _has_linear = true;
                }
                return _linear;
            }
        }

        private bool _has_lab = false;
        private Lab _lab;
        public Lab lab {
            get {
                if (!_has_lab) {
                    _lab = Convert.to_lab (rgb);
                    _has_lab = true;
                }
                return _lab;
            }
        }

        private bool _has_lch = false;
        private Lch _lch;
        public Lch lch {
            get {
                if (!_has_lch) {
                    _lch = Convert.to_lch (rgb);
                    _has_lch = true;
                }
                return _lch;
            }
        }

        private bool _has_oklab = false;
        private Lab _oklab;
        public Lab oklab {
            get {
                if (!_has_oklab) {
                    _oklab = Convert.to_oklab (rgb);
                    _has_oklab = true;
                }
                return _oklab;
            }
        }

        private bool _has_oklch = false;
        private Lch _oklch;
        public Lch oklch {
            get {
                if (!_has_oklch) {
                    _oklch = Convert.to_oklch (rgb);
                    _has_oklch = true;
                }
                return _oklch;
            }
        }

        private bool _has_hsl = false;
        private Hsl _hsl;
        public Hsl hsl {
            get {
                if (!_has_hsl) {
                    _hsl = Convert.to_hsl (rgb);
                    _has_hsl = true;
                }
                return _hsl;
            }
        }

        private bool _has_hsv = false;
        private Hsv _hsv;
        public Hsv hsv {
            get {
                if (!_has_hsv) {
                    _hsv = Convert.to_hsv (rgb);
                    _has_hsv = true;
                }
                return _hsv;
            }
        }

        private bool _has_hwb = false;
        private Hwb _hwb;
        public Hwb hwb {
            get {
                if (!_has_hwb) {
                    _hwb = Convert.to_hwb (rgb);
                    _has_hwb = true;
                }
                return _hwb;
            }
        }

        private bool _has_cmyk = false;
        private Cmyk _cmyk;
        public Cmyk cmyk {
            get {
                if (!_has_cmyk) {
                    _cmyk = Convert.to_cmyk (rgb);
                    _has_cmyk = true;
                }
                return _cmyk;
            }
        }

        /* --- convenience ------------------------------------------------- */

        /* CORE.md section 14: the hex printed over the header swatch is black
         * above this luminance and white below it. */
        public const double TEXT_SWITCH_LUMINANCE = 0.179;

        public bool wants_dark_text {
            get { return luminance > TEXT_SWITCH_LUMINANCE; }
        }

        public int red   { get { return Convert.to_byte (rgb.r); } }
        public int green { get { return Convert.to_byte (rgb.g); } }
        public int blue  { get { return Convert.to_byte (rgb.b); } }

        /* --- the fourteen format rows, CORE.md section 9 ------------------
         *
         * The rows live here rather than in the window so they can be tested
         * without a display. Precision follows section 9: HSL, HSV, HWB and
         * CMYK are integers; LAB two decimals; LCH two; OKLCH three; linear
         * RGB three; luminance four. Hue carries one decimal in LCH and OKLCH,
         * as the worked examples in that section show.
         */

        public const int ROW_COUNT = 14;

        private const string[] ROW_LABELS = {
            "HEX", "RGB", "RGB %", "HSL", "HSV", "HWB", "CMYK",
            "Linear RGB", "LAB", "LCH", "OKLCH", "Luminance",
            "CSS name", "xkcd name"
        };

        public static string row_label (int index) {
            return ROW_LABELS[index];
        }

        /* Rounds to the given decimals and folds -0.0 back to 0.0, so a channel
         * a hair below zero does not print as "-0.00". */
        private static double tidy (double v, int decimals) {
            double scale = Math.pow (10.0, decimals);
            double r = Math.round (v * scale) / scale;
            return r == 0.0 ? 0.0 : r;
        }

        private static int pct (double v) {
            return (int) Math.round (v * 100.0);
        }

        public string row_value (int index) {
            switch (index) {
                case 0:
                    return hex;
                case 1:
                    return "rgb(%d, %d, %d)".printf (red, green, blue);
                case 2:
                    return "rgb(%.1f%%, %.1f%%, %.1f%%)".printf (
                        tidy (rgb.r * 100.0, 1), tidy (rgb.g * 100.0, 1), tidy (rgb.b * 100.0, 1));
                case 3:
                    return "hsl(%d, %d%%, %d%%)".printf (
                        (int) Math.round (hsl.h), pct (hsl.s), pct (hsl.l));
                case 4:
                    return "hsv(%d, %d%%, %d%%)".printf (
                        (int) Math.round (hsv.h), pct (hsv.s), pct (hsv.v));
                case 5:
                    return "hwb(%d %d%% %d%%)".printf (
                        (int) Math.round (hwb.h), pct (hwb.w), pct (hwb.b));
                case 6:
                    return "cmyk(%d%%, %d%%, %d%%, %d%%)".printf (
                        pct (cmyk.c), pct (cmyk.m), pct (cmyk.y), pct (cmyk.k));
                case 7:
                    return "%.3f %.3f %.3f".printf (
                        tidy (linear.r, 3), tidy (linear.g, 3), tidy (linear.b, 3));
                case 8:
                    return "lab(%.2f %.2f %.2f)".printf (
                        tidy (lab.l, 2), tidy (lab.a, 2), tidy (lab.b, 2));
                case 9:
                    return "lch(%.2f %.2f %.1f)".printf (
                        tidy (lch.l, 2), tidy (lch.c, 2), tidy (lch.h, 1));
                case 10:
                    return "oklch(%.3f %.3f %.1f)".printf (
                        tidy (oklch.l, 3), tidy (oklch.c, 3), tidy (oklch.h, 1));
                case 11:
                    return "%.4f".printf (tidy (luminance, 4));
                case 12:
                    return css_name;
                case 13:
                    return xkcd_name;
                default:
                    return "";
            }
        }

        private string? _css_name = null;
        public string css_name {
            get {
                if (_css_name == null) {
                    _css_name = Names.nearest_css (rgb);
                }
                return _css_name;
            }
        }

        private string? _xkcd_name = null;
        public string xkcd_name {
            get {
                if (_xkcd_name == null) {
                    _xkcd_name = Names.nearest_xkcd (rgb);
                }
                return _xkcd_name;
            }
        }
    }
}
