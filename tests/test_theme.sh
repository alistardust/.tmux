#!/bin/sh
# test_theme.sh - Tests for theme defaults when accessibility is active
set -e
. "$(dirname "$0")/lib.sh"

TMUX_CONF="$(dirname "$0")/../.tmux.conf"

# Extract helpers and accessibility function
eval "$(sed -n '/^# _is_true/,/^# }/{ s/^# //; p; }' "$TMUX_CONF")"
eval "$(sed -n '/^# _is_enabled/,/^# }/{ s/^# //; p; }' "$TMUX_CONF")"
eval "$(sed -n '/^# _is_disabled/,/^# }/{ s/^# //; p; }' "$TMUX_CONF")"
eval "$(sed -n '/^# _apply_accessibility/,/^# }$/{ s/^# //; p; }' "$TMUX_CONF")"

# Mock tmux
tmux() { :; }

# --- Test: dark theme full palette ---
printf "test_theme: dark palette completeness\n"
tmux_conf_accessibility="enabled"
_tmux_version=3400
tmux_conf_accessibility_display_time=5000
tmux_conf_accessibility_visual_activity=true
tmux_conf_accessibility_theme=dark
# Unset all colours
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17; do
  eval "unset tmux_conf_theme_colour_$i"
done
unset tmux_conf_theme_focused_pane_bg
_apply_accessibility
assert_eq "#1a1a2e" "$tmux_conf_theme_colour_1" "dark colour_1"
assert_eq "#00d4aa" "$tmux_conf_theme_colour_4" "dark colour_4 (active)"
assert_eq "#ffd700" "$tmux_conf_theme_colour_5" "dark colour_5 (alert)"
assert_eq "#e0e0e0" "$tmux_conf_theme_colour_7" "dark colour_7 (text)"
assert_eq "#ff8c00" "$tmux_conf_theme_colour_10" "dark colour_10 (error)"
assert_eq "#1e1e3a" "$tmux_conf_theme_focused_pane_bg" "dark focused_pane_bg"

# --- Test: light theme full palette ---
printf "\ntest_theme: light palette completeness\n"
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17; do
  eval "unset tmux_conf_theme_colour_$i"
done
unset tmux_conf_theme_focused_pane_bg
tmux_conf_accessibility_theme=light
_apply_accessibility
assert_eq "#f5f5f0" "$tmux_conf_theme_colour_1" "light colour_1"
assert_eq "#007a5e" "$tmux_conf_theme_colour_4" "light colour_4 (active)"
assert_eq "#b8860b" "$tmux_conf_theme_colour_5" "light colour_5 (alert)"
assert_eq "#1a1a1a" "$tmux_conf_theme_colour_7" "light colour_7 (text)"
assert_eq "#cc3300" "$tmux_conf_theme_colour_10" "light colour_10 (error)"
assert_eq "#ededea" "$tmux_conf_theme_focused_pane_bg" "light focused_pane_bg"

# --- Test: user override is preserved ---
printf "\ntest_theme: user override preserved\n"
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17; do
  eval "unset tmux_conf_theme_colour_$i"
done
tmux_conf_theme_colour_4="#custom"
tmux_conf_accessibility_theme=dark
_apply_accessibility
assert_eq "#custom" "$tmux_conf_theme_colour_4" "user colour_4 override preserved"
assert_eq "#1a1a2e" "$tmux_conf_theme_colour_1" "non-overridden colour_1 still set"

# --- Test: auto-detect dark (COLORFGBG unset) ---
printf "\ntest_theme: auto-detect defaults to dark\n"
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17; do
  eval "unset tmux_conf_theme_colour_$i"
done
unset COLORFGBG
tmux_conf_accessibility_theme=auto
_apply_accessibility
assert_eq "#1a1a2e" "$tmux_conf_theme_colour_1" "auto with no COLORFGBG defaults to dark"

# --- Test: auto-detect light (COLORFGBG=0;15) ---
printf "\ntest_theme: auto-detect light from COLORFGBG\n"
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17; do
  eval "unset tmux_conf_theme_colour_$i"
done
COLORFGBG="0;15"
tmux_conf_accessibility_theme=auto
_apply_accessibility
assert_eq "#f5f5f0" "$tmux_conf_theme_colour_1" "COLORFGBG=0;15 detects light theme"
unset COLORFGBG

test_summary
