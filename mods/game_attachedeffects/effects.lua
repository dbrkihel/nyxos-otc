--[[
    register(id, name, thingId, thingType, config)
    config = {
        speed, disableWalkAnimation, shader,
        offset{x, y, onTop}, dirOffset[dir]{x, y, onTop},
        onAttach, onDetach
    }
]] --
AttachedEffectManager.register(1, 'Spoke Lighting', 12, ThingCategoryEffect, {
    speed = 0.5,
    onAttach = function(effect, owner)
        print('onAttach: ', effect:getId(), owner:getName())
    end,
    onDetach = function(effect, oldOwner)
        print('onDetach: ', effect:getId(), oldOwner:getName())
    end
})

AttachedEffectManager.register(2, 'Bat Wings', 307, ThingCategoryCreature, {
    speed = 5,
    disableWalkAnimation = true,
    shader = 'Outfit - Ghost',
    dirOffset = {
        [North] = {0, -10, true},
        [East] = {5, -5},
        [South] = {-5, 0},
        [West] = {-10, -5, true}
    }
})

AttachedEffectManager.register(3, 'Angel Light', 50, ThingCategoryEffect, {
    shader = 'Map - Party'
})

AttachedEffectManager.register(4, 'Brino - Effect', 2558, ThingCategoryCreature, {
    dirOffset = {
        [North] = {0, 0, true},
        [East] = {0, 0, true},
        [South] = {0, 0, true},
        [West] = {0, 0, true}
    }
})

AttachedEffectManager.register(5, 'Brino - Effect', 2559, ThingCategoryCreature, {
    dirOffset = {
        [North] = {0, 0, false},
        [East] = {0, 0, false},
        [South] = {0, 0, false},
        [West] = {0, 0, false}
    }
})
