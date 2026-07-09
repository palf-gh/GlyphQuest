#!/bin/sh
set -e

SOURCE_THEMES="${SRCROOT}/Resources/Themes"
OUT_THEMES="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/Themes"

python3 "${SRCROOT}/scripts/compile_themes.py" \
	--source "${SOURCE_THEMES}" \
	--output "${OUT_THEMES}"

for theme_dir in "${SOURCE_THEMES}"/*; do
	[ -d "${theme_dir}" ] || continue
	theme_id="$(basename "${theme_dir}")"
	mkdir -p "${OUT_THEMES}/${theme_id}"
	for asset in "${theme_dir}"/*.png; do
		[ -f "${asset}" ] || continue
		cp "${asset}" "${OUT_THEMES}/${theme_id}/"
	done
done
