#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE=""

source "$SCRIPT_DIR/lib/output.sh"
source "$SCRIPT_DIR/lib/check_http2.sh"
source "$SCRIPT_DIR/lib/check_nginx.sh"
source "$SCRIPT_DIR/lib/check_apache.sh"
source "$SCRIPT_DIR/lib/check_envoy.sh"
source "$SCRIPT_DIR/lib/check_oom.sh"

usage() {
    cat << EOF
使い方:
  $0 [オプション] [URL]

引数:
  URL              チェック対象のURL（例: https://example.com）
                   省略するとローカル設定ファイルのみを診断

オプション:
  -r, --report <file>   結果をファイルに保存
  -h, --help            ヘルプを表示

例:
  $0 https://example.com
  $0 --report /tmp/http2audit.txt https://example.com
  $0
EOF
}

TARGET_URL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--report) REPORT_FILE="$2"; shift 2 ;;
        -h|--help)   usage; exit 0 ;;
        http*)       TARGET_URL="$1"; shift ;;
        *)
            printf 'エラー: 不明なオプション: %s\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# レポートファイルの初期化
if [[ -n "$REPORT_FILE" ]]; then
    : > "$REPORT_FILE"
fi

# ヘッダー
_emit ""
_emit "${_C_BOLD}=== http2audit: HTTP/2 Bomb 影響診断 ===${_C_NC}"
_emit "実行日時: $(date '+%Y-%m-%d %H:%M:%S')"
[[ -n "$TARGET_URL" ]] && _emit "対象URL: $TARGET_URL"

# STEP 1: 依存コマンド確認
log_section "STEP 1: 依存コマンド確認"
if ! command -v curl &>/dev/null; then
    _emit "エラー: curl が見つかりません。インストールしてください。" >&2
    exit 1
fi
log_ok "curl $(curl --version 2>/dev/null | head -1 | awk '{print $1,$2}')"

# STEP 2: HTTP/2 接続確認
if [[ -n "$TARGET_URL" ]]; then
    check_http2_connection "$TARGET_URL"
else
    log_section "STEP 2: HTTP/2 有効確認"
    log_skip "URL が指定されていないためスキップ"
fi

# STEP 3/4: Webサーバー設定確認
check_nginx
check_apache
check_envoy

# STEP 5: OOM ログ確認
check_oom

# STEP 6: 改善提案
log_section "STEP 6: 改善提案"
if [[ $_WARN_COUNT -gt 0 ]]; then
    suggest_nginx
    suggest_apache
    suggest_envoy
else
    log_ok "設定に問題は見つかりませんでした"
fi

# サマリー
log_summary

if [[ -n "$REPORT_FILE" ]]; then
    _emit "\nレポートを保存しました: $REPORT_FILE"
fi
