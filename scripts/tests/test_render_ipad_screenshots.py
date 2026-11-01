import importlib.util
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
    """The 13-inch iPad's six cards: display size, whole devices inside the card and the four widgets."""

    @classmethod
    def setUpClass(cls):
        cls.ipad = load('ipad_renderer', 'render-ipad-app-store-screenshots.py')

    def inputs(self):
        screens = ('mosaic', 'mia', 'editor', 'mango', 'teddy', 'leo-fireworks-1900')
        native = {name: (Image.new('RGBA', self.ipad.SIZE, (255, 0, 255, 255)), Path(name)) for name in screens}
        for name, points in self.ipad.WIDGET_POINTS.items():
            native[name] = (Image.new('RGBA', (points[0] * 2, points[1] * 2), (255, 0, 255, 255)), Path(name))
        return native

    def magenta(self, card, points):
        return any((lambda p: p[0] > 200 and p[1] < 60 and p[2] > 200)(card.getpixel(point)) for point in points)

    def test_every_card_has_the_display_size_and_no_alpha(self):
        self.assertEqual(len(self.ipad.CARDS), len(self.ipad.base.FILES))
        for index in range(len(self.ipad.CARDS)):
            for locale in ('en', 'ru'):
                card = self.ipad.compose_image(self.inputs(), locale, index)
                self.assertEqual((card.size, card.mode), (self.ipad.SIZE, 'RGB'))

    def test_every_device_stays_whole_inside_the_card(self):
        width, height = self.ipad.SIZE
        for index, devices in enumerate(self.ipad.CARDS):
            image = Image.new('RGBA', self.ipad.SIZE)
            for name, center_x, device_width, angle, top in devices:
                screen = self.inputs()['mia'][0]
                (left, upper), (box_width, box_height) = self.ipad.device(image, screen, center_x, device_width, angle, top)
                self.assertGreaterEqual(left, 40, f'card {index + 1} {name}')
                self.assertLessEqual(left + box_width, width - 40, f'card {index + 1} {name}')
                self.assertGreaterEqual(upper, 780, f'card {index + 1} {name} reaches into the text')
                self.assertLessEqual(upper + box_height, height - 20, f'card {index + 1} {name}')

    def test_main_screens_show_the_whole_screen_above_the_bottom_margin(self):
        width, height = self.ipad.SIZE
        for card_name in ('mosaic', 'editor', 'widgets'):
            card = self.ipad.compose_image(self.inputs(), 'en', self.ipad.base.CARDS.index(card_name))
            self.assertFalse(self.magenta(card, [(x, y) for x in range(0, width, 4) for y in range(height - 60, height)]), card_name)
            if card_name != 'widgets':  # The widget card's screen is the faux Home Screen's gradient.
                self.assertTrue(self.magenta(card, [(width // 2, self.ipad.FULL_BOTTOM - 80)]), card_name)

    def test_russian_headlines_fit_the_text_area(self):
        for index in range(len(self.ipad.CARDS)):
            self.ipad.marketing_copy(Image.new('RGBA', self.ipad.SIZE), 'ru', index)

    def test_overlong_headline_is_rejected(self):
        copy = self.ipad.base.COPY
        self.ipad.base.COPY = {'en': [('Возраст вашего\nребёнка' * 3, '')] * len(self.ipad.CARDS)}
        try:
            with self.assertRaisesRegex(ValueError, 'approved text area'):
                self.ipad.marketing_copy(Image.new('RGBA', self.ipad.SIZE), 'en', 0)
        finally:
            self.ipad.base.COPY = copy

    def test_the_widget_card_says_four_sizes(self):
        index = self.ipad.base.WIDGETS
        self.assertIn('Four', self.ipad.copy_for('en', index)[1])
        self.assertIn('Четыре', self.ipad.copy_for('ru', index)[1])
        self.assertEqual(self.ipad.copy_for('en', 0), self.ipad.base.COPY['en'][0])

    def test_widgets_sit_on_the_screen_without_overlapping(self):
        width, height = self.ipad.SIZE
        boxes = []
        for name, left, top, card_width in self.ipad.widget_layout():
            points = self.ipad.WIDGET_POINTS[name]
            box = (left, top, left + card_width, top + round(card_width * points[1] / points[0]))
            self.assertGreaterEqual(box[0], 0)
            self.assertGreaterEqual(box[1], 0)
            self.assertLessEqual(box[2], width)
            self.assertLessEqual(box[3], height)
            boxes.append((name, box))
        for index, (name, box) in enumerate(boxes):
            for other, found in boxes[index + 1:]:
                overlaps = box[0] < found[2] and found[0] < box[2] and box[1] < found[3] and found[1] < box[3]
                self.assertFalse(overlaps, f'{name} overlaps {other}')
        self.assertEqual({name for name, _ in boxes}, set(self.ipad.WIDGET_POINTS))

    def test_composition_refuses_a_stale_output_folder(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / 'old.png').write_bytes(b'x')
            with self.assertRaisesRegex(ValueError, 'empty'):
                self.ipad.compose(Path(folder), Path(folder))


if __name__ == '__main__':
    unittest.main()
