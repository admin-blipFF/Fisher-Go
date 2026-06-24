import re, csv, os

OUT_DIR = r"C:\Users\s0829\fishergo\data\fish_renumber"
SRC     = r"C:\Users\s0829\fishergo\lib\features\fish\data\sample_fish_species_data_source.dart"
os.makedirs(OUT_DIR, exist_ok=True)

# ── ORIG 127 種（從對話歷史已知） ─────────────────────────────────────
ORIG_127 = [
# 其他魚類 001-060
("fish-001","其他魚類","河豚","雞泡","Diodon holocanthus",1,"fish","none",0,200,"其他"),
("fish-002","其他魚類","魟魚","魔鬼魚","Hypanus americanus",1,"fish","none",0,150,"其他"),
("fish-003","其他魚類","三角魚","三角魚","",1,"fish","none",0,30,"其他"),
("fish-004","其他魚類","三鬚魚","三鬚","",1,"fish","none",0,30,"其他"),
("fish-005","其他魚類","九肚魚","九肚魚","Harpadon nehereus",1,"fish","none",0,40,"其他"),
("fish-006","其他魚類","咬仔鳚","狗母鳚","",1,"fish","none",0,25,"其他"),
("fish-007","其他魚類","四指馬友","馬友","Eleutheronema tetradactylum",2,"fish","none",0,80,"其他"),
("fish-008","其他魚類","大眼扁頭魚","大眼牛鰍","",2,"fish","none",0,55,"其他"),
("fish-009","其他魚類","大頭帶魚","刀魚","Trichiurus lepturus",2,"fish","none",0,65,"其他"),
("fish-010","其他魚類","大頭黃姑魚","白䱛","Pennahia macrocephala",2,"fish","none",0,60,"其他"),
("fish-011","其他魚類","寶石隆頭魚","寶石青衣","",3,"fish","none",0,70,"其他"),
("fish-012","其他魚類","小帶紋石首魚","花石首","Terapon puta",2,"fish","none",0,45,"其他"),
("fish-013","其他魚類","岩魚","石狗公仔","Sebastes caurinus",3,"fish","none",0,75,"其他"),
("fish-014","其他魚類","斑點石鱸","石鱸","Plectorhinchus flavomaculatus",2,"fish","none",0,55,"其他"),
("fish-015","其他魚類","斑點金鼓","金鼓","Scatophagus argus",1,"fish","none",0,35,"其他"),
("fish-016","其他魚類","斑點鱚","花沙鑽","Sillaginodes punctatus",2,"fish","none",0,50,"其他"),
("fish-017","其他魚類","旗魚","劍旗魚","Jordanella floridae",3,"fish","none",0,90,"其他"),
("fish-018","其他魚類","日本真鱸","海鱸","Lateolabrax japonicus",3,"fish","none",0,100,"其他"),
("fish-019","其他魚類","日本馬頭魚","馬頭魚","",2,"fish","none",0,65,"其他"),
("fish-020","其他魚類","條紋伏波魚","伏波魚","Eucinostomus gula",2,"fish","none",0,40,"其他"),
("fish-021","其他魚類","梭子魚","梭魚","Sphyraena barracuda",3,"fish","none",0,85,"其他"),
("fish-022","其他魚類","沙甸魚","沙甸","Sardinella aurita",1,"fish","none",0,30,"其他"),
("fish-023","其他魚類","油魚","油甘魚","Ruvettus pretiosus",2,"fish","none",0,60,"其他"),
("fish-024","其他魚類","海鯽","海鯽","Gerres simillimus",1,"fish","none",0,35,"其他"),
("fish-025","其他魚類","海鱔","海鱔","Gymnothorax undulatus",3,"fish","none",0,95,"其他"),
("fish-026","其他魚類","獨角革魨","剝皮魚","Aluterus monoceros",2,"fish","none",0,45,"其他"),
("fish-027","其他魚類","白點竹鯊","狗仔鯊","Chiloscyllium plagiosum",2,"fish","none",0,50,"其他"),
("fish-028","其他魚類","皇帝魚","皇帝魚","Scomberoides lysan",3,"fish","none",0,80,"其他"),
("fish-029","其他魚類","短吻飛魚","飛魚","",1,"fish","none",0,30,"其他"),
("fish-030","其他魚類","石首魚","石首","Helotes octolineatus",2,"fish","none",0,45,"其他"),
("fish-031","其他魚類","窄帶馬鮫","馬鮫","Scomberomorus commerson",3,"fish","none",0,90,"其他"),
("fish-032","其他魚類","紅魔鬼岩魚","紅魔鬼","",3,"fish","none",0,75,"其他"),
("fish-033","其他魚類","羊魚","鬚鯛","Upeneichthys porosus",2,"fish","none",0,50,"其他"),
("fish-034","其他魚類","羊魚（鬚）","鬚羊魚","",1,"fish","none",0,35,"其他"),
("fish-035","其他魚類","花生魚","花生魚","",1,"fish","none",0,30,"其他"),
("fish-036","其他魚類","花鰹","花煙","Euthynnus affinis",2,"fish","none",0,55,"其他"),
("fish-037","其他魚類","蛋斑隆頭魚","青衣","",3,"fish","none",0,65,"其他"),
("fish-038","其他魚類","角聲魚","角聲","",2,"fish","none",0,45,"其他"),
("fish-039","其他魚類","豹紋珊瑚鱸","東星斑","Plectropomus leopardus",3,"fish","none",0,120,"其他"),
("fish-040","其他魚類","連米銀腹魚","連米魚","",2,"fish","none",0,40,"其他"),
("fish-041","其他魚類","里夫黃姑魚","花黃姑","",2,"fish","none",0,50,"其他"),
("fish-042","其他魚類","金目鱸","金目鱸","Lates calcarifer",3,"fish","none",0,110,"其他"),
("fish-043","其他魚類","金線馬頭魚","紅衫馬頭","Nemipterus virgatus",2,"fish","none",0,65,"其他"),
("fish-044","其他魚類","銀鯡","鯡魚","Gerres subfasciatus",1,"fish","none",0,30,"其他"),
("fish-045","其他魚類","銀鯧","白鯧","Pampus argenteus",2,"fish","none",0,60,"其他"),
("fish-046","其他魚類","銀鱚","沙鑽","Sillago argentifasciata",2,"fish","none",0,50,"其他"),
("fish-047","其他魚類","青鱗小沙丁","青鱗沙甸","",1,"fish","none",0,25,"其他"),
("fish-048","其他魚類","髭尾扁頭魚","牛鰍魚","Platycephalus indicus",2,"fish","none",0,50,"其他"),
("fish-049","其他魚類","鯣魚","貼魚","Remora remora",2,"fish","none",0,30,"其他"),
("fish-050","其他魚類","鯷魚","鯷仔","Engraulis australis",1,"fish","none",0,25,"其他"),
("fish-051","其他魚類","鰶魚","鰶魚","Dorosoma cepedianum",1,"fish","none",0,30,"其他"),
("fish-052","其他魚類","黃姑魚","黃花魚","Umbrina roncador",2,"fish","none",0,55,"其他"),
("fish-053","其他魚類","黃甲魚","黃甲","",2,"fish","none",0,45,"其他"),
("fish-054","其他魚類","黑帶金鼓","黑帶金鼓","Neoscorpis lithophilus",2,"fish","none",0,50,"其他"),
("fish-055","其他魚類","黑邊銀鯽","黑邊銀鯽","",1,"fish","none",0,35,"其他"),
("fish-056","其他魚類","黑鯧","黑鯧","Parastromateus niger",2,"fish","none",0,55,"其他"),
("fish-057","其他魚類","鼠尾隆頭魚","老鼠斑衣","",3,"fish","none",0,60,"其他"),
("fish-058","其他魚類","龍舟魚","龍舟","",2,"fish","none",0,45,"其他"),
("fish-059","其他魚類","半嘴魚","半嘴","Hemiramphus far",1,"fish","none",0,35,"其他"),
("fish-060","其他魚類","針魚","針魚","Petalichthys capensis",1,"fish","none",0,30,"其他"),
# 底棲近岸類 061-071
("fish-061","其他魚類","青針魚","青針","",1,"fish","none",0,30,"其他"),
("fish-062","底棲近岸類","比目魚","左口魚","Asterorhombus cocosensis",2,"fish","none",0,55,"其他"),
("fish-063","底棲近岸類","海鯰","海塘蝨","Genidens barbus",2,"fish","none",0,45,"其他"),
("fish-064","底棲近岸類","大鱗烏頭","大眼烏頭","Ellochelon vaigiensis",2,"fish","none",0,55,"其他"),
("fish-065","底棲近岸類","彈塗魚","彈塗","Periophthalmus barbarus",1,"fish","none",0,30,"其他"),
("fish-066","底棲近岸類","灰烏頭","烏頭","Chelon labrosus",1,"fish","none",0,35,"其他"),
("fish-067","底棲近岸類","狗母魚","狗母","Synodus variegatus",1,"fish","none",0,30,"其他"),
("fish-068","底棲近岸類","花狗母魚","花狗母","",1,"fish","none",0,30,"其他"),
("fish-069","底棲近岸類","鰕虎魚","狗公魚","Neogobius melanostomus",1,"fish","none",0,25,"其他"),
("fish-070","底棲近岸類","鰻尾鯰","海塘蝨","Tandanus tandanus",2,"fish","none",0,40,"其他"),
("fish-071","底棲近岸類","康吉鰻","星鰻","Conger conger",3,"fish","none",0,75,"其他"),
# 石斑類 072-079
("fish-072","石斑類","橙點石斑","紅斑","Epinephelus coioides",3,"fish","none",0,120,"其他"),
("fish-073","石斑類","芝麻石斑","芝麻斑","",3,"fish","none",0,110,"其他"),
("fish-074","石斑類","花頭石斑","花頭斑","",3,"fish","none",0,110,"其他"),
("fish-075","石斑類","香港石斑","青斑","Epinephelus akaara",3,"fish","none",0,115,"其他"),
("fish-076","石斑類","馬拉巴石斑","老虎斑","Epinephelus malabaricus",3,"fish","none",0,130,"其他"),
("fish-077","石斑類","黑線石斑","黑線斑","",3,"fish","none",0,110,"其他"),
("fish-078","石斑類","龍膽石斑","龍躉","Epinephelus lanceolatus",4,"fish","none",0,250,"其他"),
# 礁棲觀賞類 080-085
("fish-079","礁棲觀賞類","箱魨","箱魨","Ostracion cubicum",2,"fish","none",0,50,"其他"),
("fish-080","礁棲觀賞類","扳機魚","炮彈魚","Balistoides viridescens",2,"fish","none",0,55,"其他"),
("fish-081","礁棲觀賞類","橙點馬面魨","馬面","Cantherhines pullus",2,"fish","none",0,50,"其他"),
("fish-082","礁棲觀賞類","長帆馬面魨","長帆馬面","Stephanolepis cirrhifer",2,"fish","none",0,45,"其他"),
("fish-083","礁棲觀賞類","蝶魚","蝴蝶魚","Chaetodon marleyi",2,"fish","none",0,40,"其他"),
("fish-084","礁棲觀賞類","鸚哥魚","鸚哥","Sparisoma viride",3,"fish","none",0,65,"其他"),
# 近岸草食類 086
("fish-085","近岸草食類","泥鯭","泥鯭","Siganus fuscescens",1,"fish","none",0,30,"其他"),
# 鯛科/笛鯛類 086-108
("fish-086","鯛科/笛鯛類","三點雀鯛","三點姑娘魚","",2,"fish","none",0,45,"其他"),
("fish-087","鯛科/笛鯛類","天竺鯛","天竺鯛","Apogon imberbis",2,"fish","none",0,40,"其他"),
("fish-088","鯛科/笛鯛類","星點笛鯛","星點紅友","Lutjanus stellatus",3,"fish","none",0,90,"其他"),
("fish-089","鯛科/笛鯛類","橫帶小鯛","橫帶小鱲","Labrus viridis",2,"fish","none",0,50,"其他"),
("fish-090","鯛科/笛鯛類","沙鯛","沙鱲","",2,"fish","none",0,55,"其他"),
("fish-091","鯛科/笛鯛類","油鯛","油甘魚","",2,"fish","none",0,55,"其他"),
("fish-092","鯛科/笛鯛類","火焰笛鯛","火焰紅友","Etelis coruscans",4,"fish","none",0,180,"其他"),
("fish-093","鯛科/笛鯛類","牙點鯛","牙點鱲","",2,"fish","none",0,50,"其他"),
("fish-094","鯛科/笛鯛類","白鯛","白鱲","Diplodus lineatus",2,"fish","none",0,55,"其他"),
("fish-095","鯛科/笛鯛類","約翰笛鯛","黃雞魚","",2,"fish","none",0,65,"其他"),
("fish-096","鯛科/笛鯛類","紅樹笛鯛","紅衫公","Lutjanus argentimaculatus",3,"fish","none",0,95,"其他"),
("fish-097","鯛科/笛鯛類","紅鯛","紅鱲","Pagrus major",2,"fish","none",0,70,"其他"),
("fish-098","鯛科/笛鯛類","羅素笛鯛","紅友","Lutjanus russellii",3,"fish","none",0,90,"其他"),
("fish-099","鯛科/笛鯛類","赤鯛","赤鱲","",2,"fish","none",0,60,"其他"),
("fish-100","鯛科/笛鯛類","金線鯛","紅衫","Rhabdosargus sarba",2,"fish","none",0,60,"其他"),
("fish-101","鯛科/笛鯛類","金線鯛王","大紅衫","",3,"fish","none",0,85,"其他"),
("fish-102","鯛科/笛鯛類","鋸緣雀鯛","鋸緣姑娘魚","",2,"fish","none",0,45,"其他"),
("fish-103","鯛科/笛鯛類","雀鯛","姑娘魚","Chromis chromis",1,"fish","none",0,35,"其他"),
("fish-104","鯛科/笛鯛類","馬友鯛","馬友鱲","",2,"fish","none",0,55,"其他"),
("fish-105","鯛科/笛鯛類","黃尾笛鯛","黃尾紅友","Caesio cuning",2,"fish","none",0,65,"其他"),
("fish-106","鯛科/笛鯛類","黃尾雀鯛","黃尾姑娘魚","Microspathodon chrysurus",2,"fish","none",0,45,"其他"),
("fish-107","鯛科/笛鯛類","黃鰭鯛","黃腳鱲","Acanthopagrus latus",2,"fish","none",0,70,"其他"),
("fish-108","鯛科/笛鯛類","黑沙鯛","黑沙鱲","",2,"fish","none",0,55,"其他"),
("fish-109","鯛科/笛鯛類","黑鯛","烏頭鱲","Spondyliosoma cantharus",2,"fish","none",0,60,"其他"),
# 鰺科/洄游類 110-124
("fish-110","鰺科/洄游類","印度鯖","鯖魚","Rastrelliger kanagurta",2,"fish","none",0,55,"其他"),
("fish-111","鰺科/洄游類","大眼竹筴魚","大眼竹筴","",2,"fish","none",0,45,"其他"),
("fish-112","鰺科/洄游類","大眼竹筴魚王","竹筴王","Selar crumenophthalmus",3,"fish","none",0,70,"其他"),
("fish-113","鰺科/洄游類","橙鰭銀腹鯧鰺","黃腳鯧鰺","Photopectoralis bindus",2,"fish","none",0,55,"其他"),
("fish-114","鰺科/洄游類","紫胸馬加鰆","馬加鰆","Rhinomuraena quaesita",3,"fish","none",0,90,"其他"),
("fish-115","鰺科/洄游類","細鱗竹筴魚","細鱗竹筴","Alepes apercna",2,"fish","none",0,45,"其他"),
("fish-116","鰺科/洄游類","金鰭鰺","金鰭瓜","Gnathanodon speciosus",2,"fish","none",0,60,"其他"),
("fish-117","鰺科/洄游類","銀腹鯧鰺","鯧鰺","Leiognathus equula",1,"fish","none",0,35,"其他"),
("fish-118","鰺科/洄游類","長尾吞拿","吞拿","Thunnus tonggol",3,"fish","none",0,110,"其他"),
("fish-119","鰺科/洄游類","馬拉巴鰺","白瓜","Platycaranx malabaricus",2,"fish","none",0,45,"其他"),
("fish-120","鰺科/洄游類","黃尾擬鰺","黃尾瓜","",2,"fish","none",0,45,"其他"),
("fish-121","鰺科/洄游類","黃尾竹筴魚","竹筴","Trachurus novaezelandiae",2,"fish","none",0,50,"其他"),
("fish-122","鰺科/洄游類","黃條鰺","黃條瓜","Selaroides leptolepis",2,"fish","none",0,50,"其他"),
("fish-123","鰺科/洄游類","藍圓鰺","池仔","Decapterus maruadsi",1,"fish","none",0,30,"其他"),
# 鯖科 125-127
("fish-124","鯖科","青鱗小沙丁","青鱗沙甸","",1,"fish","none",0,25,"其他"),
("fish-125","鯖科","花鰹","花煙","Euthynnus affinis",2,"fish","none",0,55,"其他"),
("fish-126","鯖科","印度鯖","鯖魚","Rastrelliger kanagurta",2,"fish","none",0,55,"其他"),
("fish-127","鯖科","日本鯖","鯖魚","Scomber japonicus",2,"fish","none",0,50,"其他"),
]

