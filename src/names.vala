/* Named colour tables and nearest-match lookup. CORE.md section 9.
 *
 * Two vendored tables, both verbatim, neither approximated:
 *
 *   CSS   148 entries, the CSS Color 4 named colours including rebeccapurple.
 *   xkcd  949 entries, the xkcd colour survey list.
 *
 * Matching runs in OKLab with plain Euclidean distance, which is close enough
 * to perceptual for a name label and far better than distance in sRGB. The
 * OKLab coordinates of each table are computed once, on the first lookup, and
 * kept for the life of the process.
 */

namespace Aventurine {

    public class Names : Object {

        public const int CSS_COUNT  = 148;
        public const int XKCD_COUNT = 949;

        private static double[]? css_ok  = null;
        private static double[]? xkcd_ok = null;

        /* Fills a flat L,a,b triple array for one table. */
        private static double[] build_ok (uint32[] table) {
            var ok = new double[table.length * 3];
            for (int i = 0; i < table.length; i++) {
                uint32 v = table[i];
                Rgb c = Convert.from_bytes ((int) ((v >> 16) & 0xFF),
                                            (int) ((v >> 8) & 0xFF),
                                            (int) (v & 0xFF));
                Lab lab = Convert.to_oklab (c);
                ok[i * 3]     = lab.l;
                ok[i * 3 + 1] = lab.a;
                ok[i * 3 + 2] = lab.b;
            }
            return ok;
        }

        private static int nearest_index (Rgb colour, double[] ok) {
            Lab want = Convert.to_oklab (colour);
            int best = 0;
            double best_d = double.MAX;
            int n = ok.length / 3;
            for (int i = 0; i < n; i++) {
                double dl = want.l - ok[i * 3];
                double da = want.a - ok[i * 3 + 1];
                double db = want.b - ok[i * 3 + 2];
                double d = dl * dl + da * da + db * db;
                if (d < best_d) {
                    best_d = d;
                    best = i;
                }
            }
            return best;
        }

        public static string nearest_css (Rgb colour) {
            if (css_ok == null) {
                css_ok = build_ok (CSS_RGB);
            }
            return CSS_NAMES[nearest_index (colour, css_ok)];
        }

        public static string nearest_xkcd (Rgb colour) {
            if (xkcd_ok == null) {
                xkcd_ok = build_ok (XKCD_RGB);
            }
            return XKCD_NAMES[nearest_index (colour, xkcd_ok)];
        }

        /* Exact hex lookup, used by nothing in v1.0 but cheap to keep correct. */
        public static string? exact_css (Rgb colour) {
            uint32 want = (uint32) ((Convert.to_byte (colour.r) << 16)
                                  | (Convert.to_byte (colour.g) << 8)
                                  |  Convert.to_byte (colour.b));
            for (int i = 0; i < CSS_RGB.length; i++) {
                if (CSS_RGB[i] == want) {
                    return CSS_NAMES[i];
                }
            }
            return null;
        }

        /* --- CSS Color 4 named colours, 148 entries --- */

        private const string[] CSS_NAMES = {
        "aliceblue", "antiquewhite", "aqua", "aquamarine",
        "azure", "beige", "bisque", "black",
        "blanchedalmond", "blue", "blueviolet", "brown",
        "burlywood", "cadetblue", "chartreuse", "chocolate",
        "coral", "cornflowerblue", "cornsilk", "crimson",
        "cyan", "darkblue", "darkcyan", "darkgoldenrod",
        "darkgray", "darkgreen", "darkgrey", "darkkhaki",
        "darkmagenta", "darkolivegreen", "darkorange", "darkorchid",
        "darkred", "darksalmon", "darkseagreen", "darkslateblue",
        "darkslategray", "darkslategrey", "darkturquoise", "darkviolet",
        "deeppink", "deepskyblue", "dimgray", "dimgrey",
        "dodgerblue", "firebrick", "floralwhite", "forestgreen",
        "fuchsia", "gainsboro", "ghostwhite", "gold",
        "goldenrod", "gray", "green", "greenyellow",
        "grey", "honeydew", "hotpink", "indianred",
        "indigo", "ivory", "khaki", "lavender",
        "lavenderblush", "lawngreen", "lemonchiffon", "lightblue",
        "lightcoral", "lightcyan", "lightgoldenrodyellow", "lightgray",
        "lightgreen", "lightgrey", "lightpink", "lightsalmon",
        "lightseagreen", "lightskyblue", "lightslategray", "lightslategrey",
        "lightsteelblue", "lightyellow", "lime", "limegreen",
        "linen", "magenta", "maroon", "mediumaquamarine",
        "mediumblue", "mediumorchid", "mediumpurple", "mediumseagreen",
        "mediumslateblue", "mediumspringgreen", "mediumturquoise", "mediumvioletred",
        "midnightblue", "mintcream", "mistyrose", "moccasin",
        "navajowhite", "navy", "oldlace", "olive",
        "olivedrab", "orange", "orangered", "orchid",
        "palegoldenrod", "palegreen", "paleturquoise", "palevioletred",
        "papayawhip", "peachpuff", "peru", "pink",
        "plum", "powderblue", "purple", "rebeccapurple",
        "red", "rosybrown", "royalblue", "saddlebrown",
        "salmon", "sandybrown", "seagreen", "seashell",
        "sienna", "silver", "skyblue", "slateblue",
        "slategray", "slategrey", "snow", "springgreen",
        "steelblue", "tan", "teal", "thistle",
        "tomato", "turquoise", "violet", "wheat",
        "white", "whitesmoke", "yellow", "yellowgreen"
        };

