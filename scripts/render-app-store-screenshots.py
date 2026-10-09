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
    for name in NAMES:
        checkpoint = f'store-{locale}-{name}'
        matches = [item for item in entries if item['suggestedHumanReadableName'].removesuffix('.png') == checkpoint]
        if len(matches) != 1:
            raise ValueError(f'{checkpoint}: expected exactly one native checkpoint')
        path = (attachments / matches[0]['exportedFileName']).resolve()
        if path.parent != attachments.resolve():
            raise ValueError('Attachment path escapes its capture directory')
        with Image.open(path) as image:
            expected = {'widget-small': (510, 510), 'widget-medium': (1092, 510),
                        'widget-large': (1092, 1146)}.get(name, SIZE)
            if image.format != 'PNG' or image.size != expected:
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
    return ImageFont.truetype(str(ROOT / 'marketing/fonts' / filename), size)


def marketing_copy(canvas, locale, index):
    draw = ImageDraw.Draw(canvas)
    x, y = 106, 206
    draw.text((x, y), 'GROWINGUP', font=font(39, True), fill='#8ad9e4')
    title, subtitle = COPY[locale][index]
    title_font = font(119, True)
    lines = title.split('\n')
    for line in lines:
        if draw.textlength(line, font=title_font) > 1108:
            raise ValueError(f'{locale}: headline exceeds the approved text area')
    draw.multiline_text((x, 330), title, font=title_font, fill='white', spacing=20)
    if subtitle:
        body_font = font(44)
        words, wrapped = subtitle.split(), []
        line = ''
        for word in words:
            candidate = f'{line} {word}'.strip()
            if line and draw.textlength(candidate, font=body_font) > 1080:
                wrapped.append(line)
                line = word
            else:
                line = candidate
        wrapped.append(line)
        draw.multiline_text((x, 655), '\n'.join(wrapped), font=body_font, fill='#b7cbd0', spacing=14)


def rounded_mask(size, radius):
    mask = Image.new('L', size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def phone(canvas, screenshot, left, top, width, angle):
    height = round(width * SIZE[1] / SIZE[0])
    border = round(width * .02)
    frame = Image.new('RGBA', (width, height), '#080b0e')
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, width - 1, height - 1), radius=width * .14,
                                          fill='#080b0e', outline='#5b5d60', width=border)
    inner_size = (width - border * 2, height - border * 2)
    screen = screenshot.resize(inner_size, Image.Resampling.LANCZOS)
    screen.putalpha(rounded_mask(inner_size, width * .12))
    frame.alpha_composite(screen, (border, border))
    # Simulator screenshots omit the physical camera cutout; the device frame includes it.
    ImageDraw.Draw(frame).rounded_rectangle((width * .32, height * .025, width * .68, height * .069),
                                           radius=width * .05, fill='#030405')
    frame.putalpha(rounded_mask(frame.size, width * .14))
    rotated = frame.rotate(-angle, resample=Image.Resampling.BICUBIC, expand=True)
    position = (round(left + (width - rotated.width) / 2), round(top + (height - rotated.height) / 2))
    shadow = Image.new('RGBA', rotated.size, '#020d11')
    shadow.putalpha(rotated.getchannel('A').filter(ImageFilter.GaussianBlur(35)).point(lambda a: a * .35))
    canvas.alpha_composite(shadow, (position[0], position[1] + 30))
    canvas.alpha_composite(rotated, position)


def widget_screen(inputs):
    screen = Image.new('RGBA', SIZE)
    draw = ImageDraw.Draw(screen)
    for y in range(SIZE[1]):
        amount = y / SIZE[1]
        color = tuple(round(a + (b - a) * amount) for a, b in zip((169, 196, 177), (64, 89, 105)))
        draw.line((0, y, SIZE[0], y), fill=color)
    # Retain the simulator's real status bar rather than fabricating system symbols.
    header = inputs['mia'][0].crop((0, 0, SIZE[0], 190))
    screen.alpha_composite(header)
    for name, width, top in [('widget-small', 500, 350), ('widget-medium', 1140, 960),
                             ('widget-large', 1140, 1550)]:
        image = inputs[name][0]
        height = round(image.height * width / image.width)
        card = image.resize((width, height), Image.Resampling.LANCZOS)
        card.putalpha(rounded_mask(card.size, width * .065))
        screen.alpha_composite(card, ((SIZE[0] - width) // 2, top))
    return screen


def compose(directory, output):
    metadata = json.loads((directory / 'metadata.json').read_text())
    if not re.fullmatch('[0-9a-f]{40}', metadata['head_sha']):
        raise ValueError('Capture metadata needs the full source head SHA')
    if (metadata['device'], metadata['runtime']) != ('iPhone-17-Pro-Max', '26-5'):
        raise ValueError('Use the approved native iPhone 17 Pro Max / iOS 26.5 capture')
    if output.exists() and any(output.iterdir()):
        raise ValueError('Output directory must be empty to avoid stale screenshots')
    output.mkdir(parents=True, exist_ok=True)
    receipt = {'capture': metadata, 'size': list(SIZE), 'inputs': {}, 'outputs': {}}
    for locale, store_locale in [('en', 'en-US'), ('ru', 'ru')]:
        inputs = native_inputs(directory, locale)
        receipt['inputs'][store_locale] = {name: sha256(path) for name, (_, path) in inputs.items()}
        destination = output / store_locale
        destination.mkdir()
        for index, name in enumerate(FILES):
            canvas = background(index)
            marketing_copy(canvas, locale, index)
            if index == 0:
                phone(canvas, inputs['mia'][0], 119, 1004, 1135, -4)
            elif index == 1:
                phone(canvas, inputs['leo-celebration'][0], 92, 1004, 1135, 4)
            elif index == 2:
                phone(canvas, inputs['teddy'][0], -106, 1233, 766, -9)
                phone(canvas, inputs['mango'][0], 224, 1004, 1135, 5)
            else:
                phone(canvas, widget_screen(inputs), 215, 900, 890, 0)
            path = destination / name
            canvas.convert('RGB').save(path, optimize=True)
            receipt['outputs'][f'{store_locale}/{name}'] = sha256(path)
    (output / 'source.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    print(f'Composed 8 native-backed App Store PNGs in {output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    compose(args.capture.resolve(), args.output.resolve())
