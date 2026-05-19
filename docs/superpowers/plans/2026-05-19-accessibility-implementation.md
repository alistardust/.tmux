# Accessibility Mode Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a comprehensive, opt-in accessibility mode to Oh my tmux! that provides high-contrast themes (dark+light), screen reader friendly status/menus, accessible keybindings, and cursor visibility fixes.

**Architecture:** A new `_apply_accessibility` function runs synchronously before the parallel theme/bindings block in `_apply_configuration`. It sets shell variable defaults that `_apply_theme` then reads. Keybindings are added in a new section within `_apply_bindings`. All features are disabled by default; activation is via `tmux_conf_accessibility=enabled`.

**Tech Stack:** POSIX shell (embedded in `.tmux.conf`), tmux configuration commands, ShellCheck for linting.

**Spec:** `docs/superpowers/specs/2026-05-19-accessibility-design.md`

---

## File Structure

| File | Responsibility |
|------|---------------|
| `.tmux.conf` (lines ~207-208, new function) | `_apply_accessibility` function: theme auto-detect, version check, variable defaults, tmux settings |
| `.tmux.conf` (lines ~1090-1106, within `_apply_bindings`) | Accessibility keybindings section |
| `.tmux.conf` (lines ~1870, in `_apply_configuration`) | Call to `_apply_accessibility` before parallel block |
| `.tmux.conf.local` (end of file, before custom functions) | Accessibility variables + commented theme block |
| `README.md` | New "Accessibility" section |
| `tests/run_tests.sh` | Test runner script |
| `tests/lib.sh` | Shared assertion functions (sourced, not executed) |
| `tests/test_helpers.sh` | Tests for `_is_true`, `_is_disabled`, `_is_enabled` |
| `tests/test_accessibility.sh` | Tests for `_apply_accessibility` logic |
| `tests/test_bindings.sh` | Tests for accessibility keybinding generation |
| `tests/test_theme.sh` | Tests for theme variable defaults |

---

## Chunk 1: Test Infrastructure and Helper Tests

### Task 1: Create test runner

**Files:**
- Create: `tests/run_tests.sh`

- [ ] **Step 1: Create the test runner script**

```bash
#!/bin/sh
# run_tests.sh - Test runner for Oh my tmux!
# Usage: ./tests/run_tests.sh [test_file]
# Runs all test_*.sh files in the tests/ directory, or a single file if specified.

set -e

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
PASS=0
FAIL=0
ERRORS=""

# Color output (disabled if not a tty)
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  RESET='\033[0m'
else
  GREEN=''
  RED=''
  RESET=''
fi

run_test_file() {
  file="$1"
  printf "Running %s...\n" "$(basename "$file")"
  if sh "$file"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS  FAIL: $(basename "$file")\n"
  fi
}

if [ -n "$1" ]; then
  run_test_file "$1"
else
  for f in "$TESTS_DIR"/test_*.sh; do
    [ -f "$f" ] || continue
    run_test_file "$f"
  done
fi

printf "\n--- Results ---\n"
printf "${GREEN}PASS: %d${RESET}\n" "$PASS"
if [ "$FAIL" -gt 0 ]; then
  printf "${RED}FAIL: %d${RESET}\n" "$FAIL"
  printf "\nFailed tests:\n%b" "$ERRORS"
  exit 1
fi
printf "All tests passed.\n"
```

- [ ] **Step 2: Make executable and verify it runs (no tests yet)**

Run: `chmod +x tests/run_tests.sh && sh tests/run_tests.sh`
Expected: "All tests passed." (0 files found, 0 pass, 0 fail)

- [ ] **Step 3: Create test helper library**

Create `tests/lib.sh` with assertion functions used by all test files:

