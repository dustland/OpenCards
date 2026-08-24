#!/usr/bin/env python3
"""Generate OpenCards UI art assets deterministically (stdlib only).

Outputs to game_assets/ui/:
  battlefield_bg.png  1280x720  muted crop of boot_splash.png (not overwritten here)
  card_back.png       232x324   neutral card back (runtime nation tint)
  hq_us.png           256x256   US headquarters emblem plate
  hq_su.png           256x256   Soviet headquarters emblem plate
  badge_cost.png      64x64     brass coin (deployment cost)
  badge_attack.png    64x64     red steel roundel (attack)
  badge_defense.png   64x64     blue shield (defense)

Everything is seeded; rerunning produces identical bytes.
"""

import math
import os
import random
import struct
import zlib

SEED = 20260816
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game_assets", "ui")


# ---------------------------------------------------------------- PNG writer

def write_png(path: str, width: int, height: int, pixels: bytearray) -> None:
    """Encode an RGBA image (row-major, 4 bytes/px) as PNG."""
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)  # filter type 0 (None)
        raw.extend(pixels[y * stride:(y + 1) * stride])

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as fh:
        fh.write(png)


# ---------------------------------------------------------------- utilities

def clamp01(v: float) -> float:
    return 0.0 if v < 0.0 else (1.0 if v > 1.0 else v)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def mix(c1, c2, t: float):
    return (lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t))


def value_noise(seed: int, cols: int, rows: int):
    """Bilinear value-noise sampler on a (cols+1)x(rows+1) lattice."""
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


def fbm(seed: int, cols: int, rows: int, octaves: int = 2):
    layers = [(value_noise(seed + i * 977, cols >> i, rows >> i), 0.5 ** i) for i in range(octaves)]

    def sample(u: float, v: float) -> float:
        total = 0.0
        weight = 0.0
        for fn, w in layers:
            total += fn(u, v) * w
            weight += w
        return total / weight

    return sample


def star_radius(theta: float, points: int, inner_ratio: float) -> float:
    """Polar radius of a rounded star at angle theta (0..1 normalized)."""
    seg = 1.0 / points
    k = (theta % seg) / seg          # 0..1 within one point
    tri = 1.0 - abs(k * 2.0 - 1.0)   # triangle wave 0..1..0
    return inner_ratio + (1.0 - inner_ratio) * tri


def downsample(src: bytearray, size: int, factor: int) -> bytearray:
    """Box-downsample an RGBA image of size*factor by `factor`."""
    big = size * factor
    out = bytearray(size * size * 4)
    for y in range(size):
        row_base = y * size * 4
        for x in range(size):
            r = g = b = a = 0
            for dy in range(factor):
                base = ((y * factor + dy) * big + x * factor) * 4
                for dx in range(factor):
                    r += src[base]; g += src[base + 1]; b += src[base + 2]; a += src[base + 3]
                    base += 4
            n = factor * factor
            o = row_base + x * 4
            out[o] = r // n; out[o + 1] = g // n; out[o + 2] = b // n; out[o + 3] = a // n
    return out


# ---------------------------------------------------------- battlefield bg

