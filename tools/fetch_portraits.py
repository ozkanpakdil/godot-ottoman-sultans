#!/usr/bin/env python3
"""Download sultan portraits from Wikipedia (pageimages API) into assets/sultans/."""
import json
import os
import time
import urllib.parse
import urllib.request

UA = {"User-Agent": "OttomanTimelineGame/1.0 (educational Godot project; contact: local dev)"}

TITLES = {
    "osman_i": "Osman I",
    "orhan": "Orhan",
    "murad_i": "Murad I",
    "bayezid_i": "Bayezid I",
    "mehmed_i": "Mehmed I",
    "murad_ii": "Murad II",
    "mehmed_ii": "Mehmed II",
    "bayezid_ii": "Bayezid II",
    "selim_i": "Selim I",
    "suleiman_i": "Suleiman the Magnificent",
    "selim_ii": "Selim II",
    "murad_iii": "Murad III",
    "mehmed_iii": "Mehmed III",
    "ahmed_i": "Ahmed I",
    "mustafa_i": "Mustafa I",
    "osman_ii": "Osman II",
    "murad_iv": "Murad IV",
    "ibrahim": "Ibrahim of the Ottoman Empire",
    "mehmed_iv": "Mehmed IV",
    "suleiman_ii": "Suleiman II of the Ottoman Empire",
    "ahmed_ii": "Ahmed II",
    "mustafa_ii": "Mustafa II",
    "ahmed_iii": "Ahmed III",
    "mahmud_i": "Mahmud I",
    "osman_iii": "Osman III",
    "mustafa_iii": "Mustafa III",
    "abdulhamid_i": "Abdul Hamid I",
    "selim_iii": "Selim III",
    "mahmud_ii": "Mahmud II",
    "abdulmejid_i": "Abdulmejid I",
    "abdulaziz": "Abdulaziz",
    "murad_v": "Murad V",
    "abdulhamid_ii": "Abdul Hamid II",
    "mehmed_v": "Mehmed V",
    "mehmed_vi": "Mehmed VI",
}

OUT_DIR = "assets/sultans"
os.makedirs(OUT_DIR, exist_ok=True)

title_to_slug = {v: k for k, v in TITLES.items()}
api = "https://en.wikipedia.org/w/api.php?" + urllib.parse.urlencode({
    "action": "query",
    "format": "json",
    "formatversion": "2",
    "prop": "pageimages",
    "pithumbsize": "400",
    "titles": "|".join(TITLES.values()),
})

with urllib.request.urlopen(urllib.request.Request(api, headers=UA)) as r:
    data = json.load(r)

credits = []
missing = []

def have_file(slug):
    for ext in (".jpg", ".jpeg", ".png"):
        p = os.path.join(OUT_DIR, slug + ext)
        if os.path.exists(p) and os.path.getsize(p) > 1000:
            return p
    return None

def download(url, out, attempts=6):
    for i in range(attempts):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA)) as r, open(out, "wb") as f:
                f.write(r.read())
            return True
        except urllib.error.HTTPError as e:
            if e.code == 429:
                wait = 5 * (i + 1)
                print(f"  429, waiting {wait}s...")
                time.sleep(wait)
            else:
                raise
    return False

for page in data["query"]["pages"]:
    title = page.get("title", "")
    # Normalization may alter titles; match case-insensitively
    slug = None
    for t, s in title_to_slug.items():
        if t.lower() == title.lower():
            slug = s
            break
    if slug is None:
        print("UNMATCHED TITLE:", title)
        continue
    existing = have_file(slug)
    if existing:
        credits.append(f"{os.path.basename(existing)}  <-  (already downloaded)")
        print("SKIP", slug)
        continue
    thumb = page.get("thumbnail", {})
    url = thumb.get("source")
    if not url:
        missing.append((slug, title))
        continue
    ext = os.path.splitext(urllib.parse.urlparse(url).path)[1].lower()
    if ext not in (".jpg", ".jpeg", ".png"):
        ext = ".jpg"
    out = os.path.join(OUT_DIR, slug + ext)
    try:
        time.sleep(2)
        if download(url, out):
            credits.append(f"{slug}{ext}  <-  {url}")
            print("OK", slug, os.path.getsize(out))
        else:
            missing.append((slug, title))
            print("FAIL", slug, "gave up after retries")
    except Exception as e:
        missing.append((slug, title))
        print("FAIL", slug, e)

with open(os.path.join(OUT_DIR, "CREDITS.txt"), "w") as f:
    f.write("Sultan portraits downloaded from Wikipedia/Wikimedia Commons (public domain artworks).\n\n")
    f.write("\n".join(credits) + "\n")

print("---")
print("downloaded:", len(credits), "missing:", [m[0] for m in missing])
