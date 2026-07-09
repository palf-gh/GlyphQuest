#!/usr/bin/env python3
"""Compile Resources/Themes/*/theme.yaml to theme.json (stdlib only)."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
THEMES_DIR = ROOT / "Resources" / "Themes"


class YAMLParser:
    """Minimal YAML parser for GlyphQuest theme files."""

    def __init__(self, text: str) -> None:
        self.lines = text.splitlines()
        self.index = 0

    def parse(self):
        self.skip_blank()
        return self.parse_block(0)

    def skip_blank(self) -> None:
        while self.index < len(self.lines):
            stripped = self.lines[self.index].strip()
            if not stripped or stripped.startswith("#"):
                self.index += 1
                continue
            break

    def indent(self, line: str) -> int:
        return len(line) - len(line.lstrip(" "))

    def parse_block(self, base_indent: int):
        result: dict = {}
        while self.index < len(self.lines):
            self.skip_blank()
            if self.index >= len(self.lines):
                break
            line = self.lines[self.index]
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                self.index += 1
                continue
            indent = self.indent(line)
            if indent < base_indent:
                break
            if indent > base_indent:
                raise ValueError(f"Unexpected indent at line {self.index + 1}: {line}")
            if stripped.startswith("- "):
                return self.parse_list(base_indent)
            key, _, value = stripped.partition(":")
            key = key.strip()
            value = value.strip()
            self.index += 1
            if not value:
                self.skip_blank()
                if self.index < len(self.lines) and self.lines[self.index].strip().startswith("- "):
                    result[key] = self.parse_list(indent + 2)
                elif self.index < len(self.lines) and self.indent(self.lines[self.index]) > indent:
                    result[key] = self.parse_block(indent + 2)
                else:
                    result[key] = {}
            else:
                result[key] = self.parse_scalar(value)
        return result

    def parse_list(self, base_indent: int) -> list:
        items: list = []
        while self.index < len(self.lines):
            self.skip_blank()
            if self.index >= len(self.lines):
                break
            line = self.lines[self.index]
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                self.index += 1
                continue
            indent = self.indent(line)
            if indent < base_indent:
                break
            if not stripped.startswith("- "):
                break
            content = stripped[2:].strip()
            self.index += 1
            if not content:
                self.skip_blank()
                if self.index < len(self.lines) and self.lines[self.index].strip().startswith("- "):
                    items.append(self.parse_list(indent + 2))
                elif self.index < len(self.lines) and self.indent(self.lines[self.index]) > indent:
                    items.append(self.parse_block(indent + 2))
                else:
                    items.append({})
                continue
            if ": " in content or content.endswith(":"):
                item = self.parse_inline_mapping(content, indent)
                while self.index < len(self.lines):
                    self.skip_blank()
                    if self.index >= len(self.lines):
                        break
                    next_line = self.lines[self.index]
                    next_indent = self.indent(next_line)
                    if next_indent <= indent or next_line.strip().startswith("- "):
                        break
                    nested_key, _, nested_value = next_line.strip().partition(":")
                    nested_key = nested_key.strip()
                    nested_value = nested_value.strip()
                    self.index += 1
                    if not nested_value:
                        self.skip_blank()
                        if self.index < len(self.lines) and self.indent(self.lines[self.index]) > next_indent:
                            item[nested_key] = self.parse_block(next_indent + 2)
                        else:
                            item[nested_key] = {}
                    else:
                        item[nested_key] = self.parse_scalar(nested_value)
                items.append(item)
                continue
            items.append(self.parse_scalar(content))
        return items

    def parse_inline_mapping(self, content: str, indent: int) -> dict:
        key, _, value = content.partition(":")
        key = key.strip()
        value = value.strip()
        item: dict = {}
        if value:
            item[key] = self.parse_scalar(value)
        else:
            self.skip_blank()
            if self.index < len(self.lines) and self.indent(self.lines[self.index]) > indent:
                item[key] = self.parse_block(indent + 2)
            else:
                item[key] = {}
        return item

    def parse_scalar(self, value: str):
        if not value:
            return ""
        if value in {"true", "True", "yes"}:
            return True
        if value in {"false", "False", "no"}:
            return False
        if value in {"null", "None", "~"}:
            return None
        if value == "[]":
            return []
        if value == "{}":
            return {}
        if (value.startswith('"') and value.endswith('"')) or (
            value.startswith("'") and value.endswith("'")
        ):
            return value[1:-1]
        if re.fullmatch(r"-?\d+(\.\d+)?", value):
            return float(value) if "." in value else int(value)
        if value.startswith("[") and value.endswith("]"):
            inner = value[1:-1].strip()
            if not inner:
                return []
            parts = [part.strip() for part in inner.split(",")]
            return [self.parse_scalar(part) for part in parts if part]
        return value


def compile_theme(theme_dir: Path) -> None:
    yaml_path = theme_dir / "theme.yaml"
    json_path = theme_dir / "theme.json"
    if not yaml_path.exists():
        return
    data = YAMLParser(yaml_path.read_text(encoding="utf-8")).parse()
    json_path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Compiled {yaml_path.relative_to(ROOT)} -> {json_path.relative_to(ROOT)}")


def main() -> int:
    if not THEMES_DIR.exists():
        print(f"Themes directory not found: {THEMES_DIR}", file=sys.stderr)
        return 1
    for theme_dir in sorted(THEMES_DIR.iterdir()):
        if theme_dir.is_dir():
            compile_theme(theme_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
