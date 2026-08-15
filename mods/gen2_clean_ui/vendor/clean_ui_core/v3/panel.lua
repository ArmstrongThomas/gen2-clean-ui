local requireCore = ...
local Id = requireCore("foundation.id")

local Panel = {}

local COMPONENT_TYPES = {
  label = true, button = true, list = true, dropdown = true,
  tabs = true, details = true, modal_overlay = true, status_card = true,
}

local function array(value, name, item)
  if type(value) ~= "table" then
    return nil, name .. " must be an array"
  end
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return nil, name .. " must be a dense array"
    end
    count = math.max(count, key)
  end
  for index = 1, count do
    if rawget(value, index) == nil then
      return nil, name .. " must be a dense array"
    end
    if item and type(value[index]) ~= item then
      return nil, name .. "[" .. tostring(index) .. "] must be a " .. item
    end
  end
  return true
end

local function text(value, name)
  if type(value) ~= "string" or value == "" then
    return nil, name .. " must be a non-empty string"
  end
  return true
end

local function id(value, name)
  if type(value) ~= "string" or not Id.valid(value) then
    return nil, name .. " must be a valid V3 identifier"
  end
  return true
end

local function optional(value, name, expected)
  if value ~= nil and type(value) ~= expected then
    return nil, name .. " must be a " .. expected
  end
  return true
end

local function knownFields(value, name, fields)
  for key in pairs(value) do
    if type(key) ~= "string" or not fields[key] then
      return nil, name .. "." .. tostring(key) .. " is not a supported field"
    end
  end
  return true
end

local function action(value, name)
  if value == nil then return true end
  return id(value, name)
end

local function option(value, name, requireValue)
  if type(value) ~= "table" then return nil, name .. " must be an object" end
  local ok, message = knownFields(value, name, {
    id=true, label=true, value=true, disabled=true, group=true, icon=true,
    description=true, action=true,
  })
  if not ok then return nil, message end
  ok, message = id(value.id, name .. ".id")
  if not ok then return nil, message end
  ok, message = text(value.label, name .. ".label")
  if not ok then return nil, message end
  if requireValue and value.value == nil then
    return nil, name .. ".value is required"
  end
  ok, message = optional(value.disabled, name .. ".disabled", "boolean")
  if not ok then return nil, message end
  for _, field in ipairs({ "group", "icon", "description" }) do
    ok, message = optional(value[field], name .. "." .. field, "string")
    if not ok then return nil, message end
  end
  return true
end

local function optionArray(value, name, requireValue)
  local ok, message = array(value, name, "table")
  if not ok then return nil, message end
  for index, item in ipairs(value) do
    ok, message = option(item, name .. "[" .. tostring(index) .. "]",
      requireValue)
    if not ok then return nil, message end
  end
  return true
end

local function field(value, name)
  if type(value) ~= "table" then return nil, name .. " must be an object" end
  local ok, message = knownFields(value, name,
    { id=true, label=true, value=true, style=true })
  if not ok then return nil, message end
  ok, message = id(value.id, name .. ".id")
  if not ok then return nil, message end
  ok, message = text(value.label, name .. ".label")
  if not ok then return nil, message end
  if value.style ~= nil and type(value.style) ~= "string"
      and type(value.style) ~= "table" then
    return nil, name .. ".style must be a string or table"
  end
  return true
end

local function fieldArray(value, name)
  local ok, message = array(value, name, "table")
  if not ok then return nil, message end
  for index, item in ipairs(value) do
    ok, message = field(item, name .. "[" .. tostring(index) .. "]")
    if not ok then return nil, message end
  end
  return true
end

local function footerList(value, name)
  if type(value) ~= "table" then return nil, name .. " must be an object" end
  local ok, message = knownFields(value, name, { id=true, title=true, items=true })
  if not ok then return nil, message end
  ok, message = id(value.id, name .. ".id")
  if not ok then return nil, message end
  ok, message = text(value.title, name .. ".title")
  if not ok then return nil, message end
  ok, message = array(value.items, name .. ".items", "table")
  if not ok then return nil, message end
  for index, item in ipairs(value.items) do
    ok, message = knownFields(item, name .. ".items[" .. tostring(index) .. "]",
      { label=true, value=true })
    if not ok then return nil, message end
    if type(item.label) ~= "string" or item.label == "" then
      return nil, name .. ".items[" .. tostring(index) .. "].label must be a non-empty string"
    end
  end
  return true
end

local function footerLists(value, name)
  local ok, message = array(value, name, "table")
  if not ok then return nil, message end
  for index, item in ipairs(value) do
    ok, message = footerList(item, name .. "[" .. tostring(index) .. "]")
    if not ok then return nil, message end
  end
  return true
end

