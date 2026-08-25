/* Colour space conversions.
 *
 * Every matrix and constant in this file is transcribed from CORE.md section 8.
 * Do not "simplify" a coefficient: the test suite pins published reference
 * values and rounding any of these will break them.
 *
 * The canonical representation everywhere in the application is three doubles
 * in 0..1, non-linear (gamma encoded) sRGB, exactly as the portal hands them
 * over.
 */

namespace Aventurine {

    public struct Xyz  { public double x; public double y; public double z; }
    public struct Lab  { public double l; public double a; public double b; }
    public struct Lch  { public double l; public double c; public double h; }
    public struct Hsl  { public double h; public double s; public double l; }
    public struct Hsv  { public double h; public double s; public double v; }
    public struct Hwb  { public double h; public double w; public double b; }
    public struct Cmyk { public double c; public double m; public double y; public double k; }

    namespace Convert {

        /* --- 8.1 gamma ------------------------------------------------- */

        public double linearise (double c) {
            return c <= 0.04045 ? c / 12.92
                                : Math.pow ((c + 0.055) / 1.055, 2.4);
        }

        public double encode (double c) {
            return c <= 0.0031308 ? c * 12.92
                                  : 1.055 * Math.pow (c, 1.0 / 2.4) - 0.055;
        }

        public Rgb to_linear (Rgb c) {
            return { linearise (c.r), linearise (c.g), linearise (c.b) };
        }

        /* --- 8.2 relative luminance, from linearised channels ----------- */

        public double luminance (Rgb c) {
            double r = linearise (c.r);
            double g = linearise (c.g);
            double b = linearise (c.b);
            return 0.2126 * r + 0.7152 * g + 0.0722 * b;
        }

        /* --- 8.3 CIEXYZ, D65 -------------------------------------------- */

        public const double XN = 0.95047;
        public const double YN = 1.00000;
        public const double ZN = 1.08883;

        public Xyz to_xyz (Rgb c) {
            double r = linearise (c.r);
            double g = linearise (c.g);
            double b = linearise (c.b);
            return {
                0.4124564 * r + 0.3575761 * g + 0.1804375 * b,
                0.2126729 * r + 0.7151522 * g + 0.0721750 * b,
                0.0193339 * r + 0.1191920 * g + 0.9503041 * b
            };
        }

        /* --- 8.4 CIELAB and LCH ----------------------------------------- */

        private double lab_f (double t) {
            const double E = 216.0 / 24389.0;
            const double K = 24389.0 / 27.0;
            return t > E ? Math.cbrt (t) : (K * t + 16.0) / 116.0;
        }

        public Lab to_lab (Rgb c) {
            Xyz xyz = to_xyz (c);
            double fx = lab_f (xyz.x / XN);
            double fy = lab_f (xyz.y / YN);
            double fz = lab_f (xyz.z / ZN);
            return {
                116.0 * fy - 16.0,
                500.0 * (fx - fy),
                200.0 * (fy - fz)
            };
        }

        /* Shared polar form for both LAB and OKLab. */
        private void to_polar (double a, double b, out double chroma, out double hue) {
            chroma = Math.sqrt (a * a + b * b);
            hue = Math.atan2 (b, a) * 180.0 / Math.PI;
            if (hue < 0.0) {
                hue += 360.0;
            }
        }

        public Lch to_lch (Rgb c) {
            Lab lab = to_lab (c);
            double chroma, hue;
            to_polar (lab.a, lab.b, out chroma, out hue);
            return { lab.l, chroma, hue };
        }

        /* --- 8.5 OKLab and OKLCH ---------------------------------------- */

        public Lab to_oklab (Rgb c) {
            double r = linearise (c.r);
            double g = linearise (c.g);
            double b = linearise (c.b);

            double l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
            double m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
            double s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

            double l_ = Math.cbrt (l);
            double m_ = Math.cbrt (m);
            double s_ = Math.cbrt (s);

            return {
                0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
                1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
                0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
            };
        }

        public Lch to_oklch (Rgb c) {
            Lab ok = to_oklab (c);
            double chroma, hue;
            to_polar (ok.a, ok.b, out chroma, out hue);
            return { ok.l, chroma, hue };
        }

