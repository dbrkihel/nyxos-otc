Communication = {
    useIgnoreList = true,
    useWhiteList = true,
    privateMessages = false,
    yelling = false,
    allowVIPs = false,
    ignoredPlayers = {},
    whitelistedPlayers = {},
    window = nil
}
Communication.__index = Communication

function Communication:setWindow(window)
    self.window = window
end

function Communication:loadSettings()
    self.whitelistedPlayers = {}
    self.ignoredPlayers = {}

    local ignoreNode = g_settings.getNode('IgnorePlayers')
    if ignoreNode then
      for _, player in pairs(ignoreNode) do
        table.insert(self.ignoredPlayers, player)
      end
    end

    local whitelistNode = g_settings.getNode('WhitelistedPlayers')
    if whitelistNode then
      for _, player in pairs(whitelistNode) do
        table.insert(self.whitelistedPlayers, player)
      end
    end

    self.useIgnoreList = g_settings.getBoolean('UseIgnoreList')
    self.useWhiteList = g_settings.getBoolean('UseWhiteList')
    self.privateMessages = g_settings.getBoolean('IgnorePrivateMessages')
    self.yelling = g_settings.getBoolean('IgnoreYelling')
    self.allowVIPs = g_settings.getBoolean('AllowVIPs')
end

function Communication:saveSettings()
    local tmpIgnoreList = {}
    local ignoredPlayers = self:getIgnoredPlayers()
    for i = 1, #ignoredPlayers do
      table.insert(tmpIgnoreList, ignoredPlayers[i])
    end

    local tmpWhiteList = {}
    local whitelistedPlayers = self:getWhitelistedPlayers()
    for i = 1, #whitelistedPlayers do
      table.insert(tmpWhiteList, whitelistedPlayers[i])
    end

    g_settings.set('UseIgnoreList', self.useIgnoreList)
    g_settings.set('UseWhiteList', self.useWhiteList)
    g_settings.set('IgnorePrivateMessages', self.privateMessages)
    g_settings.set('IgnoreYelling', self.yelling)
    g_settings.setNode('IgnorePlayers', tmpIgnoreList)
    g_settings.setNode('WhitelistedPlayers', tmpWhiteList)
end

function Communication:getIgnoredPlayers()
    return self.ignoredPlayers
end

function Communication:getWhitelistedPlayers()
    return self.whitelistedPlayers
end

function Communication:isUsingIgnoreList()
    return self.useIgnoreList
end

function Communication:isUsingWhiteList()
    return self.useWhiteList
end

function Communication:isIgnored(name)
    return table.find(self.ignoredPlayers, name, true)
end

function Communication:addIgnoredPlayer(name)
    if self:isIgnored(name) then return end
    table.insert(self.ignoredPlayers, name)
    self.useIgnoreList = true

    local tabName = (modules.game_console.getTabByName("Server Log") and "Server Log")
    local message = tr('You are now ignoring player %s.', name)
    modules.game_console.addText(message, MessageModes.ChannelManagement, tabName)
end

function Communication:removeIgnoredPlayer(name)
    table.removevalue(self.ignoredPlayers, name)

    local tabName = (modules.game_console.getTabByName("Server Log") and "Server Log")
    local message = tr('You are no longer ignoring player %s.', name)
    modules.game_console.addText(message, MessageModes.ChannelManagement, tabName)
end

function Communication:isWhitelisted(name)
    return table.find(self.whitelistedPlayers, name, true)
end

function Communication:addWhitelistedPlayer(name)
    if self:isWhitelisted(name) then return end
    table.insert(self.whitelistedPlayers, name)
end

function Communication:removeWhitelistedPlayer(name)
    table.removevalue(self.whitelistedPlayers, name)
end

function Communication:isIgnoringPrivate()
    return self.privateMessages
end

function Communication:isIgnoringYelling()
    return self.yelling
end

function Communication:isAllowingVIPs()
    return self.allowVIPs
end

