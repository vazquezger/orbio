#!/usr/bin/env python3
"""Generates print-ready PDFs of the Orbio canvas (vector, exact scale).

Outputs (in print/):
  orbio_poster_6xA4.pdf   - 3x2 A4 landscape tiles, 72 x 36 cm assembled,
                            grey glue strips, cut marks and sheet labels
  orbio_poster_4xA4.pdf   - 2x2 A4 landscape tiles, 54 x 27 cm assembled,
                            grey glue strips, cut marks and sheet labels
  orbio_test_1xA4.pdf     - the whole canvas on one A4 page (desk tests only)

Run from the repo root after tool/generate_canvas.py:
  python3 tool/generate_poster.py
Print at 100 % ("actual size"), never "fit to page".
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_canvas as gc  # noqa: E402  (same geometry as the SVG)

MM = 72 / 25.4                       # PDF points per millimetre
A4_W, A4_H = 297.0, 210.0            # landscape, mm
MARGIN = 8.0                         # safe for most printers
OVERLAP = 10.0                       # glue strip, mm
COLS, ROWS = 3, 2
POSTER_SCALE = 0.9                   # mm per canvas unit → 72 x 36 cm


# ---- canvas primitives in canvas (SVG) units ---------------------------------

def load_markers():
    codes = json.load(open("tool/aruco_4x4_50.json"))["codes"]
    layout = json.load(open("assets/maps/canvas_markers.json"))["markers"]
    out = []
    for m in layout:
        (u0, v0), _, (u1, v1), _ = m["corners"]
        x0 = gc.X0 + u0 * (gc.X1 - gc.X0); y0 = gc.Y0 + v0 * (gc.Y1 - gc.Y0)
        x1 = gc.X0 + u1 * (gc.X1 - gc.X0); y1 = gc.Y0 + v1 * (gc.Y1 - gc.Y0)
        out.append((codes[m["id"]], x0, y0, x1 - x0))
    return out


def canvas_ops(markers):
    """PDF path operators drawing the canvas in canvas units (y down)."""
    ops = []

    def polyline(xy):
        return f"{xy[0][0]:.3f} {xy[0][1]:.3f} m " + " ".join(f"{x:.3f} {y:.3f} l" for x, y in xy[1:])

    def circle(cx, cy, r):
        k = 0.5523 * r
        return (f"{cx + r:.3f} {cy:.3f} m "
                f"{cx + r:.3f} {cy + k:.3f} {cx + k:.3f} {cy + r:.3f} {cx:.3f} {cy + r:.3f} c "
                f"{cx - k:.3f} {cy + r:.3f} {cx - r:.3f} {cy + k:.3f} {cx - r:.3f} {cy:.3f} c "
                f"{cx - r:.3f} {cy - k:.3f} {cx - k:.3f} {cy - r:.3f} {cx:.3f} {cy - r:.3f} c "
                f"{cx + k:.3f} {cy - r:.3f} {cx + r:.3f} {cy - k:.3f} {cx + r:.3f} {cy:.3f} c h")

    ops.append("1 J 1 j 0 G")
    ops.append(f"{gc.BORDER_WIDTH} w")
    ops += [polyline(line) + " S" for line in gc.BORDERS]
    ops.append(f"{gc.COAST_WIDTH} w")
    ops += [polyline(line) + " S" for line in gc.COAST]

    q = gc.QUIET
    for code, x, y, side in markers:
        ops.append(f"1 g {x - q:.3f} {y - q:.3f} {side + 2 * q:.3f} {side + 2 * q:.3f} re f")
        ops.append(f"0 g {x:.3f} {y:.3f} {side:.3f} {side:.3f} re f")
        cell = side / 6
        ops.append("1 g")
        for r in range(4):
            for c in range(4):
                if (code >> (15 - (r * 4 + c))) & 1:
                    b = gc.BLEED
                    ops.append(f"{x + (c + 1) * cell - b:.3f} {y + (r + 1) * cell - b:.3f} {cell + 2 * b:.3f} {cell + 2 * b:.3f} re f")

    for ax, ay in [(gc.X0, gc.Y0), (gc.X1, gc.Y0), (gc.X1, gc.Y1), (gc.X0, gc.Y1)]:
        ops.append("0 g " + circle(ax, ay, 12) + " f")
        ops.append("1 g " + circle(ax, ay, 8) + " f")
        ops.append(f"0 G 0.6 w {ax - 8} {ay} m {ax + 8} {ay} l S {ax} {ay - 8} m {ax} {ay + 8} l S")
        ops.append("0 g " + circle(ax, ay, 3.5) + " f")
    return ops


ANCHOR_LABELS = [("TL", gc.X0 + 30, gc.Y0 + 4, "start"), ("TR", gc.X1 - 30, gc.Y0 + 4, "end"),
                 ("BR", gc.X1 - 30, gc.Y1 + 4, "end"), ("BL", gc.X0 + 30, gc.Y1 + 4, "start")]


# ---- tiny PDF writer ---------------------------------------------------------

def pdf_text(s):
    b = s.encode("cp1252")
    return "(" + "".join(chr(c) if c not in (40, 41, 92) else "\\" + chr(c) for c in b) + ")"


def text_width_pt(s, size_pt):
    return 0.55 * size_pt * len(s)   # Helvetica average; good enough for alignment


class Pdf:
    def __init__(self):
        self.pages = []

    def add_page(self, content):
        self.pages.append(content)

    def write(self, path):
        objs = []
        objs.append("<< /Type /Catalog /Pages 2 0 R >>")
        kids = " ".join(f"{3 + 2 * i} 0 R" for i in range(len(self.pages)))
        objs.append(f"<< /Type /Pages /Kids [{kids}] /Count {len(self.pages)} >>")
        font_obj = 3 + 2 * len(self.pages)
        for i, content in enumerate(self.pages):
            objs.append(f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {A4_W * MM:.2f} {A4_H * MM:.2f}] "
                        f"/Resources << /Font << /F1 {font_obj} 0 R /F2 {font_obj + 1} 0 R >> >> /Contents {4 + 2 * i} 0 R >>")
            data = content.encode("cp1252")
            objs.append(f"<< /Length {len(data)} >>\nstream\n{content}\nendstream")
        objs.append("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
        objs.append("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>")

        out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
        offsets = []
        for n, body in enumerate(objs, start=1):
            offsets.append(len(out))
            out += f"{n} 0 obj\n{body}\nendobj\n".encode("cp1252")
        xref = len(out)
        out += f"xref\n0 {len(objs) + 1}\n0000000000 65535 f \n".encode()
        for off in offsets:
            out += f"{off:010d} 00000 n \n".encode()
        out += f"trailer\n<< /Size {len(objs) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
        with open(path, "wb") as f:
            f.write(out)


def page_content(ops, scale, src, dest, glue_rects=(), labels=(), marks=()):
    """src = (x0, y0, x1, y1) canvas units shown; dest = (left, top) mm on page."""
    sx0, sy0, sx1, sy1 = src
    left, top = dest
    w_mm = (sx1 - sx0) * scale; h_mm = (sy1 - sy0) * scale
    k = scale * MM
    # canvas → page: x_pt = (left + (x - sx0)*scale)*MM ; y_pt = (A4_H - top - (y - sy0)*scale)*MM
    e = left * MM - sx0 * k
    f = (A4_H - top) * MM + sy0 * k
    c = ["q", f"{left * MM:.3f} {(A4_H - top - h_mm) * MM:.3f} {w_mm * MM:.3f} {h_mm * MM:.3f} re W n"]
    for gx0, gy0, gx1, gy1 in glue_rects:   # canvas units, drawn under the map
        c.append(f"q {k:.6f} 0 0 {-k:.6f} {e:.3f} {f:.3f} cm 0.88 g {gx0:.3f} {gy0:.3f} {gx1 - gx0:.3f} {gy1 - gy0:.3f} re f Q")
    c.append(f"q {k:.6f} 0 0 {-k:.6f} {e:.3f} {f:.3f} cm")
    c += ops
    c.append("Q")
    for tag, tx, ty, side in ANCHOR_LABELS:
        size = 10 * scale * MM
        px = e + tx * k; py = f - ty * k
        if side == "end":
            px -= text_width_pt(tag, size)
        c.append(f"BT /F2 {size:.2f} Tf 0 g 1 0 0 1 {px:.2f} {py:.2f} Tm {pdf_text(tag)} Tj ET")
    c.append("Q")
    for x0, y0, x1, y1 in marks:            # page mm
        c.append(f"0 G 0.4 w {x0 * MM:.2f} {(A4_H - y0) * MM:.2f} m {x1 * MM:.2f} {(A4_H - y1) * MM:.2f} l S")
    for text, x, y, size, bold in labels:   # page mm, baseline
        font = "/F2" if bold else "/F1"
        c.append(f"BT {font} {size} Tf 0.25 g 1 0 0 1 {x * MM:.2f} {(A4_H - y) * MM:.2f} Tm {pdf_text(text)} Tj ET")
    return "\n".join(c)


# ---- outputs -----------------------------------------------------------------

def poster(ops, cols, rows, scale, out_path):
    pdf = Pdf()
    total = cols * rows
    tw, th = gc.W / cols, gc.H / rows          # canvas units per tile (before overlap)
    ov = OVERLAP / scale                        # overlap in canvas units
    names = [[f"{'AB'[r]}{c + 1}" for c in range(cols)] for r in range(rows)]
    for r in range(rows):
        for c in range(cols):
            x0, y0 = c * tw, r * th
            x1 = (c + 1) * tw + (ov if c < cols - 1 else 0)
            y1 = (r + 1) * th + (ov if r < rows - 1 else 0)
            glue = []
            if c < cols - 1:
                glue.append(((c + 1) * tw, y0, x1, y1))
            if r < rows - 1:
                glue.append((x0, (r + 1) * th, x1, y1))
            left, top = MARGIN, MARGIN
            w_mm = (x1 - x0) * scale; h_mm = (y1 - y0) * scale
            marks = []
            L = 5.0
            if c > 0:   # cut the left white margin along this edge
                marks += [(left, top - L - 1, left, top - 1), (left, top + h_mm + 1, left, top + h_mm + L + 1)]
            if r > 0:   # cut the top white margin along this edge
                marks += [(left - L - 1, top, left - 1, top), (left + w_mm + 1, top, left + w_mm + L + 1, top)]
            name = names[r][c]
            steps = []
            if c > 0:
                steps.append(f"recortá el borde izquierdo por las marcas y pegala sobre la franja gris de {names[r][c - 1]}")
            if r > 0:
                steps.append(f"recortá el borde superior y pegala sobre la franja gris de {names[r - 1][c]}")
            how = "; ".join(steps) if steps else "es la primera: no se recorta"
            grid = "   ".join(" ".join(f"[{n}]" if n == name else n for n in row) for row in names)
            labels = [
                (f"Orbio · Hoja {name} de {total} · {how}.", MARGIN + 3, A4_H - 7.7, 7, False),
                (f"Orden: {grid}   ·   Imprimir al 100 % (tamaño real), A4 horizontal.", MARGIN + 3, A4_H - 5.0, 6, False),
            ]
            pdf.add_page(page_content(ops, scale, (x0, y0, x1, y1), (left, top), glue, labels, marks))
    pdf.write(out_path)


def test_page(ops):
    pdf = Pdf()
    scale = min((A4_W - 2 * MARGIN) / gc.W, (A4_H - 2 * MARGIN - 6) / gc.H)
    w_mm = gc.W * scale
    left = (A4_W - w_mm) / 2
    labels = [(f"Orbio · Lienzo de prueba ({gc.W * scale / 10:.1f} × {gc.H * scale / 10:.1f} cm). "
               "Solo para probar en el escritorio: para usar, imprimí el póster de 4 o 6 hojas.", left, A4_H - 4, 7, False)]
    pdf.add_page(page_content(ops, scale, (0, 0, gc.W, gc.H), (left, MARGIN), labels=labels))
    pdf.write("print/orbio_test_1xA4.pdf")


def main():
    os.makedirs("print", exist_ok=True)
    ops = canvas_ops(load_markers())
    poster(ops, cols=3, rows=2, scale=POSTER_SCALE, out_path="print/orbio_poster_6xA4.pdf")
    poster(ops, cols=2, rows=2, scale=0.675, out_path="print/orbio_poster_4xA4.pdf")
    test_page(ops)
    for label, s in [("6xA4", POSTER_SCALE), ("4xA4", 0.675)]:
        a = (gc.X1 - gc.X0) * s; b = (gc.Y1 - gc.Y0) * s
        print(f"poster {label}: {gc.W * s / 10:.0f} x {gc.H * s / 10:.0f} cm; "
              f"anchor centres {a:.0f} x {b:.0f} mm, diagonal {math.hypot(a, b):.0f} mm")


if __name__ == "__main__":
    main()
