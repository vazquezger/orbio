#!/usr/bin/env python3
"""Generates the Orbio printable canvas.

Outputs:
  assets/maps/orbio_printable_canvas.svg  - 2:1 equirectangular world map (Natural Earth
                                            coastlines thick, country borders thin) with
                                            4 bullseye anchors (snapshot calibration)
                                            and ArUco markers in the oceans (Live view)
  assets/maps/canvas_markers.json         - marker ids and their corners in
                                            normalized map space [0,1]^2

Run from the repo root:  python3 tool/generate_canvas.py
Marker codes: tool/aruco_4x4_50.json (OpenCV DICT_4X4_50).
"""
import json

W, H, PAD = 800, 400, 20
X0, Y0, X1, Y1 = PAD, PAD, W - PAD, H - PAD   # anchor centres == normalized (0,0)..(1,1)

# ArUco marker geometry in SVG units (the 6-sheet poster prints 1 unit = 0.9 mm).
CELL = 2.5                    # one marker cell
BLEED = 0.06                  # white cells overlap slightly: no hairline seams in print
MARKER = 6 * CELL             # 4x4 bits + 1-cell black border = 6 cells (15 mm)
QUIET = CELL                  # white margin around each marker
FOOT = MARKER + 2 * QUIET     # footprint (20 mm)
CLEARANCE = 4                 # extra distance from any land outline
ANCHOR_CLEARANCE = 50         # keep away from bullseye anchors and their labels
SEAMS_X = [W / 3, 2 * W / 3]  # 3x2 A4 poster joins (also covers 2x2: W/2 checked too)
SEAMS_Y = [H / 2]
SEAM_CLEARANCE = 6


def proj(lon, lat):
    u = (lon + 180) / 360; v = (90 - lat) / 180
    return X0 + u * (X1 - X0), Y0 + v * (Y1 - Y0)


def to_normalized(x, y):
    return [round((x - X0) / (X1 - X0), 6), round((y - Y0) / (Y1 - Y0), 6)]


# ---- geography (Natural Earth 1:110m, public domain; see tool/natural_earth/) --

COAST_WIDTH = 1.2             # coastlines (~1.1 mm printed)
BORDER_WIDTH = 0.4            # land borders between countries (~0.36 mm printed)
NE_DIR = "tool/natural_earth"


def _load(name):
    return json.load(open(f"{NE_DIR}/{name}.geojson"))["features"]


def land_rings():
    """All land rings (exteriors and holes) as (lon, lat) lists."""
    rings = []
    for f in _load("ne_110m_land"):
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        for poly in polys:
            rings += [[(lo, la) for lo, la in ring] for ring in poly]
    return rings


def _artificial(a, b):
    """Edges that are not real coast: Antarctica's south edge and cuts at the antimeridian."""
    if a[1] <= -84.9 and b[1] <= -84.9:
        return True
    return abs(a[0]) >= 179.99 and abs(b[0]) >= 179.99 and (a[0] > 0) == (b[0] > 0)


def coast_polylines(rings):
    """Coastlines in SVG units, split where an edge is artificial."""
    lines = []
    for ring in rings:
        cur = []
        for a, b in zip(ring, ring[1:] + ring[:1]):
            if _artificial(a, b):
                if len(cur) > 1:
                    lines.append(cur)
                cur = []
                continue
            if not cur:
                cur = [proj(*a)]
            cur.append(proj(*b))
        if len(cur) > 1:
            lines.append(cur)
    return lines


def border_polylines():
    lines = []
    for f in _load("ne_110m_admin_0_boundary_lines_land"):
        g = f["geometry"]
        parts = g["coordinates"] if g["type"] == "MultiLineString" else [g["coordinates"]]
        lines += [[proj(lo, la) for lo, la in part] for part in parts]
    return lines


# Nothing may be drawn close to the bullseye anchors or their labels (canvas
# requirement R4); otherwise lines merge with the ring and detection fails.
ANCHOR_KEEPOUT = 28           # radius around each anchor centre (ring radius is 12)
LABEL_KEEPOUT = 5             # margin around each anchor label


def _keepouts():
    zones = []
    for ax, ay, lx, side in [(X0, Y0, X0 + 30, "start"), (X1, Y0, X1 - 30, "end"),
                             (X1, Y1, X1 - 30, "end"), (X0, Y1, X0 + 30, "start")]:
        zones.append(("circle", ax, ay, ANCHOR_KEEPOUT))
        x0 = lx if side == "start" else lx - 16
        zones.append(("rect", x0 - LABEL_KEEPOUT, ay - 6 - LABEL_KEEPOUT, x0 + 16 + LABEL_KEEPOUT, ay + 6 + LABEL_KEEPOUT))
    return zones


