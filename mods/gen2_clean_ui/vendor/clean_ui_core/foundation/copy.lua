local requireCore = ...

local Copy = {}

function Copy.deep(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do
    out[Copy.deep(key, seen)] = Copy.deep(child, seen)
  end
  return out
end

return Copy

