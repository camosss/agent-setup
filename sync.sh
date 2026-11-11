#!/bin/bash
# 지금 쓰는 설정을 레포로 복사하고, 바뀐 게 있으면 커밋하고 push 한다.
#   ./sync.sh            복사 + 커밋 + push
#   ./sync.sh --dry-run  복사 후 바뀐 파일만 보여 주고 커밋하지 않는다
#
# 공개 레포라 개인, 조직 정보는 올리지 않는다. 거를 단어와 바꿀 이름은 레포 밖
# ~/.config/agent-setup/private.json 에 둔다(형식은 private.example.json). 이 파일이 없으면 멈춘다.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
PRIVATE="$HOME/.config/agent-setup/private.json"
cd "$REPO"
dry=0; [[ "${1:-}" == "--dry-run" ]] && dry=1
[[ -f "$PRIVATE" ]] || { echo "중단: $PRIVATE 가 없습니다. private.example.json 을 참고해 만드세요." >&2; exit 1; }

# 레포에 남기지 않는 실행 중 파일
EXCLUDES=(--exclude __pycache__ --exclude state --exclude herdr-last-notified --exclude .DS_Store)

while IFS='|' read -r rel live; do
  [[ -z "$rel" || "$rel" == \#* ]] && continue
  live="${live/#\~/$HOME}"
  [[ -e "$live" ]] || { echo "건너뜀(없음): $live"; continue; }
  mkdir -p "$(dirname "$rel")"
  if [[ -d "$live" ]]; then
    rsync -a --delete "${EXCLUDES[@]}" "$live/" "$rel/"
  else
    cp "$live" "$rel"
  fi
done < paths.txt

# 비공개 정보 거르기
python3 -I - "$PRIVATE" <<'PY'
import glob, json, re, sys
cfg = json.load(open(sys.argv[1]))
pat = re.compile(cfg["private_pattern"], re.I)

s = "claude/settings.json"
d = json.load(open(s))
if cfg.get("strip_automode_environment"):
    d.get("autoMode", {}).pop("environment", None)
for k in cfg.get("strip_settings_env", []):
    d.get("env", {}).pop(k, None)
# 비공개 단어가 들어간 auto mode 규칙, 플러그인 마켓은 뺀다(install.sh 가 기존 파일 것을 유지)
for k in ("allow", "soft_deny"):
    if d.get("autoMode", {}).get(k):
        d["autoMode"][k] = [r for r in d["autoMode"][k] if not pat.search(r)]
for m in [m for m, v in d.get("extraKnownMarketplaces", {}).items() if pat.search(m + json.dumps(v))]:
    del d["extraKnownMarketplaces"][m]
json.dump(d, open(s, "w"), ensure_ascii=False, indent=2); open(s, "a").write("\n")

for f in [f for f in glob.glob("*/**", recursive=True) if not f.startswith(".git")]:
    try:
        t = open(f).read()
    except (IsADirectoryError, UnicodeDecodeError):
        continue
    o = t
    for b in cfg.get("claude_md_blocks", []):
        t = re.sub(r"\n*<!-- %s:BEGIN -->.*?<!-- %s:END -->\n?" % (re.escape(b), re.escape(b)), "\n", t, flags=re.S)
    for a, b in cfg.get("renames", []):
        t = t.replace(a, b)
    if t != o:
        open(f, "w").write(t)
PY

# 홈 경로는 __HOME__ 으로 바꿔 둔다 (install.sh 가 되돌린다)
grep -rlI --exclude-dir=.git "$HOME" claude hammerspoon herdr ghostty 2>/dev/null | while read -r f; do
  sed -i '' "s#$HOME#__HOME__#g" "$f"
done

# 비공개 단어나 토큰처럼 보이는 문자열이 남아 있으면 멈춘다
pattern="$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1]))["private_pattern"])' "$PRIVATE")"
if grep -rniIE --exclude-dir=.git "$pattern" . ; then
  echo "중단: 비공개 단어가 남아 있습니다. 위 줄을 확인하세요." >&2
  exit 1
fi
if grep -rnIE --exclude-dir=.git '(ghp_|gho_|github_pat_)[A-Za-z0-9_]{20,}|sk-ant-[A-Za-z0-9_-]{20,}|xox[abpr]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY' . ; then
  echo "중단: 비밀값으로 보이는 문자열이 있습니다. 위 줄을 확인하세요." >&2
  exit 1
fi

git add -A
if git diff --cached --quiet; then
  echo "바뀐 설정 없음"
  exit 0
fi
git diff --cached --stat
if [[ $dry == 1 ]]; then
  git reset -q
  exit 0
fi
git commit -q -m "Sync settings $(date '+%Y-%m-%d %H:%M')"
git push -q origin main
echo "push 완료"
