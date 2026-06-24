from __future__ import annotations

from pathlib import Path
import csv
import json
import re
import ssl
import time
import urllib.parse
import urllib.request
from datetime import datetime
from typing import Any

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(r"C:\Users\s0829\fishergo")
DART = ROOT / r"lib\features\fish\data\sample_fish_species_data_source.dart"
OUT = ROOT / r"data\fish_audit6_full_rebuild"
PHOTO_DIR = OUT / "photo_cache"
REPORT_DIR = OUT / "reports"
PHOTO_DIR.mkdir(parents=True, exist_ok=True)
REPORT_DIR.mkdir(parents=True, exist_ok=True)
STAMP = datetime.now().strftime("%Y%m%d_%H%M%S")

UA = "FisherGO-full-rebuild/1.0 educational species image validation"
BAD_TITLE_KEYWORDS = [
    "沙茶", "賽龍舟", "花崗岩", "料理", "文集", "djvu", "分类表", "分類表",
    "科", "family", "list", "列表", "目錄", "category", "commons category",
]
FISH_TITLE_HINTS = [
    "fish", "鯛", "鯧", "鰺", "鯖", "鱚", "鱸", "鯊", "鰻", "魨", "鯰", "鱵", "鳚", "鮋", "石斑", "隆頭", "竹筴", "goatfish",
    "snapper", "grouper", "mackerel", "blenny", "trevally", "sillago", "siganus", "lutjanus", "epinephelus",
]


def http_json(url: str, timeout: int = 18) -> dict[str, Any]:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout, context=ssl.create_default_context()) as r:
        return json.loads(r.read().decode("utf-8", errors="replace"))


def download(url: str, dest: Path, timeout: int = 30) -> bool:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout, context=ssl.create_default_context()) as r:
        data = r.read()
    dest.write_bytes(data)
    return dest.exists() and dest.stat().st_size > 1000


def dart_val(block: str, field: str) -> str:
    m = re.search(rf"{re.escape(field)}:\s*(null|'([^']*)'|([0-9]+))", block)
    if not m:
        return ""
    if m.group(1) == "null":
        return ""
    return (m.group(2) or m.group(3) or "").strip()


def parse_species() -> list[dict[str, str]]:
    text = DART.read_text(encoding="utf-8")
    block_re = re.compile(r"FishSpecies\(\s*id: 'fish-(\d{3})'.*?\n\s*\),", re.S)
    rows: list[dict[str, str]] = []
    for m in block_re.finditer(text):
        idx = m.group(1)
        block = m.group(0)
        image = dart_val(block, "imageUrl") or f"assets/fish/icons/generated/{idx}.png"
        rows.append({
            "new_id": idx,
            "commonNameZh": dart_val(block, "commonNameZh"),
            "localNameZh": dart_val(block, "localNameZh"),
            "scientificName": dart_val(block, "scientificName"),
            "fishType": dart_val(block, "fishType"),
            "bodyShape": dart_val(block, "bodyShape"),
            "rarityRank": dart_val(block, "rarityRank"),
            "imageUrl": image,
            "icon_abs": str(ROOT / image),
        })
    return rows


def inat_lookup_by_sci(sci: str) -> tuple[str, str, str, str, str]:
    if not sci:
        return "", "", "", "", "no_scientific_name"
    q = urllib.parse.urlencode({"q": sci, "rank": "species,subspecies", "per_page": "8"})
    taxa = http_json(f"https://api.inaturalist.org/v1/taxa/autocomplete?{q}")
    taxon_id = None
    matched_name = ""
    for t in taxa.get("results", []):
        name = (t.get("name") or "").strip()
        if name.lower() == sci.lower() or name.lower().startswith(sci.lower() + " "):
            taxon_id = t.get("id")
            matched_name = name
            break
    if not taxon_id:
        return "", "", "", "", "inat_taxon_not_found"
    oq = urllib.parse.urlencode({"taxon_id": taxon_id, "photos": "true", "quality_grade": "research", "per_page": "8", "order_by": "votes"})
    obs = http_json(f"https://api.inaturalist.org/v1/observations?{oq}")
    for ob in obs.get("results", []):
        for ph in ob.get("photos") or []:
            url = (ph.get("url") or "").replace("square.", "large.").replace("medium.", "large.")
            if url:
                return url, "iNaturalist", matched_name, f"taxon_id={taxon_id}", "high"
    return "", "", matched_name, f"taxon_id={taxon_id}", "inat_no_observation_photo"


