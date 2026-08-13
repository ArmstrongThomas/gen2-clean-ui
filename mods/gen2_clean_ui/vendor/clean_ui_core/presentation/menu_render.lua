local requireCore = ...
local Color = requireCore("design.color")
local Frame = requireCore("design.frame")

local MenuRender = {}
local imageCache = {}
local sourceImageLoader
local paletteShader
local paletteShaderFailed = false

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
  if quad then
    ok, drawError = pcall(G.draw, image, quad, math.floor(x),
      math.floor(y), 0, scale, scale)
  else
    ok, drawError = pcall(G.draw, image, math.floor(x), math.floor(y),
      0, scale, scale)
  end
  if G.setShader then G.setShader(previous) end
  if not ok then
    return nil, quad and "sprite_quad_draw_failed" or "sprite_draw_failed",
      tostring(drawError)
  end
  return true
end

local function drawRows(G, model, layout, font, theme)
  local gap = math.max(8, math.floor(10 * layout.scale))
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
    local baseline = rect.y + math.floor((rect.h - font:getHeight()) / 2)
    printAt(G, font, color, textFit(font, row.label, labelWidth),
      rect.x + gap, baseline)
    if right ~= "" then
      printAt(G, font, color, textFit(font, right, rect.w * 0.45),
        rect.x + rect.w - gap - math.min(rightWidth, rect.w * 0.45), baseline)
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

local function drawModal(G, model, layout, font, theme)
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

function MenuRender.draw(graphics, model, layout, font, theme)
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
