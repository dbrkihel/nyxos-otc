StoreWindow = nil
offerCheckBox = nil
buyOfferWindow = nil
SucessOfferWindow = nil
nameChangePanel = nil
hirelingWindow = nil
hirelingNameWindow = nil
bazaarWindow = nil
pixWindow = nil
OFFERID = nil
OFFERTYPE = nil

giftWindow = nil

local importFiles = {
  'styles/buttons',
  'styles/home',
  'styles/offers',
  'styles/buypanel',
  'styles/gift',
  'styles/hirelingwindow',
  'styles/hirelingname',
  'styles/history',
  'styles/namechange',
  'styles/sucessofferwindow',
  'styles/bazaar',
  'styles/pixdonate'
}

function init()
  StoreWindow = g_ui.displayUI('store')
  StoreWindow:hide()

  for i, file in pairs(importFiles) do
    g_ui.importStyle(file)
  end

  buyOfferWindow = g_ui.createWidget('BuyOfferWindow', rootWidget)
  buyOfferWindow:hide()
  -- Enter confirms the purchase (mirrors the per-offer okBuyButton click). Escape is wired in buypanel.otui.
  buyOfferWindow.onEnter = function()
    local btn = buyOfferWindow.okBuyButton
    if btn and btn:isVisible() and btn.onClick then
      btn.onClick()
    end
  end
  SucessOfferWindow = g_ui.createWidget('SucessOfferWindow', rootWidget)
  SucessOfferWindow:hide()
  -- Enter runs the same completePurchase the confirm button uses. Escape is wired in sucessofferwindow.otui.
  SucessOfferWindow.onEnter = function()
    completePurchase(SucessOfferWindow.confirm)
  end

  nameChangePanel = g_ui.createWidget('NameChangeWindow', rootWidget)
  nameChangePanel:hide()
  -- Enter = Ok (only once the name is valid), Escape = Cancel.
  nameChangePanel.onEscape = function()
    onClickNameChange(nameChangePanel.cancelButton)
  end
  nameChangePanel.onEnter = function()
    local ok = nameChangePanel.okNameChangeButton
    if ok:isVisible() and ok:isEnabled() then
      onClickNameChange(ok)
    end
  end
  hirelingWindow = g_ui.createWidget('HirelingWindow', rootWidget)
  hirelingWindow:hide()
  -- Enter = Buy Now (only once enabled), Escape = Cancel.
  hirelingWindow.onEscape = function()
    onClickNameChange(hirelingWindow.cancelHirelingButton)
  end
  hirelingWindow.onEnter = function()
    local ok = hirelingWindow.okHirelingButton
    if ok:isVisible() and ok:isEnabled() then
      onClickNameChange(ok)
    end
  end
  hirelingNameWindow = g_ui.createWidget('HirelingNameChange', rootWidget)
  hirelingNameWindow:hide()
  -- Enter = Ok (only once enabled). Escape is wired in hirelingname.otui.
  hirelingNameWindow.onEnter = function()
    local ok = hirelingNameWindow.contentPanel.ok
    if ok:isVisible() and ok:isEnabled() then
      onCloseHirelingNameWindow(true)
    end
  end
  bazaarWindow = g_ui.createWidget('BazaarWindow', rootWidget)
  bazaarWindow:hide()
  -- Enter triggers the current wizard page's "next" button. Escape is wired in bazaar.otui (closes the wizard).
  bazaarWindow.onEnter = function()
    local content = bazaarWindow.contentPanel
    local btn = content.rulesPanel:isVisible() and content.rulesPanel.next or content.characterPanel.next
    if btn and btn:isVisible() and btn:isEnabled() and btn.onClick then
      btn.onClick(btn)
    end
  end

  pixWindow = g_ui.createWidget('PixWindow', rootWidget)
  pixWindow:hide()

  offerCheckBox = UIRadioGroup.create()
  connect(g_game, {
    onStoreInit = onStoreInit,
    onGameEnd = onGameEnd,
    onCoinBalance = onCoinBalance,
    onStoreCategories = onStoreCategories,
    onStoreHomeOffers = onStoreHomeOffers,
    onStoreOffers = onStoreOffers,
    onStoreDescription = onStoreDescription,
    onStoreError = onStoreError,
    onRequestPurchaseData = onRequestPurchaseData,
    onStoreTransactionHistory = onStoreTransactionHistory,
    onStorePurchase = onStorePurchase,
    onStoreSearchOffers = onStoreSearchOffers,
    onCharacterBazarRequeriments = Bazaar.onCharacterBazarRequeriments,
    onCharacterBazarItems = Bazaar.onCharacterBazarItems,
    onCharacterBazarStoreItems = Bazaar.onCharacterBazarStoreItems,
    onCharacterBazarInformations = Bazaar.onCharacterBazarInformations,
    onRequestWorldTransferData = onRequestWorldTransferData,
    onHirelingNameChange = onHirelingNameChange,
    onRecvPixData = onRecvPixData,
    onRecvPixURL = onRecvPixURL,
    onCharacterBazarCheckInformations = onCharacterBazarCheckInformations
  })

  connect(offerCheckBox, { onSelectionChange = onSelectionOffer })

  if initStoreProtocol then
    initStoreProtocol()
  end
