#!/usr/bin/env python3
"""PreToolUse(Bash) 훅: 컨텍스트가 큰 Herdr 작업 세션(p<번호>-...)에 새 지시를 보내지 못하게 막는다.

작업 세션은 작업 하나가 끝나면 닫고 새로 연다(dispatch-work-sessions 규칙).
`herdr agent prompt <p번호-이름>` 대상 세션의 마지막 컨텍스트가 한도를 넘으면 차단한다.
진행 중인 작업의 질문 답, 정정은 지시문에 [답변] 을 넣으면 통과하고 기록을 남긴다.
오류가 나면 막지 않는다(fail open).
"""
import glob
import json
import os
import re
import subprocess
import sys
import time

LIMIT = int(os.environ.get("HERDR_REUSE_LIMIT", "150000"))
BYPASS = "[답변]"
LOG = os.path.expanduser("~/.claude/hooks/state/herdr-session-reuse.log")
TARGET_RE = re.compile(r"\bp\d+-[a-z0-9][a-z0-9-]*")


def log(line):
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + line + "\n")
    except Exception:
        pass


def session_id(name):
    out = subprocess.run(["herdr", "agent", "get", name], capture_output=True, text=True, timeout=5)
    if out.returncode != 0:
        return None
    data = json.loads(out.stdout).get("result", {})
    agent = data.get("agent", data)
    return (agent.get("agent_session") or {}).get("value")


def last_context(sid):
    files = glob.glob(os.path.expanduser(f"~/.claude/projects/*/{sid}.jsonl"))
    if not files:
        return None
    path = files[0]
    size = os.path.getsize(path)
    with open(path, "rb") as f:
        f.seek(max(0, size - 3_000_000))
        tail = f.read().decode("utf-8", "ignore")
    for line in reversed(tail.splitlines()):
        if '"usage"' not in line:
            continue
        try:
            usage = json.loads(line).get("message", {}).get("usage")
        except Exception:
            continue
        if usage:
            return (
                usage.get("input_tokens", 0)
                + usage.get("cache_read_input_tokens", 0)
                + usage.get("cache_creation_input_tokens", 0)
            )
    return None


def main():
    data = json.load(sys.stdin)
    if data.get("tool_name") != "Bash":
        return
    cmd = (data.get("tool_input") or {}).get("command", "")
    if not re.search(r"\bherdr\b.*\bagent\s+prompt\b", cmd, re.S):
        return
    targets = sorted(set(TARGET_RE.findall(cmd)))
    if not targets:
        return
    over = []
    for name in targets:
        sid = session_id(name)
        if not sid:
            continue
        ctx = last_context(sid)
        if ctx is not None and ctx > LIMIT:
            over.append((name, ctx))
    if not over:
        return
    desc = ", ".join(f"{n} {c:,} 토큰" for n, c in over)
    if BYPASS in cmd:
        log(f"BYPASS {desc} :: {cmd[:200]!r}")
        return
    log(f"DENY {desc}")
    reason = (
        f"컨텍스트가 큰 작업 세션에 새 지시를 보내려 했습니다({desc}, 한도 {LIMIT:,}). "
        "작업 하나가 끝난 세션은 `work-sessions close` 로 닫고, 새 일은 새 세션(--model opus)으로 여세요. "
        f"진행 중인 그 작업의 질문 답이나 정정이라면 지시문에 {BYPASS} 를 넣어 다시 보내세요."
    )
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # fail open
        log(f"ERROR {e!r}")
