#!/usr/bin/env bash
# nginx 設定確認のテスト（追加インストール不要）
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

# テストヘルパー: 関数を独立したサブシェルで実行して合否を記録
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
    source "$DIR/../lib/check_nginx.sh"
    NGINX_BIN=/nonexistent/nginx; NGINX_CONF_FILE=""
    out=$(check_nginx 2>&1)
    echo "$out" | grep -q '\[SKIP\]'
)

t_safe_no_warn() (
    export NO_COLOR=1
    source "$DIR/../lib/output.sh"
    source "$DIR/../lib/check_nginx.sh"
    NGINX_CONF_FILE="$DIR/fixtures/nginx_safe.conf"
    out=$(check_nginx 2>&1)
    ! echo "$out" | grep -q '\[WARN\]'
)

t_safe_streams_ok() (
    export NO_COLOR=1
    source "$DIR/../lib/output.sh"
    source "$DIR/../lib/check_nginx.sh"
    NGINX_CONF_FILE="$DIR/fixtures/nginx_safe.conf"
    out=$(check_nginx 2>&1)
    echo "$out" | grep -q 'http2_max_concurrent_streams = 64'
)

t_safe_timeout_ok() (
    export NO_COLOR=1
    source "$DIR/../lib/output.sh"
    source "$DIR/../lib/check_nginx.sh"
    NGINX_CONF_FILE="$DIR/fixtures/nginx_safe.conf"
    out=$(check_nginx 2>&1)
    echo "$out" | grep -q 'client_header_timeout = 10s'
)

t_unsafe_http2_warn() (
    export NO_COLOR=1
    source "$DIR/../lib/output.sh"
    source "$DIR/../lib/check_nginx.sh"
    NGINX_CONF_FILE="$DIR/fixtures/nginx_unsafe.conf"
    out=$(check_nginx 2>&1)
    echo "$out" | grep -q 'HTTP/2 が有効'
)

t_unsafe_streams_warn() (
    export NO_COLOR=1
    source "$DIR/../lib/output.sh"
    source "$DIR/../lib/check_nginx.sh"
    NGINX_CONF_FILE="$DIR/fixtures/nginx_unsafe.conf"
    out=$(check_nginx 2>&1)
    echo "$out" | grep -q 'http2_max_concurrent_streams.*未設定'
)

t_unsafe_suggest() (
    export NO_COLOR=1
    source "$DIR/../lib/output.sh"
    source "$DIR/../lib/check_nginx.sh"
    NGINX_CONF_FILE="$DIR/fixtures/nginx_unsafe.conf"
    check_nginx > /dev/null 2>&1
    out=$(suggest_nginx 2>&1)
    echo "$out" | grep -q 'http2_max_concurrent_streams 64'
)

t_safe_no_suggest() (
    export NO_COLOR=1
    source "$DIR/../lib/output.sh"
    source "$DIR/../lib/check_nginx.sh"
    NGINX_CONF_FILE="$DIR/fixtures/nginx_safe.conf"
    check_nginx > /dev/null 2>&1
    out=$(suggest_nginx 2>&1)
    [[ -z "$out" ]]
)

# ---- 実行 ----
_test "nginx: 未インストール → SKIP"                 t_not_found
_test "nginx: safe.conf → WARN なし"                 t_safe_no_warn
_test "nginx: safe.conf → concurrent_streams OK"     t_safe_streams_ok
_test "nginx: safe.conf → client_header_timeout OK"  t_safe_timeout_ok
_test "nginx: unsafe.conf → HTTP/2 有効で WARN"       t_unsafe_http2_warn
_test "nginx: unsafe.conf → concurrent_streams WARN" t_unsafe_streams_warn
_test "nginx: unsafe.conf → 改善提案あり"             t_unsafe_suggest
_test "nginx: safe.conf → 改善提案なし"               t_safe_no_suggest

echo "  → $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
