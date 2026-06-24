from pathlib import Path
import re
from datetime import datetime
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(r'C:\Users\s0829\fishergo')
DART = ROOT / r'lib\features\fish\data\sample_fish_species_data_source.dart'
PHOTO_DIR = ROOT / r'data\fish_audit4\photo_cache'
OUT_DIR = ROOT / r'data\fish_audit4\compare_pdf'
OUT_DIR.mkdir(parents=True, exist_ok=True)
stamp = datetime.now().strftime('%Y%m%d_%H%M%S')
OUT_PDF = OUT_DIR / f'fishergo_icon_vs_realphoto_left_right_{stamp}.pdf'
OUT_REPORT = OUT_DIR / f'fishergo_icon_vs_realphoto_left_right_{stamp}_report.txt'

text = DART.read_text(encoding='utf-8')
block_re = re.compile(r"FishSpecies\(\s*id: 'fish-(\d{3})'.*?\n\s*\),", re.S)

def val(block, field):
    m = re.search(rf"{re.escape(field)}: (null|'((?:[^'\\]|\\.)*)')(?=,)", block)
    if not m:
        return ''
    return '' if m.group(1) == 'null' else m.group(2)

items = []
for m in block_re.finditer(text):
    idx = m.group(1)
    block = m.group(0)
    image_url = val(block, 'imageUrl')
    icon_path = ROOT / image_url if image_url else ROOT / 'assets' / 'fish' / 'icons' / 'generated' / f'{idx}.png'
    if not icon_path.exists():
        icon_path = ROOT / 'assets' / 'fish' / 'icons' / 'generated' / f'{idx}.png'
    photo_path = PHOTO_DIR / f'fish-{idx}.jpg'
    items.append({
        'idx': idx,
        'common': val(block, 'commonNameZh') or '',
        'local': val(block, 'localNameZh') or '',
        'sci': val(block, 'scientificName') or '',
        'icon_path': icon_path,
        'photo_path': photo_path,
    })

# A4 landscape at 150 dpi
W, H = 1754, 1240
M = 55
HEADER_H = 80
ROW_GAP = 25
ROWS_PER_PAGE = 2
ROW_H = (H - HEADER_H - M - ROW_GAP * (ROWS_PER_PAGE - 1) - M) // ROWS_PER_PAGE
LEFT_X = M
RIGHT_X = W // 2 + 18
COL_W = (W - M * 2 - 36) // 2
IMG_H = ROW_H - 95
IMG_W = COL_W - 28

font_candidates = [
    r'C:\Windows\Fonts\msjh.ttc',
    r'C:\Windows\Fonts\mingliu.ttc',
    r'C:\Windows\Fonts\simhei.ttf',
    r'C:\Windows\Fonts\arial.ttf',
]
font_path = next((p for p in font_candidates if Path(p).exists()), None)
font_title = ImageFont.truetype(font_path, 34) if font_path else ImageFont.load_default()
font_head = ImageFont.truetype(font_path, 24) if font_path else ImageFont.load_default()
font_body = ImageFont.truetype(font_path, 20) if font_path else ImageFont.load_default()
font_small = ImageFont.truetype(font_path, 16) if font_path else ImageFont.load_default()

def cover_fit(path, box, bg='white'):
    canvas = Image.new('RGB', box, bg)
    if not path or not Path(path).exists():
        d = ImageDraw.Draw(canvas)
        d.rectangle([0, 0, box[0]-1, box[1]-1], outline=(180, 180, 180), width=3)
        d.line([20, 20, box[0]-20, box[1]-20], fill=(180, 180, 180), width=4)
        d.line([box[0]-20, 20, 20, box[1]-20], fill=(180, 180, 180), width=4)
        d.text((box[0]//2-70, box[1]//2-12), '圖片缺失', fill=(120, 120, 120), font=font_body)
        return canvas
    try:
        im = Image.open(path).convert('RGB')
        im = ImageOps.contain(im, box, Image.Resampling.LANCZOS)
        canvas.paste(im, ((box[0]-im.width)//2, (box[1]-im.height)//2))
        return canvas
    except Exception:
        return cover_fit(None, box, bg)

def draw_centered(draw, xy, text, font, fill=(0,0,0)):
    x, y, w = xy
    bbox = draw.textbbox((0,0), text, font=font)
    draw.text((x + (w - (bbox[2]-bbox[0]))//2, y), text, font=font, fill=fill)

pages = []
missing_icons = 0
missing_photos = 0
for page_start in range(0, len(items), ROWS_PER_PAGE):
    page_items = items[page_start:page_start + ROWS_PER_PAGE]
    page = Image.new('RGB', (W, H), (248, 249, 250))
    d = ImageDraw.Draw(page)
    d.text((M, 25), 'FisherGO 簡介圖 vs 實物圖｜左右對照', font=font_title, fill=(20, 30, 40))
    page_no = page_start // ROWS_PER_PAGE + 1
    total_pages = (len(items) + ROWS_PER_PAGE - 1) // ROWS_PER_PAGE
    d.text((W - 210, 35), f'{page_no}/{total_pages}', font=font_head, fill=(70, 70, 70))
    for r, item in enumerate(page_items):
        y = HEADER_H + r * (ROW_H + ROW_GAP)
        d.rounded_rectangle([M, y, W-M, y+ROW_H], radius=18, fill='white', outline=(210, 215, 220), width=2)
        title = f"{item['idx']}  {item['common']} / {item['local']}"
        sci = item['sci'] or 'scientificName 缺失'
        d.text((M+22, y+14), title, font=font_head, fill=(10, 20, 30))
        d.text((M+22, y+45), sci, font=font_small, fill=(95, 95, 95))
        d.line([W//2, y+82, W//2, y+ROW_H-18], fill=(220, 220, 220), width=2)
        draw_centered(d, (LEFT_X, y+72, COL_W), 'FisherGO 簡介圖', font_body, (35, 80, 150))
        draw_centered(d, (RIGHT_X, y+72, COL_W), '實物參考圖', font_body, (120, 60, 20))
        icon_missing = not item['icon_path'].exists()
        photo_missing = not item['photo_path'].exists()
        missing_icons += int(icon_missing)
        missing_photos += int(photo_missing)
        icon = cover_fit(item['icon_path'], (IMG_W, IMG_H), 'white')
        photo = cover_fit(item['photo_path'], (IMG_W, IMG_H), 'white')
        page.paste(icon, (LEFT_X+14, y+110))
        page.paste(photo, (RIGHT_X+14, y+110))
        d.rectangle([LEFT_X+14, y+110, LEFT_X+14+IMG_W, y+110+IMG_H], outline=(230,230,230), width=2)
        d.rectangle([RIGHT_X+14, y+110, RIGHT_X+14+IMG_W, y+110+IMG_H], outline=(230,230,230), width=2)
    pages.append(page)

if not pages:
    raise SystemExit('No fish items parsed')
pages[0].save(OUT_PDF, save_all=True, append_images=pages[1:], resolution=150.0)
OUT_REPORT.write_text(
    f'PDF={OUT_PDF}\n'
    f'items={len(items)}\n'
    f'pages={len(pages)}\n'
    f'missing_icons={missing_icons}\n'
    f'missing_photos={missing_photos}\n'
    f'source_dart={DART}\n'
    f'photo_dir={PHOTO_DIR}\n',
    encoding='utf-8'
)
print(f'PDF={OUT_PDF}')
print(f'REPORT={OUT_REPORT}')
print(f'ITEMS={len(items)} PAGES={len(pages)} MISSING_ICONS={missing_icons} MISSING_PHOTOS={missing_photos}')
