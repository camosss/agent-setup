-- herdr Claude 세션 알림 (2026-11-09)
-- ~/.claude/hooks/herdr-banner-notify.sh 가
--   open -g "hammerspoon://herdr-notify?pane=...&title=...&subtitle=...&message=..."
-- 를 호출하면 화면 오른쪽 위에 배너를 그린다. 클릭하면 Ghostty를 앞으로 가져와 해당 herdr 창으로 이동한다.
-- macOS 26에서는 hs.notify(옛 NSUserNotification)가 전달되지 않아 hs.canvas로 직접 그린다.

require("hs.ipc")  -- 터미널에서 `hs` 명령으로 점검할 수 있게
hs.autoLaunch(true)  -- 로그인 시 자동 실행 (2026-11-09 사용자 요청)

local HERDR = os.getenv("HOME") .. "/.local/bin/herdr"
local WIDTH, HEIGHT, GAP, MARGIN = 380, 92, 10, 14
local SHOW_SECONDS = 5

local banners = {}  -- 위에서부터 쌓이는 배너 목록

local function focusPane(pane)
  hs.application.launchOrFocus("Ghostty")
  if pane and pane ~= "" then
    hs.task.new(HERDR, nil, { "agent", "focus", pane }):start()
    hs.task.new("/bin/sh", nil, { os.getenv("HOME") .. "/.claude/hooks/herdr-tab-dot.sh", "clear", pane }):start()
  end
end

local function relayout()
  -- 마우스 커서가 있는 모니터에 띄운다 (모니터 여러 대일 때 보고 있는 화면, 2026-11-12 사용자 요청)
  local scr = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local f = scr:frame()
  for i, b in ipairs(banners) do
    b.canvas:topLeft({ x = f.x + f.w - WIDTH - MARGIN, y = f.y + MARGIN + (i - 1) * (HEIGHT + GAP) })
  end
end

local function dismiss(banner)
  for i, b in ipairs(banners) do
    if b == banner then
      table.remove(banners, i)
      break
    end
  end
  if banner.timer then banner.timer:stop() end
  banner.canvas:delete(0.2)
  relayout()
end

local function show(pane, title, subtitle, message)
  -- 같은 창에서 온 이전 배너는 교체
  for _, b in ipairs(banners) do
    if pane ~= "" and b.pane == pane then dismiss(b) break end
  end

  local c = hs.canvas.new({ x = 0, y = 0, w = WIDTH, h = HEIGHT })
  c:level(hs.canvas.windowLevels.overlay)
  c:behavior({ "canJoinAllSpaces", "stationary" })
  c:appendElements(
    { type = "rectangle", action = "fill", roundedRectRadii = { xRadius = 14, yRadius = 14 },
      fillColor = { hex = "#7DD3FC", alpha = 0.97 },  -- 하늘색 (사용자 요청)
      trackMouseUp = true, id = "bg" },
    { type = "text", text = title, frame = { x = 16, y = 10, w = WIDTH - 32, h = 22 },
      textSize = 15, textColor = { hex = "#0B2540" }, textFont = ".AppleSystemUIFontBold" },
    { type = "text", text = subtitle, frame = { x = 16, y = 31, w = WIDTH - 32, h = 18 },
      textSize = 12, textColor = { hex = "#1E4A6B" } },
    { type = "text", text = message, frame = { x = 16, y = 49, w = WIDTH - 32, h = 36 },
      textSize = 12.5, textColor = { hex = "#0B2540" }, textLineBreak = "truncateTail" }
  )

  local banner = { canvas = c, pane = pane }
  c:mouseCallback(function(_, event)
    if event == "mouseUp" then
      focusPane(pane)
      dismiss(banner)
    end
  end)
  banner.timer = hs.timer.doAfter(SHOW_SECONDS, function() dismiss(banner) end)

  table.insert(banners, 1, banner)
  relayout()
  c:show(0.15)
  -- 소리 없이 배너만 띄운다 (2026-11-11 사용자 요청)
