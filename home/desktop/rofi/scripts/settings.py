#!/usr/bin/env python3
"""Rofi editor for literal preferences in home/variables.nix.

Rows come from the preference file itself: the key gives the label, the comment
above the assignment is the description, and the saved value decides how a new
one is asked for. A preference nothing reads is hidden, because editing it would
change nothing.
"""
import fcntl
import html
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

COMMENT = re.compile(r'^\s*#\s?(.*)$')
ASSIGNMENT = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?);\s*$')
REFERENCE = re.compile(r'\bvariables\.((?:[A-Za-z_][A-Za-z0-9_]*\.)*[A-Za-z_][A-Za-z0-9_]*)')


def read_values(path):
    result = subprocess.run(['nix-instantiate', '--eval', '--strict', '--json', str(path)], capture_output=True, text=True)
    if result.returncode:
        raise ValueError('Could not evaluate preferences: ' + result.stderr.strip())
    return json.loads(result.stdout)


def get_value(values, key):
    for part in key.split('.'):
        values = values[part]
    return values


def flatten(values, prefix=''):
    keys = []
    for name, value in values.items():
        key = prefix + name
        keys.extend(flatten(value, key + '.') if isinstance(value, dict) else [key])
    return keys


def documented(source):
    """Map each preference to the comment block written directly above it.

    The comment is the description, so a preference is documented in exactly one
    place: the file that stores it.
    """
    docs, pending = {}, []
    for line in source.splitlines():
        comment = COMMENT.match(line)
        if comment:
            pending.append(comment.group(1).strip())
        elif assignment := ASSIGNMENT.match(line):
            docs[assignment.group(1)] = ' '.join(pending).strip()
            pending = []
        elif line.strip():
            pending = []
    return docs


def referenced_keys(repo):
    """Preferences some module still reads, or None if the tree is unreadable."""
    try:
        root = Path(repo)
        preferences = root / 'home/variables.nix'
        used = set()
        for path in root.rglob('*.nix'):
            if path == preferences or '.git' in path.parts:
                continue
            used.update(REFERENCE.findall(path.read_text()))
        return used
    except OSError:
        return None


def kind_of(value):
    """How to ask for a new value, decided by the saved one."""
    if isinstance(value, bool):
        return 'bool'
    if value is None:
        return 'nullable-int'
    if isinstance(value, int):
        return 'int'
    if isinstance(value, float):
        return 'float'
    if isinstance(value, str):
        try:
            float(value)
        except ValueError:
            return 'text'
        # A quoted number is a scale factor, kept as text so "1.5" survives a save.
        return 'scale'
    return 'text'


def catalog(path, values):
    """Preference rows in file order, with their help text and input kinds."""
    docs = documented(path.read_text())
    return [{
        'key': key,
        'help': docs.get(key.split('.')[-1], ''),
        'kind': kind_of(get_value(values, key)),
    } for key in flatten(values)]


def visible_keys(entries, used=None):
    """Rows whose value a module still reads. All of them when `used` is None.

    A module that reads a whole group, such as `variables.dictation`, counts for
    every preference inside it.
    """
    if used is None:
        return [entry['key'] for entry in entries]
    def read(key):
        parts = key.split('.')
        return any('.'.join(parts[:depth]) in used for depth in range(len(parts), 0, -1))
    return [entry['key'] for entry in entries if read(entry['key'])]


def encode(value):
    if isinstance(value, str):
        if not all(c.isprintable() for c in value):
            raise ValueError('Use a single line without control characters.')
        return json.dumps(value, ensure_ascii=False).replace('${', r'\${')
    return json.dumps(value, allow_nan=False)


def replace_value(source, key, value):
    leaf = key.split('.')[-1]
    # Deliberately support only a unique, one-line literal assignment. Refuse
    # expressions or ambiguous keys instead of trying to rewrite arbitrary Nix.
    literal = r'"(?:\\.|[^"\\\n])*"|true|false|null|-?\d+(?:\.\d+)?'
    pattern = re.compile(r'^(\s*' + re.escape(leaf) + r'\s*=\s*)(' + literal + r')(\s*;[^\n]*)$', re.M)
    matches = list(pattern.finditer(source))
    declarations = re.findall(r'\b' + re.escape(leaf) + r'\s*=', source)
    if len(matches) != 1 or len(declarations) != 1:
        raise ValueError(f'{key} must have one simple literal assignment; edit it manually.')
    match = matches[0]
    return source[:match.start(2)] + encode(value) + source[match.end(2):]


