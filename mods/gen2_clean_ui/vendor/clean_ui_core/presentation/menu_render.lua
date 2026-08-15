local requireCore = ...
local Color = requireCore("design.color")
local Frame = requireCore("design.frame")

local MenuRender = {}
local imageCache = {}
local sourceImageLoader
local paletteShader
local paletteShaderFailed = false

local TYPE_COLORS = {
  NORMAL={ "#A8A77A", "#20242A" }, FIRE={ "#EE8130", "#FFFFFF" },
  WATER={ "#6390F0", "#FFFFFF" }, ELECTRIC={ "#F7D02C", "#20242A" },
  GRASS={ "#7AC74C", "#20242A" }, ICE={ "#96D9D6", "#20242A" },
  FIGHTING={ "#C22E28", "#FFFFFF" }, POISON={ "#A33EA1", "#FFFFFF" },
  GROUND={ "#E2BF65", "#20242A" }, FLYING={ "#A98FF3", "#20242A" },
  PSYCHIC={ "#F95587", "#FFFFFF" }, BUG={ "#A6B91A", "#20242A" },
  ROCK={ "#B6A136", "#FFFFFF" }, GHOST={ "#735797", "#FFFFFF" },
  DRAGON={ "#6F35FC", "#FFFFFF" }, DARK={ "#705746", "#FFFFFF" },
  STEEL={ "#B7B7CE", "#20242A" }, FAIRY={ "#D685AD", "#20242A" },
  CURSE={ "#666666", "#FFFFFF" },
}

local PALETTE_SHADER = [[
extern vec3 pal0;
extern vec3 pal1;
extern vec3 pal2;
extern vec3 pal3;

vec4 effect(vec4 tint, Image tex, vec2 uv, vec2 screen) {
  vec4 px = Texel(tex, uv);
  float shade = floor((1.0 - px.r) * 3.0 + 0.5);
  vec3 rgb = pal0;
  if (shade > 2.5) rgb = pal3;
  else if (shade > 1.5) rgb = pal2;
  else if (shade > 0.5) rgb = pal1;
  return vec4(rgb, px.a) * tint;
}
]]

local function removeLastCodepoint(text)
  local index = #text
  while index > 1 do
    local byte = text:byte(index)
    if not byte or byte < 128 or byte >= 192 then break end
    index = index - 1
  end
  return text:sub(1, index - 1)
end

local function textFit(font, value, maximum)
  local text = tostring(value or "")
  if font:getWidth(text) <= maximum then return text end
  local suffix = "..."
  while #text > 0 and font:getWidth(text .. suffix) > maximum do
    text = removeLastCodepoint(text)
  end
  return text .. suffix
end

local function printAt(G, font, color, value, x, y)
  G.setFont(font)
  Color.set(G, color)
  G.print(tostring(value or ""), math.floor(x), math.floor(y))
end

local function typeEntry(value)
  if type(value) == "table" then
    local id = tostring(value.id or value.label or ""):upper()
    local label = tostring(value.label or value.id or "TYPE"):upper()
    return id, label
  end
  local label = tostring(value or "TYPE"):upper()
  return label, label
end

local function drawTypeBadges(G, types, rect, font, theme, scale)
  if type(types) ~= "table" or not rect or rect.w <= 0 or rect.h <= 0 then
    return rect and rect.y or 0
  end
  local gap = math.max(2, math.floor(4 * scale))
  local pad = math.max(4, math.floor(6 * scale))
  local height = math.max(font:getHeight() + math.floor(4 * scale),
    math.floor(22 * scale))
  local x, y = rect.x, rect.y
  for _, value in ipairs(types) do
    local id, label = typeEntry(value)
    local palette = TYPE_COLORS[id] or { theme.colors.focus, theme.colors.ink }
    local width = math.max(font:getWidth(label) + pad * 2,
      math.floor(30 * scale))
    if x > rect.x and x + width > rect.x + rect.w then
      x, y = rect.x, y + height + gap
    end
    if y + height > rect.y + rect.h then break end
    Color.set(G, palette[1])
    G.rectangle("fill", x, y, math.min(width, rect.w), height)
    printAt(G, font, palette[2], textFit(font, label,
      math.max(1, rect.w - pad * 2)), x + pad,
      y + math.floor((height - font:getHeight()) / 2))
    x = x + width + gap
  end
  return y + height
