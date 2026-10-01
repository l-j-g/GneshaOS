#!/usr/bin/env python3
"""Rofi editor for literal preferences in home/variables.nix."""
import fcntl
import json
import html
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

# key: (label, short help, input kind). Saved values always come from Nix.
FIELDS = {
    'terminalFontFamily': ('Monospace font', 'Fontconfig family for terminals and desktop text', 'font'),
    'terminalFontSize': ('Font size', 'Points; Terminus supports 12,14,16,18,20,22,24,28,32', 'int'),
    'stackedViewFontSize': ('Window title size', 'Font size in points for stacked and tabbed titles', 'int'),
    'themeName': ('Theme', 'Base16 colour scheme', 'theme'),
    'displayScale': ('Display scale', 'Scale factor, for example 1, 1.25, 1.5 or 2', 'scale'),
    'browserDefaultZoom': ('Browser zoom', 'Webpage zoom factor from 0.3 to 5.0, for example 1.5', 'float'),
    'gapsInner': ('Inner gaps', 'Pixels between windows; zero removes gaps', 'int'),
    'gapsOuter': ('Outer gaps', 'Pixels around workspaces; zero removes gaps', 'int'),
    'autotilingEnabled': ('Automatic tiling', 'Auto-orient new windows to their shape', 'bool'),
    'autoBrightness': ('Automatic brightness', 'Let wluma learn brightness from ambient light', 'bool'),
    'idleDimSec': ('Dim after', 'Idle seconds before dimming; must precede locking', 'int'),
    'idleLockSec': ('Lock after', 'Idle seconds before locking; between dim and screen off', 'int'),
    'idleOffSec': ('Screen off after', 'Idle seconds before powering displays off', 'int'),
    'idleSuspendSec': ('Suspend after', 'Idle seconds after screen off, or disabled', 'nullable-int'),
    'idleDimPercent': ('Dim brightness', 'Brightness level from 0 to 100 percent', 'int'),
    'lidCloseSuspendOnBattery': ('Suspend on lid close', 'Suspend on battery when the lid closes', 'bool'),
    'terminal': ('Terminal', 'Default terminal application', 'terminal'),
    'screenshotDir': ('Screenshot folder', 'Absolute path for screenshots', 'path'),
    'screenshotUploadUrl': ('Screenshot upload URL', 'Anonymous image upload service URL', 'text'),
    'gitUserName': ('Git name', 'Author name for commits', 'text'),
    'gitUserEmail': ('Git email', 'Author email for commits', 'text'),
    'publicKeyFile': ('Public key file', 'Absolute path to your public PGP key', 'path'),
    'dictation.speechModel': ('Dictation speech model', 'Installed Voxtype speech model name', 'text'),
    'dictation.language': ('Dictation language', 'Speech language code, for example en or ja', 'text'),
    'dictation.cleanupModel': ('Dictation cleanup model', 'Cleanup model name; does not install models', 'text'),
    'hermesMacTunnelEnable': ('Hermes tunnel', 'Enable the SSH tunnel and its launcher', 'bool'),
    'hermesSshHost': ('Hermes SSH host', 'Trusted SSH host alias', 'text'),
    'hermesLocalPort': ('Hermes local port', 'Local listening port, 1–65535', 'int'),
    'hermesRemotePort': ('Hermes remote port', 'Remote service port, 1–65535', 'int'),
}
NATIVE_SIZES = [12, 14, 16, 18, 20, 22, 24, 28, 32]


def read_values(path):
    result = subprocess.run(['nix-instantiate', '--eval', '--strict', '--json', str(path)], capture_output=True, text=True)
    if result.returncode:
        raise ValueError('Could not evaluate preferences: ' + result.stderr.strip())
    return json.loads(result.stdout)


def get_value(values, key):
    for part in key.split('.'):
        values = values[part]
    return values


def encode(value):
    if isinstance(value, str):
        if not all(c.isprintable() for c in value):
            raise ValueError('Use a single line without control characters.')
        return json.dumps(value, ensure_ascii=False).replace('${', r'\${')
    return json.dumps(value, allow_nan=False)


def replace_value(source, key, value):
    if key not in FIELDS:
        raise ValueError('Unknown preference.')
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


