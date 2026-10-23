#!/usr/bin/env python3
"""Compose iPhone Duo App Store cards from native outer- and inner-display captures.

The older families are rendered by render-app-store-screenshots.py, which stays untouched so
their provenance remains valid. This module reuses its capture reader, copy and background, and adds
the foldable's card layouts. One Duo placement group takes both displays: 01-04 are the outer
display (folded, portrait), 05-08 the inner display (open, landscape).

The open inner display cannot be read by XCTest (its images are black), so the runner captures
it from the host; those stills sit in the capture folder's `host` directory. The widget cards
reuse the outer run's real widget crops, which are the same 3x renders.
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

# Display sizes in pixels, as App Store Connect accepts them for iPhone Duo.
DISPLAYS = {
    'outer': {'size': (1398, 2034), 'family': 'duo-outer'},
    'inner': {'size': (2853, 2007), 'family': 'duo-inner'},
}
RUNTIME = '27-1'
DEVICE = 'iPhone-Duo'
SLUGS = ('mia', 'leo-celebration', 'mango-teddy', 'widgets')
HOST_NAMES = ('mia', 'leo-celebration', 'mango', 'teddy')
WIDGET_NAMES = ('widget-small', 'widget-medium', 'widget-large')
# Points per pixel is 3 on both displays; the faux Home Screen of the widget card is laid out in points.
WIDGET_POINTS = {'widget-small': (170, 170), 'widget-medium': (364, 170), 'widget-large': (364, 382)}

# Card layouts, in each display's own reference pixels (the display size), so cards stay exact at 1:1.
# A device is (native input, centre x, centre y, width, tilt in degrees); the frame's height follows
# the capture's aspect ratio. The portrait outer cards bleed off the bottom, with the cut kept above
# the avatar strip and bar (about 72% of the screen shows). The landscape inner cards show the whole device.
LAYOUTS = {
    'outer': {
        'text': {'left': 100, 'kicker': (118, 34), 'title': (185, 104, 14), 'body': (480, 40), 'body_widgets': 462, 'width': 1198},
        'cards': [
            [('mia', 699, None, 1240, -3)],
            [('leo-celebration', 699, None, 1240, 3)],
            [('teddy', 580, None, 1000, -6), ('mango', 800, None, 1000, 4)],
            [('widgets', 699, None, 1000, 0)],
        ],
        # The bleeding devices give a top edge instead of a centre.
        'tops': {'mia': 735, 'leo-celebration': 735, 'teddy': 640, 'mango': 1010, 'widgets': 545},
    },
    'inner': {
        'text': {'left': 140, 'kicker': (560, 38), 'title': (640, 112, 16), 'body': (940, 44), 'body_widgets': 940, 'width': 1100},
        'cards': [
            [('mia', 2027, 1003, 1460, -3)],
            [('leo-celebration', 2027, 1003, 1460, 3)],
            [('teddy', 1830, 700, 1150, -5), ('mango', 2180, 1180, 1150, 4)],
            [('widgets', 2027, 1003, 1460, 0)],
        ],
        'tops': {},
    },
}
# Faux Home Screen, in points: widget scale, the centre of the column left of the 84 pt status column,
# and each widget's left (None: centred) and top. Outer stacks the widgets; the wide inner display
# sets them side by side.
HOME_SCREEN = {
    'outer': {'scale': .8, 'center': 191, 'positions': ((None, 24), (None, 176), (None, 328))},
    'inner': {'scale': .85, 'center': 433.5, 'positions': ((24, 172), (193, 172), (532, 172))},
}


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
        top = text['body_widgets'] if index == 3 else body_top
        draw.multiline_text((left, canvas.sy(top)), '\n'.join(wrapped), font=body_font, fill='#b7cbd0', spacing=canvas.sy(12))


def device(canvas, image, screenshot, center_x, center_y, width, angle, top=None):
    """Draw a framed Duo screen: no notch or island, the native capture already holds the status column."""
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


def widget_screen(canvas, display, inputs):
    """A faux Home Screen holding the three real widget captures; the status column stays empty."""
    layout = HOME_SCREEN[display]
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


def compose_image(canvas, display, inputs, locale, index):
    layout = LAYOUTS[display]
    image = base.background(index)
    marketing_copy(canvas, image, locale, index, layout['text'])
    for name, center_x, center_y, width, angle in layout['cards'][index]:
        screen = widget_screen(canvas, display, inputs) if name == 'widgets' else inputs[name][0]
        device(canvas, image, screen, center_x, center_y, width, angle, layout['tops'].get(name))
    return image.convert('RGB')


def host_inputs(directory, locale, size):
    """The inner display's stills, taken by the host; a black or wrong-sized still is refused."""
    summary = json.loads((directory / locale / 'test-summary.json').read_text())
    if summary.get('passedTests', 0) < 1 or summary.get('failedTests', 0) != 0:
        raise ValueError(f'{locale}: capture did not pass')
    result = {}
    for name in HOST_NAMES:
        path = directory / locale / 'host' / f'store-{locale}-{name}.png'
        with Image.open(path) as image:
            if image.format != 'PNG' or image.size != size:
                raise ValueError(f'store-{locale}-{name}: invalid host PNG dimensions')
            if image.convert('L').getextrema()[1] < 40:
                raise ValueError(f'store-{locale}-{name}: the host still is black')
            result[name] = (image.convert('RGBA'), path)
    return result