end

local function lineAt(G, color, x1, y1, x2, y2)
  Color.set(G, color, 0.55)
  G.setLineWidth(1)
  G.line(x1, y1, x2, y2)
end

local function sourceImage(G, descriptor)
  if type(descriptor) ~= "table" then return nil end
  local path = descriptor.path or descriptor.asset
  if type(path) ~= "string" then return nil end
  local cached = imageCache[path]
  if cached ~= nil then return cached ~= false and cached or nil end
  if type(sourceImageLoader) ~= "function" then
    imageCache[path] = false
    return nil
  end
  local ok, image = pcall(sourceImageLoader, path)
  if not ok or image == nil then
    imageCache[path] = false
    return nil
  end
  if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end
  imageCache[path] = image
  return image
end

function MenuRender.setSourceImageLoader(loader)
  sourceImageLoader = type(loader) == "function" and loader or nil
  imageCache = {}
end

local function shaderFor(G, palette)
  if type(palette) ~= "table" or #palette < 4
      or paletteShaderFailed or not G.newShader then return nil end
  if not paletteShader then
    local ok, shader = pcall(G.newShader, PALETTE_SHADER)
    if not ok then paletteShaderFailed = true return nil end
    paletteShader = shader
  end
  local ok = pcall(function()
    for index = 1, 4 do
      local color = palette[index] or {}
      paletteShader:send("pal" .. (index - 1), {
        (color[1] or 0) / 255, (color[2] or 0) / 255,
        (color[3] or 0) / 255,
      })
    end
  end)
  return ok and paletteShader or nil
end

local function finiteNumber(value)
  local number = tonumber(value)
  if number == nil or number ~= number
      or number == math.huge or number == -math.huge then return nil end
  return number
end

local function cropDescriptor(descriptor)
  return descriptor.crop or descriptor.sourceRect or descriptor.source_rect
end

local function normalizedCrop(crop, imageWidth, imageHeight)
  if type(crop) ~= "table" then return nil end
  local x = finiteNumber(crop.x or crop[1])
  local y = finiteNumber(crop.y or crop[2])
  local width = finiteNumber(crop.w or crop.width or crop[3])
  local height = finiteNumber(crop.h or crop.height or crop[4])
  if not x or not y or not width or not height then return nil end

  if x ~= math.floor(x) or y ~= math.floor(y)
      or width ~= math.floor(width) or height ~= math.floor(height) then
    return nil
  end
  if width <= 0 or height <= 0 then return nil end
  if x < 0 or y < 0 or x + width > imageWidth
      or y + height > imageHeight then return nil end
  return { x=x, y=y, w=width, h=height }
end

local function spritePlacement(rect, width, height)
  local scale = math.min(rect.w / math.max(1, width),
    rect.h / math.max(1, height))
  return rect.x + (rect.w - width * scale) / 2,
    rect.y + (rect.h - height * scale) / 2, scale
end

local function quadFor(G, descriptor, imageWidth, imageHeight)
  local declared = cropDescriptor(descriptor)
  if declared == nil then return nil, nil end
  local crop = normalizedCrop(declared, imageWidth, imageHeight)
  if not crop then
    return nil, nil, "sprite_crop_invalid",
      "sprite crop is outside the image or has invalid dimensions"
  end
  if type(G.newQuad) ~= "function" then
    return nil, nil, "sprite_quad_unavailable",
      "graphics backend cannot create a sprite crop Quad"
  end
  local ok, quad = pcall(G.newQuad, crop.x, crop.y, crop.w, crop.h,
    imageWidth, imageHeight)
  if not ok or quad == nil then
    return nil, nil, "sprite_quad_unavailable",
      "graphics backend rejected the sprite crop Quad"
  end
  return quad, crop
end