end

function terminate()
  if terminateStoreProtocol then
    terminateStoreProtocol()
  end

  if g_game.isOnline() then
    onGameEnd()
  end

  if StoreWindow then
    StoreWindow:destroy()
  end

  StoreWindow = nil
  disconnect(g_game, {
    onStoreInit = onStoreInit,
    onGameEnd = onGameEnd,
    onCoinBalance = onCoinBalance,
    onStoreCategories = onStoreCategories,
    onStoreHomeOffers = onStoreHomeOffers,
    onStoreOffers = onStoreOffers,
    onStoreDescription = onStoreDescription,
    onStoreError = onStoreError,
    onRequestPurchaseData = onRequestPurchaseData,
    onStoreTransactionHistory = onStoreTransactionHistory,
    onStorePurchase = onStorePurchase,
    onStoreSearchOffers = onStoreSearchOffers,
    onCharacterBazarRequeriments = Bazaar.onCharacterBazarRequeriments,
    onCharacterBazarItems = Bazaar.onCharacterBazarItems,
    onCharacterBazarStoreItems = Bazaar.onCharacterBazarStoreItems,
    onCharacterBazarInformations = Bazaar.onCharacterBazarInformations,
    onRequestWorldTransferData = onRequestWorldTransferData,
    onHirelingNameChange = onHirelingNameChange,
    onRecvPixData = onRecvPixData,
    onRecvPixURL = onRecvPixURL,
    onCharacterBazarCheckInformations = onCharacterBazarCheckInformations
  })

  disconnect(offerCheckBox, { onSelectionChange = onSelectionOffer })
  offerCheckBox = nil


  if buyOfferWindow then
    buyOfferWindow:destroy()
    buyOfferWindow = nil
  end

  if SucessOfferWindow then
    SucessOfferWindow:destroy()
    SucessOfferWindow = nil
  end

  if nameChangePanel then
    nameChangePanel:destroy()
    nameChangePanel = nil
  end

  if hirelingWindow then
    hirelingWindow:destroy()
    hirelingWindow = nil
  end

  if hirelingNameWindow then
    hirelingNameWindow:destroy()
    hirelingNameWindow = nil
  end

  if bazaarWindow then
    bazaarWindow:destroy()
    bazaarWindow = nil
  end

  if pixWindow then
    pixWindow:destroy()
    pixWindow = nil
  end
end

