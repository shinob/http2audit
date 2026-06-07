#!/usr/bin/env bash
# nginx 設定確認

# テスト用オーバーライド
: "${NGINX_BIN:=nginx}"
: "${NGINX_CONF_FILE:=}"

_NGINX_SUGGEST=false

_nginx_conf_grep() {
    local pattern="$1"
    if [[ -n "$NGINX_CONF_FILE" ]]; then
        grep -E "$pattern" "$NGINX_CONF_FILE" 2>/dev/null || true
        return
    fi
    grep -rE "$pattern" /etc/nginx/ 2>/dev/null || true
}

check_nginx() {
    _NGINX_SUGGEST=false
    log_section "STEP 4: nginx 設定確認"

    if [[ -z "$NGINX_CONF_FILE" ]]; then
        local bin
        bin=$(_locate_bin "$NGINX_BIN")
        if [[ -z "$bin" ]]; then
            log_skip "nginx が見つかりません（PATH と一般的な設置場所を確認しました。場所が分かる場合は NGINX_BIN=/path/to/nginx で指定してください）"
            return 0
        fi
        local version
        version=$("$bin" -v 2>&1 | grep -oE 'nginx/[0-9.]+' | head -1 || echo "不明")
        log_info "$version を検出 ($bin)"

        if ! find /etc/nginx -name "*.conf" -readable 2>/dev/null | grep -q .; then
            log_skip "nginx 設定ファイルが読み取れません（権限不足の可能性）"
            return 0
        fi
    fi

    # HTTP/2 有効確認
    if _nginx_conf_grep 'http2[[:space:]]+on' | grep -q . || \
       _nginx_conf_grep 'listen.*[[:space:]]http2' | grep -q .; then
        log_warn "HTTP/2 が有効です"
        _NGINX_SUGGEST=true
    else
        log_ok "HTTP/2 は無効です（nginx）"
    fi

    # http2_max_concurrent_streams
    local streams
    streams=$(_nginx_conf_grep 'http2_max_concurrent_streams' \
        | sed 's/.*http2_max_concurrent_streams[[:space:]]*//' \
        | tr -d ';' | grep -oE '^[0-9]+' | head -1)
    if [[ -z "$streams" ]]; then
        log_warn "http2_max_concurrent_streams が未設定（デフォルト: 128）→ 64 以下を推奨"
        _NGINX_SUGGEST=true
    elif [[ "$streams" -le 64 ]]; then
        log_ok "http2_max_concurrent_streams = $streams"
    else
        log_warn "http2_max_concurrent_streams = $streams（推奨: 64 以下）"
        _NGINX_SUGGEST=true
    fi

    # large_client_header_buffers
    if _nginx_conf_grep 'large_client_header_buffers' | grep -q .; then
        local val
        val=$(_nginx_conf_grep 'large_client_header_buffers' | head -1 \
            | sed 's/.*large_client_header_buffers[[:space:]]*//' | tr -d ';' | xargs)
        log_ok "large_client_header_buffers: $val"
    else
        log_warn "large_client_header_buffers が未設定（推奨: 4 8k）"
        _NGINX_SUGGEST=true
    fi

    # client_header_timeout
    local header_timeout
    header_timeout=$(_nginx_conf_grep 'client_header_timeout' | grep -oE '[0-9]+' | head -1)
    if [[ -z "$header_timeout" ]]; then
        log_warn "client_header_timeout が未設定（推奨: 10s 以下）"
        _NGINX_SUGGEST=true
    elif [[ "$header_timeout" -le 10 ]]; then
        log_ok "client_header_timeout = ${header_timeout}s"
    else
        log_warn "client_header_timeout = ${header_timeout}s（推奨: 10s 以下）"
        _NGINX_SUGGEST=true
    fi

    # keepalive_timeout
    local keepalive
    keepalive=$(_nginx_conf_grep 'keepalive_timeout' | grep -oE '[0-9]+' | head -1)
    if [[ -z "$keepalive" ]]; then
        log_warn "keepalive_timeout が未設定（推奨: 15s 以下）"
        _NGINX_SUGGEST=true
    elif [[ "$keepalive" -le 15 ]]; then
        log_ok "keepalive_timeout = ${keepalive}s"
    else
        log_warn "keepalive_timeout = ${keepalive}s（推奨: 15s 以下）"
        _NGINX_SUGGEST=true
    fi
}

suggest_nginx() {
    [[ "$_NGINX_SUGGEST" != true ]] && return 0
    _emit ""
    _emit "  ${_C_BOLD}nginx 推奨設定 (/etc/nginx/nginx.conf の http{} ブロック):${_C_NC}"
    _emit "  http {"
    _emit "      http2_max_concurrent_streams 64;"
    _emit "      large_client_header_buffers 4 8k;"
    _emit "      client_header_timeout 10s;"
    _emit "      keepalive_timeout 15s;"
    _emit "  }"
    _emit "  → nginx -t && systemctl reload nginx"
}