local function drawSprite(G, descriptor, rect)
  if not rect or rect.w <= 0 or rect.h <= 0 then return true end
  local image = sourceImage(G, descriptor)
  if not image then
    return nil, "sprite_image_unavailable",
      "declared sprite image could not be loaded"
  end
  local widthOk, iw = pcall(function()
    return image.getWidth and image:getWidth()
  end)
  local heightOk, ih = pcall(function()
    return image.getHeight and image:getHeight()
  end)
  iw, ih = finiteNumber(iw), finiteNumber(ih)
  if not widthOk or not heightOk or not iw or not ih
      or iw <= 0 or ih <= 0 then
    return nil, "sprite_image_invalid",
      "declared sprite image has no usable dimensions"
  end
  local quad, crop, quadCode, quadMessage = quadFor(G, descriptor, iw, ih)
  if quadCode then return nil, quadCode, quadMessage end
  local sourceWidth = crop and crop.w or iw
  local sourceHeight = crop and crop.h or ih
  local x, y, scale = spritePlacement(rect, sourceWidth, sourceHeight)
  local previous = G.getShader and G.getShader() or nil
  local palette = descriptor.palette
  if type(palette) == "table" and type(palette.colors) == "table" then
    palette = palette.colors
  end
  local shader = shaderFor(G, palette)
  if shader and G.setShader then G.setShader(shader) end
  G.setColor(1, 1, 1, 1)
  local ok, drawError
  local flipX = descriptor.flipX == true
  local flipY = descriptor.flipY == true
  local sx = flipX and -scale or scale
  local sy = flipY and -scale or scale
  local drawX = flipX and (x + sourceWidth * scale) or x
  local drawY = flipY and (y + sourceHeight * scale) or y
  if quad then
    ok, drawError = pcall(G.draw, image, quad, math.floor(drawX),
      math.floor(drawY), 0, sx, sy)
  else
    ok, drawError = pcall(G.draw, image, math.floor(drawX), math.floor(drawY),
      0, sx, sy)
  end
  if G.setShader then G.setShader(previous) end
  if not ok then
    return nil, quad and "sprite_quad_draw_failed" or "sprite_draw_failed",
      tostring(drawError)
  end
  return true
end

local function tilePalette(graphic, tile)
  local palettes = graphic and graphic.palettes
  if type(palettes) ~= "table" then return nil end
  local index = tile < 0x60 and graphic.palMap
    and tonumber(graphic.palMap[tile + 1]) or 1
  local palette = palettes[index or 1]
  if type(palette) == "table" and type(palette.colors) == "table" then
    return palette.colors
  end
  return palette
end

local function drawNativeTilemap(G, graphic, region)
  if type(graphic) ~= "table" or graphic.kind ~= "tilemap"
      or type(graphic.sheet) ~= "table" or type(graphic.map) ~= "table"
      or not region or region.w <= 0 or region.h <= 0 then
    return nil
  end
  local width = math.max(1, tonumber(graphic.width) or 20)
  local height = math.max(1, tonumber(graphic.height) or 18)
  local sheet = graphic.sheet
  local descriptor = { path=sheet.path or sheet.asset }
  if not sourceImage(G, descriptor) then return nil end
  local tileSize = math.min(region.w / width, region.h / height)
  local mapW, mapH = tileSize * width, tileSize * height
  local mapRect = {
    x=region.x + (region.w - mapW) / 2,
    y=region.y + (region.h - mapH) / 2,
    w=mapW, h=mapH,
  }
  local wide = math.max(1, tonumber(sheet.wide) or 16)
  for row = 0, height - 1 do
    for column = 0, width - 1 do
      local tile = tonumber(graphic.map[row * width + column + 1])
      if tile then
        local tileDescriptor = {
          path=descriptor.path,
          crop={ x=(tile % wide) * 8,
            y=math.floor(tile / wide) * 8, w=8, h=8 },
          palette=tilePalette(graphic, tile),
        }
        local ok = drawSprite(G, tileDescriptor, {
          x=mapRect.x + column * tileSize,
          y=mapRect.y + row * tileSize,
          w=tileSize, h=tileSize,
        })
        if ok ~= true then return nil end
      end
    end
  end
  return mapRect
end

local function markerPosition(marker, source, target)
  local x = target.x + (marker.x - source.x) / math.max(1, source.w)
    * target.w
  local y = target.y + (marker.y - source.y) / math.max(1, source.h)
    * target.h
  local size = marker.rect and marker.rect.w or 8
  return x, y, size * target.w / math.max(1, source.w)
end

