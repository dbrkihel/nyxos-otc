-- NPC dialogue window. The server sends the conversation options through opcode
-- 0x1C as optionId + optionText pairs; the packet carries no icon.

window = nil
currentConversation = nil

-- Lines on screen, so hotReload() can put the conversation back.
messageLog = {}

-- icons-npcdialog.png is 320x32: ten frames of 32x32, indexed 0 to 9.
ICON_WIDTH = 32
ICON_HEIGHT = 32

-- Chat system colours (TextColors in gamelib/const.lua), so the conversation
-- looks the same here and in the console NPC tab.
NPC_TEXT_COLOR = '#5FF7F7'
PLAYER_TEXT_COLOR = '#9F9DFD'
KEYWORD_TEXT_COLOR = '#1f9ffe'

-- Server optionId -> sheet frame. NOT the identity: the sheet follows CipSoft's
-- order and Crystalserver's optionIdMap follows its own, so indexing straight by
-- optionId puts the abacus on "deposit" without failing anywhere.
FRAME_BY_OPTION_ID = {
  [0] = 1, [1] = 2, [2] = 3, [3] = 0,
  [4] = 5, [5] = 6, [6] = 4,
  [7] = 7, [8] = 8, [9] = 9,
}

-- The server sends its own order (the banker puts "bye" in the middle); the
-- official groups affirmations, actions, farewell. Ids 20+ go to the end.
DISPLAY_ORDER = { 7, 8, 0, 1, 2, 3, 4, 5, 6, 9 }

local displayRank = {}
for i, optionId in ipairs(DISPLAY_ORDER) do
  displayRank[optionId] = i
end

-- MIN_WIDTH is the QML's own derivation, (button + spacing) * 6 + button plus
-- the window padding, so seven shortcuts always fit in a row.
local MIN_WIDTH, MAX_WIDTH = 314, 1400
local MIN_HEIGHT, MAX_HEIGHT = 350, 900

local EDGE_GRAB_SIZE = 8
local CORNER_GRAB_SIZE = 16

-- Kept at module scope so terminate() can unhook it from rootWidget.
local hoverTracker = nil

local SETTINGS_NODE = 'NpcDialog'

-- addonWidth and marginUnrelated in NpcDialog.qml. The gap counts twice: the QML
-- spaces the chat from the separator and the separator from the trade panel.
local TRADE_WIDTH = 180
local TRADE_GAP = 10
local SEPARATOR_WIDTH = 2
local TRADE_TOTAL = TRADE_WIDTH + TRADE_GAP + SEPARATOR_WIDTH + TRADE_GAP

local tradeDocked = false

-- Inside the dialogue there is no second title bar or close button: the
-- window's own serve both halves, so the trade chrome is stripped.
local function attachTrade(trade)
  local panel = window:getChildById('tradePanel')
  if not panel or trade:getParent() == panel then
    return
  end

  trade:setParent(panel)
  trade:breakAnchors()
  trade:fill('parent')
  -- The content margins were measured from the mini-window's top, title bar
  -- included; with the bar hidden it has to ride 19px higher.
  trade:setMarginTop(-19)

  -- Only the item list and the currency slot are framed in NpcTrade.qml; the
  -- panel itself has no border.
  trade:setImageSource('')
  trade:setImageBorder(0)
  trade:setText('')
  trade:setIcon('')

  for _, id in ipairs({ 'miniwindowTopBar', 'closeButton', 'minimizeButton',
                        'extraButton', 'miniborder' }) do
    local chrome = trade:recursiveGetChildById(id)
    if chrome then
      chrome:setVisible(false)
    end
  end
end

function dockTradeWindow()
  local trade = modules.game_npctrade and modules.game_npctrade.npcWindow
  if not trade or not window then
    return
  end

  local showing = trade:isVisible() and window:isVisible()
  if showing then
    attachTrade(trade)
  end

  if showing == tradeDocked then
    return
  end
  tradeDocked = showing

  window:getChildById('tradePanel'):setVisible(showing)
  window:getChildById('tradeSeparator'):setVisible(showing)
  window:getChildById('tradeMenuButton'):setVisible(showing)
  -- chatOffButton anchors to the window's right edge, which now runs past the
  -- trade column, so the input row has to be held back with the rest.
  for _, id in ipairs({ 'chatFrame', 'buttonsPanel', 'chatOffButton' }) do
    window:getChildById(id):setMarginRight(showing and TRADE_TOTAL or 0)
  end

  -- Grows by the trade column instead of squeezing the chat, as rightPadding
  -- does in the QML.
  window:setWidth(window:getWidth() + (showing and TRADE_TOTAL or -TRADE_TOTAL))
  window:bindRectToParent()
