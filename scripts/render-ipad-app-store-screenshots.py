#!/usr/bin/env python3
"""Compose 13-inch iPad App Store cards from an iPad Pro 13-inch's native captures.

The iPhone families are rendered by render-app-store-screenshots.py. This module reuses its copy, background and
fireworks choice, and adds the iPad's card layout: six landscape 2752x2064 cards per locale, one size for the whole
set. The mosaic, Mia, Leo's fireworks, the edit mode and the widgets show a landscape iPad, where the viewer puts the
photo beside the age; the pets' card shows two portrait iPads. The capture test shoots each checkpoint in the
orientation its card shows.
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

# The card, landscape, as App Store Connect accepts it for the 13-inch iPad display.
SIZE = (2752, 2064)
# The shared background is drawn at the base renderer's size; this module owns its own copy of that module.
base.SIZE = SIZE
# The simulator's screen in portrait, as the capture runner records it.
NATIVE = (2064, 2752)
FAMILY = 'ipad-13'
DEVICE = 'iPad-Pro-13-inch-M5'
PORTRAIT = ('mango', 'teddy')
# Points per pixel is 2; the widget previews have the iPhone's sizes, and the extra large one, iPad's only, an 11-inch iPad's.
WIDGET_POINTS = {'widget-small': (170, 170), 'widget-medium': (364, 170), 'widget-large': (364, 382),
                 'widget-extraLarge': (715, 342)}
NAMES = ('mosaic', 'mia', 'editor', 'mango', 'teddy') + tuple(WIDGET_POINTS)

# The headline takes one line on a landscape card; the widgets card shows four sizes.
COPY = {locale: [(title.replace('\n', ' '), subtitle) for title, subtitle in cards] for locale, cards in base.COPY.items()}
COPY['en'][base.WIDGETS] = (COPY['en'][base.WIDGETS][0], 'Four sizes, up to iPad’s extra large.')
COPY['ru'][base.WIDGETS] = (COPY['ru'][base.WIDGETS][0], 'Четыре размера, до очень большого на iPad.')

# Card layout in card pixels. A device is (native input, centre x, top, width, tilt in degrees); its height follows
# the capture's aspect ratio, and a width of None fits the whole screen between its top and FULL_BOTTOM. The mosaic,
# the edit mode and the widgets keep controls along the bottom edge, so they show the whole device; the people's pages
# bleed off the bottom, below their name and age.
TEXT = {'left': 150, 'kicker': (128, 44), 'title': (205, 124), 'body': (382, 54), 'width': 2452}
CARDS = [
    [('mosaic', 1376, 540, None, 0)],
    [('mia', 1376, 560, 2300, -3)],
    [('leo', 1376, 560, 2300, 3)],
    [('editor', 1376, 540, None, 0)],
    [('teddy', 930, 640, 1180, -6), ('mango', 1830, 540, 1240, 5)],
    [('widgets', 1376, 540, None, 0)],
]
FULL_BOTTOM = 1990
# Faux landscape Home Screen, in points: the extra large widget over the medium and small ones, the large one beside,
# with 40 pt gaps. The block is scaled toward a 13-inch iPad's larger widgets and centred below the status bar.
HOME_SCREEN = {'positions': {'widget-extraLarge': (0, 0), 'widget-medium': (0, 382), 'widget-small': (404, 382),
                             'widget-large': (755, 0)}, 'size': (1119, 552), 'scale': 1.1}
STATUS_BAR = 64


def font(size, bold=False):
    name = 'DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf'
    return ImageFont.truetype(str(ROOT / 'marketing/fonts' / name), size)


def marketing_copy(image, locale, index):
    draw = ImageDraw.Draw(image)
    left = TEXT['left']
    draw.text((left, TEXT['kicker'][0]), 'GROWINGUP', font=font(TEXT['kicker'][1], True), fill='#8ad9e4')
    title, subtitle = COPY[locale][index]
    title_font = font(TEXT['title'][1], True)
    if draw.textlength(title, font=title_font) > TEXT['width']:
        raise ValueError(f'{locale}: headline exceeds the approved text area')
    draw.text((left, TEXT['title'][0]), title, font=title_font, fill='white')
    if subtitle:
        body_font = font(TEXT['body'][1])
        if draw.textlength(subtitle, font=body_font) > TEXT['width']:
            raise ValueError(f'{locale}: subtitle exceeds the approved text area')
        draw.text((left, TEXT['body'][0]), subtitle, font=body_font, fill='#b7cbd0')


def frame_size(screenshot, width):
    border = round(min(width, width * screenshot.height / screenshot.width) * .022)
    inner_width = width - border * 2
    return border, (inner_width, round(inner_width * screenshot.height / screenshot.width))


def full_width(screenshot, top):
    """The widest frame whose whole height fits between `top` and FULL_BOTTOM."""
    width = round((FULL_BOTTOM - top) * screenshot.width / screenshot.height)
    while width > 1 and frame_size(screenshot, width)[1][1] + 2 * frame_size(screenshot, width)[0] > FULL_BOTTOM - top:
        width -= 1
    return width


def device(image, screenshot, center_x, top, width, angle):
    """Draw a framed iPad Pro: even bezels, rounded corners, the front camera on the landscape top edge."""
    if width is None:
        width = full_width(screenshot, top)
    border, inner_size = frame_size(screenshot, width)
    height = inner_size[1] + border * 2
    short = min(width, height)
    frame = Image.new('RGBA', (width, height), '#080b0e')
    draw = ImageDraw.Draw(frame)
    draw.rounded_rectangle((0, 0, width - 1, height - 1), radius=short * .06, fill='#080b0e',
                           outline='#5b5d60', width=max(2, border // 5))
    screen = screenshot.resize(inner_size, Image.Resampling.LANCZOS)
    screen.putalpha(base.rounded_mask(inner_size, short * .045))
    frame.alpha_composite(screen, (border, border))
    camera = border * .22
    # Landscape puts the camera at the top edge's centre; held in portrait it sits on the left edge.
    centre = (width / 2, border / 2) if width > height else (border / 2, height / 2)
    draw.ellipse((centre[0] - camera, centre[1] - camera, centre[0] + camera, centre[1] + camera), fill='#1c2932')
    frame.putalpha(base.rounded_mask(frame.size, short * .06))
    rotated = frame.rotate(-angle, resample=Image.Resampling.BICUBIC, expand=True)
    position = (round(center_x - rotated.width / 2), round(top + height / 2 - rotated.height / 2))
    # The blurred shadow gets its own padding, so its edge is never cut off at the frame's bounds.
    blur = 45
    pad = blur * 3
    mask = Image.new('L', (rotated.width + pad * 2, rotated.height + pad * 2))
    mask.paste(rotated.getchannel('A'), (pad, pad))
    shadow = Image.new('RGBA', mask.size, '#020d11')
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(blur)).point(lambda a: a * .35))
    image.alpha_composite(shadow, (position[0] - pad, position[1] - pad + 36))
    image.alpha_composite(rotated, position)


def widget_screen(inputs):
    """A faux landscape Home Screen of the four real widget captures, under the mosaic's real status bar."""
    width, height = SIZE
    screen = Image.new('RGBA', SIZE)
    # Retain the simulator's real status bar rather than fabricating system symbols; the wallpaper starts in its colour.
    header = inputs['mosaic'][0].crop((0, 0, width, STATUS_BAR))
    top = header.resize((1, 1), Image.Resampling.BOX).getpixel((0, 0))[:3]
    draw = ImageDraw.Draw(screen)
    for y in range(height):
        amount = min(1, y / (height * .45))
        upper = tuple(round(a + (b - a) * amount) for a, b in zip(top, (82, 117, 113)))
        lower = tuple(round(a + (b - a) * max(0, y / height - .45) / .55) for a, b in zip((82, 117, 113), (40, 62, 78)))
        draw.line((0, y, width, y), fill=upper if y < height * .45 else lower)
    screen.alpha_composite(header)
    scale = HOME_SCREEN['scale'] * 2
    block = [round(points * scale) for points in HOME_SCREEN['size']]
    origin = ((width - block[0]) // 2, STATUS_BAR + (height - STATUS_BAR - block[1]) // 2)
    for name, (left, top_points) in HOME_SCREEN['positions'].items():
        card_width = round(WIDGET_POINTS[name][0] * scale)
        image = inputs[name][0]
        card = image.resize((card_width, round(image.height * card_width / image.width)), Image.Resampling.LANCZOS)
        card.putalpha(base.rounded_mask(card.size, 24 * scale))
        screen.alpha_composite(card, (origin[0] + round(left * scale), origin[1] + round(top_points * scale)))
    return screen


def compose_image(inputs, locale, index):
    image = base.background(index)
    marketing_copy(image, locale, index)
    for name, center_x, top, width, angle in CARDS[index]:
        if name == 'widgets':
            screen = widget_screen(inputs)
        elif name == 'leo':
            screen = base.leo(inputs)
        else:
            screen = inputs[name][0]
        device(image, screen, center_x, top, width, angle)
    return image.convert('RGB')


def expected_size(name):
    if name in WIDGET_POINTS:
        return tuple(points * 2 for points in WIDGET_POINTS[name])
    return NATIVE if name in PORTRAIT else SIZE


def native_inputs(directory, locale, fireworks):
    """The checkpoints the cards use, keyed by checkpoint name, each in the orientation its card shows."""
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
            expected = expected_size(name)
            # XCTest's element crop can lose up to two edge pixels; preserve that native crop rather than stretching it.
            valid = (all(abs(actual - target) <= 2 for actual, target in zip(image.size, expected))
                     if name in WIDGET_POINTS else image.size == expected)
            if image.format != 'PNG' or not valid:
                raise ValueError(f'{checkpoint}: invalid native PNG dimensions {image.size}, expected {expected}')
            result[name] = (image.convert('RGBA'), path)
    return result


def read_capture(directory, fireworks):
    """Validate the iPad run's metadata and read its native inputs, per store locale."""
    metadata = json.loads((directory / 'metadata.json').read_text())
    if not re.fullmatch('[0-9a-f]{40}', metadata['head_sha']):
        raise ValueError('Capture metadata needs the full source head SHA')
    if (metadata['device'], metadata['family']) != (DEVICE, FAMILY):
        raise ValueError('Use an independently captured native iPad Pro 13-inch run')
    if (metadata['native_width'], metadata['native_height']) != NATIVE:
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
    fireworks = fireworks or {'en': base.FIREWORKS, 'ru': base.FIREWORKS}
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
                        help=f'Fireworks frame in ms after the swipe, e.g. 2100 or en=1900,ru=2100 (default {base.FIREWORKS})')
    args = parser.parse_args()
    compose(args.capture.resolve(), args.output.resolve(), args.retain and args.retain.resolve(), args.fireworks)
