#!/bin/sh
# test_accessibility.sh - Tests for _apply_accessibility
set -e
. "$(dirname "$0")/lib.sh"

TMUX_CONF="$(dirname "$0")/../.tmux.conf"

# Extract all needed helper functions
eval "$(sed -n '/^# _is_true/,/^# }/{ s/^# //; p; }' "$TMUX_CONF")"
eval "$(sed -n '/^# _is_enabled/,/^# }/{ s/^# //; p; }' "$TMUX_CONF")"
eval "$(sed -n '/^# _is_disabled/,/^# }/{ s/^# //; p; }' "$TMUX_CONF")"

# Extract _apply_accessibility (will fail until we implement it)
eval "$(sed -n '/^# _apply_accessibility/,/^# }$/{ s/^# //; p; }' "$TMUX_CONF")" 2>/dev/null || true

# Mock tmux command to capture what would be set
_tmux_commands=""
tmux() {
  _tmux_commands="$_tmux_commands
tmux $*"
}

# --- Test: disabled mode is a no-op ---
printf "test_accessibility: disabled mode\n"
_tmux_commands=""
tmux_conf_accessibility="disabled"
_tmux_version=3400
tmux_conf_accessibility_display_time=5000
tmux_conf_accessibility_visual_activity=true
tmux_conf_accessibility_theme=auto
_apply_accessibility 2>/dev/null || true
assert_eq "" "$_tmux_commands" "disabled mode produces no tmux commands"

# --- Test: enabled mode sets cursor override ---
printf "\ntest_accessibility: enabled mode sets civis@\n"
_tmux_commands=""
tmux_conf_accessibility="enabled"
_tmux_version=3400
tmux_conf_accessibility_display_time=5000
tmux_conf_accessibility_visual_activity=true
tmux_conf_accessibility_theme=auto
unset tmux_conf_theme_colour_1
_apply_accessibility 2>/dev/null || true
assert_match "terminal-overrides.*civis@" "$_tmux_commands" "enabled sets civis@ override"

# --- Test: version < 3300 skips civis@ ---
printf "\ntest_accessibility: version < 3300 skips civis@\n"
_tmux_commands=""
tmux_conf_accessibility="enabled"
_tmux_version=3200
tmux_conf_accessibility_display_time=5000
tmux_conf_accessibility_visual_activity=true
tmux_conf_accessibility_theme=auto
unset tmux_conf_theme_colour_1
_apply_accessibility 2>/dev/null || true
assert_not_match "civis@" "$_tmux_commands" "version 3200 does not set civis@"
assert_match "display-message" "$_tmux_commands" "version 3200 emits warning"

# --- Test: theme colour defaults are set (dark) ---
printf "\ntest_accessibility: dark theme sets colour_1\n"
_tmux_commands=""
tmux_conf_accessibility="enabled"
_tmux_version=3400
tmux_conf_accessibility_display_time=5000
tmux_conf_accessibility_visual_activity=true
tmux_conf_accessibility_theme=dark
unset tmux_conf_theme_colour_1
_apply_accessibility 2>/dev/null || true
assert_eq "#1a1a2e" "${tmux_conf_theme_colour_1}" "dark theme sets colour_1 to #1a1a2e"

# --- Test: light theme sets colour_1 ---
printf "\ntest_accessibility: light theme sets colour_1\n"
_tmux_commands=""
tmux_conf_accessibility="enabled"
_tmux_version=3400
tmux_conf_accessibility_display_time=5000
tmux_conf_accessibility_visual_activity=true
tmux_conf_accessibility_theme=light
unset tmux_conf_theme_colour_1
_apply_accessibility 2>/dev/null || true
assert_eq "#f5f5f0" "${tmux_conf_theme_colour_1}" "light theme sets colour_1 to #f5f5f0"

# --- Test: visual_activity=false skips visual-* ---
printf "\ntest_accessibility: visual_activity=false skips visual settings\n"
_tmux_commands=""
tmux_conf_accessibility="enabled"
_tmux_version=3400
tmux_conf_accessibility_display_time=5000
tmux_conf_accessibility_visual_activity=false
tmux_conf_accessibility_theme=dark
unset tmux_conf_theme_colour_1
_apply_accessibility 2>/dev/null || true
assert_not_match "visual-activity" "$_tmux_commands" "visual_activity=false skips visual-activity"

# --- Test: invalid value triggers warning ---
printf "\ntest_accessibility: invalid value triggers warning\n"
_tmux_commands=""
tmux_conf_accessibility="yes"
_tmux_version=3400
tmux_conf_accessibility_display_time=5000
tmux_conf_accessibility_visual_activity=true
tmux_conf_accessibility_theme=auto
_apply_accessibility 2>/dev/null || true
assert_match "display-message.*unrecognized" "$_tmux_commands" "invalid value emits warning"

# --- Test: separator defaults ---
printf "\ntest_accessibility: sets ASCII separators\n"
_tmux_commands=""
tmux_conf_accessibility="enabled"
_tmux_version=3400
tmux_conf_accessibility_display_time=5000
tmux_conf_accessibility_visual_activity=true
tmux_conf_accessibility_theme=dark
unset tmux_conf_theme_left_separator_main
_apply_accessibility 2>/dev/null || true
assert_eq "|" "${tmux_conf_theme_left_separator_main}" "sets left separator to pipe"
assert_eq "|" "${tmux_conf_theme_right_separator_main}" "sets right separator to pipe"

# --- Test: status-interval is set ---
printf "\ntest_accessibility: sets status-interval 60\n"
_tmux_commands=""
tmux_conf_accessibility="enabled"
_tmux_version=3400
tmux_conf_accessibility_display_time=5000
tmux_conf_accessibility_visual_activity=true
tmux_conf_accessibility_theme=dark
unset tmux_conf_theme_colour_1
_apply_accessibility 2>/dev/null || true
assert_match "status-interval 60" "$_tmux_commands" "sets status-interval to 60"

test_summary
