import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

try:
    from PIL import Image
except ImportError:  # The renderer needs Pillow; the Linux checks skip it.
    Image = None

ROOT = Path(__file__).parents[2]
FAMILIES = ROOT / 'marketing/app-store/screenshots/families.json'


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@unittest.skipUnless(Image, 'Pillow is not installed')
class DuoCardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.duo = load('duo_renderer', 'render-duo-app-store-screenshots.py')

    def inputs(self):
        screens = ('mosaic', 'mia', 'editor', 'mango', 'teddy', 'leo-fireworks-1900')
        native = {name: (Image.new('RGBA', self.duo.SIZE, (255, 0, 255, 255)), Path(name)) for name in screens}
        for name, points in self.duo.WIDGET_POINTS.items():
            native[name] = (Image.new('RGBA', (points[0] * 3, points[1] * 3), (255, 0, 255, 255)), Path(name))
        return native

    def render(self, locale, index):
        self.duo.base.SIZE = self.duo.SIZE
        return self.duo.compose_image(self.duo.Canvas(self.duo.SIZE), self.inputs(), locale, index)

    def magenta(self, card, points):
        return any((lambda p: p[0] > 200 and p[1] < 60 and p[2] > 200)(card.getpixel(point)) for point in points)

    def test_every_card_has_the_display_size_and_no_alpha(self):
        self.assertEqual(len(self.duo.CARDS), len(self.duo.base.FILES))
        for index in range(len(self.duo.CARDS)):
            card = self.render('en', index)
            self.assertEqual(card.size, self.duo.SIZE)
            self.assertEqual(card.mode, 'RGB')

    def test_tilted_frames_keep_a_margin_to_the_edges(self):
        width, height = self.duo.SIZE
        for index in range(len(self.duo.CARDS)):
            card = self.render('ru', index)
            for x in (0, 12, 24, width - 25, width - 13, width - 1):
                self.assertFalse(self.magenta(card, [(x, y) for y in range(0, height, 4)]), f'card {index + 1}')
            for y in (0, 12, 24):
                self.assertFalse(self.magenta(card, [(x, y) for x in range(0, width, 4)]), f'card {index + 1}')

    def test_cards_cut_the_device_above_the_avatars_and_bar(self):
        card = self.render('en', self.duo.base.CARDS.index('mia'))
        self.assertTrue(self.magenta(card, [(700, 2033)]))
        # About 72% of the framed screen shows: the cut is far above the bottom bar (84-92% of the screen).
        visible = (2034 - self.duo.TOPS['mia']) / (1240 * 2034 / 1398)
        self.assertLess(visible, .74)

    def test_main_screens_show_the_whole_device(self):
        width, height = self.duo.SIZE
        for card_name in ('mosaic', 'editor'):
            card = self.render('ru', self.duo.base.CARDS.index(card_name))
            # The screen's bottom edge, with its controls, stays above the card's last rows.
            self.assertFalse(self.magenta(card, [(x, y) for x in range(0, width, 4) for y in range(height - 45, height)]), card_name)
            self.assertTrue(self.magenta(card, [(width // 2, self.duo.FULL_BOTTOM - 40)]), card_name)

    def test_russian_headlines_fit_the_text_area(self):
        for index in range(len(self.duo.CARDS)):
            self.render('ru', index)

    def test_overlong_headline_is_rejected(self):
        canvas = self.duo.Canvas(self.duo.SIZE)
        copy = self.duo.base.COPY
        self.duo.base.COPY = {'en': [('Возраст вашего\nребёнка' * 3, '')] * len(self.duo.CARDS)}
        try:
            with self.assertRaisesRegex(ValueError, 'approved text area'):
                self.duo.marketing_copy(canvas, Image.new('RGBA', self.duo.SIZE), 'en', 0, self.duo.TEXT)
        finally:
            self.duo.base.COPY = copy

    def test_widget_screen_keeps_the_status_column_empty(self):
        width, height = self.duo.SIZE
        screen = self.duo.widget_screen(self.duo.Canvas(self.duo.SIZE), self.inputs())
        self.assertEqual(screen.size, self.duo.SIZE)
        # The right 84 pt (252 px) hold the clock and Wi-Fi of the native display.
        self.assertFalse(self.magenta(screen, [(x, y) for x in range(width - 252, width, 6) for y in range(0, height, 6)]))
        self.assertTrue(self.magenta(screen, [(width // 3, height // 3)]) or self.magenta(screen, [(width // 6, height // 6)]))

    def test_composition_refuses_a_stale_output_folder(self):
        import tempfile
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / 'old.png').write_bytes(b'x')
            with self.assertRaisesRegex(ValueError, 'empty'):
                self.duo.compose(Path(folder), Path(folder))


@unittest.skipUnless(Image, 'Pillow is not installed')
class StandardCardTests(unittest.TestCase):
    """Every regular family's six cards: native sizes, the whole main screens, and the uploader's file list."""

    @classmethod
    def setUpClass(cls):
        cls.base = load('base_renderer', 'render-app-store-screenshots.py')

    def inputs(self, size, scale):
        screens = ('mosaic', 'mia', 'editor', 'mango', 'teddy', 'leo-fireworks-1900')
        native = {name: (Image.new('RGBA', size, (255, 0, 255, 255)), Path(name)) for name in screens}
        for name, points in {'widget-small': (170, 170), 'widget-medium': (364, 170), 'widget-large': (364, 382)}.items():
            native[name] = (Image.new('RGBA', (points[0] * scale, points[1] * scale), (255, 0, 255, 255)), Path(name))
        return native

    def magenta(self, card, points):
        return any((lambda p: p[0] > 200 and p[1] < 60 and p[2] > 200)(card.getpixel(point)) for point in points)

    def test_uploader_lists_the_renderer_cards(self):
        metadata = load('store_metadata', 'app-store-metadata.py')
        self.assertEqual(metadata.FILES, self.base.FILES)
        self.assertEqual(len(self.base.FILES), 6)
        for locale in ('en', 'ru'):
            self.assertEqual(len(self.base.COPY[locale]), len(self.base.CARDS))

    def test_main_screens_fit_whole_on_every_family(self):
        for size, family in self.base.PROFILES.values():
            self.base.SIZE, self.base.FAMILY = size, family
            native = self.inputs(size, 2 if family == 'home-button' else 3)
            for index, card_name in enumerate(self.base.CARDS):
                for locale in ('en', 'ru'):
                    card = self.base.compose_image(native, locale, index)
                    self.assertEqual((card.size, card.mode), (size, 'RGB'))
                if card_name in ('mosaic', 'editor'):
                    width, height = size
                    edges = [(x, y) for x in range(0, width, 3) for y in range(height - round(height * .01), height)]
                    edges += [(x, y) for x in (0, 1, width - 2, width - 1) for y in range(0, height, 3)]
                    self.assertFalse(self.magenta(card, edges), f'{family} {card_name}')

    def test_fireworks_frame_choice(self):
        self.assertEqual(self.base.fireworks_choice('2100'), {'en': 2100, 'ru': 2100})
        self.assertEqual(self.base.fireworks_choice('ru=2300'), {'en': self.base.FIREWORKS, 'ru': 2300})
        self.assertEqual(self.base.fireworks_name(2100), 'leo-fireworks-2100')
        with self.assertRaisesRegex(ValueError, 'No fireworks frame'):
            self.base.fireworks_name(2000)


@unittest.skipUnless(FAMILIES.exists(), 'manifest missing')
class ExistingFamilyProvenanceTests(unittest.TestCase):
    """The earlier families' PNGs must stay exactly what was uploaded."""

    def test_older_families_still_match_their_pngs(self):
        checked = 0
        for entry in json.loads(FAMILIES.read_text())['sets']:
            if entry['group'] == 'IPHONE_DUO_PROFILE':
                continue
            folder = (FAMILIES.parent / entry['path']).resolve()
            source = json.loads((folder / 'source.json').read_text())
            for name, sha in source['outputs'].items():
                self.assertEqual(hashlib.sha256((folder / name).read_bytes()).hexdigest(), sha, f"{entry['slug']}/{name}")
                checked += 1
        self.assertGreaterEqual(checked, 32)


if __name__ == '__main__':
    unittest.main()
