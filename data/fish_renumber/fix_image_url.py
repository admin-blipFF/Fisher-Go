"""Fix imageUrl in the newly-written dart file.

Old species (isNew=False): set imageUrl to badge file using OLD ID filename
  (badge files are named by old ID and already exist).
New species (isNew=True): keep default.png, will generate icons later.

Also patch the write_dart.py logic permanently.
"""
import re, csv, os

OUT_DIR  = r"C:\Users\s0829\fishergo\data\fish_renumber"
CSV      = os.path.join(OUT_DIR, "old_new_mapping.csv")
DART     = r"C:\Users\s0829\fishergo\lib\features\fish\data\sample_fish_species_data_source.dart"
ASSETS   = r"C:\Users\s0829\fishergo\assets\fish\icons\generated"

with open(CSV, encoding="utf-8-sig") as f:
    rows = list(csv.DictReader(f))

# Build old_id -> new_id map, plus lookup for badge files by OLD id
old_to_new = {r["old_id"]: r["new_id"] for r in rows}
new_to_old = {r["new_id"]: r["old_id"] for r in rows}
new_to_cn  = {r["new_id"]: r["commonNameZh"] for r in rows}

existing_files = set(os.listdir(ASSETS))

# For old species: imageUrl = badge file of the OLD ID
def badge_for_old_id(old_id):
    """Return path to badge file for an old fish ID."""
    num = old_id.replace("fish-","")
    # Try exact match first
    if f"{num}_hk-*-badge.png" in existing_files:
        # glob match
        import fnmatch
        matches = [f for f in existing_files if f.startswith(f"{num}_") and f.endswith("-badge.png")]
        return f"assets/fish/icons/generated/{matches[0]}" if matches else None
    return None

# Read current dart file
with open(DART, encoding="utf-8") as f:
    dart = f.read()

# For each FishSpecies block, figure out the new_id and whether it's new
# Block pattern: each FishSpecies( block
blocks = re.split(r'\n      FishSpecies\(', dart)
# blocks[0] is header, blocks[1:] are the species

new_dart_parts = [blocks[0]]  # header

for i, block in enumerate(blocks[1:], 1):
    # Extract new_id from the id: line in this block
    id_match = re.search(r"id: '([^']*)'", block)
    new_id = id_match.group(1) if id_match else f"fish-???{i}"
    is_new = any(r["new_id"] == new_id and r["isNew"] == "True" for r in rows)

    if is_new:
        # Keep default.png for new species (icon not yet generated)
        new_image_url = "assets/fish/icons/generated/default.png"
    else:
        # Find the old id for this new_id
        old_id = new_to_old.get(new_id, "")
        old_num = old_id.replace("fish-","").zfill(3)
        # Find badge file for old id
        badge_candidates = [f for f in existing_files
                           if f.startswith(f"{old_num}_") and f.endswith("-badge.png")]
        if badge_candidates:
            new_image_url = f"assets/fish/icons/generated/{badge_candidates[0]}"
        else:
            # Fallback to simple icon
            simple = f"{old_num}.png"
            new_image_url = f"assets/fish/icons/generated/{simple}" if simple in existing_files else "assets/fish/icons/generated/default.png"

    # Replace imageUrl line in block
    new_block = re.sub(
        r"imageUrl: '[^']*'",
        f"imageUrl: '{new_image_url}'",
        block
    )
    new_dart_parts.append("\n      FishSpecies(" + new_block)

new_dart = "".join(new_dart_parts)

with open(DART, "w", encoding="utf-8") as f:
    f.write(new_dart)

# Verify: count how many FishSpecies still have default.png
defaults = new_dart.count("assets/fish/icons/generated/default.png")
print(f"Fixed dart file: {defaults} species still use default.png (should be 26)")
print(f"Total FishSpecies count: {new_dart.count('      FishSpecies(')}")
print("DONE")