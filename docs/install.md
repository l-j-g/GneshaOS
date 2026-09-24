# NixOS install and recovery runbook

Target: Panasonic Let's Note CF-FV1. This runbook describes a destructive
reinstall; use the recovery procedures below when you only need to restore a
generation or data. Never run a formatting command until the target and backup
preconditions have been checked and the exact command has been reviewed.

## Hardware notes

- 14.0" 3:2 QHD (2160x1440) anti-glare; Sway uses 200% scaling.
- Intel i5/i7-11th gen, Iris Xe, 16-32GB LPDDR4x soldered, zram swap.
- Intel AX201 Wi-Fi 6 + BT 5.1, optional LTE, Thunderbolt 4 x2.
- Japanese JIS keyboard configured as US; fingerprint and IR camera support
  are untested.

The repository already configures the Panasonic EC kernel parameters and
`panasonic-laptop` module. `panafanpwr` fan control remains disabled because
CF-FV1 support is not confirmed.

## Install: preflight and target layout

This layout uses a 1 GiB EFI system partition, a LUKS2 container holding
Btrfs subvolumes `@`, `@nix`, and `@home`, and a separate exFAT `/media`
partition. Example device names below are illustrative only. Device naming
changes across machines and boots; never identify a target by its `/dev/...`
path alone.

Before any partition-table or filesystem operation:

1. Record and match the target's model, serial number, and size using firmware
   information and `lsblk -o NAME,PATH,MODEL,SERIAL,SIZE,TYPE,FSTYPE,MOUNTPOINTS`.
   Check `findmnt` and ensure none of the target's partitions are mounted or
   used as swap. Recheck immediately before each destructive operation.
2. Prove that a current backup exists on a different physical device or remote
   system. Inspect its date, contents, and readability; confirm the files
   needed to reinstall and restore are present. A snapshot on this target does
   not count as a backup.
3. Write down the exact target-specific destructive command(s), verify every
   device path against the recorded identity, and have another person review
   them where possible. If identity, backup, or command is uncertain, stop.
4. Disconnect unrelated storage where practical. Do not paste generic example
   paths into a shell or use a script to discover and wipe a device.

After these checks, partition and format the deliberately selected device
using the reviewed commands for this installation. The expected layout is:

```
<selected NVMe device>
├── p1  vfat  ESP  1 GiB             -> /boot
├── p2  LUKS2                         -> Btrfs: @, @nix, @home
└── p3  exFAT (remaining capacity)    -> /media
```

The Btrfs root can be sized to suit the device (512 GiB was used on the
original 2 TiB drive); exFAT is not suitable for Steam libraries. No swap
partition is needed because the system uses zram.

Create the Btrfs filesystem and subvolumes only after reviewing the exact
target mapper path. Required subvolume names are `@`, `@nix`, and `@home`.
Snapper also requires standalone `.snapshots` subvolumes under `@` and
`@home`; create them before mounting those subvolumes for installation.

Mount the selected subvolumes under `/mnt` with `@` as `/`, `@nix` as `/nix`,
and `@home` as `/home`; mount the selected ESP at `/mnt/boot` and exFAT
partition at `/mnt/media`. Confirm the resulting mounts with `findmnt -R /mnt`
before proceeding.

## Generate hardware configuration and install

Run `nixos-generate-config --root /mnt`. Copy the freshly generated
`/mnt/etc/nixos/hardware-configuration.nix` into
`hosts/cf-fv1/hardware-configuration.nix` as-is, preserving its generated
UUIDs and device identification. Do not replace UUIDs by hand or copy stale
identifiers from this document. Review the generated mounts against the layout
above. Put intentional mount-option or policy changes in a separate Nix module
and import that module; keep the generated hardware file machine-generated.
The media mount should use `fsType = "exfat"`.

Run `nixos-install --flake .#cf-fv1` only after checking that the generated
hardware configuration refers to the intended target. If installing from a VM
without EFI variables, `boot.loader.efi.canTouchEfiVariables = false` may be
needed for that install; on first boot on the real machine restore the normal
setting and run `bootctl install` to enroll the firmware entry. `nixos-install`
does not copy the flake into `/etc/nixos`; sync the repository there after
install so on-device rebuilds use the same configuration.

Before leaving the installer, establish a working login credential and SSH
access if needed, and test network access. Do not lose installer access until
you have confirmed first-login access on the installed system. Restore data to
`/media` only after verifying the mounted destination and backup source.

## First boot: credentials and TPM

