local keybindMount = KeyBind:getKeyBind("Movement", "Mount/dismount")

function init()
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  if g_game.isOnline() then online() end
end

function terminate()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  offline()
end

function online()
  local benchmark = g_clock.millis()
  if g_game.getFeature(GamePlayerMounts) then
    keybindMount:active()
  end
  consoleln("Player Mounts loaded in " .. (g_clock.millis() - benchmark) / 1000 .. " seconds.")
end

function offline()
  if g_game.getFeature(GamePlayerMounts) then
    keybindMount:deactive()
  end
end

function toggleMount()
  local player = g_game.getLocalPlayer()
  if player then
    player:toggleMount()
  end
end

function mount()
  local player = g_game.getLocalPlayer()
  if player then
    player:mount()
  end
end

function dismount()
  local player = g_game.getLocalPlayer()
  if player then
    player:dismount()
  end
end