end

local function saveGeometry()
  if not window then
    return
  end
  local pos = window:getPosition()
  g_settings.mergeNode(SETTINGS_NODE, {
    x = pos.x,
    y = pos.y,
    width = window:getWidth(),
    height = window:getHeight()
  })
end

local function restoreGeometry()
  local saved = g_settings.getNode(SETTINGS_NODE)
  if not saved then
    return
  end

  local width = tonumber(saved.width)
  local height = tonumber(saved.height)
  if width and height then
    window:setWidth(math.min(MAX_WIDTH, math.max(MIN_WIDTH, width)))
    window:setHeight(math.min(MAX_HEIGHT, math.max(MIN_HEIGHT, height)))
  end

  local x = tonumber(saved.x)
  local y = tonumber(saved.y)
  if x and y then
    -- The anchors have to go before the position sticks: MainWindow is centred
    -- on its parent, and a centred window snaps back on the next layout pass.
    window:breakAnchors()
    window:setPosition({ x = x, y = y })
    -- Guards against a window restored off-screen after a resolution change.
    window:bindRectToParent()
  end
end

local function setupWindowResize()
  local resizeZone = nil
  -- Distance from the pointer to the window's bottom-right corner, captured on
  -- press. Keeps that corner glued to the cursor -- see onMouseMove.
  local grabOffset = nil
  local hoverCursor = nil
  local exitPressed = false

  local function zoneAt(mousePos)
    local pos = window:getPosition()
    local right = pos.x + window:getWidth()
    local bottom = pos.y + window:getHeight()

    -- Needs a far edge too: without it every point right of the window still
    -- matches, and the cursor never reverts when you leave through that side.
    if mousePos.x < pos.x or mousePos.x > right or mousePos.y < pos.y or mousePos.y > bottom then
      return nil
    end

    if mousePos.x >= right - CORNER_GRAB_SIZE and mousePos.y >= bottom - CORNER_GRAB_SIZE then
      return 'corner'
    elseif mousePos.x >= right - EDGE_GRAB_SIZE then
      return 'right'
    elseif mousePos.y >= bottom - EDGE_GRAB_SIZE then
      return 'bottom'
    end
    return nil
  end

  -- g_mouse keeps a shared stack, so track what we pushed. `force` holds the
  -- cursor through a drag; on plain hover we defer to whoever already owns it.
  local function updateCursor(zone, force)
    local wanted = nil
    if zone == 'bottom' then
      wanted = 'vertical'
    elseif zone == 'right' then
      wanted = 'horizontal'
    elseif zone then
      -- Registered in data/cursors/cursors.otml.
      wanted = 'diagonal'
    end

    if wanted == hoverCursor then
      return
    end

    -- Same guard UIResizeBorder uses.
    if wanted and not hoverCursor and not force and g_mouse.isCursorChanged() then
      return
    end

    if hoverCursor then
      g_mouse.popCursor(hoverCursor)
    end
    hoverCursor = wanted
    if wanted then
      g_mouse.pushCursor(wanted)
    end
  end

  -- The X sits outside the padding rect, so recursiveGetChildByPos never reaches
  -- it. Handled here instead. Atlas: up at y 0, down at y 12.
  local function setExitButtonSunken(sunken)
    local exitButton = window:getChildById('exitButton')
    if exitButton then
      exitButton:setImageClip({ x = 0, y = sunken and 12 or 0, width = 12, height = 12 })
    end
  end

  local function pressedTitleButton(mousePos, id)
    local button = window:getChildById(id)
    if not button or not button:isVisible() then
      return false
    end
    local pos = button:getPosition()
    return mousePos.x >= pos.x and mousePos.x <= pos.x + button:getWidth()
       and mousePos.y >= pos.y and mousePos.y <= pos.y + button:getHeight()
  end

  local function pressedExitButton(mousePos)
    return pressedTitleButton(mousePos, 'exitButton')
  end

  window.onMousePress = function(widget, mousePos, button)
    if button ~= MouseLeftButton then
      return false
    end

    if pressedExitButton(mousePos) then
      -- $pressed never fires: the window is the pressed widget, not the button.
      exitPressed = true
      setExitButtonSunken(true)
      return true
    end

    if pressedTitleButton(mousePos, 'tradeMenuButton') then
      modules.game_npctrade.onExtraMenu()
      return true
    end

    local zone = zoneAt(mousePos)
    if not zone then
      return false
    end
    -- MainWindow is centred, so a still-anchored resize grows both ways.
    window:breakAnchors()

    local pos = window:getPosition()
    grabOffset = {
      x = (pos.x + window:getWidth()) - mousePos.x,
      y = (pos.y + window:getHeight()) - mousePos.y
    }
    resizeZone = zone
    updateCursor(zone, true)
    return true
  end

  window.onMouseMove = function(widget, mousePos, mouseMoved)
    if not resizeZone then
      updateCursor(zoneAt(mousePos))
      return false
    end

    -- From the absolute pointer position, not accumulated deltas: every pixel
    -- lost to a clamp would drift the corner away from the cursor for good.
    local pos = window:getPosition()
    if resizeZone == 'right' or resizeZone == 'corner' then
      local width = mousePos.x + grabOffset.x - pos.x
      window:setWidth(math.min(MAX_WIDTH, math.max(MIN_WIDTH, width)))
    end
    if resizeZone == 'bottom' or resizeZone == 'corner' then
      local height = mousePos.y + grabOffset.y - pos.y
      window:setHeight(math.min(MAX_HEIGHT, math.max(MIN_HEIGHT, height)))
    end
    return true
  end

  window.onMouseRelease = function(widget, mousePos, button)
    if exitPressed then
      exitPressed = false
      setExitButtonSunken(false)
      -- Releasing away from the button cancels, like any other button.
      if pressedExitButton(mousePos) then
        close()
      end
      return true
    end

    if not resizeZone then
      return false
    end
    resizeZone = nil
    grabOffset = nil
    updateCursor(zoneAt(mousePos))
    saveGeometry()
    return true
  end

  -- Hover comes from rootWidget: propagateOnMouseMove applies the same padding
  -- rect filter, so the window is never offered a move over its own edge.
  if hoverTracker then
    disconnect(rootWidget, { onMouseMove = hoverTracker })
  end
  hoverTracker = function(widget, mousePos, mouseMoved)
    if resizeZone then
      return false
    end
    -- Release rather than bail out, or the cursor stays stuck when it closes.
    if not window or not window:isVisible() then
      updateCursor(nil)
      return false
    end
    updateCursor(zoneAt(mousePos))
    return false
  end
  connect(rootWidget, { onMouseMove = hoverTracker })

  -- NpcDialog.qml dims the dialogue to 0.90 when it loses focus.
  window.onFocusChange = function(widget, focused)
    window:setOpacity(focused and 1.0 or 0.90)
  end