# ── 新增 26 種（isNew=True） ───────────────────────────────────────────
NEW_26 = [
# 石斑類 +6
("NEW","石斑類","杉斑","杉斑","Epinephelus polyphekadion",3,"fish","none",0,120,True),
("NEW","石斑類","老鼠斑","老鼠斑","Cromileptes altivelis",5,"fish","none",0,380,True),
("NEW","石斑類","西星斑","西星斑","Plectropomus laevis",4,"fish","none",0,250,True),
("NEW","石斑類","金錢斑","金錢斑","Epinephelus amblycephalus",4,"fish","none",0,220,True),
("NEW","石斑類","蘇鼠斑","蘇鼠斑","Epinephelus tukula",5,"fish","none",0,420,True),
("NEW","石斑類","紅瓜子斑","紅瓜子斑","Epinephelus areolatus",3,"fish","none",0,150,True),
# 笛鯛科 +4
("NEW","笛鯛科","五線笛鯛","五間畫眉","Lutjanus quinquelineatus",2,"fish","none",0,80,True),
("NEW","笛鯛科","四間畫眉","四間畫眉","Lutjanus kasmira",2,"fish","none",0,75,True),
("NEW","笛鯛科","千年笛鯛","白點笛鯛","Lutjanus rivulatus",4,"fish","none",0,180,True),
("NEW","笛鯛科","約氏笛鯛","約翰紅友","Lutjanus johnii",3,"fish","none",0,130,True),
# 䱛/石首魚科 +5
("NEW","䱛/石首魚科","雞蛋䱛","雞蛋䱛","Collichthys lucidus",2,"fish","none",0,60,True),
("NEW","䱛/石首魚科","老鼠䱛","老鼠䱛","Johnius dussumieri",2,"fish","none",0,55,True),
("NEW","䱛/石首魚科","紅牙䱛","丁友","Otolithes ruber",3,"fish","none",0,95,True),
("NEW","䱛/石首魚科","鮸魚","米魚","Miichthys miiuy",3,"fish","none",0,110,True),
("NEW","䱛/石首魚科","黃唇魚","金錢鮸","Bahaba taipingensis",5,"fish","none",0,0,True),
# 鱸科 +2
("NEW","鱸科","花尾胡椒鯛","花雞","Plectorhinchus cinctus",3,"fish","none",0,100,True),
("NEW","鱸科","中華烏塘鱧","黑咕咕","Bostrychus sinensis",2,"fish","none",0,65,True),
# 鰍/鮋科 +3
("NEW","鰍/鮋科","石狗公","石狗公","Sebastiscus marmoratus",3,"fish","none",2,90,True),
("NEW","鰍/鮋科","火點","火點","Scorpaena onaria",3,"fish","none",2,85,True),
("NEW","鰍/鮋科","深水石狗公","白斑菖鮋","Sebastiscus albofasciatus",4,"fish","none",2,140,True),
# 鰺科 +5
("NEW","鰺科","真池魚","巴浪","Trachurus japonicus",2,"fish","none",0,45,True),
("NEW","鰺科","六帶鰺","木棉","Caranx sexfasciatus",3,"fish","none",0,70,True),
("NEW","鰺科","浪花鰺","GT","Caranx ignobilis",5,"fish","none",0,200,True),
("NEW","鰺科","紅瓜","甲鰺","Alepes djedaba",2,"fish","none",0,50,True),
("NEW","鰺科","脂眼凹肩鰺","鬼池魚","Selar crumenophthalmus",2,"fish","none",0,48,True),
# 鯛科/笛鯛類 +1
("NEW","鯛科/笛鯛類","二長棘鯛","盤仔","Parargyrops edita",2,"fish","none",0,75,True),
]