local function drawNativeCursor(G, graphic, x, y, mapRect)
  local cursor = type(graphic) == "table" and graphic.cursorSheet or nil
  if type(cursor) ~= "table" or type(cursor.path) ~= "string"
      or not mapRect or mapRect.w <= 0 or mapRect.h <= 0 then
    return false
  end
  local width = math.max(1, tonumber(graphic.width) or 20)
  local tileSize = mapRect.w / width
  local wide = math.max(1, tonumber(cursor.wide) or 2)
  local palette = cursor.palette or cursor.colors
  if palette == nil and type(graphic.palettes) == "table" then
    palette = graphic.palettes[1]
  end
  if type(palette) == "table" and type(palette.colors) == "table" then
    palette = palette.colors
  end
  local left, top = x - tileSize, y - tileSize
  local tiles = { 0x04, 0x05, 0x06, 0x07 }
  for index, tile in ipairs(tiles) do
    local column = (index - 1) % 2
    local row = math.floor((index - 1) / 2)
    local ok = drawSprite(G, {
      path=cursor.path,
      crop={ x=(tile % wide) * 8,
        y=math.floor(tile / wide) * 8, w=8, h=8 },
      palette=palette,
    }, {
      x=left + column * tileSize,
      y=top + row * tileSize,
      w=tileSize, h=tileSize,
    })
    if ok ~= true then return false end
  end
  return true
end

local function drawMap(G, model, layout, font, theme)
  if not layout.mapView or type(layout.mapMarkers) ~= "table"
      or not layout.listRegion then return end
  local region = layout.mapRegion or layout.listRegion
  Color.set(G, theme.colors.paper)
  G.rectangle("fill", region.x, region.y, region.w, region.h)
  local mapData = type(model.map) == "table" and model.map or nil
  local graphic = model.mapGraphic or model.nativeGraphic
    or (mapData and mapData.graphic)
  local mapRect = drawNativeTilemap(G, graphic, region)
  local markerRegion = mapRect or region
  if not mapRect then
    -- Keep a deterministic fallback for hosts that do not expose the native
    -- sheet yet; the product remains usable while the asset seam is loading.
    for step = 1, 3 do
      local x = region.x + region.w * step / 4
      local y = region.y + region.h * step / 4
      lineAt(G, theme.colors.muted, x, region.y, x, region.y + region.h)
      lineAt(G, theme.colors.muted, region.x, y, region.x + region.w, y)
    end
  end
  local previous
  for _, marker in ipairs(layout.mapMarkers) do
    local x, y = markerPosition(marker, region, markerRegion)
    if previous then lineAt(G, theme.colors.muted, previous.x, previous.y, x, y) end
    previous = { x=x, y=y }
  end
  for _, marker in ipairs(layout.mapMarkers) do
    local x, y, markerSize = markerPosition(marker, region, markerRegion)
    local half = math.max(3, math.floor(markerSize * 0.5))
    local nativeCursor = marker.selected
      and drawNativeCursor(G, graphic, x, y, markerRegion) or false
    local color = marker.selected and theme.colors.focus
      or marker.player and (theme.colors.gen2Accent or theme.colors.focus)
      or theme.colors.ink
    if not nativeCursor then
      Color.set(G, color)
      G.rectangle("fill", x - half, y - half, half * 2, half * 2)
      if marker.selected then
        Color.set(G, theme.colors.selection)
        G.rectangle("fill", x - math.max(1, half - 2),
          y - math.max(1, half - 2), math.max(2, half * 2 - 4),
          math.max(2, half * 2 - 4))
      end
    end
    if marker.player then
      Color.set(G, theme.colors.paper)
      G.rectangle("fill", x - math.max(1, half - 3),
        y - math.max(1, half - 3), math.max(2, half * 2 - 6),
        math.max(2, half * 2 - 6))
    end
    if marker.selected or marker.player then
      local label = textFit(font, marker.name or "LANDMARK",
        math.max(1, region.w * 0.45))
      local labelX = x + math.max(6, math.floor(6 * layout.scale))
      local labelY = y - font:getHeight() - math.max(2, layout.scale)
      if labelX + font:getWidth(label) > region.x + region.w then
        labelX = x - font:getWidth(label) - math.max(6, layout.scale)
      end
      labelY = math.max(region.y, labelY)
      printAt(G, font, theme.colors.ink, label, labelX, labelY)
    end
  end