def gen_battlefield_bg(path: str) -> None:
    """Stylized 'command table' battlefield: bright sky, hard skyline
    silhouette, textured two-tone field, visible ruts and craters.
    Rendered at 2x supersample for clean edges."""
    SS = 2
    W, H = 1280, 720
    N_W, N_H = W * SS, H * SS
    grain = fbm(SEED + 1, 26, 15, 3)
    patch = value_noise(SEED + 4, 5, 3)
    clouds = value_noise(SEED + 5, 7, 3)
    tree_top = value_noise(SEED + 6, 90, 1)
    spikes = value_noise(SEED + 7, 22, 1)
    rng = random.Random(SEED + 3)
    px = bytearray(N_W * N_H * 4)

    sky_top = (0.235, 0.275, 0.315)
    sky_low = (0.42, 0.395, 0.325)
    cloud_col = (0.52, 0.53, 0.52)
    silhouette = (0.115, 0.135, 0.115)
    field_top_c = (0.30, 0.265, 0.19)
    field_bot_c = (0.16, 0.145, 0.105)
    grass = (0.29, 0.31, 0.20)

    horizon = 0.335
    craters = [(rng.random(), horizon + 0.06 + rng.random() * 0.5, rng.uniform(0.016, 0.042))
               for _ in range(12)]
    ruts = [(horizon + rng.uniform(0.05, 0.55), rng.uniform(0.8, 1.6), rng.random() * 6.28,
             rng.uniform(0.9, 1.0)) for _ in range(5)]

    # precompute skyline ridge height per source column
    ridge = []
    for i in range(N_W):
        u = i / (N_W - 1)
        r = 0.024 + 0.05 * tree_top(u, 0.3)
        s = spikes(u, 0.7)
        if s > 0.70:
            r += 0.075 * (s - 0.70) / 0.30
        ridge.append(r)

    for y in range(N_H):
        v = y / (N_H - 1)
        for x in range(N_W):
            u = x / (N_W - 1)
            if v < horizon:
                t = v / horizon
                base = mix(sky_top, sky_low, t ** 1.35)
                # flat cloud bands
                c = clouds(u * 1.6, t * 3.0)
                if c > 0.58:
                    base = mix(base, cloud_col, min(1.0, (c - 0.58) * 2.2) * 0.28)
                # skyline silhouette with hard base
                r = ridge[x]
                top = horizon - r
                if v >= top:
                    base = silhouette
                elif v >= top - 2.0 * SS / N_H:
                    base = mix(base, silhouette, 0.5)
            else:
                t = (v - horizon) / (1.0 - horizon)
                base = mix(field_top_c, field_bot_c, t ** 0.95)
                p = patch(u, v)
                if p > 0.46:
                    base = mix(base, grass, min(1.0, (p - 0.46) * 2.4) * 0.35)
                n = grain(u, v)
                base = (base[0] * (0.92 + 0.16 * n),
                        base[1] * (0.92 + 0.16 * n),
                        base[2] * (0.92 + 0.16 * n))
                # wheel ruts: paired tracks
                for c0, amp, phase, freq in ruts:
                    center = c0 + 0.018 * math.sin(u * 6.28 * freq * 0.6 + phase)
                    for side in (-0.011, 0.011):
                        d = abs(v - (center + side))
                        if d < 0.0045:
                            k = 1.0 - 0.24 * amp
                            base = (base[0] * k, base[1] * k * 0.97, base[2] * k * 0.95)
                        elif d < 0.008:
                            f = 1.0 - (d - 0.0045) / 0.0035
                            k = 1.0 - 0.13 * amp * f
                            base = (base[0] * k, base[1] * k * 0.98, base[2] * k * 0.96)
                # shell craters
                for cu, cv, cr in craters:
                    dx = u - cu
                    dy = (v - cv) * 0.8
                    d = math.hypot(dx, dy)
                    if d < cr:
                        base = mix(base, (0.105, 0.095, 0.07), 0.42 * (1.0 - d / cr))
                    elif d < cr * 1.3:
                        base = mix(base, (0.38, 0.34, 0.25), 0.14 * (1.0 - (d - cr) / (cr * 0.3)))
            # light vignette
            dxv, dyv = u - 0.5, (v - 0.5) * (W / H)
            vig = 1.0 - 0.09 * clamp01((dxv * dxv + dyv * dyv) * 2.4)
            r_ = clamp01(base[0] * vig)
            g_ = clamp01(base[1] * vig)
            b_ = clamp01(base[2] * vig)
            o = (y * N_W + x) * 4
            px[o] = int(r_ * 255); px[o + 1] = int(g_ * 255); px[o + 2] = int(b_ * 255); px[o + 3] = 255

    # manual 2x box downsample to W x H (downsample() only handles square images)
    out = bytearray(W * H * 4)
    for y in range(H):
        for x in range(W):
            r_ = g_ = b_ = 0
            for dy in range(SS):
                base_i = ((y * SS + dy) * N_W + x * SS) * 4
                for dx in range(SS):
                    r_ += px[base_i]; g_ += px[base_i + 1]; b_ += px[base_i + 2]
                    base_i += 4
            o = (y * W + x) * 4
            n = SS * SS
            out[o] = r_ // n; out[o + 1] = g_ // n; out[o + 2] = b_ // n; out[o + 3] = 255
    write_png(path, W, H, out)


# ------------------------------------------------------------------ card back

