ReportStatementVar = {}
ReportStatementVar.statementId = 0
ReportStatementVar.playerName = ''
ReportStatementVar.ruleIndex = 0
ReportStatementVar.ruleText = ''
ReportStatementVar.reportTranslate = ''
ReportStatementVar.reportComment = ''
ReportStatementVar.message = ''

function doReportStatement(statementId, playerName, message)
    local lastReportTime = g_settings.getNumber("lastReportTime", 0)
    local reportCooldown = 10 * 60

    if os.time() - lastReportTime < reportCooldown then
        local timeLeft = math.floor((reportCooldown - (os.time() - lastReportTime)) / 60)
        modules.game_textmessage.displayFailureMessage(tr("You must wait " .. timeLeft .. " minutes to report again."))
        return
    end

    ReportStatementVar.statementId = statementId
    ReportStatementVar.playerName = playerName
    ReportStatementVar.message = message
    ReportStatementVar.ruleIndex = 13
    ReportStatementVar.ruleText = ''
    ReportStatementVar.reportTranslate = ''
    ReportStatementVar.reportComment = ''
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
    for ruleId, _ in pairs(ReportSystemStatement) do
        local information = ReportSystemStatement[ruleId]
        index = index + 1
        for rule, _ in pairs(information) do
            local label = g_ui.createWidget('RuleLabel', ruleList)
            label:setId(ruleId)
            label:setText(rule)
            label.color = (index % 2 == 0 and '$var-textlist-even' or '$var-textlist-odd')
            label:setBackgroundColor(label.color)
            label.onFocusChange = onRuleStatementFocusChange
            if ruleId == 1 then
                label:focus()
            end
        end
    end


    stepOne:recursiveGetChildById('nextButton').onClick = setReportTwoStatement
end

function onRuleStatementFocusChange(widget)
    widget:setBackgroundColor(widget:isFocused() and "$var-textlist-selected" or widget.color)

    ReportStatementVar.ruleText = widget:getText()
    ReportStatementVar.ruleIndex = tonumber(widget:getId())
    local rules = ReportSystemStatement[widget:getId()]
    local description = rules[widget:getText()]


    stepOne:recursiveGetChildById('ruleInfoList'):setText(description .. "\n")
end

function setReportTwoStatement()
    stepOne:setVisible(false)
    stepTwoName:setVisible(false)
    stepTwoStatement:setVisible(true)
    reportTwoSoftware:setVisible(false)
    stepThree:setVisible(false)
    stepThreeBot:setVisible(false)

    stepTwoStatement:recursiveGetChildById('playerDetailsLabel'):setText(string.format('Add details on the report of "%s".',ReportStatementVar.playerName ))
    stepTwoStatement:recursiveGetChildById('statementList'):setText(ReportStatementVar.message)
    stepTwoStatement:recursiveGetChildById('detailsList'):setText('')
    stepTwoStatement:recursiveGetChildById('translateList'):setText('')
    stepTwoStatement:recursiveGetChildById('prevButton').onClick = function() doReportStatement(ReportStatementVar.statementId, ReportStatementVar.playerName, ReportStatementVar.message) end
    stepTwoStatement:recursiveGetChildById('nextButton').onClick = setReportThreeStatement
end

function onReportStatementTranslateTextChange(text)
    stepTwoStatement:recursiveGetChildById('charactersLeft'):setText(string.format('%d characters left', 300 - #text))
    ReportStatementVar.reportTranslate = text
end
function onReportStatementDetailTextChange(text)
    stepTwoStatement:recursiveGetChildById('detailsInfoLabel'):setText((#text > 0 and string.format('%d characters left', 300 - #text) or 'Please enter a comment.' ))
    stepTwoStatement:recursiveGetChildById('detailsInfoLabel'):setColor((#text > 0 and '$var-text-cip-color' or '$var-text-cip-store-red'))
    stepTwoStatement:recursiveGetChildById('nextButton'):setEnabled(#text > 0)
    ReportStatementVar.reportComment = text
end

function setReportThreeStatement()
    stepOne:setVisible(false)
    stepTwoName:setVisible(false)
    stepTwoStatement:setVisible(false)
    reportTwoSoftware:setVisible(false)
    stepThree:setVisible(true)
    stepThreeBot:setVisible(false)

    stepThree:recursiveGetChildById('name'):setText(ReportStatementVar.playerName)
    stepThree:recursiveGetChildById('reason'):setText(ReportStatementVar.ruleText)
    stepThree:recursiveGetChildById('translationList'):setText(ReportStatementVar.reportTranslate)
    stepThree:recursiveGetChildById('commentList'):setText(ReportStatementVar.reportComment)

    stepThree:recursiveGetChildById('prevButton').onClick = setReportTwoStatement

    -- send to server
    stepThree:recursiveGetChildById('nextButton').onClick = function()
        g_game.reportRuleViolation(REPORT_TYPE_STATEMENT, ReportStatementVar.ruleIndex, ReportStatementVar.playerName, ReportStatementVar.reportComment, ReportStatementVar.reportTranslate, ReportStatementVar.statementId)
        g_settings.set("lastReportTime", os.time())
        modules.game_report.hide()
        g_client.setInputLockWidget(nil)
    end
end
