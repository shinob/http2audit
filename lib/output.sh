#!/usr/bin/env bash
# Output helpers for http2audit

# Colors (disabled when not a tty or NO_COLOR is set)
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    _C_OK='\033[0;32m'
    _C_WARN='\033[1;33m'
    _C_INFO='\033[0;34m'
    _C_SKIP='\033[0;37m'
    _C_BOLD='\033[1m'
    _C_NC='\033[0m'
else
    _C_OK='' _C_WARN='' _C_INFO='' _C_SKIP='' _C_BOLD='' _C_NC=''
fi

_OK_COUNT=0
_WARN_COUNT=0
_INFO_COUNT=0
_SKIP_COUNT=0

REPORT_FILE="${REPORT_FILE:-}"

_strip_ansi() {
    local esc
    esc=$'\033'
    sed "s/${esc}\[[0-9;]*[mK]//g"
}

_emit() {
    local msg="$1"
    printf '%b\n' "$msg"
    if [[ -n "$REPORT_FILE" ]]; then
        printf '%b\n' "$msg" | _strip_ansi >> "$REPORT_FILE"
    fi
}

log_ok()   { _OK_COUNT=$((_OK_COUNT + 1));     _emit "${_C_OK}[OK]${_C_NC}   $*"; }
log_warn() { _WARN_COUNT=$((_WARN_COUNT + 1)); _emit "${_C_WARN}[WARN]${_C_NC} $*"; }
log_info() { _INFO_COUNT=$((_INFO_COUNT + 1)); _emit "${_C_INFO}[INFO]${_C_NC} $*"; }
log_skip() { _SKIP_COUNT=$((_SKIP_COUNT + 1)); _emit "${_C_SKIP}[SKIP]${_C_NC} $*"; }

log_section() { _emit "\n${_C_BOLD}--- $* ---${_C_NC}"; }

log_summary() {
    _emit ""
    _emit "${_C_BOLD}=== サマリー ===${_C_NC}"
    _emit "${_C_OK}[OK]${_C_NC}: $_OK_COUNT  ${_C_WARN}[WARN]${_C_NC}: $_WARN_COUNT  ${_C_INFO}[INFO]${_C_NC}: $_INFO_COUNT  ${_C_SKIP}[SKIP]${_C_NC}: $_SKIP_COUNT"
    if [[ $_WARN_COUNT -gt 0 ]]; then
        _emit ""
        _emit "${_C_WARN}警告があります。上記の改善提案を確認してください。${_C_NC}"
    fi
}
