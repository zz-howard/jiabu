#!/usr/bin/env python3
"""Deterministic synthetic receipts. Python 3 + Pillow==11.3.0 (HPND).

No real merchants, accounts, people, random input, EXIF or current dates.
Run from any directory. Only this script writes the three manifest JPEGs.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

EVAL = Path(__file__).resolve().parents[1]
REPO = EVAL.parents[1]
FONT_ROOT = REPO / "client/packages/jiabu_design/assets/fonts"
OUTPUTS = (EVAL / "tool/receipt_outputs.txt").read_text().splitlines()
EXPECTED = ["receipt_clear.jpg", "receipt_tilted.jpg", "receipt_long.jpg"]


def fonts(size):
    return [ImageFont.truetype(str(FONT_ROOT / name), size)
            for name in ("jiabu_hand.ttf", "jiabu_serif.otf")]


def covered(font, char):
    if char.isspace():
        return True
    mask = font.getmask(char)
    missing = font.getmask("\U0010ffff")
    return (mask.size, bytes(mask)) != (missing.size, bytes(missing))


def line(draw, xy, text, size=28):
    candidates = fonts(size)
    x, y = xy
    for char in text:
        # Both fonts are subsets without a space glyph; advance instead of drawing tofu.
        if char.isspace():
            x += size * 0.35
            continue
        font = next((f for f in candidates if covered(f, char)), None)
        if font is None:
            raise ValueError(f"Neither repository font covers U+{ord(char):04X}")
        draw.text((x, y), char, font=font, fill=(30, 30, 30))
        x += draw.textlength(char, font=font)


def receipt(merchant, items, total, tilt=False):
    # Long receipt has 16 item lines, plus header/date/total/footer.
    rows = [merchant, "合成收据 / Fictional receipt", "2026-10-20", "--------------------------"]
    rows += [f"{label}    {amount}" for label, amount in items]
    rows += ["--------------------------", f"合计 CNY {total}", "仅供测试 / TEST ONLY"]
    page = Image.new("RGB", (760, 80 + len(rows) * 46), (250, 248, 240))
    draw = ImageDraw.Draw(page)
    for index, row in enumerate(rows):
        line(draw, (45, 30 + index * 46), row)
    if tilt:
        page = page.rotate(7, Image.Resampling.BICUBIC, expand=True,
                           fillcolor=(220, 220, 220))
    return page


def main():
    if OUTPUTS != EXPECTED:
        raise ValueError("Receipt manifest and generator disagree")
    clear = receipt("虚构团团铺", [("早餐", "12.00"), ("饮品", "6.50")], "18.50")
    tilted = receipt("虚构果篮摊", [("蔬菜", "15.20"), ("水果", "17.50")], "32.70", tilt=True)
    # Sixteen separately priced items: 8.50 * 16 = 136.00.
    long = receipt("虚构果篮摊", [(f"蔬菜 {i:02d}", "8.50") for i in range(1, 17)], "136.00")
    (EVAL / "fixtures").mkdir(exist_ok=True)
    for name, page in zip(OUTPUTS, (clear, tilted, long), strict=True):
        page.save(EVAL / "fixtures" / name, format="JPEG", quality=94,
                  subsampling=0, optimize=False, progressive=False, exif=b"")
        print(name)


if __name__ == "__main__":
    main()
