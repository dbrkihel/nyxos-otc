unjustifiedPointsWindow = nil
unjustifiedPointsButton = nil
contentsPanel = nil

local bigSkull, fragsLabel, statusLabel, fragBar, fragBarBg
local detailLabel, nextFragLabel, skullTimeLabel

-- Full snapshot pushed by the server over extended opcode 201 (OTC only):
--   recent | killsToRed | killsToBlack | nextFragSeconds | skullSeconds
-- This is the precise source of truth: exact frag counts plus the time-to-expiry
-- data the 0xB7 packet cannot carry. nil until the first push arrives; until then
-- the panel falls back to figures recovered from the 0xB7 progress percentages so
-- it is still correct (minus the timers) even before the server pushes anything.
local snapshot = nil
-- Must match UNJUSTIFIED_OTC_OPCODE in the server's unjustified_otc.lua revscript.
local UNJUSTIFIED_TIME_OPCODE = 201

-- Live "next frag" countdown: the snapshot carries nextFragSeconds; we anchor it
-- to a monotonic clock reading so a local 1s ticker can decay the displayed value
-- (every minute, HH:mm) without waiting on the next server push, and the periodic
-- push simply re-anchors it (self-correcting, no drift).
local nextFragAnchorMs = nil
local countdownEvent = nil
local pendingRefreshEvent = nil -- one-shot login safety re-pull; tracked so it can be cancelled
local currentRecent = 0        -- cached from the last updateDashboard for the ticker
local lastFragLabelText = nil  -- guards redundant setText on the per-second tick

local function formatDuration(seconds)
  seconds = tonumber(seconds)
  if not seconds or seconds <= 0 then return nil end
  local d = math.floor(seconds / 86400)
  local h = math.floor((seconds % 86400) / 3600)
  local m = math.floor((seconds % 3600) / 60)
  if d > 0 then return string.format('%dd %dh', d, h) end
  if h > 0 then return string.format('%dh %02dm', h, m) end
  return string.format('%dm', math.max(1, m))
end

-- Countdown clock as HH:mm. Minutes are rounded UP so the label never shows
-- "00:00" while time still remains (it hits nil exactly at expiry instead). The
-- frag window is small (8h here), so HH stays 00..08; if the window is ever
-- configured past 24h, fall back to a day-aware format instead of "30:00".
local function formatClock(seconds)
  seconds = tonumber(seconds)
  if not seconds or seconds <= 0 then return nil end
  if seconds >= 86400 then return formatDuration(seconds) end
  local totalMinutes = math.ceil(seconds / 60)
  local h = math.floor(totalMinutes / 60)
  local m = totalMinutes % 60
  return string.format('%02d:%02d', h, m)
end

-- Remaining seconds until the oldest frag ages out, decayed live from the anchor.
local function liveNextFragSeconds()
  if not snapshot or not snapshot.nextFragSeconds or not nextFragAnchorMs then
    return nil
  end
  local elapsed = math.floor((g_clock.millis() - nextFragAnchorMs) / 1000)
  local remaining = snapshot.nextFragSeconds - elapsed
  if remaining <= 0 then return nil end
  return remaining
end

-- The 0xB7 packet encodes progress PERCENTAGES (0..100), not counts:
--   killsDay  = round(recent / killsToRed   * 100)   killsDayRemaining  = killsToRed   - recent
--   killsWeek = round(recent / killsToBlack * 100)   killsWeekRemaining = killsToBlack - recent
-- Invert progress% + remaining to recover the real (recent, threshold) pair.
local function recoverCount(progress, remaining)
  progress = tonumber(progress) or 0
  remaining = math.max(0, tonumber(remaining) or 0)
  if progress <= 0 then return 0, remaining end          -- no frags: recent 0, threshold = remaining
  if progress >= 100 then return remaining, remaining end -- saturated: handled by the next skull tier
  local threshold = math.floor(remaining * 100 / (100 - progress) + 0.5)
  if threshold < remaining then threshold = remaining end
  return threshold - remaining, threshold
end

-- Resolve (recent, threshold, remaining, skullSeconds) for the current skull tier,
-- preferring the precise server snapshot and falling back to the figures recovered
-- from the 0xB7 packet. The next-frag time is handled separately (live ticker).
local function getFragState(skull)
  local hasSkull = (skull == SkullRed or skull == SkullBlack)
  local recent, threshold, skullSecs

  if snapshot then
    recent = snapshot.recent
    threshold = hasSkull and snapshot.killsToBlack or snapshot.killsToRed
    skullSecs = snapshot.skullSeconds
  else
    local up = g_game.getUnjustifiedPoints()
    if hasSkull then
      recent, threshold = recoverCount(up.killsWeek, up.killsWeekRemaining)
    else
      recent, threshold = recoverCount(up.killsDay, up.killsDayRemaining)
    end
    -- 0xB7 only carries skull expiry in whole days; the precise seconds come
    -- from the extended opcode (snapshot) once it arrives.
    skullSecs = (up.skullTime or 0) > 0 and (up.skullTime * 86400) or nil
  end

  recent = recent or 0
  threshold = math.max(threshold or 0, recent, 1)
  local remaining = math.max(0, threshold - recent)
  return recent, threshold, remaining, skullSecs