Set a real login credential (`passwd`, or configure `hashedPassword`) and
install intended SSH authorized keys before exposing remote access. Confirm
that local login works and retain recovery access.

TPM2 enrollment is optional and should follow successful passphrase boots and
confirmation of the recovery-key storage location. Use the actual LUKS device
identified with `lsblk`/`cryptsetup status`, not an assumed device path. Keep
the recovery key outside the machine; do not put it in the repository.

## Recovery procedures

### NixOS generation rollback (configuration and packages)

At boot, select an older system generation in systemd-boot. From a running
system, `sudo nixos-rebuild switch --rollback` switches to the previous
generation. This changes the system configuration and package closure. It does
not restore arbitrary files in `/etc` or `/var`, user files in `/home`, or
files on `/media`.

### Root data restore (`/etc`, `/var`, and other files on `@`)

First preserve current state and check that the desired snapshot exists:

```console
sudo snapper -c root list
sudo snapper -c root status <from-number>..<to-number>
```

For selected files, inspect `sudo snapper -c root diff <from-number>..<to-number>` and
copy only the needed paths from the snapshot under
`/.snapshots/<number>/snapshot/`. For a broad rollback, stop affected services,
back up current data, confirm the snapshot and recovery path, then consult
`snapper(8)` for rollback behavior. This host mounts `/` explicitly with
`subvol=@`. Snapper's Btrfs default-subvolume change does not rewrite that
configured mount option, so a reported default-subvolume change alone does not
prove the next boot uses the rollback snapshot. Recovery of a bootable root
must preserve the configured `@` layout or deliberately update the mount
configuration and boot artifacts as a separate reviewed operation. Validate
the exact procedure on a disposable VM first. In a disposable VM with this
subvolume layout, `snapper rollback` against a root config mounted at
`/mnt/root-layout` was rejected as a non-root subvolume; the mount still used
`subvol=@` while the Btrfs default remained `@home`. This test does not prove a
full host boot rollback, so do not use Snapper's default-subvolume change as a
host recovery procedure. See [`snapper(8)`](https://manpages.opensuse.org/Tumbleweed/snapper/snapper.8.en.html)
for the documented rollback and undo behavior and their limits.

### Home data restore (`/home` on `@home`)

Home is a separate Btrfs subvolume with its own Snapper config. Inspect it
separately with `sudo snapper -c home list` and `sudo snapper -c home diff
<from-number>..<to-number>`. Restore selected files from
`/home/.snapshots/<number>/snapshot/` after preserving their current versions.
Do not assume a root snapshot or root rollback restores home data. Close
applications that may write the affected files; Snapper snapshots do not
guarantee application or database consistency.

### External media restore (`/media`)

`/media` is a separate exFAT filesystem and is not covered by the Btrfs
snapper configurations. Restore it from the verified external backup, after
checking source and destination mounts, free space, and representative backup
file readability. Same-disk Btrfs snapshots are not independent backups, do
not cover `/media`, and do not guarantee database-consistent exports. Keep
database backups made with the application's supported export/backup method.

## Snapshots around a risky change

Capture the number printed by the pre-snapshot command and pass it to the
post-snapshot command so Snapper records the pair:

```console
pre=$(sudo snapper -c root create -t pre -p -d "before nixos-rebuild")
sudo nixos-rebuild switch --flake .#cf-fv1
sudo snapper -c root create -t post --pre-number "$pre" -d "after nixos-rebuild"
```

Repeat with `-c home` only for a change whose relevant data is under `/home`.
If the rebuild fails, capture a post snapshot of the resulting state as well;
do not infer a successful rollback from the existence of a pre snapshot.

## Rebuild commands

```console
nixos-rebuild switch --flake .#cf-fv1
nh home switch . -c lg@cf-fv1
```

The flake discovers hosts from `hosts/`. Stable machine values belong in
`system-parameters.nix`; editable Home Manager preferences belong in
`home/variables.nix`.

## Post-install checks

- Test the charge limit through the configured Panasonic EC interface.
- Verify `/media` mounts read/write and restore data from the external backup.
- Configure LTE if present; identify hardware with `lsusb`/`lspci` first.
- Keep fan control disabled until the CF-FV1 platform is confirmed supported.

## Known install notes

- `modules/fonts.nix` uses lowercase `ter-v32n.psf.gz`, matching the package.
- A copied repository may need its ownership corrected so Nix accepts the
  local flake; inspect it before changing ownership.
- VM slirp DNS can fail at boot; inspect resolver state before retrying.
