local requireCore = ...
local Result = requireCore("foundation.result")

local Settings = {}

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
    default = true },
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
  if not (mod and mod.options and mod.options.set) then
    return Result.err("option_writer_unavailable", "mod.options:set is required")
  end
  local failures = {}
  for _, row in ipairs(extraSchema or Settings.schema) do
    local ok, code, message = mod.options:set(row.key, row.default)
    if not ok then failures[#failures + 1] = { key = row.key, code = code,
      message = message } end
  end
  if #failures > 0 then return Result.err("reset_failed", "some defaults failed", failures) end
  return Result.ok(true)
end

return Settings