end

hs.urlevent.bind("herdr-notify", function(_, params)
  show(params.pane or "", params.title or "Claude", params.subtitle or "", params.message or "")
end)

-- Ghostty에서 Cmd+V로 이미지 붙여넣기 (2026-11-09 사용자 요청)
-- 클립보드에 이미지만 있으면 Ctrl+V를 보내 Claude Code가 이미지를 첨부하게 한다.
-- 텍스트가 있으면(파일 복사 포함) 원래 Cmd+V 그대로 붙여넣는다. 키 합성에는 손쉬운 사용 권한이 필요하다.
cmdV = hs.hotkey.new({ "cmd" }, "v", function()
  -- 브라우저·슬랙에서 복사한 이미지는 텍스트(주소 등)도 함께 들어 있어 이미지가 있으면 이미지를 우선한다.
  -- Finder에서 복사한 파일(file URL)은 기존처럼 경로 텍스트로 붙인다.
  local hasImage = hs.pasteboard.readImage() ~= nil
  local isFile = false
  for _, t in ipairs(hs.pasteboard.contentTypes() or {}) do
    if t == "public.file-url" then isFile = true end
  end
  if hasImage and not isFile then
    -- Cmd를 누른 채라 키 합성(Ctrl+V)은 Cmd+Ctrl+V로 섞여 전달되지 않았다.
    -- 대신 herdr에 지금 보고 있는 창으로 Ctrl+V를 직접 보내게 한다.
    hs.task.new(HERDR, function(code, out)
      if code ~= 0 then return end
      local ok, data = pcall(hs.json.decode, out)
      local p = ok and data and data.result and data.result.pane
      if p and p.pane_id then
        hs.task.new(HERDR, nil, { "pane", "send-keys", p.pane_id, "ctrl+v" }):start()
      end
    end, { "pane", "current" }):start()
  else
    cmdV:disable()
    hs.eventtap.keyStroke({ "cmd" }, "v", 0)
    cmdV:enable()
  end
end)

local function syncCmdV(appName)
  -- 손쉬운 사용 권한이 없으면 키를 다시 보낼 수 없어 텍스트 붙여넣기가 막히므로 가로채지 않는다
  if appName == "Ghostty" and hs.accessibilityState() then cmdV:enable() else cmdV:disable() end
end
ghosttyWatcher = hs.application.watcher.new(function(name, event)
  if event == hs.application.watcher.activated then syncCmdV(name) end
end)
ghosttyWatcher:start()
local front = hs.application.frontmostApplication()
syncCmdV(front and front:name() or "")

-- 지금 보고 있는 herdr 탭의 ❗️ 표시 지우기 (2026-11-09 사용자 요청)
-- ❗️는 보고 있지 않은 탭에만 남아야 한다. herdr에는 탭 전환 이벤트가 없어서
-- Ghostty가 앞에 있을 때 1.5초마다 활성 탭을 확인한다.
local DOT_PREFIXES = { "❗️ ", "• ", "🔵 ", "● " }
local dotTaskRunning = false
local function clearActiveTabDot()
  if dotTaskRunning then return end
  local front = hs.application.frontmostApplication()
  if not front or front:name() ~= "Ghostty" then return end
  dotTaskRunning = true
  hs.task.new(HERDR, function(code, out)
    dotTaskRunning = false
    if code ~= 0 then return end
    local ok, data = pcall(hs.json.decode, out)
    if not ok or not data or not data.result then return end
    for _, t in ipairs(data.result.tabs or {}) do
      if t.focused and t.label then
        for _, p in ipairs(DOT_PREFIXES) do
          if t.label:sub(1, #p) == p then
            hs.task.new(HERDR, nil, { "tab", "rename", t.tab_id, t.label:sub(#p + 1) }):start()
            break
          end
        end
      end
    end
  end, { "tab", "list" }):start()
end
dotTimer = hs.timer.doEvery(1.5, clearActiveTabDot)
