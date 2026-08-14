local BANK_FILE = '/sounds/soundbank.json'
local SOUND_DIR = '/sounds/'

-- SoundMusicEffect_t MUSIC_TYPE_MUSIC_TITLE. The login screen has no server to
-- send 0x85, and sendDisableLoginMusic returns early for OTClient clients, so
-- both starting and stopping the title theme are up to us.
local TITLE_MUSIC = 7

local bank = nil
local benchmark = g_clock.millis()

-- The server resends the same ambience/track on every area change; without these
-- the stream would restart from zero each time instead of playing through.
local currentAmbience = nil
local currentMusic = nil
local inPartyNow = false

-- The bank stores a small type per effect; the client's enum is that + 1000.
local function numericType(bankType)
  return 1000 + bankType
end

-- Battle sounds are grouped by who caused them, everything else by what it is.
-- Values mirror Otc::SourceEffect_t in src/client/const.h (0 = global/no actor).
local BATTLE_GROUP = {
  [1] = 'own',
  [2] = 'other',
  [3] = 'creature'
}

-- Which checkboxes gate each type, per battle group. Attack/Healing/Support sit
-- indented under "Spells" in the official page, so they need the parent too.
local BATTLE_OPTION = {
  own = {
    [ENumericSoundType.SPELL_GENERIC] = {'ownSpellSound'},
    [ENumericSoundType.SPELL_ATTACK] = {'ownSpellSound', 'ownAttackSound'},
    [ENumericSoundType.SPELL_HEALING] = {'ownSpellSound', 'ownHealingSound'},
    [ENumericSoundType.SPELL_SUPPORT] = {'ownSpellSound', 'ownSupportSound'},
    [ENumericSoundType.WEAPON_ATTACK] = {'ownWeaponsSound'}
  },
  other = {
    [ENumericSoundType.SPELL_GENERIC] = {'otherSpellSound'},
    [ENumericSoundType.SPELL_ATTACK] = {'otherSpellSound', 'otherAttackSound'},
    [ENumericSoundType.SPELL_HEALING] = {'otherSpellSound', 'otherHealingSound'},
    [ENumericSoundType.SPELL_SUPPORT] = {'otherSpellSound', 'otherSupportSound'},
    [ENumericSoundType.WEAPON_ATTACK] = {'otherWeaponsSound'}
  }
}

local BATTLE_VOLUME = {
  own = 'ownBattleVolumeScrollBar',
  other = 'otherBattleVolumeScrollBar',
  creature = 'creatureBattleVolumeScrollBar'
}

-- Creature types ignore the source byte: a monster noise is a monster noise
-- whoever triggered it.
local CREATURE_OPTION = {
  [ENumericSoundType.CREATURE_NOISE] = 'creatureNoiseSound',
  [ENumericSoundType.CREATURE_DEATH] = 'creatureDeathSound',
  [ENumericSoundType.CREATURE_ATTACK] = 'creatureSpellSound'
}

-- Types that are never battle sounds: {volume slider, gating options}. The
-- message types sit under the "Console Messages" parent on the UI Sounds page.
local GLOBAL_ROUTE = {
  [ENumericSoundType.FOOD_AND_DRINK] = {'itemVolumeScrollBar', {'foodBeverages'}},
  [ENumericSoundType.ITEM_MOVEMENT] = {'itemVolumeScrollBar', {'moveItemMusic'}},
  [ENumericSoundType.EVENT] = {'eventVolumeScrollBar'},
  [ENumericSoundType.UI] = {'uiVolumeScrollBar', {'uiSounds'}},
  [ENumericSoundType.WHISPER_WITHOUT_OPEN_CHAT] =
    {'uiVolumeScrollBar', {'consoleMessageSounds', 'privateLocalMessageSounds'}},
  [ENumericSoundType.CHAT_MESSAGE] = {'uiVolumeScrollBar', {'consoleMessageSounds'}},
  [ENumericSoundType.PARTY] = {'uiVolumeScrollBar', {'partySounds'}},
  [ENumericSoundType.VIP_LIST] = {'uiVolumeScrollBar', {'vipSounds'}},
  [ENumericSoundType.RAID_ANNOUNCEMENT] =
    {'uiVolumeScrollBar', {'consoleMessageSounds', 'raidMessageSounds'}},
  [ENumericSoundType.SERVER_MESSAGE] =
    {'uiVolumeScrollBar', {'consoleMessageSounds', 'systemMessageSounds'}}
}

