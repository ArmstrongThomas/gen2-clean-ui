local requireCore = ...

local Result = {}
local RESULT_MT = { __index = Result }

function Result.ok(value)
  return setmetatable({ ok = true, value = value }, RESULT_MT)
end

function Result.err(code, message, details)
  return setmetatable({
    ok = false,
    error = {
      code = tostring(code or "unknown_error"),
      message = tostring(message or code or "unknown error"),
      details = details,
    },
  }, RESULT_MT)
end

function Result.unpack(result)
  if type(result) ~= "table" then
    return nil, "invalid_result", "expected a result table"
  end
  if result.ok then return result.value end
  local err = result.error or {}
  return nil, err.code or "unknown_error", err.message or "unknown error"
end

return Result
