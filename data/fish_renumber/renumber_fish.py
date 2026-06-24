#!/usr/bin/env python3
"""
FisherGO Fish Renumber Script
Reads existing 127 fish species, adds 26 new ones,
sorts by fishType group + rarityRank + commonNameZh,
assigns new IDs 001-153, outputs mapping CSV and rewritten Dart file.
"""

import re
import csv
from pathlib import Path

# Paths
DART_FILE = Path("C:/Users/s0829/fishergo/lib/features/fish/data/sample_fish_species_data_source.dart")
OUTPUT_DIR = Path("C:/Users/s0829/fishergo/data/fish_renumber")
MAPPING_CSV = OUTPUT_DIR / "old_new_mapping.csv"
NEW_DART_FILE = DART_FILE  # Overwrite original

# Fish type sort order (per task specification)
FISH_TYPE_ORDER = [
    "其他魚類",
    "底棲近岸類",
    "石斑類",
    "礁棲觀賞類",
    "近岸草食類",
    "鯛科/笛鯛類（含笛鯛）",  # matches "鯛科/笛鯛類" in data
    "䱛/石首魚科",
    "鱸科",
    "鰍/鮋科",
    "鰺科/洄游類",
    "鰺科/池魚",  # for new fish with this type
    "鯖科",
]

# Map target fishType names to canonical form used in data
FISH_TYPE_CANONICAL = {
    "其他魚類": "其他魚類",
    "底棲近岸類": "底棲近岸類",
    "石斑類": "石斑類",
    "礁棲觀賞類": "礁棲觀賞類",
    "近岸草食類": "近岸草食類",
    "鯛科/笛鯛類（含笛鯛）": "鯛科/笛鯛類",
    "䱛/石首魚科": "䱛/石首魚科",
    "鱸科": "鱸科",
    "鰍/鮋科": "鰍/鮋科",
    "鰺科/洄游類": "鰺科/洄游類",
    "鰺科/池魚": "鰺科/池魚",
    "鯖科": "鯖科",
}

# Fish type remapping (old fishType -> new fishType for sorting/grouping)
# Based on the task description table
FISH_TYPE_REMAP = {
    # existing fish-013, fishType=其他魚類 -> 鰍/鮋科
    "fish-013": "鰍/鮋科",
    # existing fish-018, fishType=其他魚類 -> 鱸科
    "fish-018": "鱸科",
    # existing fish-042, fishType=其他魚類 -> 鱸科
    "fish-042": "鱸科",
    # existing fish-010,012,030,041,052, fishType=其他魚類 -> 䱛/石首魚科
    "fish-010": "䱛/石首魚科",
    "fish-012": "䱛/石首魚科",
    "fish-030": "䱛/石首魚科",
    "fish-041": "䱛/石首魚科",
    "fish-052": "䱛/石首魚科",
    # existing fish-072,073,074, fishType=毒棘礁棲類 -> 鰍/鮋科
    "fish-072": "鰍/鮋科",
    "fish-073": "鰍/鮋科",
    "fish-074": "鰍/鮋科",
}

def get_target_fish_type(fish_id, original_fish_type):
    """Get the target fishType for grouping/sorting purposes."""
    if fish_id in FISH_TYPE_REMAP:
        return FISH_TYPE_REMAP[fish_id]
    return original_fish_type