-- SoundHelper::ESound -> effect id, lifted from the lookup table inside the
-- official client (tibia::qmlcomponents::TSoundHelperService). Every id's bank
-- type matches its name, which is what confirms the reading.
UiSound = {
  SCREENSHOT = 2773,
  BUTTON_PRESS = 2774,
  BUTTON_RELEASE = 2775,
  STORE_ANIMATION_RATTLING = 2780,
  STORE_ANIMATION_BUY = 2781,
  CHAT_MESSAGE_ARRIVED = 2782,
  PRIVATE_MESSAGE_IN_LOCAL_CHAT = 2783,
  SEND_CHAT_MESSAGE = 2784,
  OPEN_DIALOG_OR_WIDGET = 2785,
  VIP_LIST_LOGOUT = 2806,
  VIP_LIST_LOGIN = 2807,
  QUEST_TRACKER_ADD = 2854,
  QUEST_TRACKER_REMOVE = 2855,
  -- Not in that table; matched by bank type, which is unique for each.
  RAID_ANNOUNCEMENT = 2776,
  SERVER_MESSAGE = 2777,
  PARTY_JOIN = 2778,
  PARTY_LEAVE = 2779
}

-- Sweeping every tile is the expensive half, so it runs rarely; the gain and
-- panning tick is cheap and runs often enough to follow a running player.
local OBJECT_SCAN_INTERVAL = 400
local OBJECT_GAIN_INTERVAL = 50
-- Fraction of the remaining step covered per gain tick: enough to hide the
-- stepping, short enough that it never lags behind the movement itself.
local OBJECT_FADE_RATE = 0.25

-- Built once from the bank: appearance id -> group id.
local objectGroupOf = nil
local objectScanEvent = nil
local objectGainEvent = nil
local objectRadius = 1
local nearestObject = {}
local objectSource = {}
local playingObjectFile = {}
local objectGain = {}

local function option(key)
  return modules.client_settings.getOption(key)
end

local function volume(key)
  local value = option(key)
  if type(value) ~= 'number' then
    value = 100
  end
  return value / 100
end

function init()
  if g_sounds == nil then
    return
  end

  bank = loadJsonStruct(BANK_FILE, false)
  if not bank or not bank.effects then
    g_logger.error('game_sounds: could not load ' .. BANK_FILE)
    bank = nil
    return
  end

  connect(g_game, {
    onSoundEffect = onSoundEffect,
    onAmbientSound = onAmbientSound,
    onMusicSound = onMusicSound,
    onGameStart = onGameStart,
    onGameEnd = playTitleMusic
  })
  connect(Creature, {onShieldChange = onShieldChange})
  applyVolumes()
  playTitleMusic()
  consoleln("Sounds loaded in " .. (g_clock.millis() - benchmark) / 1000 .. " seconds (" ..
    table.size(bank.effects) .. " effects).")
end

function terminate()
  if g_sounds == nil then
    return
  end

  disconnect(Creature, {onShieldChange = onShieldChange})
  disconnect(g_game, {
    onSoundEffect = onSoundEffect,
    onAmbientSound = onAmbientSound,
    onMusicSound = onMusicSound,
    onGameStart = onGameStart,
    onGameEnd = playTitleMusic
  })
  stopObjectScan()
  g_sounds.stopAll()
  bank = nil
  currentAmbience = nil
  currentMusic = nil
end

-- Master volume has no engine knob, so it is folded into every gain we compute;
-- at zero the whole device goes off, which is what the "(off)" label means.
function applyVolumes()
  if g_sounds == nil then
    return
  end

  local master = volume('masterVolumeScrollBar')
  g_sounds.setAudioEnabled(master > 0 and option('enableAudio') ~= false)
  -- Ambience and music are the streamed groups, so they are the ones on channels;
  -- setGain reaches the running source, so a slider drag is heard immediately.
  g_sounds.getChannel(SoundChannels.Ambient):setGain(master * volume('ambienceVolumeScrollBar'))
  g_sounds.getChannel(SoundChannels.Music):setGain(master * volume('musicVolumeScrollBar'))
