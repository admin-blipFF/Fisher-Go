from pathlib import Path
import re, csv, shutil, urllib.request, urllib.parse, json, time, ssl
from datetime import datetime

root = Path(r'C:\Users\s0829\fishergo')
dart = root / 'lib/features/fish/data/sample_fish_species_data_source.dart'
stamp = datetime.now().strftime('%Y%m%d_%H%M%S')
out = root / 'data' / f'fish整理_簡介圖實物圖_{stamp}'
icons_dir = out / '01_fishergo_icons'
photos_dir = out / '02_real_photos'
sheets_dir = out / '03_compare_sheets'
for d in [icons_dir, photos_dir, sheets_dir]:
    d.mkdir(parents=True, exist_ok=True)

text = dart.read_text(encoding='utf-8')
block_re = re.compile(r"FishSpecies\(\s*id: 'fish-(\d{3})'.*?\n\s*\),", re.S)

def val(block, field):
    m = re.search(rf"{re.escape(field)}: (null|'((?:[^'\\]|\\.)*)')(?=,)", block)
    if not m:
        return ''
    return '' if m.group(1) == 'null' else m.group(2)

species=[]
for m in block_re.finditer(text):
    idx=m.group(1); block=m.group(0)
    species.append({
        'index': idx,
        'id': f'fish-{idx}',
        'afcdId': val(block,'afcdId'),
        'commonNameZh': val(block,'commonNameZh'),
        'localNameZh': val(block,'localNameZh'),
        'scientificName': val(block,'scientificName'),
        'fishType': val(block,'fishType'),
        'bodyShape': val(block,'bodyShape'),
        'rarityRank': val(block,'rarityRank'),
        'imageUrl': val(block,'imageUrl'),
    })

safe_re = re.compile(r'[\\/:*?"<>|\s]+')
def safe_name(s):
    s = safe_re.sub('_', (s or '').strip())
    return s[:80] or 'unknown'

def http_json(url, timeout=12):
    req = urllib.request.Request(url, headers={'User-Agent':'FisherGO-audit/1.0 educational asset validation'})
    with urllib.request.urlopen(req, timeout=timeout, context=ssl.create_default_context()) as r:
        return json.loads(r.read().decode('utf-8', errors='replace'))

def download(url, dest, timeout=18):
    req = urllib.request.Request(url, headers={'User-Agent':'FisherGO-audit/1.0 educational asset validation'})
    with urllib.request.urlopen(req, timeout=timeout, context=ssl.create_default_context()) as r:
        dest.write_bytes(r.read())

def ext_from_url(url):
    path=urllib.parse.urlparse(url).path.lower()
    for ext in ['.jpg','.jpeg','.png','.webp']:
        if path.endswith(ext): return '.jpg' if ext=='.jpeg' else ext
    return '.jpg'

fallback = {}
for p in [root/'data/fish_audit3/audit_sources.csv', root/'data/fish_audit2/audit_sources.csv', root/'data/fish_audit/audit_sources.csv']:
    if p.exists():
        with p.open('r',encoding='utf-8-sig',newline='') as f:
            for r in csv.DictReader(f):
                sci=(r.get('scientificName') or '').strip()
                url=(r.get('photo_url') or '').strip()
                if sci and url and str(r.get('photo_found')).lower() in ('1','true','yes'):
                    fallback.setdefault(sci, url)

photo_cache = {}
rows=[]
for i,sp in enumerate(species,1):
    idx=sp['index']; common=sp['commonNameZh']; local=sp['localNameZh']; sci=sp['scientificName']
    label = f"{idx}_{safe_name(common)}_{safe_name(local)}"
    src_icon=root / sp['imageUrl']
    icon_out = icons_dir / f'{label}.png'
    if src_icon.exists():
        shutil.copy2(src_icon, icon_out)
        icon_status='copied'
    else:
        icon_status='missing'
    photo_url=''; source=''; photo_status='missing'; photo_path=''
    if sci:
        if sci in photo_cache:
            photo_url, source = photo_cache[sci]
        else:
            try:
                q=urllib.parse.urlencode({'q':sci, 'rank':'species,subspecies', 'per_page':'5'})
                taxa=http_json(f'https://api.inaturalist.org/v1/taxa/autocomplete?{q}')
                taxon_id=None; matched=''
                for t in taxa.get('results',[]):
                    name=t.get('name','')
                    if name.lower()==sci.lower() or name.lower().startswith(sci.lower()+' '):
                        taxon_id=t.get('id'); matched=name; break
                if taxon_id:
                    oq=urllib.parse.urlencode({'taxon_id':taxon_id,'photos':'true','quality_grade':'research','per_page':'6','order_by':'votes'})
                    obs=http_json(f'https://api.inaturalist.org/v1/observations?{oq}')
                    for ob in obs.get('results',[]):
                        photos=ob.get('photos') or []
                        if photos:
                            u=photos[0].get('url') or ''
                            photo_url=u.replace('square.','large.').replace('medium.','large.')
                            source=f'iNaturalist:{matched}'
                            break
                if not photo_url and sci in fallback:
                    photo_url=fallback[sci]; source='existing_audit_fallback_by_scientificName'
            except Exception as e:
                source=f'lookup_error:{type(e).__name__}'
            photo_cache[sci]=(photo_url,source)
    if photo_url:
        try:
            dest=photos_dir / f'{label}{ext_from_url(photo_url)}'
            download(photo_url,dest)
            photo_path=str(dest.relative_to(out))
            photo_status='downloaded'
        except Exception as e:
            photo_status=f'download_error:{type(e).__name__}'
    rows.append({**sp,
        'icon_file': str(icon_out.relative_to(out)) if icon_out.exists() else '',
        'icon_status': icon_status,
        'real_photo_file': photo_path,
        'real_photo_url': photo_url,
        'real_photo_source': source,
        'real_photo_status': photo_status,
    })
    if i % 10 == 0:
        print(f'processed {i}/{len(species)}')
        time.sleep(0.2)