def read_display(directory, display, widgets=None):
    """Validate one display's capture metadata and read its native inputs, per locale."""
    metadata = json.loads((directory / 'metadata.json').read_text())
    expected = DISPLAYS[display]
    if not re.fullmatch('[0-9a-f]{40}', metadata['head_sha']):
        raise ValueError('Capture metadata needs the full source head SHA')
    if (metadata['device'], metadata['family'], metadata['runtime']) != (DEVICE, expected['family'], RUNTIME):
        raise ValueError(f'{display}: use an independently captured native iPhone Duo / iOS 27.1 run')
    if (metadata['native_width'], metadata['native_height']) != expected['size']:
        raise ValueError(f'{display}: native capture dimensions do not match the display')
    if display == 'outer':
        # The base reader checks the 3x widget crops and the display-sized cards against these globals.
        base.SIZE, base.FAMILY = expected['size'], expected['family']
        return metadata, {store: base.native_inputs(directory, locale) for locale, store in (('en', 'en-US'), ('ru', 'ru'))}
    inputs = {}
    for locale, store in (('en', 'en-US'), ('ru', 'ru')):
        inputs[store] = host_inputs(directory, locale, expected['size']) | {name: widgets[store][name] for name in WIDGET_NAMES}
    return metadata, inputs


def retain(directory, inputs, destination, names):
    """Keep the native PNGs and passing summaries the cards were composed from."""
    destination.mkdir(parents=True)
    shutil.copy2(directory / 'metadata.json', destination / 'metadata.json')
    for locale, store in (('en', 'en-US'), ('ru', 'ru')):
        folder = destination / store
        folder.mkdir()
        shutil.copy2(directory / locale / 'test-summary.json', folder / 'test-summary.json')
        for name in names:
            shutil.copy2(inputs[store][name][1], folder / f'{name}.png')


def compose(outer, inner, output, retained=None):
    if output.exists() and any(output.iterdir()):
        raise ValueError('Output directory must be empty to avoid stale screenshots')
    output.mkdir(parents=True, exist_ok=True)
    receipt = {'renderer': 'scripts/render-duo-app-store-screenshots.py',
               'renderer_sha256': base.sha256(Path(__file__)),
               'base_renderer_sha256': base.sha256(Path(base.__file__)), 'displays': {}, 'outputs': {}}
    for store in ('en-US', 'ru'):
        (output / store).mkdir()
    number, outer_inputs = 0, None
    for display, directory in (('outer', outer), ('inner', inner)):
        metadata, inputs = read_display(directory, display, outer_inputs)
        outer_inputs = outer_inputs or inputs
        names = tuple(inputs['en-US']) if display == 'outer' else HOST_NAMES
        size = DISPLAYS[display]['size']
        canvas = Canvas(size)
        base.SIZE = size
        receipt['displays'][display] = {
            'capture': metadata, 'size': list(size),
            'inputs': {store: {name: base.sha256(found[name][1]) for name in names} for store, found in inputs.items()},
            'input_sizes': {store: {name: list(found[name][0].size) for name in names} for store, found in inputs.items()}}
        if display == 'inner':
            receipt['displays'][display]['widgets_from'] = 'outer'
        for index, slug in enumerate(SLUGS):
            for locale, store in (('en', 'en-US'), ('ru', 'ru')):
                path = output / store / f'{number + index + 1:02d}-{display}-{slug}.png'
                compose_image(canvas, display, inputs[store], locale, index).save(path, optimize=True)
                receipt['outputs'][f'{store}/{path.name}'] = base.sha256(path)
        if retained:
            retain(directory, inputs, retained / display, names)
        number += len(SLUGS)
    (output / 'source.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    print(f'Composed {len(receipt["outputs"])} native-backed iPhone Duo PNGs in {output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--outer', required=True, type=Path, help='Capture directory of the folded run')
    parser.add_argument('--inner', required=True, type=Path, help='Capture directory of the open run')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--retain', type=Path, help='Copy the native inputs here (marketing/app-store/native-captures/iphone-duo)')
    args = parser.parse_args()
    compose(args.outer.resolve(), args.inner.resolve(), args.output.resolve(), args.retain and args.retain.resolve())
