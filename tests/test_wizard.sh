#!/bin/sh
set -e

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$CURRENT_DIR/.." && pwd)"
TEST_TMP_ROOT="$CURRENT_DIR/.wizard-test-tmp"

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

# Helper: run wizard with piped input, capture output files
run_wizard() {
  _input="$1"
  _tmpdir="$(make_test_dir)"
  _toml_out="$_tmpdir/tmux.toml"
  _local_out="$_tmpdir/tmux.conf.local"
  # Create a minimal .tmux.conf.local for the wizard to write into
  printf '# test\n' > "$_local_out"
  printf '%s\n' "$_input" | \
    TMUX_CONF="$_tmpdir/tmux.conf" \
    TMUX_CONF_LOCAL="$_local_out" \
    WIZARD_TOML_PATH="$_toml_out" \
    WIZARD_NON_INTERACTIVE=1 \
    sh "$WIZARD" > "$_tmpdir/stdout" 2>"$_tmpdir/stderr" || true
  printf '%s' "$_tmpdir"
}

cleanup_test_root() {
  rm -rf "$TEST_TMP_ROOT"
}

trap cleanup_test_root EXIT INT TERM

# --- Test: quick setup produces valid TOML ---
# Input: N (no SR), 1 (quick), 1 (C-b prefix), 2 (mouse off),
#        1 (dark theme), 2 (clipboard off), 2 (a11y disabled),
#        1 (24b auto), 1 (pane path on), 1 (TPM on), y (apply)
tmpdir="$(run_wizard "N
1
1
2
1
2
2
1
1
1
y")"
assert_match '\[general\]' "$(cat "$tmpdir/tmux.toml")" "quick setup produces [general] section"
assert_match 'new_pane_retain_current_path = true' "$(cat "$tmpdir/tmux.toml")" "quick setup sets pane path"
rm -rf "$tmpdir"

# --- Test: accessible preset ---
# Input: y (SR), 2 (preset), 3 (accessible), y (apply)
tmpdir="$(run_wizard "y
2
3
y")"
assert_match 'enabled = "enabled"' "$(cat "$tmpdir/tmux.toml")" "accessible preset enables a11y"
assert_match 'display_time = 5000' "$(cat "$tmpdir/tmux.toml")" "accessible preset sets display_time"
rm -rf "$tmpdir"

# --- Test: SR mode output has no non-ASCII ---
tmpdir="$(run_wizard "y
2
3
y")"
_non_ascii="$(LC_ALL=C tr -d '[\000-\177]' < "$tmpdir/stdout" | wc -c | tr -d ' ')"
assert_eq "0" "$_non_ascii" "SR mode has no non-ASCII in prompts"
rm -rf "$tmpdir"

# --- Test: wizard-managed block is idempotent ---
tmpdir="$(make_test_dir)"
_local="$tmpdir/tmux.conf.local"
printf '# existing content\nset -g status-position top\n' > "$_local"
# First run
printf 'N\n1\n2\n1\n1\n2\n2\n1\n1\n1\ny\n' | \
  TMUX_CONF="$tmpdir/tmux.conf" TMUX_CONF_LOCAL="$_local" \
  WIZARD_TOML_PATH="$tmpdir/tmux.toml" WIZARD_NON_INTERACTIVE=1 \
  sh "$WIZARD" >/dev/null 2>&1 || true
count1="$(grep -c 'wizard-managed' "$_local")"
# Second run (same answers)
printf 'N\n1\n2\n1\n1\n2\n2\n1\n1\n1\ny\n' | \
  TMUX_CONF="$tmpdir/tmux.conf" TMUX_CONF_LOCAL="$_local" \
  WIZARD_TOML_PATH="$tmpdir/tmux.toml" WIZARD_NON_INTERACTIVE=1 \
  sh "$WIZARD" >/dev/null 2>&1 || true
count2="$(grep -c 'wizard-managed' "$_local")"
assert_eq "$count1" "$count2" "wizard-managed block count unchanged on rerun"
assert_match 'status-position top' "$(cat "$_local")" "existing content preserved"
rm -rf "$tmpdir"

# --- Test: wizard-managed block uses #!important on raw tmux commands ---
tmpdir="$(run_wizard "N
1
1
1
1
2
2
1
1
1
y")"
assert_match '#!important' "$(cat "$tmpdir/tmux.conf.local")" \
  "wizard-managed raw tmux uses #!important"
rm -rf "$tmpdir"

# --- Test: Ctrl+C (empty input / broken pipe) produces no TOML file ---
tmpdir="$(make_test_dir)"
printf '' | \
  TMUX_CONF="$tmpdir/tmux.conf" TMUX_CONF_LOCAL="$tmpdir/tmux.conf.local" \
  WIZARD_TOML_PATH="$tmpdir/tmux.toml" WIZARD_NON_INTERACTIVE=1 \
  sh "$WIZARD" >/dev/null 2>&1 || true