function Communication:onClickIgnoreButton()
    if self.window then
        self.window:destroy()
        self.window = nil
    end

    doCreateCommunicationWindow()
    g_client.setInputLockWidget(self.window)

    local ignoreListPanel = self.window:getChildById('ignoreList')
    local whiteListPanel = self.window:getChildById('whiteList')
    self.window:insertLuaCall("onDestroy")
    self.window.onDestroy = function() g_client.setInputLockWidget(nil) self.window = nil end

    local useIgnoreListBox = self.window:recursiveGetChildById('checkboxUseIgnoreList')
    useIgnoreListBox:setChecked(self.useIgnoreList)
    local useWhiteListBox = self.window:recursiveGetChildById('checkboxUseWhiteList')
    useWhiteListBox:setChecked(self.useWhiteList)

    local removeIgnoreButton = self.window:getChildById('buttonIgnoreRemove')
    removeIgnoreButton:disable()
    ignoreListPanel.onChildFocusChange = function() removeIgnoreButton:enable() end
    removeIgnoreButton.onClick = function()
        local selection = ignoreListPanel:getFocusedChild()
        if selection then
            ignoreListPanel:removeChild(selection)
            selection:destroy()
        end
        removeIgnoreButton:disable()
    end

    local removeWhitelistButton = self.window:getChildById('buttonWhitelistRemove')
    removeWhitelistButton:disable()
    whiteListPanel.onChildFocusChange = function() removeWhitelistButton:enable() end
    removeWhitelistButton.onClick = function()
        local selection = whiteListPanel:getFocusedChild()
        if selection then
            whiteListPanel:removeChild(selection)
            selection:destroy()
        end
        removeWhitelistButton:disable()
    end

    local newlyIgnoredPlayers = {}
    local addIgnoreName = self.window:getChildById('ignoreNameEdit')
    local addIgnoreButton = self.window:getChildById('buttonIgnoreAdd')
    local addIgnoreFunction = function()
        local newEntry = addIgnoreName:getText()
        if newEntry == '' then
            return
        end
        if table.find(self:getIgnoredPlayers(), newEntry) then
            return
        end
        if table.find(newlyIgnoredPlayers, newEntry) then
            return
        end

        local label = g_ui.createWidget('IgnoreListLabel', ignoreListPanel)
        label:setText(newEntry)
        table.insert(newlyIgnoredPlayers, newEntry)
        addIgnoreName:setText('')
    end

    addIgnoreButton.onClick = addIgnoreFunction

    local newlyWhitelistedPlayers = {}
    local addWhitelistName = self.window:getChildById('whitelistNameEdit')
    local addWhitelistButton = self.window:getChildById('buttonWhitelistAdd')
    local addWhitelistFunction = function()
        local newEntry = addWhitelistName:getText()
        if newEntry == '' then
            return
        end
        if table.find(self:getWhitelistedPlayers(), newEntry) then
            return
        end
        if table.find(newlyWhitelistedPlayers, newEntry) then
            return
        end

        local label = g_ui.createWidget('WhiteListLabel', whiteListPanel)
        label:setText(newEntry)
        table.insert(newlyWhitelistedPlayers, newEntry)
        addWhitelistName:setText('')
    end

    addWhitelistButton.onClick = addWhitelistFunction
    self.window:insertLuaCall("onEnter")
    self.window.onEnter = function()
        if addWhitelistName:isFocused() then
            addWhitelistFunction()
        elseif addIgnoreName:isFocused() then
            addIgnoreFunction()
        end
    end

    local ignorePrivateMessageBox = self.window:recursiveGetChildById('checkboxIgnorePrivateMessages')
    ignorePrivateMessageBox:setChecked(self.privateMessages)
    local ignoreYellingBox = self.window:recursiveGetChildById('checkboxIgnoreYelling')
    ignoreYellingBox:setChecked(self.yelling)
    local allowVIPsBox = self.window:recursiveGetChildById('checkboxAllowVIPs')
    allowVIPsBox:setChecked(self.allowVIPs)

    local saveButton = self.window:recursiveGetChildById('buttonSave')
    saveButton.onClick = function()
        self.ignoredPlayers = {}
        for i = 1, ignoreListPanel:getChildCount() do
            self:addIgnoredPlayer(ignoreListPanel:getChildByIndex(i):getText())
        end

        self.whitelistedPlayers = {}
        for i = 1, whiteListPanel:getChildCount() do
            self:addWhitelistedPlayer(whiteListPanel:getChildByIndex(i):getText())
        end

        self.useIgnoreList = useIgnoreListBox:isChecked()
        self.useWhiteList = useWhiteListBox:isChecked()
        self.yelling = ignoreYellingBox:isChecked()
        self.privateMessages = ignorePrivateMessageBox:isChecked()
        self.allowVIPs = allowVIPsBox:isChecked()
        self.window:destroy()
    end

    local cancelButton = self.window:recursiveGetChildById('buttonCancel')
        cancelButton.onClick = function()
        g_client.setInputLockWidget(nil)
        self.window:destroy()
    end

    local ignoredPlayers = self:getIgnoredPlayers()
    for i = 1, #ignoredPlayers do
        local label = g_ui.createWidget('IgnoreListLabel', ignoreListPanel)
        label:setText(ignoredPlayers[i])
    end

    local whitelistedPlayers = self:getWhitelistedPlayers()
    for i = 1, #whitelistedPlayers do
        local label = g_ui.createWidget('WhiteListLabel', whiteListPanel)
        label:setText(whitelistedPlayers[i])
    end
end
