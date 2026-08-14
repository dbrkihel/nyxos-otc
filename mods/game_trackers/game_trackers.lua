---------------------------
-- Lua code author: R1ck --
-- Company: VICTOR HUGO PERENHA - JOGOS ON LINE --
---------------------------

Trackers = {}
Trackers.__index = Trackers

bossTrackerWindow = nil
bestiaryTrackerWindow = nil
imbuementTrackerWindow = nil

local openWindowEvent = nil

-- Debounce handles for the 0xB9 refresh burst (one per tracker type). The server
-- pushes refreshCyclopediaMonsterTracker on EVERY kill of a tracked monster, so a
-- multi-kill tick yields N packets; coalesce them into one widget rebuild.
local bestiaryRefreshEvent = nil
local bossRefreshEvent = nil

-- g_things.getMonsterList() rebuilds and marshals the full ~2-3k monster map on
-- every call; cache it keyed by client version (assets reload on version switch).
-- Mirrors the proven cyclopedia accessor (mods/game_cyclopedia/cyclopedia.lua).
-- Shared across the sandboxed tracker scripts as a module-global accessor.
local cachedMonsterList, cachedForVersion = nil, nil
function Trackers.getMonsterList()
	local version = g_game.getClientVersion()
	if not cachedMonsterList or cachedForVersion ~= version then
		local list = g_things.getMonsterList()
		-- never pin an empty list (failed staticdata load): retry next call
		if next(list) == nil then
			return list
		end
		cachedMonsterList, cachedForVersion = list, version
	end
	return cachedMonsterList
end


function init()
	connect(g_game, {
		onMonsterTrackerData = Trackers.onMonsterTrackerData,
		onUpdateImbuementTracker = ImbuementTracker.onReceiveData,
		onGameStart = online,
		onGameEnd = offline
	})

	-- init boss tracker
	bossTrackerWindow = g_ui.loadUI('styles/boss_tracker', m_interface.getRightPanel())
	local scrollbar = bossTrackerWindow:getChildById('miniwindowScrollBar')
	scrollbar:mergeStyle({ ['$!on'] = { }})

	local redirectButton = bossTrackerWindow:getRedirectButton()
	redirectButton:setTooltip("Open the entry of a boss in the Bossitary to add it to this list")

	local sortButton = bossTrackerWindow:getExtraButton()
	sortButton:setTooltip("Show sort options")

	bossTrackerWindow:setup()
	bossTrackerWindow:close()

	-- init bestiary tracker
	bestiaryTrackerWindow = g_ui.loadUI('styles/bestiary_tracker', m_interface.getRightPanel())
	local scrollbar = bestiaryTrackerWindow:getChildById('miniwindowScrollBar')
	scrollbar:mergeStyle({ ['$!on'] = { }})

	local redirectButton = bestiaryTrackerWindow:getRedirectButton()
	redirectButton:setTooltip("Open the entry of a boss in the Bestiary to add it to this list")

	local sortButton = bestiaryTrackerWindow:getExtraButton()
	sortButton:setTooltip("Show sort options")

	bestiaryTrackerWindow:setup()
	bestiaryTrackerWindow:close()

	-- init imbuement tracker
	imbuementTrackerWindow = g_ui.loadUI('styles/imbui_tracker', m_interface.getRightPanel())
	local scrollbar = imbuementTrackerWindow:getChildById('miniwindowScrollBar')
	scrollbar:mergeStyle({ ['$!on'] = { }})

	local sortButton = imbuementTrackerWindow:getExtraButton()
	sortButton:setTooltip("Click here to configure the Imbuement Tracker.")

	imbuementTrackerWindow:setup()
	imbuementTrackerWindow:close()
end

function terminate()
	disconnect(g_game, {
		onMonsterTrackerData = Trackers.onMonsterTrackerData,
		onUpdateImbuementTracker = ImbuementTracker.onReceiveData,
		onGameStart = online,
		onGameEnd = offline
	})

end

function online()
	local benchmark = g_clock.millis()
	ImbuementTracker.online()
	consoleln("Trackers loaded in " .. (g_clock.millis() - benchmark) / 1000 .. " seconds.")
end

function offline()
	ImbuementTracker.offline()
	BossTracker.resetWindow()
	-- Reset the tracked lists so a stale list from the previous character/session
	-- is never shown before (or instead of) the server's authoritative login push.
	BestiaryTrackerList = {}
	BossTrackerList = {}
	if openWindowEvent then
		removeEvent(openWindowEvent)
		openWindowEvent = nil
	end
	-- Drop any pending debounced refresh so it can't fire during teardown.
	if bestiaryRefreshEvent then
		removeEvent(bestiaryRefreshEvent)
		bestiaryRefreshEvent = nil
	end
	if bossRefreshEvent then
		removeEvent(bossRefreshEvent)
		bossRefreshEvent = nil
	end
end

-- Per-character g_settings key. The server push (0xB9) stays authoritative; this
-- cache only seeds the UI between login and the push (and survives a missed push
-- or a fast relog). Returns nil when the character name isn't known yet.
function Trackers.storageKey()
	local name = g_game.getCharacterName()
	if not name or name == "" then
		return nil
	end
	return "game_trackers/" .. name:lower()
end

function Trackers.saveTracker()
	local key = Trackers.storageKey()
	if not key then
		return
	end
	g_settings.setNode(key, {
		bestiary = BestiaryTrackerList or {},
		boss = BossTrackerList or {}
	})
end

function Trackers.loadTracker()
	local key = Trackers.storageKey()
	if not key then
		return nil
	end
	return g_settings.getNode(key)
