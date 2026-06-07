#!/usr/bin/env bash
# OOM ログ確認のテスト（追加インストール不要）
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

_test() {
    local name="$1"; shift
    if ("$@") 2>/dev/null; then
        PASS=$((PASS + 1)); printf '[PASS] %s\n' "$name"
    else
        FAIL=$((FAIL + 1)); printf '[FAIL] %s\n' "$name"
    fi
}

# ---- テスト関数 ----

t_oom_detected() (
    export NO_COLOR=1
    source "$DIR/../lib/output.sh"
    source "$DIR/../lib/check_oom.sh"
    DMESG_OUTPUT_FILE="$DIR/fixtures/dmesg_oom.txt"
    JOURNALCTL_OUTPUT_FILE="$DIR/fixtures/dmesg_clean.txt"
    out=$(check_oom 2>&1)
    echo "$out" | grep -q '\[WARN\]'
    echo "$out" | grep -q 'OOM の痕跡'
)

t_oom_clean() (
    export NO_COLOR=1
    source "$DIR/../lib/output.sh"
    source "$DIR/../lib/check_oom.sh"
    DMESG_OUTPUT_FILE="$DIR/fixtures/dmesg_clean.txt"
    JOURNALCTL_OUTPUT_FILE="$DIR/fixtures/dmesg_clean.txt"
    out=$(check_oom 2>&1)
    ! echo "$out" | grep -q '\[WARN\]'
    echo "$out" | grep -q '\[OK\]'
)

# ---- 実行 ----
_test "oom: OOM ログあり → WARN"  t_oom_detected
_test "oom: OOM ログなし → OK"    t_oom_clean

echo "  → $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
