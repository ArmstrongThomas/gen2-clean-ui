local requireCore = ...
local Result = requireCore("foundation.result")

local Guard = {}

function Guard.call(code, callback, ...)
  local args = { ... }
  local ok, value = xpcall(function()
    return callback(unpack and unpack(args) or table.unpack(args))
  end, function(message) return tostring(message) end)
  if not ok then return Result.err(code, value) end
  return Result.ok(value)
end

return Guard
