local requireCore = ...
local Result = requireCore("foundation.result")

local Settings = {}
local fallbackValues = setmetatable({}, { __mode = "k" })
local persistedValues = setmetatable({}, { __mode = "k" })

local STORAGE_KEY = "settings"

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

local function contextId(context)
  if type(context) ~= "table" then return nil end
  local version = context.gameVersion
  local playthrough = context.playthroughId
  if type(version) ~= "string" or version == ""
      or type(playthrough) ~= "string" or playthrough == "" then
    return nil
  end
  return version .. ":" .. playthrough
end

local function storageAccess(mod)
  local storage = mod and mod.storage
  local game = mod and mod.game
  if type(storage) ~= "table" or game == nil then return nil end

  -- The selected facade lets the title session read/write the currently
  -- selected playthrough without inventing a new one before Continue/New Game.
  if type(storage.selected) == "function" then
    local ok, selected = pcall(storage.selected, storage, game)
    if ok and type(selected) == "table"
        and type(selected.read) == "function"
        and type(selected.write) == "function" then
      local context
      if type(selected.context) == "function" then
        local contextOk, value = pcall(selected.context, selected)
        if contextOk then context = value end
      end
      local id = contextId(context)
      if id then return { facade = selected, id = id, selected = true } end
    end
  end

  if type(storage.context) ~= "function"
      or type(storage.read) ~= "function"
      or type(storage.write) ~= "function" then
    return nil
  end
  local ok, context = pcall(storage.context, storage, game)
  local id = ok and contextId(context) or nil
  if not id then return nil end
  return { facade = storage, game = game, id = id, selected = false }
end

local function readPersisted(mod)
  local access = storageAccess(mod)
  if not access then return nil end
  local cached = persistedValues[mod]
  if cached and cached.id == access.id then return cached.values end

  local ok, values
  if access.selected then
    ok, values = pcall(access.facade.read, access.facade, STORAGE_KEY)
  else
    ok, values = pcall(access.facade.read, access.facade, access.game,
      STORAGE_KEY)
  end
  if not ok or type(values) ~= "table" then values = {} end
  persistedValues[mod] = { id = access.id, values = values }
  return values
end

local function writePersisted(mod, key, value)
  local access = storageAccess(mod)
  if not access then return false end
  local values = readPersisted(mod)
  if type(values) ~= "table" then return false end
  values[key] = value

  local ok, wrote
  if access.selected then
    ok, wrote = pcall(access.facade.write, access.facade, STORAGE_KEY, values)
  else
    ok, wrote = pcall(access.facade.write, access.facade, access.game,
      STORAGE_KEY, values)
  end
  return ok and wrote ~= false
end

-- v0.1.86 exposes the option schema and reader but not the writer. Keep the
-- V3 settings surface usable on that host: native writers still win, while
-- older hosts use public storage for a durable active-playthrough fallback and
-- retain an in-memory value only when no storage context exists.
function Settings.get(mod, key, schema, fallback)
  local values = mod and fallbackValues[mod]
  if values and values[key] ~= nil then return values[key] end
  local options = mod and mod.options
  local nativeWriter = options and type(options.set) == "function"
  if not nativeWriter then
    local persisted = readPersisted(mod)
    if persisted and persisted[key] ~= nil then return persisted[key] end
  end
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
  -- Official v0.1.86 exposes the option schema and reader but not the public
  -- writer. Keep that compatibility path durable through public storage; the
  -- in-memory value remains the safe fallback before a playthrough exists.
  writePersisted(mod, key, value)
  return true
end

Settings.schema = {
  { key = "theme", label = "THEME", type = "choice", default = "clean",
    choices = { { "CLEAN", "clean" }, { "RED", "red" },
      { "BLUE", "blue" }, { "YELLOW", "yellow" }, { "GOLD", "gold" },
      { "SILVER", "silver" }, { "CRYSTAL", "crystal" },
      { "HIGH CONTRAST", "high_contrast" } } },
  { key = "dark_mode", label = "DARK MODE", type = "toggle",
    default = false },
  { key = "ui_size", label = "UI SIZE", type = "choice", default = "auto",
    choices = { { "AUTO", "auto" }, { "SMALL", "small" },
      { "MEDIUM", "medium" }, { "LARGE", "large" } } },
  { key = "text_size", label = "TEXT SIZE", type = "choice", default = "auto",
    choices = { { "AUTO", "auto" }, { "1x", "1" }, { "2x", "2" },
      { "3x", "3" } } },
  { key = "font", label = "FONT", type = "choice", default = "openttd_mono",
    choices = { { "OPENTTD MONO", "openttd_mono" },
      { "PLAIN PIXEL", "plain_pixel" }, { "SYSTEM", "system" } } },
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