-- Setup Store
function onGameEnd()
  -- Reset the purchase guard so a disconnect mid-buy doesn't leave it stuck.
  Offers:endPurchase()
  if StoreWindow:isVisible() then
    StoreWindow:hide()
  end
  g_client.setInputLockWidget(nil)
  if buyOfferWindow:isVisible() then
    buyOfferWindow:hide()
  end
  Offers:stopAllEvents()

  if hirelingWindow:isVisible() then
    hirelingWindow:hide()
  end
  if hirelingNameWindow:isVisible() then
    hirelingNameWindow:hide()
  end
  if nameChangePanel:isVisible() then
    nameChangePanel:hide()
  end
  if bazaarWindow:isVisible() then
    bazaarWindow:hide()
  end
  if pixWindow:isVisible() then
    pixWindow:hide()
  end
  if transferError and transferError:isVisible() then
    transferError:destroy()
    transferError = nil
  end

  if giftWindow and giftWindow:isVisible() then
    giftWindow:destroy()
    giftWindow = nil
  end

  if HomeOffer and HomeOffer.dailyRerollWindow then
    HomeOffer.dailyRerollWindow:destroy()
    HomeOffer.dailyRerollWindow = nil
  end
end

function closeStore()
  if StoreWindow:isVisible() then
    StoreWindow:hide()
  end
  g_client.setInputLockWidget(nil)
  if buyOfferWindow:isVisible() then
    buyOfferWindow:hide()
  end

  Offers:stopAllEvents()
end

function showStoreWindow()
  StoreWindow:show(true)
  StoreWindow:raise()
  StoreWindow:focus()
  g_client.setInputLockWidget(StoreWindow)

  if Offers.completePurchaseEvent then
    Offers.completePurchaseEvent:cancel()
  end
end

function onStoreInit(url, coinsPacketSize)
  -- The server may send the base URL with or without a trailing slash, while
  -- every image path is concatenated as a bare relative segment (e.g. "13/..").
  -- Normalize to a single trailing slash so we never produce ".../store13/..".
  if url and #url > 0 and url:sub(-1) ~= "/" then
    url = url .. "/"
  end
  Store.url = url
  Store.coinsPacketSize = coinsPacketSize
end

function onStoreCategories(categories)
  if not StoreWindow:isVisible() then
    showStoreWindow()
  end

  Categories:configure(categories)
end

function onCoinBalance(coins, transferableCoins, reservedCoins)
  if (SucessOfferWindow and SucessOfferWindow:isVisible()) or StoreWindow:isVisible() then
    StoreWindow.coinsStatus.tibiacoin:setText(formatMoney(coins, ","))
    local coinsText = string.format(" (%s: %s ", (GameInfo.CoinName and GameInfo.CoinName or "Nyxos Coins"),
      formatMoney(transferableCoins, ","))
    StoreWindow.coinsStatus.tibiacointransferable:setText(coinsText)

    Store.coins = coins
    Store.transferableCoins = transferableCoins

    bazaarWindow.contentPanel.rulesPanel:recursiveGetChildById('coin'):setText(formatMoney(transferableCoins, ","))
    bazaarWindow.contentPanel.characterPanel:recursiveGetChildById('coin'):setText(formatMoney(transferableCoins, ","))

    -- Don't rebuild the offer list mid-purchase: the post-buy balance update lands
    -- ~650ms before the delivery screen and the rebuild shows as a flicker. The
    -- purchase flow refreshes once at the end (completePurchase -> reloadOffers).
    if not Offers.purchasePending then
      Offers:refreshOffers(Offers.displayOffer, Offers.redirect, Offers.filter)
    end
  end
end

function onStoreHomeOffers(categoryName, offers, scrolling, homePanel, reasons, dailyOfferPrice, dailyOffers)
  HomeOffer:configure(categoryName, offers, scrolling, homePanel, reasons, dailyOfferPrice, dailyOffers)
end

function onStoreOffers(categoryName, offers, redirect, sortingType, filters, currentFilter, reasons)
  Offers:configure(categoryName, offers, redirect, sortingType, filters, currentFilter, reasons)
end

function onSelectionOffer(widget, selectedWidget)
  Offers:onSelectionOffer(widget, selectedWidget)
end

