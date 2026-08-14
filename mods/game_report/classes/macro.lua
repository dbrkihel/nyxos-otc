ReportMacroVar = {}
ReportMacroVar.playerId = 0
ReportMacroVar.playerName = ''
ReportMacroVar.ruleIndex = 0
ReportMacroVar.ruleText = ''
ReportMacroVar.reportComment = ''

function doReportMacro(playerId, playerName)
    local lastReportTime = g_settings.getNumber("lastReportTime", 0)
    local reportCooldown = 10 * 60

    if os.time() - lastReportTime < reportCooldown then
        local timeLeft = math.floor((reportCooldown - (os.time() - lastReportTime)) / 60)
        modules.game_textmessage.displayFailureMessage(tr("You must wait " .. timeLeft .. " minutes to report again."))
        return
    end

    ReportMacroVar.playerId = playerId
    ReportMacroVar.playerName = playerName
    ReportMacroVar.ruleIndex = 13
    ReportMacroVar.ruleText = ''
    ReportMacroVar.reportComment = ''
    reportWindow:show()
    g_client.setInputLockWidget(reportWindow)
    stepOne:setVisible(true)
    stepTwoName:setVisible(false)
    stepTwoStatement:setVisible(false)
    reportTwoSoftware:setVisible(false)
    stepThree:setVisible(false)
    stepThreeBot:setVisible(false)

    local ruleList = stepOne:recursiveGetChildById('rulesList')

    ruleList:destroyChildren()
    for ruleId, information in pairs(ReportSystemMacro) do
        if ruleId == '13' then
            for rule, _ in pairs(information) do
                ruleId = tonumber(ruleId)
                local label = g_ui.createWidget('RuleLabel', ruleList)
                label:setId(ruleId)
                label:setText(rule)
                label.color = (ruleId % 2 and '$var-textlist-even' or '$var-textlist-odd')
                label:setBackgroundColor(label.color)
                if ruleId == 13 then
                    label:focus()
                end
            end
        end
    end


    stepOne:recursiveGetChildById('nextButton').onClick = setReportTwoSoftware
end

function onRuleFocusChange(widget)
    widget:setBackgroundColor(widget:isFocused() and "$var-textlist-selected" or widget.color)

    ReportMacroVar.ruleText = widget:getText()
    ReportMacroVar.ruleIndex = tonumber(widget:getId())
    local rules = ReportSystemMacro[widget:getId()]
    local description = rules[widget:getText()]


    stepOne:recursiveGetChildById('ruleInfoList'):setText(description)
end

function setReportTwoSoftware()
    stepOne:setVisible(false)
    stepTwoName:setVisible(false)
    stepTwoStatement:setVisible(false)
    reportTwoSoftware:setVisible(true)
    stepThree:setVisible(false)
    stepThreeBot:setVisible(false)

    reportTwoSoftware:recursiveGetChildById('playerDetailsLabel'):setText(string.format('Add details on the report of "%s".',ReportMacroVar.playerName ))
    reportTwoSoftware:recursiveGetChildById('statementList'):setText('')
    reportTwoSoftware:recursiveGetChildById('prevButton').onClick = function() doReportMacro(ReportMacroVar.playerId, ReportMacroVar.playerName) end
    reportTwoSoftware:recursiveGetChildById('nextButton').onClick = setThreeMacro
end

function onReportTextChange(text)
    reportTwoSoftware:recursiveGetChildById('charactersLeft'):setText(string.format('%d characters left', 300 - #text))
    reportTwoSoftware:recursiveGetChildById('nextButton'):setEnabled(#text > 0)
    ReportMacroVar.reportComment = text
end

function setThreeMacro()
    stepOne:setVisible(false)
    stepTwoName:setVisible(false)
    stepTwoStatement:setVisible(false)
    reportTwoSoftware:setVisible(false)
    stepThree:setVisible(false)
    stepThreeBot:setVisible(true)

    stepThreeBot:recursiveGetChildById('name'):setText(ReportMacroVar.playerName)
    stepThreeBot:recursiveGetChildById('reason'):setText(ReportMacroVar.ruleText)
    stepThreeBot:recursiveGetChildById('commentList'):setText(ReportMacroVar.reportComment)


    -- send to server
    stepThreeBot:recursiveGetChildById('nextButton').onClick = function()
        g_game.reportRuleViolation(REPORT_TYPE_BOT, ReportMacroVar.ruleIndex, ReportMacroVar.playerName, ReportMacroVar.reportComment, '', 0)
        g_settings.set("lastReportTime", os.time())
        modules.game_report.hide()
        g_client.setInputLockWidget(nil)
    end
end
