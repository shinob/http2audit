#!/usr/bin/env bash
# OOM・メモリ異常ログ確認

# テスト用オーバーライド: ファイルパスを指定すると実コマンドの代わりに使用
: "${DMESG_OUTPUT_FILE:=}"
: "${JOURNALCTL_OUTPUT_FILE:=}"

_OOM_PATTERN='[Oo]ut of memory|[Oo]om.kill|[Kk]illed process'

_check_dmesg() {
    local output
    if [[ -n "$DMESG_OUTPUT_FILE" ]]; then
        output=$(cat "$DMESG_OUTPUT_FILE" 2>/dev/null || true)
    elif command -v dmesg &>/dev/null; then
        output=$(dmesg -T 2>/dev/null || dmesg 2>/dev/null || true)
    else
        log_skip "dmesg が見つかりません"
        return 0
    fi

    if echo "$output" | grep -qE "$_OOM_PATTERN"; then
        log_warn "dmesg に OOM の痕跡があります"
        echo "$output" | grep -E "$_OOM_PATTERN" | tail -3 | while IFS= read -r line; do
            log_info "  $line"
        done
    else
        log_ok "dmesg に OOM ログは見つかりませんでした"
    fi
}

_check_journalctl() {
    local output
    if [[ -n "$JOURNALCTL_OUTPUT_FILE" ]]; then
        output=$(cat "$JOURNALCTL_OUTPUT_FILE" 2>/dev/null || true)
    elif command -v journalctl &>/dev/null; then
        output=$(journalctl -k --since "24 hours ago" 2>/dev/null || true)
    else
        log_skip "journalctl が見つかりません"
        return 0
    fi

    if echo "$output" | grep -qEi "$_OOM_PATTERN"; then
        log_warn "journalctl に OOM の痕跡があります（過去24時間）"
    else
        log_ok "journalctl に OOM ログは見つかりませんでした（過去24時間）"
    fi
}

check_oom() {
    log_section "STEP 5: OOM・メモリ異常ログ確認"
    _check_dmesg
    _check_journalctl
}
