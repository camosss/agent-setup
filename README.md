# agent-setup

## 목적

- Claude Code 에이전트 여러 개를 띄우고, 조율하고, 알림 받는 작업 환경을 명령 하나로 설치한다
- 설정을 바꾸면 이 레포로 자동 동기화한다. 맥을 바꿔도 같은 환경에서 바로 이어 간다
- 토큰을 적게 쓰는 방향으로 맞춰 둔 설정이다(일찍 압축, 작업 단위 세션, 안 쓰는 커넥터 차단)

## 찾기

| 찾는 것 | 위치 |
|---------|------|
| 새 맥에 설치 | ↓ [설치](#설치) |
| 무엇이 들어 있나 | ↓ [구성](#구성) |
| 토큰 절감 설정 | ↓ [토큰 절감](#토큰-절감) |
| 설정 바꾼 뒤 올리기 | ↓ [동기화](#동기화) |
| 개인, 업무 정보 거르기 | ↓ [공개 레포 안전장치](#공개-레포-안전장치) |

## 설치

- 필요: macOS, [Homebrew](https://brew.sh), GitHub CLI 로그인

```bash
gh auth login
gh repo clone camosss/agent-setup ~/agent-setup
~/agent-setup/install.sh
```

- 하는 일: `Brewfile` 설치 → 기존 설정을 `<파일>.bak.<시각>` 으로 백업 → 설정 넣기 → Herdr 가이드 받기 → 매일 자동 동기화 등록 → Hammerspoon 다시 불러오기
- 끝나면 남은 손 작업을 출력한다

| 남은 손 작업 | 이유 |
|-------------|------|
| `claude` 실행 후 로그인 | 계정은 레포에 없다 |
| 업무용 플러그인, 스킬, auto mode 환경 설명 설치 | 공개 레포라 넣지 않았다 |
| `~/.config/agent-setup/private.json` 만들기 | `sync.sh` 가 이 파일 없이는 돌지 않는다 ([형식](./private.example.json)) |
| Hammerspoon 손쉬운 사용 허용 | Ghostty 이미지 붙여넣기 단축키 |

## 구성

| 폴더 | 설치 위치 | 내용 |
|------|-----------|------|
| [`claude/settings.json`](./claude/settings.json) | `~/.claude/settings.json` | 모델, 자동 압축 기준, 기록 보관 기간, 커넥터 차단, hook 등록, auto mode 규칙 |
| [`claude/CLAUDE.md`](./claude/CLAUDE.md) | `~/.claude/CLAUDE.md` | 모든 세션 공통 지시(한국어 답변, 압축 때 남길 것, 서브에이전트 사용, 작업 세션 운영) |
| [`claude/hooks/`](./claude/hooks) | `~/.claude/hooks/` | 컨텍스트 정리 권유, 작업 끝 알림, Herdr 탭 표시 |
| [`claude/skills/dispatch-work-sessions/`](./claude/skills/dispatch-work-sessions) | `~/.claude/skills/` | 조율 세션이 작업 세션을 열고, 지시하고, 작업이 끝나면 닫는 스킬 |
| [`hammerspoon/`](./hammerspoon) | `~/.hammerspoon/` | 에이전트 알림 배너(소리 없음, 클릭하면 그 패널로 이동), 이미지 붙여넣기 |
| [`herdr/`](./herdr) | `~/.config/herdr/` | 에이전트 패널 정렬, 라벨, 세션 복원, 마지막 알림 패널로 이동(`prefix+j`) |
| [`ghostty/`](./ghostty) | `~/.config/ghostty/` | 터미널 설정 |
| [`Brewfile`](./Brewfile) | - | `claude-code@latest`, hammerspoon, herdr, gh, node |
| [`launchd/`](./launchd) | `~/Library/LaunchAgents/` | 매일 21:00 자동 동기화 |

## 토큰 절감

오래 이어 쓰는 세션이 매 턴 큰 컨텍스트를 다시 읽는 비용이 사용량 대부분을 차지한다. 그래서 컨텍스트를 작게 유지하는 쪽으로 맞췄다.

| 설정 | 값 | 효과 |
|------|----|------|
| `autoCompactWindow` | 400K | 1M 모델 기본값(약 967K)보다 일찍 압축해 턴마다 읽는 양을 절반 아래로 |
| `cleanupPeriodDays` | 14 | 오래된 세션 기록 자동 삭제 |
| `deniedMcpServers` | 안 쓰는 커넥터 | 도구 정의가 매 세션 컨텍스트에 들어가지 않게 |
| [`context-hygiene.py`](./claude/hooks/context-hygiene.py) | 200K, 300K | 200K 넘으면 주제가 바뀐 요청에 `/clear` 권유, 300K 넘으면 인수인계 메모를 바로 쓰고 새 세션 권유 |
| `CLAUDE.md` 압축 규칙 | - | 압축 요약에 목표, 카드 번호, 브랜치, PR, 남은 일, 결정을 반드시 남김 |
| 작업 단위 세션 | - | 작업 세션은 PR, 리뷰 반영이 끝나면 닫고 다음 작업 때 새로 연다 |

## 동작

- 메시지를 보낼 때: `context-hygiene` hook 이 마지막 응답의 컨텍스트 크기를 읽고, 기준을 넘으면 Claude 에게 정리 권유를 지시한다. 같은 권유는 100K 더 늘기 전에는 반복하지 않는다
- 작업이 끝나거나 입력을 기다릴 때: 보고 있지 않은 패널이면 Hammerspoon 배너를 띄우고 Herdr 탭에 표시를 붙인다
- 조율 세션: 작업 세션을 열어 지시하고, 완료 보고(PR 링크, 남은 일)를 검증하면 닫는다. 커밋 안 한 변경이나 push 안 한 커밋이 있으면 닫지 않는다
- 하루 한 번: 지금 쓰는 설정을 이 레포로 동기화한다

## 동기화

설정은 레포로 링크하지 않고 복사한다. Claude Code 가 설정 파일을 새로 써서 링크가 끊기는 일을 피하기 위해서다.

| 명령 | 용도 |
|------|------|
| `./sync.sh` | 지금 쓰는 설정을 레포로 복사, 바뀐 게 있으면 커밋하고 push |
| `./sync.sh --dry-run` | 바뀐 파일만 보기 |
| `./install.sh` | 레포 설정을 이 맥에 설치 |

- 관리할 파일 목록은 [`paths.txt`](./paths.txt) 한 곳. 새 설정 파일은 여기에 한 줄 추가
- 홈 경로는 `__HOME__` 으로 저장하고 설치할 때 되돌린다
- 자동 동기화 로그: `/tmp/agent-setup-sync.log`

## 공개 레포 안전장치

- `sync.sh` 는 레포 밖 `~/.config/agent-setup/private.json` 을 읽는다
  - 비공개 단어가 들어간 auto mode 규칙, 플러그인 마켓, 텔레메트리 값, 지정한 `CLAUDE.md` 블록을 뺀다
  - 지정한 이름을 일반 이름으로 바꾼다
  - 그래도 비공개 단어나 토큰처럼 보이는 문자열이 남으면 커밋하지 않고 멈춘다
- `install.sh` 는 `private.json` 이 있으면 바꾼 이름을 되돌리고, 기존 설정 파일의 비공개 값은 유지한다

## 넣지 않는 것

- 메모리(`~/.claude/projects/*/memory`), 세션 기록
- 업무용 스킬, 플러그인, 토큰과 인증 파일
- Herdr 가이드(`~/.claude/agent-guides`): 원본 [2ykwang/dotfiles](https://github.com/2ykwang/dotfiles/tree/main/agent-guides)에 라이선스가 없어 다시 배포하지 않고, `install.sh` 가 고정 커밋에서 받아 온다
