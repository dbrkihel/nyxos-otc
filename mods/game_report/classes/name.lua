ReportNameVar = {}
ReportNameVar.playerName = ''
ReportNameVar.ruleIndex = 0
ReportNameVar.ruleText = ''
ReportNameVar.reportTranslate = ''
ReportNameVar.reportComment = ''

function doReportName(playerName)
    local lastReportTime = g_settings.getNumber("lastReportTime", 0)
    local reportCooldown = 10 * 60

    if os.time() - lastReportTime < reportCooldown then
        local timeLeft = math.floor((reportCooldown - (os.time() - lastReportTime)) / 60)
        modules.game_textmessage.displayFailureMessage(tr("You must wait " .. timeLeft .. " minutes to report again."))
        return
    end

    ReportNameVar.playerName = playerName
    ReportNameVar.ruleIndex = 13
    ReportNameVar.ruleText = ''
    ReportNameVar.reportTranslate = ''
    ReportNameVar.reportComment = ''
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
    local index = 0
    for ruleId, _ in pairs(ReportSystemName) do
        index = index + 1
        local information = ReportSystemName[ruleId]
        for rule, _ in pairs(information) do
            local label = g_ui.createWidget('RuleLabel', ruleList)
            label:setId(ruleId)
            label:setText(rule)
            label.color = (index % 2 == 0 and '$var-textlist-even' or '$var-textlist-odd')
            label:setBackgroundColor(label.color)
            label.onFocusChange = onRuleNameFocusChange
            if ruleId == 1 then
                label:focus()
            end
        end
    end


    stepOne:recursiveGetChildById('nextButton').onClick = setReportTwoName
end

function onRuleNameFocusChange(widget)
    widget:setBackgroundColor(widget:isFocused() and "$var-textlist-selected" or widget.color)

    ReportNameVar.ruleText = widget:getText()
    ReportNameVar.ruleIndex = tonumber(widget:getId())
    local rules = ReportSystemName[widget:getId()]
    local description = rules[widget:getText()]


    stepOne:recursiveGetChildById('ruleInfoList'):setText(description .. "\n")
end

function setReportTwoName()
    stepOne:setVisible(false)
    stepTwoName:setVisible(true)
    stepTwoStatement:setVisible(false)
    reportTwoSoftware:setVisible(false)
    stepThree:setVisible(false)
    stepThreeBot:setVisible(false)

    stepTwoName:recursiveGetChildById('playerDetailsLabel'):setText(string.format('Add details on the report of "%s".',ReportNameVar.playerName ))
    stepTwoName:recursiveGetChildById('detailsList'):setText('')
    stepTwoName:recursiveGetChildById('translateList'):setText('')
    stepTwoName:recursiveGetChildById('prevButton').onClick = function() doReportName(ReportNameVar.playerName) end
    stepTwoName:recursiveGetChildById('nextButton').onClick = setReportThreeName
end

function onReportNameTranslateTextChange(text)
    stepTwoName:recursiveGetChildById('charactersLeft'):setText(string.format('%d characters left', 300 - #text))
    ReportNameVar.reportTranslate = text
end
function onReportNameDetailTextChange(text)
    stepTwoName:recursiveGetChildById('detailsInfoLabel'):setText((#text > 0 and string.format('%d characters left', 300 - #text) or 'Please enter a comment.' ))
    stepTwoName:recursiveGetChildById('detailsInfoLabel'):setColor((#text > 0 and '$var-text-cip-color' or '$var-text-cip-store-red'))
    stepTwoName:recursiveGetChildById('nextButton'):setEnabled(#text > 0)
    ReportNameVar.reportComment = text
end

function setReportThreeName()
    stepOne:setVisible(false)
    stepTwoName:setVisible(false)
    stepTwoStatement:setVisible(false)
    reportTwoSoftware:setVisible(false)
    stepThree:setVisible(true)
    stepThreeBot:setVisible(false)

    stepThree:recursiveGetChildById('name'):setText(ReportNameVar.playerName)
    stepThree:recursiveGetChildById('reason'):setText(ReportNameVar.ruleText)
    stepThree:recursiveGetChildById('translationList'):setText(ReportNameVar.reportTranslate)
    stepThree:recursiveGetChildById('commentList'):setText(ReportNameVar.reportComment)

    stepThree:recursiveGetChildById('prevButton').onClick = setReportTwoName

    -- send to server
    stepThree:recursiveGetChildById('nextButton').onClick = function()
        g_game.reportRuleViolation(REPORT_TYPE_NAME, ReportNameVar.ruleIndex, ReportNameVar.playerName, ReportNameVar.reportComment, ReportNameVar.reportTranslate, 0)
        g_settings.set("lastReportTime", os.time())
        modules.game_report.hide()
        g_client.setInputLockWidget(nil)
    end
end