fields=['index','id','afcdId','commonNameZh','localNameZh','scientificName','fishType','bodyShape','rarityRank','imageUrl','icon_file','icon_status','real_photo_file','real_photo_url','real_photo_source','real_photo_status']
with (out/'fish_info整理.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(rows)
missing=[r for r in rows if r['real_photo_status']!='downloaded']
(out/'README.txt').write_text(
    f"FisherGO 簡介圖與實物圖整理\n建立時間: {stamp}\n來源資料: {dart}\n魚種數量: {len(rows)}\nFisherGO 圖片: {sum(1 for r in rows if r['icon_status']=='copied')}\n實物圖下載成功: {sum(1 for r in rows if r['real_photo_status']=='downloaded')}\n實物圖缺失/錯誤: {len(missing)}\n\n01_fishergo_icons = FisherGO 內的簡介圖副本\n02_real_photos = 按校正後 scientificName 找到的實物圖\n03_compare_sheets = 對比預覽圖\nfish_info整理.csv = 每條魚的文字資料、圖片路徑、實物圖來源\n",
    encoding='utf-8')

sheet_count=0
try:
    from PIL import Image, ImageDraw, ImageFont
    font_paths=[r'C:\Windows\Fonts\msjh.ttc', r'C:\Windows\Fonts\mingliu.ttc', r'C:\Windows\Fonts\simhei.ttf', r'C:\Windows\Fonts\arial.ttf']
    font_path=next((p for p in font_paths if Path(p).exists()), None)
    font=ImageFont.truetype(font_path, 22) if font_path else ImageFont.load_default()
    small=ImageFont.truetype(font_path, 16) if font_path else ImageFont.load_default()
    cell_w, cell_h = 520, 340
    cols, rows_per = 2, 5
    def fit(path, size):
        im=Image.open(path).convert('RGB')
        im.thumbnail(size, Image.LANCZOS)
        canvas=Image.new('RGB', size, 'white')
        canvas.paste(im, ((size[0]-im.width)//2, (size[1]-im.height)//2))
        return canvas
    downloaded = [r for r in rows if r['icon_file'] and r['real_photo_file']]
    for page_start in range(0, len(downloaded), cols*rows_per):
        page=downloaded[page_start:page_start+cols*rows_per]
        sheet=Image.new('RGB',(cols*cell_w, rows_per*cell_h),(245,245,245))
        draw=ImageDraw.Draw(sheet)
        for j,r in enumerate(page):
            c=j%cols; rr=j//cols; x=c*cell_w; y=rr*cell_h
            draw.rectangle([x+4,y+4,x+cell_w-4,y+cell_h-4], fill='white', outline=(190,190,190))
            title=f"{r['index']} {r['commonNameZh']} / {r['localNameZh']}"
            draw.text((x+12,y+10),title,fill=(0,0,0),font=font)
            draw.text((x+12,y+38),r['scientificName'] or 'scientificName: missing',fill=(70,70,70),font=small)
            sheet.paste(fit(out/r['icon_file'], (210,210)),(x+18,y+75))
            sheet.paste(fit(out/r['real_photo_file'], (250,210)),(x+245,y+75))
            draw.text((x+60,y+290),'FisherGO簡介圖',fill=(40,40,40),font=small)
            draw.text((x+305,y+290),'實物圖',fill=(40,40,40),font=small)
        sheet_count+=1
        sheet.save(sheets_dir/f'compare_sheet_{sheet_count:02d}.jpg', quality=92)
except Exception as e:
    (out/'compare_sheet_error.txt').write_text(str(e),encoding='utf-8')

print(f'OUT={out}')
print(f'SPECIES={len(rows)} ICONS={sum(1 for r in rows if r["icon_status"]=="copied")} PHOTOS={sum(1 for r in rows if r["real_photo_status"]=="downloaded")} MISSING_PHOTOS={len(missing)} SHEETS={sheet_count}')
if missing:
    print('MISSING_FIRST_30=' + ', '.join([f"{r['index']}{r['commonNameZh']}({r['scientificName'] or 'no-sci'})" for r in missing[:30]]))