end

-- Split out of init() because hotReload() repeats it. The .otui only declares
-- styles, so importStyle plus createWidget -- displayUI would return nil.
local function buildWindow()
  g_ui.importStyle('npcdialog')
  window = g_ui.createWidget('NpcDialogWindow', rootWidget)
  window:hide()

  local input = window:getChildById('chatInput')
  input.onKeyPress = function(widget, keyCode)
    if keyCode == KeyEnter or keyCode == KeyReturn then
      local text = widget:getText()
      if text and #text > 0 then
        sayToNpc(text)
        widget:setText('')
      end
      return true
    end
    return false
  end

  setupWindowResize()

end

-- Rebuilds the window from the .otui without restarting, keeping the open
-- conversation. Enabled by UI_HOTRELOAD in config.lua; kept apart from
-- DEVELOPERMODE, which would also change the layout being tuned.
function hotReload()
  local conversation = currentConversation
  local savedLog = messageLog

  if window then
    window:destroy()
  end
  messageLog = {}
  buildWindow()

  if conversation then
    onNpcDialog(conversation.npcId, conversation.options)
    for _, entry in ipairs(savedLog) do
      addMessage(entry.text, entry.color)
    end
  end

  g_logger.info('[NpcDialog] window reloaded from npcdialog.otui')
end

function init()
  buildWindow()

  connect(g_game, {
    onNpcDialog = onNpcDialog,
    onCloseNpcDialog = onCloseNpcDialog,
    onTalk = onTalk,
    onGameEnd = onCloseNpcDialog
  })

  if UI_HOTRELOAD then
    g_keyboard.bindKeyDown('Ctrl+Shift+R', hotReload)
  end
end

function terminate()
  disconnect(g_game, {
    onNpcDialog = onNpcDialog,
    onCloseNpcDialog = onCloseNpcDialog,
    onTalk = onTalk,
    onGameEnd = onCloseNpcDialog
  })

  if UI_HOTRELOAD then
    g_keyboard.unbindKeyDown('Ctrl+Shift+R')
  end

  if hoverTracker then
    disconnect(rootWidget, { onMouseMove = hoverTracker })
    hoverTracker = nil
  end

  if window then
    window:destroy()
    window = nil
  end
  currentConversation = nil
  messageLog = {}
