local Model = {}

Model.SCHEMA = "clean_ui.v3.presentation.v1"
Model.KINDS = {
  menu = true,
  dialogue = true,
  choice = true,
  battle = true,
  animation = true,
  device = true,
  map = true,
  document = true,
}

-- Presentation collections are ordered data, not arbitrary JSON objects. A
-- dense-array check catches the most common integration mistakes (a keyed
-- map, a missing middle entry, or a scalar row) before layout code receives
-- the model. Empty collections remain valid for source-owned transitional
-- states such as a battle message or a saving screen.
local function collection(value, name, itemType)
  if type(value) ~= "table" then
    return nil, name .. " must be a table"
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
    if itemType and type(value[index]) ~= itemType then
      return nil, (name .. "[" .. tostring(index) .. "] must be a "
        .. itemType)
    end
  end
  return count
end

local function indexField(value, name)
  if value == nil then return true end
  if type(value) ~= "number" or value < 1 or value % 1 ~= 0 then
    return nil, name .. " must be a positive integer when present"
  end
  return true
end

local function overlayShape(value, name)
  if type(value) ~= "table" then
    return nil, name .. " must be a table"
  end
  for _, field in ipairs({ "x", "y", "w", "h" }) do
    local number = value[field]
    if type(number) ~= "number" or number ~= number
        or number == math.huge or number == -math.huge then
      return nil, name .. "." .. field .. " must be finite"
    end
  end
  if value.x < 0 or value.y < 0 or value.w <= 0 or value.h <= 0
      or value.x + value.w > 1 or value.y + value.h > 1 then
    return nil, name .. " must fit within normalized bounds"
  end
  if value.color ~= nil then
    if type(value.color) ~= "table" then
      return nil, name .. ".color must be an RGB or RGBA array"
    end
    for key in pairs(value.color) do
      if type(key) ~= "number" or key < 1 or key > 4
          or key % 1 ~= 0 then
        return nil, name .. ".color must be an RGB or RGBA array"
      end
    end
    for index = 1, 4 do
      local channel = value.color[index]
      if channel ~= nil
          and (type(channel) ~= "number" or channel ~= channel
            or channel == math.huge or channel == -math.huge
            or channel < 0 or channel > 1) then
        return nil, name .. ".color channels must be between 0 and 1"
      end
    end
    if value.color[1] == nil or value.color[2] == nil
        or value.color[3] == nil then
      return nil, name .. ".color requires RGB channels"
    end
  end
  return true
end

local function circleShape(value, name)
  if type(value) ~= "table" then
    return nil, name .. " must be a table"
  end
  for _, field in ipairs({ "x", "y", "radius" }) do
    local number = value[field]
    if type(number) ~= "number" or number ~= number
        or number == math.huge or number == -math.huge then
      return nil, name .. "." .. field .. " must be finite"
    end
  end
  if value.x < -1 or value.x > 2 or value.y < -1 or value.y > 2 then
    return nil, name .. ".x/.y must be normalized within [-1, 2]"
  end
  if value.radius <= 0 or value.radius > 1 then
    return nil, name .. ".radius must be normalized within (0, 1]"
  end
  if value.color ~= nil then
    if type(value.color) ~= "table" then
      return nil, name .. ".color must be an RGB or RGBA array"
    end
    for key in pairs(value.color) do
      if type(key) ~= "number" or key < 1 or key > 4
          or key % 1 ~= 0 then
        return nil, name .. ".color must be an RGB or RGBA array"
      end
    end
    for index = 1, 4 do
      local channel = value.color[index]
      if channel ~= nil
          and (type(channel) ~= "number" or channel ~= channel
            or channel == math.huge or channel == -math.huge
            or channel < 0 or channel > 1) then
        return nil, name .. ".color channels must be between 0 and 1"
      end
    end
    if value.color[1] == nil or value.color[2] == nil
        or value.color[3] == nil then
      return nil, name .. ".color requires RGB channels"
    end
  end
  return true
end

