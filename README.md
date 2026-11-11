# agent-setup

Claude Code 에이전트 여러 개로 일하는 작업 환경 설정.

| 폴더 | 내용 |
|---|---|
| `claude/` | Claude Code 개인 설정(`settings.json`, `CLAUDE.md`), hooks(컨텍스트 정리 권유, 작업 알림), 개인 스킬 `dispatch-work-sessions` |
| `hammerspoon/` | 에이전트 알림 배너(소리 없음, 클릭하면 그 패널로 이동), Ghostty 이미지 붙여넣기 |
| `herdr/` | Herdr 터미널 관리 설정 |
| `ghostty/` | Ghostty 터미널 설정 |
| `Brewfile` | claude-code@latest, hammerspoon, herdr, gh, node |

## 새 맥에 설치

```sh
gh auth login && gh repo clone camosss/agent-setup ~/agent-setup && ~/agent-setup/install.sh
```

이미 있는 설정은 `<파일>.bak.<시각>` 으로 백업한 뒤 덮어쓴다. 끝나면 남은 손 작업(로그인, 업무용 플러그인, 손쉬운 사용 권한)을 출력한다.

## 동기화

설정은 레포로 링크하지 않고 복사한다. Claude Code 가 설정 파일을 새로 써서 링크가 끊기는 일을 피하기 위해서다.

- `./sync.sh`: 지금 쓰는 설정을 레포로 복사하고, 바뀐 게 있으면 커밋하고 push 한다
- `./sync.sh --dry-run`: 바뀐 파일만 보여 준다
- launchd 가 매일 21:00 에 `sync.sh` 를 돌린다. 로그는 `/tmp/agent-setup-sync.log`

복사할 파일 목록은 `paths.txt` 한 곳에서 관리한다. 홈 경로는 `__HOME__` 으로 저장하고 설치할 때 되돌린다. 토큰처럼 보이는 문자열이 있으면 커밋하지 않고 멈춘다.

## 넣지 않는 것

공개 레포라 개인, 업무 정보는 올리지 않는다.

- 메모리(`~/.claude/projects/*/memory`), 세션 기록
- 업무용 스킬, 플러그인, auto mode 환경 설명: 따로 설치한다
- 토큰, 인증 파일
- Herdr 가이드(`~/.claude/agent-guides`): 원본 [2ykwang/dotfiles](https://github.com/2ykwang/dotfiles/tree/main/agent-guides)에 라이선스가 없어 다시 배포하지 않고, `install.sh` 가 고정 커밋에서 받아 온다

### 비공개 정보 거르기

`sync.sh` 는 레포 밖 `~/.config/agent-setup/private.json` 을 읽어 비공개 단어가 들어간 설정을 빼고, 지정한 이름을 일반 이름으로 바꾼 뒤 올린다. 비공개 단어가 하나라도 남으면 커밋하지 않고 멈춘다. 형식은 `private.example.json`. `install.sh` 는 이 파일이 있으면 바꾼 이름을 원래대로 되돌린다.
