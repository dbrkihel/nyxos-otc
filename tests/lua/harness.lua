-- Minimal test harness for headless Lua specs. No dependencies: the client's
-- modules load under plain LuaJIT, so specs run without booting the engine.

local M = {
  passed = 0,
  failed = 0,
  failures = {},
  currentSuite = nil
}

local function record(name, err)
  M.failed = M.failed + 1
  table.insert(M.failures, {suite = M.currentSuite, name = name, err = err})
end

function M.describe(name, fn)
  local previous = M.currentSuite
  M.currentSuite = previous and (previous .. ' > ' .. name) or name
  fn()
  M.currentSuite = previous
end

function M.it(name, fn)
  local ok, err = pcall(fn)
  if ok then
    M.passed = M.passed + 1
  else
    record(name, err)
  end
end

local function describeValue(value)
  if type(value) == 'table' then
    local parts = {}
    for k, v in pairs(value) do
      table.insert(parts, tostring(k) .. '=' .. tostring(v))
    end
    table.sort(parts)
    return '{' .. table.concat(parts, ', ') .. '}'
  end
  return tostring(value)
end

function M.expect(actual)
  local matchers = {}

  function matchers.toBe(expected)
    if actual ~= expected then
      error(('expected %s, got %s'):format(describeValue(expected), describeValue(actual)), 3)
    end
  end

  function matchers.toBeNil()
    if actual ~= nil then
      error(('expected nil, got %s'):format(describeValue(actual)), 3)
    end
  end

  function matchers.toBeTruthy()
    if not actual then
      error(('expected a truthy value, got %s'):format(describeValue(actual)), 3)
    end
  end

  function matchers.toEqualPosition(x, y, z)
    if type(actual) ~= 'table' or actual.x ~= x or actual.y ~= y or actual.z ~= z then
      error(('expected position %d,%d,%d, got %s'):format(x, y, z, describeValue(actual)), 3)
    end
  end

  return matchers
end

-- corelib extends the stock string/table libraries in place, and module code
-- calls those helpers freely. Load the real files rather than stubbing them, so
-- specs exercise the same implementations the client runs.
local preludeLoaded = false
function M.loadPrelude()
  if preludeLoaded then return end
  for _, path in ipairs({'modules/corelib/string.lua', 'modules/corelib/table.lua'}) do
    local chunk = loadfile(path)
    if chunk then chunk() end
  end
  preludeLoaded = true
end

-- Loads a client module in a throwaway environment so one spec cannot leak
-- globals into the next. Returns the globals the file defined.
function M.loadModule(path, stubs)
  M.loadPrelude()

  local env = setmetatable(stubs or {}, {__index = _G})
  local chunk, err = loadfile(path)
  if not chunk then
    error('could not load ' .. path .. ': ' .. tostring(err), 2)
  end
  setfenv(chunk, env)
  chunk()
  return env
end

function M.report(label)
  local total = M.passed + M.failed
  if M.failed == 0 then
    print(('  %s: %d/%d passed'):format(label, M.passed, total))
    return true
  end

  print(('  %s: %d/%d passed, %d FAILED'):format(label, M.passed, total, M.failed))
  for _, f in ipairs(M.failures) do
    print(('    x %s > %s'):format(f.suite or '?', f.name))
    print(('      %s'):format(f.err))
  end
  return false
end

function M.reset()
  M.passed, M.failed, M.failures, M.currentSuite = 0, 0, {}, nil
end

return M
