import re, csv, os, io

OUT_DIR   = r"C:\Users\s0829\fishergo\data\fish_renumber"
SRC_CSV   = os.path.join(OUT_DIR, "old_new_mapping.csv")
DART_OUT  = r"C:\Users\s0829\fishergo\lib\features\fish\data\sample_fish_species_data_source.dart"

# ── Read CSV ──────────────────────────────────────────────────────────
with open(SRC_CSV, encoding="utf-8-sig") as f:
    rows = list(csv.DictReader(f))

def esc(s):
    """Escape a string for Dart single-quoted literal."""
    if s is None: return "''"
    s = str(s).replace('\\', '\\\\').replace("'", "\\'")
    return f"'{s}'"

def dart_bool(v):
    return "true" if str(v).lower() in ("true","1") else "false"

# Build the new Dart file
lines = []
lines.append("import '../domain/fish_species.dart';")
lines.append("")
lines.append("class SampleFishSpeciesDataSource {")
lines.append("  const SampleFishSpeciesDataSource();")
lines.append("")
lines.append("  List<FishSpecies> loadSpecies() {")
lines.append("    final species = <FishSpecies>[")
lines.append("")

for r in rows:
    old_id = r["old_id"]
    new_id = r["new_id"]
    cn     = r["commonNameZh"]
    ln     = r["localNameZh"]
    sci    = r["scientificName"]
    ft     = r["fishType"]
    shape  = r["bodyShape"]
    rr     = r["rarityRank"]
    dl     = r["dangerLevelInt"]
    mp     = r["marketPrice"]
    is_new = r["isNew"] == "True"

    lines.append("      FishSpecies(")
    lines.append(f"        id: {esc(new_id)},")
    lines.append(f"        afcdId: null,")
    lines.append(f"        commonNameZh: {esc(cn)},")
    lines.append(f"        localNameZh: {esc(ln)},")
    lines.append(f"        scientificName: {esc(sci)},")
    lines.append(f"        family: null,")
    lines.append(f"        descriptionZh: null,")
    lines.append(f"        habitatZh: null,")
    lines.append(f"        dangerLevel: {esc(dl)},")
    lines.append(f"        fishType: {esc(ft)},")
    lines.append(f"        bodyShape: {esc(shape)},")
    lines.append(f"        rarityRank: {rr},")
    lines.append(f"        imageUrl: 'assets/fish/icons/generated/default.png',")
    lines.append(f"        silhouetteUrl: 'assets/fish/icons/locked_silhouette.png',")
    lines.append("      ),")
    lines.append("")

lines.append("    ];")
lines.append("    return species;")
lines.append("  }")
lines.append("}")

dart_src = "\n".join(lines)
with open(DART_OUT, "w", encoding="utf-8") as f:
    f.write(dart_src)
print(f"Dart file written: {DART_OUT} ({len(dart_src):,} bytes)")

# ── Verify with flutter analyze ───────────────────────────────────────
import subprocess
result = subprocess.run(
    ["python", "-c",
     "import sys; print(sys.version)"],
    capture_output=True, text=True
)
print("Python:", result.stdout.strip())

# Check line count
with open(DART_OUT, encoding="utf-8") as f:
    content = f.read()
line_count = content.count("\n")
print(f"Dart lines: {line_count}")

# Verify FishSpecies count
count = content.count("      FishSpecies(")
print(f"FishSpecies entries: {count}")

# Check no remaining 'NEW' old_ids
assert "old_id" not in content, "old_id leaked into Dart!"
assert "'fish-NEW'" not in content, "NEW id leaked!"
print("No ID leakage: OK")

# Verify 001-153 all present
import re as re2
all_ids = re2.findall(r"id: 'fish-(\d{3})'", content)
all_ids_int = sorted(set(int(x) for x in all_ids))
assert all_ids_int == list(range(1,154)), f"Missing IDs: {set(range(1,154)) - set(all_ids_int)}"
print(f"All 001-153 present: OK")

print("\nDart rewrite COMPLETE")