"""Preview batch: generate 3 badge icons for confirmation before full batch."""
import requests, os, base64, time

env_path = r"C:\Users\s0829\xinglan-workspace\.env"
OPENROUTER_KEY = ""
if os.path.exists(env_path):
    for line in open(env_path, encoding="utf-8"):
        if line.strip().startswith("OPENROUTER_API_KEY"):
            OPENROUTER_KEY = line.split("=",1)[1].strip().strip('"\'')
            break

API_URL = "https://openrouter.ai/api/v1/images/generations"
ASSET_DIR = r"C:\Users\s0829\fishergo\assets\fish\icons\generated"
os.makedirs(ASSET_DIR, exist_ok=True)

RARITY_BG   = {1:"#E8485B",2:"#E8485B",3:"#2E9A93",4:"#1D6F68",5:"#F4A623"}
RARITY_SHAD = {1:"#B8303F",2:"#B8303F",3:"#1D6F68",4:"#145550",5:"#C07A10"}

# 3 preview species: one per rarity tier (R2, R3, R5)
PREVIEW_SPECIES = [
    ("121","雞蛋䱛","雞蛋䱛","Collichthys lucidus",2),
    ("072","杉斑","杉斑","Epinephelus polyphekadion",3),
    ("073","老鼠斑","老鼠斑","Cromileptes altivelis",5),
]

def make_prompt(num, cn, ln, sci, rank):
    bg = RARITY_BG[rank]; sh = RARITY_SHAD[rank]
    return (
        f'A large circular badge icon (1024x1024, PNG with transparent corners) featuring '
        f'a cartoon-style fish named "{cn}" with HK local name "{ln}" ({sci}). '
        f'The fish faces LEFT. The fish has a full colored body — white/cream colored. '
        f'A small tail, smooth fins, and a friendly round eye with a highlight dot. '
        f'The badge background is solid {bg}. '
        f'A soft shadow in {sh} is cast lower-left at 45 degrees. '
        f'The fish silhouette has a thin dark outline. There is no text on the badge. '
        f'The fish is centered, facing LEFT, tail tip touching the badge edge.'
    )

headers = {"Authorization": f"Bearer {OPENROUTER_KEY}", "Content-Type": "application/json"}

for num, cn, ln, sci, rank in PREVIEW_SPECIES:
    prompt = make_prompt(num, cn, ln, sci, rank)
    payload = {"model":"gpt-image-2","prompt":prompt,"n":1,"size":"1024x1024"}
    print(f"Generating: {cn} ({ln}) R{rank}...")
    resp = requests.post(API_URL, json=payload, headers=headers, timeout=120)
    data = resp.json()
    if resp.status_code != 200 or "data" not in data:
        print(f"  ERROR {resp.status_code}: {data}")
        continue
    img_data = data["data"][0]
    if "b64_json" in img_data:
        png_bytes = base64.b64decode(img_data["b64_json"])
    elif "url" in img_data:
        png_bytes = requests.get(img_data["url"], timeout=60).content
    out_name = f"{num}_hk-{cn}-badge.png"
    out_path = os.path.join(ASSET_DIR, out_name)
    with open(out_path, "wb") as f:
        f.write(png_bytes)
    print(f"  Saved: {out_path} ({len(png_bytes):,} bytes)")
    time.sleep(2)

print("\nPreview done. Check the 3 generated PNG files.")
print("If approved, run generate_icons.py for the remaining 23.")