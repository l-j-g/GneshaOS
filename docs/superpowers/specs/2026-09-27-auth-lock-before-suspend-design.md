# AUTH-01: Lock acknowledgment before suspend

## Purpose and success criteria

Battery lid-close and Sway idle-suspend must not begin system suspend until the
active Sway session has positively confirmed that its screen locker acquired
the lock. A failed launch, missing compositor, or acknowledgment timeout must
leave the machine awake and report an error. AC lid-close remains lock-only.
This is a safety change to the existing desktop session; it must not weaken the
five-failure PAM policy already applied to gtklock and swaylock.

## Current behavior

`gnesha-lock` serializes calls but treats a running gtklock or swaylock process
as proof of a lock, then starts gtklock with `--daemonize` and falls back to
daemonized swaylock. Neither return currently proves lock acquisition.
`swayidle` directly calls `systemctl suspend` on battery and invokes the lock
helper as a `before-sleep` callback. `logind` independently suspends on battery
lid-close, so the callback's delay inhibitor cannot reliably prevent sleep
after a failure. A Sway lid binding also invokes the lock helper without
requesting suspend.

## Approved approach

Use gtklock as the primary locker and wait for its configured post-lock
callback to acknowledge successful acquisition. If gtklock cannot start or
does not acknowledge within a bounded deadline, stop that attempt and launch
swaylock using its readiness file descriptor. Suspend only after one path
reports readiness. Keep the entire check-and-suspend sequence under a shared
runtime lock so simultaneous lid and idle requests cannot launch competing
lockers or race into suspend. Existing already-locked sessions count as ready
only when this helper has recorded a verified acknowledgment and the recorded
locker remains alive; process-name presence alone is insufficient.

Route battery lid-close and battery idle-suspend through a single Sway-owned
lock-then-suspend command. The command checks AC state after lock readiness;
on AC it leaves the machine awake. Change logind lid actions to `lock` for
battery, external power, and docked cases so logind never independently starts
an ungated suspend. Preserve docked/AC lock-only behavior. Route the explicit
Sway suspend key through the same command. Ordinary explicit system sleep
requests outside those Sway-owned paths remain outside the guarantee unless
separately brought into scope.

When Sway is not running, no Sway helper may request suspend. logind's `lock`
action can request session locking, but if there is no capable graphical
locker, the machine remains awake rather than suspending unlocked. Battery
lid-close suspend is therefore intentionally unavailable outside the active
Sway session.

## Failure and concurrency behavior

- Gtklock start failure or timeout triggers the swaylock readiness fallback.
- If neither locker confirms readiness before the bounded deadline, return a
  visible error and do not call `systemctl suspend`.
- If the verified locker exits before the suspend request, abort suspend.
- Duplicate idle/lid/keyboard requests serialize through one runtime lock.
- KeePassXC lock remains best-effort and is not evidence of screen-lock
  readiness.
- No credentials or password material are written to state files or passed to
  child processes.

## Files and validation

Expected implementation files are `home/desktop/sway/swaylock.nix`,
`home/desktop/sway/daemons.nix`, `home/desktop/sway/sway-extra.conf`, and
`hosts/cf-fv1/laptop.nix`, plus focused helper fixtures and the host lock
documentation. Fixtures must cover gtklock callback acknowledgment, swaylock
readiness fallback, startup failure, timeout, concurrent calls, and a no-Sway
case; each must assert that suspend occurs only after successful readiness.
Fast flake checks and build-only NixOS/Home Manager validation can establish
generated configuration correctness. Live unlock, lid, and suspend/recovery
testing requires a separate recovery console and remains pending until the
configuration is activated in an authorized local session.

## Deliberate limits

This change does not alter PAM tally rules, greetd, authentication credentials,
or generic systemd sleep authorization. It does not claim that the helper can
veto every unrelated source of system sleep. Runtime behavior and safe recovery
must be verified on the laptop before AUTH-01 is complete.