def gen_card_back(path: str) -> None:
    W, H = 232, 324
    px = bytearray(W * H * 4)
    base_top = (0.118, 0.138, 0.122)
    base_bottom = (0.082, 0.098, 0.088)
    brass = (0.64, 0.54, 0.31)
    brass_hi = (0.78, 0.68, 0.40)
    brass_dim = (0.30, 0.26, 0.16)
    noise = value_noise(SEED + 11, 10, 14)
    weave = value_noise(SEED + 12, 6, 8)

    cx, cy = W / 2, H / 2
    star_outer = 58.0
    star_inner = 0.40

    for y in range(H):
        v = y / (H - 1)
        for x in range(W):
            u = x / (W - 1)
            base = mix(base_top, base_bottom, v)
            n = noise(u, v)
            w = weave(u * 1.4, v * 1.2)
            base = (base[0] * (0.91 + 0.16 * n), base[1] * (0.91 + 0.16 * n), base[2] * (0.91 + 0.16 * n))
            # subtle herringbone weave in the inner field
            hb = abs((x + y) % 9 - 4.5) / 4.5
            if 14 < min(x, y, W - 1 - x, H - 1 - y) < 108:
                base = mix(base, brass_dim, (1.0 - hb) * 0.08 * (0.55 + 0.45 * w))

            # radial spotlight behind emblem
            dxs, dys = (x - cx) / (W * 0.42), (y - cy) / (H * 0.48)
            spot = clamp01(1.0 - math.hypot(dxs, dys))
            base = mix(base, (0.16, 0.15, 0.11), spot * 0.10)

            # diagonal lattice (45 deg, period 17px)
            d = (x + y) % 17
            if d <= 1 or (x - y) % 17 in (0, 1):
                base = mix(base, brass_dim, 0.48)

            inset = min(x, y, W - 1 - x, H - 1 - y)
            # outer brass rail with bevel
            if inset < 5:
                edge = 0.70 + 0.30 * math.sin((x + y) * 0.45)
                col = mix(brass_dim, brass_hi if inset < 2 else brass, edge)
                base = mix(base, col, 0.92)
            elif inset == 5:
                base = mix(base, (0.05, 0.04, 0.03), 0.55)
            elif 10 <= inset <= 11:
                base = mix(base, brass_dim, 0.72)
            elif 14 <= inset <= 15:
                base = mix(base, brass, 0.55)

            # center star emblem with inner ring
            dx, dy = x - cx, y - cy
            dist = math.hypot(dx, dy)
            theta = (math.atan2(dy, dx) / (2 * math.pi) + 1.0) % 1.0
            sr = star_radius(theta, 5, star_inner) * star_outer
            if dist <= sr * 0.42:
                base = mix(base, brass_dim, 0.35)
            if dist <= sr:
                base = mix(base, (0.17, 0.16, 0.12), 0.90)
            if abs(dist - sr) <= 1.5:
                base = mix(base, brass_hi, 0.96)
            if abs(dist - (star_outer + 14)) <= 1.1:
                base = mix(base, brass, 0.82)
            if abs(dist - (star_outer + 22)) <= 0.9:
                base = mix(base, brass_dim, 0.70)

            # corner rivets just inside inner border
            for rx, ry in ((20, 20), (W - 20, 20), (20, H - 20), (W - 20, H - 20)):
                rd = math.hypot(x - rx, y - ry)
                if rd <= 3.4:
                    base = mix(base, brass_hi, 0.92)
                elif rd <= 4.6:
                    base = mix(base, brass_dim, 0.55)

            # corner bracket flourishes
            for ox, oy, sx, sy in ((16, 16, 1, 1), (W - 17, 16, -1, 1), (16, H - 17, 1, -1), (W - 17, H - 17, -1, -1)):
                if abs(x - ox) <= 10 and abs(y - oy) <= 2 and (x - ox) * sx >= 0:
                    base = mix(base, brass, 0.75)
                if abs(y - oy) <= 10 and abs(x - ox) <= 2 and (y - oy) * sy >= 0:
                    base = mix(base, brass, 0.75)

            o = (y * W + x) * 4
            px[o] = int(clamp01(base[0]) * 255); px[o + 1] = int(clamp01(base[1]) * 255)
            px[o + 2] = int(clamp01(base[2]) * 255); px[o + 3] = 255

    write_png(path, W, H, px)


# ----------------------------------------------------------------- HQ plates

def gen_hq(path: str, rim: tuple, deep: tuple, star_fill: tuple) -> None:
    SS = 3
    SIZE = 256
    N = SIZE * SS
    px = bytearray(N * N * 4)
    cx = cy = N / 2
    r_outer = N * 0.5 - 4 * SS
    r_ring = N * 0.435
    r_inner_ring = N * 0.385
    star_outer = N * 0.215
    brass = (0.72, 0.60, 0.33)
    brass_dark = (0.45, 0.375, 0.20)
    noise = value_noise(SEED + 21, 6, 6)

    for y in range(N):
        v = y / (N - 1)
        for x in range(N):
            u = x / (N - 1)
            dx, dy = x - cx, y - cy
            dist = math.hypot(dx, dy)
            base = (0.0, 0.0, 0.0)
            alpha = 0.0
            if dist <= r_outer:
                alpha = 1.0
                t = clamp01(dist / r_outer)
                base = mix(rim, deep, t ** 0.8)
                # top-left sheen
                sheen = max(0.0, 1.0 - ((dx + dy) / (r_outer * 2.6)))
                base = mix(base, (min(1, rim[0] + 0.14), min(1, rim[1] + 0.14), min(1, rim[2] + 0.14)), sheen * 0.35)
                # weathering
                n = noise(u, v)
                base = (base[0] * (0.92 + 0.10 * n), base[1] * (0.92 + 0.10 * n), base[2] * (0.92 + 0.10 * n))
                # brass rings
                if abs(dist - r_ring) <= 3.5 * SS:
                    base = mix(base, brass_dark, 0.95)
                if abs(dist - r_inner_ring) <= 1.5 * SS:
                    base = mix(base, brass, 0.85)
                # bottom chevron fortification stripes
                if dy > r_outer * 0.30 and dy < r_outer * 0.72:
                    stripe = ((dx + dy) % (26 * SS)) < (13 * SS)
                    if stripe and abs(dist - r_outer * 0.62) < r_outer * 0.28:
                        base = mix(base, deep, 0.5)
                # center star
                theta = (math.atan2(dy, dx) / (2 * math.pi) + 1.0) % 1.0
                sr = star_radius(theta, 5, 0.44) * star_outer
                if dist <= sr:
                    base = mix(base, star_fill, 0.92)
                if abs(dist - sr) <= 1.6 * SS:
                    base = mix(base, brass, 0.9)
            o = (y * N + x) * 4
            px[o] = int(clamp01(base[0]) * 255); px[o + 1] = int(clamp01(base[1]) * 255)
            px[o + 2] = int(clamp01(base[2]) * 255); px[o + 3] = int(255 * alpha)

    write_png(path, SIZE, SIZE, downsample(px, SIZE, SS))