        private const uint32[] CSS_RGB = {
        0xF0F8FF, 0xFAEBD7, 0x00FFFF, 0x7FFFD4, 0xF0FFFF, 0xF5F5DC, 0xFFE4C4, 0x000000,
        0xFFEBCD, 0x0000FF, 0x8A2BE2, 0xA52A2A, 0xDEB887, 0x5F9EA0, 0x7FFF00, 0xD2691E,
        0xFF7F50, 0x6495ED, 0xFFF8DC, 0xDC143C, 0x00FFFF, 0x00008B, 0x008B8B, 0xB8860B,
        0xA9A9A9, 0x006400, 0xA9A9A9, 0xBDB76B, 0x8B008B, 0x556B2F, 0xFF8C00, 0x9932CC,
        0x8B0000, 0xE9967A, 0x8FBC8F, 0x483D8B, 0x2F4F4F, 0x2F4F4F, 0x00CED1, 0x9400D3,
        0xFF1493, 0x00BFFF, 0x696969, 0x696969, 0x1E90FF, 0xB22222, 0xFFFAF0, 0x228B22,
        0xFF00FF, 0xDCDCDC, 0xF8F8FF, 0xFFD700, 0xDAA520, 0x808080, 0x008000, 0xADFF2F,
        0x808080, 0xF0FFF0, 0xFF69B4, 0xCD5C5C, 0x4B0082, 0xFFFFF0, 0xF0E68C, 0xE6E6FA,
        0xFFF0F5, 0x7CFC00, 0xFFFACD, 0xADD8E6, 0xF08080, 0xE0FFFF, 0xFAFAD2, 0xD3D3D3,
        0x90EE90, 0xD3D3D3, 0xFFB6C1, 0xFFA07A, 0x20B2AA, 0x87CEFA, 0x778899, 0x778899,
        0xB0C4DE, 0xFFFFE0, 0x00FF00, 0x32CD32, 0xFAF0E6, 0xFF00FF, 0x800000, 0x66CDAA,
        0x0000CD, 0xBA55D3, 0x9370DB, 0x3CB371, 0x7B68EE, 0x00FA9A, 0x48D1CC, 0xC71585,
        0x191970, 0xF5FFFA, 0xFFE4E1, 0xFFE4B5, 0xFFDEAD, 0x000080, 0xFDF5E6, 0x808000,
        0x6B8E23, 0xFFA500, 0xFF4500, 0xDA70D6, 0xEEE8AA, 0x98FB98, 0xAFEEEE, 0xDB7093,
        0xFFEFD5, 0xFFDAB9, 0xCD853F, 0xFFC0CB, 0xDDA0DD, 0xB0E0E6, 0x800080, 0x663399,
        0xFF0000, 0xBC8F8F, 0x4169E1, 0x8B4513, 0xFA8072, 0xF4A460, 0x2E8B57, 0xFFF5EE,
        0xA0522D, 0xC0C0C0, 0x87CEEB, 0x6A5ACD, 0x708090, 0x708090, 0xFFFAFA, 0x00FF7F,
        0x4682B4, 0xD2B48C, 0x008080, 0xD8BFD8, 0xFF6347, 0x40E0D0, 0xEE82EE, 0xF5DEB3,
        0xFFFFFF, 0xF5F5F5, 0xFFFF00, 0x9ACD32
        };

        /* --- xkcd colour survey, 949 entries --- */