def validate(values):
    for key, (_, _, kind) in FIELDS.items():
        value = get_value(values, key)
        if kind == 'bool' and type(value) is not bool:
            raise ValueError(f'{key} must be on or off.')
        if kind in ('int', 'nullable-int'):
            if kind == 'nullable-int' and value is None:
                continue
            minimum = 0 if key in ('gapsInner', 'gapsOuter', 'idleDimPercent') else 1
            if type(value) is not int or value < minimum:
                raise ValueError(f'{key} must be an integer of at least {minimum}.')
        if kind in ('scale', 'float'):
            try:
                number = json.loads(value) if kind == 'scale' else value
                if type(number) not in (int, float):
                    raise ValueError()
            except (TypeError, ValueError):
                raise ValueError(f'{key} must be a positive number.') from None
            if not math.isfinite(number) or number <= 0:
                raise ValueError(f'{key} must be a positive finite number.')
        if kind not in ('bool', 'int', 'nullable-int', 'float'):
            if not isinstance(value, str) or not value or not all(c.isprintable() for c in value):
                raise ValueError(f'{key} must be nonempty, single-line text.')
        if kind == 'path' and not Path(value).is_absolute():
            raise ValueError(f'{key} needs an absolute path beginning with /.')
    if not 0.3 <= values['browserDefaultZoom'] <= 5.0:
        raise ValueError('Browser zoom must be between 0.3 and 5.0.')
    if not values['idleDimSec'] < values['idleLockSec'] < values['idleOffSec']:
        raise ValueError('Idle times must increase: dim < lock < screen off.')
    if values['idleSuspendSec'] is not None and values['idleSuspendSec'] <= values['idleOffSec']:
        raise ValueError('Suspend must be later than screen off, or disabled.')
    if values['idleDimPercent'] > 100:
        raise ValueError('Dim brightness must be between 0 and 100.')
    if any(values[k] > 65535 for k in ('hermesLocalPort', 'hermesRemotePort')):
        raise ValueError('Ports must be between 1 and 65535.')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', values['hermesSshHost']):
        raise ValueError('Use an SSH host alias containing letters, numbers, dots, underscores or hyphens.')
    if not re.fullmatch(r'https?://[A-Za-z0-9._~:/?#\[\]@%+,=-]+', values['screenshotUploadUrl']):
        raise ValueError('Use an http(s) upload URL; percent-encode spaces and special characters.')
    if values['terminalFontFamily'] in ('monospace', 'sans-serif', 'serif'):
        raise ValueError('Select a real font family; Fontconfig supplies the monospace alias.')
    if values['terminalFontFamily'] == 'Terminus' and values['terminalFontSize'] not in NATIVE_SIZES:
        raise ValueError('Terminus needs one of these sizes: ' + ', '.join(map(str, NATIVE_SIZES)))


def save_value(path, original, key, value, state_root):
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
            validate(evaluated)
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


def choose_value(key, current, config):
    label, description, kind = FIELDS[key]
    rows = []
    if kind == 'font':
        output = subprocess.check_output(['fc-list', '-f', '%{family}\n'], text=True)
        rows = sorted({s.strip() for line in output.splitlines() for s in line.split(',') if s.strip()}, key=str.casefold)
    elif kind == 'theme':
        rows = Path(config['themeNames']).read_text().splitlines()
    elif kind == 'bool':
        rows = ['On', 'Off']
    elif kind == 'terminal':
        rows = ['ghostty', 'kitty']
    if rows:
        index = menu(rows, label, description + f' • Saved: {current}')
        if index is None:
            return None, False
        return ((index == 0) if kind == 'bool' else rows[index]), True
    raw = menu([], label, description, custom=True, initial='disabled' if current is None else str(current))
    if raw is None:
        return None, False
    if kind == 'nullable-int' and raw.strip().lower() in ('disabled', 'null', 'off'):
        return None, True
    try:
        value = int(raw) if kind in ('int', 'nullable-int') else float(raw) if kind == 'float' else raw
    except ValueError:
        raise ValueError('Enter a valid number.') from None
    return value, True


def launch_apply(config):
    command = "home-rebuild; set -l result $status; read -P 'Press Enter to close… '; exit $result"
    subprocess.Popen([config['terminal'], '-e', config['fish'], '--interactive', '--command', command])


def run(config):
    path = Path(config['repo'])/'home/variables.nix'
    state_root = Path(config['stateRoot'])
    keys = list(FIELDS)
    while True:
        original = path.read_text()
        values = read_values(path)
        rows = [f'{FIELDS[k][0]}  [{get_value(values, k)}] — {FIELDS[k][1]} ({k})' for k in keys]
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
            value, selected = choose_value(key, get_value(values, key), config)
            if not selected or value == get_value(values, key):
                continue
            action = menu(['Save only', 'Save and apply', 'Cancel'], 'Save setting',
                          f'{FIELDS[key][0]}: {get_value(values, key)} → {value}\nApply rebuilds the saved Home Manager configuration, including other pending edits.')
            if action is None or action == 2:
                continue
            save_value(path, original, key, value, state_root)
            if action == 1:
                launch_apply(config)
                return
            subprocess.run(['notify-send', 'Setting saved', FIELDS[key][0] + ' — apply with home-rebuild when ready'], check=False)
        except (ValueError, OSError, subprocess.SubprocessError) as error:
            subprocess.run(['gnesha-rofi', '-e', html.escape(str(error))], check=False)


if __name__ == '__main__':
    try:
        run(json.loads(Path(sys.argv[1]).read_text()))
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        subprocess.run(['gnesha-rofi', '-e', html.escape(str(error))], check=False)
        sys.exit(1)