local function component(value, name)
  if type(value) ~= "table" then return nil, name .. " must be an object" end
  local ok, message = knownFields(value, name, {
    type=true, id=true, visible=true, enabled=true, label=true,
    description=true, style=true, layout=true, action=true, text=true,
    value=true, items=true, options=true, tabs=true, title=true,
    sprite=true, fields=true, custom_fields=true, footer_lists=true,
    layout_options=true, message=true, dim_background=true, dim_opacity=true,
    cancelable=true, screen_id=true, support=true, reason=true, milestone=true,
  })
  if not ok then return nil, message end
  ok, message = id(value.id, name .. ".id")
  if not ok then return nil, message end
  if not COMPONENT_TYPES[value.type] then
    return nil, name .. ".type is not a registered V3 component"
  end
  for _, fieldName in ipairs({ "visible", "enabled" }) do
    ok, message = optional(value[fieldName], name .. "." .. fieldName, "boolean")
    if not ok then return nil, message end
  end
  for _, fieldName in ipairs({ "label", "description" }) do
    ok, message = optional(value[fieldName], name .. "." .. fieldName, "string")
    if not ok then return nil, message end
  end
  ok, message = action(value.action, name .. ".action")
  if not ok then return nil, message end
  ok, message = optional(value.layout, name .. ".layout", "table")
  if not ok then return nil, message end
  if value.style ~= nil and type(value.style) ~= "string"
      and type(value.style) ~= "table" then
    return nil, name .. ".style must be a string or table"
  end

  if value.type == "label" then
    return text(value.text, name .. ".text")
  elseif value.type == "button" then
    return text(value.label, name .. ".label")
  elseif value.type == "list" then
    return optionArray(value.items, name .. ".items", false)
  elseif value.type == "dropdown" then
    return optionArray(value.options, name .. ".options", true)
  elseif value.type == "tabs" then
    return optionArray(value.tabs, name .. ".tabs", true)
  elseif value.type == "details" then
    if value.fields == nil and value.custom_fields == nil then
      return nil, name .. " requires fields or custom_fields"
    end
    if value.fields ~= nil then
      ok, message = fieldArray(value.fields, name .. ".fields")
      if not ok then return nil, message end
    end
    if value.custom_fields ~= nil then
      if type(value.custom_fields) ~= "table" then
        return nil, name .. ".custom_fields must be an object"
      end
      ok, message = knownFields(value.custom_fields,
        name .. ".custom_fields", { columns=true, data=true })
      if not ok then return nil, message end
      if value.custom_fields.columns ~= nil then
        local columns = value.custom_fields.columns
        if type(columns) ~= "number" or columns < 1
            or columns ~= math.floor(columns) then
          return nil, name .. ".custom_fields.columns must be a positive integer"
        end
      end
      if value.custom_fields.data ~= nil then
        ok, message = fieldArray(value.custom_fields.data,
          name .. ".custom_fields.data")
        if not ok then return nil, message end
      end
    end
    if value.footer_lists ~= nil then
      ok, message = footerLists(value.footer_lists, name .. ".footer_lists")
      if not ok then return nil, message end
    end
    if value.layout_options ~= nil then
      ok, message = optional(value.layout_options, name .. ".layout_options", "table")
      if not ok then return nil, message end
    end
    if value.sprite ~= nil and type(value.sprite) ~= "table" then
      return nil, name .. ".sprite must be an object"
    end
    return true
  elseif value.type == "modal_overlay" then
    ok, message = text(value.title, name .. ".title")
    if not ok then return nil, message end
    ok, message = text(value.message, name .. ".message")
    if not ok then return nil, message end
    ok, message = optionArray(value.options, name .. ".options", false)
    if not ok then return nil, message end
    for index, item in ipairs(value.options) do
      ok, message = action(item.action, name .. ".options["
        .. tostring(index) .. "].action")
      if not ok then return nil, message end
    end
    for _, fieldName in ipairs({ "dim_background", "cancelable" }) do
      ok, message = optional(value[fieldName], name .. "." .. fieldName, "boolean")
      if not ok then return nil, message end
    end
    ok, message = optional(value.dim_opacity, name .. ".dim_opacity", "number")
    if not ok then return nil, message end
    return true
  elseif value.type == "status_card" then
    ok, message = text(value.screen_id, name .. ".screen_id")
    if not ok then return nil, message end
    for _, fieldName in ipairs({ "support", "reason", "milestone" }) do
      ok, message = optional(value[fieldName], name .. "." .. fieldName, "string")
      if not ok then return nil, message end
    end
    return true
  end
  return true
end

function Panel.validate(screen)
  if type(screen) ~= "table" then return nil, "panel must be an object" end
  local ok, message = knownFields(screen, "panel", {
    id=true, type=true, title=true, preset=true, header=true,
    components=true, footer=true,
  })
  if not ok then return nil, message end
  if screen.type ~= "panel" then return nil, "panel.type must be panel" end
  ok, message = id(screen.id, "panel.id")
  if not ok then return nil, message end
  ok, message = text(screen.preset, "panel.preset")
  if not ok then return nil, message end
  ok, message = array(screen.components, "panel.components", "table")
  if not ok then return nil, message end
  local componentIds = {}
  for index, value in ipairs(screen.components) do
    if type(value) == "table" and value.id ~= nil and componentIds[value.id] then
      return nil, "panel.components[" .. tostring(index)
        .. "].id must be unique"
    end
    if type(value) == "table" and value.id ~= nil then
      componentIds[value.id] = true
    end
    ok, message = component(value, "panel.components[" .. tostring(index) .. "]")
    if not ok then return nil, message end
  end
  if screen.title ~= nil then
    ok, message = optional(screen.title, "panel.title", "string")
    if not ok then return nil, message end
  end
  if screen.header ~= nil then
    ok, message = optional(screen.header, "panel.header", "table")
    if not ok then return nil, message end
  end
  if screen.footer ~= nil and type(screen.footer) ~= "string"
      and type(screen.footer) ~= "table" then
    return nil, "panel.footer must be a string or object"
  end
  if type(screen.footer) == "table" and screen.footer.text ~= nil
      and type(screen.footer.text) ~= "string" then
    return nil, "panel.footer.text must be a string"
  end
  return true
end

return Panel
