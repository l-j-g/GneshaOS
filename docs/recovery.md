# Stateful application backup and recovery

This runbook records the verified Docker inventory, local snapshot recovery,
and the limits of the current setup. The operator has chosen not to use
off-disk backups. This document does not configure or schedule backups. Do not
treat a successful Nix build, a local snapshot, or a copied configuration
directory as proof that an application can be restored and started.

## Verified inventory

The live read-only inventory found seven running containers: `qbittorrent`,
`gluetun`, `lidarr`, `prowlarr`, `sabnzbd`, `audiobookshelf`, and `emby`.
Their writable configuration bind mounts are beneath
`/home/lg/src/arr/config/`, in the matching per-service directories:

```text
/home/lg/src/arr/config/qbittorrent
/home/lg/src/arr/config/gluetun
/home/lg/src/arr/config/lidarr
/home/lg/src/arr/config/prowlarr
/home/lg/src/arr/config/sabnzbd
/home/lg/src/arr/config/audiobookshelf
/home/lg/src/arr/config/emby
```

The containers also use media paths beneath `/media`. Those paths hold the
actual downloads and library files and need their own independent backup
decision. Emby's `/media` mount is read-only from inside that container; this
does not make the underlying media immutable or backed up. Check the live
Compose mounts and `findmnt` output before copying or restoring anything,
because mount configuration can change.

Ghostfolio is disabled. Its configured runtime directory and secrets file were
absent during the read-only inventory. Do not create or restore a live
Ghostfolio database based on this document. Its proposed PostgreSQL import
requires identifying and validating a real source export first.

The Arr runtime root is `/home/lg/src/arr`. Its `.env` contains runtime
credentials and its `images.lock.json` records image references; neither file
contains the application configuration or media payload. On 2026-09-28, the
`.env` metadata was observed as user-owned with mode `0644`; its contents were
not read, and the permission has not been changed. The parent `/home/lg`
directory is mode `0700`, so other unprivileged users cannot traverse to it.
The Arr configuration files and databases are under `config/`. The system and
Home Manager profile links resolve to Nix store generations, which restore
configuration/package closures but not Compose bind-mounted state. Do not
assume the pinned image manifest is a backup of the images or application data.

This inventory does not establish which application directories contain
databases, whether copying them while running is consistent, which supported
export tool or flags each application requires, or which configuration files
are essential. Verify those details against the deployed application versions
and their official backup/restore documentation before designing a backup job.
For database-backed services, use the application's documented logical export
or a documented quiesced/consistent snapshot procedure. A raw live directory
copy is not assumed to be restorable.

## Backup scope and secrets

The operator has chosen not to keep off-disk backups. None are configured or
scheduled, and no destination or retention policy should be added to this
configuration. The local `@home` Snapper snapshots and `/home` are on the same
Btrfs storage; they help recover selected files but do not protect against loss
of that storage. They also do not cover `/media`.

Do not copy credentials or keys into this repository or into ordinary test
artifacts. The configured Ghostfolio secrets file is currently absent; do not
fabricate its contents. This runbook does not create a second copy of secrets.

## Restore boundaries

- **NixOS generation rollback** restores a prior configuration and package
  closure. It does not roll back Docker bind-mounted application state or
  `/media` data.
- **Application configuration restore** restores a service's files under its
  own `config/<service>` directory. Confirm ownership, permissions, exact
  application version, and any secret dependencies before starting that
  service.
- **Database restore** must use the matching application-supported procedure
  and compatible database/application versions. Confirm the export completed,
  its format and version, and the restore command against upstream
  documentation. Never overwrite the only current database with an
  unverified export.
- **Media restore** restores the actual files under `/media`; application
  configuration or a Nix generation does not recreate those files. Check
  source and destination mounts, available space, and representative file
  readability before copying.

Keep configuration, database exports, secrets, and media as separately
identified backup sets where practical. A restore may need them from compatible
points in time. Local Btrfs snapshots, if available, are useful for local
rollback but are not an independent off-disk backup.

The Arr configuration bind mounts under `/home/lg/src/arr/config` reside on
`/home`, so they are included in the configured `@home` Snapper snapshots.
Use the [Home data restore procedure](install.md#home-data-restore-home-on-home)
to inspect or recover selected files. This is same-device rollback coverage;
it does not make a live application database consistent or replace an
independent backup.

## Local snapshot restore drill

A limited file-level drill was completed on 2026-09-28 using Home Snapper
snapshot `369` as the read-only source. The selected Lidarr `config.xml`,
SQLite database, WAL, and SHM files were copied to a private temporary directory
on `/run/user/1000` (tmpfs). The copied files matched the snapshot source,
the XML parsed, and SQLite `PRAGMA quick_check` returned `ok`. The source
snapshot and live service paths were untouched, and no container or service was
started.

This verifies that the selected snapshot files can be copied and inspected. It
does not prove that a live database snapshot is transactionally consistent,
that Lidarr can start from the copy, or that the configuration and database
constitute a supported application restore. It does not test `/media` or
Ghostfolio. A live application restore remains unverified; do not overwrite
the live config or database from a snapshot based only on this drill.

For future file-level recovery, inspect the chosen Home snapshot first, copy
only selected files into an isolated temporary path, verify copied bytes and
parse/check the copied data there, then confirm application-specific ownership
and version requirements before any authorized live restore. Never point the
temporary path at `/home/lg/src/arr`, `/media`, or a live container mount.

## Status

Inventory: verified read-only for the seven running containers and the listed
bind-mount roots. Off-disk backup: none by operator choice; no schedule or
destination is configured. Local file-level restore drill: passed for the
selected Lidarr snapshot files described above. Per-application
consistency/export procedures and a service-start restore remain unverified.
Arr configuration under `/home/lg/src/arr/config` is covered by local `@home`
Snapper snapshots, with selected-file recovery instructions linked to
`docs/install.md`; this does not protect against storage loss or establish
application consistency.