KEEPOUTS = _keepouts()


def _blocked(x, y):
    for z in KEEPOUTS:
        if z[0] == "circle" and (x - z[1]) ** 2 + (y - z[2]) ** 2 < z[3] ** 2:
            return True
        if z[0] == "rect" and z[1] <= x <= z[3] and z[2] <= y <= z[4]:
            return True
    return False


def _near_keepout(a, b):
    """Cheap bounding-box test: could segment a-b touch any keep-out zone?"""
    x0, x1 = min(a[0], b[0]), max(a[0], b[0])
    y0, y1 = min(a[1], b[1]), max(a[1], b[1])
    for z in KEEPOUTS:
        if z[0] == "circle":
            zx0, zy0, zx1, zy1 = z[1] - z[3], z[2] - z[3], z[1] + z[3], z[2] + z[3]
        else:
            zx0, zy0, zx1, zy1 = z[1:]
        if x1 >= zx0 and x0 <= zx1 and y1 >= zy0 and y0 <= zy1:
            return True
    return False


def clip_keepouts(lines, step=0.5):
    """Splits polylines wherever they enter a keep-out zone."""
    out = []
    for line in lines:
        cur = [] if _blocked(*line[0]) else [line[0]]
        for a, b in zip(line, line[1:]):
            if not _near_keepout(a, b):
                cur.append(b)
                continue
            n = max(1, int(((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5 / step))
            for k in range(1, n + 1):
                p = (a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n)
                if _blocked(*p):
                    if len(cur) > 1:
                        out.append(cur)
                    cur = []
                elif not cur or k == n:
                    cur.append(p)
        if len(cur) > 1:
            out.append(cur)
    return out


LAND_RINGS = land_rings()
LAND_XY = [[proj(lo, la) for lo, la in r] for r in LAND_RINGS]
COAST = clip_keepouts(coast_polylines(LAND_RINGS))
BORDERS = clip_keepouts(border_polylines())


def polyline_d(lines):
    return " ".join("M" + " L".join(f"{x:.2f},{y:.2f}" for x, y in line) for line in lines)


def anchor(tag, cx, cy, lx, ly, side):
    return f'''  <g id="anchor-{tag}" class="anchor">
    <circle cx="{cx}" cy="{cy}" r="12" fill="#000"/>
    <circle cx="{cx}" cy="{cy}" r="8" fill="#fff"/>
    <line x1="{cx-8}" y1="{cy}" x2="{cx+8}" y2="{cy}" stroke="#000" stroke-width="0.6"/>
    <line x1="{cx}" y1="{cy-8}" x2="{cx}" y2="{cy+8}" stroke="#000" stroke-width="0.6"/>
    <circle cx="{cx}" cy="{cy}" r="3.5" fill="#000"/>
    <text x="{lx}" y="{ly}" text-anchor="{side}" font-family="Helvetica, Arial, sans-serif" font-size="10" font-weight="bold" fill="#000">{tag}</text>
  </g>'''


# ---- marker placement -------------------------------------------------------

def _segments():
    for line in COAST:
        yield from zip(line, line[1:])


def _inside(px, py, poly):
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        (xi, yi), (xj, yj) = poly[i], poly[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def _seg_rect_dist_ok(a, b, rect):
    # Conservative: sample the segment densely and test distance to the rect.
    x0, y0, x1, y1 = rect
    steps = max(2, int(((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5))
    for k in range(steps + 1):
        t = k / steps
        x = a[0] + (b[0] - a[0]) * t; y = a[1] + (b[1] - a[1]) * t
        if x0 <= x <= x1 and y0 <= y <= y1:
            return False
    return True


def _free(cx, cy):
    h = FOOT / 2 + CLEARANCE
    rect = (cx - h, cy - h, cx + h, cy + h)
    if rect[0] < 0 or rect[1] < 0 or rect[2] > W or rect[3] > H:
        return False
    for ax, ay in [(X0, Y0), (X1, Y0), (X1, Y1), (X0, Y1)]:
        if abs(cx - ax) < ANCHOR_CLEARANCE + 30 and abs(cy - ay) < ANCHOR_CLEARANCE / 2 + 10:
            return False
    for sx in SEAMS_X + [W / 2]:
        if abs(cx - sx) < FOOT / 2 + SEAM_CLEARANCE:
            return False
    for sy in SEAMS_Y:
        if abs(cy - sy) < FOOT / 2 + SEAM_CLEARANCE:
            return False
    if sum(_inside(cx, cy, ring) for ring in LAND_XY) % 2 == 1:   # even-odd: holes count
        return False
    return all(_seg_rect_dist_ok(a, b, rect) for a, b in _segments())


def place_markers(max_markers):
    for step in range(36, 120, 2):
        spots = []
        y = Y0 + step / 2
        while y < Y1:
            x = X0 + step / 2
            while x < X1:
                if _free(x, y):
                    spots.append((x, y))
                x += step
            y += step
        if len(spots) <= max_markers:
            return step, spots
    raise SystemExit("could not fit markers")


def marker_svg(mid, code, cx, cy):
    x = cx - MARKER / 2; y = cy - MARKER / 2
    parts = [f'  <g id="marker-{mid}">',
             f'    <rect x="{cx - FOOT / 2:.2f}" y="{cy - FOOT / 2:.2f}" width="{FOOT}" height="{FOOT}" fill="#fff"/>',
             f'    <rect x="{x:.2f}" y="{y:.2f}" width="{MARKER}" height="{MARKER}" fill="#000"/>']
    for r in range(4):
        for c in range(4):
            if (code >> (15 - (r * 4 + c))) & 1:   # 1 = white cell
                parts.append(f'    <rect x="{x + (c + 1) * CELL - BLEED:.2f}" y="{y + (r + 1) * CELL - BLEED:.2f}" width="{CELL + 2 * BLEED:.2f}" height="{CELL + 2 * BLEED:.2f}" fill="#fff"/>')
    parts.append('  </g>')
    return "\n".join(parts)


def main():
    codes = json.load(open("tool/aruco_4x4_50.json"))["codes"]
    step, spots = place_markers(len(codes))
    markers = []
    svg_markers = []
    for mid, (cx, cy) in enumerate(spots):
        h = MARKER / 2
        corners = [(cx - h, cy - h), (cx + h, cy - h), (cx + h, cy + h), (cx - h, cy + h)]
        markers.append({"id": mid, "corners": [to_normalized(*p) for p in corners]})
        svg_markers.append(marker_svg(mid, codes[mid], cx, cy))

    out = ['<?xml version="1.0" encoding="UTF-8"?>',
           '<!-- Orbio printable world canvas (generated by tool/generate_canvas.py; do not edit).',
           f'     2:1 equirectangular. Anchor centres ({X0},{Y0}) ({X1},{Y0}) ({X1},{Y1}) ({X0},{Y1}) are the',
           '     normalized map corners (0,0) (1,0) (1,1) (0,1). ArUco DICT_4X4_50 markers in the oceans',
           '     are listed in assets/maps/canvas_markers.json. -->',
           f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" shape-rendering="crispEdges">',
           f'  <rect width="{W}" height="{H}" fill="#fff"/>',
           f'  <g id="coast" fill="none" stroke="#000" stroke-width="{COAST_WIDTH}" stroke-linejoin="round" stroke-linecap="round" shape-rendering="geometricPrecision">',
           f'    <path d="{polyline_d(COAST)}"/>',
           '  </g>',
           f'  <g id="borders" fill="none" stroke="#000" stroke-width="{BORDER_WIDTH}" stroke-linejoin="round" stroke-linecap="round" shape-rendering="geometricPrecision">',
           f'    <path d="{polyline_d(BORDERS)}"/>',
           '  </g>']
    out += ['  <g id="markers">'] + svg_markers + ['  </g>', '  <g id="anchors" shape-rendering="geometricPrecision">',
            anchor("TL", X0, Y0, X0 + 30, Y0 + 4, "start"),
            anchor("TR", X1, Y0, X1 - 30, Y0 + 4, "end"),
            anchor("BR", X1, Y1, X1 - 30, Y1 + 4, "end"),
            anchor("BL", X0, Y1, X0 + 30, Y1 + 4, "start"),
            '  </g>', '</svg>', '']
    open("assets/maps/orbio_printable_canvas.svg", "w").write("\n".join(out))
    json.dump({"dictionary": "DICT_4X4_50", "cells": 6,
               "note": "corners are the outer corners of each marker's black border, [TL, TR, BR, BL], in normalized map space",
               "markers": markers},
              open("assets/maps/canvas_markers.json", "w"), indent=1)
    print(f"grid step {step}: {len(markers)} markers")


if __name__ == "__main__":
    main()