```bash
#!/bin/sh
# lib.sh - Shared test assertions
# Source this from test files: . "$(dirname "$0")/lib.sh"

_TEST_COUNT=0
_TEST_FAIL=0

assert_eq() {
  _TEST_COUNT=$((_TEST_COUNT + 1))
  expected="$1"
  actual="$2"
  msg="${3:-assertion $_TEST_COUNT}"
  if [ "$expected" = "$actual" ]; then
    printf "  ok %d - %s\n" "$_TEST_COUNT" "$msg"
  else
    _TEST_FAIL=$((_TEST_FAIL + 1))
    printf "  FAIL %d - %s\n" "$_TEST_COUNT" "$msg"
    printf "    expected: '%s'\n" "$expected"
    printf "    actual:   '%s'\n" "$actual"
  fi
}

assert_match() {
  _TEST_COUNT=$((_TEST_COUNT + 1))
  pattern="$1"
  actual="$2"
  msg="${3:-assertion $_TEST_COUNT}"
  if printf '%s' "$actual" | grep -qE "$pattern"; then
    printf "  ok %d - %s\n" "$_TEST_COUNT" "$msg"
  else
    _TEST_FAIL=$((_TEST_FAIL + 1))
    printf "  FAIL %d - %s\n" "$_TEST_COUNT" "$msg"
    printf "    pattern:  '%s'\n" "$pattern"
    printf "    actual:   '%s'\n" "$actual"
  fi
}

assert_not_match() {
  _TEST_COUNT=$((_TEST_COUNT + 1))
  pattern="$1"
  actual="$2"
  msg="${3:-assertion $_TEST_COUNT}"
  if ! printf '%s' "$actual" | grep -qE "$pattern"; then
    printf "  ok %d - %s\n" "$_TEST_COUNT" "$msg"
  else
    _TEST_FAIL=$((_TEST_FAIL + 1))
    printf "  FAIL %d - %s\n" "$_TEST_COUNT" "$msg"
    printf "    should not match: '%s'\n" "$pattern"
    printf "    actual:           '%s'\n" "$actual"
  fi
}

test_summary() {
  printf "\n  %d tests, %d failures\n" "$_TEST_COUNT" "$_TEST_FAIL"
  [ "$_TEST_FAIL" -eq 0 ]
}
```

- [ ] **Step 4: Commit test infrastructure**

```bash
git add tests/run_tests.sh tests/lib.sh
git commit -m "test: add test runner and assertion library

Basic POSIX shell test infrastructure:
- run_tests.sh: discovers and runs test_*.sh files
- lib.sh: assert_eq, assert_match, assert_not_match helpers (sourced, not glob-matched)

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 2: Test helper functions

**Files:**
- Create: `tests/test_helpers.sh`

- [ ] **Step 1: Write helper function tests**

```bash
#!/bin/sh
# test_helpers.sh - Tests for _is_true, _is_enabled, _is_disabled
set -e
. "$(dirname "$0")/lib.sh"

# Extract helper functions from .tmux.conf embedded script
# The functions are on lines prefixed with "# " - strip the prefix
eval "$(sed -n '/^# _is_true/,/^# }/{ s/^# //; p; }' "$(dirname "$0")/../.tmux.conf")"
eval "$(sed -n '/^# _is_enabled/,/^# }/{ s/^# //; p; }' "$(dirname "$0")/../.tmux.conf")"
eval "$(sed -n '/^# _is_disabled/,/^# }/{ s/^# //; p; }' "$(dirname "$0")/../.tmux.conf")"

printf "test_helpers: _is_true\n"
_is_true "true" && r=0 || r=1
assert_eq "0" "$r" "_is_true 'true' returns 0"
_is_true "yes" && r=0 || r=1
assert_eq "0" "$r" "_is_true 'yes' returns 0"
_is_true "1" && r=0 || r=1
assert_eq "0" "$r" "_is_true '1' returns 0"
_is_true "false" && r=0 || r=1
assert_eq "1" "$r" "_is_true 'false' returns 1"
_is_true "no" && r=0 || r=1
assert_eq "1" "$r" "_is_true 'no' returns 1"
_is_true "0" && r=0 || r=1
assert_eq "1" "$r" "_is_true '0' returns 1"
_is_true "" && r=0 || r=1
assert_eq "1" "$r" "_is_true '' returns 1"
_is_true "enabled" && r=0 || r=1
assert_eq "1" "$r" "_is_true 'enabled' returns 1"

printf "\ntest_helpers: _is_enabled\n"
_is_enabled "enabled" && r=0 || r=1
assert_eq "0" "$r" "_is_enabled 'enabled' returns 0"
_is_enabled "disabled" && r=0 || r=1
assert_eq "1" "$r" "_is_enabled 'disabled' returns 1"
_is_enabled "true" && r=0 || r=1
assert_eq "1" "$r" "_is_enabled 'true' returns 1"
_is_enabled "" && r=0 || r=1
assert_eq "1" "$r" "_is_enabled '' returns 1"

printf "\ntest_helpers: _is_disabled\n"
_is_disabled "disabled" && r=0 || r=1
assert_eq "0" "$r" "_is_disabled 'disabled' returns 0"
_is_disabled "enabled" && r=0 || r=1
assert_eq "1" "$r" "_is_disabled 'enabled' returns 1"
_is_disabled "false" && r=0 || r=1
assert_eq "1" "$r" "_is_disabled 'false' returns 1"
_is_disabled "" && r=0 || r=1
assert_eq "1" "$r" "_is_disabled '' returns 1"