_toml_exists=0
[ -f "$tmpdir/tmux.toml" ] && _toml_exists=1
assert_eq "0" "$_toml_exists" "no TOML on empty input"
rm -rf "$tmpdir"

# --- Test: existing tmux.toml pre-fills values ---
tmpdir="$(make_test_dir)"
printf '# test\n' > "$tmpdir/tmux.conf.local"
printf '[accessibility]\nenabled = "enabled"\n' > "$tmpdir/tmux.toml"
cp "$ROOT_DIR/.tmux.conf" "$tmpdir/tmux.conf"
# SR_MODE auto-detected from accessibility=enabled, so skip SR question
printf '2\n3\ny\n' | \
  TMUX_CONF="$tmpdir/tmux.conf" TMUX_CONF_LOCAL="$tmpdir/tmux.conf.local" \
  WIZARD_TOML_PATH="$tmpdir/tmux.toml" WIZARD_NON_INTERACTIVE=1 \
  sh "$WIZARD" >/dev/null 2>&1 || true
assert_match '\[accessibility\]' "$(cat "$tmpdir/tmux.toml")" "existing TOML rewritten correctly"
rm -rf "$tmpdir"

# --- Test: --rollback with single TOML backup restores correctly ---
tmpdir="$(make_test_dir)"
printf '[general]\nnew_pane_retain_current_path = false\n' > "$tmpdir/tmux.toml"
printf '[general]\nnew_pane_retain_current_path = true\n' > "$tmpdir/tmux.toml.bak.20260101-120000"
printf '# existing\n' > "$tmpdir/tmux.conf.local"
printf '1\ny\n' | \
  TMUX_CONF="$tmpdir/tmux.conf" TMUX_CONF_LOCAL="$tmpdir/tmux.conf.local" \
  WIZARD_TOML_PATH="$tmpdir/tmux.toml" \
  sh "$WIZARD" --rollback >/dev/null 2>&1
assert_match 'true' "$(cat "$tmpdir/tmux.toml")" "rollback restores TOML backup"
rm -rf "$tmpdir"

# --- Test: --rollback with no backups exits cleanly ---
tmpdir="$(make_test_dir)"
printf '# test\n' > "$tmpdir/tmux.conf.local"
output="$(TMUX_CONF="$tmpdir/tmux.conf" TMUX_CONF_LOCAL="$tmpdir/tmux.conf.local" \
  WIZARD_TOML_PATH="$tmpdir/tmux.toml" \
  sh "$WIZARD" --rollback 2>&1)"
assert_match '[Nn]o backup' "$output" "no-backup message shown"
rm -rf "$tmpdir"

# --- Test: --rollback with empty backup is rejected ---
tmpdir="$(make_test_dir)"
printf '[general]\n' > "$tmpdir/tmux.toml"
printf '# test\n' > "$tmpdir/tmux.conf.local"
: > "$tmpdir/tmux.toml.bak.20260101-120000"
output="$(printf '1\ny\n' | \
  TMUX_CONF="$tmpdir/tmux.conf" TMUX_CONF_LOCAL="$tmpdir/tmux.conf.local" \
  WIZARD_TOML_PATH="$tmpdir/tmux.toml" \
  sh "$WIZARD" --rollback 2>&1 || true)"
assert_match 'empty' "$output" "empty backup rejected"
rm -rf "$tmpdir"

# --- Test: cancel leaves files unchanged ---
# With one backup: option 1 = backup, option 2 = Cancel
tmpdir="$(make_test_dir)"
printf '[general]\ncurrent = true\n' > "$tmpdir/tmux.toml"
printf '[general]\nold = true\n' > "$tmpdir/tmux.toml.bak.20260101-120000"
printf '# test\n' > "$tmpdir/tmux.conf.local"
printf '2\n' | \
  TMUX_CONF="$tmpdir/tmux.conf" TMUX_CONF_LOCAL="$tmpdir/tmux.conf.local" \
  WIZARD_TOML_PATH="$tmpdir/tmux.toml" \
  sh "$WIZARD" --rollback >/dev/null 2>&1
assert_match 'current = true' "$(cat "$tmpdir/tmux.toml")" "cancel preserves state"
rm -rf "$tmpdir"

# --- Test: _hex_to_rgb converts correctly ---
WIZARD_SOURCE_ONLY=1 . "$WIZARD"
_hex_to_rgb "FF8000"
assert_eq "255" "$_r" "hex_to_rgb red channel"
assert_eq "128" "$_g" "hex_to_rgb green channel"
assert_eq "0" "$_b" "hex_to_rgb blue channel"

# --- Test: _hex_to_rgb rejects invalid hex ---
_hex_to_rgb "GGGGGG" || true
assert_eq "" "$_r" "invalid hex produces empty red channel"

test_summary "Wizard"
