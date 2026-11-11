#!/usr/bin/env python3
"""UserPromptSubmit hook: 컨텍스트가 커지면 Claude에게 /clear 또는 세션 인수인계를 권하도록 알린다.

transcript 끝부분만 읽어 마지막 응답의 컨텍스트 크기를 구한다.
같은 단계 알림은 컨텍스트가 100K 더 늘기 전에는 반복하지 않고, 압축이나 /clear 로 줄면 초기화한다.
"""
import json
import os
import sys

CLEAR_AT = 200_000
HANDOFF_AT = 300_000
RENOTIFY_GROWTH = 100_000
TAIL_BYTES = 2_000_000
STATE_DIR = os.path.expanduser("~/.claude/hooks/state/context-hygiene")


def last_context_tokens(path):
    with open(path, "rb") as f:
        f.seek(0, os.SEEK_END)
        f.seek(max(0, f.tell() - TAIL_BYTES))
        lines = f.read().splitlines()
    for raw in reversed(lines):
        if b'"usage"' not in raw:
            continue
        try:
            j = json.loads(raw)
        except ValueError:
            continue
        if j.get("type") != "assistant" or j.get("isSidechain"):
            continue
        u = (j.get("message") or {}).get("usage") or {}
        return (u.get("input_tokens", 0) + u.get("cache_read_input_tokens", 0)
                + u.get("cache_creation_input_tokens", 0))
    return 0


def main():
    data = json.load(sys.stdin)
    path = data.get("transcript_path")
    sid = data.get("session_id") or "unknown"
    if not path or not os.path.exists(path):
        return
    ctx = last_context_tokens(path)

    os.makedirs(STATE_DIR, exist_ok=True)
    state_path = os.path.join(STATE_DIR, sid + ".json")
    try:
        with open(state_path) as f:
            state = json.load(f)
    except (OSError, ValueError):
        state = {"level": 0, "ctx": 0}

    # 압축이나 /clear 로 크게 줄었으면 알림 상태 초기화
    if ctx < state["ctx"] - 50_000:
        state = {"level": 0, "ctx": ctx}

    level = 2 if ctx >= HANDOFF_AT else 1 if ctx >= CLEAR_AT else 0
    if level == 0:
        state["ctx"] = ctx
    elif level > state["level"] or ctx - state["ctx"] >= RENOTIFY_GROWTH:
        k = ctx // 1000
        if level == 2:
            msg = (f"[context-hygiene] 현재 컨텍스트 약 {k}K 토큰. 이번 요청을 처리한 뒤: 이전 작업과 무관한 요청이면 "
                   "답변 끝에 한 줄로 /clear 를 권한다. 같은 작업을 이어 가는 중이면 묻지 말고 "
                   "인수인계 메모(목표, 결정 사항, 진행 상태, 남은 일, PR/브랜치, 작업 세션 표, 받은 작업 방식 지시)를 "
                   "~/.claude/handoffs/<세션 이름>-<주제>.md 에 바로 써 두고(이미 있으면 갱신), 답변 끝에 "
                   "'인수인계 메모 갱신: <경로>. 새 세션으로 넘기려면 말씀하세요' 한 줄만 붙인다. "
                   "메모를 쓸지 묻지 않는다. 작업 도중이면 끝난 뒤로 미룬다.")
        else:
            msg = (f"[context-hygiene] 현재 컨텍스트 약 {k}K 토큰. 이번 요청이 지금까지의 작업과 무관한 새 주제일 때만 "
                   "답변 끝에 한 줄로 /clear 를 권한다. 같은 작업이면 아무 말도 하지 않는다.")
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit", "additionalContext": msg}}, ensure_ascii=False))
        state = {"level": level, "ctx": ctx}

    with open(state_path, "w") as f:
        json.dump(state, f)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