test_summary
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `sh tests/run_tests.sh tests/test_helpers.sh`
Expected: All assertions pass (the functions already exist in .tmux.conf)

- [ ] **Step 3: Commit**

```bash
git add tests/test_helpers.sh
git commit -m "test: add helper function tests (_is_true, _is_enabled, _is_disabled)

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Chunk 2: Core Accessibility Function

### Task 3: Write failing tests for _apply_accessibility

**Files:**
- Create: `tests/test_accessibility.sh`

- [ ] **Step 1: Write test file for accessibility function**

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `sh tests/test_accessibility.sh`
Expected: FAIL (function does not exist yet)

- [ ] **Step 3: Implement `_apply_accessibility` in `.tmux.conf`**

Insert the new function after line 227 (after `_is_disabled`), following the `# ` prefix convention:

```bash
# _apply_accessibility() {
#   tmux_conf_accessibility=${tmux_conf_accessibility:-disabled}
#   tmux_conf_accessibility_display_time=${tmux_conf_accessibility_display_time:-5000}
#   tmux_conf_accessibility_visual_activity=${tmux_conf_accessibility_visual_activity:-true}
#   tmux_conf_accessibility_theme=${tmux_conf_accessibility_theme:-auto}
#
#   # validate input
#   if ! _is_disabled "$tmux_conf_accessibility" && ! _is_enabled "$tmux_conf_accessibility"; then
#     _display_time_ms=$(( tmux_conf_accessibility_display_time * 2 ))
#     tmux display-message -d "$_display_time_ms" "Accessibility: unrecognized value '$tmux_conf_accessibility', using 'disabled'. Valid: enabled, disabled"
#     return
#   fi
#
#   if _is_disabled "$tmux_conf_accessibility"; then
#     return
#   fi
#
#   # resolve theme (auto-detect or explicit)
#   _a11y_bg="dark"
#   case "$tmux_conf_accessibility_theme" in
#     light)
#       _a11y_bg="light"
#       ;;
#     dark)
#       _a11y_bg="dark"
#       ;;
#     *)
#       # auto-detect from $COLORFGBG
#       if [ -n "$COLORFGBG" ]; then
#         _bg_component="${COLORFGBG##*;}"
#         if [ "$_bg_component" -gt 7 ] 2>/dev/null; then
#           _a11y_bg="light"
#         fi
#       fi
#       ;;
#   esac
#
#   # version check
#   if [ "$_tmux_version" -lt 3300 ]; then
#     _display_time_ms=$(( tmux_conf_accessibility_display_time * 2 ))
#     tmux display-message -d "$_display_time_ms" "Accessibility: tmux >= 3.3 recommended for screen reader support (current: $(tmux -V))"
#   else
#     # cursor visibility (only on >= 3.3 where it matters for screen readers)
#     tmux set -as terminal-overrides '*:civis@'
#   fi
#
#   # status line
#   tmux set -g status-interval 60
#
#   # visual notifications
#   if _is_true "$tmux_conf_accessibility_visual_activity"; then
#     tmux set -g visual-activity on
#     tmux set -g visual-bell on
#     tmux set -g visual-silence on
#   fi
#
#   # theme colour defaults (dark)
#   if [ "$_a11y_bg" = "dark" ]; then
#     tmux_conf_theme_colour_1=${tmux_conf_theme_colour_1:-#1a1a2e}
#     tmux_conf_theme_colour_2=${tmux_conf_theme_colour_2:-#2d2d44}
#     tmux_conf_theme_colour_3=${tmux_conf_theme_colour_3:-#b0b0b0}
#     tmux_conf_theme_colour_4=${tmux_conf_theme_colour_4:-#00d4aa}
#     tmux_conf_theme_colour_5=${tmux_conf_theme_colour_5:-#ffd700}
#     tmux_conf_theme_colour_6=${tmux_conf_theme_colour_6:-#1a1a2e}
#     tmux_conf_theme_colour_7=${tmux_conf_theme_colour_7:-#e0e0e0}
#     tmux_conf_theme_colour_8=${tmux_conf_theme_colour_8:-#1a1a2e}
#     tmux_conf_theme_colour_9=${tmux_conf_theme_colour_9:-#ffd700}
#     tmux_conf_theme_colour_10=${tmux_conf_theme_colour_10:-#ff8c00}
#     tmux_conf_theme_colour_11=${tmux_conf_theme_colour_11:-#00d4aa}
#     tmux_conf_theme_colour_12=${tmux_conf_theme_colour_12:-#6c6c6c}
#     tmux_conf_theme_colour_13=${tmux_conf_theme_colour_13:-#e0e0e0}
#     tmux_conf_theme_colour_14=${tmux_conf_theme_colour_14:-#1a1a2e}
#     tmux_conf_theme_colour_15=${tmux_conf_theme_colour_15:-#1a1a2e}
#     tmux_conf_theme_colour_16=${tmux_conf_theme_colour_16:-#ff8c00}
#     tmux_conf_theme_colour_17=${tmux_conf_theme_colour_17:-#e0e0e0}
#     tmux_conf_theme_focused_pane_bg=${tmux_conf_theme_focused_pane_bg:-#1e1e3a}
#   else
#     tmux_conf_theme_colour_1=${tmux_conf_theme_colour_1:-#f5f5f0}
#     tmux_conf_theme_colour_2=${tmux_conf_theme_colour_2:-#e0e0da}
#     tmux_conf_theme_colour_3=${tmux_conf_theme_colour_3:-#555555}
#     tmux_conf_theme_colour_4=${tmux_conf_theme_colour_4:-#007a5e}
#     tmux_conf_theme_colour_5=${tmux_conf_theme_colour_5:-#b8860b}
#     tmux_conf_theme_colour_6=${tmux_conf_theme_colour_6:-#f5f5f0}
#     tmux_conf_theme_colour_7=${tmux_conf_theme_colour_7:-#1a1a1a}
#     tmux_conf_theme_colour_8=${tmux_conf_theme_colour_8:-#f5f5f0}
#     tmux_conf_theme_colour_9=${tmux_conf_theme_colour_9:-#b8860b}
#     tmux_conf_theme_colour_10=${tmux_conf_theme_colour_10:-#cc3300}
#     tmux_conf_theme_colour_11=${tmux_conf_theme_colour_11:-#007a5e}
#     tmux_conf_theme_colour_12=${tmux_conf_theme_colour_12:-#777777}
#     tmux_conf_theme_colour_13=${tmux_conf_theme_colour_13:-#1a1a1a}
#     tmux_conf_theme_colour_14=${tmux_conf_theme_colour_14:-#f5f5f0}
#     tmux_conf_theme_colour_15=${tmux_conf_theme_colour_15:-#f5f5f0}
#     tmux_conf_theme_colour_16=${tmux_conf_theme_colour_16:-#cc3300}
#     tmux_conf_theme_colour_17=${tmux_conf_theme_colour_17:-#1a1a1a}
#     tmux_conf_theme_focused_pane_bg=${tmux_conf_theme_focused_pane_bg:-#ededea}
#   fi
#
#   # pane content
#   tmux_conf_theme_window_fg=${tmux_conf_theme_window_fg:-default}
#   tmux_conf_theme_window_bg=${tmux_conf_theme_window_bg:-default}
#   tmux_conf_theme_highlight_focused_pane=${tmux_conf_theme_highlight_focused_pane:-true}
#   tmux_conf_theme_focused_pane_fg=${tmux_conf_theme_focused_pane_fg:-default}
#
#   # separators
#   tmux_conf_theme_left_separator_main=${tmux_conf_theme_left_separator_main:-|}
#   tmux_conf_theme_left_separator_sub=${tmux_conf_theme_left_separator_sub:-|}
#   tmux_conf_theme_right_separator_main=${tmux_conf_theme_right_separator_main:-|}
#   tmux_conf_theme_right_separator_sub=${tmux_conf_theme_right_separator_sub:-|}
#
#   # status format
#   tmux_conf_theme_status_left=${tmux_conf_theme_status_left:-" [#S] "}
#   tmux_conf_theme_status_right=${tmux_conf_theme_status_right:-" %H:%M "}
#   tmux_conf_theme_window_status_format=${tmux_conf_theme_window_status_format:-"#I:#W"}
#   tmux_conf_theme_window_status_current_format=${tmux_conf_theme_window_status_current_format:-"#I:#W*#{?window_zoomed_flag, [zoomed],}"}
#
#   # confirmation message
#   _ver_major=$(( _tmux_version / 1000 ))
#   _ver_minor=$(( (_tmux_version % 1000) / 100 ))
#   tmux display-message -d "$tmux_conf_accessibility_display_time" "Accessibility mode enabled (tmux ${_ver_major}.${_ver_minor}, display-time ${tmux_conf_accessibility_display_time}ms)"
# }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `sh tests/test_accessibility.sh`
Expected: All assertions pass

- [ ] **Step 5: Run ShellCheck on the new function**

Run: `sed -n '/^# _apply_accessibility/,/^# }$/{ s/^# //; p; }' .tmux.conf | shellcheck -s sh -`
Expected: No errors (warnings about unused variables are acceptable)

- [ ] **Step 6: Commit**

```bash
git add .tmux.conf tests/test_accessibility.sh
git commit -m "feat: add _apply_accessibility function

