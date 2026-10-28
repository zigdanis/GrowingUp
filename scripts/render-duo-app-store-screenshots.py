#!/usr/bin/env python3
"""Compose iPhone Duo App Store cards from the outer display's native captures.

The older families are rendered by render-app-store-screenshots.py. This module reuses its capture
reader, copy and background, and adds the foldable's card layout: the folded Duo's outer display,
1398x2034, six cards per locale.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import shutil

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
_spec = importlib.util.spec_from_file_location('base_renderer', ROOT / 'scripts/render-app-store-screenshots.py')
base = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(base)

# Outer display size in pixels, as App Store Connect accepts it for iPhone Duo.
SIZE = (1398, 2034)
FAMILY = 'duo-outer'
DEVICE = 'iPhone-Duo'
WIDGET_NAMES = ('widget-small', 'widget-medium', 'widget-large')
# Points per pixel is 3; the faux Home Screen of the widget card is laid out in points.
WIDGET_POINTS = {'widget-small': (170, 170), 'widget-medium': (364, 170), 'widget-large': (364, 382)}

# Card layout in reference pixels (the display size), so cards stay exact at 1:1. A device is
# (native input, centre x, centre y, width, tilt in degrees); the frame's height follows the capture's
# aspect ratio. The person cards bleed off the bottom, with the cut kept above the birthday line (about
# 72% of the screen shows), so the devices give a top edge instead of a centre. The mosaic and the edit
# mode keep controls at the bottom edge, so their devices show the whole screen above FULL_BOTTOM.
TEXT = {'left': 100, 'kicker': (118, 34), 'title': (185, 104, 14), 'body': (480, 40), 'body_widgets': 462, 'width': 1198}
CARDS = [
    [('mosaic', 699, None, None, 0)],
    [('mia', 699, None, 1240, -3)],
    [('leo', 699, None, 1240, 3)],
    [('editor', 699, None, None, 0)],
    [('teddy', 580, None, 1000, -6), ('mango', 800, None, 1000, 4)],
    [('widgets', 699, None, 1000, 0)],
]
TOPS = {'mosaic': 580, 'mia': 735, 'leo': 735, 'editor': 580, 'teddy': 640, 'mango': 1010, 'widgets': 545}
FULL_BOTTOM = 1985
# Faux Home Screen, in points: widget scale, the centre of the column left of the 84 pt status column,
# and each widget's left (None: centred) and top.
HOME_SCREEN = {'scale': .8, 'center': 191, 'positions': ((None, 24), (None, 176), (None, 328))}


class Canvas:
    """Reference-pixel coordinates scaled to one display's pixel size."""

    def __init__(self, size, reference=None):
        self.size = size
        self.reference = reference or size

    def sx(self, value):
        return round(value * self.size[0] / self.reference[0])

    def sy(self, value):
        return round(value * self.size[1] / self.reference[1])

    def font(self, size, bold=False):
        name = 'DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf'
        return ImageFont.truetype(str(ROOT / 'marketing/fonts' / name), self.sx(size))


def marketing_copy(canvas, image, locale, index, text):
    draw = ImageDraw.Draw(image)
    left = canvas.sx(text['left'])
    draw.text((left, canvas.sy(text['kicker'][0])), 'GROWINGUP', font=canvas.font(text['kicker'][1], True), fill='#8ad9e4')
    title, subtitle = base.COPY[locale][index]
    title_top, title_size, spacing = text['title']
    title_font = canvas.font(title_size, True)
    for line in title.split('\n'):
        if draw.textlength(line, font=title_font) > canvas.sx(text['width']):
            raise ValueError(f'{locale}: headline exceeds the approved text area')
    draw.multiline_text((left, canvas.sy(title_top)), title, font=title_font, fill='white', spacing=canvas.sy(spacing))
    if subtitle:
        body_top, body_size = text['body']
        body_font = canvas.font(body_size)
        wrapped, line = [], ''
        for word in subtitle.split():
            candidate = f'{line} {word}'.strip()
            if line and draw.textlength(candidate, font=body_font) > canvas.sx(text['width']):
                wrapped.append(line)
                line = word
            else:
                line = candidate
        wrapped.append(line)
        top = text['body_widgets'] if index == base.WIDGETS else body_top
        draw.multiline_text((left, canvas.sy(top)), '\n'.join(wrapped), font=body_font, fill='#b7cbd0', spacing=canvas.sy(12))