def wiki_lookup_strict(terms: list[str]) -> tuple[str, str, str, str, str]:
    # Strict fallback only. Reject generic family/list/food/boat/non-fish titles.
    for term in terms:
        if not term:
            continue
        for lang in ["zh", "yue", "en"]:
            try:
                api = f"https://{lang}.wikipedia.org/w/api.php"
                params = urllib.parse.urlencode({"action": "query", "list": "search", "srsearch": term, "srlimit": "5", "format": "json", "utf8": "1"})
                data = http_json(api + "?" + params)
                for hit in data.get("query", {}).get("search", []):
                    title = (hit.get("title") or "").strip()
                    low = title.lower()
                    if any(b.lower() in low for b in BAD_TITLE_KEYWORDS):
                        continue
                    # Require title to contain a query term OR fish-like hint. This keeps it conservative.
                    if term not in title and not any(h in low for h in FISH_TITLE_HINTS):
                        continue
                    params2 = urllib.parse.urlencode({"action": "query", "titles": title, "prop": "pageimages|info", "pithumbsize": "1000", "inprop": "url", "format": "json", "utf8": "1"})
                    data2 = http_json(api + "?" + params2)
                    for p in data2.get("query", {}).get("pages", {}).values():
                        thumb = (p.get("thumbnail") or {}).get("source")
                        fullurl = p.get("fullurl", "")
                        if thumb:
                            return thumb, f"Wikipedia-{lang}", title, fullurl, "medium"
            except Exception:
                continue
    return "", "", "", "", "not_found"


