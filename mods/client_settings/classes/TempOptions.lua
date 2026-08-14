if not TempOptions then
    TempOptions = {
        options = {}
    }
    TempOptions.__index = TempOptions
end

function TempOptions:setOption(key, value)
    local option = GameOptions:getDataSet(key)
    -- Guard against checkboxes whose id has no dataset.lua entry (e.g. the legacy
    -- screenshotCombo control). Without this, indexing a nil option below threw a
    -- Lua error the moment such a control was toggled.
    if not option then
        return
    end
    if option.tempApply and not option.tempApply(value) then
        g_logger.info("Failed to apply tmp option: " .. key)
        return
    end
    self.options[key] = value
end

function TempOptions:getOption(key)
    return self.options[key]
end

function TempOptions:resetOption(key)
    self.options[key] = nil
end

function TempOptions:resetAllOptions()
    self.options = {}
end

function TempOptions:applyOptions()
    for key, value in pairs(self.options) do
        GameOptions:setOption(key, value)
    end

    self:resetAllOptions()
end
