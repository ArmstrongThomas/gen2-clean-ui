return function(ctx)
  local Settings = {}
  Settings.__index = Settings

  function Settings.new(mod, loaderContext)
    local schema, loadError = loaderContext.loadFile("options.lua")
    assert(type(schema) == "table", loadError or "options.lua returned no schema")
    return setmetatable({ mod = mod, schema = schema }, Settings)
  end

  function Settings:define()
    if self.mod.options and self.mod.options.define then
      self.mod.options:define(self.schema)
    end
    return self.schema
  end

  function Settings:get(key)
    if self.mod.options and self.mod.options.get then
      return self.mod.options:get(key)
    end
    for _, row in ipairs(self.schema) do
      if row.key == key then return row.default end
    end
    return nil
  end

  function Settings:resetDefaults()
    if not (self.mod.options and self.mod.options.set) then
      return nil, "options_writer_unavailable",
        "Reset Defaults requires the public mod.options:set API"
    end
    for _, row in ipairs(self.schema) do
      local ok, code, message = self.mod.options:set(row.key, row.default)
      if not ok then return nil, code, message end
    end
    return true
  end

  return Settings
end

