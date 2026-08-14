if not RealMap then
    RealMap = {
        loaded = false,
        settings = {},
    }
end

local flagToFilePath = {
  ["up"] = "data/images/game/minimap/flag18.png",
  ["flag"] = "data/images/game/minimap/flag9.png",
  ["skull"] = "data/images/game/minimap/flag12.png",
  ["crossmark"] = "data/images/game/minimap/flag4.png",
  ["star"] = "data/images/game/minimap/flag3.png",
  ["sword"] = "data/images/game/minimap/flag8.png",
  ["red up"] = "data/images/game/minimap/flag14.png",
  ["?"] = "data/images/game/minimap/flag1.png",
  ["checkmark"] = "data/images/game/minimap/flag0.png",
  ["red left"] = "data/images/game/minimap/flag17.png",
  ["red right"] = "data/images/game/minimap/flag16.png",
  ["!"] = "data/images/game/minimap/flag2.png",
  ["down"] = "data/images/game/minimap/flag19.png",
  ["mouth"] = "data/images/game/minimap/flag6.png",
  ["lock"] = "data/images/game/minimap/flag10.png",
  ["red down"] = "data/images/game/minimap/flag15.png",
  ["bag"] = "data/images/game/minimap/flag11.png",
  ["cross"] = "data/images/game/minimap/flag5.png",
  ["spear"] = "data/images/game/minimap/flag7.png",
  ["$"] = "data/images/game/minimap/flag13.png",
}

function RealMap.load()
    if RealMap.loaded then
        return
    end

    RealMap.settings = g_settings.getNode('game_minimap') or { ignoreFlag = {} }
    RealMap.setMarkers()
    RealMap.loaded = true
end

function RealMap.unload()
    g_realMinimap:clean()
end

function RealMap.setIgnoreFlag(position)
    RealMap.settings.ignoreFlag[position.x .. ',' .. position.y .. ',' .. position.z] = true

    local settings = {}
    settings.ignoreFlag = RealMap.settings.ignoreFlag
    g_settings.setNode('game_minimap', settings)
end

