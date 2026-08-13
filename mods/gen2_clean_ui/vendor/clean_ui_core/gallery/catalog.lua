local requireCore = ...
local Copy = requireCore("foundation.copy")
local Data = requireCore("foundation.data")
local Order = requireCore("foundation.order")
local Result = requireCore("foundation.result")

local Gallery = {}

function Gallery.new(game)
  local self = { game = game, records = {} }

  function self:add(fixture)
    if type(fixture) ~= "table" or type(fixture.id) ~= "string"
        or type(fixture.family) ~= "string" then
      return Result.err("invalid_fixture", "fixture id and family are required")
    end
    if fixture.game and fixture.game ~= self.game then
      return Result.err("wrong_game", "fixture is for " .. tostring(fixture.game))
    end
    local snapshot, err = Data.snapshot(fixture)
    if not snapshot then return Result.err("invalid_fixture", err) end
    self.records[fixture.id] = snapshot
    return Result.ok(true)
  end

  function self:list(filter)
    local out = {}
    for _, id in ipairs(Order.keys(self.records)) do
      local fixture = self.records[id]
      if not filter or not filter.family or fixture.family == filter.family then
        out[#out + 1] = Copy.deep(fixture)
      end
    end
    return out
  end

  return self
end

return Gallery