def parse_existing_fish(dart_content):
    """Parse all FishSpecies from the Dart file."""
    fish_list = []
    
    # Pattern to match FishSpecies blocks
    # Handles both null and quoted values for fields
    # FishSpecies(\n        id: 'fish-001',\n        afcdId: null,\n        ...
    # )
    # Key fields that can be null: afcdId, scientificName, family
    pattern = r"FishSpecies\s*\(\s*id:\s*'([^']+)'\s*,\s*afcdId:\s*([^,]+),\s*commonNameZh:\s*'([^']*)',\s*localNameZh:\s*'([^']*)',\s*scientificName:\s*([^,]+),\s*family:\s*([^,]+),\s*descriptionZh:\s*'([^']*)',\s*habitatZh:\s*'([^']*)',\s*dangerLevel:\s*'([^']*)',\s*fishType:\s*'([^']*)',\s*bodyShape:\s*'([^']*)',\s*rarityRank:\s*(\d+),\s*imageUrl:\s*'([^']*)',\s*silhouetteUrl:\s*'([^']*)'\s*\)"
    
    matches = re.finditer(pattern, dart_content)
    for m in matches:
        fish_id = m.group(1)
        afcd_id_raw = m.group(2).strip()
        afcd_id = None if afcd_id_raw == 'null' else afcd_id_raw
        common_name_zh = m.group(3)
        local_name_zh = m.group(4)
        scientific_name_raw = m.group(5).strip()
        scientific_name = None if scientific_name_raw == 'null' else scientific_name_raw
        family_raw = m.group(6).strip()
        family = None if family_raw == 'null' else family_raw
        description_zh = m.group(7)
        habitat_zh = m.group(8)
        danger_level = m.group(9)
        fish_type = m.group(10)
        body_shape = m.group(11)
        rarity_rank = int(m.group(12))
        image_url = m.group(13)
        silhouette_url = m.group(14)
        
        fish_list.append({
            'id': fish_id,
            'afcdId': afcd_id,
            'commonNameZh': common_name_zh,
            'localNameZh': local_name_zh,
            'scientificName': scientific_name,
            'family': family,
            'descriptionZh': description_zh,
            'habitatZh': habitat_zh,
            'dangerLevel': danger_level,
            'fishType': fish_type,
            'bodyShape': body_shape,
            'rarityRank': rarity_rank,
            'imageUrl': image_url,
            'silhouetteUrl': silhouette_url,
            'isNew': False,
        })
    
    return fish_list

