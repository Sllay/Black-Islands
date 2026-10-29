#!/usr/bin/env python3
"""Compile a pinned, legally accepted LPC subset, never execute upstream code.

Authoring JSON/PNGs/credits stay outside game/. The Godot bake packs their PNG
bytes and this catalog into an exportable Resource (one upload per composed clip).
"""
import argparse
import csv
import hashlib
import io
import json
import re
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "harness/lpc/s01_p03_slice.json"


def data_object(text, anchor):
    """Read a JS object literal containing only JSON-compatible data, not JS."""
    start = text.index("{", text.index(anchor))
    depth, quoted, escaped = 0, False, False
    for end in range(start, len(text)):
        ch = text[end]
        if quoted:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                quoted = False
        elif ch == '"':
            quoted = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                raw = text[start:end + 1]
                raw = re.sub(r"([{,]\s*)([A-Za-z_]\w*)\s*:", r'\1"\2":', raw)
                raw = re.sub(r",\s*([}\]])", r"\1", raw)
                return json.loads(raw)
    raise ValueError("Unterminated upstream data literal")


def compile_catalog(source, fetch=False):
    manifest = json.loads(MANIFEST.read_text())
    commit = manifest["commit"]
    if fetch:
        if not (source / ".git").exists():
            subprocess.run(["git", "clone", "--filter=blob:none", "--no-checkout", "--depth=1",
                            manifest["source"] + ".git", str(source)], check=True)
        subprocess.run(["git", "-C", str(source), "fetch", "--depth=1", "origin", commit], check=True)
    subprocess.run(["git", "-C", str(source), "cat-file", "-e", commit + "^{commit}"], check=True)
    authoring = ROOT / "harness/lpc/upstream_slice"
    hashes, raw_cache, png_paths = {}, {}, []

    def blob(path, preserve=True):
        if path not in raw_cache:
            raw_cache[path] = subprocess.check_output(["git", "-C", str(source), "show", commit + ":" + path])
        raw = raw_cache[path]
        hashes[path] = hashlib.sha256(raw).hexdigest()
        if preserve:
            target = authoring / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
        return raw

    registry = blob("sources/custom-animations.js", preserve=False).decode()
    rows = data_object(registry, "const animationRowsLayout")
    custom = data_object(registry, "const customAnimations")
    # These row mappings/pivots are data, not copied upstream executable code.
    direction_suffix = ["n", "w", "s", "e"]
    clip_rows = {semantic: [rows[f"{raw}-{d}"] + 1 for d in direction_suffix]
                 for semantic, raw in [("MOVE", "walk"), ("MELEE_SLASH", "slash")]}
    credits_csv = blob("CREDITS.csv", preserve=False).decode("utf-8-sig")
    credit_rows = list(csv.DictReader(io.StringIO(credits_csv)))
    used_credits = {}
    palettes = {}
    for kind, upstream in [("skin", "body"), ("hair", "hair"), ("cloth", "cloth")]:
        data = json.loads(blob(f"palettes/ulpc-{upstream}-palettes.json"))
        for asset in manifest["assets"]:
            if asset["palette"].startswith(kind + "."):
                variant = asset["variant"]
                palettes[asset["palette"]] = {"id":asset["palette"], "upstream_variant":variant,
                                               "colors":data[variant]}
    assets = []
    for spec in manifest["assets"]:
        definition_path = "sheet_definitions/" + spec["definition"] + ".json"
        definition = json.loads(blob(definition_path))
        assert spec["variant"] in definition["variants"], spec["id"]
        asset = {k:v for k,v in spec.items() if k != "definition"}
        asset.update(body_types=[manifest["body_type"]], technical_status="verified_slice",
                     legal_status="accepted", license=manifest["selected_license"],
                     source_definition=definition_path, aliases=[], layers=[],
                     match_body_color=bool(definition.get("match_body_color", False)),
                     first_seen=commit, last_seen=commit, supported_actions=["IDLE","MOVE","MELEE_SLASH"])
        if asset["match_body_color"]:
            assert spec["palette"] == "skin.light"
        for key in sorted(k for k in definition if re.fullmatch(r"layer_\d+", k)):
            layer = definition[key]
            animation = layer.get("custom_animation", "")
            if animation and animation != "slash_oversize":
                continue  # Unsupported actions remain explicit, never optimistic.
            folder = layer.get(manifest["body_type"], "")
            if not folder:
                continue
            path = "spritesheets/" + folder + spec["variant"] + ".png"
            png = blob(path)
            assert png[:8] == b"\x89PNG\r\n\x1a\n", path
            width, height = struct.unpack(">II", png[16:24])
            if path not in png_paths:
                png_paths.append(path)
            matching = [r for r in credit_rows if r["filename"] and
                        (folder.rstrip("/") == r["filename"].rstrip("/") or
                         folder.startswith(r["filename"].rstrip("/") + "/"))]
            assert matching, "No credits: " + folder
            credit = max(matching, key=lambda r:len(r["filename"]))
            assert "CC-BY-SA 3.0" in credit["licenses"] or "CC-BY-SA-3.0" in credit["licenses"], credit
            used_credits[credit["filename"]] = credit
            source_size = int(custom[animation]["frameSize"]) if animation else 64
            frames = 6 if animation else 9
            assert width >= frames * source_size
            assert height >= (4 if animation else max(clip_rows["MELEE_SLASH"]) + 1) * source_size
            asset["layers"].append({"z":layer["zPos"], "source_index":png_paths.index(path),
                "source_path":path, "sha256":hashes[path], "source_size":[width,height],
                "frame_size":source_size, "custom_action":"MELEE_SLASH" if animation else "",
                "credit":credit["filename"]})
        assert asset["layers"], asset["id"]
        assets.append(asset)
    blob("cc-by-sa-3_0.txt")
    selected_csv = io.StringIO()
    writer = csv.DictWriter(selected_csv, fieldnames=list(credit_rows[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(used_credits.values())
    (authoring / "CREDITS-selected.csv").write_text(selected_csv.getvalue())
    catalog = {"schema_version":1, "catalog_version":manifest["catalog_version"],
        "source":manifest["source"], "source_commit":commit, "selected_license":manifest["selected_license"],
        "source_hashes":dict(sorted(hashes.items())), "png_sources":png_paths,
        "credits":list(used_credits.values()), "palettes":palettes, "assets":assets,
        "directions":["UP","LEFT","DOWN","RIGHT"], "universal_frame_size":64,
        "base_foot_pivot":[32,60], "clip_rows":clip_rows,
        "clips":{"MOVE":{"frames":9,"fps":10,"loop":True},
                 "MELEE_SLASH":{"frames":6,"fps":12,"loop":False}},
        "semantic_fallbacks":{"IDLE":"MOVE_POSE", "RUN":"MOVE", "DODGE":"MOVE", "HURT":"IDLE"},
        "frame_sizes":[64,128,192]}
    target = ROOT / "harness/lpc/catalog_v1.json"
    target.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")
    print(f"LPC_CATALOG PASS: {len(assets)} stable IDs, {len(png_paths)} pinned PNGs, {len(used_credits)} credits")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / ".tools/lpc-upstream")
    parser.add_argument("--fetch", action="store_true")
    args = parser.parse_args()
    compile_catalog(args.source, args.fetch)
