local requireCore = ...
local Id = requireCore("foundation.id")
local Order = requireCore("foundation.order")
local Result = requireCore("foundation.result")
local unpackValues = unpack or table.unpack

local Catalog = {}

function Catalog.new()
  local self = { records = {}, labelCounts = {}, legacyOrdinal = 0 }

  function self:add(ownerId, entry)
    if not Id.valid(ownerId) or type(entry) ~= "table"
        or type(entry.label) ~= "string" then
      return Result.err("invalid_menu_entry", "owner and label are required")
    end
    local entryId = entry.id
    local stable = Id.valid(entryId)
    local key
    if stable then key = Id.key(ownerId, entryId)
    else
      self.legacyOrdinal = self.legacyOrdinal + 1
      local slug = entry.label:lower():gsub("[^a-z0-9]+", "_")
      local suffix = entry.compatibilityKey and ("label." .. slug)
        or (slug .. "." .. tostring(self.legacyOrdinal))
      key = Id.key(ownerId, "legacy." .. suffix)
      self.labelCounts[entry.label] = (self.labelCounts[entry.label] or 0) + 1
    end
    self.records[key] = {
      key = key, ownerId = ownerId, entryId = entryId,
      label = entry.label, action = entry.action or entry.callback,
      actions = entry.actions,
      priority = entry.priority or 0, stable = stable,
      compatibilityLabel = stable and nil or entry.label,
    }
    return Result.ok(key)
  end

  function self:list()
    local out = {}
    for _, key in ipairs(Order.keys(self.records)) do
      local record = self.records[key]
      record.pinnable = record.stable
        or self.labelCounts[record.compatibilityLabel] == 1
      record.pinStatus = record.pinnable and nil or "stable ID required"
      out[#out + 1] = record
    end
    return Order.contributions(out)
  end

  function self:removeOwner(ownerId)
    for key, record in pairs(self.records) do
      if record.ownerId == ownerId then
        if record.compatibilityLabel then
          local count = (self.labelCounts[record.compatibilityLabel] or 1) - 1
          self.labelCounts[record.compatibilityLabel] = math.max(0, count)
        end
        self.records[key] = nil
      end
    end
  end

  function self:removeWhere(predicate)
    if type(predicate) ~= "function" then return end
    for key, record in pairs(self.records) do
      if predicate(record) then
        if record.compatibilityLabel then
          local count = (self.labelCounts[record.compatibilityLabel] or 1) - 1
          self.labelCounts[record.compatibilityLabel] = math.max(0, count)
        end
        self.records[key] = nil
      end
    end
  end

  function self:invoke(key, ...)
    local record = self.records[key]
    if not record or type(record.action) ~= "function" then
      return Result.err("action_unavailable", "menu action is unavailable")
    end
    local args = { ... }
    local ok, value = xpcall(function()
      return record.action(unpackValues(args))
    end, function(message) return tostring(message) end)
    if not ok then return Result.err("menu_action_failed", value) end
    return Result.ok(value)
  end

  return self
end

return Catalog
