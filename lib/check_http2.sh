#!/usr/bin/env bash
# HTTP/2 接続確認

# テスト用オーバーライド: CURL_CMD に別スクリプトを指定可能
: "${CURL_CMD:=curl}"

check_http2_connection() {
    local url="$1"
    log_section "STEP 2: HTTP/2 有効確認"

    if ! command -v "$CURL_CMD" &>/dev/null; then
        _emit "エラー: curl が見つかりません。インストールしてください。" >&2
        exit 1
    fi

    local status_line
    status_line=$("$CURL_CMD" -sI --http2 --max-time 10 "$url" 2>/dev/null | head -1 || true)

    if [[ -z "$status_line" ]]; then
        log_skip "接続に失敗しました: $url"
        return 0
    fi

    if echo "$status_line" | grep -qi "^HTTP/2"; then
        log_warn "$url は HTTP/2 を受け付けています"
    else
        log_ok "$url は HTTP/2 を使用していません（HTTP/1.1）"
    fi
}
