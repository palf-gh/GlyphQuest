#!/bin/sh
set -e

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
PREVIEW_ROOT="${ROOT}/build/ThemePreview"
CAPTURE_BIN="${ROOT}/build/ThemeSampleCapture"
OUTPUT_DIR="${ROOT}/docs"

mkdir -p "${PREVIEW_ROOT}/Fonts" "${PREVIEW_ROOT}/Themes" "${OUTPUT_DIR}"

python3 "${ROOT}/scripts/compile_themes.py" \
	--source "${ROOT}/Resources/Themes" \
	--output "${PREVIEW_ROOT}/Themes"

cp "${ROOT}/Resources/Fonts/"*.ttf "${PREVIEW_ROOT}/Fonts/"

for theme_dir in "${ROOT}/Resources/Themes"/*; do
	[ -d "${theme_dir}" ] || continue
	theme_id="$(basename "${theme_dir}")"
	mkdir -p "${PREVIEW_ROOT}/Themes/${theme_id}"
	for asset in "${theme_dir}"/*.png; do
		[ -f "${asset}" ] || continue
		cp "${asset}" "${PREVIEW_ROOT}/Themes/${theme_id}/"
	done
done

clang -fobjc-arc -framework Cocoa -framework CoreText \
	-I "${ROOT}" \
	-o "${CAPTURE_BIN}" \
	"${ROOT}/tools/ThemeSampleCapture/GQThemePreviewCaptureMain.m" \
	"${ROOT}/GQPalettePanel.m" \
	"${ROOT}/GQThemeLoader.m" \
	"${ROOT}/GQProgressRenderer.m"

GLYPHQUEST_RESOURCE_BUNDLE="${PREVIEW_ROOT}" \
GLYPHQUEST_SAMPLES_OUTPUT="${OUTPUT_DIR}" \
"${CAPTURE_BIN}"
