# NixOS install runbook

Target: Panasonic Let's Note CF-FV1 (Tiger Lake, ships without a drive).
Drive: M.2 2280 NVMe, fully repartitioned. The previous single exFAT
partition could not be shrunk, so the layout below is built from scratch.
Back up any data you want to keep before starting.

## Hardware notes

- 14.0" 3:2 QHD (2160x1440) anti-glare -> 200% scaling in Sway (already set)
- Intel i5/i7-11th gen, Iris Xe, 16-32GB LPDDR4x soldered, no swap disk (zram used)
- Intel AX201 Wi-Fi 6 + BT 5.1, optional LTE, Thunderbolt 4 x2
- Japanese JIS keyboard driven as US layout; 無変換/変換/かな remapped via keyd
- Fingerprint sensor and IR face camera likely unsupported on Linux (untested)
- Firmware TPM (Intel PTT) available for LUKS auto-unlock

## Quirks already handled in config

- `acpi_osi=! acpi_osi="Windows 2006" acpi_osi="Windows 2009"` kernel params
  (in `modules/letsnote`) - required to unlock EC charge limit / eco mode
- `panasonic-laptop` kernel module for backlight + hotkeys
- `services.power-profiles-daemon` + `zramSwap` for power
- fanControl (panafanpwr) is DISABLED: CF-FV1 not yet supported; enable and
  test via `letsnote.fanControl` and report platform id

## Disk layout (btrfs + LUKS2/TPM)

```
/dev/nvme0n1
├── p1  vfat  ESP  1GB            → /boot
├── p2  LUKS2 (TPM2 auto-unlock)  → /dev/mapper/root (btrfs)
│     ├── @       → /
│     ├── @nix    → /nix
│     ▔▔ @home   → /home
▔▔ p3  exFAT (rest)              → /media
```

Root (p2) is sized generously (e.g. 512GB) so games can live on btrfs
(`/home` or a subvol) - exFAT is NOT suitable for Steam libraries (no exec /
symlink support). p3 is the leftover ~1.3TB for videos/VMs.

No swap partition; `zramSwap` (50%) is used instead.

## Steps

1. Boot NixOS live USB (UEFI).
2. Inspect: `lsblk -f`, `fdisk -l /dev/nvme0n1`.
3. WIPE and partition the whole drive (data already backed up):

   ```console
   parted /dev/nvme0n1 -- mklabel gpt
   parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
   parted /dev/nvme0n1 -- set 1 boot on
   parted /dev/nvme0n1 -- mkpart ROOT 1GiB 513GiB
   parted /dev/nvme0n1 -- mkpart DATA 513GiB 100%
   mkfs.vfat -F32 /dev/nvme0n1p1
   mkfs.exfat -L data /dev/nvme0n1p3
   cryptsetup luksFormat --type luks2 /dev/nvme0n1p2
   cryptsetup open /dev/nvme0n1p2 root
   ```

   (Adjust `513GiB` if you want a bigger/smaller root. The installer shell
   has `mkfs.exfat`; if not, `nix-shell -p exfatprogs`.)

4. Format root and create subvolumes:

   ```console
   mkfs.btrfs -L nixos /dev/mapper/root
   mount /dev/mapper/root /mnt
   btrfs subvolume create /mnt/@
   btrfs subvolume create /mnt/@nix
   btrfs subvolume create /mnt/@home
   # Snapper needs .snapshots as standalone subvolumes (so snapshots
   # never contain their own snapshots):
   btrfs subvolume create /mnt/@/.snapshots
   btrfs subvolume create /mnt/@home/.snapshots
   umount /mnt
   ```

5. Mount everything:

   ```console
   mount -o subvol=@,compress=zstd,noatime /dev/mapper/root /mnt
   mkdir -p /mnt/{boot,nix,home,media}
   mount -o subvol=@nix,compress=zstd,noatime /dev/mapper/root /mnt/nix
   mount -o subvol=@home,compress=zstd,noatime /dev/mapper/root /mnt/home
   mount /dev/nvme0n1p1 /mnt/boot
   mount /dev/nvme0n1p3 /mnt/media
   ```

