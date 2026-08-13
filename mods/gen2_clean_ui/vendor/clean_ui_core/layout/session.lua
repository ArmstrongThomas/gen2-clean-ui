local requireCore = ...
local Result = requireCore("foundation.result")

local Session = {}

function Session.new()
  local self = { records = {} }

  function self:get(token)
    return self.records[token]
  end

  function self:lock(token, signature, layout)
    if token == nil then return Result.err("invalid_source_token", "source token required") end
    local current = self.records[token]
    if current and current.signature == signature then return Result.ok(current.layout) end
    self.records[token] = { signature = signature, layout = layout }
    return Result.ok(layout)
  end

  function self:release(token)
    self.records[token] = nil
  end

  function self:clear()
    self.records = {}
  end

  return self
end

return Session

