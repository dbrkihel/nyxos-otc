local exivaOption = nil
local radioAllowType = nil

local guildBox = nil
local partyBox = nil
local vipBox = nil
local whiteListBox = nil
local whiteList = nil
local guildWhiteListBox = nil
local guildWhiteList = nil
local noteLabel = nil
local charWhiteListLabel = nil
local guildWhiteListLabel = nil

local ExivaData = {
  allowAllExiva = false,
  allowGuildMember = false,
  allowPartyMember = false,
  allowVipList = false,
  allowCharacterWhiteList = false,
  allowGuildWhiteList = false,
  characterWhiteList = {},
  removeCharacter = {},
  guildWhiteList = {},
  removeGuild = {}
}

function init()
  exivaOption = g_ui.displayUI('exiva_option')

  radioAllowType = UIRadioGroup.create()
  radioAllowType:addWidget(exivaOption:recursiveGetChildById('allowAllCheckBox'))
  radioAllowType:addWidget(exivaOption:recursiveGetChildById('allowOnlyCheckBox'))
  radioAllowType.onSelectionChange = onAllowTypeChange

  guildBox = exivaOption:recursiveGetChildById("membersOfGuildCheckBox")
  partyBox = exivaOption:recursiveGetChildById("membersOfPartyCheckBox")
  vipBox = exivaOption:recursiveGetChildById("allVipCheckBox")
  whiteListBox = exivaOption:recursiveGetChildById("charWhiteListCheckBox")
  whiteList = exivaOption:recursiveGetChildById("charWhiteListTextEdit")
  guildWhiteListBox = exivaOption:recursiveGetChildById("guildWhiteListCheckBox")
  guildWhiteList = exivaOption:recursiveGetChildById("guildwhiteListTextEdit")
  noteLabel = exivaOption:recursiveGetChildById("noteLabel")
  charWhiteListLabel = exivaOption:recursiveGetChildById("charWhiteListLabel")
  guildWhiteListLabel = exivaOption:recursiveGetChildById("guildWhiteListLabel")

  hide()

  connect(g_game, {
    onGameEnd = offline,
    onGameStart = online,
    onReceiveExivaOptions = onReceiveExivaOptions
  })
end

function terminate()
  if exivaOption then
    exivaOption:destroy()
    exivaOption = nil
  end

  disconnect(g_game, {
    onGameEnd = offline,
    onGameStart = online,
    onReceiveExivaOptions = onReceiveExivaOptions
  })
end

function online()
  local benchmark = g_clock.millis()
  local active = g_game.canUseExivaRestrictions()
  local widget = m_interface.getRootPanel():recursiveGetChildById("exivaOption")
  if not widget then
    return
  end

  if active then
    widget:setTooltip("Select Characters that can Exiva you")
  else
    widget:setTooltip("Exiva Options are only available on Optional Pvp game worlds")
  end

  widget:setOn(active)
  consoleln("Exiva loaded in " .. (g_clock.millis() - benchmark) / 1000 .. " seconds.")
end

function offline()
  if exivaOption:isVisible() then
    hide()
  end
end

function toggle()
  if exivaOption:isVisible() then
    exivaOption:hide()
  else
    exivaOption:show()
  end
end

function show()
  exivaOption:show()
  g_client.setInputLockWidget(exivaOption)
end

function hide()
  exivaOption:hide()
  g_client.setInputLockWidget(nil)
end

function onRequestExivaOptions()
  updateExivaOptions()
  show()
end

function onReceiveExivaOptions(allowAllExiva, allowGuildMember, allowPartyMember, allowVipList, allowCharacterWhiteList, allowGuildWhiteList, characterWhiteList, removeCharacter, guildWhiteList, removeGuild)
  ExivaData.allowAllExiva = allowAllExiva
  ExivaData.allowGuildMember = allowGuildMember
  ExivaData.allowPartyMember = allowPartyMember
  ExivaData.allowVipList = allowVipList
  ExivaData.allowCharacterWhiteList = allowCharacterWhiteList
  ExivaData.allowGuildWhiteList = allowGuildWhiteList
  ExivaData.characterWhiteList = characterWhiteList
  ExivaData.removeCharacter = removeCharacter
  ExivaData.guildWhiteList = guildWhiteList
  ExivaData.removeGuild = removeGuild
  if exivaOption:isVisible() then
    updateExivaOptions()
  end
