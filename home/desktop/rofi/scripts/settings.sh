#!/usr/bin/env bash
# Rofi script mode: each selection starts a fresh callback. Only ROFI_DATA
# carries the edit state; Escape leaves no session files and never saves.
set -euo pipefail
config=$1
shift
repo=$(jq -r .repo "$config")
preferences="$repo/home/variables.nix"
state=${ROFI_DATA:-'{}'}

option() {
  local value=$2
  value=${value//$'\n'/ }
  value=${value//$'\r'/ }
  printf '\0%s\x1f%s\n' "$1" "$value"
}
row() { printf '%s\0info\x1f%s\n' "$1" "$2"; }
html() { jq -Rrs '@html | gsub("[\\r\\n]"; " " )'; }
header() {
  option prompt "$1"
  option markup-rows true
  option no-custom "$2"
  option data "$state"
  option message "${3:-}"
}
read_values() { nix-instantiate --eval --strict --json "$1"; }
fingerprint() { sha256sum "$preferences" | cut -d ' ' -f 1; }

catalog() {
  # Comments are the only descriptions; assignments determine row order.
  gawk '
    /^[[:space:]]*#/ { sub(/^[[:space:]]*#[[:space:]]?/, ""); help = help (help ? " " : "") $0; next }
    match($0, /^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=.*;[[:space:]]*$/, p) { print p[1] "\t" help }
    /[^[:space:]]/ { help = "" }
  ' "$preferences" | jq -Rsc --argjson values "$values" '
    [$values | paths(type != "object" and type != "array") | map(tostring) | join(".")] as $keys |
    split("\n") | map(select(length > 0) | split("\t")) |
    [.[] as $doc | $keys[] | select(split(".")[-1] == $doc[0]) | {key: ., help: $doc[1]}]'
}
main_menu() {
  local message=${1:-'Search names or descriptions • Values shown are saved preferences'} used
  state='{}'
  if ! values=$(read_values "$preferences" 2>&1); then
    header Settings true "$(printf '%s' "$values" | html)"
    row 'Close' close
    return
  fi
  entries=$(catalog)
  used=$( { rg --no-filename -o --glob '*.nix' '\bvariables(\.[A-Za-z_][A-Za-z0-9_]*)+' \
    "$repo/home" "$repo/hosts" "$repo/modules" "$repo/flake.nix" 2>/dev/null || true; } |
    sort -u | jq -Rsc 'split("\n") | map(select(length > 0) | ltrimstr("variables."))')
  local accent
  accent=$(gawk 'match($0, /border-color:[[:space:]]*(#[0-9a-fA-F]{6})/, c) { print c[1]; exit }' \
    "${XDG_CONFIG_HOME:-$HOME/.config}/gnesha/rofi-live.rasi" 2>/dev/null || true)
  [[ $accent =~ ^#[[:xdigit:]]{6}$ ]] || accent='#00ff9c'
  header Settings true "$message"
  jq -jr --argjson values "$values" --argjson used "$used" --arg accent "$accent" '
    .[] | . as $e | select(any($used[]; . as $ref | $ref == $e.key or ($e.key | startswith($ref + ".")))) |
    "<b>\(.key | @html)</b>  <span foreground=\"\($accent)\">[\($values | getpath($e.key | split(".")) | tostring | @html)]</span> — \(.help | @html)\u0000info\u001f\(.key)\n"
  ' <<< "$entries"
  row 'Apply saved settings' apply
}

edit_menu() {
  local key=$1 snapshot override help current kind choices=''
  snapshot=$(fingerprint)
  values=$(read_values "$preferences")
  entries=$(catalog)
  if ! jq -e --arg key "$key" 'any(.[]; .key == $key)' <<< "$entries" >/dev/null; then
    main_menu 'Unknown preference.'; return
  fi
  override="$repo/hosts/$(jq -r .host "$config")/home-variables.nix"
  if [[ -e $override ]]; then
    local overrides
    overrides=$(read_values "$override")
    if jq -e --arg key "$key" 'any(paths; . == ($key | split(".")))' <<< "$overrides" >/dev/null; then
      main_menu "This preference is overridden in $(printf '%s' "$override" | html); edit that file instead."
      return
    fi
  fi
  help=$(jq -r --arg key "$key" '.[] | select(.key == $key) | .help | @html' <<< "$entries")
  current=$(jq -c --arg key "$key" 'getpath($key | split("."))' <<< "$values")
  kind=$(jq -r type <<< "$current")
  state=$(jq -cn --arg key "$key" --arg snapshot "$snapshot" --arg kind "$kind" \
    '{stage:"edit", key:$key, snapshot:$snapshot, kind:$kind}')
  case $key in
    terminalFontFamily) choices=$(fc-list -f '%{family}\n' | tr ',' '\n' | sed '/^$/d' | sort -fu) ;;
    themeName) choices=$(cat "$(jq -r .themeNames "$config")") ;;
    terminal) choices=$(jq -r '.terminals[]' "$config") ;;
  esac
  [[ $kind != boolean ]] || choices=$'On\nOff'
  if [[ -n $choices ]]; then
    header "$key" true "$help • Saved: $(printf '%s' "$current" | html)"
    local boolean=false
    [[ $kind != boolean ]] || boolean=true
    printf '%s\n' "$choices" | jq -Rjr --argjson boolean "$boolean" '
      split("\n")[] | select(length > 0) | . as $label |
      (if $boolean then . == "On" else . end) as $value |
      "\($label | @html)\u0000info\u001f\($value | tojson)\n"'
  else
    header "$key" false "$help • Type a new value and press Enter. Saved: $(printf '%s' "$current" | html)"
    row "Keep saved value: $(printf '%s' "$current" | html)" back
  fi
  row 'Back' back
}

confirm_edit() {
  local value key kind
  key=$(jq -r .key <<< "$state")
  kind=$(jq -r .kind <<< "$state")
  if [[ ${ROFI_RETV:-0} == 1 ]]; then
    value=${ROFI_INFO:?}
  else
    case $key:$kind in
      idleSuspendSec:*|*:null)
        if [[ ${1,,} =~ ^(disabled|null|off)$ ]]; then value=null;
        else value=$(jq -cen --arg raw "$1" '$raw | tonumber') || { main_menu 'Enter a whole number or disabled.'; return; }; fi ;;
      *:number) value=$(jq -cen --arg raw "$1" '$raw | tonumber') || { main_menu 'Enter a valid number.'; return; } ;;
      *) value=$(jq -cn --arg raw "$1" '$raw') ;;
    esac
  fi
  state=$(jq -c --argjson value "$value" '. + {stage:"confirm", value:$value}' <<< "$state")
  header 'Save setting' true "$(printf '%s' "$key" | html) → $(jq -r '.value | tostring | @html' <<< "$state") • Apply rebuilds all pending Home Manager changes."
  row 'Save only' save
  row 'Save and apply' save-apply
  row 'Cancel' back
}

