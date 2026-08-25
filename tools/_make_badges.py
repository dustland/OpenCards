#!/usr/bin/env python3
"""Dark inset stamps in the Kards language: one family, four silhouettes."""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

SIZE = 64
SS = 4
SRC = SIZE * SS
FACE = (0.20, 0.21, 0.23)


def write_png(path: Path, w: int, h: int, px: bytes) -> None:
    raw = b""
    stride = w * 4
    for y in range(h):
        raw += b"\x00" + px[y * stride : (y + 1) * stride]

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def downsample(src: list[int]) -> bytes:
    out = bytearray(SIZE * SIZE * 4)
    for y in range(SIZE):
        for x in range(SIZE):
            r = g = b = a = 0
            for dy in range(SS):
                for dx in range(SS):
                    i = ((y * SS + dy) * SRC + (x * SS + dx)) * 4
                    r += src[i]
                    g += src[i + 1]
                    b += src[i + 2]
                    a += src[i + 3]
            n = SS * SS
            o = (y * SIZE + x) * 4
            out[o : o + 4] = bytes((r // n, g // n, b // n, a // n))
    return bytes(out)


def clamp(v: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return lo if v < lo else hi if v > hi else v


def mix(a: tuple[float, float, float], b: tuple[float, float, float], t: float) -> tuple[float, float, float]:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def put(px: list[int], x: int, y: int, rgb: tuple[float, float, float], a: float) -> None:
    if x < 0 or y < 0 or x >= SRC or y >= SRC or a <= 0:
        return
    i = (y * SRC + x) * 4
    src_a = a
    dst_a = px[i + 3] / 255.0
    out_a = src_a + dst_a * (1.0 - src_a)
    if out_a <= 0:
        return
    for c in range(3):
        dst = px[i + c] / 255.0
        src = rgb[c]
        px[i + c] = int(round(((src * src_a + dst * dst_a * (1.0 - src_a)) / out_a) * 255.0))
    px[i + 3] = int(round(out_a * 255.0))


def cover_edge(d: float) -> float:
    return clamp(-d / 1.4 + 0.5)


def shade_inset(x: float, y: float, cx: float, cy: float, dist: float) -> tuple[float, float, float]:
    dx = (x - cx) / SRC
    dy = (y - cy) / SRC
    light = clamp(0.58 - dx * 0.22 - dy * 0.30)
    lip = clamp((dist - 0.72) / 0.28)
    rgb = mix((0.14, 0.15, 0.16), FACE, light)
    rgb = mix(rgb, (0.30, 0.31, 0.33), (1.0 - lip) * 0.22)
    rgb = mix(rgb, (0.10, 0.10, 0.11), clamp((dist - 0.90) / 0.10) * 0.65)
    return (clamp(rgb[0]), clamp(rgb[1]), clamp(rgb[2]))


def sample(sdf_fn, x: float, y: float, cx: float, cy: float, char: float):
    sdf = sdf_fn(x - cx, y - cy)
    a = cover_edge(sdf)
    dist = clamp(1.0 + sdf / char)
    return dist, a


def sd_box_rounded(px: float, py: float, hx: float, hy: float, radius: float) -> float:
    ax, ay = abs(px) - hx, abs(py) - hy
    ox, oy = max(ax, 0.0), max(ay, 0.0)
    return math.hypot(ox, oy) + min(max(ax, ay), 0.0) - radius


def sd_polygon(px: float, py: float, verts: list[tuple[float, float]]) -> float:
    d = (px - verts[0][0]) ** 2 + (py - verts[0][1]) ** 2
    sign = 1.0
    count = len(verts)
    for i in range(count):
        ax, ay = verts[i]
        bx, by = verts[(i + 1) % count]
        ex, ey = px - ax, py - ay
        wx, wy = bx - ax, by - ay
        denom = wx * wx + wy * wy
        t = clamp((ex * wx + ey * wy) / denom) if denom else 0.0
        dx, dy = ex - wx * t, ey - wy * t
        d = min(d, dx * dx + dy * dy)
        c1 = py >= ay
        c2 = py < by
        c3 = (bx - ax) * ey > (by - ay) * ex
        if (c1 and c2 and c3) or ((not c1) and (not c2) and (not c3)):
            sign = -sign
    return sign * math.sqrt(d)


def sdf_square(px: float, py: float) -> float:
    return sd_box_rounded(px, py, SRC * 0.34, SRC * 0.34, SRC * 0.07)


def sdf_well(px: float, py: float) -> float:
    # Tombstone: flat sides, rounded crown.
    return sd_box_rounded(px, py + SRC * 0.02, SRC * 0.28, SRC * 0.34, SRC * 0.16)


def sdf_shield(px: float, py: float) -> float:
    s = SRC
    return (
        sd_polygon(
            px,
            py,
            [
                (-s * 0.24, -s * 0.26),
                (s * 0.24, -s * 0.26),
                (s * 0.24, s * 0.00),
                (0.0, s * 0.30),
                (-s * 0.24, s * 0.00),
            ],
        )
        - s * 0.08
    )


def stamp(sdf_fn) -> bytes:
    px = [0] * (SRC * SRC * 4)
    cx = cy = SRC * 0.5
    for y in range(SRC):
        for x in range(SRC):
            dist, a = sample(sdf_fn, x, y, cx, cy, SRC * 0.44)
            if a <= 0:
                continue
            put(px, x, y, shade_inset(x, y, cx, cy, dist), a)
    return downsample(px)


def main() -> None:
    root = Path("game_assets/ui")
    write_png(root / "badge_cost.png", SIZE, SIZE, stamp(sdf_square))
    write_png(root / "badge_operate.png", SIZE, SIZE, stamp(sdf_square))
    write_png(root / "badge_attack.png", SIZE, SIZE, stamp(sdf_well))
    write_png(root / "badge_defense.png", SIZE, SIZE, stamp(sdf_shield))


if __name__ == "__main__":
    main()