local function tilemapShape(value, name)
  if type(value) ~= "table" then
    return nil, name .. " must be a table"
  end
  if type(value.path) ~= "string" or value.path == "" then
    return nil, name .. ".path must be a non-empty string"
  end
  for _, field in ipairs({ "tileWidth", "tileHeight", "mapWidth",
      "mapHeight", "sheetColumns" }) do
    local number = value[field]
    if type(number) ~= "number" or number ~= math.floor(number)
        or number <= 0 then
      return nil, name .. "." .. field .. " must be a positive integer"
    end
  end
  for _, field in ipairs({ "logicalWidth", "logicalHeight" }) do
    local number = value[field]
    if number ~= nil and (type(number) ~= "number" or number <= 0
        or number ~= number or number == math.huge
        or number == -math.huge) then
      return nil, name .. "." .. field .. " must be positive and finite"
    end
  end
  for _, field in ipairs({ "scrollX", "scrollY" }) do
    local number = value[field]
    if number ~= nil and (type(number) ~= "number" or number ~= number
        or number == math.huge or number == -math.huge) then
      return nil, name .. "." .. field .. " must be finite"
    end
  end
  local tileCount, tileError = collection(value.tiles, name .. ".tiles",
    "number")
  if not tileCount then return nil, tileError end
  local expected = value.mapWidth * value.mapHeight
  if tileCount ~= expected then
    return nil, name .. ".tiles must contain exactly mapWidth * mapHeight tiles"
  end
  for index, tile in ipairs(value.tiles) do
    if tile ~= math.floor(tile) or tile < 0 then
      return nil, name .. ".tiles[" .. tostring(index)
        .. "] must be a non-negative integer"
    end
  end
  if value.scanlineOffsets ~= nil then
    local lineCount, lineError = collection(value.scanlineOffsets,
      name .. ".scanlineOffsets", "table")
    if not lineCount then return nil, lineError end
    if value.logicalHeight ~= nil
        and lineCount ~= math.floor(value.logicalHeight) then
      return nil, name .. ".scanlineOffsets must match logicalHeight"
    end
    for index, offset in ipairs(value.scanlineOffsets) do
      for _, field in ipairs({ "x", "y" }) do
        local number = offset[field]
        if type(number) ~= "number" or number ~= number
            or number == math.huge or number == -math.huge then
          return nil, name .. ".scanlineOffsets[" .. tostring(index)
            .. "]." .. field .. " must be finite"
        end
      end
    end
  end
  return true
end

local function positiveInteger(value)
  return type(value) == "number" and value == math.floor(value)
    and value > 0
end

local function nonEmptyString(value)
  return type(value) == "string" and value ~= ""
end

local function deviceShape(value, name)
  if type(value) ~= "table" then
    return nil, name .. " must be a device descriptor"
  end
  if not nonEmptyString(value.kind) then
    return nil, name .. ".kind must be a non-empty string"
  end
  if value.family ~= nil and not nonEmptyString(value.family) then
    return nil, name .. ".family must be a non-empty string when present"
  end
  if value.title ~= nil and not nonEmptyString(value.title) then
    return nil, name .. ".title must be a non-empty string when present"
  end
  if value.orientation ~= nil and value.orientation ~= "portrait"
      and value.orientation ~= "landscape" then
    return nil, name .. ".orientation must be portrait or landscape"
  end
  if value.aspect ~= nil then
    if type(value.aspect) == "string" then
      if value.aspect == "" then
        return nil, name .. ".aspect must not be empty"
      end
    elseif type(value.aspect) == "table" then
      if not positiveInteger(value.aspect.w)
          or not positiveInteger(value.aspect.h) then
        return nil, name .. ".aspect requires positive integer w and h"
      end
    else
      return nil, name .. ".aspect must be a ratio string or table"
    end
  end
  return true
end

