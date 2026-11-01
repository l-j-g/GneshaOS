"""Check shortcut reference rendering at the Rofi boundary."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(sys.argv.pop(1)).resolve()


class ShortcutTests(unittest.TestCase):
    def test_reference_rows_and_cancel(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            rofi = root / 'gnesha-rofi'
            rofi.write_text('#!/bin/sh\ncat > "$MENU_OUTPUT"\nexit 1\n')
            rofi.chmod(0o755)
            config = root / 'catalog.json'
            config.write_text(json.dumps({'catalog': [
                dict(key='--release Mod4+a', mode='default', category='Launch',
                     command='exec alpha', description='Open <alpha> & beta'),
                dict(key='Left', mode='resize', category='resize',
                     command='resize shrink width 10 px', description='Shrink width'),
            ]}))
            output = root / 'rows'
            result = subprocess.run(['bash', str(SCRIPT), str(config)], env={
                **os.environ, 'PATH': f'{root}:{os.environ["PATH"]}',
                'MENU_OUTPUT': str(output), 'XDG_CONFIG_HOME': str(root),
            }, capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            rows = output.read_text()
            self.assertIn('[Launch]</span> <b>Super+a</b> :: Open &lt;alpha&gt; &amp; beta (on release)', rows)
            self.assertIn('[resize]</span> <b>Left</b> :: Shrink width', rows)
            self.assertNotIn('--release', rows)
            self.assertNotIn('[default]', rows)
            self.assertEqual(sorted(p.name for p in root.iterdir()),
                             ['catalog.json', 'gnesha-rofi', 'rows'])


unittest.main()
