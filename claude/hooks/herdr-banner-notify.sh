#!/bin/sh
# herdr 안에서 도는 Claude Code가 작업을 끝내거나(Stop) 입력을 기다릴 때(Notification)
# macOS 배너를 띄운다. herdr 자체 알림이 동작하지 않아 Claude Code 훅으로 대신한다. (2026-11-09)
# - herdr 밖(Claude 데스크톱 앱 등)에서는 아무것도 하지 않는다.
# - 지금 보고 있는 창(herdr 포커스 + Ghostty가 맨 앞)이면 띄우지 않는다.
# 사용: herdr-banner-notify.sh stop | notification   (훅 입력 JSON은 stdin)

kind="${1:-stop}"
input="$(cat 2>/dev/null || true)"

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
command -v osascript >/dev/null 2>&1 || exit 0

HERDR="${HERDR_BIN_PATH:-herdr}"
pane_json="$("$HERDR" pane get "$HERDR_PANE_ID" 2>/dev/null || true)"
front_app="$(lsappinfo info -only name "$(lsappinfo front 2>/dev/null)" 2>/dev/null || true)"

KIND="$kind" INPUT="$input" PANE_JSON="$pane_json" FRONT_APP="$front_app" python3 - <<'PY' || exit 0
import json, os, subprocess

kind = os.environ.get("KIND", "stop")
try:
    hook = json.loads(os.environ.get("INPUT") or "{}")
except Exception:
    hook = {}
try:
    res = json.loads(os.environ.get("PANE_JSON") or "{}").get("result", {})
    pane = res.get("pane", res) or {}
except Exception:
    pane = {}

# 지금 보고 있는 창이면 생략
if pane.get("focused") and "ghostty" in os.environ.get("FRONT_APP", "").lower():
    raise SystemExit(0)

# 서브에이전트 종료는 무시
if hook.get("agent_id"):
    raise SystemExit(0)

cwd = hook.get("cwd") or pane.get("cwd") or ""
title = (pane.get("label")
         or pane.get("terminal_title_stripped")
         or os.path.basename(cwd.rstrip("/"))
         or "Claude")

if kind == "notification":
    message = hook.get("message") or "입력을 기다리고 있어요"
else:
    message = (hook.get("last_assistant_message") or "").strip() or "작업을 마쳤어요"
message = " ".join(message.split())[:200]

subtitle = os.path.basename(cwd.rstrip("/")) if cwd else ""

if subtitle == title:
    subtitle = ""
pane_id = os.environ.get("HERDR_PANE_ID", "")

# 1순위: Hammerspoon이 그리는 배너 (클릭하면 해당 herdr 창으로 이동). ~/.hammerspoon/init.lua 참고.
# macOS 26에서는 terminal-notifier·hs.notify 같은 옛 알림 방식이 전달되지 않는다 (2026-11-09 확인).
from urllib.parse import urlencode, quote
hs_running = subprocess.run(["pgrep", "-x", "Hammerspoon"], stdout=subprocess.DEVNULL).returncode == 0
if hs_running:
    query = urlencode({"pane": pane_id, "title": title, "subtitle": subtitle, "message": message},
                      quote_via=quote)
    r = subprocess.run(["open", "-g", "hammerspoon://herdr-notify?" + query],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
    sent = r.returncode == 0
else:
    sent = False

# 2순위: Hammerspoon이 꺼져 있으면 osascript 배너 (클릭 이동 없음, 알림 센터에 "스크립트 편집기"로 표시)
script = '''on run argv
  set t to item 1 of argv
  set m to item 2 of argv
  set s to item 3 of argv
  if s is "" then
    display notification m with title t
  else
    display notification m with title t subtitle s
  end if
end run'''
if not sent:
    subprocess.run(["osascript", "-e", script, title, message, subtitle],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)

# 탭 이름 앞에 ● 표시 (그 창에서 프롬프트를 보내거나 배너로 이동하면 지워진다)
subprocess.run(["sh", os.path.expanduser("~/.claude/hooks/herdr-tab-dot.sh"), "add", pane_id],
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)

# 마지막 알림 창을 기록해 두고 Cmd+J(herdr prefix+j)로도 이동할 수 있게 한다.
try:
    with open(os.path.expanduser("~/.claude/hooks/herdr-last-notified"), "w") as f:
        f.write(os.environ.get("HERDR_PANE_ID", ""))
except Exception:
    pass
PY
exit 0
