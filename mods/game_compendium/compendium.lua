local compendiumWindow

function init()
  compendiumWindow = g_ui.displayUI('compendium')
  hide()
end

function terminate()
  g_client.setInputLockWidget(nil)
  compendiumWindow:destroy()
end

function hide()
  compendiumWindow:hide()
  g_client.setInputLockWidget(nil)
end

function show()
  compendiumWindow:show(true)
  compendiumWindow:focus()
  g_client.setInputLockWidget(compendiumWindow)
end
