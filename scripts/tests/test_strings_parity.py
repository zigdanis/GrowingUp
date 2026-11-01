"""Every English string table has a Russian twin with the same keys, so no screen falls back to English."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', re.MULTILINE)
TABLES = sorted(p for p in ROOT.glob("*/**/en.lproj/*.strings") if ".git" not in p.parts)


def entries(path):
    text = re.sub(r"/\*.*?\*/", "", path.read_text(encoding="utf-8"), flags=re.DOTALL)
    return dict(ENTRY.findall(text))


class StringsParityTests(unittest.TestCase):
    def test_tables_exist(self):
        self.assertGreaterEqual(len(TABLES), 6)

    def test_russian_tables_have_the_english_keys(self):
        for english in TABLES:
            russian = english.parent.parent / "ru.lproj" / english.name
            with self.subTest(table=str(english.relative_to(ROOT))):
                self.assertTrue(russian.exists())
                en, ru = entries(english), entries(russian)
                self.assertEqual(sorted(set(en) - set(ru)), [], "missing in ru")
                self.assertEqual(sorted(set(ru) - set(en)), [], "missing in en")


if __name__ == "__main__":
    unittest.main()
