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
