if not Categories then
	Categories = {}
	Categories.__index = Categories

	Categories.categoryTable = {}
	Categories.buttonSize = 20
	Categories.selectButton = nil
	Categories.selectTreeItem = nil
	Categories.name = ''
end

-- Set a category button's label, ellipsizing it to the button width so long names
-- (e.g. "Packages and Bundles") no longer spill out of the container. Reserves room
-- on the right for the dropdown arrow when the category has sub-categories.
local CATEGORY_TEXT_LEFT = 15
local function ellipsizeCategory(label, name, hasArrow)
	local button = label:getParent()
	local btnW = button:getWidth()
	if not btnW or btnW <= 0 then
		btnW = 170
	end
	local shown = ellipsize_text(label, name, btnW - CATEGORY_TEXT_LEFT - (hasArrow and 24 or 14))
	-- Keep the full name reachable on hover when it had to be cut.
	if shown ~= name then
		button:setTooltip(name)
	end
end


function Categories:configure(categories)
	local categoryPanel = StoreWindow.categories
	for i, child in pairs(categoryPanel:getChildren()) do
		child:destroy()
	end

	Categories.categoryTable = {
		[0] = {name = "Home", icon = "/images/store/icon-store-home"},
	}

	local createdCategory = {"Home"}

	for i, category in pairs(categories) do
		if #category.parent == 0 then
			for i = 1, #Categories.categoryTable do
				if Categories.categoryTable[i].name == category.name then
					Categories.categoryTable[i].icon = category.icon
					break
				end
			end

			if not table.contains(createdCategory, category.name) then
				createdCategory[#createdCategory + 1] = category.name
				Categories.categoryTable[#Categories.categoryTable + 1] = {name = category.name, icon = category.icon}
			end
		else
			local created = false
			for i = 1, #Categories.categoryTable do
				if Categories.categoryTable[i].name == category.parent then
					if not Categories.categoryTable[i].childs then
						Categories.categoryTable[i].childs = {}
					end

					if not table.contains(createdCategory, category.name) then
						createdCategory[#createdCategory + 1] = category.name
						Categories.categoryTable[i].childs[#Categories.categoryTable[i].childs + 1] = {name = category.name, icon = category.icon}
					end
					created = true
				end
			end
		end
	end

	Categories.categoryTable[#Categories.categoryTable + 1] = {name = "Search", icon = "/images/store/icon-store-search-result", disabled = true}

	for id, cat in pairs(Categories.categoryTable) do
		local widget = g_ui.createWidget('TreeItem', categoryPanel)
		widget:setId(id)
		ellipsizeCategory(widget.mainButton.text, cat.name, cat.childs and #cat.childs > 0)
		if cat.childs and #cat.childs > 0 then
			widget.mainButton.scroll:setVisible(true)
		else
			widget.mainButton.scroll:setHeight(0)
		end

		if cat.disabled then
			widget:setVisible(false)
		end

		if g_resources.fileExists(cat.icon) or table.contains({"Home", "Search"}, cat.name) then
			widget.mainButton.icon:setImageSource(cat.icon)
		else
			local currentWidget = widget.mainButton.icon
			currentWidget.currentImageRequest = Store.currentRequest
			Store.imageRequests[Store.currentRequest] = currentWidget
			Store.currentRequest = Store.currentRequest + 1

			currentWidget:insertLuaCall("onDestroy")
			currentWidget.onDestroy = function()
				Store.imageRequests[currentWidget.currentImageRequest] = nil
			end

			Store:downloadImage(currentWidget.currentImageRequest, "13/"..cat.icon)
		end

		widget.mainButton.onClick = function()
			Categories:onSelectCategory(widget.mainButton)
		end
	end
end


function Categories:onSelectCategory(widget, name)
	if not widget or not widget:getParent() then
		return
	end
	local id = tonumber(widget:getParent():getId())
	local category = Categories.categoryTable[id]
	if not category then
		return
	end

	if Categories.selectTreeItem == widget then
		return true
	end

	if Categories.selectTreeItem and Categories.selectTreeItem:getParent() then
		Categories.selectTreeItem:getParent():setHeight(Categories.buttonSize)
		Categories.selectTreeItem:getParent():getChildById('panel'):setVisible(false)
		Categories.selectTreeItem:getParent():getChildById('panel'):setHeight(0)
		for _, child in pairs(Categories.selectTreeItem:getParent():getChildById('panel'):getChildren()) do
			child:destroy()
		end

		Categories.selectTreeItem = nil
	end

	local printed = false
	local selectedButton = nil
	local isFirstButton = true

	local thisParent = widget:getParent()
	if category.childs and thisParent then
		thisParent:setHeight(Categories.buttonSize+(#category.childs*Categories.buttonSize))
		if #category.childs < 3 then
			thisParent:getChildById('panel'):setHeight((#category.childs*Categories.buttonSize) + 2)
		else
			thisParent:getChildById('panel'):setHeight((#category.childs*Categories.buttonSize) + 1)
		end
		thisParent:getChildById('panel'):setVisible(true)
		thisParent:getChildById('arrow'):setVisible(true)

		for index, child in ipairs(category.childs) do
			local newWidget = g_ui.createWidget('TreeButton', widget:getParent():getChildById('panel'))
			local widgetId = 'TreeButton' .. tostring(index)
			newWidget:setId(widgetId)

			local currentWidget = newWidget.icon
			currentWidget.currentImageRequest = Store.currentRequest
			Store.imageRequests[Store.currentRequest] = currentWidget
			Store.currentRequest = Store.currentRequest + 1

			currentWidget:insertLuaCall("onDestroy")
			currentWidget.onDestroy = function()
				Store.imageRequests[currentWidget.currentImageRequest] = nil
			end

			Store:downloadImage(currentWidget.currentImageRequest, "13/"..child.icon)

			local pos = (index - 1) * 20 + (Categories.buttonSize / 3)
			if not name and not printed then
				printed = true
				thisParent.arrow:setMarginTop(pos)
			end

			newWidget.onClick = function()
				if selectedButton == newWidget then
					return true
				end

				if selectedButton then
					selectedButton:setOn(false)
					selectedButton.text:setColor("$var-text-cip-color")
				end
				selectedButton = newWidget
				selectedButton:setOn(true)
				selectedButton.text:setColor("$var-text-cip-color-highlight")
				thisParent.arrow:setMarginTop(pos)
				g_game.requestStoreOffers(OPEN_CATEGORY, child.name, 0)
			end
			newWidget:getChildById('text'):setText(short_text(child.name, 16))
			if isFirstButton then
				isFirstButton = false
				selectedButton = newWidget
				selectedButton:setOn(true)
				selectedButton.text:setColor("$var-text-cip-color-highlight")
			end
		end
	elseif widget then
		widget.scroll:setHeight(0)
	end

	if not name then
		g_game.doThing(false)
		if category.name == "Home" then
			g_game.requestStoreOffers(OPEN_HOME, "", 0)
		elseif category.childs and #category.childs > 0 then
			g_game.requestStoreOffers(OPEN_CATEGORY, category.childs[1].name, 0)
		else
			g_game.requestStoreOffers(OPEN_CATEGORY, category.name, 0)
		end
		g_game.doThing(true)
	end
	Categories.selectTreeItem = widget
	Categories.name = name
end

function Categories:setupSearch(disabled)
	Categories.categoryTable[#Categories.categoryTable].disabled = disabled

	local categoryPanel = StoreWindow.categories
	for i, child in pairs(categoryPanel:getChildren()) do
		child:destroy()
	end
	for id, cat in pairs(Categories.categoryTable) do
		local widget = g_ui.createWidget('TreeItem', categoryPanel)
		widget:setId(id)
		ellipsizeCategory(widget.mainButton.text, cat.name, cat.childs and #cat.childs > 0)
		if cat.childs and #cat.childs > 0 then
			widget.mainButton.scroll:setVisible(true)
		else
			widget.mainButton.scroll:setHeight(0)
		end

		if cat.disabled then
			widget:setVisible(false)
		end

		if g_resources.fileExists(cat.icon) or table.contains({"Home", "Search"}, cat.name) then
			widget.mainButton.icon:setImageSource(cat.icon)
		else
			local currentWidget = widget.mainButton.icon
			currentWidget.currentImageRequest = Store.currentRequest
			Store.imageRequests[Store.currentRequest] = currentWidget
			Store.currentRequest = Store.currentRequest + 1

			currentWidget:insertLuaCall("onDestroy")
			currentWidget.onDestroy = function()
				Store.imageRequests[currentWidget.currentImageRequest] = nil
			end

			Store:downloadImage(currentWidget.currentImageRequest, "13/"..cat.icon)
		end

		widget.mainButton.onClick = function()
			Categories:onSelectCategory(widget.mainButton)
		end
	end
end
