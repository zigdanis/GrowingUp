#!/usr/bin/env python3
"""Compose 13-inch iPad App Store cards from a native iPad Pro 13-inch capture.

The iPhone families are rendered by render-app-store-screenshots.py. This module reuses its copy, card order,
background and fireworks helpers, and adds the iPad's own card layout: the 2064x2752 portrait display, six cards per
locale, with iPad's extra large widget on the widget card.
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

# Portrait display size in pixels, as App Store Connect accepts it for 13-inch iPad.
SIZE = (2064, 2752)
FAMILY = 'ipad-13'
DEVICE = 'iPad-Pro-13-inch-M5'
SCALE = 2
# A full iPad shot takes about half a second, so the capture takes every other fireworks frame of the iPhone's list.
FIREWORKS_FRAMES = (1500, 1900, 2300)
FIREWORKS = 1900
# UITestWidgetPreview's sizes in points: a 6.3-inch iPhone's, and an 11-inch iPad's extra large one.
WIDGET_POINTS = {'widget-small': (170, 170), 'widget-medium': (364, 170), 'widget-large': (364, 382),
                 'widget-extraLarge': (715, 342)}
NAMES = ('mosaic', 'mia', 'editor', 'mango', 'teddy') + tuple(WIDGET_POINTS)
# The widget card shows four sizes on iPad; the other lines are the iPhone cards' own.
WIDGET_BODY = {'en': 'Four sizes for your family and pets.', 'ru': 'Четыре размера для семьи и питомцев.'}

# Card layout in display pixels. Text: left edge, kicker (top, size), title (top, size, line spacing), body (top, size)
# and the widest line. A device is (native input, centre x, width, tilt in degrees, top of the untilted frame); None
# for the width fits the whole device between its top and FULL_BOTTOM.
TEXT = {'left': 150, 'kicker': (170, 52), 'title': (262, 150, 24), 'body': (690, 60), 'width': 1764}
CARDS = [
    [('mosaic', 1032, None, 0, 840)],
    [('mia', 1032, 1340, -3, 860)],
    [('leo', 1032, 1340, 3, 860)],
    [('editor', 1032, None, 0, 840)],
    [('teddy', 700, 1080, -6, 900), ('mango', 1350, 1180, 4, 1080)],
    [('widgets', 1032, None, 0, 840)],
]
FULL_BOTTOM = 2680
# The bezel and the outer and screen corner radii, as shares of the frame's width.
BEZEL, CORNER, SCREEN_CORNER = .026, .045, .019
# Faux Home Screen, in points: widget scale, column gap, and the top of the extra large widget above the large one
# with the medium and small ones stacked beside it; the grid is centred across and down the screen.
HOME_SCREEN = {'scale': 1.25, 'gap': 30}


def font(size, bold=False):
    name = 'DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf'
    return ImageFont.truetype(str(ROOT / 'marketing/fonts' / name), size)


def copy_for(locale, index):
    title, body = base.COPY[locale][index]
    return title, WIDGET_BODY[locale] if index == base.WIDGETS else body


def wrap(draw, text, typeface, width):
    lines, line = [], ''
    for word in text.split():
        candidate = f'{line} {word}'.strip()
        if line and draw.textlength(candidate, font=typeface) > width:
            lines.append(line)
            line = word
        else:
            line = candidate
    return lines + [line]


def marketing_copy(image, locale, index):
    draw = ImageDraw.Draw(image)
    left = TEXT['left']
    draw.text((left, TEXT['kicker'][0]), 'GROWINGUP', font=font(TEXT['kicker'][1], True), fill='#8ad9e4')
    title, body = copy_for(locale, index)
    title_top, title_size, spacing = TEXT['title']
    title_font = font(title_size, True)
    for line in title.split('\n'):
        if draw.textlength(line, font=title_font) > TEXT['width']:
            raise ValueError(f'{locale}: headline exceeds the approved text area')
    draw.multiline_text((left, title_top), title, font=title_font, fill='white', spacing=spacing)
    if body:
        body_top, body_size = TEXT['body']
        body_font = font(body_size)
        draw.multiline_text((left, body_top), '\n'.join(wrap(draw, body, body_font, TEXT['width'])), font=body_font,
                            fill='#b7cbd0', spacing=16)


def frame_height(width, screenshot):
    border = round(width * BEZEL)
    return round((width - border * 2) * screenshot.height / screenshot.width) + border * 2


def full_width(screenshot, top):
    """The frame width whose whole screen fits between `top` and FULL_BOTTOM."""
    width = round((FULL_BOTTOM - top) / ((1 - 2 * BEZEL) * screenshot.height / screenshot.width + 2 * BEZEL))
    while frame_height(width, screenshot) > FULL_BOTTOM - top:
        width -= 1
    return width


def device(image, screenshot, center_x, width, angle, top):
    """Draw a framed iPad screen: an even bezel and rounded display corners, with no notch or island."""
    width = width or full_width(screenshot, top)
    border = round(width * BEZEL)
    inner_width = width - border * 2
    inner_height = round(inner_width * screenshot.height / screenshot.width)
    height = inner_height + border * 2
    frame = Image.new('RGBA', (width, height), '#080b0e')
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, width - 1, height - 1), radius=width * CORNER,
                                          fill='#080b0e', outline='#5b5d60', width=max(2, border // 6))
    inner_size = (inner_width, inner_height)
    screen = screenshot.resize(inner_size, Image.Resampling.LANCZOS)
    screen.putalpha(base.rounded_mask(inner_size, width * SCREEN_CORNER))
    frame.alpha_composite(screen, (border, border))
    frame.putalpha(base.rounded_mask(frame.size, width * CORNER))
    rotated = frame.rotate(-angle, resample=Image.Resampling.BICUBIC, expand=True)
    center_y = top + height / 2
    position = (round(center_x - rotated.width / 2), round(center_y - rotated.height / 2))
    # The blurred shadow gets its own padding, so its edge is never cut off at the frame's bounds.
    blur = 45
    pad = blur * 3
    mask = Image.new('L', (rotated.width + pad * 2, rotated.height + pad * 2))
    mask.paste(rotated.getchannel('A'), (pad, pad))
    shadow = Image.new('RGBA', mask.size, '#020d11')
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(blur)).point(lambda a: a * .35))
    image.alpha_composite(shadow, (position[0] - pad, position[1] - pad + 40))
    image.alpha_composite(rotated, position)
    return position, rotated.size


def widget_layout():
    """Each widget's place on the faux Home Screen, in pixels: (name, left, top, width)."""
    scale, gap = HOME_SCREEN['scale'], HOME_SCREEN['gap'] * HOME_SCREEN['scale']
    column = WIDGET_POINTS['widget-large'][0] * scale
    grid = column * 2 + gap
    extra_large = WIDGET_POINTS['widget-extraLarge'][1] * grid / WIDGET_POINTS['widget-extraLarge'][0]
    large = WIDGET_POINTS['widget-large'][1] * scale
    left = (SIZE[0] / SCALE - grid) / 2
    top = (SIZE[1] / SCALE - extra_large - gap - large) / 2
    second = top + extra_large + gap
    medium = WIDGET_POINTS['widget-medium'][1] * scale
    places = [('widget-extraLarge', left, top, grid), ('widget-large', left, second, column),
              ('widget-medium', left + column + gap, second, column),
              ('widget-small', left + column + gap, second + medium + gap, WIDGET_POINTS['widget-small'][0] * scale)]
    return [(name, round(x * SCALE), round(y * SCALE), round(width * SCALE)) for name, x, y, width in places]