end

function init()
  connect(g_game, { onGameStart = online,
                    onGameEnd = offline,
                    onUnjustifiedPointsChange = updateDashboard })
  connect(LocalPlayer, { onSkullChange = onSkullChange })

  ProtocolGame.registerExtendedOpcode(UNJUSTIFIED_TIME_OPCODE, onExtendedSnapshot)

  unjustifiedPointsButton = modules.client_topmenu.addRightGameToggleButton('unjustifiedPointsButton',
    tr('Unjustified Points'), '/images/icons/icon-unjustified-points-widget', toggle)
  unjustifiedPointsWindow = g_ui.loadUI('unjustifiedpoints', m_interface.getRightPanel())
  unjustifiedPointsWindow:disableResize()
  unjustifiedPointsWindow:setup()
  unjustifiedPointsWindow:hide()
  unjustifiedPointsWindow:setOn(false)

  contentsPanel = unjustifiedPointsWindow:getChildById('contentsPanel')
  bigSkull = contentsPanel:getChildById('bigSkull')
  fragsLabel = contentsPanel:getChildById('fragsLabel')
  statusLabel = contentsPanel:getChildById('statusLabel')
  fragBar = contentsPanel:getChildById('fragBar')
  fragBarBg = contentsPanel:getChildById('fragBarBg')
  detailLabel = contentsPanel:getChildById('detailLabel')
  nextFragLabel = contentsPanel:getChildById('nextFragLabel')
  skullTimeLabel = contentsPanel:getChildById('skullTimeLabel')

  if g_game.isOnline() then
    online()
  end
end

function terminate()
  stopCountdown()
  disconnect(g_game, { onGameStart = online,
                       onGameEnd = offline,
                       onUnjustifiedPointsChange = updateDashboard })
  disconnect(LocalPlayer, { onSkullChange = onSkullChange })

  ProtocolGame.unregisterExtendedOpcode(UNJUSTIFIED_TIME_OPCODE)

  unjustifiedPointsWindow:destroy()
  unjustifiedPointsButton:destroy()

  -- Null the references so updateDashboard()/refreshNextFragLabel()'s liveness
  -- guards actually protect against any stray post-terminate event (a queued 0xB7
  -- or extended-opcode packet) touching destroyed widgets.
  unjustifiedPointsWindow = nil
  unjustifiedPointsButton = nil
  contentsPanel = nil
  bigSkull, fragsLabel, statusLabel, fragBar, fragBarBg = nil, nil, nil, nil, nil
  detailLabel, nextFragLabel, skullTimeLabel = nil, nil, nil
end

function onMiniWindowClose()
  unjustifiedPointsButton:setOn(false)
  modules.game_sidebuttons.setButtonVisible("unjustifiedPoinsWidget", false)
end

