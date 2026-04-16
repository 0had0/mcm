#!/usr/bin/env bash

set -e

export CI=true
export MCM_DIR="${MCM_DIR:-$HOME/.mcm_test}"

cleanup() {
    rm -rf "$MCM_DIR"
}

trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCM="$SCRIPT_DIR/mcm.sh"

pass() { echo -e "\033[0;32m✓ $1\033[0m"; }
fail() { echo -e "\033[0;31m✗ $1\033[0m"; exit 1; }

echo "========================================"
echo "MCM Test Suite"
echo "========================================"
echo

# Test: help command
echo "Testing: help"
"$MCM" help | grep -q "MCM" && pass "help" || fail "help"

# Test: version command
echo "Testing: version"
"$MCM" version | grep -q "0\." && pass "version" || fail "version"

# Test: list command
echo "Testing: list"
"$MCM" list | grep -q "Providers" && pass "list" || fail "list"

# Test: list shows providers
echo "Testing: list shows kimi"
"$MCM" list | grep -q "kimi" && pass "list shows kimi" || fail "list shows kimi"

# Test: list shows minimax
echo "Testing: list shows minimax"
"$MCM" list | grep -q "minimax" && pass "list shows minimax" || fail "list shows minimax"

# Test: doctor command
echo "Testing: doctor"
"$MCM" doctor | grep -q "diagnostics" && pass "doctor" || fail "doctor"

# Test: doctor shows OpenSSL
"$MCM" doctor | grep -q "OpenSSL" && pass "doctor shows OpenSSL" || fail "doctor shows OpenSSL"

# Test: add without arguments shows error
echo "Testing: add without args"
"$MCM" add 2>&1 | grep -q "Usage" && pass "add without args" || fail "add without args"

# Test: use without arguments shows error
echo "Testing: use without args"
"$MCM" use 2>&1 | grep -q "Usage" && pass "use without args" || fail "use without args"

# Test: rm without arguments shows error
echo "Testing: rm without args"
"$MCM" rm 2>&1 | grep -q "Usage" && pass "rm without args" || fail "rm without args"

# Test: unknown command shows error
echo "Testing: unknown command"
"$MCM" unknown_cmd 2>&1 | grep -q "Unknown" && pass "unknown command" || fail "unknown command"

# Test: add unknown provider
echo "Testing: add unknown provider"
"$MCM" add nonexistent_provider 2>&1 | grep -q "Unknown provider" && pass "add unknown provider" || fail "add unknown provider"

# Test: use unknown provider
echo "Testing: use unknown provider"
"$MCM" use nonexistent_provider 2>&1 | grep -q "Unknown provider" && pass "use unknown provider" || fail "use unknown provider"

# Test: install
echo "Testing: install"
rm -rf "$MCM_DIR"
"$MCM" install <<< $'\n'
test -f "$MCM_DIR/.key" && pass "install creates .key" || fail "install creates .key"
test -f "$MCM_DIR/.keys.enc" && pass "install creates .keys.enc" || fail "install creates .keys.enc"
test -f "$MCM_DIR/config.sh" && pass "install creates config.sh" || fail "install creates config.sh"

# Test: use provider without key
echo "Testing: use provider without key"
"$MCM" use kimi 2>&1 | grep -q "not configured" && pass "use without key" || fail "use without key"

# Test: rm provider without key
echo "Testing: rm provider without key"
"$MCM" rm kimi 2>&1 | grep -q "not configured" && pass "rm without key" || fail "rm without key"

# Test: add provider with key
echo "Testing: add provider with key"
echo "test_api_key_123" | "$MCM" add kimi <<< $'\n\ntest_api_key_123\n'
"$MCM" doctor | grep -q "OpenSSL"

# Test: use configured provider
echo "Testing: use configured provider"
"$MCM" use kimi <<< "y" 2>&1 | grep -q "Now using" && pass "use configured provider" || fail "use configured provider"

# Test: config shows current provider
echo "Testing: config shows current"
grep -q "MCM_CURRENT=\"kimi\"" "$MCM_DIR/config.sh" && pass "config shows current" || fail "config shows current"

# Test: rm configured provider
echo "Testing: rm configured provider"
echo "y" | "$MCM" rm kimi
grep -q "none" "$MCM_DIR/config.sh" && pass "rm resets current" || fail "rm resets current"

echo
echo "========================================"
echo -e "\033[0;32mAll tests passed!\033[0m"
echo "========================================"
