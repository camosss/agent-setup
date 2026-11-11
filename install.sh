#!/bin/bash
# 새 맥에 에이전트 작업 환경을 설치한다.
#   gh auth login && gh repo clone camosss/agent-setup ~/agent-setup && ~/agent-setup/install.sh
# 이미 있는 파일은 <파일>.bak.<시각> 으로 백업하고 덮어쓴다.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO"
stamp="$(date +%Y%m%d-%H%M%S)"

# 1. 프로그램 설치
command -v brew >/dev/null || { echo "Homebrew 를 먼저 설치하세요: https://brew.sh" >&2; exit 1; }
brew bundle --file "$REPO/Brewfile"
[[ -d /Applications/Ghostty.app ]] || brew install --cask ghostty

# 2. 설정 파일 넣기
while IFS='|' read -r rel live; do
  [[ -z "$rel" || "$rel" == \#* ]] && continue
  live="${live/#\~/$HOME}"
  [[ -e "$rel" ]] || continue
  mkdir -p "$(dirname "$live")"
  if [[ -e "$live" ]]; then
    if [[ -d "$rel" ]]; then
      cp -R "$live" "$live.bak.$stamp"
    else
      cmp -s "$rel" "$live" || cp "$live" "$live.bak.$stamp"
    fi
  fi
  if [[ "$rel" == claude/settings.json && -e "$live" ]]; then
    # 레포에 없는 비공개 값(auto mode 환경 설명과 규칙, 플러그인 마켓, 텔레메트리)은 기존 파일 것을 유지한다
    sed "s#__HOME__#$HOME#g" "$rel" | python3 -I -c '
import json, sys
new, old = json.load(sys.stdin), json.load(open(sys.argv[1]))
env = old.get("autoMode", {}).get("environment")
if env: new.setdefault("autoMode", {})["environment"] = env
for k in ("allow", "soft_deny"):
    extra = [r for r in old.get("autoMode", {}).get(k, []) if r not in new.get("autoMode", {}).get(k, [])]
    if extra: new.setdefault("autoMode", {}).setdefault(k, []).extend(extra)
for m, v in old.get("extraKnownMarketplaces", {}).items():
    new.setdefault("extraKnownMarketplaces", {}).setdefault(m, v)
otel = old.get("env", {}).get("OTEL_RESOURCE_ATTRIBUTES")
if otel: new.setdefault("env", {})["OTEL_RESOURCE_ATTRIBUTES"] = otel
json.dump(new, open(sys.argv[1], "w"), ensure_ascii=False, indent=2); open(sys.argv[1], "a").write("\n")
' "$live"
  elif [[ -d "$rel" ]]; then
    mkdir -p "$live"
    rsync -a "$rel/" "$live/"
    grep -rlI "__HOME__" "$live" 2>/dev/null | while read -r f; do sed -i '' "s#__HOME__#$HOME#g" "$f"; done
  else
    sed "s#__HOME__#$HOME#g" "$rel" > "$live"
  fi
  echo "설치: $live"
done < paths.txt

# private.json 이 있으면 sync.sh 가 바꿔 둔 이름을 원래대로 되돌린다
PRIVATE="$HOME/.config/agent-setup/private.json"
if [[ -f "$PRIVATE" ]]; then
  python3 -I - "$PRIVATE" <<'PY'
import json, os, sys
cfg = json.load(open(sys.argv[1]))
roots = [os.path.expanduser(p) for p in ("~/.claude/CLAUDE.md", "~/.claude/skills/dispatch-work-sessions")]
files = [r for r in roots if os.path.isfile(r)]
for r in roots:
    for d, _, fs in os.walk(r):
        files += [os.path.join(d, f) for f in fs]
for f in files:
    try:
        t = open(f).read()
    except UnicodeDecodeError:
        continue
    o = t
    for a, b in cfg.get("renames", []):
        t = t.replace(b, a)
    if t != o:
        open(f, "w").write(t)
PY
  echo "비공개 이름 되돌림: $PRIVATE"
else
  echo "참고: ~/.config/agent-setup/private.json 이 없어 일반 이름 그대로 설치했습니다(private.example.json 참고)."
fi
# Herdr 가이드는 원본(2ykwang/dotfiles, 라이선스 없음)을 다시 배포하지 않고 고정 커밋에서 받아 온다
guides="$HOME/.claude/agent-guides"
src="https://raw.githubusercontent.com/2ykwang/dotfiles/482f5d8/agent-guides"
mkdir -p "$guides/herdr"
for f in herdr.md herdr/operations.md herdr/automation.md; do
  curl -fsSL "$src/$f" -o "$guides/$f" || echo "가이드 받기 실패: $f"
done
echo "출처: https://github.com/2ykwang/dotfiles/tree/main/agent-guides (커밋 482f5d8)" > "$guides/SOURCE.txt"
chmod +x "$HOME"/.claude/hooks/*.sh "$HOME"/.claude/skills/dispatch-work-sessions/scripts/* 2>/dev/null || true

# 3. 하루 한 번 자동 동기화
plist="$HOME/Library/LaunchAgents/com.camosss.agent-setup-sync.plist"
sed "s#__HOME__#$HOME#g" "$REPO/launchd/com.camosss.agent-setup-sync.plist" > "$plist"
launchctl bootout "gui/$(id -u)" "$plist" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$plist"
echo "자동 동기화 등록: 매일 21:00"

# 4. Hammerspoon 설정 다시 불러오기
open -g -a Hammerspoon 2>/dev/null && open -g "hammerspoon://reload" 2>/dev/null || true

cat <<'EOF'

남은 손 작업
1. claude 실행 후 로그인
2. 업무용 플러그인, 스킬, auto mode 환경 설명(autoMode.environment)은 레포에 없으니 따로 설치한다
3. ~/.config/agent-setup/private.json 을 만든다(private.example.json 참고). sync.sh 가 이 파일 없이는 돌지 않는다
4. Hammerspoon: 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 허용 (Cmd+V 이미지 붙여넣기)
5. Ghostty 를 열고 herdr 실행
EOF