def check_value(entry, value):
    """One saved value against the kind its own literal implies."""
    key, kind = entry['key'], entry['kind']
    if kind == 'bool':
        if type(value) is not bool:
            raise ValueError(f'{key} must be on or off.')
    elif kind in ('int', 'nullable-int'):
        if value is None:
            if kind != 'nullable-int':
                raise ValueError(f'{key} must not be empty.')
        elif type(value) is not int:
            raise ValueError(f'{key} must be a whole number.')
        elif value < 0:
            raise ValueError(f'{key} cannot be negative.')
    elif kind in ('float', 'scale'):
        try:
            number = float(value)
        except (TypeError, ValueError):
            raise ValueError(f'{key} must be a number.') from None
        if number != number or number in (float('inf'), float('-inf')):
            raise ValueError(f'{key} must be a finite number.')
        if number <= 0:
            raise ValueError(f'{key} must be greater than zero.')
    elif not isinstance(value, str) or not value or not all(c.isprintable() for c in value):
        raise ValueError(f'{key} must be nonempty, single-line text.')


def validate(entries, values, font_sizes=()):
    for entry in entries:
        check_value(entry, get_value(values, entry['key']))
    if not values['idleDimSec'] < values['idleLockSec'] < values['idleOffSec']:
        raise ValueError('Idle times must increase: dim < lock < screen off.')
    if values['idleSuspendSec'] is not None and values['idleSuspendSec'] <= values['idleOffSec']:
        raise ValueError('Suspend must be later than screen off, or disabled.')
    if values['terminalFontFamily'] in ('monospace', 'sans-serif', 'serif'):
        raise ValueError('Select a real font family; Fontconfig supplies the monospace alias.')
    if font_sizes and values['terminalFontFamily'] == 'Terminus' and values['terminalFontSize'] not in font_sizes:
        raise ValueError('Terminus needs one of these sizes: ' + ', '.join(map(str, font_sizes)))


