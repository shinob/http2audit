#!/usr/bin/env bash
# Apache 設定確認

# テスト用オーバーライド
: "${APACHE_BIN:=apachectl}"
: "${HTTPD_BIN:=httpd}"
: "${APACHE_CONF_FILE:=}"

_APACHE_SUGGEST=false

_apache_conf_grep() {
    local pattern="$1"
    if [[ -n "$APACHE_CONF_FILE" ]]; then
        grep -E "$pattern" "$APACHE_CONF_FILE" 2>/dev/null || true
        return
    fi
    {
        grep -rE "$pattern" /etc/apache2/ 2>/dev/null
        grep -rE "$pattern" /etc/httpd/ 2>/dev/null
    } || true
}

_apache_bin() {
    _locate_bin "$APACHE_BIN" "$HTTPD_BIN"
}

check_apache() {
    _APACHE_SUGGEST=false
    log_section "STEP 4: Apache 設定確認"

    if [[ -z "$APACHE_CONF_FILE" ]]; then
        local bin
        bin=$(_apache_bin)
        if [[ -z "$bin" ]]; then
            log_skip "Apache が見つかりません（PATH と一般的な設置場所を確認しました。場所が分かる場合は APACHE_BIN=/path/to/apachectl または HTTPD_BIN=/path/to/httpd で指定してください）"
            return 0
        fi
        local version
        version=$("$bin" -v 2>&1 | grep -oE 'Apache/[0-9.]+' | head -1 || echo "不明")
        log_info "$version を検出 ($bin)"

        # mod_http2 有効確認
        if "$bin" -M 2>/dev/null | grep -qi 'http2_module'; then
            log_warn "mod_http2 が有効です"
        else
            log_ok "mod_http2 は無効です"
            return 0
        fi
    else
        # テストモード: 設定ファイルで Protocols h2 を確認（grep -w でポータブルに）
        if ! _apache_conf_grep 'Protocols' | grep -qw 'h2'; then
            log_ok "HTTP/2 プロトコル (h2) は設定されていません"
            return 0
        fi
        log_warn "Protocols h2 が設定されています（HTTP/2 有効）"
    fi

    _APACHE_SUGGEST=true

    # H2MaxSessionStreams
    local streams
    streams=$(_apache_conf_grep 'H2MaxSessionStreams' \
        | sed 's/.*H2MaxSessionStreams[[:space:]]*//' \
        | grep -oE '^[0-9]+' | head -1)
    if [[ -z "$streams" ]]; then
        log_warn "H2MaxSessionStreams が未設定（デフォルト: 100）→ 50 以下を推奨"
    elif [[ "$streams" -le 50 ]]; then
        log_ok "H2MaxSessionStreams = $streams"
        _APACHE_SUGGEST=false
    else
        log_warn "H2MaxSessionStreams = $streams（推奨: 50 以下）"
    fi

    # H2StreamMaxMemSize
    local mem
    mem=$(_apache_conf_grep 'H2StreamMaxMemSize' \
        | sed 's/.*H2StreamMaxMemSize[[:space:]]*//' \
        | grep -oE '^[0-9]+' | head -1)
    if [[ -z "$mem" ]]; then
        log_warn "H2StreamMaxMemSize が未設定（推奨: 明示的に 65536 を設定）"
        _APACHE_SUGGEST=true
    else
        log_ok "H2StreamMaxMemSize = $mem"
    fi

    # LimitRequestFields
    local fields
    fields=$(_apache_conf_grep 'LimitRequestFields' \
        | sed 's/.*LimitRequestFields[[:space:]]*//' \
        | grep -oE '^[0-9]+' | head -1)
    if [[ -z "$fields" ]]; then
        log_warn "LimitRequestFields が未設定（デフォルト: 100）→ 50 以下を推奨"
        _APACHE_SUGGEST=true
    elif [[ "$fields" -le 50 ]]; then
        log_ok "LimitRequestFields = $fields"
    else
        log_warn "LimitRequestFields = $fields（推奨: 50 以下）"
        _APACHE_SUGGEST=true
    fi
}

suggest_apache() {
    [[ "$_APACHE_SUGGEST" != true ]] && return 0
    _emit ""
    _emit "  ${_C_BOLD}Apache 推奨設定 (VirtualHost または httpd.conf):${_C_NC}"
    _emit "  H2MaxSessionStreams 50"
    _emit "  H2WindowSize 65535"
    _emit "  H2StreamMaxMemSize 65536"
    _emit "  LimitRequestFields 50"
    _emit "  → apachectl configtest && systemctl reload apache2"
}