# -------------------------------------------------------------------- badges

def gen_badge(path: str, top: tuple, bottom: tuple, shape: str) -> None:
    SS = 4
    SIZE = 64
    N = SIZE * SS
    px = bytearray(N * N * 4)
    cx = cy = N / 2
    r = N * 0.44
    outline = (0.10, 0.09, 0.07)

    def inside(x: float, y: float) -> float:
        """Return signed coverage in 0..1 for the badge silhouette."""
        dx, dy = x - cx, y - cy
        if shape == "shield":
            w = N * 0.40
            top_y = cy - N * 0.34
            if y < cy - N * 0.06:
                cov = 1.0 if abs(dx) <= w else 0.0
                # rounded shoulders
                corner = math.hypot(abs(dx) - (w - N * 0.08) if abs(dx) > w - N * 0.08 else 0,
                                    y - (top_y + N * 0.08) if y < top_y + N * 0.08 else 0)
                if corner > N * 0.08:
                    cov = 0.0
                return cov
            t = (y - (cy - N * 0.06)) / (N * 0.40)
            return 1.0 if abs(dx) <= w * (1.0 - t) else 0.0
        dist = math.hypot(dx, dy)
        return 1.0 if dist <= r else 0.0

    for y in range(N):
        for x in range(N):
            cov = inside(x, y)
            if cov <= 0.0:
                continue
            # vertical gradient + top-left sheen
            t = y / (N - 1)
            base = mix(top, bottom, t ** 1.1)
            sheen = max(0.0, 1.0 - ((x - cx) + (y - cy)) / (N * 1.15))
            base = mix(base, (min(1, top[0] + 0.18), min(1, top[1] + 0.18), min(1, top[2] + 0.18)), sheen * 0.4)
            # inner ring engraving
            dx, dy = x - cx, y - cy
            dist = math.hypot(dx, dy)
            if shape != "shield":
                ring_r = r * 0.66
                if abs(dist - ring_r) <= 1.6 * SS:
                    base = mix(base, (base[0] * 0.55, base[1] * 0.55, base[2] * 0.55), 0.8)
            # dark outline: pixels near the silhouette edge
            near_edge = inside(x + 2.0 * SS, y) <= 0 or inside(x - 2.0 * SS, y) <= 0 \
                or inside(x, y + 2.0 * SS) <= 0 or inside(x, y - 2.0 * SS) <= 0
            if near_edge:
                base = mix(base, outline, 0.85)
            o = (y * N + x) * 4
            px[o] = int(clamp01(base[0]) * 255); px[o + 1] = int(clamp01(base[1]) * 255)
            px[o + 2] = int(clamp01(base[2]) * 255); px[o + 3] = int(255 * cov)

    write_png(path, SIZE, SIZE, downsample(px, SIZE, SS))


# ----------------------------------------------------------------------- run

def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    # battlefield_bg.png is a darkened, desaturated crop of boot_splash.png so
    # the discarded splash can sit behind cards without competing with them.
    gen_card_back(os.path.join(OUT_DIR, "card_back.png"))
    gen_hq(os.path.join(OUT_DIR, "hq_us.png"),
           rim=(0.335, 0.40, 0.375), deep=(0.14, 0.19, 0.21), star_fill=(0.66, 0.62, 0.44))
    gen_hq(os.path.join(OUT_DIR, "hq_su.png"),
           rim=(0.47, 0.25, 0.19), deep=(0.185, 0.10, 0.085), star_fill=(0.78, 0.66, 0.36))
    # Card number wells come from tools/_make_badges.py (empty recessed metal).
    print("generated UI assets in", os.path.abspath(OUT_DIR))


if __name__ == "__main__":
    main()
