/* WCAG contrast ratios and verdicts. CORE.md section 10. */

namespace Aventurine {

    public struct ContrastResult {
        public double ratio;
        public bool aa_normal;    /* >= 4.5 */
        public bool aa_large;     /* >= 3.0 */
        public bool aaa_normal;   /* >= 7.0 */
        public bool aaa_large;    /* >= 4.5 */
    }

    namespace Contrast {

        public const double AA_NORMAL  = 4.5;
        public const double AA_LARGE   = 3.0;
        public const double AAA_NORMAL = 7.0;
        public const double AAA_LARGE  = 4.5;

        /* Both arguments are relative luminance per CORE.md section 8.2. */
        public double ratio (double a, double b) {
            double hi = double.max (a, b);
            double lo = double.min (a, b);
            return (hi + 0.05) / (lo + 0.05);
        }

        public ContrastResult evaluate (double own_luminance, double other_luminance) {
            double r = ratio (own_luminance, other_luminance);
            return {
                r,
                r >= AA_NORMAL,
                r >= AA_LARGE,
                r >= AAA_NORMAL,
                r >= AAA_LARGE
            };
        }

        /* White has luminance 1.0, black 0.0, by definition of section 8.2. */
        public ContrastResult against_white (double own_luminance) {
            return evaluate (own_luminance, 1.0);
        }

        public ContrastResult against_black (double own_luminance) {
            return evaluate (own_luminance, 0.0);
        }
    }
}
