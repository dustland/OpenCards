#!/usr/bin/env python3
"""Generate premium collectible card frame assets for OpenCards.

Outputs (game_assets/ui/):
  card_frame.png       750x1050  ornate border + matte panels (transparent art window)
  card_frame_foil.png  750x1050  foil-stamp mask (white = hot-foil / holo areas)

Trim size matches standard poker/TCG: 63.5 x 88.9 mm at 300 DPI.
Godot scales these to catalog (180x252) at runtime.
"""

from __future__ import annotations

import math
import os
import random
import struct
import zlib

SEED = 20260824
W, H = 750, 1050
# Layout derived from catalog geometry scaled 750/180
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
    """Signed distance to rounded-rect exterior (negative = inside)."""
    dx = abs(x - cx) - hw + r
    dy = abs(y - cy) - hh + r
    outside = math.hypot(max(dx, 0), max(dy, 0))
    inside = min(max(dx, dy), 0.0)
    return outside + inside - r


def corner_rosette(x: float, y: float, ox: float, oy: float, scale: float) -> float:
    dx, dy = (x - ox) / scale, (y - oy) / scale
    dist = math.hypot(dx, dy)
    theta = (math.atan2(dy, dx) / (2 * math.pi) + 1.0) % 1.0
    petals = abs(math.sin(theta * 8.0)) * 0.55 + 0.45
    return clamp01(1.0 - (dist - 0.35 * petals) / 0.55)


def gen_card_frame(path: str) -> None:
    rng = random.Random(SEED)
    grain = value_noise(SEED + 1, 24, 34)
    linen = value_noise(SEED + 2, 12, 16)
    px = bytearray(W * H * 4)

    brass_hi = (0.86, 0.74, 0.42)
    brass = (0.68, 0.56, 0.30)
    brass_lo = (0.38, 0.30, 0.16)
    matte_top = (0.11, 0.10, 0.085)
    matte_bot = (0.07, 0.065, 0.055)
    parchment = (0.14, 0.12, 0.095)
    ink_line = (0.22, 0.18, 0.12)

    art_cx = W * 0.5
    art_cy = (ART_TOP + ART_BOTTOM) * 0.5
    art_hw = (W - INSET_X * 2 - ROLE_STRIP_W - 8) * 0.5
    art_hh = (ART_BOTTOM - ART_TOP) * 0.5 - 4

    for y in range(H):
        v = y / (H - 1)
        for x in range(W):
            u = x / (W - 1)
            inset = min(x, y, W - 1 - x, H - 1 - y)
            base = mix(matte_top, matte_bot, v ** 0.92)
            n = grain(u, v)
            ln = linen(u * 2.2, v * 2.2)
            base = (
                base[0] * (0.90 + 0.18 * n),
                base[1] * (0.90 + 0.18 * n),
                base[2] * (0.90 + 0.18 * n),
            )
            # linen crosshatch on matte panels
            hatch = abs(math.sin(x * 0.38 + ln * 2.0)) * abs(math.sin(y * 0.42 - ln * 1.6))
            if TEXT_TOP <= y <= TEXT_BOTTOM or y <= TITLE_BOTTOM:
                base = mix(base, parchment, hatch * 0.06)

            alpha = 1.0

            # --- outer rail (double bevel) ---
            if inset < 22:
                t = inset / 22.0
                edge = 0.55 + 0.45 * math.sin((x + y) * 0.08)
                col = mix(brass_lo, brass_hi if inset < 8 else brass, edge)
                if 8 <= inset <= 11:
                    col = mix(col, ink_line, 0.55)
                base = mix(base, col, 0.94)
            elif inset < 26:
                base = mix(base, ink_line, 0.65)

            # --- inner hairline ---
            if 28 <= inset <= 30:
                base = mix(base, brass, 0.82)

            # --- corner rosettes ---
            for ox, oy in ((38, 38), (W - 38, 38), (38, H - 38), (W - 38, H - 38)):
                rosette = corner_rosette(x, y, ox, oy, 34.0)
                if rosette > 0.05:
                    col = mix(brass_lo, brass_hi, rosette)
                    base = mix(base, col, rosette * 0.92)

            # --- left role channel ---
            if 24 <= x <= 24 + ROLE_STRIP_W and 34 <= y <= H - 34:
                groove = 0.5 + 0.5 * math.sin(y * 0.06)
                base = mix(base, mix(brass_lo, brass, groove), 0.55)

            # --- title cartouche (decorative edges only; text renders in-engine) ---
            if y <= TITLE_BOTTOM + 4 and INSET_X + ROLE_STRIP_W + 6 <= x <= W - INSET_X - 6:
                if abs(y - TITLE_BOTTOM) <= 2:
                    base = mix(base, brass, 0.82)
                elif abs(y - 18) <= 1.5:
                    base = mix(base, brass_hi, 0.78)
                elif x <= INSET_X + ROLE_STRIP_W + 14 or x >= W - INSET_X - 14:
                    if 22 <= y <= TITLE_BOTTOM - 6 and (y % 28) < 4:
                        base = mix(base, brass_lo, 0.55)

            # --- text panel (rules area borders only) ---
            if TEXT_TOP <= y <= TEXT_BOTTOM and INSET_X + ROLE_STRIP_W + 8 <= x <= W - INSET_X - 8:
                if abs(y - TEXT_TOP) <= 2 or abs(y - TEXT_BOTTOM) <= 2:
                    base = mix(base, brass_lo, 0.62)
                elif x <= INSET_X + ROLE_STRIP_W + 14 or x >= W - INSET_X - 14:
                    if abs((y - TEXT_TOP) % 56 - 28) <= 2:
                        base = mix(base, brass_lo, 0.35)

            # --- stats rail (bottom edge accent) ---
            if y >= STATS_TOP and abs(y - STATS_TOP) <= 2 and INSET_X <= x <= W - INSET_X:
                base = mix(base, brass, 0.75)

            # --- art window (transparent) ---
            art_sdf = rounded_rect_sdf(x, y, art_cx, art_cy, art_hw, art_hh, 14.0)
            if art_sdf < -2.0:
                alpha = 0.0
            elif art_sdf < 6.0:
                lip = clamp01(1.0 - (art_sdf + 2.0) / 8.0)
                lip_col = mix(brass_lo, brass_hi, lip)
                base = mix(base, lip_col, lip * 0.95)
                alpha = lip * 0.98

            # --- side filigree ticks ---
            if 32 <= y <= H - 32:
                for tick_x in (INSET_X + ROLE_STRIP_W + 10, W - INSET_X - 10):
                    if abs(x - tick_x) <= 1 and (y % 46) < 8:
                        base = mix(base, brass, 0.65)

            o = (y * W + x) * 4
            px[o] = int(clamp01(base[0]) * 255)
            px[o + 1] = int(clamp01(base[1]) * 255)
            px[o + 2] = int(clamp01(base[2]) * 255)
            px[o + 3] = int(clamp01(alpha) * 255)

    write_png(path, W, H, px)


