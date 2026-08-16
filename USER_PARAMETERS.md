# GneshaOS — user parameters

Everything you need to make this configuration yours lives in ONE file at the
repo root: `params.nix`. Nothing user-specific is hardcoded anywhere else
except `hosts/<host>/hardware-configuration.nix`, which is machine-generated
by `nixos-generate-config` (disk UUIDs etc.) and is intentionally not
parameterised — see [Quickstart](#quickstart-new-user-existing-nixos-machine) for what to do with it.

This document is the self-service reference: quickstart, every variable with
allowed/example values, and how to apply changes. `params.example.nix` in the
repo is the same content as a documented template, and doubles as the fallback
if `params.nix` is ever missing (a fresh clone always evaluates).

---

## Quickstart (new user, existing NixOS machine)

```sh
# 1. Get the config onto the machine.
git clone https://github.com/l-j-g/GneshaOS.git
sudo cp -r GneshaOS /etc/nixos   # or symlink: sudo ln -s "$PWD/GneshaOS" /etc/nixos
cd /etc/nixos

# 2. Personalise the top-level parameters.
#    cp params.example.nix params.nix   # optional: start from the template
#    Edit params.nix. At minimum change:
#      systemSettings.hostName        -> your hostname
#      userSettings.userName          -> your login name
#      userSettings.gitUserName /
#      userSettings.gitUserEmail      -> your git identity
#      userSettings.timeZone          -> your IANA timezone
#      userSettings.latitude /
#      userSettings.longitude         -> your location (wlsunset day/night tint)
#      userSettings.keyboardLayout    -> your layout
#      userSettings.displayWidth /
#      userSettings.displayHeight     -> your panel's native resolution (px)
#      userSettings.displayScale      -> "1" for 100%, "2" for 200% HiDPI

# 3. Build and switch. The flake attribute name is YOUR hostName from step 2.
sudo nixos-rebuild switch --flake .#<hostName>

# Dry-run first if you like:
nixos-rebuild build --flake .#<hostName>
```

That's the whole loop. Every later change is the same two steps: edit
`params.nix`, rebuild. There is no other file to touch for user-level
settings.

> **Fresh install instead?** Follow [`docs/install.md`](docs/install.md) for
> partitioning, then `nixos-install --flake .#<hostName>`. The parameters
> below still apply unchanged.

---

## How it works

- `flake.nix` reads `params.nix` (via `specialArgs`/`extraSpecialArgs`) and
  passes it to every module. `params.nix` is **tracked by git by design** —
  git flakes only copy tracked files, so an untracked/ignored params file
  would be invisible to `nix flake` eval and your edits would silently not
  apply.
- If `params.nix` is missing, `flake.nix` falls back to `params.example.nix`
  (identical values), so a fresh clone always evaluates.
- `params.nix` currently in the repo is the reference machine's (host
  `cf-fv1`, user `lg`). You are expected to edit it — it is not a private
  file, and nothing in the repo needs a private note to configure.

---

## Variable reference

### `systemSettings` — machine-level

| Variable | Type / allowed values | Example | What it does | Used by |
| --- | --- | --- | --- | --- |
| `hostName` | string (hostname) | `"cf-fv1"` | Machine hostname. Sets `networking.hostName` and the samba "server string". **Also the flake attr name**: rebuild with `--flake .#<hostName>`. | `flake.nix`, `hosts/<host>/default.nix` |
| `flakePath` | string (absolute path) | `"/etc/nixos"` | Where this flake lives on the machine. Feeds the `rebuild`/`nixcheck`/`nixeval` shell aliases. Default `/etc/nixos`. | `home/shell.nix` |

### `userSettings` — who sits at the machine, and preferences

