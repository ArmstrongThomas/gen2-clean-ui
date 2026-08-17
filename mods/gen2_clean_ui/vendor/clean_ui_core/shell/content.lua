local requireCore = ...
local PresentationModel = requireCore("presentation.model")

local Content = {}

local DIRECT_V3_KINDS = PresentationModel.KINDS
local V3_PRESENTATION_SCHEMA = PresentationModel.SCHEMA

local function isPresentationModel(value)
  return PresentationModel.is(value)
end

function Content.isV3Screen(value)
  return type(value) == "table"
    and (value.type == "panel" or isPresentationModel(value))
end

local TITLES = {
  mod_menus = "MOD MENUS", settings = "CLEAN UI SETTINGS",
  compatibility = "COMPATIBILITY", gallery = "UI GALLERY",
  gallery_preview = "UI GALLERY PREVIEW",
}

local FONT_LABELS = {
  plain_pixel = "PLAIN PIXEL", system = "SYSTEM",
  openttd_mono = "OPENTTD MONO",
}

local function selectedLabel(options, value)
  for _, option in ipairs(options or {}) do
    if option.value == value then return tostring(option.label or value) end
  end
  return tostring(value == nil and "----" or value)
end

-- Convert the public V3 panel vocabulary into the shared menu model used by
-- the shell preview. This keeps V3 screen descriptors data-only while still
-- giving editor/example contracts a real interactive host target.
function Content.v3Model(screen)
  if type(screen) ~= "table" then return nil end
  if DIRECT_V3_KINDS[screen.kind] then
    return isPresentationModel(screen) and screen or nil
  end
  if screen.kind == "menu" then return screen end
  if screen.type ~= "panel" then return nil end
  local rows = {}
  for _, component in ipairs(screen.components or {}) do
    if type(component) == "table" and component.visible ~= false then
      local kind = component.type
      if kind == "label" then
        rows[#rows + 1] = { id=component.id, label=component.text or "",
          kind="v3_label", disabled=true }
      elseif kind == "button" then
        rows[#rows + 1] = { id=component.id,
          label=component.label or component.id, right=">",
          kind="v3_action", action=component.action,
          disabled=component.enabled == false }
      elseif kind == "dropdown" then
        rows[#rows + 1] = { id=component.id,
          label=component.label or component.id,
          right=selectedLabel(component.options, component.value),
          value=component.value,
          choices=component.options or {}, kind="v3_dropdown",
          action=component.action,
          disabled=component.enabled == false }
      elseif kind == "list" then
        for _, item in ipairs(component.items or {}) do
          rows[#rows + 1] = { id=tostring(component.id) .. "."
              .. tostring(item.id), label=item.label or item.id,
            right=item.value == component.value and "*" or "",
            kind="v3_item", action=component.action,
            v3ComponentId=component.id, v3ItemId=item.id,
            v3Value=item.value, disabled=component.enabled == false
              or item.disabled == true }
        end
      elseif kind == "tabs" then
        for _, tab in ipairs(component.tabs or {}) do
          rows[#rows + 1] = { id=tostring(component.id) .. "."
              .. tostring(tab.id), label=tab.label or tab.id,
            right=tab.value == component.value and "*" or "",
            kind="v3_item", action=component.action,
            v3ComponentId=component.id, v3ItemId=tab.id,
            v3Value=tab.value, disabled=component.enabled == false }
        end
      elseif kind == "details" then
        for _, field in ipairs(component.fields or {}) do
          rows[#rows + 1] = { id=tostring(component.id) .. "."
              .. tostring(field.id or field.label),
            label=field.label or field.id, right=tostring(field.value or ""),
            kind="v3_label", disabled=true }
        end
      end
    end
  end
  local footer = type(screen.footer) == "table" and screen.footer.text
    or screen.footer
  local selected = 1
  for index, row in ipairs(rows) do
    if not row.disabled then selected = index break end
  end
  return {
    schema=V3_PRESENTATION_SCHEMA, apiVersion=3,
    kind="menu", opaque=true, preset=screen.preset or "M",
    title=screen.title or screen.id or "V3 SCREEN", rows=rows, selected=selected,
    scroll=0, description=footer or "A CHOOSE   B BACK",
  }
end

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
      -- Read through the shared V3 settings adapter. The released host may
      -- expose options:define/get without options:set, so bypassing Core's
      -- session-local fallback makes a setting appear stuck at its persisted
      -- value after reset or an in-session change.
      local value = shell:setting(nil, source.key)
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
    if type(fixture.model) == "table"
        and (fixture.model.kind == "menu"
          or fixture.model.kind == "device" or fixture.model.kind == "map") then
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
      right = FONT_LABELS[preview.font] or "OPENTTD MONO" },
    }
  elseif state.view == "v3_screen" then
    local model = state.payload and state.payload.model or {}
    return model.rows or {}
  end
  return {}
end

return Content
