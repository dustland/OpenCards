#!/usr/bin/env python3
"""Empty recessed metal wells for card numbers. No center icons — the digit is the mark."""

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


def cover_edge(d: float, radius: float) -> float:
    return clamp((radius - d) / 1.25 + 0.5)


def shade_metal(face: tuple[float, float, float], nx: float, ny: float, well: float) -> tuple[float, float, float]:
    dark = mix(face, (0.05, 0.04, 0.03), 0.62)
    light = mix(face, (0.98, 0.93, 0.78), 0.38)
    lamp = clamp(0.46 + (-nx * 0.30 - ny * 0.56) * 0.62)
    rgb = mix(dark, light, lamp * (0.82 - well * 0.28))
    hl = clamp(1.0 - math.hypot(nx + 0.30, ny + 0.36) * 1.65)
    return mix(rgb, light, hl * 0.16 * (1.0 - well * 0.5))


def stamp_well(px: list[int], inside, face: tuple[float, float, float]) -> bytes:
    cx = cy = SRC * 0.5
    for y in range(SRC):
        for x in range(SRC):
            dist, normal, a = inside(x, y, cx, cy)
            if a <= 0:
                continue
            if dist > 0.86:
                rgb = shade_metal(mix(face, (0.06, 0.06, 0.065), 0.35), normal[0], normal[1], 0.0)
            elif dist > 0.72:
                rgb = mix((0.015, 0.016, 0.018), face, 0.25)
            else:
                well = clamp((0.72 - dist) / 0.72)
                rgb = shade_metal(mix((0.010, 0.011, 0.012), face, 0.15 + well * 0.12), normal[0], normal[1], well * 1.1)
            if dist > 0.78 and dist < 0.92:
                rgb = mix(rgb, (0.82, 0.84, 0.88), 0.35)
            put(px, x, y, rgb, a)
    return downsample(px)


def disc_inside(x: float, y: float, cx: float, cy: float):
    dx, dy = x - cx, y - cy
    r = SRC * 0.46
    d = math.hypot(dx, dy)
    a = cover_edge(d, r)
    nx, ny = (dx / r, dy / r) if r else (0.0, 0.0)
    return (d / r if r else 1.0, (nx, ny), a)


def main() -> None:
    root = Path("game_assets/ui")
    wells = {
        "badge_cost.png": ((0.78, 0.62, 0.30), disc_inside),
        "badge_operate.png": ((0.30, 0.48, 0.40), disc_inside),
        "badge_attack.png": ((0.62, 0.30, 0.22), disc_inside),
        "badge_defense.png": ((0.32, 0.44, 0.54), disc_inside),
    }
    for name, (face, inside) in wells.items():
        write_png(root / name, SIZE, SIZE, stamp_well([0] * (SRC * SRC * 4), inside, face))


if __name__ == "__main__":
    main()
