---
name: dispatch-work-sessions
description: 조율 세션이 플랫폼별(서버, iOS, Android, Web) Claude 작업 세션을 Herdr 로 직접 열어 지시까지 넣고, 작업 하나가 끝나면(PR, 리뷰 반영 완료 등) 닫았다가 다음 작업 때 새로 연다. 작업 세션의 완료 보고를 받았을 때도 쓴다. 같은 탭 오른쪽에 붙이고 패널 제목(Server, iOS, Android, Web, 조율은 검증)과 이름(p번호-플랫폼)을 정한다. "각 작업 스레드에 요청", "작업 세션 열고 전달해", "스레드 나눠서 진행", "세션 닫아" 같은 요청에 쓴다.
---

# 작업 세션 열기와 닫기

조율 세션이 작업 세션을 직접 만든다. 창을 열어 달라거나 세션 이름을 묻지 않는다.

## 열기

1. **플랫폼 고르기:** 영향 파악으로 실제 작업이 있는 플랫폼만 고른다(소비처, 구버전, 공용 파일, 어드민 데이터).
2. **worktree 만들기:** 플랫폼마다 저장소 본체 대신 worktree 를 만든다. 본체 폴더는 다른 세션이 쓰고 있을 수 있다.
   ```sh
   git -C ~/Desktop/server fetch -q origin develop
   git -C ~/Desktop/server worktree add -b feature/<카드번호>-<slug> ~/Desktop/server-<N> origin/develop
   ```
   브랜치 이름은 git-flow 규칙을 따른다. 작업 세션에 worktree 생성을 맡겨도 되지만, 그때는 열 때 cwd 를 저장소 본체로 주고 지시에 "새 worktree 에서 작업"을 넣는다.
3. **지시문 쓰기:** scratchpad 에 폴더를 만들고 `common.md`(공통)와 `<platform>.md` 를 쓴다. 공통에 반드시 넣는 것:
   - 조율 세션 이름(ListAgents 의 내 이름). 진행, 질문, 완료 보고는 모두 이 세션으로 SendMessage
   - 요구 원문 링크. 기획 문서에 적힌 결정은 되묻지 말고 따른다
   - 플랫폼 간에 맞춰야 할 값(이벤트 값, 필드 이름)은 표로 한 번만
   - push 와 PR 은 조율 세션 확인 후. 머지, 브랜치 삭제 금지. 릴리즈 대상이면 PR base
   - 커밋, PR, 주석에 사람 이름과 결정 경위 금지. 이벤트 코드가 바뀌면 tracking-sync
   - Android: 빌드와 테스트는 push 직전 한 번, 기기 확인은 실기기만
   - 완료 조건(아래 "작업 단위로 닫고 다시 열기")을 채우면 완료 보고를 보내고 새 일을 찾지 말고 대기. 완료 보고에는 PR 링크, 브랜치, 남은 일, 다음 작업자가 알아야 할 점
4. **실행:**
   ```sh
   ~/.claude/skills/dispatch-work-sessions/scripts/work-sessions open --project <N> \
     --session server=~/Desktop/server-<N> \
     --session ios=~/Desktop/ios-app-<N> \
     --session android=~/Desktop/android-app-<N> \
     --prompt-dir <scratchpad 지시문 폴더>
   ```
   스크립트가 하는 일:
   - 현재 패널과 탭을 확인합니다.
   - 같은 탭 맨 오른쪽에 칸을 나눕니다. 4칸을 넘으면 아래로 나눕니다.
   - `p<N>-<platform>` 이름으로 Claude 를 시작합니다.
   - 패널 제목을 붙입니다. 이 세션은 `검증`으로 붙입니다.
   - 지시를 보냅니다.
   - 끝나면 상태를 한 번 출력합니다.
5. **상태 확인:** 출력에 `blocked` 가 있으면 `herdr agent read p<N>-<platform> --lines 30` 로 승인 화면을 읽고 사용자에게 알린다. 대신 승인하지 않는다.
6. **보고:** 사용자에게 세션별 저장소, 브랜치, 맡은 일을 표 하나로 보고한다.

## 진행 중

- 작업 세션의 보고는 `<cross-session-message from-name=...>` 로 온다. 답은 그 from-name 으로 SendMessage. Herdr 이름(p<N>-ios)과 Claude 세션 이름(ios-app-21 같은)은 다르다.
- 추가 지시는 `herdr agent prompt p<N>-<platform> "..."` 또는 SendMessage 둘 다 된다.
- 한 플랫폼에서 정한 기준은 다른 플랫폼에도 같이 보낸다.
- 받은 보고를 하나씩 중계하지 말고 검증한 뒤 플랫폼별로 묶어 보고한다.

## 작업 단위로 닫고 다시 열기

작업 세션은 작업 하나가 끝나면 닫는다. 오래 이어 쓰면 매 턴 큰 컨텍스트를 다시 읽어 토큰이 많이 든다. 사용자에게 묻지 않고 조율 세션이 판단한다.

**완료 조건**
- 코드 작업: PR 생성, AI 리뷰 반영, 반영한 스레드 resolve 까지 끝남. 머지는 됐거나 사용자 승인 대기. 머지 대기에서도 닫고, 리뷰 추가 수정이나 QA 피드백이 오면 새로 연다
- 조사, 확인 작업: 결과를 조율 세션에 보고함

**닫기 전 검증** (조율 세션)
- 완료 보고에 PR 링크, 브랜치, 남은 일이 있는지. 이 보고가 다음 작업의 맥락이 되므로 인수인계 파일은 따로 쓰지 않는다
- 띄워 둔 시뮬레이터, 빌드, 로컬 서버가 없는지(있으면 그 세션에 정리시키고 닫는다)

```sh
~/.claude/skills/dispatch-work-sessions/scripts/work-sessions close --project <N> --platform <platform>
```

- `--platform` 을 빼면 그 프로젝트 작업 세션을 모두 닫는다
- 스크립트가 커밋 안 한 변경이나 push 안 한 커밋을 발견하면 닫지 않고 건너뛴다. 그 세션에 정리시키고 다시 닫는다. `--force` 는 쓰지 않는다
- 닫은 뒤 사용자 보고는 한 줄로 묶는다

**다음 작업**: 같은 플랫폼에 새 작업이 생기면 위 "열기"로 새로 연다. 같은 이름(p<N>-<platform>)과 패널 제목을 쓰고, 기존 worktree 가 있으면 그대로 cwd 로 준다. 지시에 이전 완료 보고의 PR 링크와 남은 일을 넣는다.

worktree 와 브랜치는 닫아도 남는다. 정리는 사용자가 요청하거나 머지된 브랜치 삭제 규칙에 따라 하고, 지우기 전에 머지 여부와 미커밋 변경을 확인한다.

## 함정

- Herdr 에이전트 이름은 영소문자로 시작해야 한다. `3872-ios` 는 거부되므로 `p3872-ios` 로 쓴다.
- zsh 에서 `S="herdr --session default"; $S ...` 는 명령 하나로 해석돼 실패한다. 함수로 감싸거나 이 스크립트를 쓴다.
- 새 탭으로 열지 않는다. 이미 다른 탭에 열었다면 `herdr pane move <pane> --tab <현재 탭> --target-pane <옆 칸> --split right` 로 옮긴다.