6. `nixos-generate-config --root /mnt`, then copy the generated config to
   `hosts/cf-fv1/hardware-configuration.nix`. Fill in the real UUIDs
   (placeholders: ROOT_UUID, BOOT_UUID, DATA_UUID) and adjust partition
   numbers if needed. The media partition should be `fsType = "exfat"`.
7. `nixos-install --flake .#cf-fv1`
   - When installing from a VM without efivars (e.g. QEMU with a
     passed-through drive), `boot.loader.efi.canTouchEfiVariables` must be
     `false` for the install only - systemd-boot then writes to the ESP
     fallback `/EFI/BOOT/BOOTX64.EFI`, which the firmware can boot without an
     NVRAM entry. On first boot on real hardware, re-enable
     `canTouchEfiVariables = true` (the default in this repo) and run
     `bootctl install` to enroll a proper boot entry.
   - `nixos-install` does NOT copy the flake into `/etc/nixos`; sync the
     target's `/etc/nixos` from the flake afterwards so on-device rebuilds
     match (this also fixes the stale generated `hardware-configuration.nix`).
8. Reboot, then: set a login credential, enable NetworkManager, test charge
   limit.
9. Restore any backed-up data into `/media` after the network is up.

## TPM auto-unlock (do after first boot)

The LUKS volume still needs its passphrase until you enroll the TPM. As root:

```console
systemd-cryptenroll /dev/nvme0n1p2 --tpm2-device=auto --tpm2-pcrs=0+7
systemd-cryptenroll /dev/nvme0n1p2 --recovery-key
```

The second command prints a one-time recovery key - write it down and keep it
somewhere safe. After this, boot unlocks silently via the TPM while keeping a
passphrase/recovery-key slot as a fallback. (PCR 0+7 seals to firmware +
secure-boot state, so tampered boot will prompt for the key instead.)

## Snapshots & rollback

`modules/btrfs.nix` runs snapper timelines for `/` and `/home` (hourly/7-daily/
4-weekly/2-monthly), snapshots root on every boot, and scrubs monthly.

- **Boot rollback (system state)**: systemd-boot already lists every NixOS
  generation - pick an older one from the menu to boot it, or on the running
  system `sudo nixos-rebuild switch --rollback`.
- **Data rollback (`/etc`, `/var`, `/home`)**: list with
  `sudo snapper -c root list` / `sudo snapper -c home list`, then
  `sudo snapper -c root rollback <number>`.
- **Snapshot around a risky change**:
  ```console
  sudo snapper -c root create -t pre -d "before nixos-rebuild"
  sudo nixos-rebuild switch --flake .#cf-fv1
  sudo snapper -c root create -t post -d "after nixos-rebuild"
  ```

## Rebuild command

    nixos-rebuild switch --flake .#cf-fv1

## Known gotchas hit during install

- **terminus-font console font case**: `modules/fonts.nix` originally
  referenced `ter-V32n.psf.gz` but the package ships lowercase `ter-v32n.psf.gz`.
  This broke the initrd build (`Error: failed to get symlink metadata .../ter-V32n.psf.gz`)
  and aborted `nixos-install`. Fixed with the lowercase name.
- **flake repo ownership**: a repo tarball copied from another OS can keep
  the wrong uid, making nix refuse `git+file://...` ("not owned by current
  user", libgit2 7). Fix: `chown -R root:root` the repo.
- **VM networking**: slirp DNS can fail at boot; `echo 'nameserver 10.0.2.3'
  > /etc/resolv.conf` (or just retry) resolves it.

## Post-install TODO

- Test EC charge limit: `cat /sys/devices/platform/panasonic-laptop/eco_mode`
- Try panafanpwr fan control (module commented in hosts/cf-fv1/default.nix)
- Set a real login credential: `passwd` or set `hashedPassword` in
  modules/hardening.nix
- Add SSH authorized keys to modules/hardening.nix
- Verify /media (exFAT) mounts read/write
- Set up LTE module if the unit has one (`lsusb`/`lspci` to identify)
