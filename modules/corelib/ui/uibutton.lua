-- @docclass
UIButton = extends(UIWidget, "UIButton")

function UIButton.create()
  local button = UIButton.internalCreate()
  button:setFocusable(false)
  button:setClickSound(2774)
  return button
end

-- The official client plays one sound going down and another coming up
-- (TibiaButton.qml onPressedChanged), so both edges are hooked.
local function playClickSound(self, name)
  local sounds = modules.game_sounds
  if not self.clickSound or not sounds then
    return
  end
  sounds.playUi(sounds.UiSound[name])
end

function UIButton:onMousePress(pos, button)
  playClickSound(self, 'BUTTON_PRESS')
  return false
end

function UIButton:onMouseRelease(pos, button)
  if self:isPressed() then
    playClickSound(self, 'BUTTON_RELEASE')
  end
  return self:isPressed()
end