local function mapMarkerShape(value, name)
  if type(value) ~= "table" then
    return nil, name .. " must be a marker table"
  end
  if value.name ~= nil and not nonEmptyString(value.name) then
    return nil, name .. ".name must be a non-empty string when present"
  end
  if value.id ~= nil and not nonEmptyString(value.id) then
    return nil, name .. ".id must be a non-empty string when present"
  end
  for _, field in ipairs({ "x", "y" }) do
    local number = value[field]
    if number ~= nil and (type(number) ~= "number" or number ~= number
        or number == math.huge or number == -math.huge) then
      return nil, name .. "." .. field .. " must be finite when present"
    end
  end
  if value.index ~= nil and not positiveInteger(value.index) then
    return nil, name .. ".index must be a positive integer when present"
  end
  if value.nest ~= nil and type(value.nest) ~= "boolean" then
    return nil, name .. ".nest must be boolean when present"
  end
  return true
end

local function mapTileArray(value, name, expected)
  local count, collectionError = collection(value, name, "number")
  if not count then return nil, collectionError end
  if count ~= expected then
    return nil, name .. " must contain exactly width * height tiles"
  end
  for index, tile in ipairs(value) do
    if tile ~= math.floor(tile) or tile < 0 then
      return nil, name .. "[" .. tostring(index)
        .. "] must be a non-negative integer"
    end
  end
  return true
end

local function mapGraphicShape(value, name)
  if type(value) ~= "table" then
    return nil, name .. " must be a tilemap descriptor"
  end
  if value.kind ~= "tilemap" then
    return nil, name .. ".kind must be tilemap"
  end
  if not positiveInteger(value.width) or not positiveInteger(value.height) then
    return nil, name .. " requires positive integer width and height"
  end
  if type(value.sheet) ~= "table"
      or not nonEmptyString(value.sheet.path or value.sheet.asset)
      or not positiveInteger(value.sheet.wide) then
    return nil, name .. ".sheet requires path and positive integer wide"
  end
  local expected = value.width * value.height
  if value.map ~= nil then
    local valid, mapError = mapTileArray(value.map, name .. ".map", expected)
    if not valid then return nil, mapError end
  end
  if value.maps ~= nil then
    if type(value.maps) ~= "table" then
      return nil, name .. ".maps must be a table"
    end
    for region, tiles in pairs(value.maps) do
      if type(region) ~= "string" then
        return nil, name .. ".maps keys must be strings"
      end
      local valid, mapError = mapTileArray(tiles,
        name .. ".maps." .. region, expected)
      if not valid then return nil, mapError end
    end
  end
  if value.cursorSheet ~= nil then
    if type(value.cursorSheet) ~= "table"
        or not nonEmptyString(value.cursorSheet.path
          or value.cursorSheet.asset)
        or not positiveInteger(value.cursorSheet.wide) then
      return nil, name .. ".cursorSheet requires path and positive integer wide"
    end
  end
  return true
end

local function mapShape(value, name)
  if type(value) ~= "table" then
    return nil, name .. " must be a map descriptor"
  end
  if not nonEmptyString(value.region) then
    return nil, name .. ".region must be a non-empty string"
  end
  local count, collectionError = collection(value.rows, name .. ".rows",
    "table")
  if not count then return nil, collectionError end
  for index, marker in ipairs(value.rows) do
    local valid, markerError = mapMarkerShape(marker,
      name .. ".rows[" .. tostring(index) .. "]")
    if not valid then return nil, markerError end
  end
  if value.flyRows ~= nil then
    local flyCount, flyError = collection(value.flyRows, name .. ".flyRows",
      "table")
    if not flyCount then return nil, flyError end
    for index, marker in ipairs(value.flyRows) do
      local valid, markerError = mapMarkerShape(marker,
        name .. ".flyRows[" .. tostring(index) .. "]")
      if not valid then return nil, markerError end
    end
  end
  local ok, errorMessage = indexField(value.flyIndex, name .. ".flyIndex")
  if not ok then return nil, errorMessage end
  for _, field in ipairs({ "current", "player" }) do
    if value[field] ~= nil and type(value[field]) ~= "table" then
      return nil, name .. "." .. field .. " must be a table when present"
    end
  end
  if value.graphic ~= nil then
    local valid, graphicError = mapGraphicShape(value.graphic,
      name .. ".graphic")
    if not valid then return nil, graphicError end
  end
  return true
