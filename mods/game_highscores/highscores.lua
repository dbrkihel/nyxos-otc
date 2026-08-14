local highscoresWindow
local gameworldbox
local vocationbox
local categorybox
local highscoreTable

local pvpTypesById = {
  ["openPvpCheck"] = 0,
  ["optionalPvpCheck"] = 1,
  ["hardcorePvpCheck"] = 2,
  ["retroOpenPvpCheck"] = 3,
  ["retroHardcorePvpCheck"] = 4,
}

function init()
  highscoresWindow = g_ui.displayUI('highscores')
  highscoresWindow:hide()

  if initHighscoresProtocol then
    initHighscoresProtocol()
  end

  connect(g_game, {
    onGameEnd = offline,
    onHighscores = onHighscores,
  })

  initInterface()
end

function terminate()
  disconnect(g_game, {
    onGameEnd = offline,
    onHighscores = onHighscores,
  })

  if terminateHighscoresProtocol then
    terminateHighscoresProtocol()
  end

  if highscoresWindow then
    highscoresWindow:destroy()
    highscoresWindow = nil
  end
end

function hide()
  highscoresWindow:hide()
  g_client.setInputLockWidget(nil)
  modules.game_sidebuttons.setButtonVisible("highscoresDialog", false)
end

function show()
  highscoresWindow:show(true)
  highscoresWindow:focus()
  g_client.setInputLockWidget(highscoresWindow)
  modules.game_sidebuttons.setButtonVisible("highscoresDialog", true)
  g_game.highscore(0, 0, 0xFFFFFFFF, g_game.getWorldName(), 1, 20)
end

function offline()
  if modules.game_sidebuttons.isButtonVisible("highscoresDialog") then
    modules.game_sidebuttons.setButtonVisible("highscoresDialog", false)
  end
  hide()
end

function initInterface()
  highscoreTable = highscoresWindow.highscoreList
  gameworldbox = highscoresWindow.filters.gameworldbox
  vocationbox = highscoresWindow.filters.vocationbox
  categorybox = highscoresWindow.filters.categorybox
end

local function getHours(seconds)
  return math.floor((seconds/60)/60)
end

local function getMinutes(seconds)
  return math.floor(seconds/60)
end

local function getSeconds(seconds)
  return seconds%60
end

local function getTimeinWords(secs)
  local hours, minutes, seconds = getHours(secs), getMinutes(secs), getSeconds(secs)
  if (minutes > 59) then
    minutes = minutes-hours*60
  end

  local timeStr = ''

  if hours > 0 then
    timeStr = timeStr .. ' hours '
  end

  if minutes > 0 then
    timeStr = timeStr .. minutes .. ' minutes'
  elseif seconds > 0 then
    timeStr =  seconds .. ' seconds'
  end

  return timeStr
end

local function getIndex(tb, value)
  for index, name in pairs(tb) do
    if name == value then
      return index
    end
  end
  return 1
end

function onHighscores(worlds, selectedWorld, vocations, selectedVocation, categories, selectedCategory, page, pages, characters, lastUpdate)
  gameworldbox:clearOptions()
  gameworldbox:addOption("All Game Worlds")
  for id, world in pairs(worlds) do
    gameworldbox:addOption(world)
  end

  gameworldbox:setCurrentOption(selectedWorld, false)

  vocationbox:clearOptions()
  for id, vocation in pairs(vocations) do
    vocationbox:addOption(vocation)
  end
  vocationbox:setCurrentOption(vocations[selectedVocation], false)

  categorybox:clearOptions()
  for id, vocation in pairs(categories) do
    categorybox:addOption(vocation)
  end
  categorybox:setCurrentOption(categories[selectedCategory], false)

  highscoreTable:destroyChildren()
  for id, character in pairs(characters) do
    local widget = g_ui.createWidget('ListHighscore', highscoreTable)
    widget.rank:setText(character[1])
    widget.rank:setColor("#c0c0c0")
    widget.name:setText(character[2])
    widget.name:setColor("#c0c0c0")
    widget.vocation:setText(g_game.getVocationName(character[3]))
    widget.vocation:setColor("#c0c0c0")
    widget.gameworld:setText(short_text(character[4], 8))
    widget.gameworld:setColor("#c0c0c0")
    widget.level:setText(character[5])
    widget.level:setColor("#c0c0c0")
    widget:setBackgroundColor((id % 2 == 0 and '#484848' or '#414141'))
    widget.points:setText(comma_value(character[7]))
    widget.points:setColor("#c0c0c0")
    if character[6] then
      widget.rank:setColor("#60f860")
      widget.name:setColor("#60f860")
      widget.vocation:setColor("#60f860")
      widget.gameworld:setColor("#60f860")
      widget.points:setColor("#60f860")
    end
  end

  local rest = 20 - #highscoreTable:getChildren()
  if rest > 0 then
    for i = 1, rest do
      local widget = g_ui.createWidget('ListHighscore', highscoreTable)
      widget:setBackgroundColor((i % 2 == 0 and '#484848' or '#414141'))
    end
  end

  highscoresWindow.page:setText(string.format("%d / %d", page, pages))
  highscoresWindow.page:setColor("#c0c0c0")
  highscoresWindow.lastUpdate:setText("Last Update: "..getTimeinWords(os.time() - lastUpdate) .. " ago")
  highscoresWindow.lastUpdate:setColor("#909090")

  -- buttons
  local m_seletecdWorld = selectedWorld
  if m_seletecdWorld == "All Game Worlds" then
    m_seletecdWorld = ""
  end

  local stringPvpTypes = ""
  for checkboxId, typeId in pairs(pvpTypesById) do
    local checkbox = highscoresWindow:recursiveGetChildById(checkboxId)
    if checkbox and checkbox:isChecked() then
      if stringPvpTypes ~= "" then
        stringPvpTypes = stringPvpTypes .. ","
      end
      stringPvpTypes = stringPvpTypes .. typeId
    end
  end

  highscoresWindow.showOwnRank.onClick = function()
    g_game.highscore(1, getIndex(categories, categorybox:getCurrentOption().text), getIndex(vocations, vocationbox:getCurrentOption().text), m_seletecdWorld, 1, 20, stringPvpTypes)
  end
  highscoresWindow.first.onClick = function()
    g_game.highscore(0, selectedCategory, selectedVocation, m_seletecdWorld, 1, 20, stringPvpTypes)
  end
  highscoresWindow.prevButton.onClick = function()
    g_game.highscore(0, selectedCategory, selectedVocation, m_seletecdWorld, math.max(1, page -1), 20, stringPvpTypes)
  end
  highscoresWindow.nextButton.onClick = function()
    g_game.highscore(0, selectedCategory, selectedVocation, m_seletecdWorld, math.min(pages, page +1), 20, stringPvpTypes)
  end
  highscoresWindow.last.onClick = function()
    g_game.highscore(0, selectedCategory, selectedVocation, m_seletecdWorld, pages, 20, stringPvpTypes)
  end


  highscoresWindow.filters.submit.onClick = function()
    local m_seletecdWorld = gameworldbox:getCurrentOption().text
    if m_seletecdWorld == "All Game Worlds" then
      m_seletecdWorld = ""
    end
    g_game.highscore(0, getIndex(categories, categorybox:getCurrentOption().text), getIndex(vocations, vocationbox:getCurrentOption().text), m_seletecdWorld, 1, 20, stringPvpTypes)
  end
end