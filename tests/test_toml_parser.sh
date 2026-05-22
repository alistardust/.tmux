#!/bin/sh
set -e

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$CURRENT_DIR/.." && pwd)"

. "$CURRENT_DIR/lib.sh"

# Extract _parse_toml from .tmux.conf (handles nested braces in awk)
_extract_parse_toml() {
  awk '
    /^# _parse_toml\(\)/ { found=1; depth=0 }
    found {
      s = substr($0, 3)  # strip "# " prefix
      # Count braces on this line
      for (i=1; i<=length(s); i++) {
        c = substr(s, i, 1)
        if (c == "{") depth++
        if (c == "}") depth--
      }
      print s
      if (found && depth == 0 && s ~ /}/) exit
    }
  ' "$ROOT_DIR/.tmux.conf"
}

PARSE_TOML_CODE="$(_extract_parse_toml)"
if [ -z "$PARSE_TOML_CODE" ]; then
  printf 'FATAL: could not extract _parse_toml from .tmux.conf\n' >&2
  exit 1
fi

eval "$PARSE_TOML_CODE"

# Helper: run parser on inline TOML content
parse_inline() {
  printf '%s\n' "$1" | _parse_toml
}

# --- Test: empty input produces no output ---
result="$(parse_inline "")"
assert_eq "" "$result" "empty input produces no output"

# --- Test: comments and blank lines are skipped ---
result="$(parse_inline "# this is a comment

# another comment")"
assert_eq "" "$result" "comments and blanks produce no output"

# --- Test: simple section + key ---
result="$(parse_inline '[general]
new_pane_retain_current_path = true')"
assert_eq "tmux_conf_new_pane_retain_current_path=true" "$result" "general section key maps correctly"

# --- Test: theme colour (quoted string with #) ---
result="$(parse_inline '[theme]
colour_1 = "#080808"')"
assert_eq 'tmux_conf_theme_colour_1="#080808"' "$result" "quoted string with # is preserved and quoted"

# --- Test: boolean false ---
result="$(parse_inline '[clipboard]
copy_to_os_clipboard = false')"
assert_eq "tmux_conf_copy_to_os_clipboard=false" "$result" "boolean false passed through"

# --- Test: integer value ---
result="$(parse_inline '[accessibility]
display_time = 5000')"
assert_eq "tmux_conf_accessibility_display_time=5000" "$result" "integer value passed through"

# --- Test: string enum (quoted) ---
result="$(parse_inline '[accessibility]
enabled = "disabled"')"
assert_eq "tmux_conf_accessibility=disabled" "$result" "string enum unquoted in output"

# --- Test: value with dollar reference ---
result="$(parse_inline '[theme]
focused_pane_bg = "$tmux_conf_theme_colour_2"')"
assert_eq 'tmux_conf_theme_focused_pane_bg="$tmux_conf_theme_colour_2"' "$result" "dollar ref preserved and quoted"

# --- Test: value with tmux format ---
result="$(parse_inline '[theme]
terminal_title = "#h - #S - #I #W"')"
assert_eq 'tmux_conf_theme_terminal_title="#h - #S - #I #W"' "$result" "tmux format preserved and quoted"

# --- Test: inline comment stripped ---
result="$(parse_inline '[display]
colour_24b = auto # detect from env')"
assert_eq "tmux_conf_24b_colour=auto" "$result" "inline comment stripped"

# --- Test: empty quoted string ---
result="$(parse_inline '[status_bar]
window_status_separator = ""')"
assert_eq 'tmux_conf_theme_window_status_separator=' "$result" "empty string produces empty value"

# --- Test: unknown key produces warning on stderr ---
result="$(parse_inline '[general]
unknown_key = value' 2>/dev/null)"
assert_eq "" "$result" "unknown key produces no output"
# Verify warning is emitted
warn="$(parse_inline '[general]
unknown_key = value' 2>&1 >/dev/null)"
assert_match "warning.*unknown" "$warn" "unknown key emits warning on stderr"

# --- Test: multiple keys in sequence ---
result="$(parse_inline '[general]
new_pane_retain_current_path = true
new_pane_reconnect_ssh = false')"
expected="tmux_conf_new_pane_retain_current_path=true
tmux_conf_new_pane_reconnect_ssh=false"
assert_eq "$expected" "$result" "multiple keys in same section"

# --- Test: value with spaces ---
result="$(parse_inline '[status_bar]
left = " #{prefix} | #S | "')"
assert_eq 'tmux_conf_theme_status_left=" #{prefix} | #S | "' "$result" "value with spaces is quoted"

# --- Test: unknown section produces warning ---
result="$(parse_inline '[nonexistent]
key = value' 2>/dev/null)"
assert_eq "" "$result" "unknown section produces no output"

# --- Test: malformed line (no = sign) skipped silently ---
result="$(parse_inline '[general]
this is not valid toml
new_pane_retain_current_path = true')"
assert_eq "tmux_conf_new_pane_retain_current_path=true" "$result" "malformed line skipped"

# --- Test: quoted value with inline comment after closing quote ---
result="$(parse_inline '[theme]
colour_1 = "#080808" # dark grey')"
assert_eq 'tmux_conf_theme_colour_1="#080808"' "$result" "inline comment after quoted value stripped"

# --- Test: quoted value with multiple spaces before inline comment ---
result="$(parse_inline '[theme]
colour_1 = "#080808"    # dark grey')"
assert_eq 'tmux_conf_theme_colour_1="#080808"' "$result" "inline comment with extra spaces stripped"

# --- Test: TOML path detection (integration) ---
# Verify _parse_toml function is callable by invoking it on empty input
_result="$(_parse_toml < /dev/null 2>&1)" || true
assert_eq "" "$_result" "_parse_toml callable with empty input"

test_summary "TOML Parser"