function onStoreDescription(offerId, description)
  -- Cache the pushed description; configureDescription writes to the single shared
  -- panel, so rendering every push would let the last offer clobber the selected
  -- one. calldescription() renders the selected offer's text from this cache.
  Offers:cacheDescription(offerId, description)
end

function showError(title, errorMessage)
  if transferError then
    return
  end

  local cancelFunc = function()
    transferError:destroy()
    transferError = nil
    g_client.setInputLockWidget(StoreWindow)
    showStoreWindow()
  end

  transferError = displayGeneralBox(tr(title), tr(errorMessage),
    {
      { text = tr('Ok'), callback = cancelFunc },
      anchor = AnchorHorizontalCenter
    }, cancelFunc, cancelFunc)

  return true
end

function onStoreError(errorType, message)
  -- A failed purchase never reaches completePurchase, so release the guard here or
  -- onCoinBalance would stop refreshing the list for the rest of the session.
  Offers:endPurchase()
  StoreWindow:hide()
  g_client.setInputLockWidget(nil)
  showError('Purchase Error', message)
end

function onGiftWindow()
  if g_game.getTransferableTibiaCoins() < Store.coinsPacketSize then
    return showError('Gifting not possible', 'You don\'t have enough coins to gift.')
  end

  GiftCoins:onGiftWindow()
end

function requestHistory()
  g_game.openTransactionHistory(Store.requestPerPage)
end

function onStoreTransactionHistory(currentPage, pageCount, offers)
  if Offers.displayPanel then
    Offers.displayPanel:destroy()
  end
  Offers:stopAllEvents()

  Offers.displayPanel = g_ui.createWidget('HistoryPanel', StoreWindow.contentPanel)
  Offers.displayPanel:setId("history")

  Offers.displayPanel.pageState:setText(string.format("Page %d/%d", currentPage + 1, math.max(1, pageCount)))
  local pageCount = pageCount - 1
  if currentPage > 0 then
    Offers.displayPanel.previousButton.onClick = function()
      g_game.requestTransactionHistory(currentPage - 1, Store.requestPerPage)
    end
  end

  if currentPage <= pageCount - 1 then
    Offers.displayPanel.nextButton.onClick = function()
      g_game.requestTransactionHistory(currentPage + 1, Store.requestPerPage)
    end
  end

  for _, child in pairs(Offers.displayPanel.historyListPanel:getChildren()) do
    child:destroy()
    child = nil
  end

  local count = 0
  for key, item in pairs(offers) do
    local itemBox = g_ui.createWidget('HistoryLabel', Offers.displayPanel.historyListPanel)
    local color = (count % 2) == 0 and '#484848' or '#414141'
    itemBox:setBackgroundColor(color)

    if count == 0 then
      itemBox:setMarginTop(16)
    end

    count = count + 1
    itemBox.date:setText(short_text(item.description, 20))
    itemBox.date.desc:setTooltip(item.description)
    if item.price < 0 then
      itemBox.balance:setText(item.price)
      itemBox.balance:setColor("$var-text-cip-store-red")
    else
      itemBox.balance:setText("+" .. item.price)
      itemBox.balance:setColor("$var-text-cip-color-green")
    end
    itemBox.description:setText(short_text(item.name, 35))
    itemBox.description.desc:setTooltip(item.name)

    -- Coin type icon: transferable (paid) coins vs normal/online coins. The server
    -- sends coin_type per entry (0 = normal/online coin, 1 = transferable/paid coin).
    if itemBox.coinType then
      local isTransferable = item.coinType == COIN_TYPE_TRANSFERABLE
      itemBox.coinType:setImageSource('/images/store/icon-' .. (isTransferable and 'tibiacointransferable' or 'tibiacoin'))
      itemBox.coinType:setTooltip(isTransferable and tr('Transferable Nyxos Coins') or tr('Nyxos Coins'))
    end
  end
end

