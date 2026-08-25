/* Tints and shades. CORE.md section 11.
 *
 * Chroma and hue are held; only OKLCH lightness moves. The strip is eleven
 * swatches, darkest first, with the picked colour at index 5.
 */

namespace Aventurine {

    namespace Ramp {

        public const int STEPS  = 5;
        public const int LENGTH = STEPS * 2 + 1;
        public const int MIDDLE = STEPS;

        /* Index 0..4 are shades, darkest first; 5 is the colour itself;
         * 6..10 are tints, lightest last. */
        public Rgb[] build (Rgb colour) {
            Lch ok = Convert.to_oklch (colour);
            var strip = new Rgb[LENGTH];

            for (int i = STEPS; i >= 1; i--) {
                double l = ok.l - ok.l * i / 6.0;
                strip[STEPS - i] = Convert.from_oklch ({ l, ok.c, ok.h });
            }

            strip[MIDDLE] = colour;

            for (int i = 1; i <= STEPS; i++) {
                double l = ok.l + (1.0 - ok.l) * i / 6.0;
                strip[MIDDLE + i] = Convert.from_oklch ({ l, ok.c, ok.h });
            }

            return strip;
        }
    }
}