end

function updateExivaOptions()
  if ExivaData.allowAllExiva then
    radioAllowType:selectWidget(exivaOption:recursiveGetChildById('allowAllCheckBox'))
  else
    radioAllowType:selectWidget(exivaOption:recursiveGetChildById('allowOnlyCheckBox'))
  end

  guildBox:setChecked(ExivaData.allowGuildMember)
  partyBox:setChecked(ExivaData.allowPartyMember)
  vipBox:setChecked(ExivaData.allowVipList)
  whiteListBox:setChecked(ExivaData.allowCharacterWhiteList)
  guildWhiteListBox:setChecked(ExivaData.allowGuildWhiteList)

  whiteList:clearText()
  for i = 1, #ExivaData.characterWhiteList do
    local text = whiteList:getText()
    if i > 1 then
      text = text .. "\n"
    end

    text = text .. ExivaData.characterWhiteList[i]
    whiteList:setText(text)
  end

  guildWhiteList:clearText()
  for i = 1, #ExivaData.guildWhiteList do
    local text = guildWhiteList:getText()
    if i > 1 then
      text = text .. "\n"
    end

    text = text .. ExivaData.guildWhiteList[i]
    guildWhiteList:setText(text)
  end
end

function onAllowTypeChange(widget, selectedWidget)
  local enabled = selectedWidget:getId() == "allowOnlyCheckBox"
  guildBox:setEnabled(enabled)
  partyBox:setEnabled(enabled)
  vipBox:setEnabled(enabled)
  whiteListBox:setEnabled(enabled)
  whiteList:setEnabled(enabled)
  guildWhiteListBox:setEnabled(enabled)
  guildWhiteList:setEnabled(enabled)
  noteLabel:setEnabled(enabled)
  charWhiteListLabel:setEnabled(enabled)
  guildWhiteListLabel:setEnabled(enabled)
end

local function processWhiteList(text, oldList)
  local newList = {}
  local removedItems = {}
  local lineCount = 0 

  for line in text:gmatch("[^\r\n]+") do
    if lineCount >= 200 then
      break
    end
    table.insert(newList, line)
    lineCount = lineCount + 1
  end

  local newListLookup = {}
  for _, item in ipairs(newList) do
    newListLookup[item] = true
  end

  for _, oldItem in ipairs(oldList) do
    if not newListLookup[oldItem] then
      table.insert(removedItems, oldItem)
    end
  end

  return newList, removedItems
end

function onApply()
  local whiteListText = whiteList:getText()
  local oldWhiteList = ExivaData.characterWhiteList

  local newWhiteList, removedNicks = processWhiteList(whiteListText, oldWhiteList)

  ExivaData.characterWhiteList = newWhiteList
  ExivaData.removeCharacter = removedNicks

  local guildListText = guildWhiteList:getText()
  local oldGuildList = ExivaData.guildWhiteList

  local newGuildList, removedGuilds = processWhiteList(guildListText, oldGuildList)

  ExivaData.guildWhiteList = newGuildList
  ExivaData.removeGuild = removedGuilds

  ExivaData.allowGuildMember = guildBox:isChecked()
  ExivaData.allowPartyMember = partyBox:isChecked()
  ExivaData.allowVipList = vipBox:isChecked()
  ExivaData.allowCharacterWhiteList = whiteListBox:isChecked()
  ExivaData.allowGuildWhiteList = guildWhiteListBox:isChecked()

  local selectedRadio = radioAllowType:getSelectedWidget()
  if selectedRadio then
    ExivaData.allowAllExiva = selectedRadio:getId() == 'allowAllCheckBox'
  end

  sendToServer()
end

function onOkay()
  onApply()
  hide()
end

function sendToServer()
  g_game.sendExivaOptions(ExivaData.allowAllExiva, ExivaData.allowGuildMember, ExivaData.allowPartyMember, 
  ExivaData.allowVipList, ExivaData.allowCharacterWhiteList, ExivaData.allowGuildWhiteList,
  ExivaData.characterWhiteList, ExivaData.removeCharacter, ExivaData.guildWhiteList, ExivaData.removeGuild)
end