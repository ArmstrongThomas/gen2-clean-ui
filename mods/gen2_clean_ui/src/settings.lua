return function(ctx)
  local Settings = {}
  Settings.__index = Settings

  function Settings.new(mod, loaderContext)
    local schema, loadError = loaderContext.loadFile("options.lua")
    assert(type(schema) == "table", loadError or "options.lua returned no schema")
    return setmetatable({ mod = mod, schema = schema, fallbackValues = {} }, Settings)
  end

  function Settings:define()
    if self.mod.options and self.mod.options.define then
      self.mod.options:define(self.schema)
    end
    return self.schema
  end

  function Settings:get(key)
    if self.fallbackValues[key] ~= nil then
      return self.fallbackValues[key]
    end
    if self.mod.options and self.mod.options.get then
      local ok, value = pcall(self.mod.options.get, self.mod.options, key)
      if ok and value ~= nil then return value end
    end
    for _, row in ipairs(self.schema) do
      if row.key == key then return row.default end
    end
    return nil
  end

  function Settings:resetDefaults()
    for _, row in ipairs(self.schema) do
      if self.mod.options and type(self.mod.options.set) == "function" then
        local callOk, result, code, message = pcall(self.mod.options.set,
          self.mod.options, row.key, row.default)
        if not callOk then
          return nil, "options_set_failed", tostring(result)
        end
        if not result then
          return nil, code or "options_set_failed", message
        end
      else
        -- v0.1.86 exposes define/get but intentionally has no public writer.
        -- Keep reset useful for this session without pretending to persist a
        -- profile-wide change the host cannot persist.
        self.fallbackValues[row.key] = row.default
      end
    end
    return true
  end

  return Settings
end
