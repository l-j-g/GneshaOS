# AUTH-01 Lock Before Suspend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure Sway battery lid-close and idle suspend happen only after gtklock or swaylock confirms the compositor lock.

**Architecture:** Extract lock acquisition into a small sourced shell helper used by the existing `gnesha-lock` package and a new lock-then-suspend entry point. gtklock's post-lock callback is the primary acknowledgment; swaylock's readiness FD is the fallback. Sway owns the lid and idle suspend requests while logind lid actions remain lock-only.

**Tech Stack:** NixOS, Home Manager, Bash, gtklock, swaylock, swayidle, systemd-logind, systemd D-Bus.

**Spec:** `docs/superpowers/specs/2026-09-27-auth-lock-before-suspend-design.md`

## Global Constraints

- Do not start suspend unless gtklock or swaylock positively acknowledged lock readiness.
- Use a bounded acknowledgment timeout; on timeout, report the failure and keep the machine awake.
- Limit each gtklock/swaylock readiness attempt to five seconds; total wait is at most ten seconds.
- Do not treat process-name presence as proof of lock acquisition.
- Keep gtklock primary and use swaylock `--ready-fd` as fallback.
- Keep the existing five-failure PAM policy for both lockers.
- When Sway is unavailable, do not request suspend; battery lid-close is lock-only.
- AC-powered and docked lid-close remain lock-only.
- Never write credentials or password material to files or child arguments.
- Do not activate the running system during source validation.

## Review Focus

- gtklock starts but never invokes its post-lock callback: timeout and fallback must occur, and suspend must not be called. Test in Task 1.
- swaylock fails to start or omits its readiness newline: helper must fail closed. Test in Task 1.
- logind D-Bus Docked property cannot be read: lid helper must avoid suspend. Test in Task 3.
- AC or docked lid-close: lock without suspend. Test in Task 3.
- Concurrent idle and lid requests: only one lock acquisition sequence; suspend ordering is tested in Task 3. Test in Task 1.

---

### Task 1: Add readiness-helper fixtures

**Files:**
- Create: `checks/lock-readiness-stubs.sh`
- Modify: `flake.nix`

**Interfaces:**
- Consumes: helper path argument; temporary `XDG_RUNTIME_DIR`; PATH stubs for gtklock, swaylock, systemctl, busctl, and dbus-send.
- Produces: executable fixture covering both acknowledgment paths, timeout, no-Sway, and serialization.

- [ ] **Step 1: Write the fixture first**

Add cases for gtklock callback acknowledgment, gtklock timeout followed by swaylock readiness, both lockers failing, a stale acknowledgment marker, no `SWAYSOCK`, and two simultaneous lock requests. Record stub calls and assert only one locker launch occurs for concurrent requests.

- [ ] **Step 2: Verify the fixture fails against the missing helper**

Run: `bash checks/lock-readiness-stubs.sh /does/not/exist`

Expected: nonzero with a specific missing-helper error.

- [ ] **Step 3: Review the fixture assertions**

Confirm each test asserts observable lock readiness, suspend ordering, and failure behavior; do not wire the fixture into the flake until the helper exists.

---

### Task 2: Implement lock acquisition acknowledgment

**Files:**
- Create: `home/shell/lock-readiness.sh`
- Modify: `home/desktop/sway/swaylock.nix`
- Test: `checks/lock-readiness-stubs.sh`

**Interfaces:**
- Consumes: `gnesha_lock_acquire` from the sourced helper, `$XDG_RUNTIME_DIR`, configurable bounded timeout.
- Produces: `gnesha_lock_acquire` plus a `gnesha-lock` wrapper that returns success only after a verified locker acknowledgment; gtklock remains primary.

- [ ] **Step 1: Implement the gtklock callback path**

Launch gtklock under the serialized helper, wait for its post-lock callback marker, and retain the verified locker process. Keep callback state inside the private runtime directory. A previously acknowledged locker counts as ready only if its recorded process identity still matches a live locker; reject process-name-only matches.

- [ ] **Step 2: Run the gtklock acknowledgment fixture**

Run: `bash checks/lock-readiness-stubs.sh home/shell/lock-readiness.sh`

Expected: gtklock callback case passes and a missing callback does not count as readiness.

- [ ] **Step 3: Implement the swaylock readiness-FD fallback**