def full_width(canvas, screenshot, top):
    """The frame width whose whole screen fits between `top` and FULL_BOTTOM; the border is 1.8% of it per side."""
    return round((FULL_BOTTOM - top) / (.964 * screenshot.height / screenshot.width + .036))


def device(canvas, image, screenshot, center_x, center_y, width, angle, top=None):
    """Draw a framed Duo screen: no notch or island, the native capture already holds the status column."""
    if width is None:
        width = full_width(canvas, screenshot, top)
    center_x, width = canvas.sx(center_x), canvas.sx(width)
    border = round(width * .018)
    inner_width = width - border * 2
    inner_height = round(inner_width * screenshot.height / screenshot.width)
    height = inner_height + border * 2
    center_y = canvas.sy(top) + height // 2 if top is not None else canvas.sy(center_y)
    frame = Image.new('RGBA', (width, height), '#080b0e')
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, width - 1, height - 1), radius=width * .06,
                                          fill='#080b0e', outline='#5b5d60', width=border)
    inner_size = (inner_width, inner_height)
    screen = screenshot.resize(inner_size, Image.Resampling.LANCZOS)
    screen.putalpha(base.rounded_mask(inner_size, inner_width * .05))
    frame.alpha_composite(screen, (border, border))
    frame.putalpha(base.rounded_mask(frame.size, width * .06))
    rotated = frame.rotate(-angle, resample=Image.Resampling.BICUBIC, expand=True)
    position = (round(center_x - rotated.width / 2), round(center_y - rotated.height / 2))
    # The blurred shadow gets its own padding, so its edge is never cut off at the frame's bounds.
    blur = canvas.sx(35)
    pad = blur * 3
    mask = Image.new('L', (rotated.width + pad * 2, rotated.height + pad * 2))
    mask.paste(rotated.getchannel('A'), (pad, pad))
    shadow = Image.new('RGBA', mask.size, '#020d11')
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(blur)).point(lambda a: a * .35))
    image.alpha_composite(shadow, (position[0] - pad, position[1] - pad + canvas.sy(30)))
    image.alpha_composite(rotated, position)


def widget_screen(canvas, inputs):
    """A faux Home Screen holding the three real widget captures; the status column stays empty."""
    layout = HOME_SCREEN
    width, height = canvas.size
    screen = Image.new('RGBA', canvas.size)
    draw = ImageDraw.Draw(screen)
    for y in range(height):
        color = tuple(round(a + (b - a) * y / height) for a, b in zip((169, 196, 177), (64, 89, 105)))
        draw.line((0, y, width, y), fill=color)
    for name, (left, top) in zip(WIDGET_NAMES, layout['positions']):
        card_width = round(WIDGET_POINTS[name][0] * 3 * layout['scale'])
        image = inputs[name][0]
        card = image.resize((card_width, round(image.height * card_width / image.width)), Image.Resampling.LANCZOS)
        card.putalpha(base.rounded_mask(card.size, 24 * 3 * layout['scale']))
        x = round(layout['center'] * 3 - card_width / 2) if left is None else round(left * 3)
        screen.alpha_composite(card, (x, round(top * 3)))
    return screen


