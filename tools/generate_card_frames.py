#!/usr/bin/env python3
"""Generate premium collectible card frame assets for OpenCards.

Outputs (game_assets/ui/):
  card_frame.png       750x1050  ornate border + matte panels (transparent art window)
  card_frame_foil.png  750x1050  foil-stamp mask (white = hot-foil / holo areas)

Design goal: museum-grade TCG frame suitable as a print-master placeholder until
commissioned border art replaces the procedural filigree.
"""

from __future__ import annotations

import math
import os
import random
import struct
import zlib

SEED = 20260824
W, H = 750, 1050
TITLE_BOTTOM = 121
ART_TOP = 125
ART_BOTTOM = 533
TEXT_TOP = 548
TEXT_BOTTOM = 917
STATS_TOP = 927
INSET_X = 21
ROLE_STRIP_W = 17


def write_png(path: str, width: int, height: int, pixels: bytearray) -> None:
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * stride : (y + 1) * stride])

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as fh:
        fh.write(png)


def read_png_rgba(path: str) -> tuple[int, int, bytearray]:
    with open(path, "rb") as fh:
        if fh.read(8) != b"\x89PNG\r\n\x1a\n":
            raise ValueError("not png")
        width = height = 0
        color_type = 6
        idat = bytearray()
        while True:
            header = fh.read(8)
            if len(header) < 8:
                break
            length, tag = struct.unpack(">I4s", header)
            data = fh.read(length)
            fh.read(4)
            if tag == b"IHDR":
                width, height, _bit, color_type = struct.unpack(">IIBB", data[:10])
            elif tag == b"IDAT":
                idat.extend(data)
        bpp = 4 if color_type == 6 else 3 if color_type == 2 else 1
        stride = width * bpp
        dec = zlib.decompress(bytes(idat))
        raw_rows = bytearray()
        prev = bytearray(stride)
        i = 0
        for _row in range(height):
            filt = dec[i]
            i += 1
            row_bytes = bytearray(dec[i : i + stride])
            i += stride
            if filt == 1:
                for c in range(bpp, stride):
                    row_bytes[c] = (row_bytes[c] + row_bytes[c - bpp]) & 255
            elif filt == 2:
                for c in range(stride):
                    row_bytes[c] = (row_bytes[c] + prev[c]) & 255
            elif filt == 3:
                for c in range(stride):
                    left = row_bytes[c - bpp] if c >= bpp else 0
                    row_bytes[c] = (row_bytes[c] + ((left + prev[c]) >> 1)) & 255
            elif filt == 4:
                for c in range(stride):
                    a = row_bytes[c - bpp] if c >= bpp else 0
                    b = prev[c]
                    cpa = prev[c - bpp] if c >= bpp else 0
                    p = a + b - cpa
                    pa, pb, pc = abs(p - a), abs(p - b), abs(p - cpa)
                    pr = pa if pa <= pb and pa <= pc else (pb if pb <= pc else pc)
                    row_bytes[c] = (row_bytes[c] + pr) & 255
            prev = row_bytes
            if bpp == 4:
                raw_rows.extend(row_bytes)
            else:
                for px in range(width):
                    o = px * bpp
                    raw_rows.extend(row_bytes[o : o + 3])
                    raw_rows.append(255)
    return width, height, raw_rows


def clamp01(v: float) -> float:
    return 0.0 if v < 0.0 else (1.0 if v > 1.0 else v)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def mix(c1, c2, t: float):
    return (lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t))


def value_noise(seed: int, cols: int, rows: int):
    rng = random.Random(seed)
    lattice = [[rng.random() for _ in range(cols + 1)] for _ in range(rows + 1)]

    def sample(u: float, v: float) -> float:
        x = clamp01(u) * cols
        y = clamp01(v) * rows
        x0, y0 = int(x), int(y)
        x1, y1 = min(x0 + 1, cols), min(y0 + 1, rows)
        fx, fy = x - x0, y - y0
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        top = lerp(lattice[y0][x0], lattice[y0][x1], fx)
        bottom = lerp(lattice[y1][x0], lattice[y1][x1], fx)
        return lerp(top, bottom, fy)

    return sample


