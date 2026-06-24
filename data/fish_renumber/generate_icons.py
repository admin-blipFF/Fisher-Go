"""Generate fish badge icons via OpenRouter gpt-image-2 API.
Saves PNG files to assets/fish/icons/generated/{NNN}_hk-{name}-badge.png
"""
import requests, os, base64, time

OPENROUTER_KEY = os.environ.get("OPENROUTER_API_KEY", "")
if not OPENROUTER_KEY:
    # Try to load from .env
    env_path = r"C:\Users\s0829\xinglan-workspace\.env"
    if os.path.exists(env_path):
        for line in open(env_path, encoding="utf-8"):
            if line.strip().startswith("OPENROUTER_API_KEY"):
                OPENROUTER_KEY = line.split("=",1)[1].strip().strip('"\'')
                break

API_URL = "https://openrouter.ai/api/v1/images/generations"
ASSET_DIR = r"C:\Users\s0829\fishergo\assets\fish\icons\generated"
os.makedirs(ASSET_DIR, exist_ok=True)

# Rarity → background color
RARITY_BG = {
    1: "#E8485B",  # coral red
    2: "#E8485B",  # coral red
    3: "#2E9A93",  # teal
    4: "#1D6F68",  # dark teal
    5: "#F4A623",  # gold
}
RARITY_SHADOW = {
    1: "#B8303F", 2: "#B8303F",
    3: "#1D6F68", 4: "#145550",
    5: "#C07A10",
}

# 26 new species to generate (id, commonNameZh, localNameZh, scientificName, rarityRank)
SPECIES = [
    ("116","二長棘鯛","盤仔","Parargyrops edita",2),
    ("117","五線笛鯛","五間畫眉","Lutjanus quinquelineatus",2),
    ("118","四間畫眉","四間畫眉","Lutjanus kasmira",2),
    ("119","千年笛鯛","白點笛鯛","Lutjanus rivulatus",4),
    ("120","約氏笛鯛","約翰紅友","Lutjanus johnii",3),
    ("121","雞蛋䱛","雞蛋䱛","Collichthys lucidus",2),
    ("122","老鼠䱛","老鼠䱛","Johnius dussumieri",2),
    ("123","紅牙䱛","丁友","Otolithes ruber",3),
    ("124","鮸魚","米魚","Miichthys miiuy",3),
    ("125","黃唇魚","金錢鮸","Bahaba taipingensis",5),
    ("126","花尾胡椒鯛","花雞","Plectorhinchus cinctus",3),
    ("127","中華烏塘鱧","黑咕咕","Bostrychus sinensis",2),
    ("128","石狗公","石狗公","Sebastiscus marmoratus",3),
    ("129","火點","火點","Scorpaena onaria",3),
    ("130","深水石狗公","白斑菖鮋","Sebastiscus albofasciatus",4),
    ("131","真池魚","巴浪","Trachurus japonicus",2),
    ("132","六帶鰺","木棉","Caranx sexfasciatus",3),
    ("133","浪花鰺","GT","Caranx ignobilis",5),
    ("134","紅瓜","甲鰺","Alepes djedaba",2),
    ("135","脂眼凹肩鰺","鬼池魚","Selar crumenophthalmus",2),
    ("072","杉斑","杉斑","Epinephelus polyphekadion",3),
    ("073","老鼠斑","老鼠斑","Cromileptes altivelis",5),
    ("074","西星斑","西星斑","Plectropomus laevis",4),
    ("075","金錢斑","金錢斑","Epinephelus amblycephalus",4),
    ("076","蘇鼠斑","蘇鼠斑","Epinephelus tukula",5),
    ("077","紅瓜子斑","紅瓜子斑","Epinephelus areolatus",3),
]

def make_prompt(num, cn, ln, sci, rank):
    bg = RARITY_BG[rank]
    sh = RARITY_SHADOW[rank]
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

def generate_one(num, cn, ln, sci, rank):
    prompt = make_prompt(num, cn, ln, sci, rank)
    headers = {
        "Authorization": f"Bearer {OPENROUTER_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": "gpt-image-2",
        "prompt": prompt,
        "n": 1,
        "size": "1024x1024",
    }
    resp = requests.post(API_URL, json=payload, headers=headers, timeout=120)
    data = resp.json()
    if resp.status_code != 200 or "data" not in data:
        print(f"  ERROR {resp.status_code}: {data}")
        return False
    img_data = data["data"][0]
    if "b64_json" in img_data:
        png_bytes = base64.b64decode(img_data["b64_json"])
    elif "url" in img_data:
        png_bytes = requests.get(img_data["url"], timeout=60).content
    else:
        print(f"  No image data in response: {img_data}")
        return False
    out_name = f"{num}_hk-{cn}-badge.png"
    out_path = os.path.join(ASSET_DIR, out_name)
    with open(out_path, "wb") as f:
        f.write(png_bytes)
    print(f"  Saved: {out_name} ({len(png_bytes):,} bytes)")
    return True

print(f"OpenRouter API key: {'YES' if OPENROUTER_KEY else 'NO'}")
print(f"Total species to generate: {len(SPECIES)}")
print(f"Asset dir: {ASSET_DIR}")
print()

# Generate all 26
success, fail = 0, []
for num, cn, ln, sci, rank in SPECIES:
    print(f"Generating: {cn} ({ln}) R{rank}...")
    if generate_one(num, cn, ln, sci, rank):
        success += 1
    else:
        fail.append((num, cn))
    time.sleep(1)  # Rate limit buffer

print(f"\nDONE: {success}/{len(SPECIES)} succeeded, {len(fail)} failed")
if fail:
    print("Failed:", fail)