def compose_image(canvas, inputs, locale, index):
    image = base.background(index)
    marketing_copy(canvas, image, locale, index, TEXT)
    for name, center_x, center_y, width, angle in CARDS[index]:
        if name == 'widgets':
            screen = widget_screen(canvas, inputs)
        elif name == 'leo':
            screen = base.leo(inputs)
        else:
            screen = inputs[name][0]
        device(canvas, image, screen, center_x, center_y, width, angle, TOPS.get(name))
    return image.convert('RGB')


def read_capture(directory, fireworks):
    """Validate the outer run's metadata and read its native inputs, per locale."""
    metadata = json.loads((directory / 'metadata.json').read_text())
    if not re.fullmatch('[0-9a-f]{40}', metadata['head_sha']):
        raise ValueError('Capture metadata needs the full source head SHA')
    if (metadata['device'], metadata['family']) != (DEVICE, FAMILY):
        raise ValueError('Use an independently captured native iPhone Duo outer-display run')
    if (metadata['native_width'], metadata['native_height']) != SIZE:
        raise ValueError('Native capture dimensions do not match the outer display')
    # The base reader checks the 3x widget crops and the display-sized cards against these globals.
    base.SIZE, base.FAMILY = SIZE, FAMILY
    return metadata, {store: base.native_inputs(directory, locale, fireworks[locale])
                      for locale, store in (('en', 'en-US'), ('ru', 'ru'))}


def retain(directory, inputs, destination):
    """Keep the native PNGs and passing summaries the cards were composed from."""
    destination.mkdir(parents=True)
    shutil.copy2(directory / 'metadata.json', destination / 'metadata.json')
    for locale, store in (('en', 'en-US'), ('ru', 'ru')):
        folder = destination / store
        folder.mkdir()
        shutil.copy2(directory / locale / 'test-summary.json', folder / 'test-summary.json')
        for name in inputs[store]:
            shutil.copy2(inputs[store][name][1], folder / f'{name}.png')


def compose(capture, output, retained=None, fireworks=None):
    if output.exists() and any(output.iterdir()):
        raise ValueError('Output directory must be empty to avoid stale screenshots')
    output.mkdir(parents=True, exist_ok=True)
    fireworks = fireworks or {'en': base.FIREWORKS, 'ru': base.FIREWORKS}
    metadata, inputs = read_capture(capture, fireworks)
    receipt = {'renderer': 'scripts/render-duo-app-store-screenshots.py',
               'renderer_sha256': base.sha256(Path(__file__)),
               'base_renderer_sha256': base.sha256(Path(base.__file__)), 'capture': metadata, 'size': list(SIZE),
               'fireworks': {store: base.fireworks_receipt(capture, locale, fireworks[locale])
                             for locale, store in (('en', 'en-US'), ('ru', 'ru'))},
               'inputs': {store: {name: base.sha256(found[name][1]) for name in found} for store, found in inputs.items()},
               'input_sizes': {store: {name: list(found[name][0].size) for name in found} for store, found in inputs.items()},
               'outputs': {}}
    canvas = Canvas(SIZE)
    for locale, store in (('en', 'en-US'), ('ru', 'ru')):
        (output / store).mkdir()
        for index, name in enumerate(base.FILES):
            path = output / store / name
            compose_image(canvas, inputs[store], locale, index).save(path, optimize=True)
            receipt['outputs'][f'{store}/{name}'] = base.sha256(path)
    if retained:
        retain(capture, inputs, retained)
    (output / 'source.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    print(f'Composed {len(receipt["outputs"])} native-backed iPhone Duo PNGs in {output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path, help='Capture directory of the folded run')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--retain', type=Path, help='Copy the native inputs here (marketing/app-store/native-captures/iphone-duo)')
    parser.add_argument('--fireworks', type=base.fireworks_choice, default=None,
                        help=f'Fireworks frame in ms after the swipe, e.g. 2100 or en=1900,ru=2100 (default {base.FIREWORKS})')
    args = parser.parse_args()
    compose(args.capture.resolve(), args.output.resolve(), args.retain and args.retain.resolve(), args.fireworks)