        private const string[] XKCD_NAMES = {
        "cloudy blue", "dark pastel green", "dust", "electric lime",
        "fresh green", "light eggplant", "nasty green", "really light blue",
        "tea", "warm purple", "yellowish tan", "cement",
        "dark grass green", "dusty teal", "grey teal", "macaroni and cheese",
        "pinkish tan", "spruce", "strong blue", "toxic green",
        "windows blue", "blue blue", "blue with a hint of purple", "booger",
        "bright sea green", "dark green blue", "deep turquoise", "green teal",
        "strong pink", "bland", "deep aqua", "lavender pink",
        "light moss green", "light seafoam green", "olive yellow", "pig pink",
        "deep lilac", "desert", "dusty lavender", "purpley grey",
        "purply", "candy pink", "light pastel green", "boring green",
        "kiwi green", "light grey green", "orange pink", "tea green",
        "very light brown", "egg shell", "eggplant purple", "powder pink",
        "reddish grey", "baby shit brown", "liliac", "stormy blue",
        "ugly brown", "custard", "darkish pink", "deep brown",
        "greenish beige", "manilla", "off blue", "battleship grey",
        "browny green", "bruise", "kelley green", "sickly yellow",
        "sunny yellow", "azul", "darkgreen", "green/yellow",
        "lichen", "light light green", "pale gold", "sun yellow",
        "tan green", "burple", "butterscotch", "toupe",
        "dark cream", "indian red", "light lavendar", "poison green",
        "baby puke green", "bright yellow green", "charcoal grey", "squash",
        "cinnamon", "light pea green", "radioactive green", "raw sienna",
        "baby purple", "cocoa", "light royal blue", "orangeish",
        "rust brown", "sand brown", "swamp", "tealish green",
        "burnt siena", "camo", "dusk blue", "fern",
        "old rose", "pale light green", "peachy pink", "rosy pink",
        "light bluish green", "light bright green", "light neon green", "light seafoam",
        "tiffany blue", "washed out green", "browny orange", "nice blue",
        "sapphire", "greyish teal", "orangey yellow", "parchment",
        "straw", "very dark brown", "terracota", "ugly blue",
        "clear blue", "creme", "foam green", "grey/green",
        "light gold", "seafoam blue", "topaz", "violet pink",
        "wintergreen", "yellow tan", "dark fuchsia", "indigo blue",
        "light yellowish green", "pale magenta", "rich purple", "sunflower yellow",
        "green/blue", "leather", "racing green", "vivid purple",
        "dark royal blue", "hazel", "muted pink", "booger green",
        "canary", "cool grey", "dark taupe", "darkish purple",
        "true green", "coral pink", "dark sage", "dark slate blue",
        "flat blue", "mushroom", "rich blue", "dirty purple",
        "greenblue", "icky green", "light khaki", "warm blue",
        "dark hot pink", "deep sea blue", "carmine", "dark yellow green",
        "pale peach", "plum purple", "golden rod", "neon red",
        "old pink", "very pale blue", "blood orange", "grapefruit",
        "sand yellow", "clay brown", "dark blue grey", "flat green",
        "light green blue", "warm pink", "dodger blue", "gross green",
        "ice", "metallic blue", "pale salmon", "sap green",
        "algae", "bluey grey", "greeny grey", "highlighter green",
        "light light blue", "light mint", "raw umber", "vivid blue",
        "deep lavender", "dull teal", "light greenish blue", "mud green",
        "pinky", "red wine", "shit green", "tan brown",
        "darkblue", "rosa", "lipstick", "pale mauve",
        "claret", "dandelion", "orangered", "poop green",
        "ruby", "dark", "greenish turquoise", "pastel red",
        "piss yellow", "bright cyan", "dark coral", "algae green",
        "darkish red", "reddy brown", "blush pink", "camouflage green",
        "lawn green", "putty", "vibrant blue", "dark sand",
        "purple/blue", "saffron", "twilight", "warm brown",
        "bluegrey", "bubble gum pink", "duck egg blue", "greenish cyan",
        "petrol", "royal", "butter", "dusty orange",
        "off yellow", "pale olive green", "orangish", "leaf",
        "light blue grey", "dried blood", "lightish purple", "rusty red",
        "lavender blue", "light grass green", "light mint green", "sunflower",
        "velvet", "brick orange", "lightish red", "pure blue",
        "twilight blue", "violet red", "yellowy brown", "carnation",
        "muddy yellow", "dark seafoam green", "deep rose", "dusty red",
        "grey/blue", "lemon lime", "purple/pink", "brown yellow",
        "purple brown", "wisteria", "banana yellow", "lipstick red",
        "water blue", "brown grey", "vibrant purple", "baby green",
        "barf green", "eggshell blue", "sandy yellow", "cool green",
        "pale", "blue/grey", "hot magenta", "greyblue",
        "purpley", "baby shit green", "brownish pink", "dark aquamarine",
        "diarrhea", "light mustard", "pale sky blue", "turtle green",
        "bright olive", "dark grey blue", "greeny brown", "lemon green",
        "light periwinkle", "seaweed green", "sunshine yellow", "ugly purple",
        "medium pink", "puke brown", "very light pink", "viridian",
        "bile", "faded yellow", "very pale green", "vibrant green",
        "bright lime", "spearmint", "light aquamarine", "light sage",
        "yellowgreen", "baby poo", "dark seafoam", "deep teal",
        "heather", "rust orange", "dirty blue", "fern green",
        "bright lilac", "weird green", "peacock blue", "avocado green",
        "faded orange", "grape purple", "hot green", "lime yellow",
        "mango", "shamrock", "bubblegum", "purplish brown",
        "vomit yellow", "pale cyan", "key lime", "tomato red",
        "lightgreen", "merlot", "night blue", "purpleish pink",
        "apple", "baby poop green", "green apple", "heliotrope",
        "yellow/green", "almost black", "cool blue", "leafy green",
        "mustard brown", "dusk", "dull brown", "frog green",
        "vivid green", "bright light green", "fluro green", "kiwi",
        "seaweed", "navy green", "ultramarine blue", "iris",
        "pastel orange", "yellowish orange", "perrywinkle", "tealish",
        "dark plum", "pear", "pinkish orange", "midnight purple",
        "light urple", "dark mint", "greenish tan", "light burgundy",
        "turquoise blue", "ugly pink", "sandy", "electric pink",
        "muted purple", "mid green", "greyish", "neon yellow",
        "banana", "carnation pink", "tomato", "sea",
        "muddy brown", "turquoise green", "buff", "fawn",
        "muted blue", "pale rose", "dark mint green", "amethyst",
        "blue/green", "chestnut", "sick green", "pea",
        "rusty orange", "stone", "rose red", "pale aqua",
        "deep orange", "earth", "mossy green", "grassy green",
        "pale lime green", "light grey blue", "pale grey", "asparagus",
        "blueberry", "purple red", "pale lime", "greenish teal",
        "caramel", "deep magenta", "light peach", "milk chocolate",
        "ocher", "off green", "purply pink", "lightblue",
        "dusky blue", "golden", "light beige", "butter yellow",
        "dusky purple", "french blue", "ugly yellow", "greeny yellow",
        "orangish red", "shamrock green", "orangish brown", "tree green",
        "deep violet", "gunmetal", "blue/purple", "cherry",
        "sandy brown", "warm grey", "dark indigo", "midnight",
        "bluey green", "grey pink", "soft purple", "blood",
        "brown red", "medium grey", "berry", "poo",
        "purpley pink", "light salmon", "snot", "easter purple",
        "light yellow green", "dark navy blue", "drab", "light rose",
        "rouge", "purplish red", "slime green", "baby poop",
        "irish green", "pink/purple", "dark navy", "greeny blue",
        "light plum", "pinkish grey", "dirty orange", "rust red",
        "pale lilac", "orangey red", "primary blue", "kermit green",
        "brownish purple", "murky green", "wheat", "very dark purple",
        "bottle green", "watermelon", "deep sky blue", "fire engine red",
        "yellow ochre", "pumpkin orange", "pale olive", "light lilac",
        "lightish green", "carolina blue", "mulberry", "shocking pink",
        "auburn", "bright lime green", "celadon", "pinkish brown",
        "poo brown", "bright sky blue", "celery", "dirt brown",
        "strawberry", "dark lime", "copper", "medium brown",
        "muted green", "s egg", "bright aqua", "bright lavender",
        "ivory", "very light purple", "light navy", "pink red",
        "olive brown", "poop brown", "mustard green", "ocean green",
        "very dark blue", "dusty green", "light navy blue", "minty green",
        "adobe", "barney", "jade green", "bright light blue",
        "light lime", "dark khaki", "orange yellow", "ocre",
        "maize", "faded pink", "british racing green", "sandstone",
        "mud brown", "light sea green", "robin egg blue", "aqua marine",
        "dark sea green", "soft pink", "orangey brown", "cherry red",
        "burnt yellow", "brownish grey", "camel", "purplish grey",
        "marine", "greyish pink", "pale turquoise", "pastel yellow",
        "bluey purple", "canary yellow", "faded red", "sepia",
        "coffee", "bright magenta", "mocha", "ecru",
        "purpleish", "cranberry", "darkish green", "brown orange",
        "dusky rose", "melon", "sickly green", "silver",
        "purply blue", "purpleish blue", "hospital green", "shit brown",
        "mid blue", "amber", "easter green", "soft blue",
        "cerulean blue", "golden brown", "bright turquoise", "red pink",
        "red purple", "greyish brown", "vermillion", "russet",
        "steel grey", "lighter purple", "bright violet", "prussian blue",
        "slate green", "dirty pink", "dark blue green", "pine",
        "yellowy green", "dark gold", "bluish", "darkish blue",
        "dull red", "pinky red", "bronze", "pale teal",
        "military green", "barbie pink", "bubblegum pink", "pea soup green",
        "dark mustard", "shit", "medium purple", "very dark green",
        "dirt", "dusky pink", "red violet", "lemon yellow",
        "pistachio", "dull yellow", "dark lime green", "denim blue",
        "teal blue", "lightish blue", "purpley blue", "light indigo",
        "swamp green", "brown green", "dark maroon", "hot purple",
        "dark forest green", "faded blue", "drab green", "light lime green",
        "snot green", "yellowish", "light blue green", "bordeaux",
        "light mauve", "ocean", "marigold", "muddy green",
        "dull orange", "steel", "electric purple", "fluorescent green",
        "yellowish brown", "blush", "soft green", "bright orange",
        "lemon", "purple grey", "acid green", "pale lavender",
        "violet blue", "light forest green", "burnt red", "khaki green",
        "cerise", "faded purple", "apricot", "dark olive green",
        "grey brown", "green grey", "true blue", "pale violet",
        "periwinkle blue", "light sky blue", "blurple", "green brown",
        "bluegreen", "bright teal", "brownish yellow", "pea soup",
        "forest", "barney purple", "ultramarine", "purplish",
        "puke yellow", "bluish grey", "dark periwinkle", "dark lilac",
        "reddish", "light maroon", "dusty purple", "terra cotta",
        "avocado", "marine blue", "teal green", "slate grey",
        "lighter green", "electric green", "dusty blue", "golden yellow",
        "bright yellow", "light lavender", "umber", "poop",
        "dark peach", "jungle green", "eggshell", "denim",
        "yellow brown", "dull purple", "chocolate brown", "wine red",
        "neon blue", "dirty green", "light tan", "ice blue",
        "cadet blue", "dark mauve", "very light blue", "grey purple",
        "pastel pink", "very light green", "dark sky blue", "evergreen",
        "dull pink", "aubergine", "mahogany", "reddish orange",
        "deep green", "vomit green", "purple pink", "dusty pink",
        "faded green", "camo green", "pinky purple", "pink purple",
        "brownish red", "dark rose", "mud", "brownish",
        "emerald green", "pale brown", "dull blue", "burnt umber",
        "medium green", "clay", "light aqua", "light olive green",
        "brownish orange", "dark aqua", "purplish pink", "dark salmon",
        "greenish grey", "jade", "ugly green", "dark beige",
        "emerald", "pale red", "light magenta", "sky",
        "light cyan", "yellow orange", "reddish purple", "reddish pink",
        "orchid", "dirty yellow", "orange red", "deep red",
        "orange brown", "cobalt blue", "neon pink", "rose pink",
        "greyish purple", "raspberry", "aqua green", "salmon pink",
        "tangerine", "brownish green", "red brown", "greenish brown",
        "pumpkin", "pine green", "charcoal", "baby pink",
        "cornflower", "blue violet", "chocolate", "greyish green",
        "scarlet", "green yellow", "dark olive", "sienna",
        "pastel purple", "terracotta", "aqua blue", "sage green",
        "blood red", "deep pink", "grass", "moss",
        "pastel blue", "bluish green", "green blue", "dark tan",
        "greenish blue", "pale orange", "vomit", "forrest green",
        "dark lavender", "dark violet", "purple blue", "dark cyan",
        "olive drab", "pinkish", "cobalt", "neon purple",
        "light turquoise", "apple green", "dull green", "wine",
        "powder blue", "off white", "electric blue", "dark turquoise",
        "blue purple", "azure", "bright red", "pinkish red",
        "cornflower blue", "light olive", "grape", "greyish blue",
        "purplish blue", "yellowish green", "greenish yellow", "medium blue",
        "dusty rose", "light violet", "midnight blue", "bluish purple",
        "red orange", "dark magenta", "greenish", "ocean blue",
        "coral", "cream", "reddish brown", "burnt sienna",
        "brick", "sage", "grey green", "white",
        "s egg blue", "moss green", "steel blue", "eggplant",
        "light yellow", "leaf green", "light grey", "puke",
        "pinkish purple", "sea blue", "pale purple", "slate blue",
        "blue grey", "hunter green", "fuchsia", "crimson",
        "pale yellow", "ochre", "mustard yellow", "light red",
        "cerulean", "pale pink", "deep blue", "rust",
        "light teal", "slate", "goldenrod", "dark yellow",
        "dark grey", "army green", "grey blue", "seafoam",
        "puce", "spring green", "dark orange", "sand",
        "pastel green", "mint", "light orange", "bright pink",
        "chartreuse", "deep purple", "dark brown", "taupe",
        "pea green", "puke green", "kelly green", "seafoam green",
        "blue green", "khaki", "burgundy", "dark teal",
        "brick red", "royal purple", "plum", "mint green",
        "gold", "baby blue", "yellow green", "bright purple",
        "dark red", "pale blue", "grass green", "navy",
        "aquamarine", "burnt orange", "neon green", "bright blue",
        "rose", "light pink", "mustard", "indigo",
        "lime", "sea green", "periwinkle", "dark pink",
        "olive green", "peach", "pale green", "light brown",
        "hot pink", "black", "lilac", "navy blue",
        "royal blue", "beige", "salmon", "olive",
        "maroon", "bright green", "dark purple", "mauve",
        "forest green", "aqua", "cyan", "tan",
        "dark blue", "lavender", "turquoise", "dark green",
        "violet", "light purple", "lime green", "grey",
        "sky blue", "yellow", "magenta", "light green",
        "orange", "teal", "light blue", "red",
        "brown", "pink", "blue", "green",
        "purple"
        };