end

-- Ids 20+ are free keywords with no icon; they fall back to a text button.
function iconForOptionId(optionId)
  return FRAME_BY_OPTION_ID[optionId]
end

-- Fired by the C++ side with the clicked keyword.
function onKeywordClicked(widget, text, mousePos)
  if text and #text > 0 then
    sayToNpc(text)
  end
end

function onKeywordHoverChange(widget, text, hovered)
  if hovered then
    g_mouse.pushCursor('pointer')
  else
    g_mouse.popCursor('pointer')
  end
end

-- Turns {braces} into clickable fragments, as Message:highlightNPCChatText does.
-- processCodeTags strips the markers during layout. nil when there is no keyword.
local function buildKeywordFragments(text, baseColor)
  if not text:find('{', 1, true) then
    return nil
  end

  local fragments = {}
  local buffer = ''
  local hasKeyword = false

  local i, n = 1, #text
  while i <= n do
    local char = text:sub(i, i)
    if char == '{' then
      if #buffer > 0 then
        table.insert(fragments, buffer)
        table.insert(fragments, baseColor)
        buffer = ''
      end
      local keyword = ''
      i = i + 1
      while i <= n do
        local kc = text:sub(i, i)
        if kc == '}' then
          break
        end
        keyword = keyword .. kc
        i = i + 1
      end
      if #keyword > 0 then
        table.insert(fragments, '[text-event]' .. keyword .. '[/text-event]')
        table.insert(fragments, KEYWORD_TEXT_COLOR)
        hasKeyword = true
      end
    else
      buffer = buffer .. char
    end
    i = i + 1
  end

  if #buffer > 0 then
    table.insert(fragments, buffer)
    table.insert(fragments, baseColor)
  end

  return hasKeyword and fragments or nil
end

function addMessage(text, color)
  table.insert(messageLog, { text = text, color = color })

  local buffer = window:recursiveGetChildById('chatBuffer')
  local label = g_ui.createWidget('NpcDialogMessage', buffer)

  local fragments = buildKeywordFragments(text, color or NPC_TEXT_COLOR)
  if fragments then
    -- Before setColoredText, or the markers render literally.
    label:setEventListener(EVENT_TEXT_CLICK)
    label:setEventListener(EVENT_TEXT_HOVER)
    label.onTextClick = onKeywordClicked
    label.onTextHoverChange = onKeywordHoverChange
    label:setColoredText(fragments)
  else
    label:setText(text)
    if color then
      label:setColor(color)
    end
  end

  -- Deferred: the label only has a height after the next layout pass.
  addEvent(function()
    if buffer and buffer:getChildCount() > 0 then
      buffer:ensureChildVisible(buffer:getLastChild())
    end
  end)
end

-- Talking to an NPC in the modern client is a PRIVATE message, with mode NpcTo
-- and the NPC name as the receiver -- it is not speaking out loud.
--
-- The first version used g_game.talk(), which sends a plain "say" on the default
-- channel: the text landed in the general chat and the NPC was never addressed,
-- so the buttons looked broken when they were in fact talking to the wrong
-- place. Same path Chat:sendPrivateMessage uses for the console NPC tabs.
function sayToNpc(text)
  if not text or #text == 0 or not g_game.isOnline() then
    return
  end

  local name = currentConversation and currentConversation.name
  if name then
    g_game.talkPrivate(MessageModes.NpcTo, name, text)
  else
    -- Without the name there is nothing to address; speaking out loud still
    -- reaches an NPC standing next to us, which beats swallowing the message.
    g_game.talk(text)
  end

  -- Our own speech does not come back through onTalk: the client echoes what it
  -- sends instead of receiving it back from the server, so it has to be written
  -- here -- otherwise the window shows only the NPC side and the conversation
  -- reads as half of itself.
  local player = g_game.getLocalPlayer()
  if player then
    addMessage(string.format('%s %s: %s', os.date('%H:%M'), player:getName(), text),
               PLAYER_TEXT_COLOR)
  end
end

local function clearButtons()
  local panel = window:getChildById('buttonsPanel')
  panel:destroyChildren()
  panel:setHeight(0)
  return panel
end