        /* Inverse, needed for the tint and shade ramp.
         * Channels are clamped after encoding, per 8.7. */
        public Rgb from_oklab (Lab ok) {
            double l_ = ok.l + 0.3963377774 * ok.a + 0.2158037573 * ok.b;
            double m_ = ok.l - 0.1055613458 * ok.a - 0.0638541728 * ok.b;
            double s_ = ok.l - 0.0894841775 * ok.a - 1.2914855480 * ok.b;

            double l = l_ * l_ * l_;
            double m = m_ * m_ * m_;
            double s = s_ * s_ * s_;

            double r = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
            double g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
            double b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;

            return {
                clamp01 (encode (r)),
                clamp01 (encode (g)),
                clamp01 (encode (b))
            };
        }

        public Rgb from_oklch (Lch ok) {
            double rad = ok.h * Math.PI / 180.0;
            Lab lab = { ok.l, ok.c * Math.cos (rad), ok.c * Math.sin (rad) };
            return from_oklab (lab);
        }

        public double clamp01 (double v) {
            if (v < 0.0) return 0.0;
            if (v > 1.0) return 1.0;
            return v;
        }

        /* --- 8.6 the remaining spaces ----------------------------------- */

        /* Hue, and the max/min/chroma triple that HSL, HSV and HWB share. */
        private void hexcone (Rgb c, out double hue, out double max, out double min) {
            max = double.max (c.r, double.max (c.g, c.b));
            min = double.min (c.r, double.min (c.g, c.b));
            double d = max - min;

            if (d <= 0.0) {
                hue = 0.0;
                return;
            }

            if (max == c.r) {
                hue = 60.0 * (((c.g - c.b) / d) % 6.0);
            } else if (max == c.g) {
                hue = 60.0 * (((c.b - c.r) / d) + 2.0);
            } else {
                hue = 60.0 * (((c.r - c.g) / d) + 4.0);
            }

            if (hue < 0.0) {
                hue += 360.0;
            }
        }

        public Hsl to_hsl (Rgb c) {
            double hue, max, min;
            hexcone (c, out hue, out max, out min);
            double d = max - min;
            double l = (max + min) / 2.0;
            double s = 0.0;
            if (d > 0.0) {
                double denom = 1.0 - Math.fabs (2.0 * l - 1.0);
                s = denom > 0.0 ? d / denom : 0.0;
            }
            return { hue, s, l };
        }

        public Hsv to_hsv (Rgb c) {
            double hue, max, min;
            hexcone (c, out hue, out max, out min);
            double d = max - min;
            double s = max > 0.0 ? d / max : 0.0;
            return { hue, s, max };
        }

        public Hwb to_hwb (Rgb c) {
            double hue, max, min;
            hexcone (c, out hue, out max, out min);
            return { hue, min, 1.0 - max };
        }

        public Cmyk to_cmyk (Rgb c) {
            double max = double.max (c.r, double.max (c.g, c.b));
            double k = 1.0 - max;
            if (k >= 1.0) {
                /* Pure black: the other three channels are undefined, so zero. */
                return { 0.0, 0.0, 0.0, 1.0 };
            }
            double inv = 1.0 - k;
            return {
                (1.0 - c.r - k) / inv,
                (1.0 - c.g - k) / inv,
                (1.0 - c.b - k) / inv,
                k
            };
        }

        /* --- hex ---------------------------------------------------------- */

        public int to_byte (double v) {
            int b = (int) Math.round (clamp01 (v) * 255.0);
            return b;
        }

        public string to_hex (Rgb c) {
            return "#%02X%02X%02X".printf (to_byte (c.r), to_byte (c.g), to_byte (c.b));
        }

        public Rgb from_bytes (int r, int g, int b) {
            return { r / 255.0, g / 255.0, b / 255.0 };
        }

        /* Accepts #RGB, #RRGGBB and the same without the hash. */
        public bool parse_hex (string text, out Rgb result) {
            result = { 0.0, 0.0, 0.0 };
            string s = text.strip ();
            if (s.has_prefix ("#")) {
                s = s.substring (1);
            }
            if (s.length != 3 && s.length != 6) {
                return false;
            }
            for (int i = 0; i < s.length; i++) {
                if (!s[i].isxdigit ()) {
                    return false;
                }
            }
            if (s.length == 3) {
                s = "%c%c%c%c%c%c".printf (s[0], s[0], s[1], s[1], s[2], s[2]);
            }
            int v = 0;
            for (int i = 0; i < s.length; i++) {
                v = v * 16 + s[i].xdigit_value ();
            }
            result = from_bytes ((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
            return true;
        }
    }
}
