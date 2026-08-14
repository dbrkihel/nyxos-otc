minimapWidget = nil
minimapButton = nil
minimapWindow = nil
fullmapView = false
loaded = false
oldZoom = nil
oldPos = nil

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

--[[local regions = {
  ["svarground"] = {
    fromPos = { x = 32143, y = 31042, z = 7 },
    toPos = { x = 32350, y = 31251, z = 7 },
    size = { width = 207, height = 209 },
    image = "/data/minimap/regions/19-(32143-31042-7)subarea-0298-5160667f70d26dfc4db196d9dae5b048e060adf7a824c3a1c4383ee8ef6d6e51.png",
    markedColor = "#FFFF0044"
  },
}--]]

function init()
  minimapWindow = g_ui.displayUI('realminimap')

  minimapButton = modules.client_topmenu.addRightGameToggleButton('minimapButton',
      tr('Real Minimap') .. ' (Ctrl+M)', '/images/topbuttons/minimap', toggle)
  minimapButton:setOn(true)

  minimapWidget = minimapWindow:recursiveGetChildById('realMinimap')

  local gameRootPanel = m_interface.getRootPanel()

  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
  })

  connect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  if g_game.isOnline() then
    online()
  end
end

function terminate()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
  })

  disconnect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  local gameRootPanel = m_interface.getRootPanel()

  minimapWindow:destroy()
  if minimapButton then
    minimapButton:destroy()
  end
end

function toggle()
  if not minimapButton then return end

  if minimapButton:isOn() then
    minimapWindow:hide()
    minimapButton:setOn(false)
  else
    minimapWindow:show()
    minimapButton:setOn(true)
  end
end

function onClose()
  if minimapButton then
    minimapButton:setOn(false)
  end
  minimapWindow:hide()
end

function online()
  local benchmark = g_clock.millis()
  loadMap()
  updateCameraPosition()
  consoleln("Real Minimap loaded in " .. (g_clock.millis() - benchmark) / 1000 .. " seconds.")
end

function offline()
  -- saveMap()
end

function updateCameraPosition()
  local pos = minimapWidget:getCameraPosition()
  consoleln('updateCameraPosition', pos.x, pos.y, pos.z, minimapWidget:getZoom(), minimapWidget:getScale())
end

function loadMap()
  -- g_realMinimap:clean()
  consoleln("Loading map!")

  local isSatellite = false
  for i = 1, 2 do
    if i == 2 then
      isSatellite = true
    end

    local files = g_resources.listDirectoryFiles('/data/minimap' .. (isSatellite and '/satellite' or ''))
    local fileAmount = #files
    for index, filePath in pairs(files) do
      if g_resources.isFileType(filePath, 'png') then
        -- lets read the file name to evaluate the positions
        local barSeparated = filePath:split('/')
        local fileName = barSeparated[#barSeparated]
        local regex = regexMatch(fileName, string.format([[%s-([0-9]+)-([0-9]+)-([0-9]+)-([0-9]+)-([0-9a-zA-Z]+)\.bmp.lzma.png]], (isSatellite and 'satellite' or 'minimap')))

        local firstMatch = regex[1]
        if firstMatch then
          local refSize = tonumber(firstMatch[2])
          local tilesPerPixel = refSize / 32
          local posX = tonumber(firstMatch[3])
          local posY = tonumber(firstMatch[4])
          local posZ = tonumber(firstMatch[5])
          local hash = firstMatch[6]

          -- local maxRefSize = refSize
          -- for _, filePath in pairs(files) do
          --   local innerRegex = regexMatch(fileName, string.format([[%s-([0-9]+)-%s-%s-%s-([0-9a-zA-Z]+)\.png]], (isSatellite and 'satellite' or 'minimap'), firstMatch[3], firstMatch[4], firstMatch[5]))
          --   local firstMatch = innerRegex[1]
          --   if firstMatch then
          --     local innerRefSize = tonumber(firstMatch[2])
          --     if innerRefSize > maxRefSize then
          --       maxRefSize = innerRefSize
          --     end
          --   end
          -- end

          local REAL_MAP = true
          if REAL_MAP then
            posX = posX * 32
            posY = posY * 32
          end

          local fromScale = 0
          local toScale = 100

          if tilesPerPixel == 2 then
            fromScale = 0
            toScale = 1
          elseif tilesPerPixel == 1 then
            fromScale = 1
            toScale = 100
          elseif tilesPerPixel == 0.5 then
            fromScale = 2
            toScale = 100
          end

          g_realMinimap.loadImage('/data/minimap/' .. (isSatellite and 'satellite/' or '') .. filePath, isSatellite and "satellite" or "fullMinimap", {x = posX, y = posY, z = posZ}, tilesPerPixel, fromScale, toScale)

          consoleln(string.format("[%d/%d] loading map sector: %d %d %d, fromScale = %f, toScale = %f, tilesPerPixel = %f", index, fileAmount, posX, posY, posZ, fromScale, toScale, tilesPerPixel))
        end
      end
    end
  end

  -- Now, lets add the custom events for the regions widgets:
  for _, region in pairs(regions) do
    local imageId = g_realMinimap.loadRegion(region.image, region.fromPos, 1, 0, 64, region.markedColor)

    minimapWidget:addCustomMouseEvent(MouseLeftButton, region.fromPos, region.toPos, function(self, mapPos, mousePos)
      if not self:hasClickedRegion(imageId, mapPos) then
        return false
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
      return true
    end, true)
  end

  minimapWidget:setCameraPosition({x = 31000, y = 31000, z = 7})

  minimapWidget.view = "fullMinimap"
  minimapWidget:setCurrentView("fullMinimap")

  minimapWidget.onFloorChange = function(self, newPos, oldPos)
    if newPos.z > 7 then
      minimapWidget:setCurrentView("minimap")
      minimapWidget:setBackgroundColor("#000000ff")
    else
      minimapWidget:setCurrentView(minimapWidget.view)
      minimapWidget:setBackgroundColor("#336699ff")
    end
  end

  minimapWidget:addWidget("data/images/game/minimap/flag1.png", {width = 11, height = 11}, {x = 32334, y = 31754, z = 7}, "TESTE AQUI!")

  for _, markerInfo in pairs(markers) do
    local filePath = flagToFilePath[markerInfo.icon]
    if filePath then
      g_realMinimap.addWidget(filePath, {width = 11, height = 11}, markerInfo.pos, markerInfo.description)
      g_minimap.addWidget(filePath, {width = 11, height = 11}, markerInfo.pos, markerInfo.description)
    else
      print(markerInfo.icon, "not loaded!")
    end
  end
end