function toggle()
  if unjustifiedPointsButton:isOn() then
    unjustifiedPointsWindow:close()
    unjustifiedPointsButton:setOn(false)
  else
    unjustifiedPointsWindow:open()
    if m_interface.addToPanels(unjustifiedPointsWindow) then
      unjustifiedPointsButton:setOn(true)
      unjustifiedPointsWindow:getParent():moveChildToIndex(unjustifiedPointsWindow, #unjustifiedPointsWindow:getParent():getChildren())
    end
  end
end

-- 1s ticker that visibly decays the next-frag clock (the HH:mm changes once per
-- minute). Anchored to g_clock, so it stays accurate between server pushes.
function startCountdown()
  if countdownEvent then return end
  countdownEvent = cycleEvent(function()
    if not g_game.isOnline() then return end
    refreshNextFragLabel()
  end, 1000)
end

function stopCountdown()
  if countdownEvent then
    removeEvent(countdownEvent)
    countdownEvent = nil
  end
  if pendingRefreshEvent then
    removeEvent(pendingRefreshEvent)
    pendingRefreshEvent = nil
  end
end

function online()
  startCountdown()
  updateDashboard()
  -- The server pushes the snapshot opcode ~1s after login; re-pull once more as a
  -- safety so the panel is filled even if that push is briefly missed. Tracked so
  -- a fast relog/terminate within 1.5s cannot fire it against a torn-down session.
  if pendingRefreshEvent then removeEvent(pendingRefreshEvent) end
  pendingRefreshEvent = scheduleEvent(function()
    pendingRefreshEvent = nil
    updateDashboard()
  end, 1500)
end

function offline()
  stopCountdown()
  snapshot = nil
  nextFragAnchorMs = nil
  lastFragLabelText = nil
  currentRecent = 0
end

function refresh()
  updateDashboard()
end

-- Extended opcode payload: "recent|killsToRed|killsToBlack|nextFragSeconds|skullSeconds".
-- Sent by the server only to OTClient (gated by player:isUsingOtClient()).
function onExtendedSnapshot(protocol, opcode, buffer)
  local recent, ktr, ktb, nextFrag, skullSecs =
    tostring(buffer or ''):match('^(%-?%d+)|(%-?%d+)|(%-?%d+)|(%-?%d+)|(%-?%d+)$')
  if not recent then return end
  snapshot = {
    recent = tonumber(recent),
    killsToRed = tonumber(ktr),
    killsToBlack = tonumber(ktb),
    nextFragSeconds = tonumber(nextFrag),
    skullSeconds = tonumber(skullSecs),
  }
  if snapshot.skullSeconds and snapshot.skullSeconds <= 0 then snapshot.skullSeconds = nil end
  if snapshot.nextFragSeconds and snapshot.nextFragSeconds <= 0 then snapshot.nextFragSeconds = nil end
  -- Re-anchor the live countdown to "now" for the freshly received value.
  nextFragAnchorMs = g_clock.millis()
  updateDashboard()
end

function onSkullChange(localPlayer, skull)
  if not localPlayer or not localPlayer:isLocalPlayer() then return end
  updateDashboard()
end

-- Updates only the live "next frag" countdown label (called every second by the
-- ticker, and by updateDashboard). Guarded so setText runs only when HH:mm changes.
function refreshNextFragLabel()
  if not nextFragLabel then return end
  local text, visible
  local clock = formatClock(liveNextFragSeconds())
  if clock then
    text = 'Next frag drop: ' .. clock
    visible = true
  elseif currentRecent > 0 then
    text = 'Next frag drop: --'
    visible = true
  else
    text = nil
    visible = false
  end
  if text and text ~= lastFragLabelText then
    nextFragLabel:setText(text)
  end
  lastFragLabelText = text
  nextFragLabel:setVisible(visible)
end

function updateDashboard()
  if not unjustifiedPointsWindow then return end
  local localPlayer = g_game.getLocalPlayer()
  if not localPlayer then return end

  local skull = localPlayer:getSkull()
  local hasRed = (skull == SkullRed)
  local hasBlack = (skull == SkullBlack)

  local recent, threshold, remaining, skullSeconds = getFragState(skull)
  currentRecent = recent

  fragsLabel:setText(string.format('%d / %d', recent, threshold))
  fragBar:setValue(recent, 0, threshold)

  if hasBlack then
    bigSkull:setImageSource(getSkullImagePath(SkullBlack))
    statusLabel:setText(tr('BLACK SKULL'))
    statusLabel:setColor('#9a9a9a')
    detailLabel:setText(tr('You can be banished at any time.'))
  elseif hasRed then
    bigSkull:setImageSource(getSkullImagePath(SkullRed))
    statusLabel:setText(tr('RED SKULL'))
    statusLabel:setColor('#df6464')
    detailLabel:setText(string.format('%d kill%s until Black Skull (ban)',
      remaining, remaining == 1 and '' or 's'))
  else
    -- No skull yet: preview the Red Skull as the threat you are approaching, and
    -- escalate the status by how close you are (% of frags toward the red skull):
    --   < 50%  Safe (green) | 50-75% Warning (orange) | >= 75% Caution (red).
    bigSkull:setImageSource(getSkullImagePath(SkullRed))
    local pct = threshold > 0 and (recent / threshold) * 100 or 0
    if pct >= 75 then
      statusLabel:setText(tr('Caution'))
      statusLabel:setColor('#e0504f')
    elseif pct >= 50 then
      statusLabel:setText(tr('Warning'))
      statusLabel:setColor('#e8a13a')
    else
      statusLabel:setText(tr('Safe'))
      statusLabel:setColor('#61c861')
    end
    detailLabel:setText(string.format('%d more for Red Skull', remaining))
  end

  -- Live next-frag countdown (HH:mm, decays every minute via the ticker).
  refreshNextFragLabel()

  -- Skull expiry (red/black only): precise seconds from the snapshot, else the
  -- whole-day value recovered from the 0xB7 packet.
  if hasRed or hasBlack then
    local skullT = formatDuration(skullSeconds)
    local fmt = hasBlack and 'Black skull ends in: %s' or 'Red skull ends in: %s'
    skullTimeLabel:setText(string.format(fmt, skullT or '--'))
    skullTimeLabel:setVisible(true)
  else
    skullTimeLabel:setVisible(false)
  end
end

function move(panel, height, index, minimized)
  unjustifiedPointsWindow:setParent(panel)
  unjustifiedPointsWindow:open()

  if minimized then
    unjustifiedPointsWindow:setHeight(126)
    unjustifiedPointsWindow:minimize()
  else
    unjustifiedPointsWindow:maximize()
    unjustifiedPointsWindow:setHeight(126)
  end

  return unjustifiedPointsWindow
end