function onRequestPurchaseData(transactionId, productType)
  OFFERID = nil
  OFFERTYPE = nil
  if productType == OFFER_BUY_TYPE_NAMECHANGE then
    nameChangePanel:show()
    closeStore()
    -- closeStore() schedules focus back to the game window; re-focus so Enter/Escape reach the dialog.
    scheduleEvent(function() nameChangePanel:focus() end, 50)
    OFFERID = transactionId
    OFFERTYPE = productType
  elseif productType == OFFER_BUY_TYPE_HIRELING then
    hirelingWindow:show()
    closeStore()
    -- closeStore() schedules focus back to the game window; re-focus so Enter/Escape reach the dialog.
    scheduleEvent(function() hirelingWindow:focus() end, 50)
    OFFERID = transactionId
    OFFERTYPE = productType
  elseif productType == OFFER_BUY_TYPE_TRANSFER then
    closeStore()
    OFFERID = transactionId
    OFFERTYPE = productType
    modules.game_transfer.show()
  end
end

function onRequestWorldTransferData(transactionId, productType, worlds, hasRedSkull, hasBlackSkull, hasGuild, hasHouse,
                                    hasMarketCoin)
  if productType == OFFER_BUY_TYPE_TRANSFER then
    closeStore()
    OFFERID = transactionId
    OFFERTYPE = productType
    modules.game_transfer.configure(transactionId, productType, worlds, hasRedSkull, hasBlackSkull, hasGuild, hasHouse,
      hasMarketCoin)
  end
end

function onNameTextChange(widget)
  if not nameChangePanel:isVisible() then
    return
  end

  if #widget:getText() < 2 then
    nameChangePanel.okNameChangeButton:setEnabled(false)
  else
    nameChangePanel.okNameChangeButton:setEnabled(true)
  end
end

function onNameHirelingTextChange(widget)
  if not hirelingWindow then
    return
  end

  if #widget:getText() < 3 then
    hirelingWindow.okHirelingButton:setEnabled(false)
  else
    hirelingWindow.okHirelingButton:setEnabled(true)
  end
end

function onClickNameChange(widget)
  if widget:getId() == 'cancelButton' then
    if nameChangePanel:isVisible() then
      nameChangePanel:hide()
    end
    if not StoreWindow:isVisible() then
      showStoreWindow()
    end
  elseif widget:getId() == 'cancelHirelingButton' then
    if hirelingWindow then
      hirelingWindow:hide()
    end
    if not StoreWindow:isVisible() then
      showStoreWindow()
    end
  elseif widget:getId() == 'okHirelingButton' then
    -- server HIRELING_SEX: MALE = 1, FEMALE = 2 (any other value falls back to male)
    g_game.buyStoreOffer(OFFERID, OFFER_BUY_TYPE_HIRELING, hirelingWindow.nameText:getText(),
      (hirelingWindow.sexOptions.currentIndex == 1 and 1 or 2))
    if hirelingWindow then
      hirelingWindow:hide()
    end
    if not StoreWindow:isVisible() then
      showStoreWindow()
    end
  elseif widget:getId() == 'okNameChangeButton' then
    g_game.buyStoreOffer(OFFERID, OFFER_BUY_TYPE_NAMECHANGE, nameChangePanel.nameText:getText())
    if nameChangePanel then
      nameChangePanel:hide()
    end
    if not StoreWindow:isVisible() then
      showStoreWindow()
    end
  end

  if not StoreWindow:isVisible() then
    showStoreWindow()
  end

  OFFERID = nil
  OFFERTYPE = nil
end

function onSearchEdit(widget)
  local text = widget:getText()
  if text:len() < 3 then
    StoreWindow.searchText.searchIcon:setEnabled(false)
    return
  end

  StoreWindow.searchText.searchIcon:setEnabled(true)
end

function onEnterSearch()
  local text = StoreWindow.searchText:getText()
  if text:len() < 3 then
    return
  end

  StoreWindow.searchText:setText('')
  g_game.requestStoreOffers(OPEN_SEARCH, text, 0);
end

function onStoreSearchOffers(categoryName, offers, unknow, reasons)
  Categories:setupSearch(false)
  Offers:configure(categoryName, offers, 0, 0, {}, '', reasons)
