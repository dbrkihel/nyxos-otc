function Tile:hasItem(itemId)
    for _, item in pairs(self:getItems()) do
        if item:getId() == itemId then
            return true
        end
    end
    return false
end