# ── 轉成 dict 格式 ─────────────────────────────────────────────────────
def make_dict(tup, is_new=False):
    # ORIG_127 tuple: (id, fishType, commonNameZh, localNameZh, scientificName, rarityRank, bodyShape, dangerLevel, dangerLevel_int, marketPrice, extra)
    # Actually let me restructure: orig tuple was (old_id, fishType, cn, ln, sci, rarity, shape, danger, danger_int, price, _)
    old_id, fishType, cn, ln, sci, rarity, shape, dl_str, dl_int, price = tup[:10]
    return {
        "old_id": old_id, "fishType": fishType, "commonNameZh": cn,
        "localNameZh": ln, "scientificName": sci, "rarityRank": rarity,
        "bodyShape": shape, "dangerLevelInt": dl_int,
        "marketPrice": price, "isNew": is_new,
    }

existing = [make_dict(t, False) for t in ORIG_127]

def make_new(tup):
    # NEW_26 tuple: (old_id dummy, fishType, cn, ln, sci, rarity, shape, danger, danger_int, price, isNew)
    _, fishType, cn, ln, sci, rarity, shape, dl_str, dl_int, price, _ = tup[:11]
    return {
        "old_id": "NEW", "fishType": fishType, "commonNameZh": cn,
        "localNameZh": ln, "scientificName": sci, "rarityRank": rarity,
        "bodyShape": shape, "dangerLevelInt": dl_int,
        "marketPrice": price, "isNew": True,
    }

