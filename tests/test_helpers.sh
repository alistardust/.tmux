#!/bin/sh
# test_helpers.sh - Tests for _is_true, _is_enabled, _is_disabled
set -e
. "$(dirname "$0")/lib.sh"

# Extract helper functions from .tmux.conf embedded script
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