Implements core accessibility mode logic:
- Input validation with warning on unrecognized values
- Theme auto-detection from COLORFGBG (dark/light)
- Version check (skip civis@ on < 3.3, emit warning)
- Dark and light WCAG AA palettes (17 colour slots)
- ASCII separators (pipe character)
- Status format (reduced noise, active window marker)
- Visual notification settings (configurable toggle)
- Focused pane background highlight
- Activation confirmation message

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Chunk 3: Keybindings and choose-tree

### Task 4: Write failing tests for accessibility keybindings

**Files:**
- Create: `tests/test_bindings.sh`

- [ ] **Step 1: Write keybinding tests**

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `sh tests/test_bindings.sh`
Expected: FAIL (function does not exist yet)

- [ ] **Step 3: Implement `_apply_accessibility_bindings` in `.tmux.conf`**

Insert after the `_apply_accessibility` function (still in the `# ` prefixed section):

```bash
# _apply_accessibility_bindings() {
#   tmux_conf_accessibility_keys=${tmux_conf_accessibility_keys:-disabled}
#   tmux_conf_accessibility_display_time=${tmux_conf_accessibility_display_time:-5000}
#
#   if _is_disabled "$tmux_conf_accessibility_keys"; then
#     return
#   fi
#
#   # pane navigation (arrow keys)
#   tmux bind Left select-pane -L
#   tmux bind Down select-pane -D
#   tmux bind Up select-pane -U
#   tmux bind Right select-pane -R
#
#   # pane resize (Alt+arrow)
#   tmux bind M-Left resize-pane -L 2
#   tmux bind M-Down resize-pane -D 2
#   tmux bind M-Up resize-pane -U 2
#   tmux bind M-Right resize-pane -R 2
#
#   # window navigation (Ctrl+arrow)
#   tmux bind C-Left previous-window
#   tmux bind C-Right next-window
#
#   # pane announce (note: #{s|$HOME|~|:pane_current_path} replaces $HOME with ~)
#   tmux bind a display-message -d "$tmux_conf_accessibility_display_time" \
#     "#S:#W Pane #{pane_index}/#{window_panes}: #{?#{pane_current_command},#{pane_current_command},(idle)} in #{s|$HOME|~|:pane_current_path}#{?window_zoomed_flag, [zoomed],}"
#
#   # help binding
#   tmux bind A display-message -d "$tmux_conf_accessibility_display_time" \
#     "Accessibility: arrows=pane, M-arrows=resize, C-Left/Right=window, a=announce, A=help, s/w=choose-tree"
#
#   # choose-tree with accessible formats
#   tmux bind s choose-tree -sF "Session: #S (#{session_windows} windows#{?session_attached, attached,})"
#   tmux bind w choose-tree -wF "Window #I: #W (#{pane_current_command} in #{s|$HOME|~|:pane_current_path})"
# }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `sh tests/test_bindings.sh`
Expected: All assertions pass

- [ ] **Step 5: Run ShellCheck**

Run: `sed -n '/^# _apply_accessibility_bindings/,/^# }$/{ s/^# //; p; }' .tmux.conf | shellcheck -s sh -`
Expected: Clean

- [ ] **Step 6: Commit**

```bash
git add .tmux.conf tests/test_bindings.sh
git commit -m "feat: add accessibility keybindings