new_species = [make_new(t) for t in NEW_26]
print(f"Existing: {len(existing)}, New: {len(new_species)}")

# ── 合併 + 分組排序 ──────────────────────────────────────────────────────
TYPE_ORDER = {
    "其他魚類":0, "底棲近岸類":1, "石斑類":2, "礁棲觀賞類":3,
    "近岸草食類":4, "鯛科/笛鯛類":5, "笛鯛科":6, "䱛/石首魚科":7,
    "鱸科":8, "鰍/鮋科":9, "鰺科":10, "鯖科":11,
}
def sort_key(s):
    to = TYPE_ORDER.get(s["fishType"], 99)
    return (to, s["rarityRank"], s["commonNameZh"])

all_species = existing + new_species
all_species.sort(key=sort_key)

# ── 分配新 ID ──────────────────────────────────────────────────────────
for i, sp in enumerate(all_species, 1):
    sp["new_id"] = f"fish-{i:03d}"

# ── 寫 CSV ─────────────────────────────────────────────────────────────
csv_path = os.path.join(OUT_DIR, "old_new_mapping.csv")
fieldnames = ["old_id","new_id","commonNameZh","localNameZh","scientificName",
              "fishType","bodyShape","rarityRank","dangerLevelInt","marketPrice","isNew"]