end

local DOCUMENT_COMPONENTS = {
  heading = true, label = true, text = true, image = true, badges = true,
  metadata = true, list = true, map = true, divider = true,
}

local function documentControls(value, name)
  if value == nil or type(value) == "string" then return true end
  local count, collectionError = collection(value, name, "table")
  if not count then return nil, collectionError end
  for index, control in ipairs(value) do
    local path = name .. "[" .. tostring(index) .. "]"
    if not nonEmptyString(control.input) or not nonEmptyString(control.label) then
      return nil, path .. " requires input and label strings"
    end
    if control.action ~= nil and not nonEmptyString(control.action) then
      return nil, path .. ".action must be a non-empty string when present"
    end
  end
  return true
end

local function documentComponentShape(value, name)
  if type(value) ~= "table" then
    return nil, name .. " must be a component table"
  end
  if not nonEmptyString(value.type)
      or not DOCUMENT_COMPONENTS[value.type] then
    return nil, name .. ".type is not a supported document component"
  end
  if value.id ~= nil and not nonEmptyString(value.id) then
    return nil, name .. ".id must be a non-empty string when present"
  end
  local componentType = value.type
  if componentType == "heading" or componentType == "label" then
    if not nonEmptyString(value.text) then
      return nil, name .. ".text must be a non-empty string"
    end
  elseif componentType == "text" then
    local count, collectionError = collection(value.lines, name .. ".lines",
      "string")
    if not count then return nil, collectionError end
  elseif componentType == "image" then
    if not nonEmptyString(value.asset or value.path) then
      return nil, name .. " requires a non-empty asset or path"
    end
  elseif componentType == "badges" then
    local count, collectionError = collection(value.values, name .. ".values",
      "string")
    if not count then return nil, collectionError end
  elseif componentType == "metadata" or componentType == "list" then
    local count, collectionError = collection(value.items, name .. ".items",
      "table")
    if not count then return nil, collectionError end
    for index, item in ipairs(value.items) do
      local path = name .. ".items[" .. tostring(index) .. "]"
      if not nonEmptyString(item.label) then
        return nil, path .. ".label must be a non-empty string"
      end
      if item.value ~= nil and type(item.value) ~= "string"
          and type(item.value) ~= "number" then
        return nil, path .. ".value must be a string or number"
      end
    end
  elseif componentType == "map" then
    local valid, mapError = mapShape(value.map, name .. ".map")
    if not valid then return nil, mapError end
  end
  return true
end

local function documentShape(value, name)
  if type(value) ~= "table" then
    return nil, name .. " must be a document descriptor"
  end
  local count, collectionError = collection(value.regions, name .. ".regions",
    "table")
  if not count then return nil, collectionError end
  for index, region in ipairs(value.regions) do
    local path = name .. ".regions[" .. tostring(index) .. "]"
    if not nonEmptyString(region.id) or not nonEmptyString(region.role) then
      return nil, path .. " requires id and role strings"
    end
    local components, componentsError = collection(region.components,
      path .. ".components", "table")
    if not components then return nil, componentsError end
    for componentIndex, component in ipairs(region.components) do
      local valid, componentError = documentComponentShape(component,
        path .. ".components[" .. tostring(componentIndex) .. "]")
      if not valid then return nil, componentError end
    end
    for _, field in ipairs({ "priority", "minWidth", "preferredWidth" }) do
      if region[field] ~= nil
          and (type(region[field]) ~= "number" or region[field] ~= region[field]
            or region[field] < 0) then
        return nil, path .. "." .. field
          .. " must be a finite non-negative number"
      end
    end
    if region.collapse ~= nil and region.collapse ~= "stack"
        and region.collapse ~= "hide_optional" then
      return nil, path .. ".collapse must be stack or hide_optional"
    end
    if region.overflow ~= nil and region.overflow ~= "clip"
        and region.overflow ~= "scroll" then
      return nil, path .. ".overflow must be clip or scroll"
    end
  end
  local controlsOk, controlsError = documentControls(value.controls,
    name .. ".controls")
  if not controlsOk then return nil, controlsError end
  if value.focus ~= nil then
    if type(value.focus) ~= "table" then
      return nil, name .. ".focus must be a table"
    end
    if value.focus.initial ~= nil and not nonEmptyString(value.focus.initial) then
      return nil, name .. ".focus.initial must be a non-empty string"
    end
    if value.focus.order ~= nil then
      local focusCount, focusError = collection(value.focus.order,
        name .. ".focus.order", "string")
      if not focusCount then return nil, focusError end
    end
  end
  return true
