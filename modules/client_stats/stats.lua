
local statsWindow = nil
local statsButton = nil
local luaStats = nil
local luaCallback = nil
local mainStats = nil
local dispatcherStats = nil
local render = nil
local atlas = nil
local adaptiveRender = nil
local slowMain = nil
local slowRender = nil
local widgetsInfo = nil
local packets
local slowPackets

local updateEvent = nil
local monitorEvent = nil
local iter = 0
local lastSend = 0
local sendInterval = 60 -- 1 m
local fps = {}
local ping = {}
local lastSleepTimeReset = 0

-- Local profiler persistence: every `sendInterval` the full g_stats report (all buckets +
-- slow lists + frame context) is appended to a per-session log under <writeDir>/profiler/.
-- This is the data used to decide what to migrate to C++ / optimize. writeFileContents
-- truncates on write, so we accumulate the session report in memory and rewrite the file
-- whole on each dump (a few KB per dump — negligible).
local PROFILER_DIR = '/profiler'
local sessionFile = nil
local sessionReport = {}
local dumpCount = 0

function init()
  if not DEVELOPERMODE then
    return
  end

  statsButton = modules.client_topmenu.addLeftButton('statsButton', 'Debug Info', '/images/topbuttons/debug', toggle)
  statsButton:setOn(false)

  statsWindow = g_ui.displayUI('stats')
  statsWindow:hide()

  g_keyboard.bindKeyDown('Ctrl+Alt+D', toggle)

  luaStats = statsWindow:recursiveGetChildById('luaStats')
  luaCallback = statsWindow:recursiveGetChildById('luaCallback')
  mainStats = statsWindow:recursiveGetChildById('mainStats')
  dispatcherStats = statsWindow:recursiveGetChildById('dispatcherStats')
  render = statsWindow:recursiveGetChildById('render')
  atlas = statsWindow:recursiveGetChildById('atlas')
  packets = statsWindow:recursiveGetChildById('packets')
  adaptiveRender = statsWindow:recursiveGetChildById('adaptiveRender')
  slowMain = statsWindow:recursiveGetChildById('slowMain')
  slowRender = statsWindow:recursiveGetChildById('slowRender')
  slowPackets = statsWindow:recursiveGetChildById('slowPackets')
  widgetsInfo = statsWindow:recursiveGetChildById('widgetsInfo')

  lastSend = os.time()
  g_stats.resetSleepTime()
  lastSleepTimeReset = g_clock.micros()

  -- One profiler log per client session, named by start time. Lives in the PhysFS
  -- write dir (Windows: %APPDATA%/NyxosClient/nyxos-client/profiler/).
  g_resources.makeDir(PROFILER_DIR)
  sessionFile = PROFILER_DIR .. '/session_' .. os.date('%Y%m%d_%H%M%S') .. '.log'
  sessionReport = {}
  dumpCount = 0
  g_logger.info('client_stats: profiler dumps -> ' .. g_resources.getWriteDir() .. sessionFile:sub(2))

  updateEvent = scheduleEvent(update, 2000)
  monitorEvent = scheduleEvent(monitor, 1000)
end

function terminate()
  if not DEVELOPERMODE then
    return
  end

  -- Final dump so short sessions still leave profiler data on disk.
  if sessionFile then
    local ok, err = pcall(saveStats)
    if not ok then
      g_logger.error('client_stats: final saveStats failed: ' .. tostring(err))
    end
  end

  statsWindow:destroy()
  statsButton:destroy()

  g_keyboard.unbindKeyDown('Ctrl+Alt+D')

  removeEvent(updateEvent)
  removeEvent(monitorEvent)
end

function onClose()
  statsWindow:hide()
  statsButton:setOn(false)
end

function toggle()
  if statsButton:isOn() then
    statsWindow:hide()
    statsButton:setOn(false)
  else
    statsWindow:show()
    statsWindow:raise()
    statsWindow:focus()
    statsButton:setOn(true)
  end
end

function monitor()
  if #fps > 1000 then
    fps = {}
  end
  if #ping > 1000 then
    ping = {}
  end
  table.insert(fps, g_app.getFps())
  table.insert(ping, g_game.getPing())
  monitorEvent = scheduleEvent(monitor, 1000)
end

