-- Parses every Lua file the client ships. Catches the whole class of "syntax
-- error only shows up when that module happens to load at runtime".
--
-- Uses LuaJIT deliberately: the client builds with LUAJIT=ON, so `goto`/labels
-- are valid here. Checking with luac5.1 rejects code that runs perfectly fine.

local t = require('harness')

local ROOTS = {'modules', 'mods'}

local function listLuaFiles()
  local files = {}
  for _, root in ipairs(ROOTS) do
    local pipe = io.popen(('find %s -name "*.lua" -type f 2>/dev/null'):format(root))
    if pipe then
      for line in pipe:lines() do
        table.insert(files, line)
      end
      pipe:close()
    end
  end
  table.sort(files)
  return files
end

t.describe('lua syntax', function()
  local files = listLuaFiles()

  t.it('finds files to check', function()
    t.expect(#files > 0).toBeTruthy()
  end)

  for _, path in ipairs(files) do
    t.it(path .. ' parses', function()
      local chunk, err = loadfile(path)
      if not chunk then
        error(err, 2)
      end
    end)
  end
end)

return t
