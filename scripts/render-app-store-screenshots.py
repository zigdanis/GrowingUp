#!/usr/bin/env python3
"""Compose approved App Store artwork exclusively from successful native captures."""
import argparse
import hashlib
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SIZE = (1320, 2868)
FAMILY = 'dynamic-island'
PROFILES = {
    'iPhone-17-Pro-Max': ((1320, 2868), 'dynamic-island'),
    'iPhone-17-Pro': ((1206, 2622), 'dynamic-island'),
    'iPhone-14-Plus': ((1284, 2778), 'face-id'),
    'iPhone-SE-3rd-generation': ((750, 1334), 'home-button'),
}
NAMES = ('mia', 'leo-celebration', 'mango', 'teddy', 'widget-small', 'widget-medium', 'widget-large')
COPY = {
    'ru': [
        ('Возраст вашего\nребёнка', 'С точностью до секунды.'),
        ('С днём\nрождения!', 'Празднуйте вместе с GrowingUp.'),
        ('Возраст вашего\nпитомца', ''),
        ('Возраст на\nглавном экране', 'Три размера для семьи и питомцев.'),
    ],
    'en': [
        ('Your child’s\nage', 'Down to the second.'),
        ('Happy\nbirthday!', 'Celebrate with GrowingUp.'),
        ('Your pet’s\nage', ''),
        ('Home Screen\nwidgets', 'Three sizes for your family and pets.'),
    ],
}
FILES = ('01-mia.png', '02-leo-celebration.png', '03-mango-teddy.png', '04-widgets.png')


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def native_inputs(directory, locale):
    source = directory / locale
    summary = json.loads((source / 'test-summary.json').read_text())
    if summary.get('passedTests', 0) < 1 or summary.get('failedTests', 0) != 0:
        raise ValueError(f'{locale}: capture did not pass')
    attachments = source / 'attachments'
    manifest = json.loads((attachments / 'manifest.json').read_text())
    entries = [item for test in manifest for item in test['attachments']]
    result = {}
    export_suffix = re.compile(r'_\d+_[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$')
    for name in NAMES:
        checkpoint = f'store-{locale}-{name}'
        matches = [item for item in entries
                   if export_suffix.sub('', item['suggestedHumanReadableName'].removesuffix('.png')) == checkpoint]
        if len(matches) != 1:
            raise ValueError(f'{checkpoint}: expected exactly one native checkpoint')
        path = (attachments / matches[0]['exportedFileName']).resolve()
        if path.parent != attachments.resolve():
            raise ValueError('Attachment path escapes its capture directory')
        with Image.open(path) as image:
            scale = 2 if FAMILY == 'home-button' else 3
            expected = {'widget-small': (170 * scale, 170 * scale),
                        'widget-medium': (364 * scale, 170 * scale),
                        'widget-large': (364 * scale, 382 * scale)}.get(name, SIZE)
            # XCTest's element crop can lose up to two edge pixels on this runtime;
            # preserve that native crop rather than padding or stretching it.
            valid_size = (all(abs(actual - target) <= 2 for actual, target in zip(image.size, expected))
                          if name.startswith('widget-') else image.size == expected)
            if image.format != 'PNG' or not valid_size:
                raise ValueError(f'{checkpoint}: invalid native PNG dimensions')
            result[name] = (image.convert('RGBA'), path)
    return result


def background(index):
    base = [(16, 36, 43), (22, 34, 41), (23, 42, 40), (24, 58, 66)][index]
    glow = (38, 117, 132)
    small = Image.new('RGB', (132, 287))
    pixels = []
    for y in range(287):
        for x in range(132):
            distance = ((x / 131 - 1) ** 2 / 1.1 + (y / 286 - .85) ** 2 / .8) ** .5
            amount = max(0, 1 - distance) * .65
            pixels.append(tuple(round(a + (b - a) * amount) for a, b in zip(base, glow)))
    small.putdata(pixels)
    return small.resize(SIZE, Image.Resampling.BICUBIC).convert('RGBA')


def font(size, bold=False):
    filename = 'DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf'
    return ImageFont.truetype(str(ROOT / 'marketing/fonts' / filename), sx(size))


def sx(value):
    return round(value * SIZE[0] / 1320)


def sy(value):
    return round(value * SIZE[1] / 2868)


