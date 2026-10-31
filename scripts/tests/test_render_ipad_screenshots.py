import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

try:
    from PIL import Image
except ImportError:  # The renderer needs Pillow; the Linux checks skip it.
    Image = None

ROOT = Path(__file__).parents[2]


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@unittest.skipUnless(Image, 'Pillow is not installed')
class IPadCardTests(unittest.TestCase):
    """Six landscape 13-inch cards per locale: one size, whole main screens, and checkpoints in their card's orientation."""

    @classmethod
    def setUpClass(cls):
        cls.ipad = load('ipad_renderer', 'render-ipad-app-store-screenshots.py')

    def inputs(self):
        native = {name: (Image.new('RGBA', self.ipad.expected_size(name), (255, 0, 255, 255)), Path(name))
                  for name in self.ipad.NAMES + ('leo-fireworks-1900',)}
        # The status bar the widget card keeps comes from the mosaic's top rows.
        native['mosaic'][0].paste((20, 30, 40, 255), (0, 0, self.ipad.SIZE[0], self.ipad.STATUS_BAR))
        return native

    def render(self, locale, index):
        return self.ipad.compose_image(self.inputs(), locale, index)

    def magenta(self, card, points):
        return any((lambda p: p[0] > 200 and p[1] < 60 and p[2] > 200)(card.getpixel(point)) for point in points)

    def test_every_card_is_one_landscape_size_without_alpha(self):
        self.assertEqual(len(self.ipad.CARDS), len(self.ipad.base.FILES))
        for locale in ('en', 'ru'):
            for index in range(len(self.ipad.CARDS)):
                card = self.render(locale, index)
                self.assertEqual((card.size, card.mode), ((2752, 2064), 'RGB'))

    def test_checkpoints_are_read_in_their_cards_orientation(self):
        self.assertEqual(self.ipad.expected_size('mia'), (2752, 2064))
        self.assertEqual(self.ipad.expected_size('leo-fireworks-1900'), (2752, 2064))
        self.assertEqual(self.ipad.expected_size('teddy'), (2064, 2752))
        self.assertEqual(self.ipad.expected_size('widget-extraLarge'), (1430, 684))

    def test_frames_keep_a_margin_to_the_sides_and_top(self):
        width, height = self.ipad.SIZE
        for index in range(len(self.ipad.CARDS)):
            card = self.render('ru', index)
            for x in (0, 24, width - 25, width - 1):
                self.assertFalse(self.magenta(card, [(x, y) for y in range(0, height, 4)]), f'card {index + 1}')
            for y in (0, 24, self.ipad.TEXT['body'][0]):
                self.assertFalse(self.magenta(card, [(x, y) for x in range(0, width, 4)]), f'card {index + 1}')

    def test_main_screens_show_the_whole_device(self):
        width, height = self.ipad.SIZE
        for card_name in ('mosaic', 'editor', 'widgets'):
            card = self.render('en', self.ipad.base.CARDS.index(card_name))
            # The screen's bottom edge, with its controls, stays above the card's last rows.
            self.assertFalse(self.magenta(card, [(x, y) for x in range(0, width, 4) for y in range(height - 40, height)]), card_name)
            # The frame's dark bottom bezel sits just above FULL_BOTTOM.
            self.assertLess(max(card.getpixel((width // 2, self.ipad.FULL_BOTTOM - 8))), 40, card_name)

    def test_peoples_pages_bleed_off_the_bottom(self):
        width, height = self.ipad.SIZE
        for card_name in ('mia', 'leo-birthday', 'pets'):
            card = self.render('en', self.ipad.base.CARDS.index(card_name))
            self.assertTrue(self.magenta(card, [(x, height - 1) for x in range(0, width, 8)]), card_name)

    def test_copy_fits_on_one_line(self):
        for locale in ('en', 'ru'):
            for title, _ in self.ipad.COPY[locale]:
                self.assertNotIn('\n', title)
            for index in range(len(self.ipad.CARDS)):
                self.render(locale, index)

    def test_overlong_headline_is_rejected(self):
        copy = self.ipad.COPY
        self.ipad.COPY = {'en': [('Возраст вашего ребёнка' * 2, '')] * len(self.ipad.CARDS)}
        try:
            with self.assertRaisesRegex(ValueError, 'approved text area'):
                self.ipad.marketing_copy(Image.new('RGBA', self.ipad.SIZE), 'en', 0)
        finally:
            self.ipad.COPY = copy

    def test_widget_screen_keeps_the_real_status_bar_and_all_four_widgets(self):
        screen = self.ipad.widget_screen(self.inputs())
        self.assertEqual(screen.size, self.ipad.SIZE)
        self.assertEqual(screen.getpixel((10, 10))[:3], (20, 30, 40))
        layout = self.ipad.HOME_SCREEN
        scale = layout['scale'] * 2
        origin_x = (self.ipad.SIZE[0] - round(layout['size'][0] * scale)) // 2
        for name, (left, _) in layout['positions'].items():
            self.assertTrue(self.magenta(screen, [(origin_x + round((left + 60) * scale), y) for y in range(0, self.ipad.SIZE[1], 4)]), name)

    def test_portrait_capture_of_a_landscape_card_is_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / 'en'
            attachments = source / 'attachments'
            attachments.mkdir(parents=True)
            (source / 'test-summary.json').write_text(json.dumps({'passedTests': 1, 'failedTests': 0}))
            entries = []
            for index, name in enumerate(self.ipad.NAMES + ('leo-fireworks-1900',)):
                size = (2064, 2752) if name == 'mia' else self.ipad.expected_size(name)
                file = f'{index}.png'
                Image.new('RGB', size).save(attachments / file)
                entries.append({'suggestedHumanReadableName': f'store-en-{name}.png', 'exportedFileName': file})
            (attachments / 'manifest.json').write_text(json.dumps([{'attachments': entries}]))
            with self.assertRaisesRegex(ValueError, 'store-en-mia: invalid native PNG dimensions'):
                self.ipad.native_inputs(Path(folder), 'en', 1900)

    def test_composition_refuses_a_stale_output_folder(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / 'old.png').write_bytes(b'x')
            with self.assertRaisesRegex(ValueError, 'empty'):
                self.ipad.compose(Path(folder), Path(folder))


if __name__ == '__main__':
    unittest.main()
