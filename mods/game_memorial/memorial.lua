memorialWindow = nil

goldenInfo = nil
royalInfo = nil

contentTextList = nil
goldenButton = nil
royalButton = nil

function init()
  memorialWindow = g_ui.displayUI('memorial')
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
	onOutfitMemorial = onOutfitMemorial
  })

  contentTextList = memorialWindow:recursiveGetChildById('contentTextList')

  goldenButton = memorialWindow:recursiveGetChildById("goldenOutfitButton")
  royalButton = memorialWindow:recursiveGetChildById("royalCostumeButton")

  memorialWindow:hide()
end

function terminate()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
	onOutfitMemorial = onOutfitMemorial
  })

  memorialWindow:destroy()
end

function closeMemorial()
  memorialWindow:hide()
  g_client.setInputLockWidget(nil)
end

function online()
  closeMemorial()
end

function offline()
  memorialWindow:hide()
  g_client.setInputLockWidget(nil)
end

function onOutfitMemorial(golden, royal)
	goldenInfo = golden
	royalInfo = royal
	memorialWindow:show(true)
	memorialWindow:raise()
	memorialWindow:focus()
	g_client.setInputLockWidget(memorialWindow)
	selectGoldenPanel()
end

function selectGoldenPanel()
	local spacer = "          "
	local header = "The Golden Outfit has not been acquired by anyone yet."
	local content = ""
	if #goldenInfo.baseOutfit > 0 or #goldenInfo.firstAddon > 0 or #goldenInfo.secondAddon > 0 then
		header = "The following characters have spent a fortune on a Golden Outfit:"
	end

	contentTextList:destroyChildren()
	local label = g_ui.createWidget('MEListLabel', contentTextList)
    label:setText(header)
	label:setMarginTop(4)

	-- Full outfit users
	if #goldenInfo.secondAddon > 0 then
		content = tr("Full Outfit for %s gold:", formatMoney(goldenInfo.secondPrice, "."))
		label = g_ui.createWidget('MEListLabel', contentTextList)
		label:setText(content)
		label:setMarginTop(11)

		for _, k in pairs(goldenInfo.secondAddon) do
			content = tr("%s- %s", spacer, k.name)
			label = g_ui.createWidget('MEListLabel', contentTextList)
			label:setText(content)
			label:setMarginTop(-2)
		end
	end

	-- One addon users
	if #goldenInfo.firstAddon > 0 then
		content = tr("With One Addon for %s gold:", formatMoney(goldenInfo.firstPrice, "."))
		label = g_ui.createWidget('MEListLabel', contentTextList)
		label:setText(content)
		label:setMarginTop(11)

		for _, k in pairs(goldenInfo.firstAddon) do
			content = tr("%s- %s", spacer, k.name)
			label = g_ui.createWidget('MEListLabel', contentTextList)
			label:setText(content)
			label:setMarginTop(-2)
		end
	end

	-- Base outfit users
	if #goldenInfo.baseOutfit > 0 then
		content = tr("Basic Outfit for %s gold:", formatMoney(goldenInfo.basePrice, "."))
		label = g_ui.createWidget('MEListLabel', contentTextList)
		label:setText(content)
		label:setMarginTop(11)

		for _, k in pairs(goldenInfo.baseOutfit) do
			content = tr("%s- %s", spacer, k.name)
			label = g_ui.createWidget('MEListLabel', contentTextList)
			label:setText(content)
			label:setMarginTop(-2)
		end
	end

	goldenButton:setChecked(true)
	royalButton:setChecked(false)
end

function selectRoyalPanel()
	local spacer = "          "
	local header = "The Royal Costume has not been acquired by anyone yet"
	local content = ""
	if #royalInfo.baseOutfit > 0 or #royalInfo.firstAddon > 0 or #royalInfo.secondAddon > 0 then
		header = "The following characters have spent a fortune on a Royal Costume:"
	end

	contentTextList:destroyChildren()
	local label = g_ui.createWidget('MEListLabel', contentTextList)
    label:setText(header)
	label:setMarginTop(4)

	-- Full outfit users
	if #royalInfo.secondAddon > 0 then
		content = tr("Full Outfit for %s Silver Tokens and %s Gold Tokens:", formatMoney(royalInfo.secondSilver, "."), formatMoney(royalInfo.secondGold, "."))
		label = g_ui.createWidget('MEListLabel', contentTextList)
		label:setText(content)
		label:setMarginTop(11)

		for _, k in pairs(royalInfo.secondAddon) do
			content = tr("%s- %s", spacer, k.name)
			label = g_ui.createWidget('MEListLabel', contentTextList)
			label:setText(content)
			label:setMarginTop(-2)
		end
	end

	-- One addon users
	if #royalInfo.firstAddon > 0 then
		content = tr("With One Addon for %s Silver Tokens and %s Gold Tokens:", formatMoney(royalInfo.firstSilver, "."), formatMoney(royalInfo.firstGold, "."))
		label = g_ui.createWidget('MEListLabel', contentTextList)
		label:setText(content)
		label:setMarginTop(11)

		for _, k in pairs(royalInfo.firstAddon) do
			content = tr("%s- %s", spacer, k.name)
			label = g_ui.createWidget('MEListLabel', contentTextList)
			label:setText(content)
			label:setMarginTop(-2)
		end
	end

	-- Base outfit users
	if #royalInfo.baseOutfit > 0 then
		content = tr("Basic Outfit for %s Silver Tokens and %s Gold Tokens:", formatMoney(royalInfo.baseSilver, "."), formatMoney(royalInfo.baseGold, "."))
		label = g_ui.createWidget('MEListLabel', contentTextList)
		label:setText(content)
		label:setMarginTop(11)

		for _, k in pairs(royalInfo.baseOutfit) do
			content = tr("%s- %s", spacer, k.name)
			label = g_ui.createWidget('MEListLabel', contentTextList)
			label:setText(content)
			label:setMarginTop(-2)
		end
	end

	royalButton:setChecked(true)
	goldenButton:setChecked(false)
end
