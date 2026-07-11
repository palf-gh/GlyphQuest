---
name: glyphquest-theme-assets
description: >
  Create or replace GlyphQuest theme assets and YAML recipes under
  Resources/Themes/<id>/. Use when generating theme PNGs, editing theme.yaml,
  progress layer recipes, hex colours, card 3-slice geometry, toggle sprites,
  or compile_themes.py output.
---

# GlyphQuest Theme Asset Rules

Use this guide whenever creating or replacing a GlyphQuest theme. The Forest
theme is the visual and structural baseline. Rich bitmap art is welcome;
incompatible geometry is not.

## Directory layout

Each theme lives in its own folder:

```text
Resources/
  Fonts/                     # bundled .ttf + OFL.txt
  Themes/
    <id>/
      theme.yaml             # source (edit this)
      scene.png
      card.png
      toggle-off.png
      toggle-on.png
      progress-*.png         # optional progress overlays
```

The folder name must match `id` in `theme.yaml`. At build time,
`scripts/compile_themes.py` compiles each `theme.yaml` to `theme.json` in the
app bundle (`build/CompiledThemes/` when run locally). Source folders stay
YAML-only; JSON is never committed next to YAML.

## Required PNG assets — hard geometry

Every theme uses these text-free PNG files in `Resources/Themes/<id>/`:

```text
scene.png
card.png
toggle-off.png
toggle-on.png
```

Do not use a white, black, or chroma-key background. Export with real alpha.

### `scene.png` (background)

| Rule | Value |
|------|-------|
| Content | Background only — no card, UI text, controls, or fake HUD chrome |
| Aspect | **Ultrawide ≈ 2.93:1** (match Forest / Candy / Ocean) |
| Canonical size | **2146 × 733** px (or any size with the same ratio) |
| Draw mode | Aspect-filled into the palette bounds |

**Do not** ship 16:9 (1.78:1) scenes. They crop differently and look “zoomed”
compared with other themes. After generation, cover-crop to 2146×733.

### `card.png` (panel)

| Rule | Value |
|------|-------|
| Canvas | **Exactly 500 × 380** px RGBA |
| Opaque body margins | Match Forest: about **6 px left/right**, **7 px top/bottom** |
| Outer corners | Transparent (true alpha), not baked grey/white |
| Centre | Quiet, stretch-safe fill between 3-slice caps |

**Critical:** Target geometry is **500 × 380** with Forest margins (~6/6/7/7),
i.e. an opaque body of **488 × 366 (exactly 4:3)**.

Authoring rules:
1. Generate the panel on a **solid chroma-key green (`#00FF00`)** backdrop. The
   panel itself must be **exactly 4:3**, centred, with green margins remaining
   (do not full-bleed a 3:2 plate). Key out green → true alpha.
2. Place with **uniform scale only** into 500 × 380. **Never** non-uniformly
   stretch. **Never** cover-crop ornaments. **Never** invent height with
   mid-band expand if the keyed panel is already the wrong ratio — regenerate.
3. Settings bay: empty / faint recess only (Cocoa draws the gear). No baked cog.

Verify with:

```sh
python3 - <<'PY'
from PIL import Image
im = Image.open("Resources/Themes/<id>/card.png").convert("RGBA")
w, h = im.size
px = im.load()
xs, ys = [], []
for y in range(h):
    for x in range(w):
        if px[x, y][3] > 10:
            xs.append(x); ys.append(y)
print("size", w, h, "margin LRTB",
      min(xs), w-1-max(xs), min(ys), h-1-max(ys))
# Expect roughly: 6 6 7 7  (Forest baseline)
PY
```

### `toggle-off.png` / `toggle-on.png`

| Rule | Value |
|------|-------|
| Canvas | **Exactly 220 × 58** px RGBA |
| Opaque body margins | About **4 px left/right**, **2–5 px top/bottom** (near Forest) |
| Silhouette | Same bounds for off and on |
| Face | Fully opaque readable button face — never outline-only |
| Content | No text, knob, switch, gear, or labels (Cocoa draws the title) |
| Scale | **Never non-uniformly stretch.** Author at 220×58 (or crop + *uniform* scale). |

