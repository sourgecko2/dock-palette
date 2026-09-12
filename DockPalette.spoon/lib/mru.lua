--- A small most-recently-used list, used to order apps like ⌘Tab does.
--- Pure Lua; no `hs.*`.

local MRU = {}
MRU.__index = MRU

--- Creates an empty list that keeps at most `limit` keys (default 64).
function MRU.new(limit)
  return setmetatable({ keys = {}, limit = limit or 64 }, MRU)
end

--- Moves `key` to the front, adding it if needed.
function MRU:touch(key)
  if key == nil then
    return
  end
  self:remove(key)
  table.insert(self.keys, 1, key)
  while #self.keys > self.limit do
    table.remove(self.keys)
  end
end

--- Forgets `key`.
function MRU:remove(key)
  for i = #self.keys, 1, -1 do
    if self.keys[i] == key then
      table.remove(self.keys, i)
    end
  end
end

--- Returns the 1-based recency rank of `key`, or nil if it is not in the list.
function MRU:rank(key)
  for i, candidate in ipairs(self.keys) do
    if candidate == key then
      return i
    end
  end
  return nil
end

return MRU
