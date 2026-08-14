-- Guards the drag contract between the spell list and the framework.
--
-- Regression: onDragEnter returned nil, so UIManager never set m_draggingWidget
-- and therefore never fired onDragLeave. The dragged icon had already been
-- reparented to the root panel, so it stayed floating over the interface at the
-- drop position and the spell never reached the action bar.

local t = require('harness')

-- Returns the module environment: the handlers resolve their collaborators
-- through it, so stubs have to be installed there rather than in _G.
local function loadSpellList()
  return t.loadModule('mods/game_tibia_spelllist/t_spelllist.lua', {
    g_ui = {createWidget = function() return nil end},
    modules = {}
  })
end

-- Stands in for a spell icon: records the handlers that get bound to it.
local function fakeIcon()
  return {}
end

t.describe('spell list drag', function()
  t.it('binds all three handlers', function()
    local env = loadSpellList()
    local icon = fakeIcon()
    env.bindSpellDragHandlers(icon, {})

    t.expect(type(icon.onDragEnter)).toBe('function')
    t.expect(type(icon.onDragMove)).toBe('function')
    t.expect(type(icon.onDragLeave)).toBe('function')
  end)

  t.it('onDragEnter returns true so the drag is tracked', function()
    local env = loadSpellList()
    local icon = fakeIcon()
    local seen = false
    env.bindSpellDragHandlers(icon, {})

    -- onUpdateDragSpell touches the widget tree, which does not exist headless.
    -- Replacing it keeps this focused on the return value, which is the contract
    -- UIManager checks.
    env.onUpdateDragSpell = function() seen = true end

    t.expect(icon.onDragEnter(icon, {x = 0, y = 0})).toBe(true)
    t.expect(seen).toBe(true)
  end)

  t.it('onDragMove returns true so the icon keeps following the cursor', function()
    local env = loadSpellList()
    local icon = fakeIcon()
    env.bindSpellDragHandlers(icon, {})
    env.onUpdateDragSpell = function() end

    t.expect(icon.onDragMove(icon, {x = 0, y = 0}, {x = 1, y = 1})).toBe(true)
  end)

  t.it('onDragLeave takes droppedWidget before mousePos', function()
    local env = loadSpellList()
    local icon = fakeIcon()
    local parent = {}
    local gotPos, gotParent
    env.bindSpellDragHandlers(icon, parent)

    env.onLeaveDragSpell = function(self, mousePos, originalParent)
      gotPos, gotParent = mousePos, originalParent
    end

    -- The framework calls onDragLeave(droppedWidget, mousePos). Declaring only
    -- two parameters would bind droppedWidget to mousePos and pass a widget on.
    local droppedWidget = {id = 'someActionButton'}
    icon.onDragLeave(icon, droppedWidget, {x = 42, y = 7})

    t.expect(gotParent).toBe(parent)
    t.expect(gotPos.x).toBe(42)
    t.expect(gotPos.y).toBe(7)
  end)
end)

return t
