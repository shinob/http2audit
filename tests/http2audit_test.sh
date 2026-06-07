#!/usr/bin/env bash
# http2audit.sh 統合テスト（追加インストール不要）
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$DIR/../http2audit.sh"
PASS=0; FAIL=0

_test() {
    local name="$1"; shift
    if ("$@") 2>/dev/null; then
        PASS=$((PASS + 1)); printf '[PASS] %s\n' "$name"
    else
        FAIL=$((FAIL + 1)); printf '[FAIL] %s\n' "$name"
    fi
}

# 各テストで使う共通の環境変数（全サーバーを「未インストール」扱い）
_base_env() {
    export NO_COLOR=1
    export NGINX_BIN=/nonexistent/nginx
    export APACHE_BIN=/nonexistent/apachectl
    export ENVOY_BIN=/nonexistent/envoy
    export NGINX_CONF_FILE=""
    export APACHE_CONF_FILE=""
    export ENVOY_CONF_FILE=""
    export DMESG_OUTPUT_FILE="$DIR/fixtures/dmesg_clean.txt"
    export JOURNALCTL_OUTPUT_FILE="$DIR/fixtures/dmesg_clean.txt"
}

# ---- テスト関数 ----

t_help() (
    _base_env
    out=$(bash "$SCRIPT" --help 2>&1)
    echo "$out" | grep -q '使い方'
)

t_no_url_skip() (
    _base_env
    out=$(bash "$SCRIPT" 2>&1)
    echo "$out" | grep -q 'URL が指定されていないためスキップ'
)

t_summary_shown() (
    _base_env
    out=$(bash "$SCRIPT" 2>&1)
    echo "$out" | grep -q 'サマリー'
)

t_report_file() (
    _base_env
    tmpfile=$(mktemp)
    bash "$SCRIPT" --report "$tmpfile" > /dev/null 2>&1
    [[ -s "$tmpfile" ]]
    grep -q 'http2audit' "$tmpfile"
    rm -f "$tmpfile"
)

t_unknown_option_fails() (
    _base_env
    bash "$SCRIPT" --unknown-flag > /dev/null 2>&1
    [[ $? -ne 0 ]]
)

t_nginx_safe_ok() (
    _base_env
    export NGINX_CONF_FILE="$DIR/fixtures/nginx_safe.conf"
    out=$(bash "$SCRIPT" 2>&1)
    echo "$out" | grep -q 'http2_max_concurrent_streams = 64'
)

t_nginx_unsafe_warn_and_suggest() (
    _base_env
    export NGINX_CONF_FILE="$DIR/fixtures/nginx_unsafe.conf"
    out=$(bash "$SCRIPT" 2>&1)
    echo "$out" | grep -q '\[WARN\]'
    echo "$out" | grep -q '推奨設定'
)

t_exit_code_zero() (
    _base_env
    bash "$SCRIPT" > /dev/null 2>&1
    [[ $? -eq 0 ]]
)

# ---- 実行 ----
_test "http2audit: --help が正常終了"             t_help
_test "http2audit: URL なし → STEP2 スキップ"     t_no_url_skip
_test "http2audit: サマリーが出力される"          t_summary_shown
_test "http2audit: --report でファイルが生成"     t_report_file
_test "http2audit: 不明オプションでエラー終了"    t_unknown_option_fails
_test "http2audit: nginx safe.conf → OK"          t_nginx_safe_ok
_test "http2audit: nginx unsafe.conf → WARN+提案" t_nginx_unsafe_warn_and_suggest
_test "http2audit: 正常終了コードが 0"            t_exit_code_zero

echo "  → $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
