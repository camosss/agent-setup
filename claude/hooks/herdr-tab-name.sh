#!/bin/sh
# herdr 탭 이름을 그 탭의 대표 Claude 세션 제목으로 맞춘다
# 사용: herdr-tab-name.sh [pane_id]   pane_id를 생략하면 HERDR_PANE_ID
# - 대표 세션은 탭의 왼쪽 위 칸이다. 다른 칸에서 불리면 아무것도 하지 않는다
# - 탭 이름이 숫자(기본값)이거나 이 스크립트가 붙인 이름일 때만 바꾼다. 직접 바꾼 이름은 두지 않는다
# - 앞에 붙은 ❗️ 표시(herdr-tab-dot.sh)는 유지한다
pane="${1:-${HERDR_PANE_ID:-}}"
[ -n "$pane" ] || exit 0
H="${HERDR_BIN_PATH:-$HOME/.local/bin/herdr}"
command -v "$H" >/dev/null 2>&1 || H=herdr

H="$H" PANE="$pane" STATE="$HOME/.claude/hooks/herdr-tab-names.json" python3 - <<'PY' || exit 0
import json, os, re, subprocess

H, pane, state_path = os.environ["H"], os.environ["PANE"], os.environ["STATE"]
DOT_PREFIXES = ("❗️ ", "• ", "🔵 ", "● ")
MAX_LEN = 20
DEFAULT_TITLES = {"", "Claude Code", "claude"}

def herdr(*args):
    out = subprocess.run([H, *args], capture_output=True, text=True, timeout=5)
    if out.returncode != 0:
        raise SystemExit(0)
    return json.loads(out.stdout)["result"]

info = herdr("pane", "get", pane)["pane"]
title = (info.get("terminal_title_stripped") or "").strip()
if title in DEFAULT_TITLES:
    raise SystemExit(0)

panes = herdr("pane", "layout", "--pane", pane)["layout"]["panes"]
top_left = min(panes, key=lambda p: (p["rect"]["y"], p["rect"]["x"]))
if top_left["pane_id"] != pane:
    raise SystemExit(0)

tab_id = info["tab_id"]
tab = herdr("tab", "get", tab_id)
label = ((tab.get("tab") or tab).get("label") or "")
prefix = next((p for p in DOT_PREFIXES if label.startswith(p)), "")
base = label[len(prefix):]

try:
    with open(state_path) as f:
        state = json.load(f)
except Exception:
    state = {}

is_auto = base.isdigit() or state.get(tab_id) == base
if not is_auto:
    raise SystemExit(0)

name = re.sub(r"^PROJECT-\d+\s+", "", title)
if len(name) > MAX_LEN:
    name = name[:MAX_LEN - 1] + "…"
if name == base:
    raise SystemExit(0)

subprocess.run([H, "tab", "rename", tab_id, prefix + name],
               capture_output=True, timeout=5)
state[tab_id] = name
with open(state_path, "w") as f:
    json.dump(state, f, ensure_ascii=False)
PY
exit 0
