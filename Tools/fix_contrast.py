#!/usr/bin/env python3
"""Theme.swift icindeki paletleri WCAG kontrast hedeflerine gore ayarlar.

Renklerin tonu korunur; yalnizca aciklik degeri hedefe ulasana kadar
siyaha veya beyaza dogru harmanlanir. Yeni tema eklendiginde tekrar calistir:

    python3 Tools/fix_contrast.py            # rapor + duzeltme
    python3 Tools/fix_contrast.py --check    # sadece rapor
"""

import re
import sys
from pathlib import Path

THEME_FILE = Path(__file__).resolve().parent.parent / "Sources/Shared/Theme.swift"

# Rol -> (karsilastirilacak zemin, hedef kontrast)
TARGETS = {
    "fg":     ("bg", 8.0),
    "muted":  ("bg", 4.6),
    "accent": ("bg", 4.6),
}
CODE_TARGET = 7.0  # cr(fg, codeBG)


def to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def to_hex(rgb):
    return "#" + "".join(f"{max(0, min(255, round(c))):02X}" for c in rgb)


def luminance(h):
    c = [x / 255 for x in to_rgb(h)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def contrast(a, b):
    l1, l2 = sorted([luminance(a), luminance(b)], reverse=True)
    return (l1 + 0.05) / (l2 + 0.05)


def blend(h, toward, t):
    r, g, b = to_rgb(h)
    tr, tg, tb = toward
    return to_hex((r + (tr - r) * t, g + (tg - g) * t, b + (tb - b) * t))


def adjust(color, bg, target):
    """Tonu koruyarak rengi hedef kontrasta tasir."""
    if contrast(color, bg) >= target:
        return color
    toward = (0, 0, 0) if luminance(bg) > 0.5 else (255, 255, 255)
    best = color
    t = 0.0
    while t <= 1.0:
        cand = blend(color, toward, t)
        best = cand
        if contrast(cand, bg) >= target:
            return cand
        t += 0.02
    return best


def main():
    check_only = "--check" in sys.argv
    src = THEME_FILE.read_text()

    pattern = re.compile(r"static let (\w+) = Theme\((.*?)\)\n", re.S)
    report, changes = [], 0
    new_src = src

    for match in pattern.finditer(src):
        block = match.group(2)
        fields = dict(re.findall(r'(\w+):\s*"(#[0-9a-fA-F]{6})"', block))
        name_match = re.search(r'name:\s*"([^"]+)"', block)
        if not name_match or "bg" not in fields:
            continue
        name = name_match.group(1)

        fixed = dict(fields)
        for role, (against, target) in TARGETS.items():
            if role in fixed:
                fixed[role] = adjust(fixed[role], fixed[against], target)

        # Kod blogu zemini: govde metni orada da okunur kalmali
        if "codeBG" in fixed and contrast(fixed["fg"], fixed["codeBG"]) < CODE_TARGET:
            toward = (255, 255, 255) if luminance(fixed["bg"]) > 0.5 else (0, 0, 0)
            t = 0.0
            while t <= 1.0 and contrast(fixed["fg"], fixed["codeBG"]) < CODE_TARGET:
                fixed["codeBG"] = blend(fields["codeBG"], toward, t)
                t += 0.02
        if "codeFG" in fixed and fields.get("codeFG") == fields.get("fg"):
            fixed["codeFG"] = fixed["fg"]

        diff = {k: (fields[k], v) for k, v in fixed.items() if v.upper() != fields[k].upper()}
        report.append((name, fields, fixed, diff))

        if diff and not check_only:
            new_block = block
            for key, (_old, new) in diff.items():
                new_block = re.sub(rf'({key}:\s*)"#[0-9a-fA-F]{{6}}"',
                                   rf'\g<1>"{new}"', new_block, count=1)
            new_src = new_src.replace(match.group(0),
                                      f"static let {match.group(1)} = Theme({new_block})\n")
            changes += 1

    if changes:
        THEME_FILE.write_text(new_src)

    print(f"{'tema':26}{'govde':>8}{'soluk':>8}{'accent':>8}{'kod':>8}   degisen")
    for name, old, new, diff in report:
        print(f"{name:26}"
              f"{contrast(new['fg'], new['bg']):8.2f}"
              f"{contrast(new['muted'], new['bg']):8.2f}"
              f"{contrast(new['accent'], new['bg']):8.2f}"
              f"{contrast(new['fg'], new['codeBG']):8.2f}"
              f"   {', '.join(diff) if diff else '-'}")
    print(f"\n{len(report)} tema · {changes} tanesi guncellendi")

    # --check modunda hicbir sey yazilmaz; esigin altinda tema varsa
    # cikis kodu 1 olur (CI bu sayede kirmiziya doner).
    if check_only:
        failing = [name for name, _o, _n, diff in report if diff]
        if failing:
            print(f"\nEsigin altinda {len(failing)} tema: {', '.join(failing)}")
            return 1
        print("Tum temalar kontrast hedeflerini karsiliyor.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