end

function Trackers.onMonsterTrackerData(trackerType, monsterData)
	-- Apply the authoritative list synchronously (cheap) so saveTracker and any
	-- later open() show current data, but debounce the expensive widget rebuild:
	-- a multi-kill tick fires N 0xB9 packets, so collapse them into one refresh.
	if trackerType == 0 then
		BestiaryTrackerList = monsterData
		if bestiaryRefreshEvent then
			removeEvent(bestiaryRefreshEvent)
		end
		bestiaryRefreshEvent = scheduleEvent(function()
			bestiaryRefreshEvent = nil
			BestiaryTracker.showTrackerData()
		end, 50)
	else
		BossTrackerList = monsterData
		if bossRefreshEvent then
			removeEvent(bossRefreshEvent)
		end
		bossRefreshEvent = scheduleEvent(function()
			bossRefreshEvent = nil
			BossTracker.showTrackerData()
		end, 50)
	end
	-- Persist after applying the push so the cache always mirrors the server.
	Trackers.saveTracker()
end

function toggleBossTracker()
	if bossTrackerWindow:isVisible() then
		bossTrackerWindow:close()
	else
		bossTrackerWindow:open()
		if m_interface.addToPanels(bossTrackerWindow) then
			bossTrackerWindow:getParent():moveChildToIndex(bossTrackerWindow, #bossTrackerWindow:getParent():getChildren())
			BossTracker.initSortFields()
		end
		-- Always render on open so a closed-then-opened tracker shows the current
		-- (authoritative) list, even if addToPanels found no free panel slot.
		BossTracker.showTrackerData()
	end
end

function toggleBestiaryTracker()
	if bestiaryTrackerWindow:isVisible() then
		bestiaryTrackerWindow:close()
    	modules.game_sidebuttons.setButtonVisible("bestiaryTrackerWidget", false)
	else
		bestiaryTrackerWindow:open()
		if m_interface.addToPanels(bestiaryTrackerWindow) then
			bestiaryTrackerWindow:getParent():moveChildToIndex(bestiaryTrackerWindow, #bestiaryTrackerWindow:getParent():getChildren())
			BestiaryTracker.initSortFields()
			BestiaryTracker.showTrackerData()
    		modules.game_sidebuttons.setButtonVisible("bestiaryTrackerWidget", true)
		end
	end
end

function toggleImbuementTracker()
	if imbuementTrackerWindow:isVisible() then
		imbuementTrackerWindow:close()
    	modules.game_sidebuttons.setButtonVisible("imbuementTrackerWidget", false)
		g_game.imbuementDurations(false)
	else
		imbuementTrackerWindow:open()
		if m_interface.addToPanels(imbuementTrackerWindow) then
			imbuementTrackerWindow:getParent():moveChildToIndex(imbuementTrackerWindow, #imbuementTrackerWindow:getParent():getChildren())
			ImbuementTracker.initSortFields()
			g_game.imbuementDurations(true)
			openWindowEvent = scheduleEvent(showTracker, 50)
		end
	end
end

function showTracker()
	ImbuementTracker.showTrackerData()
	modules.game_sidebuttons.setButtonVisible("imbuementTrackerWidget", true)
end

function moveTracker(type, panel, height, minimized)
  local windowByType = {
    ["bestiaryTracker"] = bestiaryTrackerWindow,
    ["bosstiaryTracker"] = bossTrackerWindow,
    ["imbuementTracker"] = imbuementTrackerWindow
  }
  local window = windowByType[type]

  window:setParent(panel)
  window:open()

  if minimized then
    window:setHeight(height)
    window:minimize()
  else
    window:maximize()
    window:setHeight(height)
  end

  if type == "imbuementTracker" then
    ImbuementTracker.initSortFields()
    g_game.doThing(false)
    g_game.imbuementDurations(true)
    g_game.doThing(true)
    if not minimized then
      openWindowEvent = scheduleEvent(showTracker, 50)
    end
  end

  return window
end

function onPlayerUnload()
	BestiaryTracker.onLogout()
	BossTracker.onLogout()
end

-- OTML deserialization yields string-keyed entry fields; normalize them back to
-- the numeric 1..6 entry array the tracker UI expects ([1] raceId .. [6] completed).
local function normalizeTrackerList(list)
	local result = {}
	if type(list) ~= "table" then
		return result
	end
	for _, entry in ipairs(list) do
		local normalized = {}
		for i = 1, 6 do
			normalized[i] = tonumber(entry[i])
		end
		if normalized[1] then
			table.insert(result, normalized)
		end
	end
	return result
end

function onPlayerLoad(bestiaryTrackerWidgetOptions, bossTrackerWidgetOptions)
	-- Seed the lists from the per-character cache so the UI shows the last known
	-- trackers immediately on login. The server's 0xB9 push (onMonsterTrackerData)
	-- arrives shortly after and overwrites these with authoritative data.
	local cached = Trackers.loadTracker()
	if cached then
		BestiaryTrackerList = normalizeTrackerList(cached.bestiary)
		BossTrackerList = normalizeTrackerList(cached.boss)
	end

	if bestiaryTrackerWidgetOptions then
		BestiaryTracker.onLogin(bestiaryTrackerWidgetOptions)
	end

	if bossTrackerWidgetOptions then
		BossTracker.onLogin(bossTrackerWidgetOptions)
	end
end

function reopenImbuementPanel()
	if imbuementTrackerWindow:isVisible() then
		g_game.doThing(false)
		g_game.imbuementDurations(true)
		g_game.doThing(true)
	end
end