end

local function drawRows(G, model, layout, font, theme)
  if layout.mapView and not model.flyView then return end
  local gap = math.max(8, math.floor(10 * layout.scale))
  local function drawBar(rect, fraction, fillColor)
    Color.set(G, theme.colors.muted)
    G.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
    Color.set(G, fillColor or theme.colors.focus)
    G.rectangle("fill", rect.x + 1, rect.y + 1,
      math.max(0, (rect.w - 2) * math.max(0, math.min(1, fraction or 0))),
      math.max(0, rect.h - 2))
  end
  for _, measured in ipairs(layout.rows or {}) do
    local row, rect = measured.row, measured.rect
    if measured.index == model.selected then
      Color.set(G, theme.colors.selection)
      G.rectangle("fill", rect.x, rect.y + 1, rect.w, rect.h - 2)
      Color.set(G, theme.colors.focus)
      G.rectangle("fill", rect.x, rect.y + 1,
        math.max(2, math.floor(3 * layout.scale)), rect.h - 2)
    end
    local color = row.disabled and theme.colors.muted or theme.colors.ink
    local right = tostring(row.right or row.valueLabel or "")
    local rightWidth = right ~= "" and font:getWidth(right) or 0
    local labelWidth = math.max(1, rect.w - rightWidth - gap * 3)
    local rowBar = row.bar
    local hasBar = type(rowBar) == "number"
      or type(rowBar) == "table"
    local baseline = hasBar
      and rect.y + math.max(1, math.floor(2 * layout.scale))
      or rect.y + math.floor((rect.h - font:getHeight()) / 2)
    printAt(G, font, color, textFit(font, row.label, labelWidth),
      rect.x + gap, baseline)
    if right ~= "" then
      printAt(G, font, color, textFit(font, right, rect.w * 0.45),
        rect.x + rect.w - gap - math.min(rightWidth, rect.w * 0.45), baseline)
    end
    if hasBar then
      local fraction = type(rowBar) == "table"
        and tonumber(rowBar.fraction or rowBar.value) or tonumber(rowBar)
      local barHeight = math.max(3, math.floor(5 * layout.scale))
      local barRect = {
        x = rect.x + gap,
        y = rect.y + rect.h - gap - barHeight,
        w = math.max(1, rect.w - gap * 2),
        h = barHeight,
      }
      local label = tostring(row.barLabel or "")
      if label ~= "" then
        local labelY = barRect.y - font:getHeight()
          - math.max(1, math.floor(layout.scale))
        printAt(G, font, color, textFit(font, label, rect.w - gap * 2),
          rect.x + gap, labelY)
      end
      drawBar(barRect, fraction,
        row.barColor == "accent" and theme.colors.gen2Accent
          or theme.colors.focus)
    end
    lineAt(G, theme.colors.muted, rect.x + gap, rect.y + rect.h - 1,
      rect.x + rect.w - gap, rect.y + rect.h - 1)
  end
end

