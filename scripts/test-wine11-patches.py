#!/usr/bin/env python3
"""Exercise hash/order checks and real patch application without a Wine build."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class PatchApplicationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='mgu-patch-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'scripts').mkdir()
        (self.root / 'runtime/indie-wine11').mkdir(parents=True)
        (self.root / 'patches/wine11').mkdir(parents=True)
        self.source = self.root / 'source'
        self.source.mkdir()
        (self.source / 'configure').touch()
        (self.source / 'value.txt').write_text('before\n')
        self.script = self.root / 'scripts/apply-wine11-patches.py'
        shutil.copyfile(Path(__file__).with_name('apply-wine11-patches.py'), self.script)
        self.patch = self.root / 'patches/wine11/0001.patch'
        self.patch.write_text('--- a/value.txt\n+++ b/value.txt\n@@ -1 +1 @@\n-before\n+after\n')
        self.lock = {'indiePatches': ['0001.patch'],
                     'indiePatchSHA256': {'0001.patch': hashlib.sha256(self.patch.read_bytes()).hexdigest()}}

    def run_apply(self):
        (self.root / 'runtime/indie-wine11/source.lock.json').write_text(json.dumps(self.lock))
        return subprocess.run([sys.executable, str(self.script), str(self.source)],
                              capture_output=True, text=True)

    def assert_rejected_before_mutation(self):
        result = self.run_apply()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual((self.source / 'value.txt').read_text(), 'before\n')

    def test_real_application_and_reapplication_rejected(self):
        result = self.run_apply()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.source / 'value.txt').read_text(), 'after\n')
        self.assertNotEqual(self.run_apply().returncode, 0)

    def test_changed_hash(self):
        self.patch.write_text(self.patch.read_text() + '\n')
        self.assert_rejected_before_mutation()

    def test_unlisted_patch(self):
        self.patch.with_name('0002.patch').write_text('unreviewed')
        self.assert_rejected_before_mutation()

    def test_missing_hash(self):
        self.lock['indiePatchSHA256'] = {}
        self.assert_rejected_before_mutation()

    def test_duplicate(self):
        self.lock['indiePatches'].append('0001.patch')
        self.assert_rejected_before_mutation()

    def test_path_traversal(self):
        self.lock['indiePatches'] = ['../0001.patch']
        self.assert_rejected_before_mutation()

    def test_order_is_manifest_order(self):
        second = self.patch.with_name('0002.patch')
        second.write_text('--- a/value.txt\n+++ b/value.txt\n@@ -1 +1 @@\n-after\n+final\n')
        self.lock['indiePatches'].append(second.name)
        self.lock['indiePatchSHA256'][second.name] = hashlib.sha256(second.read_bytes()).hexdigest()
        result = self.run_apply()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.source / 'value.txt').read_text(), 'final\n')


if __name__ == '__main__':
    unittest.main()