Adds _apply_accessibility_bindings function:
- Arrow keys for pane navigation
- Alt+arrow for pane resize
- Ctrl+Left/Right for window prev/next
- <prefix> a: pane context announce (session:window Pane X/Y: cmd in path)
- <prefix> A: help listing all accessibility keys
- <prefix> s/w: choose-tree with accessible text format

All bindings are additive (existing bindings preserved).
Activated by tmux_conf_accessibility_keys=enabled.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Chunk 4: Integration into _apply_configuration and _apply_bindings

### Task 5: Wire accessibility into the main orchestration

**Files:**
- Modify: `.tmux.conf` (line ~1870 in `_apply_configuration`)
- Modify: `.tmux.conf` (line ~1106 at end of `_apply_bindings`)

- [ ] **Step 1: Add `_apply_accessibility` call in `_apply_configuration`**

In `_apply_configuration`, insert the call BEFORE the parallel block. Find line:
```
#   _apply_tmux_256color
```
Insert before it:
```
#   _apply_accessibility
```

The modified section should read:
```bash
#   _apply_accessibility
#   _apply_tmux_256color
#   _apply_24b&
#   _apply_theme&
#   _apply_bindings&
#   wait
```

- [ ] **Step 2: Add `_apply_accessibility_bindings` call in `_apply_bindings`**

