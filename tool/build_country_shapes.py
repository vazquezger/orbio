#!/usr/bin/env python3
"""Fills each country's Areas in assets/data/world_sample.json from Natural Earth.

For every country in the content file (matched by ISO alpha-3 `code` against
Natural Earth's ADM0_A3) it writes:
  "areas":    list of rings, each a list of [lon, lat] (exteriors and holes;
              the app fills them even-odd)
  "centroid": Natural Earth's label point (where the name goes)
Everything else in the file is kept. Run from the repo root:
  python3 tool/build_country_shapes.py
"""
import json
import re

CONTENT = "assets/data/world_sample.json"
NE = "tool/natural_earth/ne_110m_admin_0_countries.geojson"


def main():
    shapes = {}
    for f in json.load(open(NE))["features"]:
        p, g = f["properties"], f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        rings = [[[round(lo, 3), round(la, 3)] for lo, la in ring] for poly in polys for ring in poly]
        shapes[p["ADM0_A3"]] = (rings, {"lat": round(p["LABEL_Y"], 4), "lon": round(p["LABEL_X"], 4)})

    data = json.load(open(CONTENT))
    for c in data["countries"]:
        rings, label = shapes[c["code"]]
        c.pop("outline", None)
        c["areas"] = rings
        c["centroid"] = label
    data["about"] = re.sub(r"'outline'[^.]*\.", "'areas' are Natural Earth 1:110m rings in GeoJSON [lon, lat] order (tool/build_country_shapes.py).", data["about"])

    text = json.dumps(data, ensure_ascii=False, indent=2)
    # Keep coordinate pairs on one line, and up to 6 pairs per line.
    text = re.sub(r"\[\s+(-?[\d.]+),\s+(-?[\d.]+)\s+\]", r"[\1, \2]", text)
    text = re.sub(r"(\[-?[\d.]+, -?[\d.]+\]),\s+(?=\[-?[\d.]+, -?[\d.]+\])", r"\1, ", text)
    open(CONTENT, "w").write(text + "\n")
    print({c["code"]: [len(r) for r in c["areas"]] for c in data["countries"]})


if __name__ == "__main__":
    main()
