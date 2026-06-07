#!/usr/bin/env bash
# テストランナー（追加インストール不要）
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAIL=0

for f in "$DIR"/*_test.sh; do
    [[ -f "$f" ]] || continue
    printf '\n\033[1m--- %s ---\033[0m\n' "$(basename "$f")"
    bash "$f" || FAIL=$((FAIL + 1))
done

echo ""
if [[ $FAIL -eq 0 ]]; then
    printf '\033[0;32mAll tests passed.\033[0m\n'
    exit 0
else
    printf '\033[0;31m%d test file(s) failed.\033[0m\n' "$FAIL"
    exit 1
fi
