local requireCore = ...
local Order = requireCore("foundation.order")

local Focus = {}

function Focus.new()
  local self = { scopes = {}, current = nil }

  function self:set(ids, preferred)
    self.scopes = {}
    for _, id in ipairs(ids or {}) do self.scopes[id] = true end
    if preferred and self.scopes[preferred] then self.current = preferred
    elseif not self.scopes[self.current] then self.current = Order.keys(self.scopes)[1] end
    return self.current
  end

  function self:restore(id)
    if id and self.scopes[id] then self.current = id end
    return self.current
  end

  return self
end

return Focus