-- Builds one human-readable profiler snapshot covering the current measurement window
-- (everything since the last clear): frame context + all g_stats buckets + slow calls.
-- Must be called BEFORE the buckets are cleared.
local function buildProfilerDump()
  local lines = {}
  local function add(s) table.insert(lines, s) end

  local fpsMin, fpsMax, fpsSum, fpsN = math.huge, 0, 0, #fps
  for i = 1, fpsN do
    local v = fps[i]
    if v < fpsMin then fpsMin = v end
    if v > fpsMax then fpsMax = v end
    fpsSum = fpsSum + v
  end
  local pingSum, pingN = 0, 0
  for i = 1, #ping do
    local v = ping[i]
    if v and v >= 0 then
      pingSum = pingSum + v
      pingN = pingN + 1
    end
  end

  local where = 'offline'
  local localPlayer = g_game.getLocalPlayer()
  if localPlayer then
    -- During login the local player exists before the first map packet sets its
    -- position, so getPosition() can still be nil here.
    local pos = localPlayer:getPosition()
    if pos then
      where = string.format('%s @ %d,%d,%d (%s)', localPlayer:getName(), pos.x, pos.y, pos.z,
        g_game.getWorldName() or '?')
    else
      where = string.format('%s (logging in)', localPlayer:getName() or '?')
    end
  end

  local sleepPct = math.round(100 * g_stats.getSleepTime() / math.max(1, g_clock.micros() - lastSleepTimeReset), 1)

  add('================================================================================')
  add(string.format('PROFILER DUMP #%d | %s | window %ds', dumpCount + 1, os.date('%Y-%m-%d %H:%M:%S'), sendInterval))
  add('player: ' .. where)
  add(string.format('uptime: %ds | GFPS: %d | PFPS: %d | fps avg/min/max: %d/%d/%d (%d samples) | ping avg: %dms',
    g_clock.seconds(), g_app.getGraphicsFps(), g_app.getProcessingFps(),
    fpsN > 0 and math.floor(fpsSum / fpsN) or 0, fpsN > 0 and fpsMin or 0, fpsMax, fpsN,
    pingN > 0 and math.floor(pingSum / pingN) or 0))
  add(string.format('sleep: %s%% | lua ram: %d KB | mem: %s | packets: %d (%d KB)',
    tostring(sleepPct), gcinfo(), tostring(g_platform.getMemoryUsage()),
    g_game.getRecivedPacketsCount(), math.floor(g_game.getRecivedPacketsSize() / 1024)))
  add('adaptive: ' .. g_adaptiveRenderer.getLevel() .. ' | ' .. g_adaptiveRenderer.getDebugInfo())
  add('atlas: ' .. g_atlas.getStats())

  local buckets = {
    { STATS_MAIN, 'MAIN' },
    { STATS_RENDER, 'RENDER' },
    { STATS_DISPATCHER, 'DISPATCHER' },
    { STATS_LUA, 'LUA' },
    { STATS_LUACALLBACK, 'LUACALLBACK' },
    { STATS_PACKETS, 'PACKETS' },
  }
  for _, bucket in ipairs(buckets) do
    add('')
    add('---- ' .. bucket[2] .. ' (top 30 by total time this window) ----')
    add(g_stats.get(bucket[1], 30, true))
  end

  add('')
  add('---- SLOW calls > 5ms (most recent first) ----')
  for _, bucket in ipairs({ { STATS_MAIN, 'MAIN' }, { STATS_RENDER, 'RENDER' },
      { STATS_DISPATCHER, 'DISPATCHER' }, { STATS_LUA, 'LUA' }, { STATS_PACKETS, 'PACKETS' } }) do
    add('[' .. bucket[2] .. ']')
    add(g_stats.getSlow(bucket[1], 25, 5, true))
  end
  add('')
  return table.concat(lines, '\n')
end

-- Periodic entry point (every sendInterval): persists the profiler window to disk,
-- optionally forwards to the legacy HTTP stats service, then clears the buckets to
-- start a fresh window. Also callable manually from the terminal: saveStats()
function saveStats()
  lastSend = os.time()

  -- 1) Local dump first (reads the buckets).
  dumpCount = dumpCount + 1
  table.insert(sessionReport, buildProfilerDump())
  if sessionFile then
    g_resources.writeFileContents(sessionFile, table.concat(sessionReport, '\n'))
  end

  -- 2) Legacy HTTP report, only when a stats service is configured (also reads buckets).
  if Services and Services.stats ~= nil and Services.stats:len() > 3 then
    local ok, err = pcall(sendStats)
    if not ok then
      g_logger.error('client_stats: sendStats failed: ' .. tostring(err))
    end
  end

  -- 3) Single owner of the window reset: clear all buckets/slow lists and counters.
  for i = 1, g_stats.types() do
    g_stats.clear(i - 1)
    g_stats.clearSlow(i - 1)
  end
  lastSleepTimeReset = g_clock.micros()
  g_stats.resetSleepTime()
  fps = {}
  ping = {}
