#!/usr/bin/env python3
"""Search Wikimedia Commons for public-domain Ottoman/Turkish music and download tracks."""
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

UA = {"User-Agent": "OttomanTimelineGame/1.0 (educational Godot project; contact: local dev)"}
OUT_DIR = "assets/audio"
os.makedirs(OUT_DIR, exist_ok=True)

QUERIES = [
    "mehter",
    "ceddin deden",
    "Ottoman military band",
    "Tanburi Cemil Bey",
    "Ottoman classical music",
    "Turkish march",
    "Mahmudiye march",
    "Ertuğrul frigate march",
]

ACCEPT_MIME = {"audio/ogg", "application/ogg", "audio/mpeg", "audio/wav", "audio/x-wav", "audio/flac"}
ACCEPT_EXT = {".ogg", ".oga", ".mp3", ".wav", ".flac"}

def api(params):
    url = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)

def search_files(query, limit=15):
    data = api({
        "action": "query", "format": "json", "list": "search",
        "srsearch": query, "srnamespace": "6", "srlimit": str(limit),
    })
    return [hit["title"] for hit in data.get("query", {}).get("search", [])]

def file_info(titles):
    data = api({
        "action": "query", "format": "json", "formatversion": "2",
        "titles": "|".join(titles), "prop": "imageinfo",
        "iiprop": "url|size|mime",
    })
    out = []
    for p in data.get("query", {}).get("pages", []):
        ii = (p.get("imageinfo") or [{}])[0]
        out.append({"title": p.get("title"), "url": ii.get("url"),
                    "size": ii.get("size", 0), "mime": ii.get("mime", ""),
                    "desc_url": ii.get("descriptionurl", "")})
    return out

def download(url, out, attempts=5):
    for i in range(attempts):
        try:
            time.sleep(3)
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r, open(out, "wb") as f:
                f.write(r.read())
            return True
        except urllib.error.HTTPError as e:
            if e.code == 429:
                wait = 10 * (i + 1)
                print(f"  429, waiting {wait}s...")
                time.sleep(wait)
            else:
                raise
    return False

seen = set()
candidates = []
for q in QUERIES:
    try:
        titles = search_files(q)
        time.sleep(2)
        for info in file_info(titles):
            t = info["title"] or ""
            if t in seen:
                continue
            seen.add(t)
            mime = info["mime"]
            size = info["size"]
            ext = os.path.splitext(urllib.parse.urlparse(info["url"]).path)[1].lower()
            if (mime in ACCEPT_MIME or ext in ACCEPT_EXT) and 150_000 < size < 20_000_000:
                candidates.append(info)
    except Exception as e:
        print("query failed:", q, e)
    time.sleep(2)

print(f"{len(candidates)} audio candidates")
for c in candidates[:25]:
    print(f"  {c['size']//1000:>6} KB  {c['mime']:20}  {c['title']}")

wanted = int(sys.argv[1]) if len(sys.argv) > 1 else 3
credits = []
count = 0
for c in candidates:
    if count >= wanted:
        break
    raw = c["title"].replace("File:", "")
    base = re.sub(r"[^A-Za-z0-9_\-]+", "_", raw).strip("_")
    ext = os.path.splitext(urllib.parse.urlparse(c["url"]).path)[1].lower()
    if not ext:
        ext = ".ogg"
    name = base if base.lower().endswith((".ogg", ".mp3", ".wav", ".flac")) else base + ext
    out = os.path.join(OUT_DIR, name)
    if os.path.exists(out):
        count += 1
        continue
    if download(c["url"], out):
        credits.append(f"{name}\n  source: {c['desc_url']}\n  license: see source page (Wikimedia Commons)\n")
        print("DOWNLOADED", name, os.path.getsize(out))
        count += 1
    else:
        print("FAILED", name)

if credits:
    with open(os.path.join(OUT_DIR, "CREDITS.txt"), "a") as f:
        f.write("\n".join(credits))
print("tracks:", count)