function RealMap.setRegions(minimapWidget, mainAreaId, regions)
  if not minimapWidget.selectedCity then
    minimapWidget.selectedCity = 0
    minimapWidget.selectedRegions = {}
  end

  for _, region in pairs(minimapWidget.selectedRegions) do
    g_realMinimap.disableRegion(region)
  end

  if minimapWidget.selectedCity == mainAreaId then
    minimapWidget:setSelectedCity(0)
    return
  end

  minimapWidget.selectedCity = mainAreaId
  for _, region in pairs(RealMap.regions) do
    if table.contains(regions, region.areaId) then
      local imageId = g_realMinimap.loadRegion(region.image, region.fromPos, 1, 0, 64, region.markedColor, region.areaId)
      g_realMinimap.enableRegion(imageId)
      minimapWidget.selectedRegions[#minimapWidget.selectedRegions + 1] = imageId
    end
  end

  modules.game_cyclopedia.MapCyclopedia.setImprovevedValue(mainAreaId)

  if minimapWidget.selectedRegion then
    g_realMinimap.disableRegion(minimapWidget.selectedRegion.id)
    minimapWidget.selectedRegion = nil
  end
end

function RealMap.setRegion(minimapWidget)
  for _, region in pairs(RealMap.regions) do
    local imageId = g_realMinimap.loadRegion(region.image, region.fromPos, 1, 0, 64, region.markedColor, region.areaId)

    minimapWidget:addCustomMouseEvent(MouseLeftButton, region.fromPos, region.toPos, function(self, mapPos, mousePos)
      if not self:hasClickedRegion(imageId, mapPos) then
        return false
      end

      minimapWidget:setSelectedCity(0)
      if minimapWidget.selectedCity and minimapWidget.selectedCity > 0 then
        for _, region in pairs(minimapWidget.selectedRegions) do
          g_realMinimap.disableRegion(region)
        end
        minimapWidget.selectedRegions = {}
        minimapWidget.selectedCity = 0
      end

      if minimapWidget.selectedRegion then
        if minimapWidget.selectedRegion.id == imageId then
          -- if it is the same, just remove it
          g_realMinimap.disableRegion(minimapWidget.selectedRegion.id)
          minimapWidget.selectedRegion = nil
          return true
        end

        -- if it is another one, then we disable it, and continue to enable
        -- a new one (keeping only one selected)
        g_realMinimap.disableRegion(minimapWidget.selectedRegion.id)
        minimapWidget.selectedRegion = nil
      end

      minimapWidget.selectedRegion = {region = region, id = imageId}
      g_realMinimap.enableRegion(imageId)

      local areaName, subAreaName = self:getAreaNameById(region.areaId)
      modules.game_cyclopedia.MapCyclopedia.onChangeArea(areaName, subAreaName)
      modules.game_cyclopedia.MapCyclopedia.setImprovevedValue(region.areaId)

      return true
    end)
  end
end

function RealMap.setCameraPosition(widget, pos)
  if not widget or not widget.setCameraPosition or not pos then
    return
  end
  widget:setCameraPosition(pos)
end

function RealMap.getCameraPosition(widget)
  if not widget or not widget.getCameraPosition then
    return nil
  end
  return widget:getCameraPosition()
end

function RealMap.setCrossPosition(widget, pos)
  if not widget or not widget.setCrossPosition or not pos then
    return
  end
  widget:setCrossPosition(pos)
end

function RealMap.hideCross(widget)
  widget:hideCross()
end

function RealMap.setZoom(widget, zoom)
  widget:setZoom(zoom)
end

function RealMap.setMarkers()
  local ignoreFlag = RealMap.settings.ignoreFlag and RealMap.settings.ignoreFlag or {}
  for _, markerInfo in pairs(RealMap.markers) do
    local filePath = flagToFilePath[markerInfo.icon]
    if filePath then
      -- g_realMinimap.addWidget(filePath, {width = 11, height = 11}, markerInfo.pos, markerInfo.description)
      if not ignoreFlag[markerInfo.pos.x .. ',' .. markerInfo.pos.y .. ',' .. markerInfo.pos.z] then
        g_minimap.addWidget(filePath, {width = 11, height = 11}, markerInfo.pos, markerInfo.description)
      end
    else
      print(markerInfo.icon, "not loaded!")
    end
  end
end

function RealMap.setUIMarkers(widget)
  -- ~5900 markers: each addWidget synchronously does g_ui.createWidget('MinimapFlag')
  -- + setImageSource + 2x centerInPosition anchors. Doing all in one frame freezes
  -- the client. Stream them in fixed-size batches over consecutive frames; each batch
  -- still collapses to a single layout pass via disable/enable bracketing.
  -- A token bumped per call cancels any in-flight load when the panel re-opens/destroys.
  widget._markerLoadToken = (widget._markerLoadToken or 0) + 1
  local token = widget._markerLoadToken

  local n = #RealMap.markers
  local i = 1
  local BATCH = 250

  local function step()
    if widget:isDestroyed() or widget._markerLoadToken ~= token then
      return
    end

    local layout = widget:getLayout()
    if layout then
      layout:disableUpdates()
    end

    local processed = 0
    while i <= n and processed < BATCH do
      local markerInfo = RealMap.markers[i]
      local filePath = flagToFilePath[markerInfo.icon]
      if filePath then
        widget:addWidget(filePath, {width = 11, height = 11}, markerInfo.pos, markerInfo.description)
      else
        print(markerInfo.icon, "not loaded!")
      end
      i = i + 1
      processed = processed + 1
    end

    if layout then
      layout:enableUpdates()
      layout:update()
    end

    if i <= n then
      scheduleEvent(step, 0)
    end
  end

  -- first batch runs inline so nearby flags appear immediately; rest streams in
  step()

  -- after the static automap flags, lay down the player's own marks. These are
  -- shared with game_minimap via the 'Minimap' settings node, so a flag created
  -- on either map shows up on both and survives a restart. addWidget already
  -- honours the active icon filter, so streamed user marks respect Show All.
  RealMap.setUserFlags(widget)
end

-- Personal marks live under the same 'Minimap' node game_minimap's UIMinimap
-- load/save use, keyed by "x,y,z" so each tile holds a single flag.
function RealMap.getUserFlags()
  local settings = g_settings.getNode('Minimap')
  if settings and settings.flags then
    return settings.flags
  end
  return {}
end

function RealMap.setUserFlags(widget)
  for _, flag in pairs(RealMap.getUserFlags()) do
    if flag.imagePath and flag.position then
      widget:addWidget(flag.imagePath, flag.imageSize or {width = 11, height = 11}, flag.position, flag.description)
    end
  end
end

-- game_minimap's UIMinimap:save() re-serialises this node as an array (keyed by
-- widgetId), while we key by "x,y,z". Both readers iterate with pairs(), so the
-- mixed schema is harmless, but writes must match by position value (not key) so
-- a flag stays unique per tile regardless of which map last saved it.
local function findFlagKeyByPos(flags, pos)
  for key, flag in pairs(flags) do
    local p = flag and flag.position
    if p and p.x == pos.x and p.y == pos.y and p.z == pos.z then
      return key
    end
  end
  return nil
end

function RealMap.saveUserFlag(imagePath, imageSize, pos, description)
  if not pos then return end
  local settings = g_settings.getNode('Minimap') or {}
  settings.flags = settings.flags or {}
  local key = findFlagKeyByPos(settings.flags, pos) or (pos.x .. ',' .. pos.y .. ',' .. pos.z)
  settings.flags[key] = {
    imagePath = imagePath,
    imageSize = imageSize,
    position = {x = pos.x, y = pos.y, z = pos.z},
    description = description,
  }
  g_settings.setNode('Minimap', settings)
end

function RealMap.removeUserFlag(pos)
  if not pos then return end
  local settings = g_settings.getNode('Minimap')
  if not settings or not settings.flags then return end
  local key = findFlagKeyByPos(settings.flags, pos)
  if key then
    settings.flags[key] = nil
    g_settings.setNode('Minimap', settings)
  end
end

function RealMap.setLevelSeparator(widget, levelSeparator)
  widget:setLevelSeparator(levelSeparator)
end
