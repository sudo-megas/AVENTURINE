# AVENTURINE

Authoritative design document. If code and this file disagree, this file wins — change it here first, then change the code.

`aventurine` is a screen colour picker for Linux. Pick a pixel, get every representation of that colour worth having, keep a history of what you picked. It does one thing and it is not tied to any one desktop.

Status: pre-v1.0. Target: `v1.0`.

---

## Contents

- [1. What it is](#1-what-it-is)
- [2. Non-goals](#2-non-goals)
- [3. Platform, stack, dependencies](#3-platform-stack-dependencies)
- [4. Repository layout](#4-repository-layout)
- [5. Architecture — the source ladder](#5-architecture--the-source-ladder)
- [6. Capture backends](#6-capture-backends)
- [7. Backend selection and diagnostics](#7-backend-selection-and-diagnostics)
- [8. Colour model and conversions](#8-colour-model-and-conversions)
- [9. Format rows](#9-format-rows)
- [10. Contrast](#10-contrast)
- [11. Tints and shades](#11-tints-and-shades)
- [12. History and persistence](#12-history-and-persistence)
- [13. Export](#13-export)
- [14. User interface](#14-user-interface)
- [15. Theme](#15-theme)
- [16. Keyboard](#16-keyboard)
- [17. About page](#17-about-page)
- [18. Versioning, packaging, release](#18-versioning-packaging-release)
- [19. Accepted trade-offs](#19-accepted-trade-offs)

---

## 1. What it is

A single-window GTK4 application. You press the pick button, the compositor's own colour-picker crosshair appears, you click a pixel, and the window fills with:

- fourteen textual representations of that colour
- contrast ratios against white and black with WCAG verdicts
- a strip of five tints and five shades
- a running history of everything picked, capped at 100

Every row is click-to-copy. Nothing is copied automatically.

The design constraint that shapes everything else: **the app must keep working when the desktop underneath it changes.** It talks to standardised interfaces, never to a specific compositor.

## 2. Non-goals

Two hard bans, and only two:

- **No telemetry, analytics, crash reporting, or data collection of any kind.**
- **No network access.** The binary opens no socket. There is no update check, no remote palette service, no link fetching.

Everything else is permitted and can be added when it earns its place — export formats, palette editing, extra colour spaces, whatever comes later. There is no list of forbidden features beyond the two above.

## 3. Platform, stack, dependencies

| Item | Choice |
|---|---|
| Platforms | Linux only, permanently. Documented as a design decision, not a limitation |
| Language | Vala |
| Toolkit | GTK4 |
| Build | Plain `Makefile` invoking `valac` |
| Licence | GPL-3.0-or-later |
| UI language | English only in v1.0 |

Runtime dependencies, complete:

| Dependency | Why it is genuinely needed |
|---|---|
| `gtk4` | The entire user interface, plus image decoding via `GdkPixbuf` and clipboard access via `Gdk.Clipboard` |
| `glib2` | Provides `GLib` and `GIO`. `GIO` carries the D-Bus client used to talk to the portal, so no separate D-Bus or portal library is required |

Build-time only: `vala`, `pkgconf`, `make`, `gcc`.

That is two runtime libraries, both of which are already present on any system running a GTK application. There is deliberately no `libportal` — the two D-Bus calls the app makes are short enough to write directly against `GIO`, and adding a library to save forty lines would be a dependency that does no real work.

## 4. Repository layout

```text
AVENTURINE/
├── CORE.md
├── B1.md
├── LICENSE
├── README.md
├── Makefile
├── src/
│   ├── main.vala
│   ├── window.vala
│   ├── about.vala
│   ├── colour.vala
│   ├── convert.vala
│   ├── contrast.vala
│   ├── ramp.vala
│   ├── names.vala
│   ├── history.vala
│   ├── export.vala
│   ├── theme.vala
│   ├── doctor.vala
│   └── source/
│       ├── colour-source.vala
│       ├── portal-source.vala
│       └── image-source.vala
├── data/
│   ├── banner.svg
│   ├── io.github.sudomegas.aventurine.desktop
│   ├── io.github.sudomegas.aventurine.svg
│   └── style.css
├── tests/
│   ├── convert-test.vala
│   ├── portal-test.vala
│   ├── mock-portal.vala
│   └── run-portal-test.sh
├── packaging/
│   ├── arch/PKGBUILD
│   └── debian/
│       ├── control
│       └── rules
└── .github/workflows/build.yml
```

Naming that must not drift:

| Thing | Value |
|---|---|
| Binary | `aventurine` |
| Application ID | `io.github.sudomegas.aventurine` |
| Repository | `github.com/sudo-megas/AVENTURINE` |
| Arch package | `aventurine` |
| Debian package | `aventurine` |

## 5. Architecture — the source ladder

Nothing above the capture layer knows how a colour was obtained. Define one interface and implement it several times:

```vala
public struct Rgb {
    public double r;
    public double g;
    public double b;
}

public interface ColourSource : Object {
    public abstract string id { get; }
    public abstract string label { get; }
    public abstract bool probe ();
    public abstract async Rgb? pick () throws Error;
}
```

`probe()` is cheap, synchronous, and must never prompt the user or draw anything — it answers "could this backend plausibly work right now". `pick()` is async and returns `null` when the user cancels, which is not an error.

A `SourceLadder` object holds an ordered list of sources, runs `probe()` on each at startup, caches the first that answers, and re-probes if a `pick()` later fails. Everything else in the app — the conversions, the UI, the history — is platform-agnostic and untouched by any of this.

This is the entire reason the app survives a desktop change. Moving from Niri to KDE swaps which backend answers `probe()`. No other code notices.

## 6. Capture backends

### 6.1 Portal `PickColor` — primary

Calls `org.freedesktop.portal.Screenshot.PickColor` on the session bus. Works on GNOME, KDE, COSMIC, Hyprland, sway and wlroots compositors, and Niri — anywhere a portal backend implements the method.

The call is asynchronous in an unusual way: the method returns immediately with an object path, and the actual answer arrives later as a `Response` signal on that path. Subscribe **before** making the call, or the answer is missed.

The request path is constructed, not returned:

```text
/org/freedesktop/portal/desktop/request/SENDER/TOKEN
```

`SENDER` is the connection's unique bus name with the leading `:` removed and every `.` replaced by `_`. `TOKEN` is any valid object-path element the app chooses and passes as the `handle_token` option.

| Field | Value |
|---|---|
| Bus name | `org.freedesktop.portal.Desktop` |
| Object | `/org/freedesktop/portal/desktop` |
| Interface | `org.freedesktop.portal.Screenshot` |
| Method | `PickColor(s parent_window, a{sv} options) → (o handle)` |
| Response signal | `org.freedesktop.portal.Request.Response(u code, a{sv} results)` |
| Success code | `0` — `1` is user cancellation, `2` is failure |
| Result key | `color`, type `(ddd)`, three doubles in the range 0 to 1 |

`probe()` for this backend checks that the `org.freedesktop.portal.Desktop` name is owned on the session bus and that the `Screenshot` interface reports a non-zero `version` property. It does **not** attempt a real pick, since that would throw a crosshair at the user on startup.

### 6.2 Image source — fallback that cannot fail

Open a PNG or JPEG, or paste an image from the clipboard, and pick a pixel from it. No platform interface involved, so `probe()` always returns `true`. This guarantees the app is never completely useless, and it is genuinely useful on its own — pulling a colour out of a screenshot or a photograph.

Implemented with `Gdk.Texture` for display and `GdkPixbuf` for pixel access. The click coordinate is mapped back through the display scale factor to source pixels before reading.

### 6.3 Layers held for later

Two more rungs exist in the design and are deliberately not in v1.0:

- **Frozen frame** — call the portal's `Screenshot` method with `interactive: false`, display the resulting image full-screen, and let the user click a pixel in it. Covers desktops that have a screenshot backend but no `PickColor`, and because the app owns the pixels it is also where a magnifier lens would come from.
- **X11 `XGetImage`** — for a genuine X11 session, gated on `XDG_SESSION_TYPE=x11` and loaded via `dlopen` so it never becomes a link-time dependency.

Both slot into the ladder without touching anything above it. That is the point of the interface.

## 7. Backend selection and diagnostics

Selection order: portal, then image. First to pass `probe()` wins, and the winner is cached for the session.

`AVENTURINE_SOURCE=portal|image` forces a specific backend, skipping probing. This is the only environment variable the app reads and exists for debugging.

`aventurine --doctor` prints the ladder with a verdict per rung and exits:

```text
aventurine 1.0
session type   wayland
portal owner   org.freedesktop.portal.Desktop present
Screenshot     version 2
  portal       ok
  image        ok
selected       portal
```

> [!IMPORTANT]
> When no backend passes, the window still opens. A banner across the top explains that no screen-capture backend answered and points at `--doctor`; image picking stays available. The app never exits silently and never presents an empty window with no explanation.

## 8. Colour model and conversions

Everything is stored internally as three doubles in the range 0 to 1, non-linear sRGB, exactly as the portal returns them. All conversions derive from that.

### 8.1 Gamma

```text
linearise(c) = c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4
encode(c)    = c <= 0.0031308 ? c * 12.92 : 1.055 * c ^ (1 / 2.4) - 0.055
```

### 8.2 Relative luminance

Computed from **linearised** channels:

```text
Y = 0.2126 R + 0.7152 G + 0.0722 B
```

### 8.3 CIEXYZ, D65

```text
X = 0.4124564 R + 0.3575761 G + 0.1804375 B
Y = 0.2126729 R + 0.7151522 G + 0.0721750 B
Z = 0.0193339 R + 0.1191920 G + 0.9503041 B
```

White point: `Xn = 0.95047`, `Yn = 1.00000`, `Zn = 1.08883`.

### 8.4 CIELAB and LCH

```text
e = 216 / 24389
k = 24389 / 27
f(t) = t > e ? cbrt(t) : (k * t + 16) / 116

L* = 116 * f(Y / Yn) - 16
a* = 500 * (f(X / Xn) - f(Y / Yn))
b* = 200 * (f(Y / Yn) - f(Z / Zn))

C  = sqrt(a*^2 + b*^2)
H  = atan2(b*, a*) in degrees, normalised to 0..360
```

> [!NOTE]
> This uses a **D65** white point. CSS Color 4's `lab()` function uses D50, so values shown here will differ slightly from a browser's. This is a deliberate choice for internal consistency with the sRGB working space, and it is stated in the README so the difference never looks like a bug.

### 8.5 OKLab and OKLCH

From **linearised** sRGB:

```text
l = 0.4122214708 R + 0.5363325363 G + 0.0514459929 B
m = 0.2119034982 R + 0.6806995451 G + 0.1073969566 B
s = 0.0883024619 R + 0.2817188376 G + 0.6299787005 B

l' = cbrt(l)   m' = cbrt(m)   s' = cbrt(s)

L = 0.2104542553 l' + 0.7936177850 m' - 0.0040720468 s'
a = 1.9779984951 l' - 2.4285922050 m' + 0.4505937099 s'
b = 0.0259040371 l' + 0.7827717662 m' - 0.8086757660 s'
```

Inverse, needed for the tint and shade ramp:

```text
l' = L + 0.3963377774 a + 0.2158037573 b
m' = L - 0.1055613458 a - 0.0638541728 b
s' = L - 0.0894841775 a - 1.2914855480 b

l = l'^3   m = m'^3   s = s'^3

R = +4.0767416621 l - 3.3077115913 m + 0.2309699292 s
G = -1.2684380046 l + 2.6097574011 m - 0.3413193965 s
B = -0.0041960863 l - 0.7034186147 m + 1.7076147010 s
```

Then gamma-encode. OKLCH polar form is the same `C` and `H` derivation as §8.4.

### 8.6 The remaining spaces

| Space | Derivation |
|---|---|
| HSL, HSV | Standard hexcone from non-linear sRGB |
| HWB | `W = min(R,G,B)`, `Bl = 1 - max(R,G,B)`, hue as in HSL |
| CMYK | `K = 1 - max(R,G,B)`, `C = (1-R-K)/(1-K)` and so on. Undefined channels are zero when `K = 1` |
| Linear RGB | §8.1 applied per channel, shown as 0 to 1 |

### 8.7 Gamut handling

Converting back from OKLCH can land outside sRGB. v1.0 clamps each channel to the range 0 to 1 after encoding. Chroma reduction toward the gamut boundary is the perceptually correct answer and is a candidate for a later version; the clamp is documented rather than hidden.

## 9. Format rows

Fourteen rows, in this order. Each is a label, a monospace value, and a copy affordance.

| # | Row | Example output |
|---|---|---|
| 1 | HEX | `#A1B2C3` |
| 2 | RGB | `rgb(161, 178, 195)` |
| 3 | RGB percent | `rgb(63.1%, 69.8%, 76.5%)` |
| 4 | HSL | `hsl(210, 22%, 70%)` |
| 5 | HSV | `hsv(210, 17%, 76%)` |
| 6 | HWB | `hwb(210 63% 24%)` |
| 7 | CMYK | `cmyk(17%, 9%, 0%, 24%)` |
| 8 | Linear RGB | `0.356 0.445 0.546` |
| 9 | LAB | `lab(71.80 -2.29 -10.62)` |
| 10 | LCH | `lch(71.80 10.86 257.8)` |
| 11 | OKLCH | `oklch(0.756 0.031 248.2)` |
| 12 | Relative luminance | `0.4336` |
| 13 | Nearest CSS name | `darkgray` |
| 14 | Nearest xkcd name | `light grey blue` |

Hex is **uppercase**. Precision: HSL, HSV, HWB and CMYK are integers; LAB, LCH and OKLCH carry two, two and three decimals respectively; linear RGB three; luminance four. Hue carries one decimal in LCH and OKLCH.

> [!NOTE]
> The example column above is computed by the formulas in section 8 and is pinned by `tests/convert-test.vala`. An earlier draft of this table carried hand-worked values for rows 4, 8, 9, 10, 11, 12 and 13 that section 8 does not produce; they were corrected against the formulas rather than the formulas against them. Row 13 is `darkgray` because `#A9A9A9` really is nearer to `#A1B2C3` than `#B0C4DE` is under plain Euclidean distance in OKLab — a chroma-weighted metric would answer `lightsteelblue`, and that is a candidate for a later version, not a v1.0 change.

Nearest-name matching runs in OKLab with plain Euclidean distance, which is close enough to perceptual for a name label and far better than distance in sRGB.

> [!NOTE]
> The CSS named-colour table is 148 entries and is embedded directly. The xkcd survey list is 949 entries; if it cannot be vendored into the repository at build time, row 14 is dropped and deferred rather than approximated. A wrong colour name is worse than no colour name.

## 10. Contrast

Two rows, against white and against black:

```text
ratio = (Lmax + 0.05) / (Lmin + 0.05)
```

using relative luminance from §8.2. Each row shows the ratio to two decimals and four badges — AA normal at 4.5, AA large at 3.0, AAA normal at 7.0, AAA large at 4.5 — each pass or fail.

## 11. Tints and shades

Five tints and five shades, generated in OKLCH by holding chroma and hue and moving lightness:

```text
tint i  (i = 1..5) : L + (1 - L) * i / 6
shade i (i = 1..5) : L - L * i / 6
```

Rendered as a single eleven-swatch strip with the picked colour in the middle. Clicking a swatch copies its hex; it does not become the current colour.

## 12. History and persistence

| Property | Value |
|---|---|
| Location | `$XDG_CONFIG_HOME/aventurine/history.toml`, falling back to `~/.config/aventurine/history.toml` |
| Format | TOML, hand-written and hand-parsed — the schema is three fields |
| Cap | 100 entries, oldest evicted first |
| Per entry | Uppercase hex, ISO 8601 timestamp, backend id that captured it |

```toml
[[entry]]
hex = "#A1B2C3"
at = "2026-08-25T14:03:11+03:00"
source = "portal"
```

Writes are atomic: write to `history.toml.tmp` in the same directory, `fsync`, then `rename`. A malformed file is tolerated, not fatal — parse what is readable, skip what is not, and never overwrite until the user picks something new.

Every row has a delete control on hover. Clear all requires confirmation.

## 13. Export

Two formats, both writing the current history:

**GIMP palette** — `.gpl`:

```text
GIMP Palette
Name: AVENTURINE
Columns: 8
#
161 178 195	#A1B2C3
```

**CSS custom properties** — `.css`:

```css
:root {
  --aventurine-1: #A1B2C3;
  --aventurine-2: #4E6E5D;
}
```

The destination is chosen through `Gtk.FileDialog`, which routes through the FileChooser portal — no assumptions about the user's file manager.

## 14. User interface

Single window, 420 × 640, resizable, not always-on-top. Vertical order:

1. **Header** — the picked colour as a large swatch filling roughly 30% of the height, with the hex printed over it. The text is black or white, chosen by whether the colour's relative luminance exceeds 0.179.
2. **Pick button** — full width, directly under the header.
3. **Format rows** — the fourteen rows of §9 in a scrolling list.
4. **Contrast block** — the two rows of §10.
5. **Ramp strip** — the eleven swatches of §11.
6. **History** — a list, newest first, each row a small swatch plus hex plus relative time.

Copying is always explicit. Clicking a row copies that row's value and shows a toast naming what was copied. Nothing lands on the clipboard without a click.

On first run, before anything is picked, the header shows a neutral placeholder and the format rows are absent rather than showing zeros.

## 15. Theme

The app follows the desktop. Read `org.freedesktop.portal.Settings.ReadOne` for namespace `org.freedesktop.appearance`, key `color-scheme`:

| Value | Meaning |
|---|---|
| `0` | No preference |
| `1` | Prefer dark |
| `2` | Prefer light |

Set `Gtk.Settings.gtk_application_prefer_dark_theme` accordingly, and subscribe to `SettingChanged` so a live theme switch is picked up without a restart. If the Settings portal is absent, fall back to the GTK default and do nothing clever.

There is no theme toggle and no settings window. `data/style.css` carries only the handful of rules GTK's defaults do not cover.

## 16. Keyboard

| Key | Action |
|---|---|
| `Space` or `Ctrl+P` | Pick |
| `Ctrl+C` | Copy hex |
| `1` to `9` | Copy the value of that numbered format row |
| `Ctrl+Shift+C` | Clear history, with confirmation |
| `Ctrl+E` | Export |
| `Escape` | Close window |

## 17. About page

Shows: maker, version, release date, source address, active capture backend, and the full GPL-3.0 text. Addresses are selectable text and **not** clickable — the app opens no browser and follows no link, which follows from the no-network rule in §2 rather than being a separate policy.

## 18. Versioning, packaging, release

Tags are two-numeral: `v1.0`, then `v1.1`, `v1.2`. Not `v1.0.0`.

Two artifacts, both built in CI, both attached to the GitHub release:

| Artifact | Built by | In |
|---|---|---|
| `aventurine-1.0-1-x86_64.pkg.tar.zst` | `makepkg` | `archlinux:base-devel` container |
| `aventurine_1.0-1_amd64.deb` | `dpkg-deb` | `debian:trixie` container |

No portable tarball, no AppImage, no Flatpak in v1.0.

Adding the package to the `megas-xlr` repository is a manual step performed locally after release, because it needs the signing key `62328913D18D8EC3`, which never leaves the machine and is never present in CI.

## 19. Accepted trade-offs

Stated plainly so none of them looks like a defect later:

- **No magnifier lens.** The portal hands back one colour and nothing else. A zoom lens requires owning the screen pixels, which is the frozen-frame layer in §6.3. The compositor's own crosshair is used instead.
- **No colour profile.** The portal's `PickColor` returns three numbers with no profile attached — there is no way to know which display they came from or what its profile is. Values are treated as sRGB. On a wide-gamut display such as a QD-OLED panel, they will not match what a colour-managed application reports.
- **LAB uses D65, not CSS's D50.** See §8.4.
- **Out-of-gamut ramp entries are clamped, not gamut-mapped.** See §8.7.
- **No global hotkey.** That needs the GlobalShortcuts portal and a running session service. Bind `aventurine` in the compositor's own configuration instead; the README shows how for Niri, Hyprland, KDE and GNOME.
