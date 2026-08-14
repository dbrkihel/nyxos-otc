function init()
  trade = g_ui.displayUI('new')
  hide()
end

function terminate()
  if trade then
      trade:destroy()
      trade = nil
  end
end

function toggle()
  if trade:isVisible() then
      trade:hide()
  else
      trade:show()
  end
end

function show()
  trade:show()
end

function hide()
  trade:hide()
end