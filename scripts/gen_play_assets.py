#!/usr/bin/env python3
"""Generate Google Play store visual assets from the adaptive-icon source of truth.

Outputs (written to exports/play/):
- icon_512.png         512x512 app icon (full-bleed teal background, no alpha)
- feature_graphic.png  1024x500 marketing banner (no alpha)

The geometry mirrors android/app/src/main/res/drawable/ic_launcher_foreground.xml
exactly — viewport 108, outer ring radius 24, crosshairs 60% opacity, terracotta
dot at (69, 43) radius 3.2. If you change the XML, rerun this script.
"""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

TEAL = (46, 140, 128)        # #2E8C80
TEAL_DARK = (36, 110, 100)   # gradient bottom
TERRACOTTA = (204, 107, 74)  # #CC6B4A
WHITE = (255, 255, 255)
CROSSHAIR_ALPHA = 153        # 60% of 255

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "exports" / "play"
OUT.mkdir(parents=True, exist_ok=True)


def _draw_scope(draw: ImageDraw.ImageDraw, size: int, cx: float, cy: float):
    """Render the white scope ring + crosshairs + terracotta dot at the given
    center. Geometry is viewport-108 units scaled to `size`.
    """
    s = size / 108.0

    def at(*xs):
        return tuple(x * s for x in xs)

    # Outer white ring (radius 24, inner cutout radius 16)
    r_out, r_in = 24 * s, 16 * s
    draw.ellipse((cx - r_out, cy - r_out, cx + r_out, cy + r_out), fill=WHITE)
    draw.ellipse(
        (cx - r_in, cy - r_in, cx + r_in, cy + r_in),
        fill=None,
        outline=None,
    )

    # Use a temp alpha layer so we can knock out the inner ring without
    # painting over the background.
    return s


def render_icon(size: int = 512) -> Image.Image:
    """Render the adaptive icon at `size` × `size` with full-bleed teal background.

    Output is RGB (no alpha) per Play Store requirements.
    """
    img = Image.new("RGBA", (size, size), TEAL + (255,))
    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, "RGBA")

    s = size / 108.0
    cx, cy = 54 * s, 54 * s

    # White ring drawn by two-circle even-odd fill (outer 24, inner hole 16)
    r_out, r_in = 24 * s, 16 * s
    draw.ellipse((cx - r_out, cy - r_out, cx + r_out, cy + r_out), fill=WHITE + (255,))
    draw.ellipse((cx - r_in, cy - r_in, cx + r_in, cy + r_in), fill=(0, 0, 0, 0))

    # Crosshairs at 60% opacity
    cross = (255, 255, 255, CROSSHAIR_ALPHA)
    draw.rectangle((53.2 * s, 37 * s, 54.8 * s, 71 * s), fill=cross)
    draw.rectangle((37 * s, 53.2 * s, 71 * s, 54.8 * s), fill=cross)

    # Terracotta indicator dot at (69, 43), radius 3.2
    dr = 3.2 * s
    dx, dy = 69 * s, 43 * s
    draw.ellipse((dx - dr, dy - dr, dx + dr, dy + dr), fill=TERRACOTTA + (255,))

    # Composite, then flatten alpha against teal so the inner-ring hole shows teal.
    composed = Image.alpha_composite(img, overlay)
    return composed.convert("RGB")


def _load_font(candidates: list[str], size: int) -> ImageFont.FreeTypeFont:
    for path in candidates:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def render_feature_graphic() -> Image.Image:
    """1024x500 marketing banner — icon on left, wordmark + tagline on right."""
    w, h = 1024, 500

    # Vertical gradient from TEAL → TEAL_DARK for depth
    base = Image.new("RGB", (w, h), TEAL)
    grad = Image.new("L", (1, h))
    for y in range(h):
        # 0 at top → 255 at bottom
        grad.putpixel((0, y), int(255 * (y / (h - 1))))
    grad = grad.resize((w, h))
    overlay = Image.new("RGB", (w, h), TEAL_DARK)
    base = Image.composite(overlay, base, grad)

    # Left: icon at 320 px, vertically centered, padded 80 from left edge
    icon = render_icon(320)
    icon_x = 80
    icon_y = (h - 320) // 2
    base.paste(icon, (icon_x, icon_y))

    # Right: wordmark + tagline
    draw = ImageDraw.Draw(base)
    text_x = icon_x + 320 + 56
    text_w = w - text_x - 56

    title_font = _load_font(
        [
            "/System/Library/Fonts/Helvetica.ttc",
            "/System/Library/Fonts/HelveticaNeue.ttc",
        ],
        size=78,
    )
    tagline_font = _load_font(
        [
            "/System/Library/Fonts/Helvetica.ttc",
            "/System/Library/Fonts/HelveticaNeue.ttc",
        ],
        size=32,
    )

    title = "ClaudeScope"
    tagline_l1 = "Your Claude usage,"
    tagline_l2 = "without the guessing."

    title_bbox = draw.textbbox((0, 0), title, font=title_font)
    title_h = title_bbox[3] - title_bbox[1]
    tag_bbox = draw.textbbox((0, 0), tagline_l1, font=tagline_font)
    tag_h = tag_bbox[3] - tag_bbox[1]

    gap_after_title = 24
    gap_between_lines = 8
    block_h = title_h + gap_after_title + tag_h * 2 + gap_between_lines
    y0 = (h - block_h) // 2

    draw.text((text_x, y0), title, font=title_font, fill=WHITE)
    draw.text(
        (text_x, y0 + title_h + gap_after_title),
        tagline_l1,
        font=tagline_font,
        fill=(255, 255, 255, 220),
    )
    draw.text(
        (text_x, y0 + title_h + gap_after_title + tag_h + gap_between_lines),
        tagline_l2,
        font=tagline_font,
        fill=(255, 255, 255, 220),
    )

    # Subtle terracotta accent dot, mirroring the icon's indicator
    dot_r = 10
    dot_x = text_x + (title_bbox[2] - title_bbox[0]) + 18
    dot_y = y0 + title_h // 2 + 6
    draw.ellipse(
        (dot_x - dot_r, dot_y - dot_r, dot_x + dot_r, dot_y + dot_r),
        fill=TERRACOTTA,
    )

    return base


def main() -> None:
    icon = render_icon(512)
    icon_path = OUT / "icon_512.png"
    icon.save(icon_path, "PNG", optimize=True)
    print(f"wrote {icon_path} ({icon_path.stat().st_size // 1024} KB)")

    fg = render_feature_graphic()
    fg_path = OUT / "feature_graphic.png"
    fg.save(fg_path, "PNG", optimize=True)
    print(f"wrote {fg_path} ({fg_path.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
