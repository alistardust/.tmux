#!/bin/sh
# test_bindings.sh - Tests for accessibility keybinding generation
set -e
. "$(dirname "$0")/lib.sh"

TMUX_CONF="$(dirname "$0")/../.tmux.conf"

# Extract helpers
eval "$(sed -n '/^# _is_true/,/^# }/{ s/^# //; p; }' "$TMUX_CONF")"
eval "$(sed -n '/^# _is_enabled/,/^# }/{ s/^# //; p; }' "$TMUX_CONF")"
eval "$(sed -n '/^# _is_disabled/,/^# }/{ s/^# //; p; }' "$TMUX_CONF")"

# Extract accessibility bindings function
eval "$(sed -n '/^# _apply_accessibility_bindings/,/^# }$/{ s/^# //; p; }' "$TMUX_CONF")" 2>/dev/null || true

# Mock tmux
_tmux_commands=""
tmux() {
  _tmux_commands="$_tmux_commands
tmux $*"
}

# --- Test: disabled produces no bindings ---
printf "test_bindings: disabled mode\n"
_tmux_commands=""
tmux_conf_accessibility_keys="disabled"
tmux_conf_accessibility_display_time=5000
_apply_accessibility_bindings 2>/dev/null || true
assert_eq "" "$_tmux_commands" "disabled mode produces no bindings"

# --- Test: enabled adds pane navigation ---
printf "\ntest_bindings: enabled adds arrow pane nav\n"
_tmux_commands=""
tmux_conf_accessibility_keys="enabled"
tmux_conf_accessibility_display_time=5000
_apply_accessibility_bindings 2>/dev/null || true
assert_match "bind.*Left.*select-pane -L" "$_tmux_commands" "binds Left to select-pane -L"
assert_match "bind.*Right.*select-pane -R" "$_tmux_commands" "binds Right to select-pane -R"
assert_match "bind.*Up.*select-pane -U" "$_tmux_commands" "binds Up to select-pane -U"
assert_match "bind.*Down.*select-pane -D" "$_tmux_commands" "binds Down to select-pane -D"

# --- Test: enabled adds resize bindings ---
printf "\ntest_bindings: enabled adds M-arrow resize\n"
assert_match "bind.*M-Left.*resize-pane -L" "$_tmux_commands" "binds M-Left to resize-pane -L"
assert_match "bind.*M-Right.*resize-pane -R" "$_tmux_commands" "binds M-Right to resize-pane -R"

# --- Test: enabled adds window navigation ---
printf "\ntest_bindings: enabled adds C-arrow window nav\n"
assert_match "bind.*C-Left.*previous-window" "$_tmux_commands" "binds C-Left to previous-window"
assert_match "bind.*C-Right.*next-window" "$_tmux_commands" "binds C-Right to next-window"

# --- Test: enabled adds pane announce ---
printf "\ntest_bindings: enabled adds pane announce\n"
assert_match "bind.*a.*display-message" "$_tmux_commands" "binds 'a' to display-message"
assert_match "Pane.*pane_index" "$_tmux_commands" "announce includes pane_index"

# --- Test: enabled adds help binding ---
printf "\ntest_bindings: enabled adds help binding\n"
assert_match "bind.*A.*display-message" "$_tmux_commands" "binds 'A' to display-message"
assert_match "Accessibility:" "$_tmux_commands" "help message starts with Accessibility:"

# --- Test: enabled adds choose-tree bindings ---
printf "\ntest_bindings: enabled adds choose-tree\n"
assert_match "bind.*s.*choose-tree" "$_tmux_commands" "binds 's' to choose-tree"
assert_match "bind.*w.*choose-tree" "$_tmux_commands" "binds 'w' to choose-tree"
assert_match "Session:" "$_tmux_commands" "choose-tree format includes Session:"

test_summary
