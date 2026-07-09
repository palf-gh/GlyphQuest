#!/usr/bin/env python3
"""Generate initial theme.yaml files from the legacy Objective-C theme registry."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
THEMES_DIR = ROOT / "Resources" / "Themes"


def hx(r: float, g: float, b: float, a: float = 1.0) -> str:
    rr, gg, bb, aa = int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), int(round(a * 255))
    if aa >= 255:
        return f"#{rr:02X}{gg:02X}{bb:02X}"
    return f"#{rr:02X}{gg:02X}{bb:02X}{aa:02X}"


def dump_yaml(data, indent=0) -> str:
    lines: list[str] = []
    pad = "  " * indent
    if isinstance(data, dict):
        for key, value in data.items():
            if isinstance(value, (dict, list)):
                if isinstance(value, list) and not value:
                    lines.append(f"{pad}{key}: []")
                elif isinstance(value, dict) and not value:
                    lines.append(f"{pad}{key}: {{}}")
                else:
                    lines.append(f"{pad}{key}:")
                    lines.append(dump_yaml(value, indent + 1))
            elif isinstance(value, bool):
                lines.append(f"{pad}{key}: {'true' if value else 'false'}")
            elif value is None:
                lines.append(f"{pad}{key}: null")
            elif isinstance(value, str):
                if any(ch in value for ch in ':#{}[],&*?|>-\'"%@`'):
                    lines.append(f'{pad}{key}: "{value}"')
                else:
                    lines.append(f"{pad}{key}: {value}")
            else:
                lines.append(f"{pad}{key}: {value}")
    elif isinstance(data, list):
        for item in data:
            if isinstance(item, dict):
                first = True
                for key, value in item.items():
                    if first:
                        if isinstance(value, (dict, list)):
                            lines.append(f"{pad}- {key}:")
                            lines.append(dump_yaml(value, indent + 2))
                        elif isinstance(value, str) and any(ch in value for ch in ':#{}[],&*?|>-\'"%@`'):
                            lines.append(f'{pad}- {key}: "{value}"')
                        else:
                            lines.append(f"{pad}- {key}: {value}")
                        first = False
                    else:
                        if isinstance(value, (dict, list)):
                            lines.append(f"{pad}  {key}:")
                            lines.append(dump_yaml(value, indent + 2))
                        elif isinstance(value, str) and any(ch in value for ch in ':#{}[],&*?|>-\'"%@`'):
                            lines.append(f'{pad}  {key}: "{value}"')
                        else:
                            lines.append(f"{pad}  {key}: {value}")
            elif isinstance(item, str):
                if any(ch in item for ch in ':#{}[],&*?|>-\'"%@`'):
                    lines.append(f'{pad}- "{item}"')
                else:
                    lines.append(f"{pad}- {item}")
            else:
                lines.append(f"{pad}- {item}")
    return "\n".join(lines)


def colours(**kwargs):
    return {key: hx(*rgba) if isinstance(rgba, tuple) else rgba for key, rgba in kwargs.items()}


def progress_colours(**kwargs):
    out = {}
    for key, value in kwargs.items():
        if isinstance(value, dict):
            out[key] = {sub_key: hx(*sub_value) if isinstance(sub_value, tuple) else sub_value for sub_key, sub_value in value.items()}
        elif isinstance(value, list):
            out[key] = [hx(*item) if isinstance(item, tuple) else item for item in value]
        elif isinstance(value, tuple):
            out[key] = hx(*value)
        else:
            out[key] = value
    return out


THEMES = {
    "forest": {
        "id": "forest",
        "names": {"en": "Forest Quest", "ja": "森のクエスト", "zh": "森林任务", "ko": "숲의 퀘스트"},
        "percent_font": "Quicksand-Bold",
        "card": {"left_cap": 135, "right_cap": 118, "title_leading": 56},
        "colours": colours(
            title=(0.40, 0.25, 0.11, 1.0),
            progress_title=(0.30, 0.20, 0.11, 1.0),
            percent=(0.34, 0.22, 0.12, 1.0),
            count=(0.33, 0.50, 0.16, 1.0),
            toggle_text=(1.0, 1.0, 1.0, 1.0),
            toggle_shadow=(0.43, 0.17, 0.02, 0.70),
            settings_text=(1.0, 1.0, 1.0, 1.0),
            row_text=(0.31, 0.20, 0.10, 1.0),
            row_percent=(0.20, 0.50, 0.16, 1.0),
            row_top=(1.00, 0.94, 0.76, 0.92),
            row_bottom=(0.94, 0.80, 0.48, 0.92),
            row_stroke=(0.58, 0.35, 0.12, 0.68),
            row_accent=(0.55, 0.80, 0.24, 0.95),
        ),
        "progress": {
            "shape": {"bezel_radius": "auto", "track_radius": "auto", "fill_radius": "auto", "gloss_radius": "auto"},
            "fill_mode": "continuous",
            **progress_colours(
                bezel={"top": (0.99, 0.79, 0.34, 1.0), "bottom": (0.83, 0.52, 0.13, 1.0), "stroke": (0.54, 0.31, 0.08, 0.95)},
                track={"top": (0.82, 0.67, 0.37, 1.0), "bottom": (0.98, 0.87, 0.58, 1.0), "stroke": (0.48, 0.30, 0.10, 0.46)},
                rim=(1.0, 0.96, 0.72, 0.58),
                shadow=(0.25, 0.13, 0.03, 0.22),
                fill=[(0.25, 0.62, 0.10, 1.0), (0.45, 0.80, 0.18, 1.0), (0.72, 0.94, 0.32, 1.0)],
                near_fill=[(0.78, 0.52, 0.08, 1.0), (0.95, 0.72, 0.18, 1.0), (1.00, 0.88, 0.38, 1.0)],
                complete_fill=[(0.62, 0.42, 0.05, 1.0), (0.92, 0.68, 0.12, 1.0), (1.00, 0.94, 0.45, 1.0)],
                fill_stroke=(0.25, 0.47, 0.10, 0.85),
                near_fill_stroke=(0.55, 0.38, 0.06, 0.85),
                complete_fill_stroke=(0.65, 0.45, 0.05, 0.90),
            ),
            "track_layers": [],
            "fill_layers": [{"kind": "stripes", "angle": -55, "width": 7, "spacing": 12, "colour": "#FFFFFF29"}],
            "gloss": {"enabled": True, "colour": "#FFFFFF", "alpha": 0.20},
        },
    },
    "cyber": {
        "id": "cyber",
        "names": {"en": "Cyber Neon", "ja": "サイバーネオン", "zh": "赛博霓虹", "ko": "사이버 네온"},
        "percent_font": "Orbitron-Black",
        "card": {"left_cap": 205, "right_cap": 128, "title_leading": 56},
        "colours": colours(
            title=(0.78, 0.98, 1.00, 1.0),
            progress_title=(0.36, 0.91, 1.00, 1.0),
            percent=(0.94, 0.98, 1.00, 1.0),
            count=(0.37, 0.92, 1.00, 1.0),
            toggle_text=(1.0, 1.0, 1.0, 1.0),
            toggle_shadow=(0.00, 0.05, 0.14, 0.90),
            settings_text=(0.88, 1.00, 1.00, 1.0),
            row_text=(0.88, 0.96, 1.00, 1.0),
            row_percent=(0.38, 0.94, 1.00, 1.0),
            row_top=(0.07, 0.14, 0.27, 0.93),
            row_bottom=(0.03, 0.07, 0.16, 0.93),
            row_stroke=(0.35, 0.92, 1.00, 0.72),
            row_accent=(1.00, 0.20, 0.85, 0.95),
        ),
        "progress": {
            "shape": {
                "bezel_radius": 3,
                "track_radius": 1.5,
                "fill_radius": 1,
                "gloss_radius": 0.5,
                "bezel_radius_small": 1.5,
                "track_radius_small": 0.75,
                "fill_radius_small": 0.5,
                "gloss_radius_small": 0.5,
            },
            "fill_mode": "continuous",
            **progress_colours(
                bezel={"top": (0.28, 0.92, 1.00, 1.0), "bottom": (0.50, 0.13, 0.94, 1.0), "stroke": (0.62, 0.96, 1.00, 0.95)},
                track={"top": (0.03, 0.07, 0.14, 1.0), "bottom": (0.10, 0.15, 0.28, 1.0), "stroke": (0.31, 0.84, 1.00, 0.55)},
                rim=(0.82, 0.98, 1.00, 0.70),
                shadow=(0.00, 0.00, 0.10, 0.46),
                fill=[(0.00, 0.48, 1.00, 1.0), (0.00, 0.92, 1.00, 1.0), (0.95, 0.18, 1.00, 1.0)],
                near_fill=[(0.52, 0.18, 1.00, 1.0), (1.00, 0.20, 0.86, 1.0), (1.00, 0.72, 0.20, 1.0)],
                complete_fill=[(0.92, 0.97, 1.00, 1.0), (0.18, 0.96, 1.00, 1.0), (1.00, 0.20, 0.86, 1.0)],
                fill_stroke=(0.25, 0.87, 1.00, 0.90),
                near_fill_stroke=(1.00, 0.40, 0.88, 0.90),
                complete_fill_stroke=(0.88, 0.98, 1.00, 0.95),
            ),
            "track_layers": [
                {"kind": "lines", "angle": 90, "spacing": 14, "thickness": 0.75, "colour": "#47F0FF40", "inset": 2, "offset_x": 8}
            ],
            "fill_layers": [
                {"kind": "shapes", "shape": "rect", "spacing": 9, "width": 4, "inset_y": 2, "colour": "#EBFFFF61", "offset_x": 4}
            ],
            "gloss": {"enabled": True, "colour": "#FFFFFF", "alpha": 0.22},
        },
    },
    "moonlight": {
        "id": "moonlight",
        "names": {"en": "Moonlight Magic", "ja": "月夜の魔法", "zh": "月光魔法", "ko": "달빛 마법"},
        "percent_font": "Cinzel-Black",
        "card": {"left_cap": 190, "right_cap": 138, "title_leading": 56},
        "colours": colours(
            title=(0.26, 0.17, 0.42, 1.0),
            progress_title=(0.86, 0.74, 1.00, 1.0),
            percent=(0.26, 0.17, 0.42, 1.0),
            count=(0.29, 0.22, 0.59, 1.0),
            toggle_text=(1.0, 1.0, 1.0, 1.0),
            toggle_shadow=(0.04, 0.03, 0.18, 0.86),
            settings_text=(1.00, 0.92, 0.68, 1.0),
            row_text=(0.94, 0.90, 1.00, 1.0),
            row_percent=(0.96, 0.77, 1.00, 1.0),
            row_top=(0.14, 0.13, 0.33, 0.94),
            row_bottom=(0.07, 0.08, 0.22, 0.94),
            row_stroke=(0.86, 0.72, 0.30, 0.70),
            row_accent=(0.67, 0.42, 1.00, 0.95),
        ),
        "progress": {
            "shape": {"bezel_radius": "auto", "track_radius": "auto", "fill_radius": "auto", "gloss_radius": "auto"},
            "fill_mode": "continuous",
            **progress_colours(
                bezel={"top": (0.97, 0.78, 0.30, 1.0), "bottom": (0.35, 0.25, 0.80, 1.0), "stroke": (0.94, 0.76, 0.34, 0.95)},
                track={"top": (0.07, 0.08, 0.22, 1.0), "bottom": (0.18, 0.17, 0.37, 1.0), "stroke": (0.83, 0.67, 0.33, 0.55)},
                rim=(1.00, 0.88, 0.58, 0.62),
                shadow=(0.03, 0.02, 0.13, 0.44),
                fill=[(0.30, 0.36, 0.94, 1.0), (0.48, 0.36, 1.00, 1.0), (0.90, 0.58, 1.00, 1.0)],
                near_fill=[(0.58, 0.38, 1.00, 1.0), (0.86, 0.48, 1.00, 1.0), (1.00, 0.80, 0.32, 1.0)],
                complete_fill=[(0.76, 0.68, 1.00, 1.0), (1.00, 0.83, 0.35, 1.0), (1.00, 0.96, 0.70, 1.0)],
                fill_stroke=(0.62, 0.52, 1.00, 0.90),
                near_fill_stroke=(0.92, 0.58, 1.00, 0.90),
                complete_fill_stroke=(1.00, 0.84, 0.36, 0.95),
            ),
            "track_layers": [
                {"kind": "shapes", "shape": "oval", "spacing": 34, "size": 2.4, "colour": "#FFE06B2E", "offset_x": 12, "y": "mid"}
            ],
            "fill_layers": [
                {"kind": "shapes", "shape": "star", "spacing": 22, "size": 2.8, "size_alt": 1.8, "colour": "#FFEB7A5C", "offset_x": 10, "y": "mid"}
            ],
            "gloss": {"enabled": True, "colour": "#FFFFFF", "alpha": 0.20},
        },
    },
    "candy": {
        "id": "candy",
        "names": {"en": "Candy Workshop", "ja": "キャンディ工房", "zh": "糖果工坊", "ko": "캔디 공방"},
        "percent_font": "Nunito-ExtraBold",
        "card": {"left_cap": 175, "right_cap": 130, "title_leading": 56},
        "colours": colours(
            title=(0.68, 0.25, 0.39, 1.0),
            progress_title=(0.58, 0.31, 0.43, 1.0),
            percent=(0.56, 0.26, 0.31, 1.0),
            count=(0.19, 0.60, 0.53, 1.0),
            toggle_text=(1.0, 1.0, 1.0, 1.0),
            toggle_shadow=(0.40, 0.14, 0.24, 0.55),
            settings_text=(1.00, 1.00, 1.00, 1.0),
            row_text=(0.55, 0.24, 0.33, 1.0),
            row_percent=(0.15, 0.58, 0.52, 1.0),
            row_top=(1.00, 0.96, 0.80, 0.94),
            row_bottom=(1.00, 0.77, 0.87, 0.94),
            row_stroke=(0.96, 0.47, 0.67, 0.64),
            row_accent=(0.35, 0.84, 0.74, 0.95),
        ),
        "progress": {
            "shape": {"bezel_radius": "auto", "track_radius": "auto", "fill_radius": "auto", "gloss_radius": "auto"},
            "fill_mode": "continuous",
            **progress_colours(
                bezel={"top": (1.00, 0.93, 0.38, 1.0), "bottom": (0.98, 0.44, 0.68, 1.0), "stroke": (0.86, 0.33, 0.52, 0.92)},
                track={"top": (1.00, 0.91, 0.77, 1.0), "bottom": (1.00, 0.98, 0.88, 1.0), "stroke": (0.91, 0.50, 0.66, 0.48)},
                rim=(1.00, 1.00, 0.83, 0.66),
                shadow=(0.47, 0.18, 0.29, 0.22),
                fill=[(0.30, 0.78, 0.68, 1.0), (0.92, 0.58, 0.94, 1.0), (1.00, 0.80, 0.32, 1.0)],
                near_fill=[(1.00, 0.58, 0.42, 1.0), (1.00, 0.68, 0.28, 1.0), (1.00, 0.90, 0.46, 1.0)],
                complete_fill=[(0.42, 0.86, 0.76, 1.0), (1.00, 0.65, 0.82, 1.0), (1.00, 0.92, 0.47, 1.0)],
                fill_stroke=(0.56, 0.38, 0.74, 0.78),
                near_fill_stroke=(0.88, 0.48, 0.28, 0.82),
                complete_fill_stroke=(0.91, 0.44, 0.62, 0.85),
            ),
            "track_layers": [
                {"kind": "stripes", "angle": -55, "width": 5, "spacing": 14, "colour": "#FF8CB81F", "offset_x": 0}
            ],
            "fill_layers": [
                {"kind": "stripes", "angle": -55, "width": 5, "spacing": 11, "colour": "#FFFFFF4D"}
            ],
            "gloss": {"enabled": True, "colour": "#FFFFFF", "alpha": 0.20},
        },
    },
    "ocean": {
        "id": "ocean",
        "names": {"en": "Ocean Pearl", "ja": "海の真珠", "zh": "海洋珍珠", "ko": "바다 진주"},
        "percent_font": "Exo2-ExtraBold",
        "card": {"left_cap": 160, "right_cap": 135, "title_leading": 56},
        "colours": colours(
            title=(0.10, 0.41, 0.56, 1.0),
            progress_title=(0.13, 0.49, 0.64, 1.0),
            percent=(0.10, 0.34, 0.49, 1.0),
            count=(0.05, 0.56, 0.58, 1.0),
            toggle_text=(1.0, 1.0, 1.0, 1.0),
            toggle_shadow=(0.02, 0.18, 0.29, 0.62),
            settings_text=(0.96, 1.00, 1.00, 1.0),
            row_text=(0.09, 0.34, 0.47, 1.0),
            row_percent=(0.04, 0.56, 0.58, 1.0),
            row_top=(0.82, 0.98, 0.99, 0.94),
            row_bottom=(0.58, 0.88, 0.92, 0.94),
            row_stroke=(0.32, 0.70, 0.77, 0.64),
            row_accent=(0.18, 0.76, 0.70, 0.95),
        ),
        "progress": {
            "shape": {"bezel_radius": "auto", "track_radius": "auto", "fill_radius": "auto", "gloss_radius": "auto"},
            "fill_mode": "continuous",
            **progress_colours(
                bezel={"top": (0.70, 0.97, 1.00, 1.0), "bottom": (0.20, 0.59, 0.78, 1.0), "stroke": (0.15, 0.45, 0.62, 0.90)},
                track={"top": (0.58, 0.85, 0.90, 1.0), "bottom": (0.87, 0.99, 1.00, 1.0), "stroke": (0.19, 0.55, 0.68, 0.46)},
                rim=(0.92, 1.00, 1.00, 0.72),
                shadow=(0.02, 0.18, 0.28, 0.28),
                fill=[(0.04, 0.56, 0.88, 1.0), (0.16, 0.86, 0.83, 1.0), (0.55, 0.96, 0.78, 1.0)],
                near_fill=[(0.10, 0.71, 0.92, 1.0), (0.25, 0.90, 0.78, 1.0), (0.92, 0.94, 0.56, 1.0)],
                complete_fill=[(0.66, 0.96, 1.00, 1.0), (0.38, 0.92, 0.82, 1.0), (0.98, 0.96, 0.78, 1.0)],
                fill_stroke=(0.05, 0.49, 0.65, 0.82),
                near_fill_stroke=(0.07, 0.60, 0.70, 0.84),
                complete_fill_stroke=(0.30, 0.74, 0.76, 0.90),
            ),
            "track_layers": [
                {"kind": "shapes", "shape": "oval", "spacing": 28, "size": 4, "colour": "#FFFFFF2E", "stroke": True, "stroke_width": 0.7, "offset_x": 14, "y": "mid"}
            ],
            "fill_layers": [
                {"kind": "shapes", "shape": "oval", "spacing": 18, "size": 5.2, "size_alt": 3.4, "colour": "#FFFFFF47", "stroke": True, "stroke_width": 0.8, "offset_x": 7, "y": "mid"}
            ],
            "gloss": {"enabled": True, "colour": "#FFFFFF", "alpha": 0.20},
        },
    },
    "y2k": {
        "id": "y2k",
        "names": {"en": "Y2K Pop", "ja": "Y2Kポップ", "zh": "Y2K 流行", "ko": "Y2K 팝"},
        "percent_font": "Nunito-ExtraBold",
        "card": {"left_cap": 185, "right_cap": 140, "title_leading": 56},
        "colours": colours(
            title=(0.16, 0.31, 0.56, 1.0),
            progress_title=(0.20, 0.33, 0.62, 1.0),
            percent=(0.16, 0.28, 0.54, 1.0),
            count=(0.77, 0.15, 0.58, 1.0),
            toggle_text=(1.0, 1.0, 1.0, 1.0),
            toggle_shadow=(0.23, 0.08, 0.42, 0.38),
            settings_text=(1.00, 1.00, 1.00, 1.0),
            row_text=(0.19, 0.31, 0.56, 1.0),
            row_percent=(0.74, 0.14, 0.58, 1.0),
            row_top=(0.90, 0.98, 1.00, 0.96),
            row_bottom=(0.80, 0.89, 1.00, 0.96),
            row_stroke=(0.62, 0.52, 0.94, 0.60),
            row_accent=(0.96, 0.28, 0.70, 0.95),
        ),
        "progress": {
            "shape": {"bezel_radius": "auto", "track_radius": "auto", "fill_radius": "auto", "gloss_radius": "auto"},
            "fill_mode": "continuous",
            **progress_colours(
                bezel={"top": (0.96, 0.98, 1.00, 1.0), "bottom": (0.72, 0.52, 0.98, 1.0), "stroke": (0.36, 0.55, 0.88, 0.88)},
                track={"top": (0.88, 0.98, 1.00, 1.0), "bottom": (0.68, 0.88, 1.00, 1.0), "stroke": (0.46, 0.55, 0.86, 0.48)},
                rim=(1.00, 1.00, 1.00, 0.78),
                shadow=(0.30, 0.17, 0.58, 0.24),
                fill=[(0.10, 0.72, 0.96, 1.0), (0.38, 0.91, 1.00, 1.0), (0.94, 0.36, 0.80, 1.0)],
                near_fill=[(0.98, 0.26, 0.68, 1.0), (0.72, 0.30, 0.98, 1.0), (0.42, 0.82, 1.00, 1.0)],
                complete_fill=[(1.00, 0.84, 0.34, 1.0), (1.00, 0.42, 0.76, 1.0), (0.52, 0.92, 1.00, 1.0)],
                fill_stroke=(0.20, 0.54, 0.82, 0.84),
                near_fill_stroke=(0.78, 0.20, 0.66, 0.86),
                complete_fill_stroke=(0.91, 0.54, 0.22, 0.90),
            ),
            "track_layers": [
                {"kind": "shapes", "shape": "star", "spacing": 24, "size": 2.4, "size_alt": 1.5, "colour": "#FFFFFF6B", "offset_x": 11, "y": "mid"}
            ],
            "fill_layers": [
                {"kind": "shapes", "shape": "star", "spacing": 16, "size": 2.7, "size_alt": 1.7, "colour": "#FFFFFF75", "offset_x": 8, "y": "mid"}
            ],
            "gloss": {"enabled": True, "colour": "#FFFFFF", "alpha": 0.20},
        },
    },
}


def main() -> None:
    for theme_id, data in THEMES.items():
        theme_dir = THEMES_DIR / theme_id
        theme_dir.mkdir(parents=True, exist_ok=True)
        yaml_path = theme_dir / "theme.yaml"
        yaml_path.write_text(dump_yaml(data) + "\n", encoding="utf-8")
        print(f"Wrote {yaml_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
