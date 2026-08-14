-- Local developer config. Copy this file to `config.lua` and edit that copy --
-- `config.lua` is gitignored, so your own hosts and credentials never get
-- committed. The client works without it; everything here is optional.
--
-- init.lua reads the { Services, Servers } table returned at the bottom, and it
-- takes precedence over the built-in defaults.

-- Auto-login exists so you can iterate on UI without typing credentials every
-- run. Leave it off unless you are actively doing that.
AUTO_LOGIN_DEBUG = false
AUTO_LOGIN_EMAIL = "your-account"
AUTO_LOGIN_PASS = "your-password"
AUTO_LOGIN_HOST = "http://127.0.0.1/login.php"

-- Stop at the character list instead of entering the world directly.
AUTO_SELECT_CHAR = false

-- Logs every prewalk, server confirmation and watchdog trip to Nyxos.log.
-- Very noisy; turn it on only while chasing a movement desync.
g_extras.set("debugWalking", false)

-- Ctrl+Shift+R rebuilds the NPC dialogue window straight from its .otui without
-- restarting the client, so geometry changes show up immediately.
UI_HOTRELOAD = true

-- Ctrl+T opens the in-client terminal: live log plus a Lua command line.
DEV_TERMINAL = true

return {
  Services = {
    website = "",
    updater = "",
    stats = "",
    crash = "",
    feedback = "",
    -- client_topmenu iterates this as a LIST, so it must be a table of URLs.
    status = {},
    createAccount = "http://127.0.0.1",
    recoveryPassword = "http://127.0.0.1",
    -- "Get Coins" in the store and market opens this.
    Coins = "http://127.0.0.1",
  },
  Servers = {
    Local = "http://127.0.0.1/login.php",
  },
}
