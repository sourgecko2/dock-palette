--- Deterministic Lua-literal serialiser for menu snapshots.
---
--- `DockPalette:dumpMenus()` uses it to print a snapshot of an app's menus for inspection. Map
--- keys are sorted so output is stable. Pure Lua.

local M = {}

local function isArray(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  for i = 1, count do
    if t[i] == nil then
      return false
    end
  end
  return true
end

local function scalar(value)
  local kind = type(value)
  if kind == "string" then
    return string.format("%q", value)
  elseif kind == "number" then
    if value == math.floor(value) and math.abs(value) < 2 ^ 53 then
      return string.format("%d", value)
    end
    return string.format("%.17g", value)
  elseif kind == "boolean" then
    return tostring(value)
  end
  error("serialize: unsupported type " .. kind)
end

local function keyLiteral(key)
  if type(key) == "string" and key:match("^[%a_][%w_]*$") then
    return key
  end
  return "[" .. scalar(key) .. "]"
end

local function sortKeys(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then
    return ta < tb
  end
  return a < b
end

local function encode(value, indent)
  if type(value) ~= "table" then
    return scalar(value)
  end
  if next(value) == nil then
    return "{}"
  end

  local inner = indent .. "  "
  local lines = {}
  if isArray(value) then
    for _, item in ipairs(value) do
      lines[#lines + 1] = inner .. encode(item, inner) .. ","
    end
  else
    local keys = {}
    for key in pairs(value) do
      keys[#keys + 1] = key
    end
    table.sort(keys, sortKeys)
    for _, key in ipairs(keys) do
      lines[#lines + 1] = inner .. keyLiteral(key) .. " = " .. encode(value[key], inner) .. ","
    end
  end
  return "{\n" .. table.concat(lines, "\n") .. "\n" .. indent .. "}"
end

--- Returns `value` (tables, strings, numbers, booleans) as a Lua literal.
function M.serialize(value)
  return encode(value, "")
end

return M