end

-- A party shield appearing on or leaving the local player is the join/leave the
-- "Join/leave Party" checkbox covers. Which of the two bank ids is which is not
-- in the SoundHelper table, so the pairing here is by elimination.
function onShieldChange(creature, shieldId)
  if creature ~= g_game.getLocalPlayer() then
    return
  end

  local inParty = shieldId ~= ShieldNone
  if inParty == inPartyNow then
    return
  end
  inPartyNow = inParty
  playUi(inParty and UiSound.PARTY_JOIN or UiSound.PARTY_LEAVE)
end

function playTitleMusic()
  stopObjectScan()
  if not bank or g_game.isOnline() then
    return
  end
  currentMusic = nil
  onMusicSound(TITLE_MUSIC)
end

function onGameStart()
  currentMusic = nil
  g_sounds.getChannel(SoundChannels.Music):stop(2)
  startObjectScan()
end

-- Sweeps the tiles the player can see, recording per group how many objects are
-- around (for the tier) and where the closest one sits (for volume and panning).
-- The bank has the thresholds but no radius, so the viewport is the read:
-- counts of 1/3/5/9 only make sense over a screen-sized area.
local function scanVisibleObjects()
  local player = g_game.getLocalPlayer()
  -- The player exists a few frames before the map does, so the position is nil
  -- on the first ticks after login.
  local center = player and player:getPosition()
  if not center then
    return {}, {}
  end

  local range = g_map.getAwareRange()
  local halfX = math.floor(range.width / 2)
  local halfY = math.floor(range.height / 2)

  local counts, nearest = {}, {}
  for dx = -halfX, halfX do
    for dy = -halfY, halfY do
      local tile = g_map.getTile({x = center.x + dx, y = center.y + dy, z = center.z})
      if tile then
        local squared = dx * dx + dy * dy
        for _, item in ipairs(tile:getItems()) do
          local group = objectGroupOf[item:getId()]
          if group then
            counts[group] = (counts[group] or 0) + 1
            local best = nearest[group]
            if not best or squared < best.squared then
              nearest[group] = {x = center.x + dx, y = center.y + dy, squared = squared}
            end
          end
        end
      end
    end
  end
  objectRadius = math.max(halfX, halfY)
  return counts, nearest
end

-- Highest tier whose threshold the count reaches; tiers are sorted ascending.
local function tierFileFor(entry, count)
  local chosen = nil
  for _, tier in ipairs(entry.tiers) do
    if count >= tier[1] then
      chosen = tier[2]
    end
  end
  return chosen
end

-- Runs far more often than the scan so the level tracks the player's own speed:
-- distance is recomputed against the live position, not the one from scan time.
local function updateObjectGains()
  objectGainEvent = scheduleEvent(updateObjectGains, OBJECT_GAIN_INTERVAL)

  local player = g_game.getLocalPlayer()
  local center = player and player:getPosition()
  if not bank or not center or not g_sounds.isAudioEnabled() then
    return
  end

  local ceiling = volume('masterVolumeScrollBar') * volume('ambienceVolumeScrollBar')

  for groupId in pairs(bank.objects) do
    local spot = nearestObject[groupId]
    local target, panX, panY = 0, 0, 0

    if spot and playingObjectFile[groupId] then
      local dx = spot.x - center.x
      local dy = spot.y - center.y
      local distance = math.sqrt(dx * dx + dy * dy)
      -- Silent at the edge of what we scanned, loudest standing on top of it.
      local falloff = 1 - math.min(distance / objectRadius, 1)
      target = ceiling * falloff * falloff
      if distance > 0 then
        panX, panY = dx / distance, dy / distance
      end
    end

    local current = objectGain[groupId] or 0
    -- Short smoothing: it only hides the step between ticks, it does not decide
    -- how fast the sound dies -- distance already does that.
    current = current + (target - current) * OBJECT_FADE_RATE
    if math.abs(target - current) < 0.005 then
      current = target
    end
    objectGain[groupId] = current

    local source = objectSource[groupId]
    if source then
      source:setGain(current)
      -- OpenAL's listener faces -Z with +Y up, so the map's south (+y) maps onto
      -- the depth axis; screen-right stays screen-right.
      source:setPanning(panX, -panY)
      if current <= 0 and not nearestObject[groupId] then
        source:stop()
        objectSource[groupId] = nil
        playingObjectFile[groupId] = nil
      end
    end
  end