end

local function finiteNumber(value)
  return type(value) == "number" and value == value
    and value ~= math.huge and value ~= -math.huge
end

local function colorShape(value, name)
  local count, collectionError = collection(value, name, "number")
  if not count then return nil, collectionError end
  if count ~= 3 and count ~= 4 then
    return nil, name .. " must contain RGB or RGBA channels"
  end
  for index, channel in ipairs(value) do
    if not finiteNumber(channel) or channel < 0 then
      return nil, name .. " channels must be finite and non-negative"
    end
  end
  return true
end

local function paletteShape(value, name)
  if type(value) ~= "table" then
    return nil, name .. " must be a palette array"
  end
  local colors = type(value.colors) == "table" and value.colors or value
  local colorsName = colors == value and name or name .. ".colors"
  local count, collectionError = collection(colors, colorsName, "table")
  if not count then return nil, collectionError end
  if count == 0 then return nil, colorsName .. " must not be empty" end
  for index, color in ipairs(colors) do
    local valid, colorError = colorShape(color,
      colorsName .. "[" .. tostring(index) .. "]")
    if not valid then return nil, colorError end
  end
  return true
end

local function spriteShape(value, name)
  if type(value) ~= "table" then
    return nil, name .. " must be a sprite descriptor"
  end
  local path = value.path or value.asset
  if type(path) ~= "string" or path == "" then
    return nil, name .. ".path must be a non-empty asset path"
  end
  if value.assetPath ~= nil then
    if type(value.assetPath) ~= "string"
        or value.assetPath:sub(1, 9) ~= "overrides/"
        or value.assetPath:find("..", 1, true)
        or value.assetPath:find("\\", 1, true)
        or value.assetPath:find(":", 1, true) then
      return nil, name .. ".assetPath must be a safe overrides-relative path"
    end
  end
  if value.normalized ~= nil and type(value.normalized) ~= "boolean" then
    return nil, name .. ".normalized must be boolean"
  end
  local rect = value.rect or value
  if type(rect) ~= "table" then
    return nil, name .. ".rect must be a table"
  end
  for _, field in ipairs({ "x", "y", "w", "h" }) do
    if not finiteNumber(rect[field]) then
      return nil, name .. ".rect." .. field .. " must be finite"
    end
  end
  if rect.w <= 0 or rect.h <= 0 then
    return nil, name .. ".rect.w/.h must be positive"
  end
  for _, field in ipairs({ "flipX", "flipY" }) do
    if value[field] ~= nil and type(value[field]) ~= "boolean" then
      return nil, name .. "." .. field .. " must be boolean"
    end
  end
  if value.crop ~= nil then
    if type(value.crop) ~= "table" then
      return nil, name .. ".crop must be a table"
    end
    for _, field in ipairs({ "x", "y", "w", "h" }) do
      local number = value.crop[field]
      if type(number) ~= "number" or number ~= math.floor(number)
          or number ~= number or number == math.huge
          or number == -math.huge then
        return nil, name .. ".crop." .. field .. " must be an integer"
      end
    end
    if value.crop.x < 0 or value.crop.y < 0
        or value.crop.w <= 0 or value.crop.h <= 0 then
      return nil, name .. ".crop must use a non-negative origin and positive size"
    end
  end
  if value.palette ~= nil then
    local valid, paletteError = paletteShape(value.palette, name .. ".palette")
    if not valid then return nil, paletteError end
  end
  return true