def rounded_rect_sdf(x: float, y: float, cx: float, cy: float, hw: float, hh: float, r: float) -> float:
    dx = abs(x - cx) - hw + r
    dy = abs(y - cy) - hh + r
    outside = math.hypot(max(dx, 0), max(dy, 0))
    inside = min(max(dx, dy), 0.0)
    return outside + inside - r


def metal_shade(base, nx: float, ny: float, hi, mid, lo):
    lamp = clamp01(0.52 + (-nx * 0.34 - ny * 0.58) * 0.55)
    col = mix(lo, hi, lamp)
    spec = clamp01(1.0 - math.hypot(nx + 0.25, ny + 0.32) * 1.8)
    col = mix(col, hi, spec * 0.22)
    return mix(base, col, 0.92)


def laurel_medallion(x: float, y: float, ox: float, oy: float, radius: float) -> float:
    dx, dy = x - ox, y - oy
    dist = math.hypot(dx, dy)
    if dist > radius + 6:
        return 0.0
    theta = math.atan2(dy, dx)
    leaves = 0.55 + 0.45 * abs(math.sin(theta * 7.0 + dist * 0.04))
    ring = abs(dist - (radius - 4))
    core = clamp01(1.0 - dist / (radius - 10)) if dist < radius - 10 else 0.0
    outer = clamp01(1.0 - ring / 3.5) if ring < 3.5 else 0.0
    return max(core * 0.55, outer * leaves)


def scroll_column(x: float, y: float, sx: float, y0: float, y1: float) -> float:
    if y < y0 or y > y1 or abs(x - sx) > 5:
        return 0.0
    t = (y - y0) / (y1 - y0)
    wave = math.sin(t * math.pi * 6.0) * 3.2
    return clamp01(1.0 - abs(x - sx - wave) / 1.8)


def art_layout():
    art_cx = W * 0.5
    art_cy = (ART_TOP + ART_BOTTOM) * 0.5
    art_hw = (W - INSET_X * 2 - ROLE_STRIP_W - 8) * 0.5
    art_hh = (ART_BOTTOM - ART_TOP) * 0.5 - 4
    return art_cx, art_cy, art_hw, art_hh


