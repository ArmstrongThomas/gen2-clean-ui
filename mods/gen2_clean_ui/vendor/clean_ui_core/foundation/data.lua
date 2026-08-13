local requireCore = ...
local Copy = requireCore("foundation.copy")

local Data = {}

local function validate(value, path, seen)
  local kind = type(value)
  if kind == "nil" or kind == "boolean" or kind == "number" or kind == "string" then
    if kind == "number" and (value ~= value or value == math.huge or value == -math.huge) then
      return nil, "non-finite number at " .. path
    end
    return true
  end
  if kind ~= "table" then return nil, kind .. " at " .. path end
  if getmetatable(value) ~= nil then return nil, "metatable at " .. path end
  if seen[value] then return nil, "cycle at " .. path end
  seen[value] = true
  for key, child in pairs(value) do
    local keyKind = type(key)
    if keyKind ~= "string" and keyKind ~= "number" then
      return nil, "invalid key type at " .. path
    end
    local ok, err = validate(child, path .. "." .. tostring(key), seen)
    if not ok then return nil, err end
  end
  seen[value] = nil
  return true
end

function Data.validate(value)
  return validate(value, "$", {})
end

function Data.snapshot(value)
  local ok, err = Data.validate(value)
  if not ok then return nil, err end
  return Copy.deep(value)
end

return Data

