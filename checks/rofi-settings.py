"""Exercise real script-mode callbacks against temporary Nix preferences."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = Path(sys.argv.pop(1)).resolve()


class SettingsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'home').mkdir()
        self.path = self.root / 'home/variables.nix'
        self.source = (ROOT / 'home/variables.nix').read_text()
        self.path.write_text(self.source)
        self.path.chmod(0o640)
        # Reference a whole group as well as individual keys.
        (self.root / 'home/default.nix').write_text(
            'variables.dictation variables.gapsInner variables.autoBrightness '
            'variables.gitUserName variables.idleLockSec variables.idleSuspendSec variables.browserDefaultZoom '
            'variables.displayScale variables.terminalFontFamily variables.terminalFontSize')
        self.config = self.root / 'config.json'
        self.config.write_text(json.dumps({
            'repo': str(self.root), 'host': 'test', 'stateRoot': str(self.root / 'state'),
            'validator': str(ROOT / 'home/desktop/rofi/settings-validate.nix'),
            'fontSizes': [12, 14, 16, 18, 20, 22, 24, 28, 32],
            'terminals': ['ghostty'], 'themeNames': str(self.root / 'themes'),
            'terminal': 'false', 'fish': 'false',
        }))

    def call(self, previous=None, info=None, custom=None):
        env = os.environ.copy()
        for name in ('ROFI_RETV', 'ROFI_DATA', 'ROFI_INFO'):
            env.pop(name, None)
        env['ROFI_RETV'] = '0' if previous is None else '2' if custom is not None else '1'
        if previous:
            env['ROFI_DATA'] = previous[0]['data']
        if info is not None:
            env['ROFI_INFO'] = info
        result = subprocess.run(['bash', str(SCRIPT), str(self.config)] + ([] if custom is None else [custom]),
                                env=env, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        headers, rows = {}, []
        for line in result.stdout.decode().split('\n'):
            if line.startswith('\0'):
                name, value = line[1:].split('\x1f', 1)
                headers[name] = value
            elif line:
                label, _, options = line.partition('\0')
                fields = options.split('\x1f')
                rows.append((label, dict(zip(fields[::2], fields[1::2]))))
        return headers, rows

    def select(self, menu, action):
        for _, options in menu[1]:
            if options.get('info') == action:
                return self.call(menu, action)
        self.fail(f'No action {action!r} in {menu}')

    def edit(self, key, value):
        menu = self.select(self.call(), key)
        return self.call(menu, custom=value)

    def values(self):
        return json.loads(subprocess.check_output(['nix-instantiate', '--eval', '--strict', '--json', str(self.path)]))

    def test_documented_nested_rows_and_unused_filter(self):
        menu = self.call()
        names = [options.get('info') for _, options in menu[1]]
        self.assertIn('dictation.language', names)
        self.assertNotIn('screenshotDir', names)
        label = next(label for label, opts in menu[1] if opts.get('info') == 'dictation.language')
        self.assertIn('Language code', label)
        self.assertIn('<b>', label)

    def test_save_only_preserves_comments_and_mode(self):
        confirmation = self.edit('gapsInner', '17')
        self.assertEqual(self.path.read_text(), self.source)
        self.select(confirmation, 'save')
        self.assertEqual(self.path.read_text(), self.source.replace('gapsInner = 5;', 'gapsInner = 17;'))
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o640)
        self.assertEqual(list(self.path.parent.glob('.settings-*')), [])

    def test_cancel_does_not_write(self):
        self.select(self.edit('gapsInner', '17'), 'back')
        self.assertEqual(self.path.read_text(), self.source)

    def test_nested_string_and_interpolation_round_trip(self):
        for key, value in [('dictation.language', 'ja'), ('gitUserName', '${builtins.abort "unsafe"} \\ <&>')]:
            self.select(self.edit(key, value), 'save')
        self.assertEqual(self.values()['dictation']['language'], 'ja')
        self.assertEqual(self.values()['gitUserName'], '${builtins.abort "unsafe"} \\ <&>')

    def test_boolean_and_nullable_callbacks(self):
        menu = self.select(self.call(), 'autoBrightness')
        confirmation = self.select(menu, 'false')
        self.select(confirmation, 'save')
        self.assertFalse(self.values()['autoBrightness'])
        self.select(self.edit('idleSuspendSec', '1900'), 'save')
        self.assertEqual(self.values()['idleSuspendSec'], 1900)
        self.select(self.edit('idleSuspendSec', 'disabled'), 'save')
        self.assertIsNone(self.values()['idleSuspendSec'])

    def test_invalid_values_never_write(self):
        for key, value in [('gapsInner', '-1'), ('gapsInner', '1.5'), ('idleLockSec', '1'),
                           ('idleSuspendSec', '1'), ('displayScale', 'nan'), ('displayScale', '0'),
                           ('gitUserName', ''), ('gitUserName', 'bad\nline'), ('terminalFontSize', '0')]:
            with self.subTest(key=key, value=value):
                menu = self.edit(key, value)
                if any(opts.get('info') == 'save' for _, opts in menu[1]):
                    menu = self.select(menu, 'save')
                self.assertTrue(menu[0].get('message'))
                self.assertEqual(self.path.read_text(), self.source)

    def test_concurrent_edit_refused(self):
        menu = self.edit('gapsInner', '17')
        changed = self.source + '\n# another editor\n'
        self.path.write_text(changed)
        result = self.select(menu, 'save')
        self.assertIn('changed', result[0]['message'])
        self.assertEqual(self.path.read_text(), changed)

    def test_lock_refuses_save(self):
        menu = self.edit('gapsInner', '17')
        state = self.root / 'state'
        state.mkdir(exist_ok=True)
        with (state / 'activation.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.select(menu, 'save')
        self.assertIn('rebuild', result[0]['message'])
        self.assertEqual(self.path.read_text(), self.source)

    def test_symlink_and_expression_refused(self):
        menu = self.edit('gapsInner', '17')
        target = self.root / 'target.nix'
        self.path.rename(target)
        self.path.symlink_to(target)
        self.select(menu, 'save')
        self.assertEqual(target.read_text(), self.source)
        self.path.unlink()
        self.path.write_text(self.source.replace('gapsInner = 5;', 'gapsInner = 2 + 3;'))
        self.select(self.edit('gapsInner', '17'), 'save')
        self.assertIn('gapsInner = 2 + 3;', self.path.read_text())

    def test_host_override_refuses_edit(self):
        host = self.root / 'hosts/test'
        host.mkdir(parents=True)
        (host / 'home-variables.nix').write_text('{ gapsInner = 12; }')
        result = self.select(self.call(), 'gapsInner')
        self.assertIn('overridden', result[0]['message'])
        self.assertEqual(self.path.read_text(), self.source)

    def test_apply_and_save_apply_launch_terminal_then_close(self):
        terminal = self.root / 'terminal'
        log = self.root / 'terminal-args'
        terminal.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$@" > "' + str(log) + '"\n')
        terminal.chmod(0o700)
        config = json.loads(self.config.read_text())
        config.update(terminal=str(terminal), fish='/test/fish')
        self.config.write_text(json.dumps(config))
        for action in ('save-apply', 'apply-now'):
            if action == 'save-apply':
                menu = self.edit('gapsInner', '17')
            else:
                log.unlink()
                menu = self.select(self.call(), 'apply')
            result = self.select(menu, action)
            self.assertEqual(result, ({}, []))
            for _ in range(100):
                if log.exists() and log.read_text():
                    break
                time.sleep(0.01)
            args = log.read_text()
            self.assertIn('/test/fish', args)
            self.assertIn('home-rebuild;', args)
        self.assertEqual(self.values()['gapsInner'], 17)

    def test_whole_zoom_keeps_accepting_fractional_values(self):
        self.select(self.edit('browserDefaultZoom', '1'), 'save')
        self.assertEqual(self.values()['browserDefaultZoom'], 1)
        self.select(self.edit('browserDefaultZoom', '1.25'), 'save')
        self.assertEqual(self.values()['browserDefaultZoom'], 1.25)

    def test_valid_scale_and_rejected_font_alias(self):
        self.select(self.edit('displayScale', '1.5'), 'save')
        self.assertEqual(self.values()['displayScale'], '1.5')
        self.select(self.edit('terminalFontFamily', 'monospace'), 'save')
        self.assertEqual(self.values()['terminalFontFamily'], 'IBM Plex Mono')

    def test_ambiguous_leaf_and_host_override_added_during_edit(self):
        self.path.write_text(self.source.replace('gapsInner = 5;', 'gapsInner = 5;\n  duplicate = { gapsInner = 7; };'))
        original = self.path.read_text()
        self.select(self.edit('gapsInner', '17'), 'save')
        self.assertEqual(self.path.read_text(), original)
        self.path.write_text(self.source)
        menu = self.edit('gapsInner', '17')
        host = self.root / 'hosts/test'
        host.mkdir(parents=True)
        (host / 'home-variables.nix').write_text('{ gapsInner = 12; }')
        self.select(menu, 'save')
        self.assertEqual(self.path.read_text(), self.source)

    def test_apply_requires_confirmation_and_cancel_is_safe(self):
        menu = self.select(self.call(), 'apply')
        self.assertIn('pending', menu[0]['message'])
        self.select(menu, 'back')
        self.assertEqual(self.path.read_text(), self.source)


if __name__ == '__main__':
    unittest.main()
