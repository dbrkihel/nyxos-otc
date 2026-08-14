-- Guards the crosshair cast routing: a spell declared needPosition must go
-- through the aim prompt, and everything else must stay plain speech. Getting
-- this backwards silently casts area spells on the caster instead of the tile.

local t = require('harness')

local function loadSpells()
  local talked, aimed = {}, {}
  local env = t.loadModule('modules/gamelib/spells.lua', {
    g_game = {
      talk = function(words) table.insert(talked, words) end
    },
    modules = {
      game_interface = {
        startAimedCast = function(words) table.insert(aimed, words) end
      }
    }
  })
  return env.Spells, talked, aimed
end

t.describe('Spells', function()
  t.describe('getSpellByWords', function()
    t.it('finds a stock spell', function()
      local Spells = loadSpells()
      local spell = Spells.getSpellByWords('exura')
      t.expect(spell).toBeTruthy()
      t.expect(spell.name).toBe('Light Healing')
    end)

    t.it('finds Death Echo and reports it needs a position', function()
      local Spells = loadSpells()
      local spell = Spells.getSpellByWords('exevo mort ora')
      t.expect(spell).toBeTruthy()
      t.expect(spell.needPosition).toBe(true)
    end)

    t.it('returns nil for words that are not a spell', function()
      local Spells = loadSpells()
      t.expect(Spells.getSpellByWords('good morning')).toBeNil()
    end)
  end)

  t.describe('needsPosition', function()
    t.it('is true for a crosshair spell', function()
      local Spells = loadSpells()
      t.expect(Spells.needsPosition('exevo mort ora')).toBe(true)
    end)

    t.it('is false for an ordinary spell', function()
      local Spells = loadSpells()
      t.expect(Spells.needsPosition('exura')).toBe(false)
    end)

    t.it('is false for words that are not a spell, and for empty input', function()
      local Spells = loadSpells()
      t.expect(Spells.needsPosition('good morning')).toBe(false)
      t.expect(Spells.needsPosition('')).toBe(false)
      t.expect(Spells.needsPosition(nil)).toBe(false)
    end)
  end)

  t.describe('cast', function()
    t.it('routes a needPosition spell to the aim prompt', function()
      local Spells, talked, aimed = loadSpells()
      Spells.cast('exevo mort ora')
      t.expect(#aimed).toBe(1)
      t.expect(aimed[1]).toBe('exevo mort ora')
      t.expect(#talked).toBe(0)
    end)

    t.it('sends an ordinary spell as plain speech', function()
      local Spells, talked, aimed = loadSpells()
      Spells.cast('exura')
      t.expect(#talked).toBe(1)
      t.expect(talked[1]).toBe('exura')
      t.expect(#aimed).toBe(0)
    end)

    t.it('sends unknown words as plain speech', function()
      local Spells, talked, aimed = loadSpells()
      Spells.cast('good morning')
      t.expect(#talked).toBe(1)
      t.expect(#aimed).toBe(0)
    end)

    t.it('ignores empty input', function()
      local Spells, talked, aimed = loadSpells()
      Spells.cast('')
      Spells.cast(nil)
      t.expect(#talked).toBe(0)
      t.expect(#aimed).toBe(0)
    end)
  end)
end)

return t
