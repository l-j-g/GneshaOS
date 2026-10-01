import importlib.util
import re
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import fcntl

spec = importlib.util.spec_from_file_location('settings', sys.argv.pop(1))
settings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(settings)
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'home/variables.nix'
FONT_SIZES = [int(number) for number in re.findall(r'\d+', (ROOT / 'home/programs/terminals/font-sizes.nix').read_text())]


def entries(values=None):
    values = values if values is not None else settings.read_values(SOURCE)
    return settings.catalog(SOURCE, values)


class SettingsTests(unittest.TestCase):
    def test_rows_come_from_the_preference_file(self):
        rows = {entry['key']: entry for entry in entries()}
        # The description is the comment above the assignment, nothing else.
        self.assertIn('webpage zoom', rows['browserDefaultZoom']['help'])
        self.assertIn('commits', rows['gitUserEmail']['help'])
        self.assertIn('speech model', rows['dictation.speechModel']['help'])
        # Kinds are decided by the saved literal, so nothing restates them.
        self.assertEqual(rows['autoBrightness']['kind'], 'bool')
        self.assertEqual(rows['terminalFontSize']['kind'], 'int')
        self.assertEqual(rows['browserDefaultZoom']['kind'], 'float')
        self.assertEqual(rows['displayScale']['kind'], 'scale')
        self.assertEqual(rows['idleSuspendSec']['kind'], 'nullable-int')
        self.assertEqual(rows['gitUserName']['kind'], 'text')

    def test_every_preference_is_documented(self):
        self.assertEqual([entry['key'] for entry in entries() if not entry['help']], [])

    def test_unread_preferences_are_hidden(self):
        rows = entries()
        self.assertEqual(settings.visible_keys(rows, {'gapsInner'}), ['gapsInner'])
        # Reading a group counts for every preference inside it.
        self.assertEqual(settings.visible_keys(rows, {'dictation'}), [e['key'] for e in rows if e['key'].startswith('dictation.')])
        # An unreadable tree means no opinion: show everything.
        self.assertEqual(len(settings.visible_keys(rows, None)), len(rows))

    def test_this_configuration_reads_every_preference(self):
        # The real tree: nothing in the menu should be a setting nothing uses.
        rows = settings.catalog(SOURCE, settings.read_values(SOURCE))
        unused = [entry['key'] for entry in rows if entry['key'] not in settings.visible_keys(rows, settings.referenced_keys(ROOT))]
        self.assertEqual(unused, [])

    def test_edit_preserves_unrelated_text(self):
        source = SOURCE.read_text()
        changed = settings.replace_value(source, 'terminalFontFamily', 'IBM Plex Mono')
        strip_family = lambda text: re.sub(r'terminalFontFamily = [^;\n]*;', 'terminalFontFamily = <value>;', text)
        self.assertEqual(strip_family(changed), strip_family(source))
        changed = settings.replace_value(source, 'dictation.language', 'ja')
        self.assertIn('language = "ja";', changed)

    def test_nix_interpolation_is_literal(self):
        value = '${builtins.abort "unsafe"}'
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)/'values.nix'
            p.write_text(settings.replace_value(SOURCE.read_text(), 'gitUserName', value))
            self.assertEqual(settings.read_values(p)['gitUserName'], value)

    def test_refuse_ambiguous_or_expression_edits(self):
        for source in ['{ gapsInner = 1; gapsInner = 2; }', '{\n gapsInner = 1 + 2;\n}']:
            with self.assertRaises(ValueError):
                settings.replace_value(source, 'gapsInner', 5)

    def test_validation(self):
        rows = entries()
        values = settings.read_values(SOURCE) | {'terminalFontFamily': 'Terminus', 'terminalFontSize': 16}
        settings.validate(rows, values, FONT_SIZES)
        for key, value in [('idleLockSec', 1), ('idleSuspendSec', 1), ('displayScale', 'nan'),
                           ('displayScale', 'true'), ('displayScale', 0), ('gapsInner', '5'),
                           ('gapsInner', -1), ('autoBrightness', 'yes'), ('terminalFontFamily', 'monospace')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                settings.validate(rows, values | {key: value}, FONT_SIZES)

    def test_atomic_save_and_concurrent_edit_refusal(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)/'variables.nix'; p.write_text(SOURCE.read_text()); p.chmod(0o640)
            source = p.read_text()
            settings.save_value(p, source, 'terminalFontFamily', 'Departure Mono', Path(d)/'state', entries())
            self.assertEqual(settings.read_values(p)['terminalFontFamily'], 'Departure Mono')
            self.assertEqual(p.stat().st_mode & 0o777, 0o640)
            with self.assertRaises(ValueError):
                settings.save_value(p, source, 'gapsInner', 9, Path(d)/'state', entries())
            self.assertEqual(settings.read_values(p)['gapsInner'], settings.read_values(SOURCE)['gapsInner'])

    def test_activation_lock_refuses_save(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)/'variables.nix'; p.write_text(SOURCE.read_text())
            state = Path(d)/'state'; state.mkdir()
            with (state/'activation.lock').open('a') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                with self.assertRaises(ValueError):
                    settings.save_value(p, p.read_text(), 'gapsInner', 10, state, entries())
            self.assertEqual(p.read_text(), SOURCE.read_text())

    def test_cancel_and_save_menu_flows(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); (root/'home').mkdir()
            p = root/'home/variables.nix'; p.write_text(SOURCE.read_text())
            config = {'repo': d, 'stateRoot': d+'/state', 'host': 'test', 'terminals': ['ghostty']}
            # The temporary tree holds no modules, so nothing is referenced and
            # the editor would show no rows.
            show_everything = patch.object(settings, 'referenced_keys', return_value=None)
            with show_everything, patch.object(settings, 'menu', return_value=None):
                settings.run(config)
            self.assertEqual(p.read_text(), SOURCE.read_text())
            key = [entry['key'] for entry in entries()].index('gapsInner')
            first = settings.read_values(p)['gapsInner'] + 1
            second = first + 1
            with show_everything, patch.object(settings, 'menu', side_effect=[key, str(first), 2, None]):
                settings.run(config)
            self.assertEqual(p.read_text(), SOURCE.read_text())
            original_run = subprocess.run
            def command(args, **kwargs):
                if args[0] == 'notify-send':
                    return subprocess.CompletedProcess(args, 0)
                return original_run(args, **kwargs)
            with show_everything, patch.object(settings, 'menu', side_effect=[key, str(first), 0, None]), patch.object(settings.subprocess, 'run', side_effect=command), patch.object(settings, 'launch_apply') as launch:
                settings.run(config)
                launch.assert_not_called()
            self.assertEqual(settings.read_values(p)['gapsInner'], first)
            with show_everything, patch.object(settings, 'menu', side_effect=[key, str(second), 1]), patch.object(settings, 'launch_apply') as launch:
                settings.run(config)
                launch.assert_called_once_with(config)
            self.assertEqual(settings.read_values(p)['gapsInner'], second)
            before = p.read_text()
            with show_everything, patch.object(settings, 'menu', side_effect=[len(entries()), 0]), patch.object(settings, 'launch_apply') as launch:
                settings.run(config)
                launch.assert_called_once_with(config)
            self.assertEqual(p.read_text(), before)

    def test_failed_validation_keeps_original(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)/'variables.nix'; p.write_text(SOURCE.read_text())
            with self.assertRaises(ValueError):
                settings.save_value(p, p.read_text(), 'idleLockSec', 1, Path(d)/'state', entries())
            self.assertEqual(p.read_text(), SOURCE.read_text())
            self.assertEqual(list(Path(d).glob('.settings-*')), [])

    def test_font_menu_lists_searchable_families(self):
        with patch.object(settings.subprocess, 'check_output', return_value='Terminus\nIBM Plex Mono,IBM Plex Mono Medm\nTerminus\n'), patch.object(settings, 'menu', return_value=0) as menu:
            entry = next(entry for entry in entries() if entry['key'] == 'terminalFontFamily')
            value, selected = settings.choose_value(entry, 'Terminus', {})
            self.assertTrue(selected)
            self.assertEqual(value, 'IBM Plex Mono')
            self.assertEqual(menu.call_args.args[0], ['IBM Plex Mono', 'IBM Plex Mono Medm', 'Terminus'])
        with patch.object(settings.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '0\n', '')) as command:
            self.assertEqual(settings.menu(['IBM Plex Mono'], 'Font'), 0)
            self.assertIn('-i', command.call_args.args[0])
            self.assertIn('-no-custom', command.call_args.args[0])

if __name__ == '__main__':
    unittest.main()
