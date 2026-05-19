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