end

function getProfilerLogPath()
  return g_resources.getWriteDir() .. (sessionFile or PROFILER_DIR)
end

function sendStats()
  local localPlayer = g_game.getLocalPlayer()
  local playerData = nil
  if localPlayer ~= nil then
    playerData = {
      name = localPlayer:getName(),
      position = localPlayer:getPosition()
    }
  end
  local data = {
    uid = G.UUID,
    stats = {},
    slow = {},
    render = g_adaptiveRenderer.getDebugInfo(),
    player = playerData,
    fps = fps,
    ping = ping,
    sleepTime = math.round(g_stats.getSleepTime() / math.max(1, g_clock.micros() - lastSleepTimeReset), 2),
    proxy = {},

    details = {
      report_delay = sendInterval,
      os = g_app.getOs(),
      graphics_vendor = g_graphics.getVendor(),
      graphics_renderer = g_graphics.getRenderer(),
      graphics_version = g_graphics.getVersion(),
      fps = g_app.getFps(),
      maxFps = g_app.getMaxFps(),
      atlas = g_atlas.getStats(),
      classic = tostring(g_settings.getBoolean("classicView")),
      fullscreen = tostring(g_window.isFullscreen()),
      vsync = tostring(g_settings.getBoolean("vsync")),
      autoReconnect = tostring(g_settings.getBoolean("autoReconnect")),
      window_width = g_window.getWidth(),
      window_height = g_window.getHeight(),
      player_name = g_game.getCharacterName(),
      world_name = g_game.getWorldName(),
      otserv_host = G.host,
      otserv_protocol = g_game.getProtocolVersion(),
      otserv_client = g_game.getClientVersion(),
      build_version = g_app.getVersion(),
      build_revision = g_app.getBuildRevision(),
      build_commit = g_app.getBuildCommit(),
      build_date = g_app.getBuildDate(),
      display_width = g_window.getDisplayWidth(),
      display_height = g_window.getDisplayHeight(),
      cpu = g_platform.getCPUName(),
      mem = g_platform.getTotalSystemMemory(),
      mem_usage = g_platform.getMemoryUsage(),
      lua_mem_usage = gcinfo(),
      os_name = g_platform.getOSName(),
      platform = g_window.getPlatformType(),
      uptime = g_clock.seconds(),
      layout = g_resources.getLayout(),
      packets = g_game.getRecivedPacketsCount(),
      packets_size = g_game.getRecivedPacketsSize()
    }
  }
  if g_proxy then
    data["proxy"] = g_proxy.getProxiesDebugInfo()
  end
  -- NOTE: bucket clearing / sleep-time & fps/ping resets are owned by saveStats(),
  -- which calls this function; clearing here too would wipe the freshly-dumped window.
  for i = 1, g_stats.types() do
    table.insert(data.stats, g_stats.get(i - 1, 10, false))
    table.insert(data.slow, g_stats.getSlow(i - 1, 50, 10, false))
  end
  data.widgets = g_stats.getWidgetsInfo(10, false)
  data = json.encode(data, 1)
  -- g_http.post signature is (url, data, timeout, headers map); missing args
  -- nil-fill in the binder and nil fails the map cast
  g_http.post(Services.stats, data, HTTP.timeout, {})
end

