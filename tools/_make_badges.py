#!/usr/bin/env python3
"""Supersampled metal pips that match badge_cost: disc, rim, engraved icon."""

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


def cover_circle(d: float, radius: float) -> float:
    return clamp((radius - d) / 1.35 + 0.5)


def stamp_icon(px: list[int], kind: str, ink: tuple[float, float, float], highlight: tuple[float, float, float]) -> None:
    cx = cy = SRC * 0.5
    scale = SRC / 64.0

    def stamp(fn) -> None:
        for y in range(SRC):
            for x in range(SRC):
                cover = fn(((x - cx) / scale, (y - cy) / scale))
                if cover > 0:
                    put(px, x, y, ink, cover * 0.82)
                    put(px, x - 1, y - 1, highlight, cover * 0.22)

    if kind == "spear":

        def spear(p):
            x, y = p
            head = cover_circle(math.hypot(x, y + 4.0), 0.2)
            # upward triangle
            if -7.2 <= y <= 3.2 and abs(x) <= (3.2 - y) * 0.55:
                head = max(head, 1.0)
            shaft = 1.0 if abs(x) <= 1.15 and 2.4 <= y <= 10.6 else 0.0
            guard = 1.0 if abs(y - 2.6) <= 0.95 and abs(x) <= 4.6 else 0.0
            return clamp(max(head, shaft, guard))

        stamp(spear)
    elif kind == "chevrons":

        def chevrons(p):
            x, y = p
            cover = 0.0
            for mid in (-4.4, 2.2):
                yy = y - mid
                band = abs(yy - abs(x) * 0.72)
                if -6.2 <= x <= 6.2 and -3.2 <= yy <= 2.4 and band <= 1.45:
                    cover = 1.0
            return cover

        stamp(chevrons)


def metal_disc(face: tuple[float, float, float], icon: str | None) -> bytes:
    px = [0] * (SRC * SRC * 4)
    cx = cy = SRC * 0.5
    r_outer = SRC * 0.46
    r_rim = SRC * 0.395
    r_groove = SRC * 0.355
    r_face = SRC * 0.33
    dark = mix(face, (0.08, 0.06, 0.04), 0.55)
    light = mix(face, (1.0, 0.96, 0.82), 0.42)
    groove = mix(face, (0.04, 0.03, 0.02), 0.62)
    for y in range(SRC):
        for x in range(SRC):
            dx = x - cx
            dy = y - cy
            d = math.hypot(dx, dy)
            a = cover_circle(d, r_outer)
            if a <= 0:
                continue
            nx = dx / r_outer
            ny = dy / r_outer
            lamp = clamp(0.52 + (-nx * 0.32 - ny * 0.58) * 0.55)
            if d > r_rim:
                rgb = mix(dark, light, lamp * 0.85)
            elif d > r_groove:
                rgb = mix(groove, face, 1.0 - lamp)
            else:
                radial = clamp(1.0 - (d / r_face) * 0.22)
                rgb = mix(dark, light, lamp * radial)
                if d > r_face:
                    rgb = mix(rgb, groove, 0.35)
            # soft inner highlight on the upper-left face
            if d < r_face:
                hl = clamp(1.0 - math.hypot(nx + 0.28, ny + 0.34) * 1.7)
                rgb = mix(rgb, light, hl * 0.18)
            put(px, x, y, rgb, a)
    if icon:
        stamp_icon(px, icon, mix(face, (0.12, 0.08, 0.05), 0.62), mix(face, (1.0, 0.94, 0.78), 0.55))
    return downsample(px)


def main() -> None:
    root = Path("game_assets/ui")
    write_png(root / "badge_attack.png", SIZE, SIZE, metal_disc((0.72, 0.36, 0.26), "spear"))
    write_png(root / "badge_operate.png", SIZE, SIZE, metal_disc((0.28, 0.58, 0.54), "chevrons"))


if __name__ == "__main__":
    main()
