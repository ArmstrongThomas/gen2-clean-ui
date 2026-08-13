local requireCore = ...
local Order = requireCore("foundation.order")
local Result = requireCore("foundation.result")
local Contract = requireCore("v3.contract")

local Registry = {}

function Registry.new(game)
  local self = { game = game, records = {}, revision = 0 }
  local function key(ownerId, contractId) return ownerId .. "\0" .. contractId end

  function self:register(ownerId, contract)
    local staged = Contract.validate(ownerId, contract, self.game)
    if not staged.ok then return staged end
    local recordKey = key(ownerId, contract.id)
    local replaced = self.records[recordKey] ~= nil
    self.records[recordKey] = staged.value
    self.revision = self.revision + 1
    return Result.ok({ replaced = replaced, revision = self.revision })
  end

  function self:unregister(ownerId, contractId)
    local recordKey = key(ownerId, contractId)
    if self.records[recordKey] ~= nil then
      self.records[recordKey] = nil
      self.revision = self.revision + 1
    end
    return Result.ok({ revision = self.revision })
  end

  function self:list()
    local out = {}
    for _, recordKey in ipairs(Order.keys(self.records)) do
      out[#out + 1] = self.records[recordKey]
    end
    return out
  end

  function self:actions()
    local out = {}
    for _, record in ipairs(self:list()) do
      for actionId, callback in pairs(record.actions or {}) do
        out[record.ownerId .. "\0" .. record.contractId .. "\0" .. actionId] = callback
      end
    end
    return out
  end

  function self:menuExtensions()
    local out = {}
    for _, record in ipairs(self:list()) do
      for _, extension in ipairs(record.extensions or {}) do
        if type(extension) == "table"
            and (extension.type == "start.action"
              or extension.type == "menu.action") then
          local copy = {}
          for key, value in pairs(extension) do copy[key] = value end
          copy.ownerId = record.ownerId
          copy.contractId = record.contractId
          copy.actionCallback = record.actions
            and record.actions[extension.action] or nil
          copy.actionTable = record.actions
          out[#out + 1] = copy
        end
      end
    end
    return Order.contributions(out)
  end

  return self
end

return Registry
