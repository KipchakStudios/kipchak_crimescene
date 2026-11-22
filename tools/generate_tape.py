import argparse
import os
from PIL import Image, ImageDraw, ImageFont

WIDTH = 2048
HEIGHT = 128
BAR = 9

PRESETS = {
    'tape_police': 'POLICE LINE \u2013 DO NOT CROSS',
    'tape_crime_scene': 'CRIME SCENE \u2013 DO NOT CROSS',
    'tape_polis_tr': 'POL\u0130S \u2013 G\u0130RMEY\u0130N\u0130Z',
}


def hex_color(value):
    value = value.lstrip('#')
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def load_font(path, size):
    if path and os.path.isfile(path):
        font = ImageFont.truetype(path, size)
        try:
            font.set_variation_by_axes([700])
        except Exception:
            pass
        return font
    return ImageFont.load_default(size)


def render(text, out_path, background, foreground, font_path):
    image = Image.new('RGBA', (WIDTH, HEIGHT), background + (255,))
    draw = ImageDraw.Draw(image)
    draw.rectangle([0, 0, WIDTH, BAR - 1], fill=foreground + (255,))
    draw.rectangle([0, HEIGHT - BAR, WIDTH, HEIGHT], fill=foreground + (255,))

    max_width = WIDTH - 160
    max_height = HEIGHT - BAR * 2 - 26
    size = 140
    while size > 10:
        font = load_font(font_path, size)
        left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
        if right - left <= max_width and bottom - top <= max_height:
            break
        size -= 2

    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    x = (WIDTH - (right - left)) / 2 - left
    y = (HEIGHT - (bottom - top)) / 2 - top
    draw.text((x, y), text, font=font, fill=foreground + (255,))

    gap = (WIDTH - (right - left)) / 2
    for cx in (gap / 2, WIDTH - gap / 2):
        r = 11
        cy = HEIGHT / 2
        draw.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=foreground + (255,))

    image.save(out_path)


def main():
    parser = argparse.ArgumentParser(description='Generate a police tape texture for kipchak_crimescene')
    parser.add_argument('--name', help='Output texture name without extension, e.g. tape_custom')
    parser.add_argument('--text', help='Text printed on the tape')
    parser.add_argument('--bg', default='FFCC00', help='Background color as hex')
    parser.add_argument('--fg', default='111111', help='Text and border color as hex')
    parser.add_argument('--font', default=r'C:\Windows\Fonts\CascadiaCode.ttf', help='Path to a TTF/OTF font')
    parser.add_argument('--out', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'textures'))
    args = parser.parse_args()

    os.makedirs(args.out, exist_ok=True)
    background = hex_color(args.bg)
    foreground = hex_color(args.fg)

    if args.name and args.text:
        jobs = {args.name: args.text}
    else:
        jobs = PRESETS

    for name, text in jobs.items():
        path = os.path.join(args.out, name + '.png')
        render(text, path, background, foreground, args.font)
        print(path)


if __name__ == '__main__':
    main()
