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
      theme.json             # generated (committed; compile_themes.py)
      scene.png
      card.png
      toggle-off.png
      toggle-on.png
      progress-*.png         # optional progress overlays
```

The folder name must match `id` in `theme.yaml`. At build time,
`scripts/compile_themes.py` compiles each `theme.yaml` to `theme.json`.
Runtime loads JSON only via `GQThemeLoader`.

## Required PNG assets

Every theme uses these text-free PNG files in `Resources/Themes/<id>/`:

```text
scene.png
card.png
toggle-off.png
toggle-on.png
```

- `scene`: wide background only. No card, UI text, or controls. Aspect-filled.
- `card`: exactly 500 x 380 px RGBA PNG, with transparent outer corners and
  the same overall card placement and transparent margin rhythm as
  `Resources/Themes/forest/card.png`.
- `toggle-off` and `toggle-on`: exactly 220 x 58 px RGBA PNG. Same silhouette
  and bounds. Button frames, not switch controls; no knob, state label, glyph,
  or highlight outside the button body. Cocoa draws the localized label.
- Toggle sprites must include a fully opaque, readable central button face.
  Never use an outline-only sprite or leave a black/transparent interior.

Do not use a white, black, or chroma-key background. Export with real alpha.

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

## Progress layer recipes

Decorations are composable layers, not hard-coded theme branches.

| kind | key parameters |
|------|----------------|
| `lines` | `angle`, `spacing`, `thickness`, `colour`, `inset`, `dash: [on, off]` |
| `stripes` | `angle`, `width`, `spacing`, `colour` |
| `shapes` | `shape: oval\|rect\|diamond\|star`, `spacing`, `size`, `size_alt`, `colour`, `y: mid\|top\|bottom\|jitter` |
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

Use `fill_mode: segments` with `segments: { width, gap, inset_y }` for
segmented fills (e.g. Cyber) without custom code.

## Card composition and 3-slice safety

Cards use horizontal 3-slice scaling. Keep unique left decoration inside
`card.left_cap` and right decoration inside `card.right_cap`.

- The centre between caps must be a quiet, stretch-safe fill.
- Cap boundaries must blend into the centre at 250 px, 425 px, and wide widths.
- Keep the title-start ornament in the upper-left cap, compatible with
  `title_leading`.
- Reserve the upper-right interior for the 94 x 25 text button.
- Reserve the lower-right interior for the 26 x 26 settings button.
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

The large percentage uses `percent_font`. Other UI text stays on the system
font for reliable CJK rendering.

## Adding a new theme

1. Copy the nearest `Resources/Themes/<id>/` folder to a new ID.
2. Replace `scene.png`, `card.png`, `toggle-off.png`, `toggle-on.png`.
3. Edit `theme.yaml` (colours, card caps, progress shape/layers/overlays).
4. Run `python3 scripts/compile_themes.py` (or build in Xcode).
5. Commit both `theme.yaml` and generated `theme.json`.

No ObjC changes are required unless adding a new progress layer kind.

## Image-generation workflow

1. Generate scene, card, and two toggle frames separately.
2. Remove any generated words, numbers, pseudo-icons, baked-in gear, or switch knobs.
3. Normalise to required dimensions with genuine transparency.
4. Render the card at narrow, ordinary, and extremely wide widths before use.
5. Verify both normal progress and script-list mode for every theme.

## Interaction and visual QA

- Custom-drawn controls remain `NSButton` instances.
- Add interactive controls after the scroll view so they stay frontmost.
- Test settings popover, theme selection, and script toggle with real clicks.
- Resize the Glyphs sidebar narrower and wider after theme changes.

## Related skill

**glyphquest-create-theme** — end-to-end workflow to scaffold
`Resources/Themes/<id>/`, write `theme.yaml`, compile JSON, and build. When PNGs
are missing and image generation is available, start that skill; it will invoke
this asset skill for image rules and generation.
