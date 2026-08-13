local requireCore = ...

local OverlayStack = {}

function OverlayStack.new()
  local self = { values = {} }
  function self:push(value) self.values[#self.values + 1] = value return value end
  function self:top() return self.values[#self.values] end
  function self:pop() return table.remove(self.values) end
  function self:clear() self.values = {} end
  return self
end

return OverlayStack

