local requireCore = ...
local Copy = requireCore("foundation.copy")
local Result = requireCore("foundation.result")

local Pins = {}

function Pins.new(saveApi, storageKey)
  storageKey = storageKey or "clean_ui.pins"
  local loaded = saveApi and saveApi.get and saveApi:get(storageKey,
    { version = 1, keys = {} }) or { version = 1, keys = {} }
  local self = { saveApi = saveApi, storageKey = storageKey,
    data = type(loaded) == "table" and loaded or { version = 1, keys = {} } }
  self.data.keys = type(self.data.keys) == "table" and self.data.keys or {}

  local function persist()
    if not (self.saveApi and self.saveApi.set) then
      return Result.err("save_unavailable", "mod.save:set is unavailable")
    end
    local ok, stored, code, message = pcall(function()
      return self.saveApi:set(self.storageKey, Copy.deep(self.data))
    end)
    if not ok then return Result.err("pin_save_failed", stored) end
    -- The established host save writer mutates the save and returns nil.
    -- Treat a non-throwing nil as success while still honoring an explicit
    -- false from newer hosts that choose to report a failed write.
    if stored == false then
      return Result.err(code or "pin_save_failed",
        message or "mod.save:set did not persist the pin")
    end
    return Result.ok(true)
  end

  function self:contains(key) return self.data.keys[key] == true end
  function self:set(key, pinned)
    self.data.keys[key] = pinned and true or nil
    return persist()
  end
  function self:toggle(key) return self:set(key, not self:contains(key)) end
  function self:snapshot() return Copy.deep(self.data) end
  return self
end

return Pins