Do not leave huge transparent side gutters (30–50 px). Do not take a square/tall
generated button and squash it into 220×58 — that reads as a stretched texture.
Prefer: (1) generate/draw a wide thin button already near ~4:1, then uniform
cover/fit; or (2) build the sprite at exact 220×58 from theme materials.

## theme.yaml essentials

Colours use hex: `#RRGGBB` or `#RRGGBBAA`.

```yaml
id: forest
names:
  en: Forest Quest
  ja: 森のクエスト
  zh: 森林任务
  ko: 숲의 퀘스트
percent_font: Quicksand-Bold
card:
  left_cap: 135
  right_cap: 118
  title_leading: 56
colours:
  title: "#663F1CFF"
  percent: "#56381FFF"
  # ...
progress:
  shape:
    bezel_radius: auto      # auto = half height (pill)
    track_radius: auto
    fill_radius: auto
  fill_mode: continuous     # continuous | segments
  bezel: { top: "#...", bottom: "#...", stroke: "#..." }
  track: { top: "#...", bottom: "#...", stroke: "#..." }
  fill: ["#...", "#...", "#..."]
  near_fill: ["#...", "#...", "#..."]
  complete_fill: ["#...", "#...", "#..."]
  track_layers: []
  fill_layers:
    - kind: stripes
      angle: -55
      width: 7
      spacing: 12
      colour: "#FFFFFF29"
  gloss:
    enabled: true
    colour: "#FFFFFF"
    alpha: 0.22
```

Card caps and `title_leading` live in `theme.yaml` under `card:`. Do not edit
ObjC for per-theme colours or progress styling.

### Text colour guidance

- Light parchment / cream cards (Forest, Candy, Moonlight paper): dark brown /
  ink text is fine.
- Dark metal / neon / deep leather faces (Cyber, Strike, Leather Bound): use
  **near-white** for `title`, `percent`, `count`, `toggle_text`, and
  `settings_text` so labels stay readable on the card art.

## Progress layer recipes

Decorations are composable layers, not hard-coded theme branches.

| kind | key parameters |
|------|----------------|
| `lines` | `angle`, `spacing`, `thickness`, `colour`, `inset`, `dash: [on, off]` |
| `stripes` | `angle`, `width`, `spacing`, `colour` |
| `shapes` | `shape: oval\|rect\|diamond\|star\|parallelogram`, `spacing`, `size`, `size_alt`, `colour`, `y: mid\|top\|bottom\|jitter`; for `parallelogram` also `width`, `shear`, `inset_y` |
| `grid` | `x_spacing`, `y_spacing`, `colour`, `thickness` |
| `speckle` | `density`, `size`, `colour`, `seed` |
| `gradient` | `colours`, `angle`, `blend: normal\|screen\|multiply` |
| `image` | `file`, `mode: stretch\|tile\|aspect_fill`, `opacity`, `inset` |

Optional PNG overlays:

```yaml
progress:
  overlays:
    bezel: { file: progress-bezel.png, mode: stretch, opacity: 1.0 }
    track: { file: progress-track-overlay.png, mode: tile, opacity: 0.7 }
    fill:  { file: progress-fill-overlay.png, mode: stretch, opacity: 0.9 }
```

Use `fill_mode: segments` with `segments: { width, gap, inset_y, shape, shear }` for
segmented fills (e.g. Cyber). Set `shape: parallelogram` for bottom-left →
top-right tactical bars.

### Gauge corner styles

Under `progress.shape`:

```yaml
shape:
  corner: chamfer          # default is rounded (omit or use radius keys)
  chamfer: 5               # fallback cut size
  bezel_chamfer: 5
  track_chamfer: 3.5
  fill_chamfer: 3
  # optional *_small variants for script-row gauges
```

`corner: chamfer` draws a rectangle with diagonally cut corners instead of
rounded radii. Radius keys (`bezel_radius`, etc.) are ignored while chamfer is
active.

Optional leading-edge tip for the continuous fill (bezel/track stay chamfered):

```yaml
shape:
  corner: chamfer
  fill_end: slant            # full-height `/` cut on the progress tip
  fill_end_shear: auto       # auto ≈ fill height; or a px number
```

