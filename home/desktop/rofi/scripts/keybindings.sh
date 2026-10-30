#!/usr/bin/env bash
# Search effective Sway bindings and save key changes for the next rebuild.
set -euo pipefail
config=$1
repo=$(jq -r .repo "$config")
preferences="$repo/home/desktop/sway/keybinding-edits.nix"
capture=$(jq -r .capture "$config")
state_root=$(jq -r .stateRoot "$config")
message='Select an action to change its keys • Saved changes apply after home-rebuild'

accent=$(awk 'match($0, /border-color:[[:space:]]*(#[0-9a-fA-F]{6})/, c) { print c[1]; exit }' \
  "${XDG_CONFIG_HOME:-$HOME/.config}/gnesha/rofi-live.rasi" 2>/dev/null || true)
[[ $accent =~ ^#[[:xdigit:]]{6}$ ]] || accent='#00ff9c'

html() { jq -Rrs '@html'; }
fingerprint() { sha256sum "$preferences" | cut -d ' ' -f 1; }
read_edits() { nix-instantiate --eval --strict --json "$preferences"; }
menu() {
  gnesha-rofi -dmenu -i -no-custom -markup-rows -format i -p Keybindings \
    -mesg "$1" -lines 12 -theme-str 'window { width: 85%; }'
}

save_edit() (
  # Share the activation lock with Settings and rebuild helpers; replace only
  # the candidate we validated, and refuse to overwrite concurrent edits.
  umask 077
  mkdir -p "$state_root" || exit 1
  exec 9> "$state_root/activation.lock" || exit 1
  flock -n 9 || { echo 'A rebuild or another save is running.'; exit 1; }
  [[ ! -L $preferences && $(fingerprint) == "$snapshot" ]] || {
    echo 'Shortcuts changed while the menu was open. Select the action again.'; exit 1;
  }
  candidate=$(mktemp "${preferences%/*}/.keybindings-XXXXXXXX.nix") || exit 1
  trap 'rm -f -- "$candidate"' EXIT
  # All keys are data. Escape Nix interpolation as well as JSON quoting.
  jq -r --arg mode "$mode" --arg source "$source" --arg replacement "$replacement" '
    (if $mode == "default" then ["keybindings"] else ["modes", $mode] end) as $path |
    if $source == $replacement then delpaths([$path + [$source]])
    else setpath($path + [$source]; $replacement) end |
    def literal: tojson | split("${") | join("\\${");
    def nix($indent):
      if type == "object" then
        if length == 0 then "{ }" else
          "{\n" + (to_entries | map($indent + "  " + (.key | literal) + " = " + (.value | nix($indent + "  ")) + ";") | join("\n")) + "\n" + $indent + "}"
        end
      else literal end;
    "# Key changes saved by Gnesha Keybindings. Commands remain in their owning modules.\n" + nix("")
  ' <<< "$edits" > "$candidate" || exit 1
  nix-instantiate --eval --strict --json "$candidate" >/dev/null || exit 1
  chmod --reference="$preferences" "$candidate" || exit 1
  [[ ! -L $preferences && $(fingerprint) == "$snapshot" ]] || {
    echo 'Shortcuts changed during validation. Nothing was saved.'; exit 1;
  }
  mv -T -- "$candidate" "$preferences" || exit 1
)

while true; do
  snapshot=$(fingerprint)
  if ! edits=$(read_edits 2>&1); then
    printf 'Close\n' | menu "$(printf '%s' "$edits" | html)" >/dev/null || true
    exit 0
  fi
  # Overlay pending edits on the installed catalog, always using the original
  # identity so an action can be edited repeatedly before rebuilding.
  rows=$(jq -c --argjson edits "$edits" '
    .catalog | map(.key = ((if .mode == "default" then $edits.keybindings else $edits.modes[.mode] end)[.sourceKey] // .sourceKey)) |
    sort_by(.mode, .description, .sourceKey)
  ' "$config")
  if ! selected=$(jq -r --arg accent "$accent" '
    .[] | (.key | sub("^(--[^ ]+ +)+"; "")) as $chord |
    "<b>\($chord | gsub("Mod4"; "Super") | gsub("Mod1"; "Alt") | @html)</b>  " +
    (if .mode == "default" then "" else "<span foreground=\"\($accent)\">[\(.mode | @html)]</span> " end) +
    "— \(.description | @html)" +
    (if .key | contains("--release ") then " (on release)" else "" end) +
    (if .key | contains("--locked ") then " (also when locked)" else "" end) +
    (if .key | contains("--no-repeat ") then " (no repeat)" else "" end) +
    "\u0000meta\u001f\(.command | gsub("[\r\n]"; " "))"
  ' <<< "$rows" | menu "$message"); then exit 0; fi
  [[ $selected =~ ^[0-9]+$ ]] || exit 0
  binding=$(jq -ec --argjson index "$selected" '.[$index] // empty' <<< "$rows") || exit 0
  source=$(jq -r .sourceKey <<< "$binding")
  mode=$(jq -r .mode <<< "$binding")
  if ! chord=$("$capture"); then continue; fi
  # Capture emits a keysym with optional modifiers, never executable syntax.
  if [[ ! $chord =~ ^((Shift|Ctrl|Mod1|Mod4)\+)*[A-Za-z0-9_]+$ ]]; then
    message='Could not recognize that key. Nothing was saved.'; continue
  fi
  flags=${source%"${source##* }"}
  replacement="$flags$chord"
  # Ignore behavior flags and modifier order when detecting collisions.
  if jq -e --arg mode "$mode" --arg source "$source" --arg chord "$chord" '
    def canonical:
      sub("^(--[^ ]+ +)+"; "") | split("+") |
      (.[0:-1] | map(if . == "Control" then "Ctrl" else . end) | sort) + [.[-1] | ascii_downcase];
    ($chord | canonical) as $new |
    any(.[]; .mode == $mode and .sourceKey != $source and (.key | canonical) == $new)
  ' <<< "$rows" >/dev/null; then
    message='That key combination is already assigned in this mode. Nothing was saved.'; continue
  fi
  description=$(jq -r '.description | @html' <<< "$binding")
  if ! confirm=$(printf 'Save\nCancel\n' | menu "$description → $(printf '%s' "$chord" | html) • Apply later with home-rebuild"); then continue; fi
  [[ $confirm == 0 ]] || continue
  if result=$(save_edit 2>&1); then
    message='Shortcut saved. Run home-rebuild to apply pending changes.'
  else
    message=$(printf '%s' "$result" | html)
  fi
done
