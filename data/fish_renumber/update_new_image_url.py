"""Update imageUrl for 26 new species — match by Chinese name, not ID number.
Icon files were named with assumed IDs; CSV uses different new_ids.
"""
import csv, re, os

OUT_DIR = r"C:\Users\s0829\fishergo\data\fish_renumber"
CSV     = os.path.join(OUT_DIR, "old_new_mapping.csv")
DART    = r"C:\Users\s0829\fishergo\lib\features\fish\data\sample_fish_species_data_source.dart"
ASSETS  = r"C:\Users\s0829\fishergo\assets\fish\icons\generated"

with open(CSV, encoding="utf-8-sig") as f:
    rows = list(csv.DictReader(f))

# new_id -> commonNameZh for new species
new_species = {r["new_id"]: r["commonNameZh"] for r in rows if r["isNew"] == "True"}

# Build: commonNameZh -> actual badge file (by scanning for -hk-{cn}-badge.png)
existing_files = os.listdir(ASSETS)
cn_to_file = {}
for cn in new_species.values():
    # find file ending with -{cn}-badge.png (any number prefix)
    matches = [f for f in existing_files if f.endswith(f"_hk-{cn}-badge.png")]
    if matches:
        cn_to_file[cn] = matches[0]
    else:
        print(f"  NO ICON for: {cn}")

print(f"Matched {len(cn_to_file)}/{len(new_species)} icons by name")

with open(DART, encoding="utf-8") as f:
    dart = f.read()

blocks = re.split(r'\n      FishSpecies\(', dart)
new_parts = [blocks[0]]
updated = 0

for block in blocks[1:]:
    id_match = re.search(r"id: '([^']*)'", block)
    new_id = id_match.group(1) if id_match else ""
    if new_id in new_species:
        cn = new_species[new_id]
        if cn in cn_to_file:
            new_url = f"assets/fish/icons/generated/{cn_to_file[cn]}"
            block = re.sub(r"imageUrl: '[^']*'", f"imageUrl: '{new_url}'", block)
            updated += 1
    new_parts.append("\n      FishSpecies(" + block)

new_dart = "".join(new_parts)
with open(DART, "w", encoding="utf-8") as f:
    f.write(new_dart)

defaults = new_dart.count("assets/fish/icons/generated/default.png")
print(f"Updated {updated} new species imageUrl")
print(f"Remaining default.png: {defaults} (should be 0)")
print(f"Total FishSpecies: {new_dart.count('      FishSpecies(')}")
print("DONE")