function update()
  -- 100ms tick (full 9-step panel refresh every ~900ms). The previous 20ms tick made
  -- the debug window itself a measurable consumer while profiling.
  updateEvent = scheduleEvent(update, 100)
  if lastSend + sendInterval < os.time() then
    saveStats()
  end

  if not statsWindow:isVisible() then
    return
  end

  iter = (iter + 1) % 9 -- some functions are slow (~5ms), it will avoid lags
  if iter == 0 then
    statsWindow.debugPanel.sleepTime:setText("GFPS: " .. g_app.getGraphicsFps() .. " PFPS: " .. g_app.getProcessingFps() .. " Packets: " .. g_game.getRecivedPacketsCount() .. " , " .. (g_game.getRecivedPacketsSize() / 1024) .. " KB")
    statsWindow.debugPanel.luaRamUsage:setText("Ram usage by lua: " .. gcinfo() .. " kb")
  elseif iter == 1 then
    local adaptive = "Adaptive: " .. g_adaptiveRenderer.getLevel() .. " | " .. g_adaptiveRenderer.getDebugInfo()
    adaptiveRender:setText(adaptive)
    atlas:setText("Atlas: " .. g_atlas.getStats())
  elseif iter == 2 then
    render:setText(g_stats.get(STATS_RENDER, 10, true))
    mainStats:setText(g_stats.get(STATS_MAIN, 5, true))
    dispatcherStats:setText(g_stats.get(STATS_DISPATCHER, 30, true))
  elseif iter == 3 then
    luaStats:setText(g_stats.get(STATS_LUA, 30, true))
    luaCallback:setText(g_stats.get(STATS_LUACALLBACK, 30, true))
  elseif iter == 4 then
    slowMain:setText(g_stats.getSlow(STATS_DISPATCHER, 10, 10, true) .. "\n\n\n" .. g_stats.getSlow(STATS_MAIN, 20, 20, true))
  elseif iter == 5 then
    slowRender:setText(g_stats.getSlow(STATS_RENDER, 10, 10, true))
  elseif iter == 6 then
    -- getWidgetsInfo walks the whole widget tree and is expensive; keep it off in the
    -- periodic UI refresh (matches the placeholder text in stats.otui). The full report
    -- is still captured raw in the periodic profiler dump via sendStats when enabled.
    -- widgetsInfo:setText(g_stats.getWidgetsInfo(10, true))
  elseif iter == 7 then
    packets:setText(g_stats.get(STATS_PACKETS, 10, true))
    slowPackets:setText(g_stats.getSlow(STATS_PACKETS, 10, 10, true))
  elseif iter == 8 then
    if g_proxy and statsWindow.debugPanel.proxies then
      local proxiesDebug = g_proxy.getProxiesDebugInfo()

      local displayProxy = {}
      for proxy_name, proxy_debug in pairs(proxiesDebug) do
        local result = {}
        local out = proxy_name.." - " .. proxy_debug

        result.address, result.port,
        result.p, result.rp,
        result.in_count, result.in_bytes,
        result.out_count, result.out_bytes,
        result.conns, result.sess,
        result.r = out:match(
            "([%d%.]+):(%d+)%s%-%sP:%s*(%d+)%s+RP:%s*(%d+)%s+In:%s*(%d+)%s+%((%d+)%)%s+Out:%s*(%d+)%s+%((%d+)%)%s+Conns:%s*(%d+)%s+Sess:%s*(%d+)%s+R:%s*([%d%.]+)"
        )

        if result.sess == nil then
          -- Debug-info line didn't match the expected format; show it raw instead of
          -- erroring on tonumber(nil) comparisons below.
          displayProxy[#displayProxy+1] = out
        elseif tonumber(result.sess) >= 1 then
          displayProxy[#displayProxy+1] =  string.format("[color=\"$var-text-cip-color-green\"]%s - P: %s RP: %s In: %s (%s) Out: %s (%s) Conns: %s Sess: %s R: %s[/color]",
            proxy_name, result.p, result.rp, result.in_count, result.in_bytes,
            result.out_count, result.out_bytes, result.conns, result.sess, result.r
          )
        elseif tonumber(result.in_count) == 0 or tonumber(result.p) == 0 then
          displayProxy[#displayProxy+1] =  string.format("[color=\"$var-text-cip-color-light-red\"]%s - P: %s RP: %s In: %s (%s) Out: %s (%s) Conns: %s Sess: %s R: %s[/color]",
            proxy_name, result.p, result.rp, result.in_count, result.in_bytes,
            result.out_count, result.out_bytes, result.conns, result.sess, result.r
          )
        else
          displayProxy[#displayProxy+1] =  string.format("%s - P: %s RP: %s In: %s (%s) Out: %s (%s) Conns: %s Sess: %s R: %s",
            proxy_name, result.p, result.rp, result.in_count, result.in_bytes,
            result.out_count, result.out_bytes, result.conns, result.sess, result.r
          )
        end
      end
      table.sort(displayProxy, function(a, b)
        local aP = tonumber(a:match("Sess: (%d+)")) or math.huge
        local bP = tonumber(b:match("Sess: (%d+)")) or math.huge
        return aP > bP
      end)

      statsWindow.debugPanel.proxies:setColorText(table.concat(displayProxy, "\n"))
    end
  end
end
