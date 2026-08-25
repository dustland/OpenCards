#!/usr/bin/env python3
"""Ivory stencil marks: bullet (strike), shield (hold), cross (effect)."""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

SIZE = 64
SS = 4
SRC = SIZE * SS


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


def cover(d: float) -> float:
    return clamp(0.5 - d / 1.35)


def sdf_box(px: float, py: float, hx: float, hy: float) -> float:
    ax, ay = abs(px) - hx, abs(py) - hy
    return math.hypot(max(ax, 0.0), max(ay, 0.0)) + min(max(ax, ay), 0.0)


def sdf_circle(px: float, py: float, r: float) -> float:
    return math.hypot(px, py) - r


def sdf_triangle_up(px: float, py: float, half_w: float, half_h: float) -> float:
    return sd_polygon(
        px,
        py,
        [(-half_w, half_h), (half_w, half_h), (0.0, -half_h)],
    )


def stamp(inside) -> bytes:
    px = [0] * (SRC * SRC * 4)
    ivory = (0.96, 0.90, 0.76)
    ink = (0.06, 0.04, 0.03)
    for y in range(SRC):
        for x in range(SRC):
            d = inside(x + 0.5, y + 0.5)
            fill = cover(d)
            ring = cover(abs(d) - 1.15) * (1.0 if d > -2.4 else 0.0)
            a = max(fill, ring * 0.92)
            if a <= 0:
                continue
            t = clamp(fill)
            rgb = (
                ink[0] + (ivory[0] - ink[0]) * t,
                ink[1] + (ivory[1] - ink[1]) * t,
                ink[2] + (ivory[2] - ink[2]) * t,
            )
            i = (y * SRC + x) * 4
            px[i : i + 4] = [
                int(round(rgb[0] * 255)),
                int(round(rgb[1] * 255)),
                int(round(rgb[2] * 255)),
                int(round(a * 255)),
            ]
    return downsample(px)


def bullet(x: float, y: float) -> float:
    cx = cy = SRC * 0.5
    px, py = x - cx, y - cy
    s = SRC
    tip = sdf_triangle_up(px, py + s * 0.22, s * 0.11, s * 0.16)
    body = sdf_box(px, py + s * 0.04, s * 0.105, s * 0.22)
    groove = sdf_box(px, py + s * 0.14, s * 0.12, s * 0.03)
    primer = sdf_circle(px, py - s * 0.24, s * 0.07)
    return min(tip, body, groove, primer)


def sd_polygon(px: float, py: float, verts: list[tuple[float, float]]) -> float:
    d = (px - verts[0][0]) ** 2 + (py - verts[0][1]) ** 2
    s = 1.0
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
            s = -s
    return s * math.sqrt(d)


def shield(x: float, y: float) -> float:
    s = SRC
    return sd_polygon(
        x,
        y,
        [
            (s * 0.22, s * 0.16),
            (s * 0.78, s * 0.16),
            (s * 0.78, s * 0.48),
            (s * 0.50, s * 0.86),
            (s * 0.22, s * 0.48),
        ],
    )


def cross(x: float, y: float) -> float:
    cx = cy = SRC * 0.5
    px, py = x - cx, y - cy
    s = SRC
    arm = s * 0.11
    reach = s * 0.30
    return min(sdf_box(px, py, reach, arm), sdf_box(px, py, arm, reach))


def main() -> None:
    root = Path("game_assets/ui")
    write_png(root / "role_bullet.png", SIZE, SIZE, stamp(bullet))
    write_png(root / "role_shield.png", SIZE, SIZE, stamp(shield))
    write_png(root / "role_cross.png", SIZE, SIZE, stamp(cross))


if __name__ == "__main__":
    main()