def widget_screen(inputs):
    """A faux Home Screen holding the four real widget captures; the status bar stays empty."""
    width, height = SIZE
    screen = Image.new('RGBA', SIZE)
    draw = ImageDraw.Draw(screen)
    for y in range(height):
        color = tuple(round(a + (b - a) * y / height) for a, b in zip((169, 196, 177), (64, 89, 105)))
        draw.line((0, y, width, y), fill=color)
    for name, left, top, card_width in widget_layout():
        image = inputs[name][0]
        card = image.resize((card_width, round(image.height * card_width / image.width)), Image.Resampling.LANCZOS)
        # Widget corners are 24 pt at native size.
        card.putalpha(base.rounded_mask(card.size, 24 * SCALE * card_width / (WIDGET_POINTS[name][0] * SCALE)))
        screen.alpha_composite(card, (left, top))
    return screen


def compose_image(inputs, locale, index):
    base.SIZE = SIZE
    image = base.background(index)
    marketing_copy(image, locale, index)
    for name, center_x, width, angle, top in CARDS[index]:
        if name == 'widgets':
            screen = widget_screen(inputs)
        elif name == 'leo':
            screen = base.leo(inputs)
        else:
            screen = inputs[name][0]
        device(image, screen, center_x, width, angle, top)
    return image.convert('RGB')


