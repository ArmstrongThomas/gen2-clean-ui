return function()
  local Diagnostics = {}
  Diagnostics.__index = Diagnostics

  function Diagnostics.new(limit)
    return setmetatable({ limit = limit or 128, entries = {}, sequence = 0 }, Diagnostics)
  end

  function Diagnostics:record(screenId, code, detail)
    self.sequence = self.sequence + 1
    self.entries[#self.entries + 1] = {
      sequence = self.sequence,
      screenId = screenId,
      code = code,
      detail = detail,
    }
    if #self.entries > self.limit then table.remove(self.entries, 1) end
  end

  function Diagnostics:snapshot()
    local copy = {}
    for index, entry in ipairs(self.entries) do
      copy[index] = {
        sequence = entry.sequence,
        screenId = entry.screenId,
        code = entry.code,
        detail = entry.detail,
      }
    end
    return copy
  end

  function Diagnostics:clear()
    self.entries = {}
  end

  return Diagnostics
end