At the end of `_apply_bindings` (just before its closing `}`), add:
```bash
#   _apply_accessibility_bindings
```

Find the line (around line 1106):
```
# }
```
That closes `_apply_bindings`. Insert before it:
```
#
#   _apply_accessibility_bindings
```

- [ ] **Step 3: Verify the full test suite passes**

Run: `sh tests/run_tests.sh`
Expected: All test files pass

- [ ] **Step 4: Run ShellCheck on the full embedded script**

Run: `sed -n '/^# EOF$/,$ { s/^# //; p; }' .tmux.conf | shellcheck -s sh -`
Expected: Only pre-existing warnings (document any new ones)

- [ ] **Step 5: Commit**

```bash
git add .tmux.conf
git commit -m "feat: wire accessibility into apply_configuration and apply_bindings

_apply_accessibility runs synchronously before the parallel block
to ensure theme variables are set before _apply_theme reads them.
_apply_accessibility_bindings runs at the end of _apply_bindings.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Chunk 5: .tmux.conf.local Variables and Theme Block

### Task 6: Add accessibility section to .tmux.conf.local

**Files:**
- Modify: `.tmux.conf.local` (insert before the custom functions section at end)

- [ ] **Step 1: Find insertion point**

The file ends with custom shell functions (around line 480+). Insert the accessibility
section before the custom functions block. Look for the line:
```
# # /!\ do not add custom shell functions below this line
```
Or if that does not exist, insert before the `# "$@"` line near the end.

- [ ] **Step 2: Add accessibility variables and theme block**

Insert this content:

```bash
# -- accessibility -------------------------------------------------------------

# accessibility mode, possible values are:
#   - enabled (activates high-contrast theme, ASCII separators, screen-reader
#     friendly labels, reduced visual noise, and cursor visibility fixes)
#   - disabled (default)
# NOTE: screen reader support requires tmux >= 3.3
# NOTE: unrecognized values trigger a warning and are treated as disabled
tmux_conf_accessibility=disabled

# accessible keybindings, possible values are:
#   - enabled (adds arrow-key pane navigation, single-modifier resize,
#     and a pane context announcement binding)
#   - disabled (default)
tmux_conf_accessibility_keys=disabled

# visual notifications (activity, bell, silence), possible values are:
#   - true (default when accessibility=enabled; screen readers announce these)
#   - false (disable if notifications are too noisy with your screen reader)
tmux_conf_accessibility_visual_activity=true

# display-message duration in milliseconds for accessibility messages
# (pane announce, warnings). Screen readers need time to read the text aloud.
# version warning uses 2x this value.
#   - default: 5000 (5 seconds)
tmux_conf_accessibility_display_time=5000

# accessible theme background, possible values are:
#   - auto (default: detect from $COLORFGBG if available, else dark)
#   - dark (dark background, light text)
#   - light (light background, dark text)
tmux_conf_accessibility_theme=auto

# -- accessible theme (manual control) ----------------------------------------
# High-contrast, colorblind-safe, screen-reader-friendly theme.
# Activate all at once with tmux_conf_accessibility=enabled above, or uncomment
# individual lines below for manual control.
# Requires: tmux >= 3.3 for full screen reader support.
# Tested with: NVDA + Windows Terminal, Orca + GNOME Terminal, TDSR.
#
# Dark palette:
#tmux_conf_theme_colour_1="#1a1a2e"    # background (near-black)
#tmux_conf_theme_colour_2="#2d2d44"    # inactive border
#tmux_conf_theme_colour_3="#b0b0b0"    # inactive text (8.5:1)
#tmux_conf_theme_colour_4="#00d4aa"    # active/focus (8.2:1)
#tmux_conf_theme_colour_5="#ffd700"    # alert/urgent (11.3:1)
#tmux_conf_theme_colour_6="#1a1a2e"    # dark accent
#tmux_conf_theme_colour_7="#e0e0e0"    # primary text (12.1:1)
#tmux_conf_theme_colour_8="#1a1a2e"    # dark accent
#tmux_conf_theme_colour_9="#ffd700"    # warning (11.3:1)
#tmux_conf_theme_colour_10="#ff8c00"   # error/important (5.8:1)
#tmux_conf_theme_colour_11="#00d4aa"   # success (8.2:1)
#tmux_conf_theme_colour_12="#6c6c6c"   # muted text (4.6:1)
#tmux_conf_theme_colour_13="#e0e0e0"   # bright text (12.1:1)
#tmux_conf_theme_colour_14="#1a1a2e"   # dark accent
#tmux_conf_theme_colour_15="#1a1a2e"   # dark accent
#tmux_conf_theme_colour_16="#ff8c00"   # danger (5.8:1)
#tmux_conf_theme_colour_17="#e0e0e0"   # bright text (12.1:1)
#
# Light palette (uncomment these INSTEAD of dark palette above):
#tmux_conf_theme_colour_1="#f5f5f0"    # background (off-white)
#tmux_conf_theme_colour_2="#e0e0da"    # inactive border
#tmux_conf_theme_colour_3="#555555"    # inactive text (7.5:1)
#tmux_conf_theme_colour_4="#007a5e"    # active/focus (5.2:1)
#tmux_conf_theme_colour_5="#b8860b"    # alert/urgent (4.6:1)
#tmux_conf_theme_colour_6="#f5f5f0"    # light accent
#tmux_conf_theme_colour_7="#1a1a1a"    # primary text (15.3:1)
#tmux_conf_theme_colour_8="#f5f5f0"    # light accent
#tmux_conf_theme_colour_9="#b8860b"    # warning (4.6:1)
#tmux_conf_theme_colour_10="#cc3300"   # error/important (5.4:1)
#tmux_conf_theme_colour_11="#007a5e"   # success (5.2:1)
#tmux_conf_theme_colour_12="#777777"   # muted text (4.6:1)
#tmux_conf_theme_colour_13="#1a1a1a"   # bright text (15.3:1)
#tmux_conf_theme_colour_14="#f5f5f0"   # light accent
#tmux_conf_theme_colour_15="#f5f5f0"   # light accent
#tmux_conf_theme_colour_16="#cc3300"   # danger (5.4:1)
#tmux_conf_theme_colour_17="#1a1a1a"   # bright text (15.3:1)
#
# ASCII separators (for both dark and light):
#tmux_conf_theme_left_separator_main="|"
#tmux_conf_theme_left_separator_sub="|"
#tmux_conf_theme_right_separator_main="|"
#tmux_conf_theme_right_separator_sub="|"
#
# Accessible status format:
#tmux_conf_theme_window_status_format="#I:#W"
#tmux_conf_theme_window_status_current_format="#I:#W*#{?window_zoomed_flag, [zoomed],}"
```