        private const uint32[] XKCD_RGB = {
        0xACC2D9, 0x56AE57, 0xB2996E, 0xA8FF04, 0x69D84F, 0x894585, 0x70B23F, 0xD4FFFF,
        0x65AB7C, 0x952E8F, 0xFCFC81, 0xA5A391, 0x388004, 0x4C9085, 0x5E9B8A, 0xEFB435,
        0xD99B82, 0x0A5F38, 0x0C06F7, 0x61DE2A, 0x3778BF, 0x2242C7, 0x533CC6, 0x9BB53C,
        0x05FFA6, 0x1F6357, 0x017374, 0x0CB577, 0xFF0789, 0xAFA88B, 0x08787F, 0xDD85D7,
        0xA6C875, 0xA7FFB5, 0xC2B709, 0xE78EA5, 0x966EBD, 0xCCAD60, 0xAC86A8, 0x947E94,
        0x983FB2, 0xFF63E9, 0xB2FBA5, 0x63B365, 0x8EE53F, 0xB7E1A1, 0xFF6F52, 0xBDF8A3,
        0xD3B683, 0xFFFCC4, 0x430541, 0xFFB2D0, 0x997570, 0xAD900D, 0xC48EFD, 0x507B9C,
        0x7D7103, 0xFFFD78, 0xDA467D, 0x410200, 0xC9D179, 0xFFFA86, 0x5684AE, 0x6B7C85,
        0x6F6C0A, 0x7E4071, 0x009337, 0xD0E429, 0xFFF917, 0x1D5DEC, 0x054907, 0xB5CE08,
        0x8FB67B, 0xC8FFB0, 0xFDDE6C, 0xFFDF22, 0xA9BE70, 0x6832E3, 0xFDB147, 0xC7AC7D,
        0xFFF39A, 0x850E04, 0xEFC0FE, 0x40FD14, 0xB6C406, 0x9DFF00, 0x3C4142, 0xF2AB15,
        0xAC4F06, 0xC4FE82, 0x2CFA1F, 0x9A6200, 0xCA9BF7, 0x875F42, 0x3A2EFE, 0xFD8D49,
        0x8B3103, 0xCBA560, 0x698339, 0x0CDC73, 0xB75203, 0x7F8F4E, 0x26538D, 0x63A950,
        0xC87F89, 0xB1FC99, 0xFF9A8A, 0xF6688E, 0x76FDA8, 0x53FE5C, 0x4EFD54, 0xA0FEBF,
        0x7BF2DA, 0xBCF5A6, 0xCA6B02, 0x107AB0, 0x2138AB, 0x719F91, 0xFDB915, 0xFEFCAF,
        0xFCF679, 0x1D0200, 0xCB6843, 0x31668A, 0x247AFD, 0xFFFFB6, 0x90FDA9, 0x86A17D,
        0xFDDC5C, 0x78D1B6, 0x13BBAF, 0xFB5FFC, 0x20F986, 0xFFE36E, 0x9D0759, 0x3A18B1,
        0xC2FF89, 0xD767AD, 0x720058, 0xFFDA03, 0x01C08D, 0xAC7434, 0x014600, 0x9900FA,
        0x02066F, 0x8E7618, 0xD1768F, 0x96B403, 0xFDFF63, 0x95A3A6, 0x7F684E, 0x751973,
        0x089404, 0xFF6163, 0x598556, 0x214761, 0x3C73A8, 0xBA9E88, 0x021BF9, 0x734A65,
        0x23C48B, 0x8FAE22, 0xE6F2A2, 0x4B57DB, 0xD90166, 0x015482, 0x9D0216, 0x728F02,
        0xFFE5AD, 0x4E0550, 0xF9BC08, 0xFF073A, 0xC77986, 0xD6FFFE, 0xFE4B03, 0xFD5956,
        0xFCE166, 0xB2713D, 0x1F3B4D, 0x699D4C, 0x56FCA2, 0xFB5581, 0x3E82FC, 0xA0BF16,
        0xD6FFFA, 0x4F738E, 0xFFB19A, 0x5C8B15, 0x54AC68, 0x89A0B0, 0x7EA07A, 0x1BFC06,
        0xCAFFFB, 0xB6FFBB, 0xA75E09, 0x152EFF, 0x8D5EB7, 0x5F9E8F, 0x63F7B4, 0x606602,
        0xFC86AA, 0x8C0034, 0x758000, 0xAB7E4C, 0x030764, 0xFE86A4, 0xD5174E, 0xFED0FC,
        0x680018, 0xFEDF08, 0xFE420F, 0x6F7C00, 0xCA0147, 0x1B2431, 0x00FBB0, 0xDB5856,
        0xDDD618, 0x41FDFE, 0xCF524E, 0x21C36F, 0xA90308, 0x6E1005, 0xFE828C, 0x4B6113,
        0x4DA409, 0xBEAE8A, 0x0339F8, 0xA88F59, 0x5D21D0, 0xFEB209, 0x4E518B, 0x964E02,
        0x85A3B2, 0xFF69AF, 0xC3FBF4, 0x2AFEB7, 0x005F6A, 0x0C1793, 0xFFFF81, 0xF0833A,
        0xF1F33F, 0xB1D27B, 0xFC824A, 0x71AA34, 0xB7C9E2, 0x4B0101, 0xA552E6, 0xAF2F0D,
        0x8B88F8, 0x9AF764, 0xA6FBB2, 0xFFC512, 0x750851, 0xC14A09, 0xFE2F4A, 0x0203E2,
        0x0A437A, 0xA50055, 0xAE8B0C, 0xFD798F, 0xBFAC05, 0x3EAF76, 0xC74767, 0xB9484E,
        0x647D8E, 0xBFFE28, 0xD725DE, 0xB29705, 0x673A3F, 0xA87DC2, 0xFAFE4B, 0xC0022F,
        0x0E87CC, 0x8D8468, 0xAD03DE, 0x8CFF9E, 0x94AC02, 0xC4FFF7, 0xFDEE73, 0x33B864,
        0xFFF9D0, 0x758DA3, 0xF504C9, 0x77A1B5, 0x8756E4, 0x889717, 0xC27E79, 0x017371,
        0x9F8303, 0xF7D560, 0xBDF6FE, 0x75B84F, 0x9CBB04, 0x29465B, 0x696006, 0xADF802,
        0xC1C6FC, 0x35AD6B, 0xFFFD37, 0xA442A0, 0xF36196, 0x947706, 0xFFF4F2, 0x1E9167,
        0xB5C306, 0xFEFF7F, 0xCFFDBC, 0x0ADD08, 0x87FD05, 0x1EF876, 0x7BFDC7, 0xBCECAC,
        0xBBF90F, 0xAB9004, 0x1FB57A, 0x00555A, 0xA484AC, 0xC45508, 0x3F829D, 0x548D44,
        0xC95EFB, 0x3AE57F, 0x016795, 0x87A922, 0xF0944D, 0x5D1451, 0x25FF29, 0xD0FE1D,
        0xFFA62B, 0x01B44C, 0xFF6CB5, 0x6B4247, 0xC7C10C, 0xB7FFFA, 0xAEFF6E, 0xEC2D01,
        0x76FF7B, 0x730039, 0x040348, 0xDF4EC8, 0x6ECB3C, 0x8F9805, 0x5EDC1F, 0xD94FF5,
        0xC8FD3D, 0x070D0D, 0x4984B8, 0x51B73B, 0xAC7E04, 0x4E5481, 0x876E4B, 0x58BC08,
        0x2FEF10, 0x2DFE54, 0x0AFF02, 0x9CEF43, 0x18D17B, 0x35530A, 0x1805DB, 0x6258C4,
        0xFF964F, 0xFFAB0F, 0x8F8CE7, 0x24BCA8, 0x3F012C, 0xCBF85F, 0xFF724C, 0x280137,
        0xB36FF6, 0x48C072, 0xBCCB7A, 0xA8415B, 0x06B1C4, 0xCD7584, 0xF1DA7A, 0xFF0490,
        0x805B87, 0x50A747, 0xA8A495, 0xCFFF04, 0xFFFF7E, 0xFF7FA7, 0xEF4026, 0x3C9992,
        0x886806, 0x04F489, 0xFEF69E, 0xCFAF7B, 0x3B719F, 0xFDC1C5, 0x20C073, 0x9B5FC0,
        0x0F9B8E, 0x742802, 0x9DB92C, 0xA4BF20, 0xCD5909, 0xADA587, 0xBE013C, 0xB8FFEB,
        0xDC4D01, 0xA2653E, 0x638B27, 0x419C03, 0xB1FF65, 0x9DBCD4, 0xFDFDFE, 0x77AB56,
        0x464196, 0x990147, 0xBEFD73, 0x32BF84, 0xAF6F09, 0xA0025C, 0xFFD8B1, 0x7F4E1E,
        0xBF9B0C, 0x6BA353, 0xF075E6, 0x7BC8F6, 0x475F94, 0xF5BF03, 0xFFFEB6, 0xFFFD74,
        0x895B7B, 0x436BAD, 0xD0C101, 0xC6F808, 0xF43605, 0x02C14D, 0xB25F03, 0x2A7E19,
        0x490648, 0x536267, 0x5A06EF, 0xCF0234, 0xC4A661, 0x978A84, 0x1F0954, 0x03012D,
        0x2BB179, 0xC3909B, 0xA66FB5, 0x770001, 0x922B05, 0x7D7F7C, 0x990F4B, 0x8F7303,
        0xC83CB9, 0xFEA993, 0xACBB0D, 0xC071FE, 0xCCFD7F, 0x00022E, 0x828344, 0xFFC5CB,
        0xAB1239, 0xB0054B, 0x99CC04, 0x937C00, 0x019529, 0xEF1DE7, 0x000435, 0x42B395,
        0x9D5783, 0xC8ACA9, 0xC87606, 0xAA2704, 0xE4CBFF, 0xFA4224, 0x0804F9, 0x5CB200,
        0x76424E, 0x6C7A0E, 0xFBDD7E, 0x2A0134, 0x044A05, 0xFD4659, 0x0D75F8, 0xFE0002,
        0xCB9D06, 0xFB7D07, 0xB9CC81, 0xEDC8FF, 0x61E160, 0x8AB8FE, 0x920A4E, 0xFE02A2,
        0x9A3001, 0x65FE08, 0xBEFDB7, 0xB17261, 0x885F01, 0x02CCFE, 0xC1FD95, 0x836539,
        0xFB2943, 0x84B701, 0xB66325, 0x7F5112, 0x5FA052, 0x6DEDFD, 0x0BF9EA, 0xC760FF,
        0xFFFFCB, 0xF6CEFC, 0x155084, 0xF5054F, 0x645403, 0x7A5901, 0xA8B504, 0x3D9973,
        0x000133, 0x76A973, 0x2E5A88, 0x0BF77D, 0xBD6C48, 0xAC1DB8, 0x2BAF6A, 0x26F7FD,
        0xAEFD6C, 0x9B8F55, 0xFFAD01, 0xC69C04, 0xF4D054, 0xDE9DAC, 0x05480D, 0xC9AE74,
        0x60460F, 0x98F6B0, 0x8AF1FE, 0x2EE8BB, 0x11875D, 0xFDB0C0, 0xB16002, 0xF7022A,
        0xD5AB09, 0x86775F, 0xC69F59, 0x7A687F, 0x042E60, 0xC88D94, 0xA5FBD5, 0xFFFE71,
        0x6241C7, 0xFFFE40, 0xD3494E, 0x985E2B, 0xA6814C, 0xFF08E8, 0x9D7651, 0xFEFFCA,
        0x98568D, 0x9E003A, 0x287C37, 0xB96902, 0xBA6873, 0xFF7855, 0x94B21C, 0xC5C9C7,
        0x661AEE, 0x6140EF, 0x9BE5AA, 0x7B5804, 0x276AB3, 0xFEB308, 0x8CFD7E, 0x6488EA,
        0x056EEE, 0xB27A01, 0x0FFEF9, 0xFA2A55, 0x820747, 0x7A6A4F, 0xF4320C, 0xA13905,
        0x6F828A, 0xA55AF4, 0xAD0AFD, 0x004577, 0x658D6D, 0xCA7B80, 0x005249, 0x2B5D34,
        0xBFF128, 0xB59410, 0x2976BB, 0x014182, 0xBB3F3F, 0xFC2647, 0xA87900, 0x82CBB2,
        0x667C3E, 0xFE46A5, 0xFE83CC, 0x94A617, 0xA88905, 0x7F5F00, 0x9E43A2, 0x062E03,
        0x8A6E45, 0xCC7A8B, 0x9E0168, 0xFDFF38, 0xC0FA8B, 0xEEDC5B, 0x7EBD01, 0x3B5B92,
        0x01889F, 0x3D7AFD, 0x5F34E7, 0x6D5ACF, 0x748500, 0x706C11, 0x3C0008, 0xCB00F5,
        0x002D04, 0x658CBB, 0x749551, 0xB9FF66, 0x9DC100, 0xFAEE66, 0x7EFBB3, 0x7B002C,
        0xC292A1, 0x017B92, 0xFCC006, 0x657432, 0xD8863B, 0x738595, 0xAA23FF, 0x08FF08,
        0x9B7A01, 0xF29E8E, 0x6FC276, 0xFF5B00, 0xFDFF52, 0x866F85, 0x8FFE09, 0xEECFFE,
        0x510AC9, 0x4F9153, 0x9F2305, 0x728639, 0xDE0C62, 0x916E99, 0xFFB16D, 0x3C4D03,
        0x7F7053, 0x77926F, 0x010FCC, 0xCEAEFA, 0x8F99FB, 0xC6FCFF, 0x5539CC, 0x544E03,
        0x017A79, 0x01F9C6, 0xC9B003, 0x929901, 0x0B5509, 0xA00498, 0x2000B1, 0x94568C,
        0xC2BE0E, 0x748B97, 0x665FD1, 0x9C6DA5, 0xC44240, 0xA24857, 0x825F87, 0xC9643B,
        0x90B134, 0x01386A, 0x25A36F, 0x59656D, 0x75FD63, 0x21FC0D, 0x5A86AD, 0xFEC615,
        0xFFFD01, 0xDFC5FE, 0xB26400, 0x7F5E00, 0xDE7E5D, 0x048243, 0xFFFFD4, 0x3B638C,
        0xB79400, 0x84597E, 0x411900, 0x7B0323, 0x04D9FF, 0x667E2C, 0xFBEEAC, 0xD7FFFE,
        0x4E7496, 0x874C62, 0xD5FFFF, 0x826D8C, 0xFFBACD, 0xD1FFBD, 0x448EE4, 0x05472A,
        0xD5869D, 0x3D0734, 0x4A0100, 0xF8481C, 0x02590F, 0x89A203, 0xE03FD8, 0xD58A94,
        0x7BB274, 0x526525, 0xC94CBE, 0xDB4BDA, 0x9E3623, 0xB5485D, 0x735C12, 0x9C6D57,
        0x028F1E, 0xB1916E, 0x49759C, 0xA0450E, 0x39AD48, 0xB66A50, 0x8CFFDB, 0xA4BE5C,
        0xCB7723, 0x05696B, 0xCE5DAE, 0xC85A53, 0x96AE8D, 0x1FA774, 0x7A9703, 0xAC9362,
        0x01A049, 0xD9544D, 0xFA5FF7, 0x82CAFC, 0xACFFFC, 0xFCB001, 0x910951, 0xFE2C54,
        0xC875C4, 0xCDC50A, 0xFD411E, 0x9A0200, 0xBE6400, 0x030AA7, 0xFE019A, 0xF7879A,
        0x887191, 0xB00149, 0x12E193, 0xFE7B7C, 0xFF9408, 0x6A6E09, 0x8B2E16, 0x696112,
        0xE17701, 0x0A481E, 0x343837, 0xFFB7CE, 0x6A79F7, 0x5D06E9, 0x3D1C02, 0x82A67D,
        0xBE0119, 0xC9FF27, 0x373E02, 0xA9561E, 0xCAA0FF, 0xCA6641, 0x02D8E9, 0x88B378,
        0x980002, 0xCB0162, 0x5CAC2D, 0x769958, 0xA2BFFE, 0x10A674, 0x06B48B, 0xAF884A,
        0x0B8B87, 0xFFA756, 0xA2A415, 0x154406, 0x856798, 0x34013F, 0x632DE9, 0x0A888A,
        0x6F7632, 0xD46A7E, 0x1E488F, 0xBC13FE, 0x7EF4CC, 0x76CD26, 0x74A662, 0x80013F,
        0xB1D1FC, 0xFFFFE4, 0x0652FF, 0x045C5A, 0x5729CE, 0x069AF3, 0xFF000D, 0xF10C45,
        0x5170D7, 0xACBF69, 0x6C3461, 0x5E819D, 0x601EF9, 0xB0DD16, 0xCDFD02, 0x2C6FBB,
        0xC0737A, 0xD6B4FC, 0x020035, 0x703BE7, 0xFD3C06, 0x960056, 0x40A368, 0x03719C,
        0xFC5A50, 0xFFFFC2, 0x7F2B0A, 0xB04E0F, 0xA03623, 0x87AE73, 0x789B73, 0xFFFFFF,
        0x98EFF9, 0x658B38, 0x5A7D9A, 0x380835, 0xFFFE7A, 0x5CA904, 0xD8DCD6, 0xA5A502,
        0xD648D7, 0x047495, 0xB790D4, 0x5B7C99, 0x607C8E, 0x0B4008, 0xED0DD9, 0x8C000F,
        0xFFFF84, 0xBF9005, 0xD2BD0A, 0xFF474C, 0x0485D1, 0xFFCFDC, 0x040273, 0xA83C09,
        0x90E4C1, 0x516572, 0xFAC205, 0xD5B60A, 0x363737, 0x4B5D16, 0x6B8BA4, 0x80F9AD,
        0xA57E52, 0xA9F971, 0xC65102, 0xE2CA76, 0xB0FF9D, 0x9FFEB0, 0xFDAA48, 0xFE01B1,
        0xC1F80A, 0x36013F, 0x341C02, 0xB9A281, 0x8EAB12, 0x9AAE07, 0x02AB2E, 0x7AF9AB,
        0x137E6D, 0xAAA662, 0x610023, 0x014D4E, 0x8F1402, 0x4B006E, 0x580F41, 0x8FFF9F,
        0xDBB40C, 0xA2CFFE, 0xC0FB2D, 0xBE03FD, 0x840000, 0xD0FEFE, 0x3F9B0B, 0x01153E,
        0x04D8B2, 0xC04E01, 0x0CFF0C, 0x0165FC, 0xCF6275, 0xFFD1DF, 0xCEB301, 0x380282,
        0xAAFF32, 0x53FCA1, 0x8E82FE, 0xCB416B, 0x677A04, 0xFFB07C, 0xC7FDB5, 0xAD8150,
        0xFF028D, 0x000000, 0xCEA2FD, 0x001146, 0x0504AA, 0xE6DAA6, 0xFF796C, 0x6E750E,
        0x650021, 0x01FF07, 0x35063E, 0xAE7181, 0x06470C, 0x13EAC9, 0x00FFFF, 0xD1B26F,
        0x00035B, 0xC79FEF, 0x06C2AC, 0x033500, 0x9A0EEA, 0xBF77F6, 0x89FE05, 0x929591,
        0x75BBFD, 0xFFFF14, 0xC20078, 0x96F97B, 0xF97306, 0x029386, 0x95D0FC, 0xE50000,
        0x653700, 0xFF81C0, 0x0343DF, 0x15B01A, 0x7E1E9C
        };
    }
}
