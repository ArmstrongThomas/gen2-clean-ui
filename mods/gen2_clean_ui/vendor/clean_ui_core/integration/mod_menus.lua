local requireCore = ...
local Result = requireCore("foundation.result")

local ModMenus = {}

function ModMenus.new(catalog, pins)
  local self = { catalog = catalog, pins = pins }

  function self:rows()
    local out = {}
    for _, entry in ipairs(self.catalog:list()) do
      out[#out + 1] = {
        id = entry.key,
        label = entry.label,
        pinned = self.pins:contains(entry.key),
        pinnable = entry.pinnable,
        pinStatus = entry.pinStatus,
        ownerId = entry.ownerId,
        entryId = entry.entryId,
      }
    end
    return out
  end

  function self:activate(key, context)
    return self.catalog:invoke(key, context)
  end

  function self:togglePin(key)
    local record = self.catalog.records[key]
    if not record then
      return Result.err("unknown_menu_entry", "menu entry is unavailable")
    end
    local pinnable
    for _, row in ipairs(self.catalog:list()) do
      if row.key == key then pinnable = row.pinnable break end
    end
    if not pinnable then
      return Result.err("stable_id_required", "stable ID required")
    end
    return self.pins:toggle(key)
  end

  return self
end

return ModMenus
