---
name: glyphquest-create-theme
description: >
  End-to-end workflow to add a new GlyphQuest theme under Resources/Themes/<id>/.
  Use when the user asks to create, add, or scaffold a theme, or to produce
  theme.yaml plus required PNGs. When PNGs are missing and image generation is
  available, read and follow glyphquest-theme-assets to generate assets.
---

# GlyphQuest Create Theme

Orchestrates a full new theme from brief to build-ready files. Asset geometry,
PNG rules, and progress-layer syntax live in **glyphquest-theme-assets** — read
that skill before generating or placing any image.

## Inputs to confirm

Gather (or infer from the request):

| Field | Rule |
|-------|------|
| `id` | Lowercase ASCII, matches folder name (e.g. `aurora`) |
| `names` | `en`, `ja`, `zh`, `ko` display titles |
| Reference | Closest existing theme to copy (`forest`, `cyber`, …) |
| Visual brief | Material language, palette, mood |
| PNGs | Whether the user supplied `scene`, `card`, `toggle-off`, `toggle-on` |

Default reference: **forest** (pill gauge, simple stripes). Use **cyber** for
angular/segmented looks, **ocean** for bubbles, **moonlight** for stars, etc.

## Workflow checklist

Copy and track progress:

```text
- [ ] 1. Scaffold Resources/Themes/<id>/
- [ ] 2. Resolve PNG assets (user files or generated)
- [ ] 3. Write theme.yaml (colours, card caps, progress recipe)
- [ ] 4. Run compile_themes.py
- [ ] 5. Build Release and sync release/ if requested
- [ ] 6. Visual QA notes for the user
```

## Step 1 — Scaffold

```sh
REF=forest   # or nearest match
ID=<new-id>
cp -R "Resources/Themes/${REF}" "Resources/Themes/${ID}"
rm -f "Resources/Themes/${ID}/theme.yaml"
```

Keep copied PNGs only as temporary placeholders until real assets exist.

## Step 2 — PNG assets (decision)

Required files in `Resources/Themes/<id>/`:

```text
scene.png        # ultrawide ≈2.93:1 (canonical 2146×733), text-free
card.png         # 500×380 RGBA, Forest-like margins (~6/6/7/7 LRTB)
toggle-off.png   # 220×58 RGBA, text-free, Forest-like margins
toggle-on.png    # 220×58 RGBA, same silhouette as off
```

**Hard geometry** (scene ratio, card/toggle transparent margins, dark-card
white text) is defined in **glyphquest-theme-assets** — read that skill before
generating or accepting any PNG. Do not ship 16:9 scenes or cards with large
empty transparent bands above/below the panel.

### User already provided images

Replace placeholders with supplied files. Verify dimensions:

```sh
sips -g pixelWidth -g pixelHeight "Resources/Themes/${ID}/card.png"
sips -g pixelWidth -g pixelHeight "Resources/Themes/${ID}/toggle-off.png"
```

Resize if needed (card example):

```sh
sips -z 380 500 "Resources/Themes/${ID}/card.png"
sips -z 58 220 "Resources/Themes/${ID}/toggle-off.png"
sips -z 58 220 "Resources/Themes/${ID}/toggle-on.png"
```

Then **read glyphquest-theme-assets** and confirm 3-slice caps, toggle opacity,
and no baked-in text before continuing.

### Images not provided — generate when possible

**If image generation is available** (e.g. GenerateImage):

1. **Read glyphquest-theme-assets** in full and follow it for every asset.
2. Open `Resources/Themes/forest/` (or the chosen reference) to inspect baseline
   layout before prompting.
3. Generate **four separate images** — never one combined sheet:

| File | Size | Prompt focus |
|------|------|--------------|
| `scene.png` | ultrawide ≈2.93:1 (target 2146×733) | Background only; no card, text, or UI chrome — **not 16:9** |
| `card.png` | 500×380 | Game UI panel filling most of the frame; transparent outer corners; quiet centre; caps match reference rhythm |
| `toggle-off.png` | 220×58 | Button frame filling the canvas, opaque face, no text/knob/switch |
| `toggle-on.png` | 220×58 | Same silhouette as off; brighter/active material |