def marketing_copy(canvas, locale, index):
    draw = ImageDraw.Draw(canvas)
    x, y = sx(106), sy(206)
    draw.text((x, y), 'GROWINGUP', font=font(39, True), fill='#8ad9e4')
    title, subtitle = COPY[locale][index]
    title_font = font(119, True)
    lines = title.split('\n')
    for line in lines:
        if draw.textlength(line, font=title_font) > sx(1108):
            raise ValueError(f'{locale}: headline exceeds the approved text area')
    draw.multiline_text((x, sy(330)), title, font=title_font, fill='white', spacing=sy(20))
    if subtitle:
        body_font = font(44)
        words, wrapped = subtitle.split(), []
        line = ''
        for word in words:
            candidate = f'{line} {word}'.strip()
            if line and draw.textlength(candidate, font=body_font) > sx(1080):
                wrapped.append(line)
                line = word
            else:
                line = candidate
        wrapped.append(line)
        draw.multiline_text((x, sy(655)), '\n'.join(wrapped), font=body_font, fill='#b7cbd0', spacing=sy(14))


def rounded_mask(size, radius):
    mask = Image.new('L', size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def phone(canvas, screenshot, left, top, width, angle, native_layout=False):
    if not native_layout:
        left, top, width = sx(left), sy(top), sx(width)
    if FAMILY == 'home-button':
        home_button_phone(canvas, screenshot, left, top, width, angle)
        return
    border = round(width * .02)
    # Uniform scaling keeps the independently captured screen's native aspect ratio.
    inner_width = width - border * 2
    inner_height = round(inner_width * screenshot.height / screenshot.width)
    height = inner_height + border * 2
    frame = Image.new('RGBA', (width, height), '#080b0e')
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, width - 1, height - 1), radius=width * .14,
                                          fill='#080b0e', outline='#5b5d60', width=border)
    inner_size = (inner_width, inner_height)
    screen = screenshot.resize(inner_size, Image.Resampling.LANCZOS)
    screen.putalpha(rounded_mask(inner_size, width * .12))
    frame.alpha_composite(screen, (border, border))
    draw = ImageDraw.Draw(frame)
    if FAMILY == 'face-id':
        # iPhone 14 Plus: the notch touches the top edge, with rounded lower corners.
        notch = (width * .31, border, width * .69, border + inner_width * 33 / 428)
        draw.rounded_rectangle(notch, radius=inner_width * 12 / 428, fill='#030405')
        draw.rectangle((notch[0], border, notch[2], border + inner_width * 12 / 428), fill='#030405')
    else:
        # iPhone 17 Pro's floating camera island stays inside the native safe area.
        draw.rounded_rectangle((border + inner_width * .344, border + inner_width * 11 / 402,
                                border + inner_width * .656, border + inner_width * 48 / 402),
                               radius=inner_width * 19 / 402, fill='#030405')
    frame.putalpha(rounded_mask(frame.size, width * .14))
    rotated = frame.rotate(-angle, resample=Image.Resampling.BICUBIC, expand=True)
    position = (round(left + (width - rotated.width) / 2), round(top + (height - rotated.height) / 2))
    shadow = Image.new('RGBA', rotated.size, '#020d11')
    shadow.putalpha(rotated.getchannel('A').filter(ImageFilter.GaussianBlur(sx(35))).point(lambda a: a * .35))
    canvas.alpha_composite(shadow, (position[0], position[1] + sy(30)))
    canvas.alpha_composite(rotated, position)