- [ ] **Step 3: Verify .tmux.conf.local additions are well-formed**

Run: `grep -c 'tmux_conf_accessibility' .tmux.conf.local`
Expected: At least 5 matches (the accessibility variable block was added correctly)

- [ ] **Step 4: Commit**

```bash
git add .tmux.conf.local
git commit -m "feat: add accessibility variables and theme block to .tmux.conf.local

Adds the accessibility configuration section with:
- Master toggle (tmux_conf_accessibility)
- Keybindings toggle (tmux_conf_accessibility_keys)
- Visual activity toggle
- Display time configuration
- Theme auto-detect/dark/light selector
- Full commented-out dark and light palette blocks
- ASCII separator and status format options

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Chunk 6: README and Theme Tests

### Task 7: Add Accessibility section to README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Find insertion point**

Look for the "Configuration" section. Insert a new "Accessibility" section after it.

- [ ] **Step 2: Add Accessibility section**

```markdown
Accessibility
-------------

Oh my tmux! includes an opt-in accessibility mode for screen reader users, low
vision users, and colorblind users. Enable it by setting one variable in your
`.tmux.conf.local`:

```
tmux_conf_accessibility=enabled
```

### What changes when enabled

- **Cursor always visible** - screen readers track the hardware cursor; tmux no
  longer hides it in menus and choose-tree
- **High-contrast palette** - WCAG AA compliant colors, distinguishable under
  all forms of color blindness
- **ASCII separators** - `|` instead of Powerline glyphs (screen readers announce
  "bar" instead of "black right-pointing triangle")
- **Reduced status noise** - 60-second refresh, no seconds, no hostname in status
- **Text notifications** - visual-activity/bell/silence produce message-line text
  that screen readers detect

### Keybindings (optional)

Enable accessible keybindings with `tmux_conf_accessibility_keys=enabled`:

| Key | Action |
|-----|--------|
| `<prefix> Left/Down/Up/Right` | Move between panes |
| `<prefix> M-Left/Down/Up/Right` | Resize pane |
| `<prefix> C-Left/C-Right` | Previous/next window |
| `<prefix> a` | Announce pane context |
| `<prefix> A` | List accessibility keys |
| `<prefix> s` | Sessions (accessible format) |
| `<prefix> w` | Windows (accessible format) |

### Requirements

- tmux >= 3.3 for full screen reader support (cursor tracking in choose-tree)
- tmux 2.6-3.2: theme and keybindings work, but screen reader cursor tracking
  in menus will not function; a warning is displayed

