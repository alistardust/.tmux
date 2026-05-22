#!/bin/sh
set -e

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$CURRENT_DIR/.." && pwd)"
TEST_TMP_ROOT="$CURRENT_DIR/.migration-test-tmp"

. "$CURRENT_DIR/lib.sh"

WIZARD="$ROOT_DIR/setup-wizard.sh"

make_test_dir() {
  _counter=0
  [ -d "$TEST_TMP_ROOT" ] || mkdir -p "$TEST_TMP_ROOT"

  while [ "$_counter" -lt 100 ]; do
    _dir="$TEST_TMP_ROOT/$$-$_counter"
    if mkdir "$_dir" 2>/dev/null; then
      printf '%s' "$_dir"
      return 0
    fi
    _counter=$((_counter + 1))
  done

  return 1
}

cleanup_test_root() {
  rm -rf "$TEST_TMP_ROOT"
}

trap cleanup_test_root EXIT INT TERM

# Helper: run migration mode
run_migration() {
  _input_local="$1"
  _tmpdir="$(make_test_dir)"
  cp "$ROOT_DIR/.tmux.conf" "$_tmpdir/tmux.conf"
  printf '%s\n' "$_input_local" > "$_tmpdir/tmux.conf.local"
  printf 'y\n' | \
    TMUX_CONF="$_tmpdir/tmux.conf" \
    TMUX_CONF_LOCAL="$_tmpdir/tmux.conf.local" \
    WIZARD_TOML_PATH="$_tmpdir/tmux.toml" \
    WIZARD_MIGRATE_ONLY=1 \
    sh "$WIZARD" >/dev/null 2>&1
  printf '%s' "$_tmpdir"
}

# --- Test: simple variable migrated ---
tmpdir="$(run_migration 'tmux_conf_new_pane_retain_current_path=true')"
assert_match 'new_pane_retain_current_path = true' "$(cat "$tmpdir/tmux.toml")" \
  "simple var migrated to TOML"
assert_match '#\[migrated-to-toml\]' "$(cat "$tmpdir/tmux.conf.local")" \
  "migrated var commented in local"
rm -rf "$tmpdir"

# --- Test: #!important line NOT migrated ---
tmpdir="$(run_migration 'tmux_conf_theme_colour_1="#ff0000" #!important')"
assert_match '#!important' "$(cat "$tmpdir/tmux.conf.local")" \
  "important line preserved in local"
rm -rf "$tmpdir"

# --- Test: raw tmux command preserved ---
tmpdir="$(run_migration 'tmux_conf_new_pane_retain_current_path=true
set -g status-position top')"
assert_match 'status-position top' "$(cat "$tmpdir/tmux.conf.local")" \
  "raw tmux command preserved"
rm -rf "$tmpdir"

# --- Test: commented variable left in place ---
tmpdir="$(run_migration '#tmux_conf_theme_colour_1="#080808"')"
assert_match '#tmux_conf_theme' "$(cat "$tmpdir/tmux.conf.local")" \
  "commented var left in local"
rm -rf "$tmpdir"

# --- Test: backup created ---
tmpdir="$(run_migration 'tmux_conf_new_pane_retain_current_path=true')"
_has_backup="$(find "$tmpdir" -name '*pre-toml*' | wc -l | tr -d ' ')"
assert_match '[1-9]' "$_has_backup" "backup file created"
rm -rf "$tmpdir"

# --- Test: %if/%endif block NOT migrated ---
tmpdir="$(run_migration '%if #{>=:#{version},3.2}
tmux_conf_theme_colour_1="#080808"
%endif')"
assert_match '%if' "$(cat "$tmpdir/tmux.conf.local")" \
  "conditional block preserved in local"
rm -rf "$tmpdir"

# --- Test: shell expression NOT migrated ---
tmpdir="$(run_migration 'tmux_conf_theme_status_left="$(hostname)"')"
assert_match 'hostname' "$(cat "$tmpdir/tmux.conf.local")" \
  "shell expression preserved in local"
rm -rf "$tmpdir"

test_summary "Migration"