def gen_card_frame(path: str) -> None:
    grain = value_noise(SEED + 1, 28, 40)
    micro = value_noise(SEED + 3, 64, 90)
    px = bytearray(W * H * 4)

    brass_hi = (0.90, 0.78, 0.46)
    brass = (0.70, 0.58, 0.32)
    brass_lo = (0.34, 0.27, 0.14)
    matte_top = (0.10, 0.095, 0.082)
    matte_bot = (0.065, 0.060, 0.052)
    parchment = (0.13, 0.115, 0.09)
    ink = (0.18, 0.14, 0.10)

    art_cx, art_cy, art_hw, art_hh = art_layout()

    for y in range(H):
        v = y / (H - 1)
        for x in range(W):
            u = x / (W - 1)
            inset = min(x, y, W - 1 - x, H - 1 - y)
            base = mix(matte_top, matte_bot, v ** 0.88)
            n = grain(u, v)
            scratch = micro(u * 3.0, v * 3.0)
            base = (base[0] * (0.88 + 0.20 * n), base[1] * (0.88 + 0.20 * n), base[2] * (0.88 + 0.20 * n))

            # soft spotlight behind art (printed cards often have subtle field lift)
            sx = (x - art_cx) / (art_hw + 40)
            sy = (y - art_cy) / (art_hh + 60)
            spot = clamp01(1.0 - math.hypot(sx, sy * 0.9))
            base = mix(base, parchment, spot * 0.07)

            alpha = 1.0

            # outer rail: solid beveled brass (NO diagonal lattice)
            if inset <= 24:
                nx = (inset - 12) / 12.0 if inset <= 12 else (24 - inset) / 12.0
                ny = math.sin((x + y) * 0.03 + scratch * 6.0) * 0.15
                if inset <= 8:
                    col = metal_shade(base, nx, ny, brass_hi, brass, brass_lo)
                elif inset <= 12:
                    col = mix(brass_lo, ink, 0.72)
                elif inset <= 20:
                    col = metal_shade(base, nx + 0.2, ny, brass, brass_lo, ink)
                else:
                    col = mix(ink, brass_lo, 0.35)
                base = mix(base, col, 0.96)

            # inner pinstripe
            if 27 <= inset <= 29:
                base = mix(base, brass_hi, 0.78)

            # corner laurel medallions (larger, more "medal" than rosette)
            for ox, oy in ((46, 46), (W - 46, 46), (46, H - 46), (W - 46, H - 46)):
                m = laurel_medallion(x, y, ox, oy, 36.0)
                if m > 0.04:
                    col = mix(brass_lo, brass_hi, m)
                    base = mix(base, col, m * 0.94)

            # vertical scroll filigree beside art/text column
            for sx in (INSET_X + ROLE_STRIP_W + 12, W - INSET_X - 12):
                s = scroll_column(x, y, sx, ART_TOP - 8, TEXT_BOTTOM + 8)
                if s > 0.05:
                    base = mix(base, mix(brass_lo, brass_hi, s), s * 0.75)

            # role channel (inset colored strip in-engine; groove only here)
            if 26 <= x <= 26 + ROLE_STRIP_W and 40 <= y <= H - 40:
                groove = 0.5 + 0.5 * math.sin(y * 0.045)
                base = mix(base, mix(ink, brass_lo, groove), 0.62)

            # title cartouche rails
            if y <= TITLE_BOTTOM + 2 and INSET_X + ROLE_STRIP_W + 8 <= x <= W - INSET_X - 8:
                if abs(y - TITLE_BOTTOM) <= 2.5:
                    base = mix(base, brass_hi, 0.85)
                elif abs(y - 20) <= 2.0:
                    base = mix(base, brass, 0.72)
                elif abs(x - (INSET_X + ROLE_STRIP_W + 8)) <= 2 or abs(x - (W - INSET_X - 8)) <= 2:
                    if 24 <= y <= TITLE_BOTTOM - 8:
                        base = mix(base, brass_lo, 0.58)

            # rules panel rails
            if TEXT_TOP <= y <= TEXT_BOTTOM and INSET_X + ROLE_STRIP_W + 10 <= x <= W - INSET_X - 10:
                if abs(y - TEXT_TOP) <= 2 or abs(y - TEXT_BOTTOM) <= 2:
                    base = mix(base, brass, 0.68)
                if abs(x - (INSET_X + ROLE_STRIP_W + 10)) <= 1.5 or abs(x - (W - INSET_X - 10)) <= 1.5:
                    if (y - TEXT_TOP) % 48 < 6:
                        base = mix(base, brass_lo, 0.42)

            # stats shelf
            if STATS_TOP <= y <= H - 28 and INSET_X + 8 <= x <= W - INSET_X - 8:
                if abs(y - STATS_TOP) <= 2.5:
                    base = mix(base, brass_hi, 0.80)
                if y >= H - 30 and abs(y - (H - 28)) <= 2:
                    base = mix(base, brass_lo, 0.55)

            # stat medallion rings (bottom corners — numbers render in-engine)
            for mx in (INSET_X + 56, W - INSET_X - 56):
                my = H - 54
                d = math.hypot(x - mx, y - my)
                if 24 <= d <= 30:
                    base = mix(base, brass_hi, 0.82)
                elif 20 <= d < 24:
                    base = mix(base, brass_lo, 0.55)

            # art window: dark groove + gold lip + transparent center
            art_sdf = rounded_rect_sdf(x, y, art_cx, art_cy, art_hw, art_hh, 16.0)
            if art_sdf < -3.0:
                alpha = 0.0
            elif art_sdf < 0.0:
                groove = clamp01(1.0 + art_sdf / 3.0)
                base = mix(base, ink, groove * 0.85)
                alpha = 1.0
            elif art_sdf < 8.0:
                lip = clamp01(1.0 - art_sdf / 8.0)
                lip_col = mix(brass_lo, brass_hi, lip ** 0.8)
                base = mix(base, lip_col, lip * 0.96)
                alpha = max(0.0, 1.0 - lip * 0.15)

            o = (y * W + x) * 4
            px[o] = int(clamp01(base[0]) * 255)
            px[o + 1] = int(clamp01(base[1]) * 255)
            px[o + 2] = int(clamp01(base[2]) * 255)
            px[o + 3] = int(clamp01(alpha) * 255)

    write_png(path, W, H, px)