| Variable | Type / allowed values | Example | What it does | Used by |
| --- | --- | --- | --- | --- |
| `userName` | string (POSIX login name) | `"lg"` | Your login name. Must match the user declared in `hosts/<host>/default.nix` and your `@home` btrfs subvolume (see [Applying changes](#applying-changes)). | `flake.nix` (home-manager user), `home/default.nix`, `hosts/<host>/default.nix` (samba valid/force user, docker extraGroups), `home/theme.nix` |
| `gitUserName` | string | `"lg"` | Git identity (commits you make). | `home/editors.nix` (`programs.git`) |
| `gitUserEmail` | string (email) | `"lg@lgreve.com"` | Git identity email. | `home/editors.nix` |
| `homeDirectory` | string (absolute path) | `"/home/lg"` | Your home directory. Must match the `@home` subvolume / useradd default. | `home/default.nix` (`home.homeDirectory`) |
| `timeZone` | string (IANA tz name) | `"Australia/Sydney"` | System timezone. | `hosts/<host>/default.nix` (`time.timeZone`) |
| `latitude` | float, decimal degrees (negative = south) | `-33.87` | Your latitude for wlsunset's day/night tint. | `home/desktop/sway.nix` |
| `longitude` | float, decimal degrees (negative = west) | `151.21` | Your longitude for wlsunset. | `home/desktop/sway.nix` |
| `keyboardLayout` | string (xkb layout) | `"us"` | Keyboard layout. | `home/desktop/sway.nix` (input "type:keyboard") |
| `keyboardOptions` | string (xkb options) | `"ctrl:nocaps"` | Keyboard option remaps; `""` for none. | `home/desktop/sway.nix` |
| `displayWidth` | int (px) | `2160` | Panel native width. Sizes the generated wallpaper SVG. | `home/theme.nix` |
| `displayHeight` | int (px) | `1440` | Panel native height. Sizes the generated wallpaper SVG. | `home/theme.nix` |
| `displayScale` | **string** (NOT number) | `"2"` | Sway output scaling: `"1"` = 100%, `"2"` = 200% HiDPI. Must be a string (sway accepts fractional too, e.g. `"1.5"`). Also the value `scale.sh default` (Mod+0) resets to. | `home/desktop/sway.nix`, `home/desktop/scripts/scale.sh` |
| `gapsInner` | int (px) | `5` | Sway gaps inner. | `home/desktop/sway-extra.conf` |
| `gapsOuter` | int (px) | `5` | Sway gaps outer. | `home/desktop/sway-extra.conf` |
| `terminalFontSize` | int (pt) | `11` | foot terminal font size. | `home/desktop/foot.nix` |
| `screenshotDir` | string (path, `~` ok) | `"~/Pictures/Screenshots"` | Where grimshot saves screenshots (dir is mkdir'd on session start). | `home/desktop/sway.nix` |
| `screenshotUploadUrl` | string (URL) | `"https://x0.at/"` | Anonymous image host for the screenshot-upload bindings (Shift+Print). Point at your own 0x0-compatible endpoint to change it. | `home/desktop/sway-extra.conf` |
| `idleDimSec` | int (seconds) | `240` | swayidle: dim after N s idle. | `home/desktop/daemons.nix` |
| `idleDimPercent` | int (%) | `10` | swayidle: dim brightness level (%). | `home/desktop/daemons.nix` |
| `idleLockSec` | int (seconds) | `300` | swayidle: lock after N s idle. | `home/desktop/daemons.nix` |
| `idleOffSec` | int (seconds) | `600` | swayidle: DPMS off after N s idle. | `home/desktop/daemons.nix` |
| `idleSuspendSec` | int (seconds) | `900` | swayidle: suspend after N s idle (battery only). Sequence: dim → lock → off → suspend. | `home/desktop/daemons.nix` |
| `backlightDevice` | string (device name) | `"intel_backlight"` | Backlight device. Find yours with `brightnessctl -l` (or look in `/sys/class/backlight/*`). | `home/desktop/waybar.nix`, `home/desktop/daemons.nix` |
| `autoBrightness` | bool | `false` | When true, enable wluma's adaptive ambient-brightness service; manual changes teach its brightness model. | `home/desktop/daemons.nix` |
| `alsSensorPath` | string (absolute path) | `"/sys/bus/iio/devices/iio:device4/in_illuminance_raw"` | Ambient-light sensor raw path for automatic brightness (retained for hardware documentation; wluma discovers IIO sensors under `/sys/bus/iio/devices`). | `home/desktop/daemons.nix` |
| `arrComposePath` | string (absolute path) | `"/home/lg/src/arr/docker-compose.yml"` | docker-compose file of the self-hosted *arr media stack (stopped cleanly before `/media` unmounts at shutdown). Point at your compose file or ignore if you don't run the stack. | `hosts/<host>/default.nix` (docker-compose-stop unit) |

---

## Applying changes

1. Edit `params.nix` in the repo (on the machine, e.g. `/etc/nixos`).
2. Rebuild:

   ```sh
   sudo nixos-rebuild switch --flake .#<hostName>   # hostName = your value
   ```

   If you use the bundled shell aliases (`rebuild`, `rebuild-boot`, `nixcheck`,
   `nixeval` from `home/shell.nix`), they already resolve host + flake path
   from `params.nix` — no flags needed.

3. Changes to the **display** (resolution/scaling) also affect the generated
   wallpaper and the `scale.sh` reset value — just rebuild and relog (or
   restart sway) to pick them up.

Notes and gotchas:

- **Changing `hostName`** renames the flake attribute: rebuild with
  `--flake .#<newName>`. Machine-generated references (systemd-boot entries)
  are unaffected.
- **Changing `userName`/`homeDirectory`** requires the matching POSIX user
  (declared in `hosts/<host>/default.nix`) and the `@home` btrfs subvolume to
  exist on the machine — create the subvolume first
  (`btrfs subvolume create /mnt/@home` during install) or the build won't
  match your filesystem.
- **`displayScale` is a string**: `"1"`, `"2"`, `"1.5"` — not an integer.
- **Hardware names** (`backlightDevice`, `alsSensorPath`) are machine-specific:
  check `brightnessctl -l` and `/sys/bus/iio/devices/` on YOUR machine.
- **`hardware-configuration.nix`** (`hosts/cf-fv1/`) is generated per machine
  by `nixos-generate-config --root /mnt`; copy it into the host dir for your
  machine. This is the only non-parameterised file.
- **Keep `params.nix` tracked**: it must stay in git for `nix flake` to see
  your edits (git flakes only copy tracked files). Do not add it to
  `.gitignore`.
- If `params.nix` is deleted, the build falls back to `params.example.nix` —
  the config still evaluates, with the reference machine's values.

## FAQ

**Do I need any private notes or secrets to configure this?** No. Every
user-facing value is in `params.nix`; the repo ships with documented
examples, not private state.

**Where is my wallpaper defined?** `displayWidth`/`displayHeight` in
`params.nix` drive the wallpaper SVG generated in `home/theme.nix`. Change
resolution there, not in the theme.

**How do I find my ambient-light sensor?** `ls /sys/bus/iio/devices/` and
look for the `iio:deviceN` that exposes `in_illuminance_raw`; set
`alsSensorPath` to that file's absolute path.
