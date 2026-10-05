"""Builds the app's logo files and launcher icons from the Tabital mark.

Source: the mark in the main project (tabital_front/brand/source/mark.png, 1182x889, commit
6082925). It's the same artwork as tabitalpay.com's site icon and mark. Rerun this when the
founder supplies a vector or a larger mark:

    "../../tabital/.venv/Scripts/python.exe" tool/make_brand_icons.py

Needs Pillow (already in the Flask project's virtualenv). Writes:
  assets/brand/        mark.png (transparent), mark-256.png, icon-512.png (gold on navy)
  android/.../res/     mipmap-*/ic_launcher.png (legacy), mipmap-*/ic_launcher_foreground.png,
                       mipmap-anydpi-v26/ic_launcher.xml (adaptive), values/ic_launcher_colors.xml
  web/                 favicon.png, icons/Icon-*.png
"""
from pathlib import Path

from PIL import Image

APP = Path(__file__).resolve().parents[1]
SOURCE = APP.parents[1] / "tabital_front" / "brand" / "source" / "mark.png"
NAVY = (2, 22, 63, 255)  # #02163F, Tp.navy
RES = APP / "android" / "app" / "src" / "main" / "res"

# Launcher sizes per density: legacy icon (48 dp) and adaptive layer (108 dp)
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def mark() -> Image.Image:
    im = Image.open(SOURCE).convert("RGBA")
    return im.crop(im.getbbox())


def place(canvas: int, width_share: float, background=None) -> Image.Image:
    """The mark centred on a square canvas, its width a share of the canvas."""
    m = mark()
    w = round(canvas * width_share)
    h = round(m.height * w / m.width)
    m = m.resize((w, h), Image.LANCZOS)
    out = Image.new("RGBA", (canvas, canvas), background or (0, 0, 0, 0))
    out.alpha_composite(m, ((canvas - w) // 2, (canvas - h) // 2))
    return out


def save(im: Image.Image, path: Path, rgb=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    (im.convert("RGB") if rgb else im).save(path, optimize=True)
    print("wrote", path.relative_to(APP))


def main():
    brand = APP / "assets" / "brand"
    m = mark()
    # In-app mark, transparent, at most 1024 px wide (sharp at any size the app shows)
    big = m.resize((1024, round(m.height * 1024 / m.width)), Image.LANCZOS) if m.width > 1024 else m
    save(big, brand / "mark.png")
    save(place(256, 0.84), brand / "mark-256.png")
    save(place(512, 0.64, NAVY), brand / "icon-512.png", rgb=True)

    for name, k in DENSITIES.items():
        # Legacy launcher icon: gold mark on navy, the mark at 64% like the web app's icon-512
        save(place(round(48 * k), 0.64, NAVY), RES / f"mipmap-{name}" / "ic_launcher.png", rgb=True)
        # Adaptive foreground: 108 dp canvas; the mark stays inside the 66 dp safe circle
        # (width 56% of 108 dp = 60 dp wide, 45 dp tall: the diagonal is under 66 dp)
        save(place(round(108 * k), 0.56), RES / f"mipmap-{name}" / "ic_launcher_foreground.png")

    adaptive = RES / "mipmap-anydpi-v26" / "ic_launcher.xml"
    adaptive.parent.mkdir(parents=True, exist_ok=True)
    adaptive.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- Tabital launcher icon: navy background, gold mark (tool/make_brand_icons.py) -->\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n', encoding="utf-8")
    print("wrote", adaptive.relative_to(APP))
    colors = RES / "values" / "ic_launcher_colors.xml"
    colors.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#02163F</color>\n</resources>\n', encoding="utf-8")
    print("wrote", colors.relative_to(APP))

    web = APP / "web"
    save(place(32, 0.84), web / "favicon.png")
    save(place(192, 0.64, NAVY), web / "icons" / "Icon-192.png", rgb=True)
    save(place(512, 0.64, NAVY), web / "icons" / "Icon-512.png", rgb=True)
    # Maskable icons keep the mark inside the central 80% circle
    save(place(192, 0.52, NAVY), web / "icons" / "Icon-maskable-192.png", rgb=True)
    save(place(512, 0.52, NAVY), web / "icons" / "Icon-maskable-512.png", rgb=True)


if __name__ == "__main__":
    main()