end

local function updateObjectSounds()
  objectScanEvent = scheduleEvent(updateObjectSounds, OBJECT_SCAN_INTERVAL)

  if not bank or not g_sounds.isAudioEnabled() then
    return
  end

  local counts, nearest = scanVisibleObjects()
  nearestObject = nearest

  for groupId, entry in pairs(bank.objects) do
    local wanted = tierFileFor(entry, counts[groupId] or 0)

    -- Only swap the stream when the density tier actually changes; the gain tick
    -- handles everything else, including fading a departed group out.
    if wanted and wanted ~= playingObjectFile[groupId] then
      if objectSource[groupId] then
        objectSource[groupId]:stop()
      end
      local file = bank.files[tostring(wanted)]
      if file then
        objectSource[groupId] = g_sounds.playPositioned(SOUND_DIR .. file.name,
                                                        objectGain[groupId] or 0, 0, 0)
        playingObjectFile[groupId] = wanted
      end
    end
  end
end

function startObjectScan()
  if not bank or not bank.objects or objectScanEvent then
    return
  end

  objectGroupOf = {}
  for groupId, entry in pairs(bank.objects) do
    for _, appearance in ipairs(entry.appearances) do
      objectGroupOf[appearance] = groupId
    end
  end
  updateObjectSounds()
  updateObjectGains()
end

function stopObjectScan()
  if objectScanEvent then
    removeEvent(objectScanEvent)
    objectScanEvent = nil
  end
  if objectGainEvent then
    removeEvent(objectGainEvent)
    objectGainEvent = nil
  end
  for _, source in pairs(objectSource) do
    source:stop()
  end
  objectSource = {}
  nearestObject = {}
  playingObjectFile = {}
  objectGain = {}
end

-- 0x85 kind 0. Server ids are SoundAmbientEffect_t; 0 means stop.
function onAmbientSound(ambientId)
  if not bank then
    return
  end

  if ambientId == currentAmbience then
    return
  end
  currentAmbience = ambientId

  local channel = g_sounds.getChannel(SoundChannels.Ambient)
  local entry = bank.ambience[tostring(ambientId)]
  if not entry then
    channel:stop()
    return
  end

  local file = bank.files[tostring(entry.bed)]
  if file then
    local source = channel:play(SOUND_DIR .. file.name, 0, 1.0)
    if source then
      source:setLooping(true)
    end
  end
end

-- 0x85 kind 1. Server ids are SoundMusicEffect_t; 0 means stop.
function onMusicSound(musicId)
  if not bank then
    return
  end

  if musicId == currentMusic then
    return
  end
  currentMusic = musicId

  local channel = g_sounds.getChannel(SoundChannels.Music)
  local entry = bank.music[tostring(musicId)]
  -- Id 7 is the title theme, which is what the "Anthem" checkbox turns off.
  if not entry or (musicId == 7 and not option('anthemMusic')) then
    channel:stop()
    return
  end

  local file = bank.files[tostring(entry.file)]
  if file then
    local source = channel:play(SOUND_DIR .. file.name, 0, 1.0)
    if source then
      source:setLooping(true)
    end
  end
end

-- Returns the volume slider to scale this sound by, or nil when an option
-- silences it entirely.
local function route(soundType, source)
  local global = GLOBAL_ROUTE[soundType]
  if global then
    for _, gate in ipairs(global[2] or {}) do
      if not option(gate) then
        return nil
      end
    end
    return global[1]
  end

  local creatureGate = CREATURE_OPTION[soundType]
  if creatureGate then
    return option(creatureGate) and BATTLE_VOLUME.creature or nil
  end

  -- Global covers NPC-caused and actorless sounds; the page has no slider of its
  -- own for those, and "other players" is the closest group that can mute them.
  local group = BATTLE_GROUP[source] or 'other'

  if group == 'creature' then
    -- Monster attacks carry weapon/spell types, not CREATURE_ATTACK (which no
    -- effect in the bank uses), so one checkbox covers all of them.
    return option('creatureSpellSound') and BATTLE_VOLUME.creature or nil
  end

  local gates = BATTLE_OPTION[group][soundType]
  if not gates then
    return nil
  end
  for _, gate in ipairs(gates) do
    if not option(gate) then
      return nil
    end
  end
  return BATTLE_VOLUME[group]
