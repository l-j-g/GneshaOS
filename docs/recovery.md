# Stateful application backup and recovery

This runbook records the currently verified Docker inventory and the recovery
work that still needs an operator-selected backup destination and a disposable
restore drill. It does not configure or schedule backups. Do not treat a
successful Nix build, a local snapshot, or a copied configuration directory as
proof that application data can be restored.

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

This inventory does not establish which application directories contain
databases, whether copying them while running is consistent, which supported
export tool or flags each application requires, or which configuration files
are essential. Verify those details against the deployed application versions
and their official backup/restore documentation before designing a backup job.
For database-backed services, use the application's documented logical export
or a documented quiesced/consistent snapshot procedure. A raw live directory
copy is not assumed to be restorable.

## Independent backup destination and secrets

No off-disk backup destination has been selected, and no retention policy has
been approved. Select a different physical device or remote system, record its
identity and mount point, and prove it is mounted before any backup or restore
operation. Do not silently write to an unmounted destination path on the root
filesystem. Choose retention only after estimating the sizes and recovery
needs of `/media`, service configuration, and any database exports.

Back up credentials and keys only when they are needed for recovery. Encrypt
secret-bearing backup material before it leaves the host, restrict access to
the backup and its decryption key, and keep the key or recovery phrase in a
separate protected location. Test that authorized recovery access works
without placing secrets, private keys, password hashes, or recovery keys in
this repository, logs, or ordinary unencrypted backup archives. The configured
Ghostfolio secrets file is currently absent; do not fabricate its contents.

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

## Safe restore-drill procedure

The restore drill is **pending**. No off-disk destination is selected, and no
restore drill has been performed. Once an operator selects a destination and
the drill is authorized, use an isolated disposable host or VM and
temporary paths that cannot overlap `/home/lg/src/arr`, `/media`, or live
container names/networks:

1. Record the backup source identity, mount, date, inventory, and checksums.
   Confirm the source is read-only for the drill and that a separate current
   copy exists before testing.
2. Create a fresh isolated environment with no access to production bind
   mounts. Use the documented application and database versions and prevent
   network exposure or automatic connections to production services.
3. Restore a representative service configuration and its corresponding
   documented database export into temporary directories. Decrypt secrets
   only into protected temporary storage with restrictive permissions.
4. Start only the isolated service using distinct names, ports, and networks.
   Confirm its documented health checks and inspect representative records or
   files using read-only application functions.
5. Record the exact application versions, export/restore commands, elapsed
   time, checks performed, and any data or permission issues. Destroy only the
   disposable environment and its temporary data after preserving the report.
6. Revise this runbook with evidence from the completed drill before treating
   the backup method as verified.

Do not perform this drill against the live containers or original data paths.
Do not run a restore command until the selected destination, backup contents,
and isolated target have been positively identified.

## Status

Inventory: verified read-only for the seven running containers and the listed
bind-mount roots. Off-disk destination and retention: pending operator
selection. Per-application consistency/export procedures: pending verification
for the deployed versions. Disposable restore drill: pending; no restore has
been performed.
