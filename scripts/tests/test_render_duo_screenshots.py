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

    def inputs(self, display):
        size = self.duo.DISPLAYS[display]['size']
        native = {name: (Image.new('RGBA', size, (255, 0, 255, 255)), Path(name)) for name in ('mia', 'leo-celebration', 'mango', 'teddy')}
        for name, points in self.duo.WIDGET_POINTS.items():
            native[name] = (Image.new('RGBA', (points[0] * 3, points[1] * 3), (255, 0, 255, 255)), Path(name))
        return native

    def render(self, display, locale, index):
        size = self.duo.DISPLAYS[display]['size']
        self.duo.base.SIZE = size
        return self.duo.compose_image(self.duo.Canvas(size), display, self.inputs(display), locale, index)

    def test_every_card_has_the_display_size_and_no_alpha(self):
        for display, settings in self.duo.DISPLAYS.items():
            for index in range(4):
                card = self.render(display, 'en', index)
                self.assertEqual(card.size, settings['size'])
                self.assertEqual(card.mode, 'RGB')

    def magenta(self, card, points):
        return any((lambda p: p[0] > 200 and p[1] < 60 and p[2] > 200)(card.getpixel(point)) for point in points)

    def test_tilted_frames_keep_a_margin_to_the_edges(self):
        for display, settings in self.duo.DISPLAYS.items():
            width, height = settings['size']
            for index in range(4):
                card = self.render(display, 'ru', index)
                where = f'{display} card {index + 1}'
                for x in (0, 12, 24, width - 25, width - 13, width - 1):
                    self.assertFalse(self.magenta(card, [(x, y) for y in range(0, height, 4)]), where)
                for y in (0, 12, 24):
                    self.assertFalse(self.magenta(card, [(x, y) for x in range(0, width, 4)]), where)
                if display == 'inner':
                    # The landscape cards show the whole device; the portrait ones bleed off the bottom on purpose.
                    for y in (height - 25, height - 13, height - 1):
                        self.assertFalse(self.magenta(card, [(x, y) for x in range(0, width, 4)]), where)

    def test_outer_cards_cut_the_device_above_the_avatars_and_bar(self):
        card = self.render('outer', 'en', 0)
        self.assertTrue(self.magenta(card, [(700, 2033)]))
        # About 72% of the framed screen shows: the cut is far above the bottom bar (84-92% of the screen).
        frame_top = self.duo.LAYOUTS['outer']['tops']['mia']
        visible = (2034 - frame_top) / (1240 * 2034 / 1398)
        self.assertLess(visible, .74)

    def test_russian_headlines_fit_the_text_area(self):
        for display in self.duo.DISPLAYS:
            for index in range(4):
                self.render(display, 'ru', index)

    def test_overlong_headline_is_rejected(self):
        size = self.duo.DISPLAYS['outer']['size']
        canvas = self.duo.Canvas(size)
        copy = self.duo.base.COPY
        self.duo.base.COPY = {'en': [('Возраст вашего\nребёнка' * 3, '')] * 4}
        try:
            with self.assertRaisesRegex(ValueError, 'approved text area'):
                self.duo.marketing_copy(canvas, Image.new('RGBA', size), 'en', 0, self.duo.LAYOUTS['outer']['text'])
        finally:
            self.duo.base.COPY = copy

    def test_widget_screen_keeps_the_status_column_empty(self):
        for display, settings in self.duo.DISPLAYS.items():
            width, height = settings['size']
            screen = self.duo.widget_screen(self.duo.Canvas(settings['size']), display, self.inputs(display))
            self.assertEqual(screen.size, settings['size'])
            # The right 84 pt (252 px) hold the clock and Wi-Fi of the native display.
            self.assertFalse(self.magenta(screen, [(x, y) for x in range(width - 252, width, 6) for y in range(0, height, 6)]), display)
            self.assertTrue(self.magenta(screen, [(width // 3, height // 3)]) or self.magenta(screen, [(width // 6, height // 6)]), display)

    def test_inner_widget_card_sets_the_widgets_side_by_side_on_the_wide_display(self):
        positions = self.duo.HOME_SCREEN['inner']['positions']
        lefts = [left for left, _ in positions]
        self.assertEqual(sorted(lefts), lefts)
        self.assertEqual(len({top for _, top in positions}), 1)

    def test_composition_refuses_a_stale_output_folder(self):
        import tempfile
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / 'old.png').write_bytes(b'x')
            with self.assertRaisesRegex(ValueError, 'empty'):
                self.duo.compose(Path(folder), Path(folder), Path(folder))


@unittest.skipUnless(FAMILIES.exists(), 'manifest missing')
class ExistingFamilyProvenanceTests(unittest.TestCase):
    """The Duo work must not change the renderer or PNGs the earlier families were uploaded from."""

    def test_older_families_still_match_their_renderer_and_pngs(self):
        renderer = hashlib.sha256((ROOT / 'scripts/render-app-store-screenshots.py').read_bytes()).hexdigest()
        checked = 0
        for entry in json.loads(FAMILIES.read_text())['sets']:
            if entry['group'] == 'IPHONE_DUO_PROFILE':
                continue
            folder = (FAMILIES.parent / entry['path']).resolve()
            source = json.loads((folder / 'source.json').read_text())
            if source['capture'].get('workflow') == 'local-screenshot-only':
                self.assertEqual(source['renderer_sha256'], renderer, entry['slug'])
            for name, sha in source['outputs'].items():
                self.assertEqual(hashlib.sha256((folder / name).read_bytes()).hexdigest(), sha, f"{entry['slug']}/{name}")
                checked += 1
        self.assertGreaterEqual(checked, 32)


if __name__ == '__main__':
    unittest.main()