def gen_card_frame_foil(path: str) -> None:
    px = bytearray(W * H * 4)
    art_cx, art_cy, art_hw, art_hh = art_layout()

    for y in range(H):
        for x in range(W):
            a = 0.0
            inset = min(x, y, W - 1 - x, H - 1 - y)

            if inset <= 10 or (8 <= inset <= 12):
                a = max(a, 0.94)
            if 27 <= inset <= 29:
                a = max(a, 0.80)

            for ox, oy in ((46, 46), (W - 46, 46), (46, H - 46), (W - 46, H - 46)):
                a = max(a, laurel_medallion(x, y, ox, oy, 36.0) * 0.96)

            for sx in (INSET_X + ROLE_STRIP_W + 12, W - INSET_X - 12):
                a = max(a, scroll_column(x, y, sx, ART_TOP - 8, TEXT_BOTTOM + 8) * 0.70)

            if y <= TITLE_BOTTOM + 2 and INSET_X + ROLE_STRIP_W + 8 <= x <= W - INSET_X - 8:
                if abs(y - TITLE_BOTTOM) <= 2.5 or abs(y - 20) <= 2.0:
                    a = max(a, 0.88)

            art_sdf = rounded_rect_sdf(x, y, art_cx, art_cy, art_hw, art_hh, 16.0)
            if 0.0 <= art_sdf < 7.0:
                a = max(a, clamp01(1.0 - art_sdf / 7.0) * 0.90)

            if STATS_TOP <= y <= H - 28 and abs(y - STATS_TOP) <= 2.5:
                a = max(a, 0.75)

            gx, gy = W - INSET_X - 30, 38
            if math.hypot(x - gx, y - gy) <= 15:
                a = max(a, 0.95)

            for mx in (INSET_X + 56, W - INSET_X - 56):
                d = math.hypot(x - mx, y - (H - 54))
                if 22 <= d <= 31:
                    a = max(a, 0.78)

            o = (y * W + x) * 4
            v = int(a * 255)
            px[o] = v
            px[o + 1] = v
            px[o + 2] = v
            px[o + 3] = v if a > 0.02 else 0

    write_png(path, W, H, px)


def composite_print_proof(
    frame_path: str,
    art_path: str,
    out_path: str,
    title: str = "Rifle Platoon",
    deploy: str = "1",
    attack: str = "1",
    defense: str = "2",
) -> None:
    """Compose a 750×1050 print proof PNG (frame + art + placeholder text blocks)."""
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("skip print proof: Pillow not installed")
        return

    frame = Image.open(frame_path).convert("RGBA")
    art = Image.open(art_path).convert("RGBA")
    canvas = frame.copy()

    art_cx, art_cy, art_hw, art_hh = art_layout()
    ax0 = int(art_cx - art_hw)
    ay0 = int(art_cy - art_hh)
    box_w = int(art_hw * 2)
    box_h = int(art_hh * 2)
    fitted = art.resize((box_w, box_h), Image.Resampling.LANCZOS)
    canvas.paste(fitted, (ax0, ay0), fitted)

    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf", 28)
        small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf", 36)
    except OSError:
        font = ImageFont.load_default()
        small = font

    tw = draw.textlength(title.upper(), font=font)
    draw.text(((W - tw) / 2, 42), title.upper(), fill=(235, 220, 180, 255), font=font)
    draw.text((INSET_X + 38, H - 68), deploy, fill=(244, 234, 210, 255), font=small)
    draw.text((W - INSET_X - 98, H - 68), attack, fill=(244, 234, 210, 255), font=small)
    draw.text((W - INSET_X - 52, H - 68), defense, fill=(244, 234, 210, 255), font=small)
    draw.text((INSET_X + ROLE_STRIP_W + 24, TEXT_TOP + 16), "Infantry. Deploy: Ready.", fill=(190, 178, 150, 255), font=font)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    canvas.save(out_path, "PNG")


def main(out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    frame = os.path.join(out_dir, "card_frame.png")
    foil = os.path.join(out_dir, "card_frame_foil.png")
    gen_card_frame(frame)
    gen_card_frame_foil(foil)

    art = os.path.join(os.path.dirname(out_dir), "generated_cards", "us-rifle-platoon.png")
    proof = os.path.join(os.path.dirname(os.path.dirname(out_dir)), "builds", "qa", "print_proof_rifle_platoon.png")
    if os.path.isfile(art):
        composite_print_proof(frame, art, proof)


if __name__ == "__main__":
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game_assets", "ui")
    main(root)
    print("generated card frames in", os.path.abspath(root))