def get_new_fish_data():
    """Return data for the 26 new fish species."""
    new_fish = [
        # 石斑類 (6 new)
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '杉斑',
            'localNameZh': '杉斑',
            'scientificName': 'Epinephelus polyphekadion',
            'family': None,
            'descriptionZh': '香港常見食用石斑，身形修長，斑紋似杉木因而得名。',
            'habitatZh': '珊瑚礁及岩礁區，水深 10-50 米。',
            'dangerLevel': 'none',
            'fishType': '石斑類',
            'bodyShape': 'fish',
            'rarityRank': 3,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '老鼠斑',
            'localNameZh': '老鼠斑',
            'scientificName': 'Cromileptes altivelis',
            'family': None,
            'descriptionZh': '名貴石斑，頭部隆起似老鼠，養殖及野生均常見。',
            'habitatZh': '珊瑚礁區，水深 5-30 米。',
            'dangerLevel': 'none',
            'fishType': '石斑類',
            'bodyShape': 'fish',
            'rarityRank': 5,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '西星斑',
            'localNameZh': '西星斑',
            'scientificName': 'Plectropomus laevis',
            'family': None,
            'descriptionZh': '鞍帶石斑近親，身上有明顯星點，產自印度-西太平洋。',
            'habitatZh': '珊瑚礁及岩礁，水深 10-60 米。',
            'dangerLevel': 'none',
            'fishType': '石斑類',
            'bodyShape': 'fish',
            'rarityRank': 4,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '金錢斑',
            'localNameZh': '金錢斑',
            'scientificName': 'Epinephelus amblycephalus',
            'family': None,
            'descriptionZh': '頭部有明顯深色斑塊似金錢而得名，食用價值高。',
            'habitatZh': '岩礁及珊瑚礁，水深 20-80 米。',
            'dangerLevel': 'none',
            'fishType': '石斑類',
            'bodyShape': 'fish',
            'rarityRank': 4,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '蘇鼠斑',
            'localNameZh': '蘇鼠斑',
            'scientificName': 'Epinephelus tukula',
            'family': None,
            'descriptionZh': '大型石斑，體色偏灰白，蘇鼠指其灰黑色斑紋如老鼠。',
            'habitatZh': '深海岩礁，水深 30-100 米。',
            'dangerLevel': 'none',
            'fishType': '石斑類',
            'bodyShape': 'fish',
            'rarityRank': 5,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '紅瓜子斑',
            'localNameZh': '紅瓜子斑',
            'scientificName': 'Epinephelus areolatus',
            'family': None,
            'descriptionZh': '小型石斑，體色偏紅，斑點圓潤似瓜子因而得名。',
            'habitatZh': '珊瑚礁及碎石區，水深 15-80 米。',
            'dangerLevel': 'none',
            'fishType': '石斑類',
            'bodyShape': 'fish',
            'rarityRank': 3,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        # 笛鯛科 (4 new)
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '五線笛鯛',
            'localNameZh': '五間畫眉',
            'scientificName': 'Lutjanus quinquelineatus',
            'family': None,
            'descriptionZh': '身上五條金色橫紋，體型細小，常見於珊瑚礁附近。',
            'habitatZh': '珊瑚礁及岩礁，水深 5-30 米。',
            'dangerLevel': 'none',
            'fishType': '笛鯛科',
            'bodyShape': 'fish',
            'rarityRank': 2,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '四間畫眉',
            'localNameZh': '四間畫眉',
            'scientificName': 'Lutjanus kasmira',
            'family': None,
            'descriptionZh': '四至五條深色橫紋，分布於印度-太平洋珊瑚礁區。',
            'habitatZh': '珊瑚礁，水深 3-50 米。',
            'dangerLevel': 'none',
            'fishType': '笛鯛科',
            'bodyShape': 'fish',
            'rarityRank': 2,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '千年笛鯛',
            'localNameZh': '白點笛鯛',
            'scientificName': 'Lutjanus rivulatus',
            'family': None,
            'descriptionZh': '大型笛鯛，體側有眾多小白點，別名白點笛鯛。',
            'habitatZh': '珊瑚礁及岩礁，水深 10-60 米。',
            'dangerLevel': 'none',
            'fishType': '笛鯛科',
            'bodyShape': 'fish',
            'rarityRank': 4,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '約氏笛鯛',
            'localNameZh': '約翰紅友',
            'scientificName': 'Lutjanus johnii',
            'family': None,
            'descriptionZh': '幼魚為黃褐色，隨成長變深紅，分布於西太平洋及印度洋。',
            'habitatZh': '河口及珊瑚礁，水深 5-40 米。',
            'dangerLevel': 'none',
            'fishType': '笛鯛科',
            'bodyShape': 'fish',
            'rarityRank': 3,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        # 䱛/石首魚科 (5 new)
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '雞蛋䱛',
            'localNameZh': '雞蛋䱛',
            'scientificName': 'Collichthys lucidus',
            'family': None,
            'descriptionZh': '頭大身圓似雞蛋，珠三角常見，俗稱雞蛋䱛。',
            'habitatZh': '河口及沿岸沙泥底，水深 5-25 米。',
            'dangerLevel': 'none',
            'fishType': '䱛/石首魚科',
            'bodyShape': 'fish',
            'rarityRank': 2,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '老鼠䱛',
            'localNameZh': '老鼠䱛',
            'scientificName': 'Johnius dussumieri',
            'family': None,
            'descriptionZh': '小型石首魚，頭部尖小似老鼠，香港近岸常見。',
            'habitatZh': '沙泥底沿岸，水深 5-30 米。',
            'dangerLevel': 'none',
            'fishType': '䱛/石首魚科',
            'bodyShape': 'fish',
            'rarityRank': 2,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '紅牙䱛',
            'localNameZh': '丁友',
            'scientificName': 'Otolithes ruber',
            'family': None,
            'descriptionZh': '體型修長，牙齒紅色，俗名丁友，市場常見。',
            'habitatZh': '沙泥底，水深 10-50 米。',
            'dangerLevel': 'none',
            'fishType': '䱛/石首魚科',
            'bodyShape': 'fish',
            'rarityRank': 3,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '鮸魚',
            'localNameZh': '米魚',
            'scientificName': 'Miichthys miiuy',
            'family': None,
            'descriptionZh': '大型石首魚，北方稱米魚，香港近海有分布，養殖常見。',
            'habitatZh': '泥沙底，水深 20-80 米。',
            'dangerLevel': 'none',
            'fishType': '䱛/石首魚科',
            'bodyShape': 'fish',
            'rarityRank': 3,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '黃唇魚',
            'localNameZh': '金錢鮸',
            'scientificName': 'Bahaba taipingensis',
            'family': None,
            'descriptionZh': '受保護的大型石首魚，嘴巴黃色，俗稱金錢鮸，極為稀有。',
            'habitatZh': '河口及沿岸，水深 5-30 米。',
            'dangerLevel': 'none',
            'fishType': '䱛/石首魚科',
            'bodyShape': 'fish',
            'rarityRank': 5,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        # 鱸科 (2 new)
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '花尾胡椒鯛',
            'localNameZh': '花雞',
            'scientificName': 'Plectorhinchus cinctus',
            'family': None,
            'descriptionZh': '體側有多條深色橫紋，尾鰭有花紋，常被誤認為笛鯛。',
            'habitatZh': '岩礁及珊瑚礁，水深 10-50 米。',
            'dangerLevel': 'none',
            'fishType': '鱸科',
            'bodyShape': 'fish',
            'rarityRank': 3,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '中華烏塘鱧',
            'localNameZh': '黑咕咕',
            'scientificName': 'Bostrychus sinensis',
            'family': None,
            'descriptionZh': '河口及泥灘常見，體色深褐，俗稱黑咕咕，養殖種類。',
            'habitatZh': '河口及泥灘，水深 0-5 米。',
            'dangerLevel': 'none',
            'fishType': '鱸科',
            'bodyShape': 'fish',
            'rarityRank': 2,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        # 鰍/鮋科 (3 new)
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '石狗公',
            'localNameZh': '石狗公',
            'scientificName': 'Sebastiscus marmoratus',
            'family': None,
            'descriptionZh': '岩礁區常見鮋魚，體色似岩石，有毒刺，市場稱石狗公。',
            'habitatZh': '岩礁及碎石區，水深 10-60 米。',
            'dangerLevel': 'medium',
            'fishType': '鰍/鮋科',
            'bodyShape': 'fish',
            'rarityRank': 3,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '火點',
            'localNameZh': '火點',
            'scientificName': 'Scorpaena onaria',
            'family': None,
            'descriptionZh': '紅色鮋魚，鰭尖有毒，常伏擊獵物，岩礁區常見。',
            'habitatZh': '岩礁區，水深 15-80 米。',
            'dangerLevel': 'medium',
            'fishType': '鰍/鮋科',
            'bodyShape': 'fish',
            'rarityRank': 3,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '深水石狗公',
            'localNameZh': '白斑菖鮋',
            'scientificName': 'Sebastiscus albofasciatus',
            'family': None,
            'descriptionZh': '深海鮋魚，有明顯白色斑紋，較為罕見。',
            'habitatZh': '深海岩礁，水深 50-150 米。',
            'dangerLevel': 'medium',
            'fishType': '鰍/鮋科',
            'bodyShape': 'fish',
            'rarityRank': 4,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        # 鰺科 (5 new)
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '真池魚',
            'localNameZh': '巴浪',
            'scientificName': 'Trachurus japonicus',
            'family': None,
            'descriptionZh': '日本竹筴魚，香港俗稱巴浪，市場常見小型鰺魚。',
            'habitatZh': '表層至中層水域，結群游動。',
            'dangerLevel': 'none',
            'fishType': '鰺科',
            'bodyShape': 'fish',
            'rarityRank': 2,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '六帶鰺',
            'localNameZh': '木棉',
            'scientificName': 'Caranx sexfasciatus',
            'family': None,
            'descriptionZh': '大型鰺魚，體側有六條深色橫帶，俗名木棉，拖網常見。',
            'habitatZh': '沿海及河口，水深 5-50 米。',
            'dangerLevel': 'none',
            'fishType': '鰺科',
            'bodyShape': 'fish',
            'rarityRank': 3,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '浪花鰺',
            'localNameZh': 'GT',
            'scientificName': 'Caranx ignobilis',
            'family': None,
            'descriptionZh': '俗稱 GT (Giant Trevally)，香港近海最大型鰺魚，運動釣魚對象。',
            'habitatZh': '珊瑚礁及岩礁附近，水深 5-30 米。',
            'dangerLevel': 'none',
            'fishType': '鰺科',
            'bodyShape': 'fish',
            'rarityRank': 5,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '紅瓜',
            'localNameZh': '甲鰺',
            'scientificName': 'Alepes djedaba',
            'family': None,
            'descriptionZh': '甲鰺屬，體色偏紅，市場俗稱紅瓜或甲鰺。',
            'habitatZh': '沿海結群，水深 5-30 米。',
            'dangerLevel': 'none',
            'fishType': '鰺科',
            'bodyShape': 'fish',
            'rarityRank': 2,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '脂眼凹肩鰺',
            'localNameZh': '鬼池魚',
            'scientificName': 'Selar crumenophthalmus',
            'family': None,
            'descriptionZh': '眼睛後方有脂腺凹陷，俗稱鬼池魚，市場常見。',
            'habitatZh': '沿海表層，水深 5-25 米。',
            'dangerLevel': 'none',
            'fishType': '鰺科',
            'bodyShape': 'fish',
            'rarityRank': 2,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
        # 鯛科/笛鯛類 (1 new)
        {
            'id': 'fish-NEW',
            'afcdId': None,
            'commonNameZh': '二長棘鯛',
            'localNameZh': '盤仔',
            'scientificName': 'Parargyrops edita',
            'family': None,
            'descriptionZh': '體型似盤，市場稱盤仔，南方常見食用鯛魚。',
            'habitatZh': '沙泥底，水深 10-40 米。',
            'dangerLevel': 'none',
            'fishType': '鯛科/笛鯛類',
            'bodyShape': 'fish',
            'rarityRank': 2,
            'imageUrl': None,
            'silhouetteUrl': None,
            'isNew': True,
        },
    ]
    return new_fish

