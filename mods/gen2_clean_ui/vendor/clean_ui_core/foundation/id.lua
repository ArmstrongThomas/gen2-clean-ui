local requireCore = ...

local Id = {}
local PATTERN = "^[a-z0-9][a-z0-9_.%-]*$"

function Id.valid(value)
  return type(value) == "string" and #value <= 96 and value:match(PATTERN) ~= nil
end

function Id.require(value, label)
  if not Id.valid(value) then
    return nil, "invalid_id", (label or "id") .. " must match " .. PATTERN
  end
  return value
end

function Id.key(ownerId, entryId)
  return ownerId .. "\0" .. entryId
end

return Id