local function drawDetails(G, model, layout, font, theme)
  local region = layout.detailRegion
  if not region then return true end
  Color.set(G, theme.colors.raised)
  G.rectangle("fill", region.x, region.y, region.w, region.h)
  local gap = math.max(8, math.floor(10 * layout.scale))
  local rich = layout.details
  if rich then
    local details = model.details or {}
    local top = rich.top
    local y = top.y
    if details.title and details.title ~= "" then
      printAt(G, font, theme.colors.ink,
        textFit(font, details.title, top.w), top.x, y)
      y = y + font:getHeight() + math.max(3, math.floor(4 * layout.scale))
    end
    for _, field in ipairs(details.fields or {}) do
      if y + font:getHeight() > top.y + top.h then break end
      local value = tostring(field.value or "")
      printAt(G, font, theme.colors.muted,
        textFit(font, field.label or "", rich.fieldWidth * 0.42),
        rich.fieldX, y)
      local width = font:getWidth(value)
      printAt(G, font, field.style == "accent" and theme.colors.focus
        or theme.colors.ink,
        textFit(font, value, rich.fieldWidth * 0.52),
        rich.fieldX + rich.fieldWidth
          - math.min(width, rich.fieldWidth * 0.52), y)
      y = y + font:getHeight() + math.max(3, math.floor(4 * layout.scale))
    end
    if type(details.typeBadges) == "table" then
      local badgeBottom = drawTypeBadges(G, details.typeBadges, {
        x=rich.fieldX, y=y, w=rich.fieldWidth,
        h=math.max(1, top.y + top.h - y),
      }, font, theme, layout.scale)
      y = badgeBottom + math.max(3, math.floor(4 * layout.scale))
    end
    for _, progress in ipairs(details.bars or {}) do
      local barHeight = math.max(3, math.floor(5 * layout.scale))
      local labelHeight = font:getHeight()
      local barY = y + labelHeight + math.max(1, math.floor(layout.scale))
      if barY + barHeight > top.y + top.h then break end
      local label = tostring(progress.label or "")
      local value = tostring(progress.value or "")
      printAt(G, font, theme.colors.muted,
        textFit(font, label, rich.fieldWidth * 0.42), rich.fieldX, y)
      local valueWidth = font:getWidth(value)
      if value ~= "" then
        printAt(G, font, progress.style == "accent"
          and theme.colors.focus or theme.colors.ink,
          textFit(font, value, rich.fieldWidth * 0.52),
          rich.fieldX + rich.fieldWidth
            - math.min(valueWidth, rich.fieldWidth * 0.52), y)
      end
      local fraction = tonumber(progress.fraction or 0) or 0
      Color.set(G, theme.colors.muted)
      G.rectangle("fill", rich.fieldX, barY, rich.fieldWidth, barHeight)
      Color.set(G, progress.style == "accent"
        and (theme.colors.gen2Accent or theme.colors.focus)
        or theme.colors.focus)
      G.rectangle("fill", rich.fieldX + 1, barY + 1,
        math.max(0, (rich.fieldWidth - 2)
          * math.max(0, math.min(1, fraction))),
        math.max(0, barHeight - 2))
      y = barY + barHeight + math.max(3, math.floor(4 * layout.scale))
    end
    local sprite = details.sprite
    if type(sprite) == "table" then
      local spriteOk, spriteCode, spriteMessage = drawSprite(G, sprite,
        rich.sprite)
      if spriteOk ~= true then return nil, spriteCode, spriteMessage end
    end
    for _, cell in ipairs(rich.cells or {}) do
      local field, rect = cell.field, cell.rect
      local value = tostring(field.value or "")
      local combined = tostring(field.label or "")
      if value ~= "" then combined = combined .. " " .. value end
      printAt(G, font, field.style == "accent" and theme.colors.focus
        or theme.colors.ink, textFit(font, combined, rect.w), rect.x, rect.y)
    end
    for _, section in ipairs(rich.footerSections or {}) do
      printAt(G, font, theme.colors.muted,
        textFit(font, section.section.title or "", section.title.w),
        section.title.x, section.title.y)
      for _, measured in ipairs(section.items or {}) do
        local item, rect = measured.item, measured.rect
        local value = tostring(item.value or "")
        printAt(G, font, theme.colors.ink,
          textFit(font, item.label or "", rect.w * 0.62), rect.x, rect.y)
        if value ~= "" then
          local width = font:getWidth(value)
          printAt(G, font, theme.colors.ink,
            textFit(font, value, rect.w * 0.35),
            rect.x + rect.w - math.min(width, rect.w * 0.35), rect.y)
        end
      end
    end
    return true
  end
  local y = region.y + gap
  for _, field in ipairs(model.details or {}) do
    if y + font:getHeight() > region.y + region.h then break end
    local label = tostring(field.label or "")
    local value = tostring(field.value or "")
    printAt(G, font, theme.colors.muted,
      textFit(font, label, region.w * 0.42), region.x + gap, y)
    local valueWidth = font:getWidth(value)
    printAt(G, font, field.style == "accent" and theme.colors.focus
      or theme.colors.ink, textFit(font, value, region.w * 0.5),
      region.x + region.w - gap - math.min(valueWidth, region.w * 0.5), y)
    y = y + font:getHeight() + gap
  end
  return true
end