end

local function spritesShape(value, name)
  local count, collectionError = collection(value, name, "table")
  if not count then return nil, collectionError end
  for index, sprite in ipairs(value) do
    local valid, spriteError = spriteShape(sprite,
      name .. "[" .. tostring(index) .. "]")
    if not valid then return nil, spriteError end
  end
  return true
end

local function labelShape(value, name)
  if type(value) ~= "table" then
    return nil, name .. " must be a table"
  end
  if type(value.text) ~= "string" then
    return nil, name .. ".text must be a string"
  end
  for _, field in ipairs({ "x", "y" }) do
    local number = value[field]
    if type(number) ~= "number" or number ~= number
        or number == math.huge or number == -math.huge then
      return nil, name .. "." .. field .. " must be finite"
    end
    if number < 0 or number > 1 then
      return nil, name .. "." .. field .. " must be normalized"
    end
  end
  if value.align ~= nil and value.align ~= "left"
      and value.align ~= "center" and value.align ~= "right" then
    return nil, name .. ".align must be left, center, or right"
  end
  if value.maxWidth ~= nil then
    local width = value.maxWidth
    if type(width) ~= "number" or width ~= width
        or width == math.huge or width == -math.huge
        or width <= 0 or width > 1 then
      return nil, name .. ".maxWidth must be normalized"
    end
  end
  if value.color ~= nil then
    local color = value.color
    if type(color) ~= "table" then
      return nil, name .. ".color must be an RGB or RGBA array"
    end
    for key in pairs(color) do
      if type(key) ~= "number" or key < 1 or key > 4
          or key % 1 ~= 0 then
        return nil, name .. ".color must be an RGB or RGBA array"
      end
    end
    for index = 1, 4 do
      local channel = color[index]
      if channel ~= nil
          and (type(channel) ~= "number" or channel ~= channel
            or channel == math.huge or channel == -math.huge
            or channel < 0 or channel > 1) then
        return nil, name .. ".color channels must be between 0 and 1"
      end
    end
    if color[1] == nil or color[2] == nil or color[3] == nil then
      return nil, name .. ".color requires RGB channels"
    end
  end
  return true
end

local function nonNegativeInteger(value, name)
  if value == nil then return true end
  if type(value) ~= "number" or value ~= math.floor(value) or value < 0 then
    return nil, name .. " must be a non-negative integer when present"
  end
  return true
end