### Screen reader recommendations

| Platform | Recommended setup |
|----------|-------------------|
| Windows + WSL | Windows Terminal + NVDA (or JAWS) + SSH into WSL |
| Linux | GNOME Terminal + Orca, or any terminal + TDSR |
| macOS | Terminal.app + VoiceOver |

### Configuration reference

| Variable | Values | Default |
|----------|--------|---------|
| `tmux_conf_accessibility` | `enabled`, `disabled` | `disabled` |
| `tmux_conf_accessibility_keys` | `enabled`, `disabled` | `disabled` |
| `tmux_conf_accessibility_visual_activity` | `true`, `false` | `true` |
| `tmux_conf_accessibility_display_time` | milliseconds | `5000` |
| `tmux_conf_accessibility_theme` | `auto`, `dark`, `light` | `auto` |

We welcome feedback from screen reader users. Please open an issue if you
encounter accessibility problems.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add Accessibility section to README

Documents the accessibility mode: quick start, feature list,
keybinding reference, requirements, screen reader recommendations,
and configuration variable reference.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 8: Theme variable tests

**Files:**
- Create: `tests/test_theme.sh`

- [ ] **Step 1: Write theme tests**

```bash
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
```

- [ ] **Step 2: Run tests**

Run: `sh tests/test_theme.sh`
Expected: All pass

- [ ] **Step 3: Run full test suite**

Run: `sh tests/run_tests.sh`
Expected: All 4 test files pass

- [ ] **Step 4: Commit**

```bash
git add tests/test_theme.sh
git commit -m "test: add theme variable and auto-detection tests

Validates dark/light palettes, user override preservation,
and COLORFGBG auto-detection logic.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Chunk 7: Final Validation and Push

### Task 9: End-to-end validation

- [ ] **Step 1: Run full test suite one final time**

Run: `sh tests/run_tests.sh`
Expected: All tests pass

- [ ] **Step 2: Run ShellCheck on full embedded script**

Run: `sed -n '/^# EOF$/,$ { s/^# //; p; }' .tmux.conf | shellcheck -s sh - 2>&1 | head -30`
Expected: Only pre-existing issues (no new warnings from accessibility code)

- [ ] **Step 3: Verify backward compatibility (disabled is default)**

Confirm that with no accessibility variables set, the extracted script does nothing different:
```bash
# Extract the shell script portion and source it
SCRIPT=$(sed -n '/^# EOF$/,$ { s/^# //; p; }' .tmux.conf)

# Simulate default state (disabled)
tmux_conf_accessibility=disabled
eval "$SCRIPT"

# _apply_accessibility should be a no-op: theme colours must NOT be set
if [ -n "${tmux_conf_theme_colour_1:-}" ]; then
  echo "FAIL: disabled mode set theme variables (expected no-op)"
  exit 1
fi
echo "PASS: disabled mode is a clean no-op"
```

- [ ] **Step 4: Verify git log is clean and atomic**

Run: `git --no-pager log --oneline master..HEAD`
Expected:
```
<hash> test: add theme variable and auto-detection tests
<hash> docs: add Accessibility section to README
<hash> feat: add accessibility variables and theme block to .tmux.conf.local
<hash> feat: wire accessibility into apply_configuration and apply_bindings
<hash> feat: add accessibility keybindings
<hash> feat: add _apply_accessibility function
<hash> test: add helper function tests
<hash> test: add test runner and assertion library
<hash> docs: add accessibility mode design spec
```

- [ ] **Step 5: Push to fork**

Run: `git push origin feature/accessibility-improvements`
Expected: Push succeeds to alistardust/.tmux

- [ ] **Step 6: Note for manual screen reader testing**

After push, the following manual validation is needed (not automatable):
1. Ali's co-worker tests with NVDA + Windows Terminal + SSH + tmux >= 3.3
2. Validate status bar reads cleanly without decorative noise
3. Validate choose-tree announces current selection
4. Validate `<prefix> a` is read correctly
5. Validate keybindings do not conflict with NVDA navigation

---

## Summary

| Chunk | Tasks | Purpose |
|-------|-------|---------|
| 1 | Tasks 1-2 | Test infrastructure + helper tests |
| 2 | Task 3 | Core `_apply_accessibility` function (TDD) |
| 3 | Task 4 | Keybindings + choose-tree (TDD) |
| 4 | Task 5 | Wire into orchestration functions |
| 5 | Task 6 | `.tmux.conf.local` config block |
| 6 | Tasks 7-8 | README docs + theme tests |
| 7 | Task 9 | Final validation + push |

Total: 9 tasks, ~35 steps, 9 commits.
