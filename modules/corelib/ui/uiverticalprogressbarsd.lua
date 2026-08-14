-- @docclass
UIVerticalProgressBarSD = extends(UIWidget, "UIVerticalProgressBarSD")

function UIVerticalProgressBarSD.create()
  local progressbar = UIVerticalProgressBarSD.internalCreate()
  progressbar:setFocusable(false)
  progressbar:setOn(true)
  progressbar.min = 0
  progressbar.max = 100
  progressbar.value = 0
  progressbar.bgBorderLeft = 0
  progressbar.bgBorderRight = 0
  progressbar.bgBorderTop = 0
  progressbar.bgBorderBottom = 0
  progressbar:insertLuaCall("onSetup")
  progressbar:insertLuaCall("onGeometryChange")
  return progressbar
end

function UIVerticalProgressBarSD:setMinimum(minimum)
  self.minimum = minimum
  if self.value < minimum then
    self:setValue(minimum)
  end
end

function UIVerticalProgressBarSD:setMaximum(maximum)
  self.maximum = maximum
  if self.value > maximum then
    self:setValue(maximum)
  end
end

function UIVerticalProgressBarSD:setValue(value, minimum, maximum)
  if minimum then
    self:setMinimum(minimum)
  end

  if maximum then
    self:setMaximum(maximum)
  end

  self.value = math.max(math.min(value, self.maximum), self.minimum)
  self:updateBackground()
end

function UIVerticalProgressBarSD:setPercent(percent)
  self:setValue(percent, 0, 100)
end

function UIVerticalProgressBarSD:getPercent()
  return self.value
end

function UIVerticalProgressBarSD:getPercentPixels()
  return (self.maximum - self.minimum) / self:getHeight()
end

function UIVerticalProgressBarSD:getProgress()
  -- 0 (empty) for a degenerate/uninitialized range; returning 1 made an empty bar
  -- render FULL (minimum/maximum are nil until the first setValue/setPercent).
  if self.minimum == nil or self.maximum == nil or self.minimum == self.maximum then return 0 end
  return (self.value - self.minimum) / (self.maximum - self.minimum)
end

function UIVerticalProgressBarSD:updateBackground()
  if self:isOn() then
    -- Real fill height, 0 when empty (see UIProgressBarSD): the old math.max(...,1)
    -- left a 1px golden sliver on empty segments.
    local height = math.round(self:getProgress() * (self:getHeight() - self.bgBorderTop - self.bgBorderBottom))
    local width = self:getWidth() - self.bgBorderLeft - self.bgBorderRight

    local rect = { x = self.bgBorderLeft, y = self.bgBorderTop + (self:getHeight() - height - self.bgBorderBottom), width = width, height = height }
    if self:getImageSource() == '' then
      self:setBackgroundRect(rect)
    else
      self:setImageRect(rect)
    end
    self:setImageVisible(height > 0)
  end
end

function UIVerticalProgressBarSD:onSetup()
  self:updateBackground()
end

function UIVerticalProgressBarSD:onStyleApply(name, node)
  for name,value in pairs(node) do
    if name == 'background-border-left' then
      self.bgBorderLeft = tonumber(value)
    elseif name == 'background-border-right' then
      self.bgBorderRight = tonumber(value)
    elseif name == 'background-border-top' then
      self.bgBorderTop = tonumber(value)
    elseif name == 'background-border-bottom' then
      self.bgBorderBottom = tonumber(value)
    elseif name == 'background-border' then
      self.bgBorderLeft = tonumber(value)
      self.bgBorderRight = tonumber(value)
      self.bgBorderTop = tonumber(value)
      self.bgBorderBottom = tonumber(value)
    elseif name == 'percent' then
      self.percent = self:setPercent(tonumber(value))
    end
  end
end

function UIVerticalProgressBarSD:onGeometryChange(oldRect, newRect)
  if not self:isOn() then
    self:setHeight(0)
  end
  self:updateBackground()
end
