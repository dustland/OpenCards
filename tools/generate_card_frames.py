#!/usr/bin/env python3
"""Generate metal / acrylic engraved card frame assets for OpenCards.

AmEx Centurion-inspired: matte gunmetal base, laser-etched grooves with
top-left specular catch. Outputs:
  card_frame.png       750×1050 RGBA — engraved plate (transparent art window)
  card_frame_foil.png  750×1050 — glint mask (raised edge catch-light zones)

Physical mapping:
  Aluminum + laser engrave, or acrylic + CNC/UV print + white ink in grooves.
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
INSET_X = 24
ROLE_STRIP_W = 14
CORNER_R = 28.0


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
    dx = abs(x - cx) - hw + r
    dy = abs(y - cy) - hh + r
    outside = math.hypot(max(dx, 0), max(dy, 0))
    inside = min(max(dx, dy), 0.0)
    return outside + inside - r


def art_layout():
    art_cx = W * 0.5
    art_cy = (ART_TOP + ART_BOTTOM) * 0.5
    art_hw = (W - INSET_X * 2 - ROLE_STRIP_W - 10) * 0.5
    art_hh = (ART_BOTTOM - ART_TOP) * 0.5 - 6
    return art_cx, art_cy, art_hw, art_hh


# --- engraving helpers ---

MATTE = (0.042, 0.044, 0.048)
MATTE_HI = (0.055, 0.057, 0.062)
GROOVE = (0.014, 0.015, 0.017)
SPEC = (0.78, 0.81, 0.86)
SPEC_WARM = (0.84, 0.78, 0.68)


def brushed_base(x: int, y: int, u: float, v: float, grain_fn) -> tuple:
    n = grain_fn(u, v)
    streak = math.sin(y * 0.42 + n * 4.0) * 0.5 + 0.5
    base = mix(MATTE, MATTE_HI, streak * 0.12 + n * 0.08)
    return base


def groove_strength(dist: float, half_w: float = 2.2) -> float:
    if dist > half_w:
        return 0.0
    t = 1.0 - dist / half_w
    return t * t


def apply_groove(base, dist: float, lx: float = -0.7, ly: float = -0.7, half_w: float = 2.2):
    g = groove_strength(dist, half_w)
    if g <= 0.0:
        return base, 0.0
    out = mix(base, GROOVE, g * 0.92)
    # Specular on the "upper-left" lip of the trench (light from NW).
    edge = clamp01(1.0 - dist / 0.75) if dist < 0.75 else 0.0
    spec = edge * g * 0.85
    out = mix(out, SPEC, spec)
    return out, spec


def dist_to_hline(y: float, y0: float) -> float:
    return abs(y - y0)


def dist_to_vline(x: float, x0: float) -> float:
    return abs(x - x0)


def dist_to_rounded_border(x: float, y: float, inset_target: float) -> float:
    inset = min(x, y, W - 1 - x, H - 1 - y)
    return abs(inset - inset_target)


def gen_card_frame(path: str) -> None:
    grain = value_noise(SEED + 10, 32, 48)
    px = bytearray(W * H * 4)
    art_cx, art_cy, art_hw, art_hh = art_layout()

    for y in range(H):
        v = y / (H - 1)
        for x in range(W):
            u = x / (W - 1)
            base = brushed_base(x, y, u, v, grain)
            alpha = 1.0
            glint_hint = 0.0

            # Outer card edge bevel (rolled metal edge)
            inset = min(x, y, W - 1 - x, H - 1 - y)
            if inset < 6:
                bevel = inset / 6.0
                col = mix(GROOVE, SPEC if inset < 2 else MATTE_HI, bevel)
                base = mix(base, col, 0.94)
                if inset <= 2:
                    glint_hint = max(glint_hint, 0.9)

            # Double hairline border (credit-card register)
            for target in (18.0, 22.0):
                d = dist_to_rounded_border(x, y, target)
                base, spec = apply_groove(base, d, half_w=1.4)
                glint_hint = max(glint_hint, spec)

            # Inner frame line
            d = dist_to_rounded_border(x, y, 30.0)
            base, spec = apply_groove(base, d, half_w=1.2)
            glint_hint = max(glint_hint, spec)

            # Corner miter accents (Centurion-style subtle ticks)
            for ox, oy, sx, sy in ((34, 34, 1, 1), (W - 34, 34, -1, 1), (34, H - 34, 1, -1), (W - 34, H - 34, -1, -1)):
                if abs(x - ox) <= 14 and abs(y - oy) <= 1.8 and (x - ox) * sx >= 0:
                    base, spec = apply_groove(base, abs(y - oy), half_w=1.0)
                    glint_hint = max(glint_hint, spec)
                if abs(y - oy) <= 14 and abs(x - ox) <= 1.8 and (y - oy) * sy >= 0:
                    base, spec = apply_groove(base, abs(x - ox), half_w=1.0)
                    glint_hint = max(glint_hint, spec)

            # Role channel (vertical trench)
            if 32 <= x <= 32 + ROLE_STRIP_W and 38 <= y <= H - 38:
                d = min(x - 32, 32 + ROLE_STRIP_W - x)
                base, spec = apply_groove(base, d, half_w=2.0)
                glint_hint = max(glint_hint, spec * 0.6)

            # Title divider
            if INSET_X + ROLE_STRIP_W + 8 <= x <= W - INSET_X - 8:
                d = dist_to_hline(y, TITLE_BOTTOM)
                base, spec = apply_groove(base, d, half_w=1.8)
                glint_hint = max(glint_hint, spec)
                d2 = dist_to_hline(y, 22.0)
                base, spec = apply_groove(base, d2, half_w=1.2)
                glint_hint = max(glint_hint, spec * 0.7)

            # Text panel rails
            if TEXT_TOP <= y <= TEXT_BOTTOM and INSET_X + ROLE_STRIP_W + 12 <= x <= W - INSET_X - 12:
                for yy in (TEXT_TOP, TEXT_BOTTOM):
                    base, spec = apply_groove(base, dist_to_hline(y, yy), half_w=1.5)
                    glint_hint = max(glint_hint, spec)
                for xx in (INSET_X + ROLE_STRIP_W + 12, W - INSET_X - 12):
                    if abs(x - xx) <= 1.2 and (y - TEXT_TOP) % 64 < 5:
                        base, spec = apply_groove(base, abs(x - xx), half_w=1.0)
                        glint_hint = max(glint_hint, spec * 0.5)

            # Stats shelf
            if abs(y - STATS_TOP) <= 1.5 and INSET_X + 8 <= x <= W - INSET_X - 8:
                base, spec = apply_groove(base, abs(y - STATS_TOP), half_w=1.4)
                glint_hint = max(glint_hint, spec)

            # Stat well rings (laser-cut recess)
            for mx in (INSET_X + 58, W - INSET_X - 58):
                my = H - 56
                d = abs(math.hypot(x - mx, y - my) - 26)
                base, spec = apply_groove(base, d, half_w=2.0)
                glint_hint = max(glint_hint, spec * 0.85)

            # Art inset: deep channel + transparent center (photo window in metal)
            art_sdf = rounded_rect_sdf(x, y, art_cx, art_cy, art_hw, art_hh, 12.0)
            if art_sdf < -4.0:
                alpha = 0.0
            elif art_sdf < 0.0:
                depth = clamp01(1.0 + art_sdf / 4.0)
                base = mix(base, GROOVE, depth * 0.95)
                base = mix(base, (0.008, 0.009, 0.01), depth * 0.4)
            elif art_sdf < 10.0:
                lip = clamp01(1.0 - art_sdf / 10.0)
                base, spec = apply_groove(base, art_sdf, half_w=3.5)
                base = mix(base, mix(GROOVE, MATTE, 0.5), lip * 0.5)
                glint_hint = max(glint_hint, spec)
                alpha = max(0.0, 1.0 - lip * 0.12)

            o = (y * W + x) * 4
            px[o] = int(clamp01(base[0]) * 255)
            px[o + 1] = int(clamp01(base[1]) * 255)
            px[o + 2] = int(clamp01(base[2]) * 255)
            px[o + 3] = int(clamp01(alpha) * 255)

    write_png(path, W, H, px)


def gen_card_frame_foil(path: str) -> None:
    """Glint mask: bright only on engraved edge catches (maps to polish/secondary op on acrylic)."""
    px = bytearray(W * H * 4)
    art_cx, art_cy, art_hw, art_hh = art_layout()

    for y in range(H):
        for x in range(W):
            a = 0.0
            inset = min(x, y, W - 1 - x, H - 1 - y)

            if inset <= 2:
                a = max(a, 0.85)

            for target in (18.0, 22.0, 30.0):
                d = abs(min(x, y, W - 1 - x, H - 1 - y) - target)
                if d < 0.8:
                    a = max(a, clamp01(1.0 - d / 0.8) * 0.75)

            if 32 <= x <= 32 + ROLE_STRIP_W and 38 <= y <= H - 38:
                d = min(x - 32, 32 + ROLE_STRIP_W - x)
                if d < 0.9:
                    a = max(a, 0.55)

            if INSET_X + ROLE_STRIP_W + 8 <= x <= W - INSET_X - 8:
                for yy in (TITLE_BOTTOM, 22.0, TEXT_TOP, TEXT_BOTTOM, STATS_TOP):
                    d = abs(y - yy)
                    if d < 0.7:
                        a = max(a, clamp01(1.0 - d / 0.7) * 0.7)

            art_sdf = rounded_rect_sdf(x, y, art_cx, art_cy, art_hw, art_hh, 12.0)
            if 0.0 <= art_sdf < 2.5:
                a = max(a, clamp01(1.0 - art_sdf / 2.5) * 0.92)

            for mx in (INSET_X + 58, W - INSET_X - 58):
                d = abs(math.hypot(x - mx, y - (H - 56)) - 26)
                if d < 1.2:
                    a = max(a, clamp01(1.0 - d / 1.2) * 0.8)

            gx, gy = W - INSET_X - 32, 40
            if math.hypot(x - gx, y - gy) <= 12:
                a = max(a, 0.75)

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
    fitted = art.resize((int(art_hw * 2), int(art_hh * 2)), Image.Resampling.LANCZOS)
    canvas.paste(fitted, (ax0, ay0), fitted)

    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 26)
        small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 34)
        body = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 20)
    except OSError:
        font = ImageFont.load_default()
        small = font
        body = font

    silver = (198, 202, 210, 255)
    dim = (120, 124, 132, 255)
    tw = draw.textlength(title.upper(), font=font)
    # Engraved type: bright lip + dark offset (simulates etched letterform)
    draw.text(((W - tw) / 2 + 1, 44), title.upper(), fill=(20, 22, 26, 200), font=font)
    draw.text(((W - tw) / 2, 42), title.upper(), fill=silver, font=font)
    for label, px_x in ((deploy, INSET_X + 42), (attack, W - INSET_X - 102), (defense, W - INSET_X - 56)):
        draw.text((px_x + 1, H - 66), label, fill=(16, 18, 22, 180), font=small)
        draw.text((px_x, H - 67), label, fill=silver, font=small)
    draw.text((INSET_X + ROLE_STRIP_W + 28, TEXT_TOP + 18), "Infantry. Deploy: Ready.", fill=dim, font=body)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    canvas.save(out_path, "PNG")


def main(out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    frame = os.path.join(out_dir, "card_frame.png")
    foil = os.path.join(out_dir, "card_frame_foil.png")
    gen_card_frame(frame)
    gen_card_frame_foil(foil)

    art = os.path.join(os.path.dirname(out_dir), "generated_cards", "us-rifle-platoon.png")
    proof = os.path.join(os.path.dirname(os.path.dirname(out_dir)), "builds", "qa", "print_proof_metal_rifle.png")
    if os.path.isfile(art):
        composite_print_proof(frame, art, proof)


if __name__ == "__main__":
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game_assets", "ui")
    main(root)
    print("generated metal engraved frames in", os.path.abspath(root))