end

function openBaazarWindow()
  closeStore()
  g_client.setInputLockWidget(bazaarWindow)
  bazaarWindow:show(true)
  -- g_ui.setInputLockWidget(bazaarWindow)
  g_game.requestCharacterRequeriments()
end

-- Hireling name change
function onHirelingNameChange(hirelingId, creatureId)
  g_ui.setInputLockWidget(hirelingNameWindow)
  hirelingNameWindow:show()
  hirelingNameWindow:focus()
  hirelingNameWindow.cache = { hirelingId = hirelingId, creatureId = creatureId }
end

function onNameChangeText(widget)
  if not hirelingNameWindow then
    return
  end

  if #widget:getText() < 3 then
    hirelingNameWindow.contentPanel.ok:setEnabled(false)
  else
    hirelingNameWindow.contentPanel.ok:setEnabled(true)
  end
end

function onCloseHirelingNameWindow(okButton)
  local textField = hirelingNameWindow:recursiveGetChildById("hirelingName")
  if not textField then
    return true
  end

  if okButton then
    g_game.sendHirelingNameChange(textField:getText(), hirelingNameWindow.cache.creatureId,
      hirelingNameWindow.cache.hirelingId)
  end

  textField:clearText()
  g_ui.setInputLockWidget(nil)
  hirelingNameWindow.cache = {}
  hirelingNameWindow:hide()
end

function pixPlataform()
  transferError:destroy()
  transferError = nil
  g_client.setInputLockWidget(nil)

  g_game.requestPixPrice()
end