def home_button_phone(canvas, screenshot, left, top, width, angle):
    # SE 3 body: 138.4 x 67.3 mm, rectangular 16:9 LCD and physical Touch ID.
    height = round(width * 138.4 / 67.3)
    border = max(2, round(width * .02))
    frame = Image.new('RGBA', (width, height), '#080b0e')
    draw = ImageDraw.Draw(frame)
    draw.rounded_rectangle((0, 0, width - 1, height - 1), radius=width * .105,
                           fill='#080b0e', outline='#5b5d60', width=border)
    screen_width = round(width * .87)
    screen_height = round(screen_width * screenshot.height / screenshot.width)
    screen_left = (width - screen_width) // 2
    screen_top = round(width * .25)
    # Home Button LCD has no notch, island, or rounded display corners.
    screen = screenshot.resize((screen_width, screen_height), Image.Resampling.LANCZOS)
    frame.alpha_composite(screen, (screen_left, screen_top))
    draw.rounded_rectangle((width * .43, width * .12, width * .57, width * .135),
                           radius=width * .008, fill='#34373b')
    draw.ellipse((width * .325, width * .105, width * .35, width * .13), fill='#1c2932')
    center_y = screen_top + screen_height + (height - screen_top - screen_height) / 2
    radius = width * .078
    draw.ellipse((width / 2 - radius, center_y - radius, width / 2 + radius, center_y + radius),
                 fill='#07090b', outline='#777a80', width=max(1, border // 3))
    frame.putalpha(rounded_mask(frame.size, width * .105))
    rotated = frame.rotate(-angle, resample=Image.Resampling.BICUBIC, expand=True)
    position = (round(left + (width - rotated.width) / 2), round(top + (height - rotated.height) / 2))
    shadow = Image.new('RGBA', rotated.size, '#020d11')
    shadow.putalpha(rotated.getchannel('A').filter(ImageFilter.GaussianBlur(sx(35))).point(lambda a: a * .35))
    canvas.alpha_composite(shadow, (position[0], position[1] + sy(30)))
    canvas.alpha_composite(rotated, position)


def widget_screen(inputs):
    screen = Image.new('RGBA', SIZE)
    draw = ImageDraw.Draw(screen)
    for y in range(SIZE[1]):
        amount = y / SIZE[1]
        color = tuple(round(a + (b - a) * amount) for a, b in zip((169, 196, 177), (64, 89, 105)))
        draw.line((0, y, SIZE[0], y), fill=color)
    # Retain the simulator's real status bar rather than fabricating system symbols.
    header_height = 40 if FAMILY == 'home-button' else (132 if FAMILY == 'face-id' else 186)
    header = inputs['mia'][0].crop((0, 0, SIZE[0], header_height))
    screen.alpha_composite(header)
    layouts = ([('widget-small', 250, 80), ('widget-medium', 560, 360), ('widget-large', 560, 652)]
               if FAMILY == 'home-button' else [('widget-small', 500, 350), ('widget-medium', 1140, 960),
                                               ('widget-large', 1140, 1550)])
    for name, width, top in layouts:
        if FAMILY != 'home-button':
            width, top = sx(width), sy(top)
        image = inputs[name][0]
        height = round(image.height * width / image.width)
        card = image.resize((width, height), Image.Resampling.LANCZOS)
        native_width = 170 if name == 'widget-small' else 364
        card.putalpha(rounded_mask(card.size, width * 24 / native_width))
        screen.alpha_composite(card, ((SIZE[0] - width) // 2, top))
    return screen


def compose_image(inputs, locale, index):
    canvas = background(index)
    marketing_copy(canvas, locale, index)
    if FAMILY == 'home-button':
        # Shorter LCD needs a distinct layout; keep the physical Home button visible.
        if index == 0:
            phone(canvas, inputs['mia'][0], 167, 408, 415, -4, native_layout=True)
        elif index == 1:
            phone(canvas, inputs['leo-celebration'][0], 167, 408, 415, 4, native_layout=True)
        elif index == 2:
            phone(canvas, inputs['teddy'][0], 20, 570, 300, -9, native_layout=True)
            phone(canvas, inputs['mango'][0], 270, 408, 410, 5, native_layout=True)
        else:
            phone(canvas, widget_screen(inputs), 162, 385, 425, 0, native_layout=True)
        return canvas.convert('RGB')
    if index == 0:
        phone(canvas, inputs['mia'][0], 119, 1004, 1135, -4)
    elif index == 1:
        phone(canvas, inputs['leo-celebration'][0], 92, 1004, 1135, 4)
    elif index == 2:
        phone(canvas, inputs['teddy'][0], -106, 1233, 766, -9)
        phone(canvas, inputs['mango'][0], 158, 1004, 1000, 5)
    else:
        phone(canvas, widget_screen(inputs), 215, 900, 890, 0)
    return canvas.convert('RGB')


def compose(directory, output):
    global SIZE, FAMILY
    metadata = json.loads((directory / 'metadata.json').read_text())
    if not re.fullmatch('[0-9a-f]{40}', metadata['head_sha']):
        raise ValueError('Capture metadata needs the full source head SHA')
    if metadata['device'] not in PROFILES or metadata['runtime'] != '26-5':
        raise ValueError('Use a supported, independently captured native device / iOS 26.5')
    SIZE, FAMILY = PROFILES[metadata['device']]
    if (metadata['native_width'], metadata['native_height']) != SIZE:
        raise ValueError('Native capture dimensions do not match the selected hardware')
    if output.exists() and any(output.iterdir()):
        raise ValueError('Output directory must be empty to avoid stale screenshots')
    output.mkdir(parents=True, exist_ok=True)
    receipt = {'capture': metadata, 'size': list(SIZE), 'family': FAMILY,
               'renderer_sha256': sha256(Path(__file__)), 'inputs': {}, 'input_sizes': {}, 'outputs': {}}
    for locale, store_locale in [('en', 'en-US'), ('ru', 'ru')]:
        inputs = native_inputs(directory, locale)
        receipt['inputs'][store_locale] = {name: sha256(path) for name, (_, path) in inputs.items()}
        receipt['input_sizes'][store_locale] = {name: list(image.size) for name, (image, _) in inputs.items()}
        destination = output / store_locale
        destination.mkdir()
        for index, name in enumerate(FILES):
            path = destination / name
            compose_image(inputs, locale, index).save(path, optimize=True)
            receipt['outputs'][f'{store_locale}/{name}'] = sha256(path)
    (output / 'source.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    print(f'Composed 8 native-backed App Store PNGs in {output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    compose(args.capture.resolve(), args.output.resolve())
