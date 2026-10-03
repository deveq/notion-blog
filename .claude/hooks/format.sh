#!/usr/bin/env bash
# Claude Code PostToolUse 훅 → 수정된 파일 자동 포맷
#
# Edit/Write 직후 해당 파일 하나에 eslint --fix → prettier --write 를 실행한다.
# 자동수정 불가능한 ESLint 에러가 남으면 exit 2 로 stderr 를 Claude 에게 돌려보내 직접 고치게 하고,
# 그 외 실패(도구 없음 등)는 세션을 방해하지 않도록 exit 0 으로 흡수한다.
set -uo pipefail

payload="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0

file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -n "$file" ] && [ -f "$file" ] || exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$file" in
  "$root"/node_modules/* | "$root"/.next/*) exit 0 ;;
  "$root"/*) ;;
  *) exit 0 ;;
esac

bin="$root/node_modules/.bin"
[ -x "$bin/prettier" ] || exit 0
cd "$root" || exit 0

case "$file" in
  *.ts | *.tsx | *.js | *.jsx | *.mjs | *.cjs)
    if [ -x "$bin/eslint" ]; then
      lint_out="$("$bin/eslint" --fix --no-warn-ignored "$file" 2>&1)"
      lint_code=$?
    fi
    "$bin/prettier" --write --log-level warn "$file" >/dev/null 2>&1
    if [ "${lint_code:-0}" -ne 0 ]; then
      printf '[format hook] ESLint 자동수정 후에도 남은 에러가 있습니다:\n%s\n' "$lint_out" >&2
      exit 2
    fi
    ;;
  *.json | *.css | *.md)
    "$bin/prettier" --write --log-level warn "$file" >/dev/null 2>&1
    ;;
esac

exit 0