-- The name rides the caption banner, not the window's own centred title, which
-- is why the title is cleared. The banner is sliced so its ends stay intact
-- while the middle gives, so it only has to be told how wide to be.
--
-- Width is set from a deferred event because the label reports its size only
-- after the next layout pass; asking right after setText measures the old text.
local function setCaption(name)
  window:setText('')

  -- recursive, not getChildById: the banner is a grandchild now, parented to the
  -- conversation frame so it stacks between that frame and the podestal.
  local flag = window:recursiveGetChildById('captionFlag')
  local label = window:recursiveGetChildById('captionFlagText')
  if not flag or not label then
    return
  end

  label:setText(name)
  addEvent(function()
    if flag and label then
      -- TibiaDialog.qml: textLeftMargin + max(70, textWidth) + textRightMargin.
      -- The 70 floor is the official's own note that short flags look wrong.
      flag:setWidth(87 + math.max(70, label:getTextSize().width) + 12)
    end
  end)
end

function onNpcDialog(npcId, options)
  currentConversation = { npcId = npcId, options = options }

  local npc = g_map.getCreatureById(npcId)
  if npc then
    -- Kept because it is the receiver of everything sent from here on.
    currentConversation.name = npc:getName()
    setCaption(npc:getName())

    local outfit = window:recursiveGetChildById('npcOutfit')
    local fallback = window:recursiveGetChildById('npcOutfitFallback')
    outfit:setOutfit(npc:getOutfit())
    outfit:setVisible(true)
    fallback:setVisible(false)
  else
    -- With no creature on the map there is no outfit to draw; the official
    -- client falls back to the "multiple NPCs" icon in the same situation.
    setCaption(tr('Conversation'))
    window:recursiveGetChildById('npcOutfit'):setVisible(false)
    window:recursiveGetChildById('npcOutfitFallback'):setVisible(true)
  end

  local panel = clearButtons()

  -- Sorts by the display table; anything not in it (ids 20+) goes to the end,
  -- preserving arrival order.
  local sorted = {}
  for index, option in ipairs(options) do
    table.insert(sorted, { id = option[1], text = option[2], arrival = index })
  end
  table.sort(sorted, function(a, b)
    local ra = displayRank[a.id] or (100 + a.arrival)
    local rb = displayRank[b.id] or (100 + b.arrival)
    return ra < rb
  end)

  for _, option in ipairs(sorted) do
    local frame = iconForOptionId(option.id)
    local button
    if frame then
      button = g_ui.createWidget('NpcDialogButton', panel)
      button:setIconClip({
        x = frame * ICON_WIDTH, y = 0,
        width = ICON_WIDTH, height = ICON_HEIGHT
      })
    else
      button = g_ui.createWidget('NpcDialogTextButton', panel)
      button:setText(option.text)
      button:setWidth(math.max(50, #option.text * 8))
    end
    button:setTooltip(option.text)
    button.onClick = function()
      sayToNpc(option.text)
    end
  end

  if #sorted > 0 then
    panel:setHeight(36) -- matches NpcDialogButton; see the note on its size
  end

  if not window:isVisible() then
    restoreGeometry()
    window:show()
    window:raise()
    -- initialFocusItem: chatInput in NpcDialog.qml -- the caret belongs in the
    -- chat box when a conversation opens, so you can just start typing.
    local input = window:getChildById('chatInput')
    if input then
      input:focus()
    else
      window:focus()
    end
  end
end

function onTalk(name, level, mode, message, channelId, position)
  if not window or not window:isVisible() then
    return
  end

  -- Only the speech of the NPC being talked to matters here; everything else
  -- keeps going to the console as usual.
  if mode == MessageModes.NpcFrom or mode == MessageModes.NpcFromStartBlock then
    addMessage(string.format('%s %s: %s', os.date('%H:%M'), name, message),
               NPC_TEXT_COLOR)
  end
end

function close()
  -- Saying goodbye is what ends the conversation on the server side; closing
  -- only the window would leave the NPC believing it is still going.
  if currentConversation and g_game.isOnline() then
    sayToNpc('bye')
  end
  onCloseNpcDialog()
end

function onCloseNpcDialog()
  currentConversation = nil
  messageLog = {}
  if not window then
    return
  end

  -- Recorded on the way out so a drag is captured too: dragging is UIWindow's
  -- own business and never passes through the resize handlers.
  saveGeometry()
  window:hide()

  -- The trade panel is docked to this window, so it goes with it.
  local trade = modules.game_npctrade
  if trade and trade.npcWindow and trade.npcWindow:isVisible() then
    trade.closeNpcTrade()
  end
  local buffer = window:recursiveGetChildById('chatBuffer')
  if buffer then
    buffer:destroyChildren()
  end
  clearButtons()
end