end

function onSoundEffect(pos, source, effectId)
  if not bank or not g_sounds.isAudioEnabled() then
    return
  end

  local effect = bank.effects[tostring(effectId)]
  if not effect or #effect.files == 0 then
    return
  end

  local soundType = numericType(effect.type)
  -- Effects list several takes so the same hit does not sound identical twice.
  local file = bank.files[tostring(effect.files[math.random(#effect.files)])]
  if not file then
    return
  end

  local gain = (effect.gain and effect.gain[1] or 1.0) * volume('masterVolumeScrollBar')

  if soundType == ENumericSoundType.AMBIENCE_STREAM then
    -- Streamed and looping in spirit: a new ambience replaces the running one,
    -- which is exactly what SoundChannel does and what plain play() would not.
    g_sounds.getChannel(SoundChannels.Ambient):play(SOUND_DIR .. file.name, 0, gain)
    return
  end

  local slider = route(soundType, source)
  if not slider then
    return
  end

  -- Without a cached buffer the engine streams even a 30 KB hit, which costs a
  -- decode per shot and spams refill errors near EOF. preload() is a no-op once
  -- the file is cached and skips anything too big for the cache anyway.
  local path = SOUND_DIR .. file.name
  if not file.stream then
    g_sounds.preload(path)
  end

  -- Deliberately not a SoundChannel: channels stop the previous source, and in
  -- combat several effects have to overlap instead of cutting each other off.
  g_sounds.play(path, 0, gain * volume(slider))
end

-- Interface sounds are raised by the client itself, so they name an id from
-- UiSound instead of arriving over the wire. `extraGate` is for the per-channel
-- message checkboxes, which the sound's type alone cannot tell apart.
function playUi(effectId, extraGate)
  if extraGate and not option(extraGate) then
    return
  end
  onSoundEffect(nil, 0, effectId)
end

-- Which "Console Messages" child owns each talk mode. Modes absent here are
-- either our own speech or system text that the page does not cover.
local CHAT_OPTION = {
  [MessageModes.Say] = 'consoleMessageSounds',
  [MessageModes.Whisper] = 'consoleMessageSounds',
  [MessageModes.Yell] = 'consoleMessageSounds',
  -- NPC speech inside the dialogue window arrives as NpcFromStartBlock, not
  -- NpcFrom, so leaving it out silences exactly the private NPC conversation.
  [MessageModes.NpcFrom] = 'npcMessageSounds',
  [MessageModes.NpcFromStartBlock] = 'npcMessageSounds',
  [MessageModes.PrivateFrom] = 'privateMessageSounds',
  [MessageModes.GamemasterPrivateFrom] = 'privateMessageSounds',
  [MessageModes.Channel] = 'consoleMessageSounds',
  [MessageModes.ChannelHighlight] = 'consoleMessageSounds',
  [MessageModes.GamemasterChannel] = 'consoleMessageSounds',
  [MessageModes.GamemasterBroadcast] = 'globalMessageSounds',
  [MessageModes.Guild] = 'guildMessageSounds',
  [MessageModes.Party] = 'partyMessageSounds',
  [MessageModes.PartyManagement] = 'partyMessageSounds'
}

-- An incoming line in a channel the player kept ticked. Our own outgoing speech
-- gets its own sound, which is why the To/NpcTo modes are not in the table.
function playChatSound(mode, ownMessage)
  if ownMessage then
    playUi(UiSound.SEND_CHAT_MESSAGE)
    return
  end

  local gate = CHAT_OPTION[mode]
  if gate then
    playUi(UiSound.CHAT_MESSAGE_ARRIVED, gate)
  end
end
