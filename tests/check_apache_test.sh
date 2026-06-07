#!/usr/bin/env bash
# Apache 設定確認のテスト（追加インストール不要）
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

t_not_found() (
    export NO_COLOR=1
    source "$DIR/../lib/output.sh"
    source "$DIR/../lib/check_apache.sh"
    APACHE_BIN=/nonexistent/apachectl
    HTTPD_BIN=/nonexistent/httpd
    APACHE_CONF_FILE=""
    out=$(check_apache 2>&1)
    echo "$out" | grep -q '\[SKIP\]'
)

t_safe_streams_ok() (
    export NO_COLOR=1
    source "$DIR/../lib/output.sh"
    source "$DIR/../lib/check_apache.sh"
    APACHE_CONF_FILE="$DIR/fixtures/apache_safe.conf"
    out=$(check_apache 2>&1)
    echo "$out" | grep -q 'H2MaxSessionStreams = 50'
)

t_safe_fields_ok() (
    export NO_COLOR=1
    source "$DIR/../lib/output.sh"
    source "$DIR/../lib/check_apache.sh"
    APACHE_CONF_FILE="$DIR/fixtures/apache_safe.conf"
    out=$(check_apache 2>&1)
    echo "$out" | grep -q 'LimitRequestFields = 50'
)

t_unsafe_streams_warn() (
    export NO_COLOR=1
    source "$DIR/../lib/output.sh"
    source "$DIR/../lib/check_apache.sh"
    APACHE_CONF_FILE="$DIR/fixtures/apache_unsafe.conf"
    out=$(check_apache 2>&1)
    echo "$out" | grep -q 'H2MaxSessionStreams.*未設定'
)

t_unsafe_fields_warn() (
    export NO_COLOR=1
    source "$DIR/../lib/output.sh"
    source "$DIR/../lib/check_apache.sh"
    APACHE_CONF_FILE="$DIR/fixtures/apache_unsafe.conf"
    out=$(check_apache 2>&1)
    echo "$out" | grep -q 'LimitRequestFields.*未設定'
)

# ---- 実行 ----
_test "apache: 未インストール → SKIP"               t_not_found
_test "apache: safe.conf → H2MaxSessionStreams OK"  t_safe_streams_ok
_test "apache: safe.conf → LimitRequestFields OK"   t_safe_fields_ok
_test "apache: unsafe.conf → H2MaxSessionStreams WARN" t_unsafe_streams_warn
_test "apache: unsafe.conf → LimitRequestFields WARN"  t_unsafe_fields_warn

echo "  → $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
