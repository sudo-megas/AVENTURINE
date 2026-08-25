/* The capture interface. CORE.md section 5.
 *
 * Nothing above this layer knows how a colour was obtained. Adding a rung to
 * the ladder — the frozen-frame and X11 layers held back in section 6.3 — means
 * implementing this interface and nothing else.
 */

namespace Aventurine {

    public interface ColourSource : Object {

        /* Stable identifier. Written into the history file and accepted by
         * AVENTURINE_SOURCE, so it must not drift: "portal", "image". */
        public abstract string id { get; }

        /* Human wording for --doctor and the about page. */
        public abstract string label { get; }

        /* Cheap, synchronous, and never prompts the user or draws anything.
         * It answers "could this backend plausibly work right now", nothing
         * more: a real capture attempt here would throw a crosshair at the
         * user on startup. */
        public abstract bool probe ();

        /* Returns null when the user cancels, which is not an error. */
        public abstract async Rgb? pick () throws Error;
    }
}