function choseBuyCoins()
  -- Pix is intentionally disabled in the client for now, so skip the payment-method
  -- modal and send the player straight to the website (same as the market's Get Coins).
  -- The Pix code below (pixPlataform / PixWindow / onRecvPix*) is kept for when it's
  -- re-enabled; just re-add the displayGeneralBox here to bring the chooser back.
  g_platform.openUrl(Services.Coins)
end

function createDonateRules()
  local rulesTextList = pixWindow:recursiveGetChildById('rules')
  if rulesTextList then
    rulesTextList:destroyChildren()

    -- Placeholder only. Selling anything in your store makes this a real consumer
    -- contract, so replace it with terms written for your own operation and law.
    local longText = "Extended Terms of Conditions for Paid Services\n\n" ..
        "PLACEHOLDER - no terms have been set for this server.\n\n" ..
        "If you run a server from this client and offer any paid service, you must " ..
        "replace this text with your own terms of service, naming the legal entity " ..
        "that operates the server, the applicable jurisdiction, and a working contact " ..
        "address for cancellations and refunds.\n\n" ..
        "The text lives in mods/game_store/store.lua, in createDonateRules()."

    local label = g_ui.createWidget('UILabel', rulesTextList)
    label:setText(longText)
    label:setColor(tovar('$var-text-cip-color'))
    label:setFont(tovar('$var-cip-font'))
    label:setTextWrap(true)
    label:setTextAutoResize(true)
    label:setMarginRight(15)
    label:setBackgroundColor('#414141')

    local rulesScrollBar = pixWindow:recursiveGetChildById('rulesScrollBar')
    if rulesScrollBar then
      rulesTextList:setVerticalScrollBar(rulesScrollBar)
    end
  end
end

function onCpfChange(widget, text)
  local donaterInfo = pixWindow:recursiveGetChildById('donaterInfo')
  local txt = string.gsub(text, "%D", "")
  donaterInfo:getChildById('next'):setEnabled(txt:len() == 11)
  widget:setText(format_cpf(text), false)
end

function onRecvPixData(pixList)
  if not pixWindow:isVisible() then
    pixWindow:show()
  end

  local donateRules = pixWindow:recursiveGetChildById('donateRules')
  local donaterInfo = pixWindow:recursiveGetChildById('donaterInfo')

  g_client.setInputLockWidget(pixWindow)
  pixWindow:recursiveGetChildById('donateRules'):setVisible(true)
  pixWindow:recursiveGetChildById('donaterInfo'):setVisible(false)
  pixWindow:recursiveGetChildById('qrCode'):setVisible(false)
  pixWindow:recursiveGetChildById('success'):setVisible(false)

  if donateRules:isVisible() then
    pixWindow:setHeight(520)
    pixWindow:setWidth(520)
    donateRules:getChildById('next'):setEnabled(false)
    donateRules:getChildById('termCondition'):setChecked(false)
    createDonateRules()
  end

  donateRules:getChildById('next').onClick = function()
    pixWindow:recursiveGetChildById('donateRules'):setVisible(false)
    pixWindow:recursiveGetChildById('donaterInfo'):setVisible(true)
    pixWindow:setHeight(220)
    pixWindow:setWidth(250)
  end

  local donaterCpf = donaterInfo:recursiveGetChildById('donaterCpf')

  local coinsValue = donaterInfo:recursiveGetChildById('coinsValue')
  coinsValue:clear()

  local sortedPixList = {}
  for coin, value in pairs(pixList) do
    table.insert(sortedPixList, { coin = coin, value = value })
  end

  table.sort(sortedPixList, function(a, b) return a.value < b.value end)

  for _, item in ipairs(sortedPixList) do
    coinsValue:addOption(string.format("%s Coins (R$ %.2f)", item.coin, item.value / 100),
      { coin = item.coin, value = item.value })
  end

  -- Keep this setting enabled until system completion
  -- Require user to fill in personal information

  donaterInfo:getChildById('next').onClick = function()
    pixWindow:setHeight(250)
    local data = coinsValue:getCurrentOption().data
    if data and data.coin then
      local cpf = string.gsub(donaterCpf:getText(), "%D", "")

      g_game.requestPixURL(data.coin, cpf)
      closePix()
    end
  end
end

function closePix()
  pixWindow:hide()
  g_client.setInputLockWidget(nil)
end

function onTermConditionChange(widgetId, value)
  pixWindow:recursiveGetChildById('donateRules'):getChildById('next'):setEnabled(value)
end

function onRecvPixURL(url, token)
  if not pixWindow:isVisible() then
    pixWindow:show()
  end
  pixWindow:recursiveGetChildById('donateRules'):setVisible(false)
  pixWindow:recursiveGetChildById('donaterInfo'):setVisible(false)
  pixWindow:recursiveGetChildById('qrCode'):setVisible(true)
  pixWindow:recursiveGetChildById('success'):setVisible(false)

  local qrCode = pixWindow:recursiveGetChildById('qrCode')
  qrCode:recursiveGetChildById('qrCodePanel').code:setImageSource('/images/store/store-flag-expires', false)

  HTTP.downloadImage(url, function(path, err)
    if err then
      if DEVELOPERMODE then
        g_logger.warning("HTTP error: " .. err .. " - " .. url)
      end
      return
    end
    local widget = qrCode:recursiveGetChildById('qrCodePanel').code
    if widget then
      widget:setImageSource(path, false)
    end
  end)

  qrCode:recursiveGetChildById('pixKey'):setText(token)
end

function copyCode()
  local qrCode = pixWindow:recursiveGetChildById('qrCode')
  local text = qrCode:recursiveGetChildById('pixKey'):getText()

  g_window.setClipboardText(text)
end

function onCharacterBazarCheckInformations(initialFee)
  Bazaar.initialFee = initialFee
end

function chooseTextMode(field, buttonId)
  local hiddenButton = pixWindow:recursiveGetChildById(buttonId)
  local fieldElement = pixWindow:recursiveGetChildById(field)

  local hidden = fieldElement:isTextHidden()
  isButtonPressed = not isButtonPressed

  if isButtonPressed then
    hiddenButton:setOn(true)
    fieldElement:setTextHidden(true)
  else
    hiddenButton:setOn(false)
    fieldElement:setTextHidden(false)
  end
end