def gen_card_frame_foil(path: str) -> None:
    px = bytearray(W * H * 4)
    art_cx = W * 0.5
    art_cy = (ART_TOP + ART_BOTTOM) * 0.5
    art_hw = (W - INSET_X * 2 - ROLE_STRIP_W - 8) * 0.5
    art_hh = (ART_BOTTOM - ART_TOP) * 0.5 - 4

    for y in range(H):
        for x in range(W):
            a = 0.0
            inset = min(x, y, W - 1 - x, H - 1 - y)

            # outer brass rail foil
            if inset < 10 or (8 <= inset <= 11):
                a = max(a, 0.92)

            # inner hairline
            if 28 <= inset <= 30:
                a = max(a, 0.75)

            # corner rosettes
            for ox, oy in ((38, 38), (W - 38, 38), (38, H - 38), (W - 38, H - 38)):
                rosette = corner_rosette(x, y, ox, oy, 34.0)
                a = max(a, rosette * 0.95)

            # title cartouche edges
            if y <= TITLE_BOTTOM + 4 and INSET_X + ROLE_STRIP_W + 6 <= x <= W - INSET_X - 6:
                if abs(y - TITLE_BOTTOM) <= 2 or abs(y - 18) <= 1.5:
                    a = max(a, 0.85)
                if x <= INSET_X + ROLE_STRIP_W + 14 or x >= W - INSET_X - 14:
                    if 22 <= y <= TITLE_BOTTOM - 6:
                        a = max(a, 0.55)

            # art window lip
            art_sdf = rounded_rect_sdf(x, y, art_cx, art_cy, art_hw, art_hh, 14.0)
            if -2.0 <= art_sdf < 4.0:
                a = max(a, clamp01(1.0 - (art_sdf + 2.0) / 6.0) * 0.88)

            # stats rail top edge
            if abs(y - STATS_TOP) <= 2 and INSET_X <= x <= W - INSET_X:
                a = max(a, 0.70)

            # rarity gem zone (top-right of title bar)
            gx, gy = W - INSET_X - 28, 36
            if math.hypot(x - gx, y - gy) <= 14:
                a = max(a, 0.90)

            # medallion wells (corners of stats row)
            for mx, my in ((INSET_X + 52, H - 52), (W - INSET_X - 52, H - 52)):
                d = math.hypot(x - mx, y - my)
                if 20 <= d <= 28:
                    a = max(a, 0.72)

            o = (y * W + x) * 4
            v = int(a * 255)
            px[o] = v
            px[o + 1] = v
            px[o + 2] = v
            px[o + 3] = v if a > 0.02 else 0

    write_png(path, W, H, px)


def main(out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    gen_card_frame(os.path.join(out_dir, "card_frame.png"))
    gen_card_frame_foil(os.path.join(out_dir, "card_frame_foil.png"))


if __name__ == "__main__":
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game_assets", "ui")
    main(root)
    print("generated card frames in", os.path.abspath(root))