local function drawShellStatus(G, model, shell, font, theme, scale)
  local status = shell.status
  Color.set(G, theme.colors.raised)
  G.rectangle("fill", status.x, status.y, status.w, status.h)
  local value = model.statusBar
    or (model.shell and model.shell.statusBar) or {}
  local left = tostring(value.time or "--:--")
  local right = tostring(value.region or "POKEGEAR")
  printAt(G, font, theme.colors.ink, left, status.x + math.floor(8 * scale),
    status.y + math.floor((status.h - font:getHeight()) / 2))
  local rightWidth = font:getWidth(right)
  printAt(G, font, theme.colors.gen2Accent or theme.colors.focus, right,
    status.x + status.w - rightWidth - math.floor(8 * scale),
    status.y + math.floor((status.h - font:getHeight()) / 2))
  lineAt(G, theme.colors.muted, status.x, status.y + status.h - 1,
    status.x + status.w, status.y + status.h - 1)
end

local function drawShellRail(G, model, shell, font, theme, scale)
  local rail = shell.rail
  Color.set(G, theme.colors.raised)
  G.rectangle("fill", rail.x, rail.y, rail.w, rail.h)
  lineAt(G, theme.colors.muted, rail.x, rail.y, rail.x + rail.w, rail.y)
  local cards = model.apps or (model.shell and model.shell.apps) or {}
  local count = math.max(1, #cards)
  local gap = math.max(3, math.floor(4 * scale))
  local width = math.max(1, (rail.w - gap * (count - 1)) / count)
  for index, card in ipairs(cards) do
    local rect = { x=rail.x + (index - 1) * (width + gap),
      y=rail.y + math.max(3, math.floor(5 * scale)),
      w=width, h=math.max(1, rail.h - math.floor(10 * scale)) }
    local launcher = model.launcher or (model.shell and model.shell.launcher) or {}
    if card.selected or index == launcher.selected then
      Color.set(G, theme.colors.selection)
      G.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
      Color.set(G, theme.colors.focus)
      G.rectangle("fill", rect.x, rect.y,
        math.max(2, math.floor(3 * scale)), rect.h)
    end
    local label = tostring(card.label or card.id or "APP"):upper()
    printAt(G, font, theme.colors.ink, textFit(font, label,
      math.max(1, rect.w - math.floor(8 * scale))),
      rect.x + math.floor(4 * scale),
      rect.y + math.floor((rect.h - font:getHeight()) / 2))
  end
end

local function drawShellDetails(G, model, rect, font, theme, scale)
  local details = model.details or {}
  if type(details) ~= "table" or #details == 0 then return end
  local gap = math.max(6, math.floor(8 * scale))
  local y = rect.y + math.max(8, math.floor(12 * scale))
  for _, field in ipairs(details) do
    if y + font:getHeight() > rect.y + rect.h then break end
    local label = tostring(field.label or "")
    local value = tostring(field.value or "")
    printAt(G, font, theme.colors.muted,
      textFit(font, label, rect.w * 0.42), rect.x + gap, y)
    local width = font:getWidth(value)
    printAt(G, font, field.style == "accent" and theme.colors.focus
      or theme.colors.ink, textFit(font, value, rect.w * 0.5),
      rect.x + rect.w - gap - math.min(width, rect.w * 0.5), y)
    y = y + font:getHeight() + gap
  end
end

local drawModal

local function drawAppShell(G, model, layout, font, theme)
  local shell = layout.shell
  if type(shell) ~= "table" then return nil, "shell_layout_missing" end
  local scale = layout.scale or 1
  Color.set(G, theme.colors.raised)
  G.rectangle("fill", layout.outer.x, layout.outer.y,
    layout.outer.w, layout.outer.h)
  Frame.draw(G, shell.device, theme, scale)
  Color.set(G, theme.colors.paper)
  G.rectangle("fill", shell.screen.x, shell.screen.y,
    shell.screen.w, shell.screen.h)
  drawShellStatus(G, model, shell, font, theme, scale)
  Color.set(G, theme.colors.raised)
  G.rectangle("fill", shell.content.x, shell.content.y,
    shell.content.w, shell.content.h)
  local screen = model.screen or (model.shell and model.shell.screen) or {}
  local title = tostring(screen.title or model.title or "POKEGEAR")
  if model.view == "strip" then
    local active = model.activeApp or {}
    printAt(G, font, theme.colors.gen2Accent or theme.colors.focus,
      textFit(font, title, shell.content.w - 24),
      shell.content.x + 12, shell.content.y + 14)
    printAt(G, font, theme.colors.ink,
      textFit(font, active.label or "SELECT AN APP", shell.content.w - 24),
      shell.content.x + 12, shell.content.y + 48)
    printAt(G, font, theme.colors.muted,
      textFit(font, active.subtitle or "LEFT/RIGHT TO BROWSE",
        shell.content.w - 24), shell.content.x + 12, shell.content.y + 48
        + font:getHeight() + 6)
  elseif layout.mapView then
    drawMap(G, model, layout, font, theme)
    if model.flyView then drawRows(G, model, layout, font, theme) end
  elseif #layout.rows > 0 then
    drawRows(G, model, layout, font, theme)
  else
    drawShellDetails(G, model, shell.content, font, theme, scale)
  end
  drawShellRail(G, model, shell, font, theme, scale)
  drawModal(G, model, layout, font, theme)
  G.setColor(1, 1, 1, 1)
  return true
end

drawModal = function(G, model, layout, font, theme)
  local modal = layout.modal
  if not modal then return end
  local descriptor = model.modal
  Color.set(G, "#000000", descriptor.dim_opacity or 0.4)
  G.rectangle("fill", layout.outer.x, layout.outer.y,
    layout.outer.w, layout.outer.h)
  Frame.draw(G, modal.rect, theme, layout.scale)
  local title = descriptor.title or descriptor.message or "CHOOSE"
  printAt(G, font, theme.colors.ink,
    textFit(font, title, modal.inner.w), modal.inner.x, modal.inner.y)
  for _, measured in ipairs(modal.options or {}) do
    local option, rect = measured.option, measured.rect
    if measured.index == descriptor.selected then
      Color.set(G, theme.colors.selection)
      G.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
      Color.set(G, theme.colors.focus)
      G.rectangle("fill", rect.x, rect.y,
        math.max(2, math.floor(3 * layout.scale)), rect.h)
    end
    printAt(G, font, option.disabled and theme.colors.muted or theme.colors.ink,
      textFit(font, option.label, rect.w - 20), rect.x + 10,
      rect.y + math.floor((rect.h - font:getHeight()) / 2))
  end
end

-- Shared by production menu and battle presenters. The descriptor remains
-- data-only; the runtime owns the image loader and palette shader.
MenuRender.drawSprite = drawSprite
MenuRender.drawTypeBadges = drawTypeBadges

function MenuRender.draw(graphics, model, layout, font, theme)
  if model.appShell or model.kind == "device" then
    return drawAppShell(graphics, model, layout, font, theme)
  end
  if model.opaque then
    Color.set(graphics, theme.colors.raised)
    graphics.rectangle("fill", 0, 0, layout.viewport.w, layout.viewport.h)
  end
  Frame.draw(graphics, layout.outer, theme, layout.scale)
  local titleY = layout.header.y
    + math.floor((layout.header.h - font:getHeight()) / 2)
  printAt(graphics, font, theme.colors.ink, model.title or "MENU",
    layout.header.x, titleY)
  lineAt(graphics, theme.colors.muted, layout.header.x,
    layout.header.y + layout.header.h - 1,
    layout.header.x + layout.header.w,
    layout.header.y + layout.header.h - 1)
  drawMap(graphics, model, layout, font, theme)
  drawRows(graphics, model, layout, font, theme)
  local detailsOk, detailsCode, detailsMessage = drawDetails(graphics, model,
    layout, font, theme)
  if detailsOk ~= true then
    graphics.setColor(1, 1, 1, 1)
    return nil, detailsCode or "details_draw_failed", detailsMessage
  end
  lineAt(graphics, theme.colors.muted, layout.footer.x, layout.footer.y,
    layout.footer.x + layout.footer.w, layout.footer.y)
  local description = model.description
  if type(description) == "table" then description = table.concat(description, " ") end
  printAt(graphics, font, theme.colors.muted,
    textFit(font, description or model.controls or "A CHOOSE   B BACK",
      layout.footer.w), layout.footer.x,
    layout.footer.y + math.floor((layout.footer.h - font:getHeight()) / 2))
  drawModal(graphics, model, layout, font, theme)
  graphics.setColor(1, 1, 1, 1)
  return true
end

return MenuRender
