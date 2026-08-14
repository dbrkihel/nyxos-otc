function Item:setInCorpse(value)
	self.isInCorpse = value
end

function Item:inCorpse()
	return self.isInCorpse
end

function getItemServerName(itemId)
    local thing = g_things.getThingType(itemId, ThingCategoryItem)
    if not thing then
        return ""
    end

    local moneyNames = {
      [3031] = "gold coin",
      [3035] = "platinum coin",
      [3043] = "crystal coin"
    }

    if moneyNames[itemId] then
      return string.capitalize(moneyNames[itemId])
    end

    -- getMarketData() can be nil for items with no market entry; indexing .name on
    -- it threw "attempt to index a nil value". Guard it.
    local marketData = thing:getMarketData()
    if marketData and marketData.name and marketData.name ~= '' then
      return string.capitalize(marketData.name)
    end
    return ""
end

function getItemCategory(itemId)
    local thing = g_things.getThingType(itemId, ThingCategoryItem)
    if not thing then
        return 0
    end

    return thing:getMarketData().category or 0
end

function getItemCategoryBySlot(itemId)
    local thing = g_things.getThingType(itemId, ThingCategoryItem)
    if not thing then
        return -1
    end

    local category = thing:getMarketData().category
    if not category then
        return -1
    end

    local leftHand = {MarketCategory.Axes, Clubs, DistanceWeapons, Swords, WandsRods}
    if category == MarketCategory.HelmetsHats then
        return CONST_SLOT_HEAD
    elseif category == MarketCategory.Armors then
        return CONST_SLOT_ARMOR
    elseif category == MarketCategory.Legs then
        return CONST_SLOT_LEGS
    elseif category == MarketCategory.Boots then
        return CONST_SLOT_FEET
    elseif category >= MarketCategory.Axes and category <= MarketCategory.WandsRods or category == MarketCategory.FistWeapons then
        return CONST_SLOT_LEFT
    end

    return -1
end

function isCorpse(itemId)
    local thing = g_things.getThingType(itemId, ThingCategoryItem)
    if not thing then
        return false
    end

    local corpse = false
    if thing.isCorpse then
        corpse = thing:isCorpse()
    elseif thing.isLyingCorpse then
        corpse = thing:isLyingCorpse()
    end

    local playerCorpse = false
    if thing.isPlayerCorpse then
        playerCorpse = thing:isPlayerCorpse()
    end

    return corpse and not playerCorpse
end

function getItemColor(itemId)
    local item = Item.create(itemId, 1)
    if not item then
        return "#F0F0F0"
    end

    local value = item:getPriceValue()
    if value >= 1000000 then
        return "#F0F000"
    elseif value >= 100000 then
        return "#FF68FF"
    elseif value >= 10000 then
        return "#20A0FF"
    elseif value >= 1000 then
        return "#00F000"
    elseif value >= 1 then
        return "#AAAAAA"
    end

    return "#F0F0F0"
end
