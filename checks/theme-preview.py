#!/usr/bin/env python3
"""Exercise live terminal theme output without touching the desktop."""
import os
import shutil
from pathlib import Path
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1] / 'home/desktop/sway/scripts/theme-preview'
with tempfile.TemporaryDirectory(prefix='gnesha-theme-check-') as directory:
    root = Path(directory)
    config = root / 'config'
    data = config / 'gnesha'
    data.mkdir(parents=True)
    palette = [f'{i:06x}' for i in range(32)]
    (data / 'theme-data').write_text('\t'.join(['fixture', *palette]) + '\n')
    binary = root / 'bin'
    binary.mkdir()
    for name in ['systemctl', 'kitten', 'swaymsg', 'pkill']:
        stub = binary / name
        stub.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$TEST_LOG"\n'
                        'case "$*" in *USR2*) exit "${RELOAD_STATUS:-0}";; esac\n')
        stub.chmod(0o755)
    log = root / 'log'
    env = dict(os.environ, XDG_CONFIG_HOME=str(config), TEST_LOG=str(log),
               PATH=f'{binary}:' + os.environ['PATH'])
    for status in ['0', '1', '2']:
        log.write_text('')
        result = subprocess.run(['sh', str(source), '--apply', 'fixture'],
                                env=dict(env, RELOAD_STATUS=status), capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
        output = (data / 'ghostty-live.conf').read_text()
        assert 'background = #000000\n' in output
        assert 'foreground = #000005\n' in output
        assert 'selection-background = #000002\n' in output
        assert 'selection-foreground = #000006\n' in output
        for i in range(16):
            assert f'palette = {i}=#{palette[16+i]}\n' in output
        assert f'--signal USR2 --require-handler --euid {os.geteuid()} --exact ghostty' in log.read_text()
        assert ('Ghostty reload failed' in result.stderr) == (status == '2')
    ghostty = shutil.which('ghostty')
    if ghostty:
        subprocess.run([ghostty, '+validate-config',
                        f'--config-file={data / "ghostty-live.conf"}'], check=True)
print('Live terminal theme checks passed')