def sort_key(fish, fish_type_order_map):
    """Generate sort key for a fish: (fishType order, rarityRank, commonNameZh)."""
    # Get the target fishType for sorting (may differ from stored fishType for some fish)
    target_type = get_target_fish_type(fish['id'], fish['fishType'])
    
    # Map target fishType to canonical form for ordering
    # Some fish in the existing data have fishType=鯛科/笛鯛類 but new fish have 笛鯛科 or 鯛科/笛鯛類
    # We need to normalize for sorting
    sort_type = target_type
    if target_type == "笛鯛科":
        sort_type = "鯛科/笛鯛類"  # Put with 鯛科/笛鯛類
    
    type_order = fish_type_order_map.get(sort_type, 999)
    rarity = fish['rarityRank']
    name = fish['commonNameZh']
    return (type_order, rarity, name)

def assign_new_ids(sorted_fish):
    """Assign new IDs from 001 to n to sorted fish."""
    for i, fish in enumerate(sorted_fish, 1):
        fish['newId'] = f"fish-{i:03d}"
    return sorted_fish

def write_mapping_csv(fish_list, csv_path):
    """Write the old->new ID mapping CSV."""
    with open(csv_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        # Header
        writer.writerow([
            'old_id', 'new_id', 'commonNameZh', 'localNameZh', 
            'scientificName', 'fishType', 'rarityRank', 'bodyShape',
            'isVenomous', 'dangerLevel', 'marketPrice',
            'descriptionZh', 'habitatZh', 'isNew'
        ])
        
        for fish in fish_list:
            old_id = fish['id'] if not fish['isNew'] else 'new'
            new_id = fish['newId']
            
            # Determine isVenomous based on fishType or dangerLevel
            is_venomous = 'false'
            if fish['fishType'] in ['鰍/鮋科']:
                is_venomous = 'true'
            elif fish.get('dangerLevel') in ['medium', 'high']:
                is_venomous = 'true'
            
            # Determine market price (placeholder based on rarity for new fish)
            market_price = fish.get('marketPrice', 0) if fish.get('marketPrice') is not None else 0
            
            writer.writerow([
                old_id,
                new_id,
                fish['commonNameZh'],
                fish['localNameZh'],
                fish.get('scientificName') or '',
                fish['fishType'],
                fish['rarityRank'],
                fish.get('bodyShape', 'fish'),
                is_venomous,
                fish.get('dangerLevel', 'none'),
                market_price,
                fish.get('descriptionZh', ''),
                fish.get('habitatZh', ''),
                'true' if fish['isNew'] else 'false'
            ])
    
    print(f"Mapping CSV written to: {csv_path}")

def generate_dart_file(sorted_fish, output_path):
    """Generate the new Dart file with updated IDs."""
    
    dart_template = '''import '../domain/fish_species.dart';

class SampleFishSpeciesDataSource {{
  const SampleFishSpeciesDataSource();

  List<FishSpecies> loadSpecies() {{
    final species = <FishSpecies>[
{entries}
    ];

    species.sort((a, b) {{
      final typeCompare = (a.fishType ?? '').compareTo(b.fishType ?? '');
      if (typeCompare != 0) return typeCompare;

      final shapeCompare = (a.bodyShape ?? '').compareTo(b.bodyShape ?? '');
      if (shapeCompare != 0) return shapeCompare;

      final rarityCompare = b.rarityRank.compareTo(a.rarityRank);
      if (rarityCompare != 0) return rarityCompare;

      return a.commonNameZh.compareTo(b.commonNameZh);
    }});

    return species;
  }}
}}
'''
    
    entries = []
    for fish in sorted_fish:
        new_id = fish['newId']
        afcd_id = fish.get('afcdId') or 'null'
        if afcd_id and afcd_id != 'null':
            afcd_id = f"'{afcd_id}'"
        
        scientific_name = fish.get('scientificName') or 'null'
        if scientific_name and scientific_name != 'null':
            scientific_name = f"'{scientific_name}'"
        
        family = fish.get('family') or 'null'
        if family and family != 'null':
            family = f"'{family}'"
        
        # Determine imageUrl and silhouetteUrl - use placeholder for new fish
        if fish['isNew']:
            image_url = "'assets/fish/icons/generated/default.png'"
            silhouette_url = "'assets/fish/icons/locked_silhouette.png'"
        else:
            # Extract existing image number from old ID and use it
            old_id = fish['id']
            # Old ID format: fish-XXX where XXX is 001-127
            try:
                old_num = int(old_id.split('-')[1])
                image_url = f"'assets/fish/icons/generated/{old_num:03d}.png'"
            except:
                image_url = "'assets/fish/icons/generated/default.png'"
            silhouette_url = "'assets/fish/icons/locked_silhouette.png'"
        
        entry = f'''      FishSpecies(
        id: '{new_id}',
        afcdId: {afcd_id},
        commonNameZh: '{fish['commonNameZh']}',
        localNameZh: '{fish['localNameZh']}',
        scientificName: {scientific_name},
        family: {family},
        descriptionZh: '{fish.get('descriptionZh', '')}',
        habitatZh: '{fish.get('habitatZh', '')}',
        dangerLevel: '{fish.get('dangerLevel', 'unknown')}',
        fishType: '{fish['fishType']}',
        bodyShape: '{fish.get('bodyShape', 'fish')}',
        rarityRank: {fish['rarityRank']},
        imageUrl: {image_url},
        silhouetteUrl: {silhouette_url},
      ),'''
        entries.append(entry)
    
    dart_content = dart_template.format(entries='\n'.join(entries))
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(dart_content)
    
    print(f"Dart file written to: {output_path}")

def main():
    # Read existing Dart file
    print(f"Reading Dart file: {DART_FILE}")
    dart_content = DART_FILE.read_text(encoding='utf-8')
    
    # Parse existing fish
    existing_fish = parse_existing_fish(dart_content)
    print(f"Parsed {len(existing_fish)} existing fish species")
    
    # Get new fish
    new_fish = get_new_fish_data()
    print(f"Added {len(new_fish)} new fish species")
    
    # Combine all fish
    all_fish = existing_fish + new_fish
    print(f"Total fish: {len(all_fish)}")
    
    # Build fishType order map
    fish_type_order_map = {}
    for i, ft in enumerate(FISH_TYPE_ORDER):
        # Map to canonical form
        canonical = FISH_TYPE_CANONICAL.get(ft, ft)
        fish_type_order_map[canonical] = i
    
    # Sort fish by target fishType, rarityRank, commonNameZh
    sorted_fish = sorted(all_fish, key=lambda f: sort_key(f, fish_type_order_map))
    
    # Assign new IDs
    sorted_fish = assign_new_ids(sorted_fish)
    
    # Write mapping CSV
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    write_mapping_csv(sorted_fish, MAPPING_CSV)
    
    # Generate Dart file
    generate_dart_file(sorted_fish, NEW_DART_FILE)
    
    # Print summary
    print("\n=== Summary ===")
    print(f"Total fish: {len(sorted_fish)}")
    print(f"New IDs range: {sorted_fish[0]['newId']} to {sorted_fish[-1]['newId']}")
    
    # Count by fishType
    type_counts = {}
    for fish in sorted_fish:
        ft = fish['fishType']
        type_counts[ft] = type_counts.get(ft, 0) + 1
    
    print("\nFish count by fishType:")
    for ft, count in type_counts.items():
        print(f"  {ft}: {count}")

if __name__ == '__main__':
    main()