local function namingShape(value, name)
  if type(value) ~= "table" then
    return nil, name .. " must be a naming descriptor"
  end
  local entry = value.entry
  if type(entry) ~= "table" or type(entry.text) ~= "string" then
    return nil, name .. ".entry.text must be a string"
  end
  for _, field in ipairs({ "maxLength", "sourceLength" }) do
    local number = entry[field]
    if number ~= nil and (type(number) ~= "number"
        or number ~= math.floor(number) or number < 0) then
      return nil, name .. ".entry." .. field
        .. " must be a non-negative integer when present"
    end
  end
  if entry.maxLength ~= nil and entry.maxLength < 1 then
    return nil, name .. ".entry.maxLength must be positive"
  end
  if entry.glyphs ~= nil then
    local glyphCount, glyphError = collection(entry.glyphs,
      name .. ".entry.glyphs", "string")
    if not glyphCount then return nil, glyphError end
    if entry.maxLength ~= nil and glyphCount > entry.maxLength then
      return nil, name .. ".entry.glyphs exceeds maxLength"
    end
  end
  if value.case ~= nil and value.case ~= "upper" and value.case ~= "lower" then
    return nil, name .. ".case must be upper or lower when present"
  end

  local keyboard = value.keyboard
  if type(keyboard) ~= "table" then
    return nil, name .. ".keyboard must be a table"
  end
  local columns = keyboard.columns
  if type(columns) ~= "number" or columns ~= math.floor(columns)
      or columns < 1 then
    return nil, name .. ".keyboard.columns must be a positive integer"
  end
  local rowCount, rowError = collection(keyboard.rows,
    name .. ".keyboard.rows", "table")
  if not rowCount or rowCount == 0 then
    return nil, rowError or (name .. ".keyboard.rows must not be empty")
  end
  for rowIndex, row in ipairs(keyboard.rows) do
    local cellCount, cellError = collection(row,
      name .. ".keyboard.rows[" .. tostring(rowIndex) .. "]", "string")
    if not cellCount or cellCount == 0 then
      return nil, cellError or (name .. ".keyboard.rows["
        .. tostring(rowIndex) .. "] must not be empty")
    end
  end
  if keyboard.bottom ~= nil then
    local bottomCount, bottomError = collection(keyboard.bottom,
      name .. ".keyboard.bottom", "table")
    if not bottomCount then return nil, bottomError end
    for index, target in ipairs(keyboard.bottom) do
      if type(target.label) ~= "string" or target.label == "" then
        return nil, name .. ".keyboard.bottom[" .. tostring(index)
          .. "].label must be a non-empty string"
      end
    end
  end

  if value.cursor ~= nil then
    if type(value.cursor) ~= "table" then
      return nil, name .. ".cursor must be a table"
    end
    if value.cursor.bottomRow ~= nil
        and type(value.cursor.bottomRow) ~= "boolean" then
      return nil, name .. ".cursor.bottomRow must be boolean"
    end
    local valid, cursorError = nonNegativeInteger(value.cursor.row,
      name .. ".cursor.row")
    if not valid then return nil, cursorError end
    valid, cursorError = nonNegativeInteger(value.cursor.col,
      name .. ".cursor.col")
    if not valid then return nil, cursorError end
    if value.cursor.targetIndex ~= nil then
      if type(value.cursor.targetIndex) ~= "number"
          or value.cursor.targetIndex ~= math.floor(value.cursor.targetIndex)
          or value.cursor.targetIndex < 1 then
        return nil, name .. ".cursor.targetIndex must be positive integer"
      end
    end
  end
  return true
end