On gtklock start failure or timeout, stop that attempt and launch swaylock with `--ready-fd`; accept readiness only after its newline arrives before the deadline.

- [ ] **Step 4: Run both success and fail-closed fixture paths**

Run: `bash checks/lock-readiness-stubs.sh home/shell/lock-readiness.sh`

Expected: both successful paths return ready; dual failure and timeout return nonzero.

- [ ] **Step 5: Add the passing fixture to the fast source-script check**

Add the helper fixture invocation to `sourceScriptCheck` in `flake.nix`.

- [ ] **Step 6: Run syntax and formatting checks**

Run: `bash -n home/shell/lock-readiness.sh checks/lock-readiness-stubs.sh` and `nix fmt -- --check flake.nix`.

Expected: both pass.

---

### Task 3: Gate every Sway-owned suspend route

**Files:**
- Modify: `home/desktop/sway/swaylock.nix`
- Modify: `home/desktop/sway/daemons.nix`
- Modify: `home/desktop/sway/sway-extra.conf`
- Modify: `hosts/cf-fv1/laptop.nix`
- Test: `checks/lock-readiness-stubs.sh`

**Interfaces:**
- Consumes: `gnesha_lock_acquire` from Task 2.
- Produces: `gnesha-lock-and-suspend [--lid]`; calls systemd only after successful lock readiness.

- [ ] **Step 1: Add the command behavior tests**

Test that a no-Sway request fails without a suspend call; AC lid-close and docked lid-close lock without suspend; inability to query logind's `org.freedesktop.login1.Manager.Docked` property fails closed; battery idle/lid requests suspend only after readiness.

- [ ] **Step 2: Implement `gnesha-lock-and-suspend`**

Implement `gnesha_lock_and_suspend [--lid]` in the sourced helper. For `--lid`, query Docked through `busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager Docked`; require exactly `b false` before considering suspend. If that query fails or returns an unexpected value, do not suspend. Skip suspend on AC or while docked. For battery idle suspend, suspend after readiness.

- [ ] **Step 3: Route lid, idle, and keyboard requests through the command**

Change the Sway lid binding, swayidle battery timeout, and explicit Sway suspend key to `gnesha-lock-and-suspend`. Keep `before-sleep` using the acknowledgment-aware `gnesha-lock`.

- [ ] **Step 4: Make logind lid actions lock-only**

Set `HandleLidSwitch`, `HandleLidSwitchExternalPower`, and `HandleLidSwitchDocked` to `lock`, preventing logind from bypassing the Sway-owned gated suspend path.

- [ ] **Step 5: Run the Sway route fixtures**

Run: `bash checks/lock-readiness-stubs.sh home/shell/lock-readiness.sh`.

Expected: no-Sway, AC, docked, failed Docked query, and readiness-failure paths never call systemctl suspend; eligible battery paths call it only after readiness.

---

### Task 4: Document and validate the generated configuration

**Files:**
- Modify: `home/desktop/sway/README.md` or the existing host lock section in `hosts/cf-fv1/README.md`
- Modify: `TODO`
- Modify: `flake.nix`

**Interfaces:**
- Consumes: generated lock and suspend commands from Tasks 2–3.
- Produces: fast fixture coverage and accurate operator-facing behavior/pending status.

- [ ] **Step 1: Document Sway-present and Sway-absent behavior**

Explain that battery lid-close outside Sway locks only and leaves the machine awake, while eligible Sway battery requests lock before suspend. State that unrelated system sleep sources are outside the guarantee.

- [ ] **Step 2: Run the fast checks and both build-only validations**

Run: `nix flake check --show-trace`; `nixos-rebuild build --flake .#cf-fv1`; `nix build --no-link '.#homeConfigurations."lg@cf-fv1".activationPackage'`.

Expected: all pass without activating the system or Home Manager.

- [ ] **Step 3: Review the staged patch and commit the generation**

Run: `git diff --check`; inspect the exact staged files; commit only AUTH-01 implementation files and progress record.

Expected: focused commit; do not include unrelated worktree changes.

---

## Runtime verification still required

After authorized activation, use a separate recovery console to test gtklock
unlock, swaylock fallback unlock, failed authentication tally behavior,
simultaneous idle/lid requests, AC and docked lid behavior, battery lid-close,
and the no-Sway lock-only case. Until those checks pass, record AUTH-01 as
implemented/built but runtime-unverified.