The tip shear collapses to 0 at 100% (full cover, cut hidden) and the fill is
hidden until there is enough width to form the tip (so ≈0% shows no leading edge).
Match overlay patterns to the same `/` direction (`parallelogram` with
`shear: auto`, or `lines` / `stripes` at `angle: 135`).

## Card composition and 3-slice safety

Cards use horizontal 3-slice scaling. Keep unique left decoration inside
`card.left_cap` and right decoration inside `card.right_cap`.

- The centre between caps must be a quiet, stretch-safe fill.
- Cap boundaries must blend into the centre at 250 px, 425 px, and wide widths.
- Keep the title-start ornament in the upper-left cap, compatible with
  `title_leading`.
- Reserve the upper-right interior for the 94 x 25 text button.
- Reserve the lower-right interior for the 26 x 26 settings button.
  Keep that bay **empty or only a faint recess** — Cocoa draws the gear on
  top. Do not bake a clear gear, cog, badge, or metallic settings icon into
  `card.png`.
- Keep the central percentage, gauge, and count areas quiet.

When caps change, update `card.left_cap`, `card.right_cap`, and
`card.title_leading` together in `theme.yaml`.

## Theme identity

Each theme needs a distinct material language:

- Forest: parchment, gold trim, soft green growth.
- Cyber: angular panels, circuit/grid language, segmented gauge, cyan/magenta glow.
- Moonlight: indigo paper, gold filigree, stars and lunar details.
- Candy: frosting trim, bright cream material, playful stripes.
- Ocean: pearl and wave trim, watery glass, bubbles and coral details.
- Y2K: glossy pop chrome, star accents, pastel neon gradients.
- Strike: dark brushed metal, chamfered HUD, red neon accents (no trademark names).
- Leather: stitched leather panel, warm grain, embossed corners; prefer light text.
  Author scene / toggles / card as separate continuous images at their real draw
  sizes — do **not** tile a card crop across the scene or buttons to “match scale”.

The large percentage uses `percent_font`. Other UI text stays on the system
font for reliable CJK rendering.

## Adding a new theme

1. Copy the nearest `Resources/Themes/<id>/` folder to a new ID.
2. Replace `scene.png`, `card.png`, `toggle-off.png`, `toggle-on.png`.
3. **Normalise geometry** to the hard rules above (scene ratio, card/toggle
   margins) before shipping.
4. Edit `theme.yaml` (colours, card caps, progress shape/layers/overlays).
5. Run `python3 scripts/compile_themes.py` (or build in Xcode).
6. Commit `theme.yaml` + PNGs; `theme.json` is a build artefact.

No ObjC changes are required unless adding a new progress layer kind.

## Image-generation workflow

1. Generate scene, card, and two toggle frames **separately**.
2. Prompt for ultrawide scene (~3:1), not 16:9.
3. Prompt for card/toggle with the panel filling most of the frame (small outer
   margin only).
4. Remove any generated words, numbers, pseudo-icons, baked-in gear, or switch knobs.
5. Key out studio backdrops and normalise **without non-uniform stretch**:
   - scene → 2146×733 cover-crop (uniform scale)
   - card → 500×380 with Forest-like LRTB margins (uniform scale + crop/pad)
   - toggles → **author at exact 220×58** or uniform scale only; never squash a
     square/tall generated button into the wide slot
6. Run the margin verification snippet above; reject assets with large empty
   transparent bands or visibly stretched grain/stitches/borders.
7. Render the card at narrow, ordinary, and extremely wide widths before use.
8. Verify both normal progress and script-list mode for every theme.

## Interaction and visual QA

- Custom-drawn controls remain `NSButton` instances.
- Add interactive controls after the scroll view so they stay frontmost.
- Test settings popover, theme selection, and script toggle with real clicks.
- Resize the Glyphs sidebar narrower and wider after theme changes.
- Compare new themes side-by-side with Forest in the sample gallery: title,
  percent, bar, and gear must sit on the same vertical rhythm.

## Related skill

**glyphquest-create-theme** — end-to-end workflow to scaffold
`Resources/Themes/<id>/`, write `theme.yaml`, compile JSON, and build. When PNGs
are missing and image generation is available, start that skill; it will invoke
this asset skill for image rules and generation.
