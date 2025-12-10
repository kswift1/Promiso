#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCE_ROOT="$ROOT/Projects/ResourceKit"
ASSETS_DIR="$RESOURCE_ROOT/Resources/Assets.xcassets"
COLORS_DIR="$ASSETS_DIR/Colors"
GEN_DIR="$RESOURCE_ROOT/Sources/Generated"
SPEC_FILE="$RESOURCE_ROOT/Sources/ColorSpec.swift"
BUNDLE_ID="com.promiso.resourcekit"

mkdir -p "$COLORS_DIR" "$GEN_DIR"

python3 - "$ASSETS_DIR" "$COLORS_DIR" "$GEN_DIR" "$SPEC_FILE" "$BUNDLE_ID" <<'PY'
import json, sys, pathlib, re

assets_dir = pathlib.Path(sys.argv[1])
colors_dir = pathlib.Path(sys.argv[2])
gen_dir = pathlib.Path(sys.argv[3])
spec_file = pathlib.Path(sys.argv[4])
bundle_id = sys.argv[5]

def components(hex_str: str):
    s = hex_str.strip().lstrip("#")
    if len(s) != 6:
        return ("1.0","1.0","1.0")
    v = int(s, 16)
    f = lambda x: f"{x/255.0:.4f}"
    return f((v>>16)&0xFF), f((v>>8)&0xFF), f(v&0xFF)

content = spec_file.read_text(encoding="utf-8")
pattern = re.compile(
    r'\.init\s*\(\s*assetName:\s*"([^"]+)"\s*,\s*lightHex:\s*"([^"]+)"\s*,\s*darkHex:\s*(nil|"[^"]*")\s*\)',
    re.MULTILINE
)
specs = []
for match in pattern.finditer(content):
    asset, light, dark_raw = match.groups()
    dark = None if dark_raw == "nil" else dark_raw.strip('"')
    specs.append({"assetName": asset, "lightHex": light, "darkHex": dark})

if not specs:
    print("❌ No specs parsed from ColorSpec.swift")
    sys.exit(1)

# Colorset 생성
for spec in specs:
    folder = colors_dir / f"{spec['assetName']}.colorset"
    folder.mkdir(parents=True, exist_ok=True)
    light = components(spec["lightHex"])
    colors = [{
        "idiom": "universal",
        "color": {
            "color-space": "srgb",
            "components": {"red": light[0], "green": light[1], "blue": light[2], "alpha": "1.000"}
        }
    }]
    dark_hex = spec.get("darkHex")
    if dark_hex:
        dark = components(dark_hex)
        colors.append({
            "idiom": "universal",
            "appearances": [{"appearance": "luminosity", "value": "dark"}],
            "color": {
                "color-space": "srgb",
                "components": {"red": dark[0], "green": dark[1], "blue": dark[2], "alpha": "1.000"}
            }
        })
    contents = {"colors": colors, "info": {"version": 1, "author": "xcode"}}
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2), encoding="utf-8")

# Swift 확장 생성
from collections import defaultdict

def camel(s: str) -> str:
    parts = s.split(".")
    if not parts:
        return ""
    base = parts[-1]
    return base[0].lower() + base[1:] if base else ""

groups = defaultdict(list)
for spec in specs:
    key = spec["assetName"]
    top = key.split(".")[0] if "." in key else "Custom"
    groups[top].append(key)

lines = [
    "//",
    "//  Color+Generated.swift",
    "//  AUTO-GENERATED. DO NOT EDIT.",
    "//",
    "",
    "import SwiftUI",
    "",
    "public extension Color {",
    f"    private static let bundle = Bundle(identifier: \"{bundle_id}\")",
    ""
]

for group, items in groups.items():
    lines.append(f"    // MARK: - {group}")
    lines.append(f"    struct {group.lower()} {{")
    for key in items:
        var_name = camel(key)
        lines.append(f"        public static var {var_name}: Color {{ Color(\"{key}\", bundle: Color.bundle) }}")
    lines.append("    }")
    lines.append("")

lines.append("}")

gen_dir.joinpath("Color+Generated.swift").write_text("\n".join(lines), encoding="utf-8")
print("✅ Generated colorsets and Color+Generated.swift")
PY