function Model.validate(value)
  if type(value) ~= "table" then
    return nil, "invalid_model", "presentation model must be a table"
  end
  if value.schema ~= Model.SCHEMA then
    return nil, "invalid_model", "presentation model schema must be "
      .. Model.SCHEMA
  end
  if value.apiVersion ~= 3 then
    return nil, "invalid_model", "presentation model apiVersion must be 3"
  end
  if not Model.KINDS[value.kind] then
    return nil, "unsupported_presentation", "unsupported presentation kind"
  end
  if type(value.preset) ~= "string" or value.preset == "" then
    return nil, "invalid_model", "presentation model preset is required"
  end
  local count, collectionError
  if value.kind == "menu" then
    count, collectionError = collection(value.rows, "menu.rows", "table")
    if not count then
      return nil, "invalid_model", "menu presentation requires "
        .. collectionError
    end
    local ok, errorMessage = indexField(value.selected, "menu.selected")
    if not ok then return nil, "invalid_model", errorMessage end
    if value.naming ~= nil then
      local namingValid, namingError = namingShape(value.naming, "menu.naming")
      if not namingValid then
        return nil, "invalid_model", namingError
      end
    end
  elseif value.kind == "dialogue" then
    count, collectionError = collection(value.lines, "dialogue.lines", "string")
    if not count then
      return nil, "invalid_model", "dialogue presentation requires "
        .. collectionError
    end
  elseif value.kind == "choice" then
    count, collectionError = collection(value.options, "choice.options", "table")
    if not count then
      return nil, "invalid_model", "choice presentation requires "
        .. collectionError
    end
    local ok, errorMessage = indexField(value.selected, "choice.selected")
    if not ok then return nil, "invalid_model", errorMessage end
  elseif value.kind == "battle" then
    if type(value.player) ~= "table" or type(value.enemy) ~= "table" then
      return nil, "invalid_model",
        "battle presentation requires player and enemy tables"
    end
    count, collectionError = collection(value.actions, "battle.actions", "table")
    if not count then
      return nil, "invalid_model", "battle presentation requires "
        .. collectionError
    end
    for _, field in ipairs({ "selectedAction", "selectedMove" }) do
      local ok, errorMessage = indexField(value[field], "battle." .. field)
      if not ok then return nil, "invalid_model", errorMessage end
    end
  elseif value.kind == "device" then
    local valid, deviceError = deviceShape(value.device, "device")
    if not valid then return nil, "invalid_model", deviceError end
    if value.apps ~= nil then
      local appsCount, appsError = collection(value.apps, "device.apps",
        "table")
      if not appsCount then return nil, "invalid_model", appsError end
    end
    if value.activeApp ~= nil and type(value.activeApp) ~= "table" then
      return nil, "invalid_model", "device.activeApp must be a table"
    end
  elseif value.kind == "map" then
    local valid, mapError = mapShape(value.map, "map")
    if not valid then return nil, "invalid_model", mapError end
  elseif value.kind == "document" then
    local valid, documentError = documentShape(value.document, "document")
    if not valid then return nil, "invalid_model", documentError end
  end
  if value.kind == "animation" then
    if type(value.animation) ~= "table"
        or type(value.animation.id) ~= "string"
        or value.animation.id == "" then
      return nil, "invalid_model",
        "animation presentation requires animation.id"
    end
    if value.animation.overlay ~= nil
        and type(value.animation.overlay) ~= "boolean" then
      return nil, "invalid_model",
        "animation.overlay must be boolean when present"
    end
    if value.animation.sprites ~= nil then
      local spritesValid, spritesError = spritesShape(value.animation.sprites,
        "animation.sprites")
      if not spritesValid then
        return nil, "invalid_model", spritesError
      end
    end
    if value.animation.backgroundSprites ~= nil then
      local spritesValid, spritesError = spritesShape(
        value.animation.backgroundSprites, "animation.backgroundSprites")
      if not spritesValid then
        return nil, "invalid_model", spritesError
      end
    end
    if value.animation.overlays ~= nil then
      local overlayCount, overlayError = collection(value.animation.overlays,
        "animation.overlays", "table")
      if not overlayCount then
        return nil, "invalid_model", overlayError
      end
      for index, overlay in ipairs(value.animation.overlays) do
        local validOverlay, shapeError = overlayShape(overlay,
          "animation.overlays[" .. tostring(index) .. "]")
        if not validOverlay then
          return nil, "invalid_model", shapeError
        end
      end
    end
    if value.animation.circles ~= nil then
      local circleCount, circleError = collection(value.animation.circles,
        "animation.circles", "table")
      if not circleCount then
        return nil, "invalid_model", circleError
      end
      for index, circle in ipairs(value.animation.circles) do
        local validCircle, shapeError = circleShape(circle,
          "animation.circles[" .. tostring(index) .. "]")
        if not validCircle then
          return nil, "invalid_model", shapeError
        end
      end
    end
    if value.animation.tilemap ~= nil then
      local validTilemap, tilemapError = tilemapShape(value.animation.tilemap,
        "animation.tilemap")
      if not validTilemap then
        return nil, "invalid_model", tilemapError
      end
    end
    if value.animation.labels ~= nil then
      local labelCount, labelError = collection(value.animation.labels,
        "animation.labels", "table")
      if not labelCount then
        return nil, "invalid_model", labelError
      end
      for index, label in ipairs(value.animation.labels) do
        local validLabel, shapeError = labelShape(label,
          "animation.labels[" .. tostring(index) .. "]")
        if not validLabel then
          return nil, "invalid_model", shapeError
        end
      end
    end
  end
  return true
end

function Model.is(value)
  return Model.validate(value) == true
end

return Model