with open(csv_path, "w", newline="", encoding="utf-8-sig") as f:
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    for sp in all_species:
        w.writerow({k: sp[k] for k in fieldnames})
print(f"CSV: {csv_path}")

# ── 寫 TXT 報告 ────────────────────────────────────────────────────────
txt_path = os.path.join(OUT_DIR, "renumbered_fish_catalog.txt")
with open(txt_path, "w", encoding="utf-8") as f:
    for sp in all_species:
        marker = " ★NEW★" if sp["isNew"] else ""
        old = sp["old_id"]
        new = sp["new_id"]
        f.write(f"{new.replace('fish-',''):>3} | {old.replace('fish-','').replace('NEW','--'):>3} | "
                f"{sp['commonNameZh']:<10} | {sp['localNameZh']:<10} | {sp['fishType']:<12} | R{sp['rarityRank']}{marker}\n")
print(f"TXT: {txt_path}")

# ── 驗證 ───────────────────────────────────────────────────────────────
ids = [sp["new_id"] for sp in all_species]
assert len(ids)==len(set(ids)), "Duplicate new IDs!"
num_ids = [int(id.replace("fish-","")) for id in ids]
assert num_ids == list(range(1,len(num_ids)+1)), "Non-contiguous!"
print(f"  IDs 001-{len(all_species):03d} contiguous: OK")
for ft, grp in [(ft,[sp["new_id"] for sp in all_species if sp["fishType"]==ft]) for ft in TYPE_ORDER]:
    if grp: print(f"  {ft}: {grp[0]} → {grp[-1]} ({len(grp)} spp)")
sci_names = [sp["scientificName"] for sp in all_species if sp["scientificName"]]
if len(sci_names) != len(set(sci_names)):
    from collections import Counter
    dupes = [n for n,c in Counter(sci_names).items() if c>1]
    print(f"  DUPLICATE scientific names: {dupes}")
else:
    print("  Scientific name uniqueness: OK")
print(f"\nTotal: {len(all_species)} (127 orig + 26 new)")
print("DONE")