def make_pdf(rows: list[dict[str, str]], pdf_path: Path) -> None:
    W, H = 1754, 1240
    M, HEADER_H, ROW_GAP, ROWS_PER_PAGE = 50, 75, 22, 2
    ROW_H = (H - HEADER_H - M - ROW_GAP * (ROWS_PER_PAGE - 1) - M) // ROWS_PER_PAGE
    LEFT_X, RIGHT_X = M, W // 2 + 15
    COL_W = (W - M * 2 - 30) // 2
    IMG_W, IMG_H = COL_W - 24, ROW_H - 92
    font_paths = [r"C:\Windows\Fonts\msjh.ttc", r"C:\Windows\Fonts\mingliu.ttc", r"C:\Windows\Fonts\arial.ttf"]
    fp = next((p for p in font_paths if Path(p).exists()), None)
    f_title = ImageFont.truetype(fp, 32) if fp else ImageFont.load_default()
    f_head = ImageFont.truetype(fp, 23) if fp else ImageFont.load_default()
    f_body = ImageFont.truetype(fp, 19) if fp else ImageFont.load_default()
    f_sci = ImageFont.truetype(fp, 15) if fp else ImageFont.load_default()

    def centered(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, text: str, font: ImageFont.ImageFont, fill: tuple[int, int, int]):
        bb = draw.textbbox((0, 0), text, font=font)
        draw.text((x + (w - (bb[2] - bb[0])) // 2, y), text, font=font, fill=fill)

    def fit(path: Path | None, box: tuple[int, int], label: str) -> Image.Image:
        canvas = Image.new("RGB", box, "white")
        d = ImageDraw.Draw(canvas)
        if path and path.exists():
            try:
                im = Image.open(path).convert("RGB")
                im.thumbnail(box, Image.Resampling.LANCZOS)
                canvas.paste(im, ((box[0] - im.width) // 2, (box[1] - im.height) // 2))
                return canvas
            except Exception:
                pass
        d.rectangle([0, 0, box[0] - 1, box[1] - 1], outline=(180, 180, 180), width=3)
        d.line([20, 20, box[0] - 20, box[1] - 20], fill=(180, 180, 180), width=4)
        d.line([box[0] - 20, 20, 20, box[1] - 20], fill=(180, 180, 180), width=4)
        d.text((box[0] // 2 - 58, box[1] // 2 - 10), label, fill=(140, 140, 140), font=f_sci)
        return canvas

    pages: list[Image.Image] = []
    total_pages = (len(rows) + ROWS_PER_PAGE - 1) // ROWS_PER_PAGE
    for start in range(0, len(rows), ROWS_PER_PAGE):
        page_items = rows[start:start + ROWS_PER_PAGE]
        page = Image.new("RGB", (W, H), (245, 247, 250))
        d = ImageDraw.Draw(page)
        d.text((M, 22), "FisherGO 簡介圖 vs 實物圖｜全系統重建版", font=f_title, fill=(15, 25, 45))
        d.text((W - 180, 28), f"{start // ROWS_PER_PAGE + 1}/{total_pages}", font=f_head, fill=(80, 80, 80))
        for ri, r in enumerate(page_items):
            y = HEADER_H + ri * (ROW_H + ROW_GAP)
            d.rectangle([M, y, W - M, y + ROW_H], fill="white", outline=(200, 205, 215), width=2)
            idx = r["new_id"]
            title = f"{idx}  {r['commonNameZh']} / {r['localNameZh']}"
            d.text((M + 20, y + 12), title, font=f_head, fill=(10, 18, 35))
            d.text((M + 20, y + 42), f"sci: {r.get('scientificName') or '—'}", font=f_sci, fill=(90, 90, 90))
            d.text((M + 20, y + 62), f"來源: {r.get('photo_source') or '—'}｜信心: {r.get('confidence') or '—'}", font=f_sci, fill=(130, 130, 130))
            d.line([W // 2, y + 18, W // 2, y + ROW_H - 12], fill=(215, 215, 215), width=2)
            centered(d, LEFT_X, y + 82, COL_W, "FisherGO 簡介圖", f_body, (35, 75, 155))
            centered(d, RIGHT_X, y + 82, COL_W, "實物參考圖", f_body, (130, 55, 15))
            icon = Path(r["icon_abs"])
            photo = PHOTO_DIR / f"fish-{idx}.jpg"
            page.paste(fit(icon, (IMG_W, IMG_H), "icon 缺失"), (LEFT_X + 12, y + 110))
            page.paste(fit(photo if photo.exists() else None, (IMG_W, IMG_H), "未找到實物圖"), (RIGHT_X + 12, y + 110))
            d.rectangle([LEFT_X + 12, y + 110, LEFT_X + 12 + IMG_W, y + 110 + IMG_H], outline=(225, 225, 225), width=2)
            d.rectangle([RIGHT_X + 12, y + 110, RIGHT_X + 12 + IMG_W, y + 110 + IMG_H], outline=(225, 225, 225), width=2)
        pages.append(page)
    pages[0].save(pdf_path, save_all=True, append_images=pages[1:], resolution=150)


def main() -> None:
    rows = parse_species()
    out_rows: list[dict[str, str]] = []
    for i, r in enumerate(rows, 1):
        idx = r["new_id"]
        sci = r.get("scientificName", "")
        url = source = matched = page = confidence = ""
        try:
            url, source, matched, page, confidence = inat_lookup_by_sci(sci)
        except Exception as e:
            confidence = f"inat_error:{type(e).__name__}"
        if not url:
            # Only strict Wiki fallback. Do not accept generic title hits.
            terms = [r.get("commonNameZh", ""), r.get("localNameZh", ""), sci]
            try:
                url, source, matched, page, confidence = wiki_lookup_strict([t for t in terms if t])
            except Exception as e:
                confidence = f"wiki_error:{type(e).__name__}"
        dest = PHOTO_DIR / f"fish-{idx}.jpg"
        photo_status = "missing"
        if url:
            try:
                if download(url, dest):
                    photo_status = "downloaded"
                else:
                    photo_status = "download_failed_small_file"
            except Exception as e:
                photo_status = f"download_error:{type(e).__name__}"
        row = dict(r)
        row.update({
            "photo_url": url,
            "photo_source": source,
            "matched_title_or_taxon": matched,
            "source_page": page,
            "confidence": confidence,
            "photo_status": photo_status,
            "photo_abs": str(dest) if dest.exists() else "",
        })
        out_rows.append(row)
        print(f"[{i:03d}/{len(rows)}] {idx} {r['commonNameZh']}/{r['localNameZh']} sci={sci or '—'} -> {photo_status} {source} {matched} confidence={confidence}")
        time.sleep(0.35)

    csv_path = OUT / f"full_rebuild_audit_{STAMP}.csv"
    fields = [
        "new_id", "commonNameZh", "localNameZh", "scientificName", "fishType", "bodyShape", "rarityRank", "imageUrl", "icon_abs",
        "photo_url", "photo_source", "matched_title_or_taxon", "source_page", "confidence", "photo_status", "photo_abs",
    ]
    with csv_path.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(out_rows)

    missing_path = REPORT_DIR / f"missing_or_low_confidence_{STAMP}.csv"
    with missing_path.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows([r for r in out_rows if r["photo_status"] != "downloaded" or r["confidence"] not in ("high", "medium")])

    pdf_path = OUT / f"fishergo_icon_vs_realphoto_full_rebuild_{STAMP}.pdf"
    make_pdf(out_rows, pdf_path)

    downloaded = sum(1 for r in out_rows if r["photo_status"] == "downloaded")
    high = sum(1 for r in out_rows if r["confidence"] == "high")
    medium = sum(1 for r in out_rows if r["confidence"] == "medium")
    report = OUT / f"full_rebuild_report_{STAMP}.txt"
    report.write_text(
        f"PDF={pdf_path}\nCSV={csv_path}\nMISSING_LOW_CONF={missing_path}\nTOTAL={len(out_rows)}\nDOWNLOADED={downloaded}\nHIGH_CONF={high}\nMEDIUM_CONF={medium}\nMISSING_OR_FAILED={len(out_rows)-downloaded}\n",
        encoding="utf-8",
    )
    print("=== DONE ===")
    print(report.read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
