#!/usr/bin/env bash
# Envoy 設定確認

# テスト用オーバーライド
: "${ENVOY_BIN:=envoy}"
: "${ENVOY_CONF_FILE:=}"

_ENVOY_SUGGEST=false

_find_envoy_conf() {
    if [[ -n "$ENVOY_CONF_FILE" ]]; then
        echo "$ENVOY_CONF_FILE"
        return
    fi
    for path in /etc/envoy/envoy.yaml /etc/envoy/config.yaml /opt/envoy/envoy.yaml; do
        [[ -f "$path" ]] && echo "$path" && return
    done
}

check_envoy() {
    _ENVOY_SUGGEST=false
    log_section "STEP 4: Envoy 設定確認"

    if [[ -z "$ENVOY_CONF_FILE" ]]; then
        if ! command -v "$ENVOY_BIN" &>/dev/null; then
            log_skip "Envoy が見つかりません"
            return 0
        fi
        local version
        version=$("$ENVOY_BIN" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "不明")
        log_info "Envoy $version を検出"
    fi

    local conf
    conf=$(_find_envoy_conf)
    if [[ -z "$conf" ]]; then
        log_skip "Envoy 設定ファイルが見つかりません"
        return 0
    fi

    # http2_options セクションの有無
    if ! grep -q 'http2_options' "$conf" 2>/dev/null; then
        log_warn "http2_options が未設定（max_concurrent_streams がデフォルト値のまま）"
        _ENVOY_SUGGEST=true
        return 0
    fi

    # max_concurrent_streams
    local streams
    streams=$(grep 'max_concurrent_streams' "$conf" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    if [[ -z "$streams" ]]; then
        log_warn "http2_options.max_concurrent_streams が未設定 → 100 以下を推奨"
        _ENVOY_SUGGEST=true
    elif [[ "$streams" -le 100 ]]; then
        log_ok "max_concurrent_streams = $streams"
    else
        log_warn "max_concurrent_streams = $streams（推奨: 100 以下）"
        _ENVOY_SUGGEST=true
    fi

    # max_request_headers_kb
    local headers_kb
    headers_kb=$(grep 'max_request_headers_kb' "$conf" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    if [[ -z "$headers_kb" ]]; then
        log_warn "max_request_headers_kb が未設定（推奨: 60 以下）"
        _ENVOY_SUGGEST=true
    elif [[ "$headers_kb" -le 60 ]]; then
        log_ok "max_request_headers_kb = ${headers_kb}KB"
    else
        log_warn "max_request_headers_kb = ${headers_kb}KB（推奨: 60 以下）"
        _ENVOY_SUGGEST=true
    fi
}

suggest_envoy() {
    [[ "$_ENVOY_SUGGEST" != true ]] && return 0
    _emit ""
    _emit "  ${_C_BOLD}Envoy 推奨設定 (http_connection_manager):${_C_NC}"
    _emit "  http2_options:"
    _emit "    max_concurrent_streams: 100"
    _emit "    hpack_table_size: 4096"
    _emit "  max_request_headers_kb: 60"
}
