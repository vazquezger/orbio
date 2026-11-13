#!/usr/bin/env python3
"""Downloads missing 4:3 country flag SVGs (lipis/flag-icons) into assets/flags/.

Run from the repo root:
  python3 tool/fetch_flags.py
"""
import concurrent.futures
import json
import os
import urllib.request

CONTENT = "assets/data/world_sample.json"
FLAGS_DIR = "assets/flags"
BASE_URL = "https://cdn.jsdelivr.net/gh/lipis/flag-icons@7.2.3/flags/4x3"


def fetch_one(iso2: str) -> str:
    dest = os.path.join(FLAGS_DIR, f"{iso2}.svg")
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return "cached"
    url = f"{BASE_URL}/{iso2}.svg"
    req = urllib.request.Request(url, headers={"User-Agent": "orbio-flag-fetcher/1.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        svg = resp.read()
    with open(dest, "wb") as f:
        f.write(svg)
    return "downloaded"


def main():
    os.makedirs(FLAGS_DIR, exist_ok=True)
    countries = json.load(open(CONTENT))["countries"]
    codes = sorted({c["iso2"] for c in countries})
    downloaded = 0
    cached = 0
    failed = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
        futures = {pool.submit(fetch_one, code): code for code in codes}
        for fut in concurrent.futures.as_completed(futures):
            code = futures[fut]
            try:
                status = fut.result()
                if status == "downloaded":
                    downloaded += 1
                else:
                    cached += 1
            except Exception as e:
                failed.append((code, str(e)))
    print(f"Flags ready: {downloaded} downloaded, {cached} cached, {len(failed)} failed")
    if failed:
        print("Failed:", failed)


if __name__ == "__main__":
    main()