save_edit() (
  # A subshell owns the lock and candidate cleanup. Explicit failure exits are
  # required here because the caller tests this function in an if statement.
  local state_root key value snapshot leaf candidate validator override
  state_root=$(jq -r .stateRoot "$config")
  (umask 077; mkdir -p "$state_root") || exit 1
  exec 9> "$state_root/activation.lock" || exit 1
  flock -n 9 || { echo 'A rebuild or activation is running. Save after it finishes.'; exit 1; }
  key=$(jq -r .key <<< "$state")
  value=$(jq -c .value <<< "$state")
  snapshot=$(jq -r .snapshot <<< "$state")
  [[ ! -L $preferences && $(fingerprint) == "$snapshot" ]] || { echo 'Preferences changed while the menu was open. Reopen the setting.'; exit 1; }
  override="$repo/hosts/$(jq -r .host "$config")/home-variables.nix"
  if [[ -e $override ]] && read_values "$override" | jq -e --arg key "$key" 'any(paths; . == ($key | split(".")))' >/dev/null; then
    echo 'This preference is overridden by the host configuration.'; exit 1
  fi
  candidate=$(mktemp "${preferences%/*}/.settings-XXXXXXXX.nix") || exit 1
  trap 'rm -f -- "$candidate"' EXIT
  leaf=${key##*.}
  # JSON strings are Nix literals after escaping interpolation. Pass through
  # the environment: awk -v would interpret backslashes a second time.
  export SETTINGS_LEAF="$leaf" SETTINGS_LITERAL
  SETTINGS_LITERAL=$(jq -r 'if type == "string" then tojson | split("${") | join("\\${") else tojson end' <<< "$value")
  gawk '
    BEGIN { leaf = ENVIRON["SETTINGS_LEAF"]; literal = ENVIRON["SETTINGS_LITERAL"] }
    { declarations += gsub("\\<" leaf "[[:space:]]*=", "&") }
    match($0, "^([[:space:]]*" leaf "[[:space:]]*=[[:space:]]*)(\"([^\"\\\\]|\\\\.)*\"|true|false|null|-?[0-9]+(\\.[0-9]+)?)([[:space:]]*;[^\\n]*)$", p) {
      # Preserve a float literal when the new number happens to be whole.
      if (p[2] ~ /^-?[0-9]+\./ && literal ~ /^-?[0-9]+$/) literal = literal ".0"
      $0 = p[1] literal p[5]; matches++
    }
    { print }
    END { if (matches != 1 || declarations != 1) { print "Use one simple literal assignment; edit expressions or ambiguous keys manually." > "/dev/stderr"; exit 1 } }
  ' "$preferences" > "$candidate" || exit 1
  chmod --reference="$preferences" "$candidate" || exit 1
  validator=$(jq -r .validator "$config")
  nix-instantiate --eval --strict --json "$validator" \
    --argstr original "$preferences" --argstr candidate "$candidate" --argstr key "$key" \
    --argstr valueJSON "$value" --argstr fontSizesJSON "$(jq -c .fontSizes "$config")" >/dev/null || exit 1
  [[ ! -L $preferences && $(fingerprint) == "$snapshot" ]] || { echo 'Preferences changed during validation. Nothing was saved.'; exit 1; }
  mv -T -- "$candidate" "$preferences"
)

launch_apply() {
  local terminal fish
  terminal=$(jq -r .terminal "$config")
  fish=$(jq -r .fish "$config")
  # Detach all standard streams so Rofi does not wait for the rebuild.
  "$terminal" -e "$fish" --interactive --command \
    "home-rebuild; set -l result \$status; read -P 'Press Enter to close… '; exit \$result" \
    </dev/null >/dev/null 2>&1 &
}

case ${ROFI_RETV:-0} in
  0) main_menu ;;
  1|2)
    action=${ROFI_INFO:-}
    stage=$(jq -r '.stage // "main"' <<< "$state")
    if [[ ${ROFI_RETV} == 1 && $action == back ]]; then main_menu
    elif [[ $stage == edit ]]; then confirm_edit "${1:-}"
    elif [[ $stage == confirm && ${ROFI_RETV} == 1 && ( $action == save || $action == save-apply ) ]]; then
      if message=$(save_edit 2>&1); then
        if [[ $action == save-apply ]]; then launch_apply; else main_menu 'Setting saved. Apply with home-rebuild when ready.'; fi
      else main_menu "$(printf '%s' "$message" | html)"; fi
    elif [[ $stage == apply && ${ROFI_RETV} == 1 && $action == apply-now ]]; then launch_apply
    elif [[ ${ROFI_RETV} == 1 && $action == apply ]]; then
      state='{"stage":"apply"}'
      header 'Apply saved settings' true 'Builds and activates all saved Home Manager changes, including other pending edits.'
      row Apply apply-now
      row Cancel back
    elif [[ ${ROFI_RETV} == 1 && $action == close ]]; then exit 0
    elif [[ $stage == main && ${ROFI_RETV} == 1 ]]; then edit_menu "$action"
    else main_menu 'Select a listed action.'; fi ;;
  *) main_menu ;;
esac
