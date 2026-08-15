local requireCore = ...
local Result = requireCore("foundation.result")

local Settings = {}
local fallbackValues = setmetatable({}, { __mode = "k" })

local function fallbackFor(mod)
  local values = fallbackValues[mod]
  if not values then
    values = {}
    fallbackValues[mod] = values
  end
  return values
end

local function schemaDefault(schema, key)
  for _, row in ipairs(schema or Settings.schema) do
    if row.key == key then return row.default end
  end
  return nil
end

-- v0.1.86 exposes the option schema and reader but not the writer. Keep the
-- V3 settings surface usable on that host: native writers still win, while
-- older hosts get a session-local override instead of a hard failure. The
-- fallback is deliberately in-memory; the public API gives a mod no safe
-- profile-wide persistence channel before options:set exists.
function Settings.get(mod, key, schema, fallback)
  local values = mod and fallbackValues[mod]
  if values and values[key] ~= nil then return values[key] end
  local options = mod and mod.options
  if options and type(options.get) == "function" then
    local ok, value = pcall(options.get, options, key)
    if ok and value ~= nil then return value end
  end
  if fallback ~= nil then return fallback end
  return schemaDefault(schema, key)
end

function Settings.set(mod, key, value, schema)
  local options = mod and mod.options
  if options and type(options.set) == "function" then
    local ok, a, b, c = pcall(options.set, options, key, value)
    if not ok then return nil, "options_set_failed", tostring(a) end
    return a, b, c
  end
  if schemaDefault(schema, key) == nil then
    return nil, "unknown_option", tostring(key)
  end
  fallbackFor(mod)[key] = value
  return true
end

Settings.schema = {
  { key = "theme", label = "THEME", type = "choice", default = "clean",
    choices = { { "CLEAN", "clean" }, { "DARK", "dark" },
      { "HIGH CONTRAST", "high_contrast" } } },
  { key = "ui_size", label = "UI SIZE", type = "choice", default = "auto",
    choices = { { "AUTO", "auto" }, { "SMALL", "small" },
      { "MEDIUM", "medium" }, { "LARGE", "large" } } },
  { key = "text_size", label = "TEXT SIZE", type = "choice", default = "auto",
    choices = { { "AUTO", "auto" }, { "1x", "1" }, { "2x", "2" },
      { "3x", "3" }, { "4x", "4" } } },
  { key = "font", label = "FONT", type = "choice", default = "plain_pixel",
    choices = { { "PLAIN PIXEL", "plain_pixel" }, { "SYSTEM", "system" } } },
  { key = "density", label = "DENSITY", type = "choice", default = "auto",
    choices = { { "AUTO", "auto" }, { "COMFORTABLE", "comfortable" },
      { "COMPACT", "compact" } } },
  { key = "pointer_touch", label = "POINTER & TOUCH", type = "toggle",
    default = false },
}

function Settings.define(mod, schema)
  if not (mod and mod.options and mod.options.define) then
    return Result.err("options_unavailable", "mod.options:define is unavailable")
  end
  schema = schema or Settings.schema
  if type(schema) ~= "table" then
    return Result.err("invalid_options_schema", "settings schema must be a table")
  end
  local ok, value = pcall(function() return mod.options:define(schema) end)
  if not ok then return Result.err("options_define_failed", value) end
  return Result.ok(value)
end

function Settings.reset(mod, extraSchema)
  local failures = {}
  local schema = extraSchema or Settings.schema
  for _, row in ipairs(schema) do
    local ok, code, message = Settings.set(mod, row.key, row.default, schema)
    if not ok then failures[#failures + 1] = { key = row.key, code = code,
      message = message } end
  end
  if #failures > 0 then return Result.err("reset_failed", "some defaults failed", failures) end
  return Result.ok(true)
end

return Settings