def save_value(path, original, key, value, state_root, entries, font_sizes=()):
    state_root.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (state_root/'activation.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('A rebuild or activation is running. Save after it finishes.') from None
        if path.is_symlink() or path.read_text() != original:
            raise ValueError('Preferences changed while the menu was open. Reopen the setting.')
        updated = replace_value(original, key, value)
        fd, name = tempfile.mkstemp(prefix='.settings-', suffix='.nix', dir=path.parent)
        candidate = Path(name)
        try:
            with os.fdopen(fd, 'w') as stream:
                stream.write(updated)
            candidate.chmod(path.stat().st_mode & 0o777)
            evaluated = read_values(candidate)
            validate(entries, evaluated, font_sizes)
            if get_value(evaluated, key) != value:
                raise ValueError('The edited assignment did not change the expected preference.')
            if path.read_text() != original:
                raise ValueError('Preferences changed during validation. Nothing was saved.')
            os.replace(candidate, path)
        finally:
            candidate.unlink(missing_ok=True)


def menu(rows, prompt, message='', custom=False, initial=''):
    args = ['gnesha-rofi', '-dmenu', '-i', '-p', prompt, '-mesg', html.escape(message), '-lines', '12', '-theme-str', 'window { width: 85%; }']
    if custom:
        args += ['-filter', initial]
    else:
        args += ['-no-custom', '-format', 'i']
    result = subprocess.run(args, input='\n'.join(rows), text=True, capture_output=True)
    if result.returncode == 1:
        return None
    if result.returncode:
        raise ValueError('Rofi failed: ' + result.stderr.strip())
    result_text = result.stdout.rstrip('\n')
    if custom:
        return result_text
    try:
        index = int(result_text)
        if 0 <= index < len(rows):
            return index
    except ValueError:
        pass
    raise ValueError('Rofi returned an invalid selection.')


# Preferences with a menu instead of a prompt, because the candidates come from
# somewhere the editor can read: the installed font families, the generated theme
# catalog, and the terminals this configuration actually enables.
MENUS = {
    'terminalFontFamily': 'fonts',
    'themeName': 'themeNames',
    'terminal': 'terminals',
}


def candidate_rows(entry, config):
    offered = MENUS.get(entry['key'])
    if offered == 'fonts':
        output = subprocess.check_output(['fc-list', '-f', '%{family}\n'], text=True)
        return sorted({s.strip() for line in output.splitlines() for s in line.split(',') if s.strip()}, key=str.casefold)
    if offered == 'themeNames':
        return Path(config['themeNames']).read_text().splitlines()
    if offered == 'terminals':
        return list(config['terminals'])
    if entry['kind'] == 'bool':
        return ['On', 'Off']
    return []


def choose_value(entry, current, config):
    label, kind = entry['key'], entry['kind']
    rows = candidate_rows(entry, config)
    if rows:
        index = menu(rows, label, entry['help'] + f' • Saved: {current}')
        if index is None:
            return None, False
        return ((index == 0) if kind == 'bool' else rows[index]), True
    raw = menu([], label, entry['help'], custom=True, initial='disabled' if current is None else str(current))
    if raw is None:
        return None, False
    if kind == 'nullable-int' and raw.strip().lower() in ('disabled', 'null', 'off'):
        return None, True
    try:
        value = int(raw) if kind in ('int', 'nullable-int') else float(raw) if kind in ('float', 'scale') else raw
    except ValueError:
        raise ValueError('Enter a valid number.') from None
    return value, True


def launch_apply(config):
    command = "home-rebuild; set -l result $status; read -P 'Press Enter to close… '; exit $result"
    subprocess.Popen([config['terminal'], '-e', config['fish'], '--interactive', '--command', command])


def run(config):
    path = Path(config['repo'])/'home/variables.nix'
    state_root = Path(config['stateRoot'])
    font_sizes = config.get('fontSizes', [])
    while True:
        original = path.read_text()
        values = read_values(path)
        entries = catalog(path, values)
        by_key = {entry['key']: entry for entry in entries}
        keys = visible_keys(entries, referenced_keys(config['repo']))
        rows = [f'{by_key[k]["key"]}  [{get_value(values, k)}] — {by_key[k]["help"]} ({k})' for k in keys]
        rows.append('Apply saved settings — Build and activate Home Manager')
        index = menu(rows, 'Settings', 'Search by name or description • Values shown are saved preferences')
        if index is None:
            return
        if index == len(keys):
            action = menu(['Apply', 'Cancel'], 'Apply saved settings',
                          'Builds and activates all saved Home Manager changes, including other pending edits.')
            if action == 0:
                launch_apply(config)
                return
            continue
        key = keys[index]
        try:
            override = Path(config['repo'])/'hosts'/config['host']/'home-variables.nix'
            if override.exists():
                try:
                    get_value(read_values(override), key)
                except KeyError:
                    pass
                else:
                    raise ValueError(f'This preference is overridden in {override}; edit that file instead.')
            value, selected = choose_value(by_key[key], get_value(values, key), config)
            if not selected or value == get_value(values, key):
                continue
            action = menu(['Save only', 'Save and apply', 'Cancel'], 'Save setting',
                          f'{by_key[key]["key"]}: {get_value(values, key)} → {value}\nApply rebuilds the saved Home Manager configuration, including other pending edits.')
            if action is None or action == 2:
                continue
            save_value(path, original, key, value, state_root, entries, font_sizes)
            if action == 1:
                launch_apply(config)
                return
            subprocess.run(['notify-send', 'Setting saved', by_key[key]['key'] + ' — apply with home-rebuild when ready'], check=False)
        except (ValueError, OSError, subprocess.SubprocessError) as error:
            subprocess.run(['gnesha-rofi', '-e', html.escape(str(error))], check=False)


if __name__ == '__main__':
    try:
        run(json.loads(Path(sys.argv[1]).read_text()))
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        subprocess.run(['gnesha-rofi', '-e', html.escape(str(error))], check=False)
        sys.exit(1)
