"""Intake Center I1 — input collector (all supported inputs + zip + watch + URL stub)."""
import shutil
import tempfile
import unittest
import zipfile
from pathlib import Path

from kie.intake import collector
from kie.intake.collector import UrlImportNotImplemented


def _pdf(path: Path, text: str = "hello") -> Path:
    import fitz
    doc = fitz.open()
    doc.new_page().insert_text((72, 72), text)
    path.parent.mkdir(parents=True, exist_ok=True)
    doc.save(str(path))
    doc.close()
    return path


class TestCollector(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_single_and_multiple(self):
        a = _pdf(self.tmp / "a.pdf", "alpha")
        b = _pdf(self.tmp / "b.pdf", "beta")
        one = collector.collect_paths([a])
        self.assertEqual(len(one), 1)
        self.assertEqual(one[0].original_name, "a.pdf")
        many = collector.collect_paths([a, b])
        self.assertEqual([s.original_name for s in many], ["a.pdf", "b.pdf"])

    def test_folder_import_recursive(self):
        _pdf(self.tmp / "docs" / "x.pdf")
        _pdf(self.tmp / "docs" / "sub" / "y.pdf")
        (self.tmp / "docs" / "notes.txt").write_text("ignore me")  # unsupported → skipped
        srcs = collector.collect_paths([self.tmp / "docs"])
        names = sorted(s.original_name for s in srcs)
        self.assertEqual(names, ["x.pdf", "y.pdf"])
        # category defaults to the folder name
        self.assertTrue(all(s.category == "docs" for s in srcs))

    def test_zip_import_expands_members(self):
        _pdf(self.tmp / "m1.pdf", "one")
        _pdf(self.tmp / "m2.pdf", "two")
        zpath = self.tmp / "bundle.zip"
        with zipfile.ZipFile(zpath, "w") as zf:
            zf.write(self.tmp / "m1.pdf", "m1.pdf")
            zf.write(self.tmp / "m2.pdf", "folder/m2.pdf")
        srcs = collector.collect_paths([zpath], _scratch=self.tmp / "scratch")
        self.assertEqual(sorted(s.original_name for s in srcs), ["m1.pdf", "m2.pdf"])

    def test_zip_slip_blocked(self):
        zpath = self.tmp / "evil.zip"
        with zipfile.ZipFile(zpath, "w") as zf:
            zf.writestr("../escape.pdf", b"%PDF-1.4\n")
        members = collector.expand_zip(zpath, self.tmp / "out")
        self.assertFalse((self.tmp / "escape.pdf").exists())
        self.assertEqual(members, [])

    def test_drag_drop_mixed_files_and_folders_dedup(self):
        a = _pdf(self.tmp / "a.pdf", "alpha")
        _pdf(self.tmp / "folder" / "c.pdf")
        # 'a' appears both directly and (not) in folder → dedup by resolved path
        srcs = collector.collect_paths([a, self.tmp / "folder", a])
        names = sorted(s.original_name for s in srcs)
        self.assertEqual(names, ["a.pdf", "c.pdf"])

    def test_watch_folder_new_and_changed(self):
        f = self.tmp / "watch"
        _pdf(f / "keep.pdf", "keep")
        p2 = _pdf(f / "change.pdf", "v1")
        srcs, index = collector.scan_watch_folder({}, f)
        self.assertEqual(sorted(s.original_name for s in srcs), ["change.pdf", "keep.pdf"])
        # Second scan with the prior index: nothing new.
        srcs2, index2 = collector.scan_watch_folder(index, f)
        self.assertEqual(srcs2, [])
        # Modify one file → only it is re-emitted.
        _pdf(p2, "v2 completely different content here to change the hash")
        srcs3, _ = collector.scan_watch_folder(index2, f)
        self.assertEqual([s.original_name for s in srcs3], ["change.pdf"])

    def test_url_import_is_placeholder(self):
        with self.assertRaises(UrlImportNotImplemented):
            collector.url_import("https://example.com/x.pdf")


if __name__ == "__main__":
    unittest.main()
