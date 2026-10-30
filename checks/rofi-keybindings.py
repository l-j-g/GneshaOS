"""Exercise the shortcut editor against real, temporary Nix files."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(sys.argv.pop(1)).resolve()


class ShortcutTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.edits = self.root / 'home/desktop/sway/keybinding-edits.nix'
        self.edits.parent.mkdir(parents=True)
        self.edits.write_text('{ keybindings = {}; modes = {}; }\n')
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        # Only the interactive boundaries are replaced; the real editor reads,
        # validates, and saves the real Nix file.
        self.stub('gnesha-rofi', '''import os, pathlib, sys
p = pathlib.Path(os.environ['FIXTURE'])
with (p / 'menus').open('ab') as log:
    log.write(sys.stdin.buffer.read() + b'\\n---\\n')
queue = (p / 'queue').read_text().splitlines()
if not queue:
    sys.exit(1)
answer = queue.pop(0)
(p / 'queue').write_text('\\n'.join(queue) + ('\\n' if queue else ''))
if answer == 'cancel':
    sys.exit(1)
print(answer)
''')
        self.stub('capture-key', '''import os, pathlib, sys
p = pathlib.Path(os.environ['FIXTURE'])
if (p / 'concurrent').exists():
    (p / 'home/desktop/sway/keybinding-edits.nix').write_text('{ keybindings = {}; modes = {}; } # external edit\\n')
key = (p / 'key').read_text()
if not key:
    sys.exit(1)
print(key)
''')
        self.catalog = [
            dict(key='--release Mod4+a', sourceKey='--release Mod4+a', mode='default', command='exec alpha', description='Launch alpha'),
            dict(key='Mod4+b', sourceKey='Mod4+b', mode='default', command='exec beta', description='Launch beta'),
            dict(key='Left', sourceKey='Left', mode='resize', command='resize shrink width 10 px', description='Shrink width'),
        ]
        self.config = self.root / 'config.json'
        self.config.write_text(json.dumps(dict(
            repo=str(self.root), catalog=self.catalog,
            capture=str(self.bin / 'capture-key'), stateRoot=str(self.root / 'state'))))

    def stub(self, name, code):
        target = self.bin / name
        target.write_text(f'#!{sys.executable}\n' + code)
        target.chmod(0o755)

    def run_menu(self, key='Mod4+x', queue=('0', '0')):
        (self.root / 'queue').write_text('\n'.join(queue) + '\n')
        (self.root / 'key').write_text(key)
        result = subprocess.run(['bash', str(SCRIPT), str(self.config)], env={
            **os.environ, 'PATH': f'{self.bin}:{os.environ["PATH"]}',
            'FIXTURE': str(self.root)}, capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        return (self.root / 'menus').read_bytes()

    def values(self):
        return json.loads(subprocess.check_output([
            'nix-instantiate', '--eval', '--strict', '--json', str(self.edits)]))

    def test_save_preserves_release_flag_and_other_bindings(self):
        self.run_menu()
        self.assertEqual(self.values(), {'keybindings': {'--release Mod4+a': '--release Mod4+x'}, 'modes': {}})

    def test_cancel_never_writes(self):
        before = self.edits.read_bytes()
        self.run_menu(queue=('0', 'cancel'))
        self.assertEqual(self.edits.read_bytes(), before)

    def test_capture_cancel_never_writes(self):
        before = self.edits.read_bytes()
        self.run_menu(key='', queue=('0', 'cancel'))
        self.assertEqual(self.edits.read_bytes(), before)

    def test_conflicting_chord_is_rejected_even_with_different_flags(self):
        before = self.edits.read_bytes()
        self.run_menu(key='Mod4+b', queue=('0', 'cancel'))
        self.assertEqual(self.edits.read_bytes(), before)

    def test_invalid_capture_cannot_write_nix_code(self):
        before = self.edits.read_bytes()
        self.run_menu(key='${builtins.abort "injected"}', queue=('0', 'cancel'))
        self.assertEqual(self.edits.read_bytes(), before)

    def test_symlink_cannot_replace_another_file(self):
        other = self.root / 'other.nix'
        self.edits.rename(other)
        self.edits.symlink_to(other)
        before = other.read_bytes()
        self.run_menu()
        self.assertTrue(self.edits.is_symlink())
        self.assertEqual(other.read_bytes(), before)

    def test_recording_original_chord_removes_the_pending_edit(self):
        self.run_menu()
        self.run_menu(key='Mod4+a')
        self.assertEqual(self.values()['keybindings'], {})

    def test_pending_edits_are_visible_and_editable_again(self):
        self.run_menu()
        output = self.run_menu(key='Mod4+y')
        self.assertIn(b'Super+x', output)
        self.assertEqual(self.values()['keybindings'], {'--release Mod4+a': '--release Mod4+y'})

    def test_mode_edits_do_not_change_default_bindings(self):
        self.run_menu(key='h', queue=('2', '0'))
        self.assertEqual(self.values(), {'keybindings': {}, 'modes': {'resize': {'Left': 'h'}}})

    def test_concurrent_changes_are_preserved(self):
        (self.root / 'concurrent').touch()
        self.run_menu()
        self.assertIn('# external edit', self.edits.read_text())

    def test_activation_lock_prevents_save(self):
        state = self.root / 'state'
        state.mkdir()
        with (state / 'activation.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.run_menu()
        self.assertEqual(self.values()['keybindings'], {})

    def test_display_hides_default_mode_and_sway_flags(self):
        output = self.run_menu(queue=('cancel',))
        self.assertNotIn(b'[default]', output)
        self.assertNotIn(b'--release', output)
        self.assertIn(b'[resize]', output)


unittest.main()