4. Save into `Resources/Themes/<id>/` with exact filenames above.
5. Normalise dimensions with `sips` if the generator output differs.
6. Re-read glyphquest-theme-assets **Image-generation workflow** and **Card
   composition** sections; reject and regenerate assets that include text,
   wrong geometry, or outline-only toggles.

**If image generation is not available:**

- Still scaffold `theme.yaml` and compile JSON so colours/progress work in code.
- List the four missing PNGs with sizes and constraints from
  glyphquest-theme-assets.
- Do not block YAML/compile work on missing art.

Optional progress overlays (`progress-bezel.png`, etc.) follow the same rule:
generate only when needed and when generation is available; otherwise document
what to add later.

## Step 3 — theme.yaml

Start from the reference theme YAML, then customise:

```yaml
id: <id>
names:
  en: ...
  ja: ...
  zh: ...
  ko: ...
percent_font: "Quicksand-Bold"   # or Orbitron-Black, Cinzel-Black, etc.
card:
  left_cap: 135                  # adjust with card art
  right_cap: 118
  title_leading: 56
colours:
  title: "#RRGGBB"
  # … all keys from reference theme
progress:
  shape:
    bezel_radius: auto           # or numeric for angular themes
    track_radius: auto
    fill_radius: auto
  fill_mode: continuous          # or segments
  # bezel, track, rim, shadow, fill, near_fill, complete_fill, strokes
  track_layers: []
  fill_layers: []                # layer recipe — see glyphquest-theme-assets
  gloss:
    enabled: true
    colour: "#FFFFFF"
    alpha: 0.2
```

Rules:

- Folder name, `id` in YAML, and `Resources/Themes/<id>/` must match.
- Colours: hex `#RRGGBB` or `#RRGGBBAA` only.
- Tune `card.left_cap` / `right_cap` together with the card PNG caps.
- Match progress decoration to the visual brief via `track_layers` /
  `fill_layers`; do not add ObjC theme branches.

Copy colour/progress starting points from the reference theme, then shift hex
values and layers toward the new brief.

## Step 4 — Compile

```sh
python3 scripts/compile_themes.py
```

This writes to `build/CompiledThemes/` for local validation. Xcode builds
compile straight into the app bundle via `scripts/bundle_themes.sh`.

Commit `theme.yaml` only — do not add `theme.json` beside it in
`Resources/Themes/`.

## Step 5 — Build (when validating)

```sh
xcodebuild -project GlyphQuest.xcodeproj -scheme GlyphQuest \
  -configuration Release -derivedDataPath DerivedData \
  SYMROOT=build OBJROOT=build/Intermediates build
```

Refresh shipped bundle when the user wants an installable plugin:

```sh
rm -rf release/GlyphQuest.glyphsPalette
cp -R build/Release/GlyphQuest.glyphsPalette release/
```

No `project.pbxproj` edits are needed — `Resources/Themes` is a folder reference.

## Step 6 — Handoff / QA

Tell the user:

- Theme ID and path
- Whether PNGs were user-supplied, generated, or still missing
- Suggested in-Glyphs checks: theme picker, wide/narrow sidebar, script-list mode,
  toggle and settings clicks

If assets were generated, warn that AI PNGs often need a manual alpha/3-slice pass
before shipping.

## Do not

- Edit the plan file or hard-code theme colours in ObjC
- Register themes manually in `GlyphQuestPalette.m`
- Ship placeholder Forest PNGs under a new theme ID without saying so
- Generate one image containing scene+card+toggles combined

## Related skill

**glyphquest-theme-assets** — mandatory read for PNG geometry, 3-slice caps,
toggle rules, progress layer kinds, and overlays. Invoke it whenever creating,
replacing, or reviewing theme images or YAML progress recipes.