def native_inputs(directory, locale, fireworks):
    """The checkpoints the cards use, keyed by checkpoint name; Leo's card is the chosen fireworks frame."""
    source = directory / locale
    summary = json.loads((source / 'test-summary.json').read_text())
    if summary.get('passedTests', 0) < 1 or summary.get('failedTests', 0) != 0:
        raise ValueError(f'{locale}: capture did not pass')
    attachments = source / 'attachments'
    entries = [item for test in json.loads((attachments / 'manifest.json').read_text()) for item in test['attachments']]
    export_suffix = re.compile(r'_\d+_[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$')
    result = {}
    for name in NAMES + (base.fireworks_name(fireworks),):
        checkpoint = f'store-{locale}-{name}'
        matches = [item for item in entries if item['suggestedHumanReadableName'].endswith('.png')
                   and export_suffix.sub('', item['suggestedHumanReadableName'].removesuffix('.png')) == checkpoint]
        if len(matches) != 1:
            raise ValueError(f'{checkpoint}: expected exactly one native checkpoint')
        path = (attachments / matches[0]['exportedFileName']).resolve()
        if path.parent != attachments.resolve():
            raise ValueError('Attachment path escapes its capture directory')
        with Image.open(path) as image:
            if name in WIDGET_POINTS:
                expected = tuple(points * SCALE for points in WIDGET_POINTS[name])
                # XCTest's element crop can lose up to two edge pixels; keep that native crop as it is.
                valid = all(abs(actual - target) <= 2 for actual, target in zip(image.size, expected))
            else:
                valid = image.size == SIZE
            if image.format != 'PNG' or not valid:
                raise ValueError(f'{checkpoint}: invalid native PNG dimensions {image.size}')
            result[name] = (image.convert('RGBA'), path)
    return result


def read_capture(directory, fireworks):
    """Validate the iPad run's metadata and read its native inputs, per store locale."""
    for locale, delay in fireworks.items():
        if delay not in FIREWORKS_FRAMES:
            raise ValueError(f'{locale}: the iPad capture shoots fireworks only at {FIREWORKS_FRAMES} ms, not {delay}')
    metadata = json.loads((directory / 'metadata.json').read_text())
    if not re.fullmatch('[0-9a-f]{40}', metadata['head_sha']):
        raise ValueError('Capture metadata needs the full source head SHA')
    if (metadata['device'], metadata['family']) != (DEVICE, FAMILY):
        raise ValueError('Use an independently captured native 13-inch iPad Pro run')
    if (metadata['native_width'], metadata['native_height']) != SIZE:
        raise ValueError('Native capture dimensions do not match the 13-inch iPad display')
    return metadata, {store: native_inputs(directory, locale, fireworks[locale])
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
    fireworks = fireworks or {'en': FIREWORKS, 'ru': FIREWORKS}
    metadata, inputs = read_capture(capture, fireworks)
    receipt = {'renderer': 'scripts/render-ipad-app-store-screenshots.py',
               'renderer_sha256': base.sha256(Path(__file__)),
               'base_renderer_sha256': base.sha256(Path(base.__file__)), 'capture': metadata, 'size': list(SIZE),
               'fireworks': {store: base.fireworks_receipt(capture, locale, fireworks[locale])
                             for locale, store in (('en', 'en-US'), ('ru', 'ru'))},
               'inputs': {store: {name: base.sha256(found[name][1]) for name in found} for store, found in inputs.items()},
               'input_sizes': {store: {name: list(found[name][0].size) for name in found} for store, found in inputs.items()},
               'outputs': {}}
    for locale, store in (('en', 'en-US'), ('ru', 'ru')):
        (output / store).mkdir()
        for index, name in enumerate(base.FILES):
            path = output / store / name
            compose_image(inputs[store], locale, index).save(path, optimize=True)
            receipt['outputs'][f'{store}/{name}'] = base.sha256(path)
    if retained:
        retain(capture, inputs, retained)
    (output / 'source.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    print(f'Composed {len(receipt["outputs"])} native-backed 13-inch iPad PNGs in {output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path, help='Capture directory of the iPad Pro 13-inch run')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--retain', type=Path, help='Copy the native inputs here (marketing/app-store/native-captures/<slug>)')
    parser.add_argument('--fireworks', type=base.fireworks_choice, default=None,
                        help=f'Fireworks frame in ms after the swipe, e.g. 1500 or en=1500,ru=1900 (default {FIREWORKS}; '
                             f'shot: {", ".join(map(str, FIREWORKS_FRAMES))})')
    args = parser.parse_args()
    compose(args.capture.resolve(), args.output.resolve(), args.retain and args.retain.resolve(), args.fireworks)
