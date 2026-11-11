#!/bin/sh
# herdr 탭 이름 앞에 ❗️ 표시를 붙이거나 지운다. (2026-11-09)
# 사용: herdr-tab-dot.sh add|clear [pane_id]   pane_id를 생략하면 HERDR_PANE_ID
# - add: Claude가 끝났는데 그 창을 보고 있지 않을 때 (herdr-banner-notify.sh가 호출)
# - clear: 그 창에서 프롬프트를 보냈을 때(UserPromptSubmit 훅), 배너를 눌러 이동했을 때
mode="${1:-add}"; pane="${2:-${HERDR_PANE_ID:-}}"
[ -n "$pane" ] || exit 0
H="${HERDR_BIN_PATH:-$HOME/.local/bin/herdr}"
command -v "$H" >/dev/null 2>&1 || H=herdr
tab="$("$H" pane get "$pane" 2>/dev/null | python3 -c 'import sys,json;r=json.load(sys.stdin)["result"];print((r.get("pane") or r).get("tab_id",""))' 2>/dev/null)"
[ -n "$tab" ] || exit 0
label="$("$H" tab get "$tab" 2>/dev/null | python3 -c 'import sys,json;r=json.load(sys.stdin)["result"];print((r.get("tab") or r).get("label") or "")' 2>/dev/null)"
[ -n "$label" ] || exit 0
DOT="❗️ "   # 사용자 선택 (2026-11-09). herdr 탭 이름은 색 코드를 지원하지 않는다.
OLD="• "    # 예전 표시
OLD2="🔵 "  # 예전 표시
case "$mode" in
  add)
    case "$label" in
      "$DOT"*) ;;
      "$OLD"*) "$H" tab rename "$tab" "$DOT${label#"$OLD"}" >/dev/null 2>&1 ;;
      "$OLD2"*) "$H" tab rename "$tab" "$DOT${label#"$OLD2"}" >/dev/null 2>&1 ;;
      *) "$H" tab rename "$tab" "$DOT$label" >/dev/null 2>&1 ;;
    esac ;;
  clear)
    case "$label" in
      "$DOT"*) "$H" tab rename "$tab" "${label#"$DOT"}" >/dev/null 2>&1 ;;
      "$OLD"*) "$H" tab rename "$tab" "${label#"$OLD"}" >/dev/null 2>&1 ;;
      "$OLD2"*) "$H" tab rename "$tab" "${label#"$OLD2"}" >/dev/null 2>&1 ;;
    esac ;;
esac
exit 0
