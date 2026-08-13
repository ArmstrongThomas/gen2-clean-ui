local requireCore = ...

local Content = {}

local TITLES = {
  mod_menus = "MOD MENUS", settings = "CLEAN UI SETTINGS",
  compatibility = "COMPATIBILITY", gallery = "UI GALLERY",
  gallery_preview = "UI GALLERY PREVIEW",
}

local function choiceLabel(row, value)
  for _, choice in ipairs(row.choices or {}) do
    if choice[2] == value then return tostring(choice[1]) end
  end
  return tostring(value == nil and "----" or value)
end

local function optionRows(shell, compatibility)
  local rows = {}
  for _, source in ipairs(shell.core.settingsSchema or {}) do
    local native = tostring(source.key):match("^native_") ~= nil
    if native == compatibility then
      local value = shell.mod.options:get(source.key)
      rows[#rows + 1] = {
        id = source.key, label = source.label or source.key,
        kind = source.type, value = value, choices = source.choices,
        right = source.type == "toggle" and (value and "ON" or "OFF")
          or choiceLabel(source, value), source = source,
      }
    end
  end
  return rows
end

local function fixtures(payload)
  local out = {}
  local source = type(payload) == "table" and payload or {}
  local seen = {}
  local collections = {}
  local function append(collection)
    if type(collection) ~= "table" then return end
    if collections[collection] then return end
    collections[collection] = true
    if type(collection.id) == "string"
        or type(collection.screenId) == "string" then
      if not seen[collection] then
        seen[collection], out[#out + 1] = true, collection
      end
      return
    end
    local numeric = {}
    for key in pairs(collection) do
      if type(key) == "number" then numeric[#numeric + 1] = key end
    end
    table.sort(numeric)
    for _, key in ipairs(numeric) do
      local fixture = collection[key]
      append(fixture)
    end
    local named = {}
    for key in pairs(collection) do
      if type(key) ~= "number" then named[#named + 1] = key end
    end
    table.sort(named, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(named) do
      local fixture = collection[key]
      if key ~= "count" and key ~= "game" and key ~= "filter"
          and key ~= "sourceContract" then append(fixture) end
    end
  end
  if source.fixture then
    append(source.fixture)
  elseif source.fixtures then
    append(source.fixtures)
  elseif source.records then
    append(source.records)
  else
    append(source)
  end
  return out
end

function Content.fixtures(payload) return fixtures(payload) end

function Content.families(payload)
  local found = {}
  for _, fixture in ipairs(fixtures(payload)) do
    found[tostring(fixture.family or "other")] = true
  end
  local out = {}
  for family in pairs(found) do out[#out + 1] = family end
  table.sort(out)
  return out
end

function Content.title(view) return TITLES[view] or "CLEAN UI" end

function Content.rows(shell, state)
  if state.view == "settings" then
    local rows = optionRows(shell, false)
    rows[#rows + 1] = { id = "__compatibility", kind = "open",
      label = "COMPATIBILITY", right = ">" }
    rows[#rows + 1] = { id = "__reset", kind = "reset",
      label = "RESET DEFAULTS", right = "" }
    return rows
  elseif state.view == "compatibility" then
    return optionRows(shell, true)
  elseif state.view == "mod_menus" then
    local rows = {}
    for _, source in ipairs(shell.core:modMenuRows()) do
      rows[#rows + 1] = {
        id = source.id, label = source.label, kind = "mod_action",
        pinned = source.pinned, pinnable = source.pinnable,
        right = source.pinnable and "" or "ID REQUIRED", source = source,
      }
    end
    return rows
  elseif state.view == "gallery" then
    local rows = {}
    local families = Content.families(state.payload)
    local family = families[state.galleryFamily or 1]
    for index, fixture in ipairs(fixtures(state.payload)) do
      if not family or tostring(fixture.family or "other") == family then
        rows[#rows + 1] = {
        id = fixture.id or fixture.screenId or ("fixture." .. index),
        label = fixture.label or fixture.title or fixture.id
          or fixture.screenId or ("FIXTURE " .. index),
        right = tostring(fixture.support or fixture.status or "PREVIEW"):upper(),
        kind = "gallery", source = fixture,
      }
      end
    end
    return rows
  elseif state.view == "gallery_preview" then
    local fixture = state.payload and (state.payload.fixture or state.payload) or {}
    local preview = state.preview or {}
    if type(fixture.model) == "table" and fixture.model.kind == "menu" then
      local rows = {}
      for _, source in ipairs(fixture.model.rows or {}) do
        rows[#rows + 1] = {
          id = source.id, label = source.label, right = source.right,
          kind = "preview_row", source = source,
        }
      end
      return rows
    end
    return {
      { id = "id", label = "ID", right = tostring(fixture.id or "UNKNOWN") },
      { id = "family", label = "FAMILY",
        right = tostring(fixture.family or "UNKNOWN"):upper() },
      { id = "support", label = "SUPPORT",
        right = tostring(fixture.support or fixture.status or "PREVIEW"):upper() },
      { id = "preset", label = "PRESET", right = tostring(fixture.preset or "--") },
      { id = "reason", label = "REASON",
        right = tostring(fixture.reason or fixture.nativeReason or "Synthetic fixture") },
      { id = "content", label = "CONTENT",
        right = tostring(preview.content or "NORMAL") },
      { id = "ui_size", label = "UI SIZE",
        right = tostring(preview.ui_size or "AUTO"):upper() },
      { id = "text_size", label = "TEXT SIZE",
        right = tostring(preview.text_size or "AUTO"):upper() },
      { id = "font", label = "FONT",
        right = preview.font == "system" and "SYSTEM" or "PLAIN PIXEL" },
    }
  end
  return {}
end

return Content
