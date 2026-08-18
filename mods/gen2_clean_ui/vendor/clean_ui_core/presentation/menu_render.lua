local requireCore = ...
local Color = requireCore("design.color")
local Frame = requireCore("design.frame")

local MenuRender = {}
local imageCache = {}
local sourceImageLoader
local paletteShader
local paletteShaderFailed = false
local partyIconClock = 0

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

local STATUS_COLORS = {
  PSN={ "#B452B9", "#FFFFFF" }, PAR={ "#D6A62C", "#20242A" },
  SLP={ "#687A8C", "#FFFFFF" }, BRN={ "#C95232", "#FFFFFF" },
  FRZ={ "#6AAFC1", "#FFFFFF" }, FNT={ "#4B4F58", "#FFFFFF" },
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

-- PlainPixel is intentionally kept at its authored pixel sizes. These
-- semantic styles add hierarchy without scaling the font horizontally or
-- inventing a second, stretched raster. A style's stepDelta requests a
-- family-relative whole-size face for that one run; the font catalog still
-- steps it down independently if the text cannot fit.
local TEXT_STYLES = {
  body={ color="ink", weight=1, stepDelta=0 },
  label={ color="muted", weight=1, stepDelta=0 },
  value={ color="ink", weight=1, stepDelta=0 },
  caption={ color="muted", weight=1, stepDelta=-1 },
  strong={ color="ink", weight=2, stepDelta=0 },
  subheading={ color="muted", weight=2, stepDelta=0 },
  heading={ color="ink", weight=2, stepDelta=1 },
  title={ color="ink", weight=2, stepDelta=1 },
  display={ color="ink", weight=2, stepDelta=2 },
  accent={ color="focus", weight=2, stepDelta=0 },
  muted={ color="muted", weight=1, stepDelta=0 },
}

local function textStyleOptions(style, options)
  local requested = type(style) == "table" and style or nil
  local base = type(style) == "string" and TEXT_STYLES[style]
    or TEXT_STYLES.body
  base = base or TEXT_STYLES.body
  local output = {}
  if type(options) == "table" then
    for key, value in pairs(options) do output[key] = value end
  end
  if output.step == nil and output.stepDelta == nil then
    output.stepDelta = tonumber(requested and requested.stepDelta
      or base.stepDelta) or 0
  end
  return output
end

local function printStyled(G, font, theme, value, x, y, style)
  local requested = type(style) == "table" and style or nil
  local base = type(style) == "string" and TEXT_STYLES[style]
    or TEXT_STYLES.body
  base = base or TEXT_STYLES.body
  local color = requested and requested.color or base.color
  if type(color) == "string" and theme and theme.colors then
    color = theme.colors[color] or color
  end
  local weight = tonumber(requested and requested.weight or base.weight) or 1
  printAt(G, font, color, value, x, y)
  if weight >= 2 then
    local height = font and type(font.getHeight) == "function"
      and tonumber(font:getHeight()) or 15
    local offset = math.max(1, math.floor(height / 15))
    printAt(G, font, color, value, x + offset, y)
  end
end

local function fontHeight(font)
  if not font or type(font.getHeight) ~= "function" then return 0 end
  local ok, height = pcall(font.getHeight, font)
  return ok and tonumber(height) or 0
end

local function genderKind(value)
  local gender = tostring(value or ""):lower()
  if gender == "female" or gender == "f" then return "female" end
  if gender == "male" or gender == "m" then return "male" end
  if gender == "none" or gender == "genderless"
      or gender == "no_gender" or gender == "no-gender"
      or gender == "nogender" or gender == "no gender"
      or gender == "unknown" then
    return "none"
  end
  return nil
end

-- Gender art is authored at two source sizes. Choose an exact integer
-- multiple when the selected font supports one. For an in-between font size,
-- choose the largest cleanly magnified source that fits below it; drawSprite's
-- reciprocal reduction handles the rare smaller-than-source case without
-- introducing a fractional magnification.
local function resolveGenderIcon(icon, font)
  if type(icon) ~= "table" or type(icon.variants) ~= "table" then
    return icon, nil
  end
  local height = math.max(1, math.floor(fontHeight(font) + 0.5))
  local selected = height % 10 == 0 and 10
    or (height % 16 == 0 and 16 or nil)
  if not selected then
    local bestOutput, bestSize = 0, nil
    for _, size in ipairs({ 10, 16 }) do
      local multiple = math.floor(height / size)
      if multiple >= 1 then
        local output = size * multiple
        if output > bestOutput
            or (output == bestOutput and size == 16) then
          bestOutput, bestSize = output, size
        end
      end
    end
    selected = bestSize or 10
  end
  local variant = icon.variants[tostring(selected)]
    or icon.variants[selected]
  if type(variant) ~= "table" then return icon, nil end
  local copy = {}
  for key, value in pairs(icon) do copy[key] = value end
  for key, value in pairs(variant) do copy[key] = value end
  copy.gender = icon.gender or copy.gender
  return copy, selected
end

local function fontWidth(font, value)
  if not font or type(font.getWidth) ~= "function" then return 0 end
  local ok, width = pcall(font.getWidth, font, tostring(value or ""))
  return ok and tonumber(width) or 0
end

-- Resolve one constrained string against the frame's base policy.  The
-- returned face is allowed to differ from the face used by neighboring text;
-- all font objects are cached by FontCatalog, so this is safe within a frame.
local function resolveTextRun(layout, baseFont, value, maximum, options)
  local text = tostring(value or "")
  local limit = tonumber(maximum)
  if not limit or limit < 0 then limit = math.huge end
  local run
  if type(layout) == "table" and type(layout.textRun) == "function" then
    local ok, candidate = pcall(layout.textRun, text, limit, options)
    if ok and type(candidate) == "table" and candidate.font then
      run = candidate
    end
  end
  local active = run and run.font or baseFont
  local fitted = textFit(active, text, limit)
  return {
    font=active,
    text=fitted,
    width=fontWidth(active, fitted),
    height=fontHeight(active),
    fits=run and run.fits ~= false or true,
    policy=run and run.policy or nil,
  }
end

local function printFitted(G, layout, baseFont, color, value, x, y, maximum,
    options)
  local run = resolveTextRun(layout, baseFont, value, maximum, options)
  local offset = math.floor((fontHeight(baseFont) - run.height) / 2)
  printAt(G, run.font, color, run.text, x, y + offset)
  return run
end

local function printStyledFitted(G, layout, baseFont, theme, value, x, y,
    maximum, style, options)
  local run = resolveTextRun(layout, baseFont, value, maximum,
    textStyleOptions(style, options))
  if type(options) == "table" and options.align == "center" then
    x = x + math.max(0, math.floor((maximum - run.width) / 2))
  end
  local offset = math.floor((fontHeight(baseFont) - run.height) / 2)
  printStyled(G, run.font, theme, run.text, x, y + offset, style)
  return run
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

local function typeLabelList(values)
  local labels = {}
  for _, value in ipairs(values or {}) do
    local _, label = typeEntry(value)
    labels[#labels + 1] = label
  end
  return table.concat(labels, " / ")
end

local function shade(value, factor)
  local r, g, b = Color.rgba(value)
  local function channel(channelValue)
    return math.max(0, math.min(255, math.floor(channelValue * 255
      * factor + 0.5)))
  end
  return ("#%02X%02X%02X"):format(channel(r), channel(g), channel(b))
end

local function drawBadge(G, label, rect, palette, font, scale)
  if not rect or rect.w <= 0 or rect.h <= 0 then return end
  local fill, text = palette[1], palette[2]
  local border = shade(fill, 0.52)
  local highlight = shade(fill, 1.32)
  local shadow = shade(fill, 0.72)
  local borderSize = math.max(1, math.floor(scale))
  Color.set(G, border)
  G.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
  local inner = {
    x=rect.x + borderSize, y=rect.y + borderSize,
    w=math.max(1, rect.w - borderSize * 2),
    h=math.max(1, rect.h - borderSize * 2),
  }
  Color.set(G, fill)
  G.rectangle("fill", inner.x, inner.y, inner.w, inner.h)
  -- A tiny inset bevel is the part of the reference treatment that makes
  -- these read as type chips instead of flat colored text.
  Color.set(G, highlight)
  G.rectangle("fill", inner.x, inner.y, inner.w, borderSize)
  G.rectangle("fill", inner.x, inner.y, borderSize, inner.h)
  Color.set(G, shadow)
  G.rectangle("fill", inner.x, inner.y + inner.h - borderSize,
    inner.w, borderSize)
  G.rectangle("fill", inner.x + inner.w - borderSize, inner.y,
    borderSize, inner.h)
  printAt(G, font, text, label, inner.x + math.max(2, math.floor(4 * scale)),
    inner.y + math.floor((inner.h - font:getHeight()) / 2))
end

local function badgeWidth(font, scale, exemplar, minimum)
  local pad = math.max(4, math.floor(6 * scale))
  return math.max(tonumber(minimum) or 0,
    font:getWidth(exemplar) + pad * 2)
end

local function drawBadges(G, values, rect, font, theme, scale, palettes,
    fixedWidth)
  if type(values) ~= "table" or not rect or rect.w <= 0 or rect.h <= 0 then
    return rect and rect.y or 0
  end
  local gap = math.max(2, math.floor(4 * scale))
  local pad = math.max(4, math.floor(6 * scale))
  local height = math.max(font:getHeight() + math.floor(4 * scale),
    math.floor(22 * scale))
  local x, y = rect.x, rect.y
  for _, value in ipairs(values) do
    local id, label = typeEntry(value)
    local palette = palettes[id] or { theme.colors.focus, theme.colors.ink }
    local width = fixedWidth or math.max(font:getWidth(label) + pad * 2,
      math.floor(30 * scale))
    if x > rect.x and x + width > rect.x + rect.w then
      x, y = rect.x, y + height + gap
    end
    if y + height > rect.y + rect.h then break end
    local available = math.max(1, rect.x + rect.w - x)
    local badgeActualWidth = fixedWidth or math.min(width, available)
    -- Fixed type/status chips are sized from the longest supported label, so
    -- the label must remain intact. A caller that supplies an arbitrary
    -- non-fixed badge still gets the legacy fitting behavior.
    local badgeLabel = fixedWidth and label or textFit(font, label,
      math.max(1, badgeActualWidth - pad * 2))
    drawBadge(G, badgeLabel,
      { x=x, y=y, w=badgeActualWidth, h=height },
      palette, font, scale)
    x = x + width + gap
  end
  return y + height
end

local function drawTypeBadges(G, types, rect, font, theme, scale, align)
  if type(types) ~= "table" then return rect and rect.y or 0 end
  if align == "center" and rect and #types > 0 then
    local gap = math.max(2, math.floor(4 * scale))
    local badge = badgeWidth(font, scale, "ELECTRIC", math.floor(30 * scale))
    local total = badge * #types + gap * (#types - 1)
    rect = {
      x = rect.x + math.floor(math.max(0, rect.w - total) / 2),
      y = rect.y, w = total, h = rect.h,
    }
  end
  return drawBadges(G, types, rect, font, theme, scale, TYPE_COLORS,
    badgeWidth(font, scale, "ELECTRIC", math.floor(30 * scale)))
end

local function drawStatusBadge(G, status, rect, font, theme, scale)
  if type(status) ~= "string" or status == "" or status == "OK" then
    return rect and rect.y or 0
  end
  return drawBadges(G, { status }, rect, font, theme, scale, STATUS_COLORS,
    badgeWidth(font, scale, "FNT", math.floor(52 * scale)))
end

local function lineAt(G, color, x1, y1, x2, y2)
  Color.set(G, color, 0.55)
  G.setLineWidth(1)
  G.line(x1, y1, x2, y2)
end

local function sourceImage(G, descriptor)
  if type(descriptor) ~= "table" then return nil end
  local path = descriptor.path or descriptor.asset
  local assetPath = descriptor.assetPath
  if type(path) ~= "string" then return nil end
  local cacheKey = path .. "\n" .. tostring(assetPath or "")
  local cached = imageCache[cacheKey]
  if cached ~= nil then return cached ~= false and cached or nil end
  if type(sourceImageLoader) ~= "function" then
    imageCache[cacheKey] = false
    return nil
  end
  local ok, image = pcall(sourceImageLoader, path, assetPath)
  if not ok or image == nil then
    imageCache[cacheKey] = false
    return nil
  end
  if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end
  imageCache[cacheKey] = image
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

local function animatedDescriptor(descriptor, clock)
  if type(descriptor) ~= "table" or type(descriptor.animation) ~= "table" then
    return descriptor
  end
  local animation = descriptor.animation
  local frames = math.floor(tonumber(animation.frames or descriptor.frames) or 1)
  local duration = math.max(1,
    math.floor(tonumber(animation.frameDuration) or 1))
  local crop = cropDescriptor(descriptor)
  if frames <= 1 or type(crop) ~= "table" then return descriptor end
  local frame = math.floor((tonumber(clock) or 0) / duration) % frames
  local copy = {}
  for key, value in pairs(descriptor) do copy[key] = value end
  local nextCrop = {
    x=tonumber(crop.x or crop[1]) or 0,
    y=tonumber(crop.y or crop[2]) or 0,
    w=tonumber(crop.w or crop.width or crop[3]) or 0,
    h=tonumber(crop.h or crop.height or crop[4]) or 0,
  }
  if animation.axis == "x" then
    nextCrop.x = nextCrop.x + nextCrop.w * frame
  else
    nextCrop.y = nextCrop.y + nextCrop.h * frame
  end
  copy.crop = nextCrop
  return copy
end

local function pixelRound(value)
  return math.floor((tonumber(value) or 0) + 0.5)
end

local function greatestCommonDivisor(left, right)
  left = math.floor(math.abs(tonumber(left) or 0))
  right = math.floor(math.abs(tonumber(right) or 0))
  while right > 0 do
    left, right = right, left % right
  end
  return math.max(1, left)
end

local function pixelScale(width, height, fit)
  if fit >= 1 then
    -- Magnification is only allowed at a whole-pixel scale. Leaving a small
    -- amount of measured slack is preferable to making source pixels change
    -- width across one destination sprite.
    return math.max(1, math.floor(fit + 0.000001))
  end

  -- Exact reciprocal reductions (for example 16px -> 8px) preserve a
  -- consistent source-pixel footprint. Prefer the largest divisor that still
  -- fits the measured rectangle.
  local common = greatestCommonDivisor(width, height)
  local best = 0
  for divisor = 2, common do
    if common % divisor == 0 then
      local candidate = 1 / divisor
      if candidate <= fit + 0.000001 and candidate > best then
        best = candidate
      end
    end
  end
  if best > 0 then return best end

  -- A non-divisible source cannot have an exact reciprocal reduction. Keep
  -- nearest filtering and integer extents as the safe fallback; authored
  -- pixel sheets used by the products are divisible in their normal crops.
  return fit
end

-- Keep the raster boundary discrete even when the responsive layout produced
-- fractional rectangles. Whole-pixel magnification and exact reciprocal
-- reduction prevent the GPU from giving neighboring source pixels different
-- widths. The final fallback is reserved for a non-divisible source crop.
local function spritePlacement(rect, width, height)
  local x1 = pixelRound(rect.x)
  local y1 = pixelRound(rect.y)
  local x2 = math.max(x1 + 1, pixelRound(rect.x + rect.w))
  local y2 = math.max(y1 + 1, pixelRound(rect.y + rect.h))
  local availableWidth, availableHeight = x2 - x1, y2 - y1
  local sourceWidth = math.max(1, width)
  local sourceHeight = math.max(1, height)
  local fit = math.min(availableWidth / sourceWidth,
    availableHeight / sourceHeight)
  if fit <= 0 then return x1, y1, 0, 0, 0, 0 end

  local scale = pixelScale(sourceWidth, sourceHeight, fit)
  local outputWidth = math.max(1, math.min(availableWidth,
    pixelRound(sourceWidth * scale)))
  local outputHeight = math.max(1, math.min(availableHeight,
    pixelRound(sourceHeight * scale)))
  local x = pixelRound(x1 + (availableWidth - outputWidth) * 0.5)
  local y = pixelRound(y1 + (availableHeight - outputHeight) * 0.5)
  return x, y, outputWidth / sourceWidth, outputHeight / sourceHeight,
    outputWidth, outputHeight
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

local function drawSprite(G, descriptor, rect, animationClock)
  if not rect or rect.w <= 0 or rect.h <= 0 then return true end
  local drawDescriptor = animatedDescriptor(descriptor, animationClock)
  local image = sourceImage(G, drawDescriptor)
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
  local quad, crop, quadCode, quadMessage = quadFor(G, drawDescriptor, iw, ih)
  if quadCode then return nil, quadCode, quadMessage end
  local sourceWidth = crop and crop.w or iw
  local sourceHeight = crop and crop.h or ih
  local x, y, scaleX, scaleY, outputWidth, outputHeight = spritePlacement(
    rect, sourceWidth, sourceHeight)
  if outputWidth <= 0 or outputHeight <= 0 then return true end
  local previous = G.getShader and G.getShader() or nil
  local palette = drawDescriptor.palette
  if type(palette) == "table" and type(palette.colors) == "table" then
    palette = palette.colors
  end
  local shader = shaderFor(G, palette)
  if shader and G.setShader then G.setShader(shader) end
  G.setColor(1, 1, 1, 1)
  local ok, drawError
  local flipX = drawDescriptor.flipX == true
  local flipY = drawDescriptor.flipY == true
  local sx = flipX and -scaleX or scaleX
  local sy = flipY and -scaleY or scaleY
  local drawX = flipX and (x + outputWidth) or x
  local drawY = flipY and (y + outputHeight) or y
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
  local tileScale = pixelScale(8, 8, math.min(region.w / width,
    region.h / height))
  local tileSize = math.max(1, pixelRound(8 * tileScale))
  local mapW, mapH = tileSize * width, tileSize * height
  local mapRect = {
    x=pixelRound(region.x + (region.w - mapW) / 2),
    y=pixelRound(region.y + (region.h - mapH) / 2),
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
      or marker.nest and (theme.colors.gen2Accent or theme.colors.focus)
      or marker.player and (theme.colors.gen2Accent or theme.colors.focus)
      or theme.colors.ink
    if not nativeCursor then
      Color.set(G, color)
      if marker.nest and G.polygon then
        G.polygon("fill", x, y - half, x + half, y,
          x, y + half, x - half, y)
      else
        G.rectangle("fill", x - half, y - half, half * 2, half * 2)
      end
      if marker.selected then
        Color.set(G, theme.colors.selection)
        G.rectangle("fill", x - math.max(1, half - 2),
          y - math.max(1, half - 2), math.max(2, half * 2 - 4),
          math.max(2, half * 2 - 4))
      end
      if marker.nest then
        Color.set(G, theme.colors.paper)
        G.rectangle("fill", x - math.max(1, half - 3),
          y - math.max(1, half - 3), math.max(2, half * 2 - 6),
          math.max(2, half * 2 - 6))
      end
    end
    if marker.player then
      Color.set(G, theme.colors.paper)
      G.rectangle("fill", x - math.max(1, half - 3),
        y - math.max(1, half - 3), math.max(2, half * 2 - 6),
        math.max(2, half * 2 - 6))
    end
    if marker.selected or marker.player then
      local labelRun = resolveTextRun(layout, font, marker.name or "LANDMARK",
        math.max(1, region.w * 0.45))
      local label = labelRun.text
      local labelX = x + math.max(6, math.floor(6 * layout.scale))
      local labelY = y - labelRun.height - math.max(2, layout.scale)
      if labelX + labelRun.width > region.x + region.w then
        labelX = x - labelRun.width - math.max(6, layout.scale)
      end
      labelY = math.max(region.y, labelY)
      printAt(G, labelRun.font, theme.colors.ink, label, labelX, labelY)
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
    local rightRun = right ~= "" and resolveTextRun(layout, font, right,
      rect.w * 0.45) or nil
    local rightWidth = rightRun and rightRun.width or 0
    local labelWidth = math.max(1, rect.w - rightWidth - gap * 3)
    local rowBar = row.bar
    local hasBar = type(rowBar) == "number"
      or type(rowBar) == "table"
    local baseline = hasBar
      and rect.y + math.max(1, math.floor(2 * layout.scale))
      or rect.y + math.floor((rect.h - font:getHeight()) / 2)
    printFitted(G, layout, font, color, row.label, rect.x + gap, baseline,
      labelWidth)
    if rightRun then
      local rightY = baseline
        + math.floor((font:getHeight() - rightRun.height) / 2)
      printAt(G, rightRun.font, color, rightRun.text,
        rect.x + rect.w - gap - rightRun.width, rightY)
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
        printFitted(G, layout, font, color, label, rect.x + gap, labelY,
          rect.w - gap * 2)
      end
      drawBar(barRect, fraction,
        row.barColor == "accent" and theme.colors.gen2Accent
          or theme.colors.focus)
    end
    lineAt(G, theme.colors.muted, rect.x + gap, rect.y + rect.h - 1,
      rect.x + rect.w - gap, rect.y + rect.h - 1)
  end
end

local function namingLabel(value)
  local label = tostring(value or "")
  if label == "<PK>" then return "PK" end
  if label == "<MN>" then return "MN" end
  return label
end

local function drawNaming(G, model, layout, font, theme)
  local naming = layout.naming
  if not naming then return end
  local scale = layout.scale
  local gap = math.max(6, math.floor(8 * scale))
  local text = naming.text
  local glyphs = naming.glyphs
  local maxLength = math.max(1, naming.maxLength or 10)
  local slotGap = math.max(2, math.floor(3 * scale))
  local slotWidth = math.max(1,
    (naming.entry.w - (maxLength - 1) * slotGap) / maxLength)
  local slotHeight = math.max(font:getHeight() + gap,
    math.floor(28 * scale))
  local entryY = naming.entry.y
  local sourceLength = naming.sourceLength
    or (type(glyphs) == "table" and #glyphs or #text)
  local counter = sourceLength .. "/" .. maxLength

  printAt(G, font, theme.colors.muted, "ENTRY", naming.entry.x, entryY)
  local slotsY = entryY + font:getHeight() + math.max(2, math.floor(3 * scale))
  for index = 1, maxLength do
    local x = naming.entry.x + (index - 1) * (slotWidth + slotGap)
    Color.set(G, index <= #text and theme.colors.selection
      or theme.colors.raised)
    G.rectangle("fill", x, slotsY, slotWidth, slotHeight,
      theme.radii and theme.radii.sm or 0)
    local glyph = type(glyphs) == "table" and tostring(glyphs[index] or "")
      or text:sub(index, index)
    printAt(G, font, index <= #text and theme.colors.ink
      or theme.colors.muted, glyph ~= "" and glyph or "-",
      x + math.max(2, (slotWidth - font:getWidth(glyph ~= "" and glyph or "-")) / 2),
      slotsY + math.floor((slotHeight - font:getHeight()) / 2))
  end
  printAt(G, font, theme.colors.muted, counter,
    naming.entry.x + naming.entry.w - font:getWidth(counter),
    entryY)
  lineAt(G, theme.colors.muted, naming.entry.x, naming.entry.y + naming.entry.h,
    naming.entry.x + naming.entry.w, naming.entry.y + naming.entry.h)

  local cursor = naming.cursor or {}
  for _, cell in ipairs(naming.cells or {}) do
    local selected
    if cell.kind == "bottom" then
      selected = cursor.bottomRow == true
        and (cursor.targetIndex or 0) == cell.index
    else
      selected = cursor.bottomRow ~= true
        and (cursor.row or -1) == cell.row
        and (cursor.col or -1) == cell.col
    end
    local rect = cell.rect
    Color.set(G, selected and theme.colors.selection or theme.colors.raised)
    G.rectangle("fill", rect.x, rect.y, rect.w, rect.h,
      theme.radii and theme.radii.sm or 0)
    if selected then
      Color.set(G, theme.colors.focus)
      G.rectangle("fill", rect.x, rect.y, math.max(2, math.floor(3 * scale)),
        rect.h)
    end
    local value = namingLabel(cell.value)
    local run = resolveTextRun(layout, font, value, math.max(1, rect.w - gap * 2))
    printAt(G, run.font, selected and theme.colors.ink or theme.colors.muted,
      run.text, rect.x + math.max(gap, (rect.w - run.width) / 2),
      rect.y + math.floor((rect.h - run.height) / 2))
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
      printFitted(G, layout, font, theme.colors.ink, details.title, top.x, y,
        top.w)
      y = y + font:getHeight() + math.max(3, math.floor(4 * layout.scale))
    end
    for _, field in ipairs(details.fields or {}) do
      if y + font:getHeight() > top.y + top.h then break end
      local value = tostring(field.value or "")
      printFitted(G, layout, font, theme.colors.muted, field.label or "",
        rich.fieldX, y, rich.fieldWidth * 0.42)
      local valueRun = resolveTextRun(layout, font, value,
        rich.fieldWidth * 0.52)
      printAt(G, valueRun.font, field.style == "accent"
        and theme.colors.focus or theme.colors.ink, valueRun.text,
        rich.fieldX + rich.fieldWidth - valueRun.width,
        y + math.floor((font:getHeight() - valueRun.height) / 2))
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
      printFitted(G, layout, font, theme.colors.muted, label, rich.fieldX, y,
        rich.fieldWidth * 0.42)
      if value ~= "" then
        local valueRun = resolveTextRun(layout, font, value,
          rich.fieldWidth * 0.52)
        printAt(G, valueRun.font, progress.style == "accent"
          and theme.colors.focus or theme.colors.ink, valueRun.text,
          rich.fieldX + rich.fieldWidth - valueRun.width,
          y + math.floor((font:getHeight() - valueRun.height) / 2))
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
      printFitted(G, layout, font, field.style == "accent"
        and theme.colors.focus or theme.colors.ink, combined, rect.x, rect.y,
        rect.w)
    end
    for _, section in ipairs(rich.footerSections or {}) do
      printFitted(G, layout, font, theme.colors.muted,
        section.section.title or "", section.title.x, section.title.y,
        section.title.w)
      for _, measured in ipairs(section.items or {}) do
        local item, rect = measured.item, measured.rect
        local value = tostring(item.value or "")
        printFitted(G, layout, font, theme.colors.ink, item.label or "",
          rect.x, rect.y, rect.w * 0.62)
        if value ~= "" then
          local valueRun = resolveTextRun(layout, font, value, rect.w * 0.35)
          printAt(G, valueRun.font, theme.colors.ink, valueRun.text,
            rect.x + rect.w - valueRun.width,
            rect.y + math.floor((font:getHeight() - valueRun.height) / 2))
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
    printFitted(G, layout, font, theme.colors.muted, label, region.x + gap,
      y, region.w * 0.42)
    local valueRun = resolveTextRun(layout, font, value, region.w * 0.5)
    printAt(G, valueRun.font, field.style == "accent"
      and theme.colors.focus or theme.colors.ink, valueRun.text,
      region.x + region.w - gap - valueRun.width,
      y + math.floor((font:getHeight() - valueRun.height) / 2))
    y = y + font:getHeight() + gap
  end
  return true
end

local function drawShellStatus(G, model, shell, font, theme, scale, layout)
  local status = shell.status
  Color.set(G, theme.colors.raised)
  G.rectangle("fill", status.x, status.y, status.w, status.h)
  local value = model.statusBar
    or (model.shell and model.shell.statusBar) or {}
  local left = tostring(value.time or "--:--")
  local right = tostring(value.region or "POKEGEAR")
  printFitted(G, layout, font, theme.colors.ink, left,
    status.x + math.floor(8 * scale),
    status.y + math.floor((status.h - font:getHeight()) / 2), status.w * 0.45)
  local rightRun = resolveTextRun(layout, font, right, status.w * 0.45)
  printAt(G, rightRun.font, theme.colors.gen2Accent or theme.colors.focus,
    rightRun.text, status.x + status.w - rightRun.width - math.floor(8 * scale),
    status.y + math.floor((status.h - rightRun.height) / 2))
  lineAt(G, theme.colors.muted, status.x, status.y + status.h - 1,
    status.x + status.w, status.y + status.h - 1)
end

local function drawShellRail(G, model, shell, font, theme, scale, layout)
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
    printFitted(G, layout, font, theme.colors.ink, label,
      rect.x + math.floor(4 * scale),
      rect.y + math.floor((rect.h - font:getHeight()) / 2),
      math.max(1, rect.w - math.floor(8 * scale)))
  end
end

local function drawShellDetails(G, model, rect, font, theme, scale, layout)
  local details = model.details or {}
  if type(details) ~= "table" or #details == 0 then return end
  local gap = math.max(6, math.floor(8 * scale))
  local y = rect.y + math.max(8, math.floor(12 * scale))
  for _, field in ipairs(details) do
    if y + font:getHeight() > rect.y + rect.h then break end
    local label = tostring(field.label or "")
    local value = tostring(field.value or "")
    printFitted(G, layout, font, theme.colors.muted, label, rect.x + gap, y,
      rect.w * 0.42)
    local valueRun = resolveTextRun(layout, font, value, rect.w * 0.5)
    printAt(G, valueRun.font, field.style == "accent"
      and theme.colors.focus or theme.colors.ink, valueRun.text,
      rect.x + rect.w - gap - valueRun.width,
      y + math.floor((font:getHeight() - valueRun.height) / 2))
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
  drawShellStatus(G, model, shell, font, theme, scale, layout)
  Color.set(G, theme.colors.raised)
  G.rectangle("fill", shell.content.x, shell.content.y,
    shell.content.w, shell.content.h)
  local screen = model.screen or (model.shell and model.shell.screen) or {}
  local title = tostring(screen.title or model.title or "POKEGEAR")
  if model.view == "strip" then
    local active = model.activeApp or {}
    printFitted(G, layout, font, theme.colors.gen2Accent or theme.colors.focus,
      title, shell.content.x + 12, shell.content.y + 14, shell.content.w - 24)
    printFitted(G, layout, font, theme.colors.ink,
      active.label or "SELECT AN APP", shell.content.x + 12,
      shell.content.y + 48, shell.content.w - 24)
    printFitted(G, layout, font, theme.colors.muted,
      active.subtitle or "LEFT/RIGHT TO BROWSE", shell.content.x + 12,
      shell.content.y + 48 + font:getHeight() + 6, shell.content.w - 24)
  elseif layout.mapView then
    drawMap(G, model, layout, font, theme)
    if model.flyView then drawRows(G, model, layout, font, theme) end
  elseif #layout.rows > 0 then
    drawRows(G, model, layout, font, theme)
  else
    drawShellDetails(G, model, shell.content, font, theme, scale, layout)
  end
  drawShellRail(G, model, shell, font, theme, scale, layout)
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
  -- Modal titles are a reusable heading surface, not another body row. Give
  -- the larger semantic run a small inset so its top pixels cannot touch the
  -- frame even when the title font is one step above the body font.
  local titleInset = math.max(8, math.floor(12 * layout.scale))
  printStyledFitted(G, layout, font, theme, title,
    modal.inner.x, modal.inner.y + titleInset, modal.inner.w, "title")
  for _, measured in ipairs(modal.options or {}) do
    local option, rect = measured.option, measured.rect
    if measured.index == descriptor.selected then
      Color.set(G, theme.colors.selection)
      G.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
      Color.set(G, theme.colors.focus)
      G.rectangle("fill", rect.x, rect.y,
        math.max(2, math.floor(3 * layout.scale)), rect.h)
    end
    printFitted(G, layout, font,
      option.disabled and theme.colors.muted or theme.colors.ink,
      option.label, rect.x + 10,
      rect.y + math.floor((rect.h - font:getHeight()) / 2), rect.w - 20)
  end
end

local function drawMenuHeader(G, model, layout, font, theme)
  local titleY = layout.header.y
    + math.floor((layout.header.h - font:getHeight()) / 2)
  printStyledFitted(G, layout, font, theme, model.title or "MENU",
    layout.header.x, titleY, layout.header.w, "title")
  lineAt(G, theme.colors.muted, layout.header.x,
    layout.header.y + layout.header.h - 1,
    layout.header.x + layout.header.w,
    layout.header.y + layout.header.h - 1)
end

local function drawMenuFooter(G, model, layout, font, theme, centerText)
  lineAt(G, theme.colors.muted, layout.footer.x, layout.footer.y,
    layout.footer.x + layout.footer.w, layout.footer.y)
  local value = centerText or model.description or model.controls or ""
  if type(value) == "table" then value = table.concat(value, " ") end
  value = tostring(value or "")
  if centerText then
    local run = resolveTextRun(layout, font, value, layout.footer.w)
    printAt(G, run.font, theme.colors.ink, run.text,
      layout.footer.x + math.max(0, (layout.footer.w - run.width) / 2),
      layout.footer.y + math.floor((layout.footer.h - run.height) / 2))
    if model.description and model.description ~= "" then
      local back = "B BACK"
      local backRun = resolveTextRun(layout, font, back, layout.footer.w)
      printAt(G, backRun.font, theme.colors.muted, back,
        layout.footer.x + layout.footer.w - backRun.width,
        layout.footer.y + math.floor((layout.footer.h - backRun.height) / 2))
    end
  else
    printFitted(G, layout, font, theme.colors.muted, value, layout.footer.x,
      layout.footer.y + math.floor((layout.footer.h - font:getHeight()) / 2),
      layout.footer.w)
  end
end

local function drawGender(G, gender, icon, x, y, font, theme, scale, clock,
    requestedSize)
  if genderKind(gender) then
    if type(icon) ~= "table" or type(icon.path) ~= "string" then
      return nil, "gender_asset_missing",
        "a known gender requires an authored gender icon descriptor"
    end
    local fontHeight = font and type(font.getHeight) == "function"
      and tonumber(font:getHeight()) or 1
    local iconSize = math.max(1, math.floor(tonumber(requestedSize)
      or fontHeight + 0.5))
    local resolvedIcon = resolveGenderIcon(icon, font)
    local ok = drawSprite(G, resolvedIcon, {
      x=x, y=y + math.floor((font:getHeight() - iconSize) / 2),
      w=iconSize, h=iconSize,
    }, clock)
    if ok == true then return iconSize end
    return nil, "gender_asset_unavailable",
      "the authored gender icon could not be drawn"
  end
  return 0
end

local function drawProgressBar(G, label, value, fraction, rect, font, theme,
    fillColor, scale, layout)
  local valueText = tostring(value or "")
  local labelRun = resolveTextRun(layout, font, label, rect.w)
  local valueRun = resolveTextRun(layout, font, valueText, rect.w)
  local labelWidth = labelRun.width
  local valueWidth = valueRun.width
  local barWidth = math.max(14, rect.w - labelWidth - valueWidth
    - math.floor(11 * scale))
  printStyled(G, labelRun.font, theme, labelRun.text, rect.x,
    rect.y + math.floor((font:getHeight() - labelRun.height) / 2), "label")
  local bar = {
    x=rect.x + labelWidth + math.floor(4 * scale),
    y=rect.y + math.floor((font:getHeight() - math.max(5, math.floor(7 * scale))) / 2),
    w=barWidth, h=math.max(5, math.floor(7 * scale)),
  }
  Color.set(G, theme.colors.muted)
  G.rectangle("fill", bar.x, bar.y, bar.w, bar.h)
  Color.set(G, fillColor or "#5B9555")
  G.rectangle("fill", bar.x + 1, bar.y + 1,
    math.max(0, (bar.w - 2) * math.max(0, math.min(1,
      tonumber(fraction) or 0))), math.max(1, bar.h - 2))
  printStyled(G, valueRun.font, theme, valueRun.text,
    bar.x + bar.w + math.floor(4 * scale),
    rect.y + math.floor((font:getHeight() - valueRun.height) / 2), "value")
end

local function drawPartyHp(G, row, rect, font, theme, scale, layout)
  local hp = tonumber(row.hp) or 0
  local maxHp = tonumber(row.maxHp) or 0
  drawProgressBar(G, "hp", ("%d / %d"):format(hp, maxHp),
    row.hpFraction or (maxHp > 0 and hp / maxHp or 0), rect, font, theme,
    theme.colors.hpBar or "#5B9555", scale, layout)
end

local function drawPartyList(G, model, layout, font, theme)
  local list = layout.partyList
  if type(list) ~= "table" then return nil, "party_list_layout_missing" end
  local scale = layout.scale or 1
  local columns = list.columns or {}
  partyIconClock = (partyIconClock + 1) % 2048
  drawMenuHeader(G, model, layout, font, theme)
  for _, measured in ipairs(list.rows or {}) do
    local row, rect = measured.row, measured.rect
    Color.set(G, theme.colors.paper)
    G.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
    if measured.index == model.selected then
      Color.set(G, theme.colors.focus)
      G.setLineWidth(math.max(1, math.floor(scale)))
      G.rectangle("line", rect.x, rect.y, rect.w, rect.h)
    end
    local gap = columns.gap or math.max(5, math.floor(8 * scale))
    local iconSize = columns.pokemonIconSize
      or math.min(math.max(1, rect.h - gap * 2), math.floor(34 * scale))
    local iconRect = {
      x=rect.x + gap, y=rect.y + (rect.h - iconSize) / 2,
      w=iconSize, h=iconSize,
    }
    if row.icon then
      local spriteOk, spriteCode, spriteMessage = drawSprite(G, row.icon,
        iconRect, partyIconClock)
      if spriteOk ~= true then return nil, spriteCode, spriteMessage end
    end
    local identityX = iconRect.x + iconRect.w + gap
    local statusWidth = columns.statusWidth or math.max(30,
      math.floor(rect.w * 0.13))
    local typeWidth = columns.typeWidth or math.max(66,
      math.floor(rect.w * 0.32))
    local hpWidth = columns.hpWidth or math.max(76,
      math.floor(rect.w * 0.29))
    local levelWidth = columns.levelWidth or math.max(math.floor(42 * scale),
      font:getWidth("Lv.99") + gap)
    local rightX = rect.x + rect.w - gap - typeWidth
    local statusX = rightX - gap - statusWidth
    local hpX = statusX - gap - hpWidth
    local levelX = hpX - gap - levelWidth
    local nameWidth = math.max(30, levelX - identityX - gap)
    local textY = rect.y + math.floor((rect.h - font:getHeight()) / 2)
    if row.kind == "empty" then
      printStyled(G, font, theme, "—", identityX, textY, "muted")
    else
      local genderWidth, genderCode, genderMessage = drawGender(G, row.gender,
        row.genderIcon, identityX, textY, font, theme, scale, partyIconClock,
        columns.genderIconSize)
      if genderWidth == nil then return nil, genderCode, genderMessage end
      local nameX = identityX + genderWidth + (genderWidth > 0 and 4 or 0)
      local nameStyle = row.disabled and "muted"
        or (measured.index == model.selected and "heading" or "strong")
      printStyledFitted(G, layout, font, theme,
        row.label or (row.isEgg and "EGG" or "POKEMON"), nameX, textY,
        nameWidth, nameStyle)
      printStyledFitted(G, layout, font, theme,
        ("Lv.%s"):format(tostring(row.level or "--")), levelX, textY,
        levelWidth, "label")
      if not row.isEgg and row.hp ~= nil and row.maxHp ~= nil then
        drawPartyHp(G, row, { x=hpX, y=textY, w=hpWidth, h=font:getHeight() },
          font, theme, scale, layout)
        drawStatusBadge(G, row.status, {
          x=statusX, y=rect.y + math.max(1, (rect.h - font:getHeight()) / 2),
          w=statusWidth, h=math.max(font:getHeight() + 4, math.floor(22 * scale)),
        }, font, theme, scale)
      end
      drawTypeBadges(G, row.types, {
        x=rightX, y=rect.y + math.max(1, (rect.h
          - math.max(font:getHeight() + 4, math.floor(22 * scale))) / 2),
        w=typeWidth, h=math.max(1, rect.h - 2),
      }, font, theme, scale)
    end
    lineAt(G, theme.colors.muted, rect.x, rect.y + rect.h - 1,
      rect.x + rect.w, rect.y + rect.h - 1)
  end
  drawMenuFooter(G, model, layout, font, theme, model.partyCountText)
  drawModal(G, model, layout, font, theme)
  return true
end

local function drawSummaryField(G, label, value, rect, font, theme, style, scale,
    layout)
  if not rect or rect.h <= 0 then return end
  Color.set(G, theme.colors.raised, 0.32)
  G.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
  local labelWidth = math.min(rect.w * 0.46, font:getWidth(label) + 4)
  local textY = rect.y + math.floor((rect.h - font:getHeight()) / 2)
  printStyledFitted(G, layout, font, theme, label,
    rect.x + math.floor(8 * (scale or 1)), textY, labelWidth, "label")
  local text = tostring(value or "")
  local valueRun = resolveTextRun(layout, font, text, rect.w - labelWidth)
  printStyled(G, valueRun.font, theme, valueRun.text,
    rect.x + rect.w - valueRun.width,
    textY + math.floor((font:getHeight() - valueRun.height) / 2),
    style == "accent" and "accent" or "value")
  lineAt(G, theme.colors.muted, rect.x, rect.y + rect.h - 1,
    rect.x + rect.w, rect.y + rect.h - 1)
end

local function drawSummaryIdentity(G, model, layout, font, theme)
  local summary = model.summary or {}
  local mon = summary.pokemon or {}
  local status = summary.status or {}
  local scale = layout.scale or 1
  local portrait = layout.summary.portrait
  Color.set(G, theme.colors.raised)
  G.rectangle("fill", portrait.x, portrait.y, portrait.w, portrait.h)
  if model.artwork then
    local spriteOk, spriteCode, spriteMessage = drawSprite(G, model.artwork,
      { x=portrait.x + math.floor(4 * scale),
        y=portrait.y + math.floor(4 * scale),
        w=math.max(1, portrait.w - math.floor(8 * scale)),
        h=math.max(1, portrait.h - math.floor(8 * scale)) })
    if spriteOk ~= true then return nil, spriteCode, spriteMessage end
  end
  local info = layout.summary.info
  Color.set(G, theme.colors.paper)
  G.rectangle("fill", info.x, info.y, info.w, info.h)
  local x, y = info.x + math.floor(8 * scale), info.y + math.floor(6 * scale)
  local name = mon.name or mon.speciesName or "POKEMON"
  local speciesName = mon.speciesName or "POKEMON"
  -- Keep the species row present for every Pokemon.  When a nickname is
  -- absent the heading and caption intentionally repeat the species; the
  -- stable two-line identity rail is more important than collapsing the row
  -- and making every other identity element jump vertically.
  local showSpecies = type(speciesName) == "string" and speciesName ~= ""
  local nameRun = printStyledFitted(G, layout, font, theme, name, x, y,
    info.w * 0.55, "heading")
  local level = ("Lv.%s"):format(tostring(mon.level or "--"))
  local levelRun = resolveTextRun(layout, font, level, info.w * 0.35)
  printAt(G, levelRun.font, theme.colors.ink, levelRun.text,
    info.x + info.w - levelRun.width - math.floor(8 * scale),
    y + math.floor((math.max(font:getHeight(), nameRun.height)
      - levelRun.height) / 2))
  local identityTextHeight = math.max(font:getHeight(), nameRun.height)
  if showSpecies then
    local speciesRun = printStyledFitted(G, layout, font, theme, speciesName,
      x, y + identityTextHeight + math.max(1, math.floor(2 * scale)),
      info.w * 0.55, "caption")
    identityTextHeight = identityTextHeight + speciesRun.height
      + math.max(1, math.floor(2 * scale))
  end
  y = y + identityTextHeight + math.max(5, math.floor(6 * scale))
  local genderWidth, genderCode, genderMessage = drawGender(G, mon.gender,
    mon.genderIcon, x, y, font, theme, scale, nil,
    layout.summary.genderIconSize)
  if genderWidth == nil then return nil, genderCode, genderMessage end
  local typeX = x + genderWidth + (genderWidth > 0 and 8 or 0)
  local badgeHeight = math.max(font:getHeight() + math.floor(4 * scale),
    math.floor(22 * scale))
  drawTypeBadges(G, status.types, {
    x=typeX, y=y - math.floor(2 * scale),
    w=math.max(1, info.x + info.w - typeX - math.floor(8 * scale)),
    h=math.max(1, badgeHeight),
  }, font, theme, scale)
  local hpY = y + badgeHeight + math.max(5, math.floor(7 * scale))
  local bottomY = info.y + info.h - font:getHeight()
    - math.floor(8 * scale)
  if hpY + font:getHeight() > bottomY - math.floor(4 * scale) then
    hpY = math.max(y + font:getHeight(),
      bottomY - font:getHeight() - math.floor(4 * scale))
  end
  local hp = tonumber(status.hp) or 0
  local maxHp = tonumber(status.maxHp) or 0
  drawPartyHp(G, { hp=hp, maxHp=maxHp,
    hpFraction=maxHp > 0 and hp / maxHp or 0 }, {
      x=x, y=hpY, w=info.w * 0.48, h=font:getHeight(),
    }, font, theme, scale, layout)
  drawStatusBadge(G, status.status, {
    x=x, y=info.y + info.h - font:getHeight() - math.floor(8 * scale),
    w=math.max(38, math.floor(52 * scale)),
    h=math.max(font:getHeight() + 4, math.floor(22 * scale)),
  }, font, theme, scale)
  if status.status == "OK" then
    printStyledFitted(G, layout, font, theme, "HEALTHY", x,
      info.y + info.h - font:getHeight() - math.floor(6 * scale),
      info.w * 0.45, "label")
  end
  local experience = status.experience or {}
  local nextLevel = tonumber(experience.nextLevel)
  local toNext = tonumber(experience.toNext)
  local expValue = nextLevel and nextLevel >= 100 and "MAX"
    or (toNext and ("NXT " .. tostring(math.max(0, math.floor(toNext))))
      or "--")
  drawProgressBar(G, "EXP", expValue, experience.fraction or 0, {
    x=info.x + info.w * 0.53, y=hpY, w=info.w * 0.39,
    h=font:getHeight(),
  }, font, theme, theme.colors.expBar or "#356AC3", scale, layout)
  return true
end

local function drawSummaryTabs(G, model, layout, font, theme)
  for _, measured in ipairs(layout.tabs or {}) do
    local tab, rect = measured.tab, measured.rect
    if tab.selected then
      Color.set(G, theme.colors.selection)
      G.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
      Color.set(G, theme.colors.focus)
      G.rectangle("fill", rect.x, rect.y + rect.h - math.max(2, math.floor(layout.scale)),
        rect.w, math.max(2, math.floor(layout.scale)))
    end
    local style = tab.selected and "strong" or "label"
    printStyledFitted(G, layout, font, theme, tab.label or tab.id,
      rect.x + math.floor(4 * layout.scale),
      rect.y + math.floor((rect.h - font:getHeight()) / 2),
      math.max(1, rect.w - math.floor(8 * layout.scale)), style)
  end
end

local function drawSummaryMoves(G, model, layout, font, theme)
  local summary = model.summary or {}
  local moves = summary.moves or {}
  local selected = (summary.moveDetail and summary.moveDetail.selectedIndex)
    or model.selected or 1
  local scale = layout.scale or 1
  for _, measured in ipairs(layout.summary.moveRows or {}) do
    local row, rect = measured.row, measured.rect
    local active = measured.index == selected
    Color.set(G, active and theme.colors.selection or theme.colors.paper)
    G.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
    if active then
      Color.set(G, theme.colors.focus)
      G.setLineWidth(math.max(1, math.floor(scale)))
      G.rectangle("line", rect.x, rect.y, rect.w, rect.h)
    end
    local move = moves[measured.index]
    local name = move and move.name or row.label or "---"
    local typeRectW = layout.summary.typeBadgeWidth
      or math.min(96 * scale, rect.w * 0.26)
    local ppText = move and ("%d/%d"):format(move.pp, move.maxPp) or "--"
    local power = move and move.power or "--"
    printStyledFitted(G, layout, font, theme, name,
      rect.x + math.floor(8 * scale),
      rect.y + math.floor((rect.h - font:getHeight()) / 2),
      rect.w * 0.36, move and "strong" or "muted")
    if move then
      drawTypeBadges(G, { move.type }, {
        x=rect.x + rect.w * 0.40,
        y=rect.y + math.max(1, (rect.h - math.floor(22 * scale)) / 2),
        w=typeRectW, h=rect.h,
      }, font, theme, scale)
    end
    local ppRun = resolveTextRun(layout, font, ppText, rect.w * 0.18)
    local ppX = rect.x + rect.w - ppRun.width - math.floor(8 * scale)
    printStyled(G, ppRun.font, theme, ppRun.text, ppX,
      rect.y + math.floor((rect.h - ppRun.height) / 2), "label")
    local powerText = ("PWR %s"):format(tostring(power))
    local powerRun = resolveTextRun(layout, font, powerText, rect.w * 0.28)
    printStyled(G, powerRun.font, theme, powerRun.text,
      ppX - powerRun.width - math.floor(12 * scale),
      rect.y + math.floor((rect.h - powerRun.height) / 2), "label")
    lineAt(G, theme.colors.muted, rect.x, rect.y + rect.h - 1,
      rect.x + rect.w, rect.y + rect.h - 1)
  end
  local info = layout.summary.moveInfo
  if not info then return end
  Color.set(G, theme.colors.raised)
  G.rectangle("fill", info.x, info.y, info.w, info.h)
  local move = moves[selected]
  local title = move and (move.name .. " INFO") or "MOVE INFO"
  local infoPad = math.max(8, math.floor(10 * scale))
  local splitX = info.x + math.floor(info.w * 0.66)
  local titleRun = printStyledFitted(G, layout, font, theme, title,
    info.x + infoPad, info.y + infoPad,
    math.max(1, splitX - info.x - infoPad * 2), "heading")
  local contentY = info.y + infoPad + titleRun.height
    + math.max(5, math.floor(6 * scale))
  local lines = move and move.description or {}
  local descriptionWidth = math.max(1, splitX - info.x - infoPad * 2)
  for index, line in ipairs(lines) do
    local y = contentY + (index - 1) * (font:getHeight() + 2)
    if y + font:getHeight() > info.y + info.h then break end
    printStyledFitted(G, layout, font, theme, line,
      info.x + infoPad, y, descriptionWidth, "body")
  end
  -- The right side is a compact metadata rail. It uses only move fields
  -- exposed by V3, so it adds hierarchy and useful density without inventing
  -- accuracy or other unavailable Gen II data.
  local railX = splitX + math.floor(12 * scale)
  local railW = math.max(1, info.x + info.w - railX - infoPad)
  Color.set(G, theme.colors.muted, 0.45)
  G.rectangle("fill", splitX, info.y + infoPad,
    math.max(1, math.floor(scale)),
    math.max(1, info.h - infoPad * 2))
  printStyledFitted(G, layout, font, theme, "MOVE DATA", railX,
    info.y + infoPad, railW, "subheading")
  local railY = info.y + infoPad + font:getHeight()
    + math.max(6, math.floor(8 * scale))
  if move then
    printStyledFitted(G, layout, font, theme, "TYPE", railX, railY,
      railW * 0.38, "label")
    drawTypeBadges(G, { move.type }, {
      x=railX + railW * 0.38, y=railY - math.floor(3 * scale),
      w=railW * 0.62, h=math.max(1, math.floor(26 * scale)),
    }, font, theme, scale)
    railY = railY + math.max(font:getHeight(), math.floor(22 * scale))
      + math.max(6, math.floor(8 * scale))
    local function moveMeta(label, value)
      printStyledFitted(G, layout, font, theme, label, railX, railY,
        railW * 0.42, "label")
      local run = resolveTextRun(layout, font, tostring(value or "--"),
        railW * 0.54)
      printStyled(G, run.font, theme, run.text,
        railX + railW - run.width,
        railY + math.floor((font:getHeight() - run.height) / 2), "value")
      railY = railY + font:getHeight() + math.max(5, math.floor(7 * scale))
    end
    moveMeta("POWER", move.power or "--")
    moveMeta("PP", ("%d / %d"):format(move.pp or 0, move.maxPp or 0))
  end
end

local function drawSummaryControls(G, model, layout, font, theme)
  local footer = layout.footer
  if type(footer) ~= "table" then return end
  lineAt(G, theme.colors.muted, footer.x, footer.y,
    footer.x + footer.w, footer.y)
  local legend = model.controlLegend
  if type(legend) ~= "table" or #legend == 0 then
    drawMenuFooter(G, model, layout, font, theme, "")
    return
  end
  local scale = layout.scale or 1
  local segmentWidth = footer.w / #legend
  for index, entry in ipairs(legend) do
    local text = type(entry) == "table" and entry.label or entry
    text = tostring(text or "")
    if text ~= "" then
      local run = resolveTextRun(layout, font, text,
        math.max(1, segmentWidth - math.floor(8 * scale)), {
          stepDelta=-1,
        })
      local segmentX = footer.x + (index - 1) * segmentWidth
      printStyled(G, run.font, theme, run.text,
        segmentX + math.max(0, (segmentWidth - run.width) / 2),
        footer.y + math.floor((footer.h - run.height) / 2), "label")
    end
  end
end

local function drawSummaryPage(G, model, layout, font, theme)
  if type(layout.summary) ~= "table" then
    return nil, "summary_layout_missing"
  end
  drawMenuHeader(G, model, layout, font, theme)
  drawSummaryTabs(G, model, layout, font, theme)
  local identityOk, identityCode, identityMessage = drawSummaryIdentity(
    G, model, layout, font, theme)
  if identityOk ~= true then return nil, identityCode, identityMessage end
  local summary = model.summary or {}
  local scale = layout.scale or 1
  if model.purpose == "moves" or model.mode == "move_reorder" then
    drawSummaryMoves(G, model, layout, font, theme)
  else
    local content = layout.summary.content
    if content then
      Color.set(G, theme.colors.paper)
      G.rectangle("fill", content.x, content.y, content.w, content.h)
      local fields = {}
      if summary.purpose == "status" then
        local status, exp = summary.status or {},
          summary.status and summary.status.experience or {}
        fields = {
          { "HP", ("%d/%d"):format(status.hp or 0, status.maxHp or 0) },
          { "STATUS", status.status or "OK",
            status.status and status.status ~= "OK" and "accent" or nil },
          { "TYPE", typeLabelList(status.types) },
          { "EXP", exp.experience or "--" },
          { "NEXT", exp.toNext or "--" },
          { "DEX", (summary.pokemon or {}).dex or "--" },
          { "HELD", summary.heldItem and summary.heldItem.name or "NONE" },
          { "POKERUS", status.pokerus or "NONE" },
        }
      elseif summary.purpose == "stats" then
        local trainer = summary.stats and summary.stats.trainer or {}
        fields = {
          { "OT", trainer.name }, { "ID", trainer.id },
          { "TYPE", typeLabelList(summary.status and summary.status.types) },
          { "DEX", (summary.pokemon or {}).dex or "--" },
        }
        for _, stat in ipairs(summary.stats and summary.stats.values or {}) do
          fields[#fields + 1] = { stat.label, stat.value }
        end
        fields[#fields + 1] = {
          "HELD", summary.heldItem and summary.heldItem.name or "NONE",
        }
      elseif summary.purpose == "egg" then
        for _, line in ipairs(summary.egg and summary.egg.lines or {}) do
          fields[#fields + 1] = { "", line }
        end
      end
      local columns = 2
      local fieldGap = math.max(8, math.floor(12 * scale))
      local cellWidth = math.max(1, (content.w - fieldGap) / columns)
      local sectionTitle = summary.purpose == "status" and "JOURNAL"
        or (summary.purpose == "stats" and "DETAILS" or "EGG")
      local sectionHeight = font:getHeight() + math.max(8,
        math.floor(12 * scale))
      printStyledFitted(G, layout, font, theme, sectionTitle,
        content.x + math.floor(8 * scale), content.y + math.floor(4 * scale),
        content.w, "heading")
      lineAt(G, theme.colors.focus, content.x,
        content.y + sectionHeight - 1, content.x + content.w,
        content.y + sectionHeight - 1)
      local rowCount = math.max(1, math.ceil(#fields / columns))
      local usableHeight = math.max(1, content.h - sectionHeight
        - math.max(0, rowCount - 1) * fieldGap)
      local lineHeight = math.max(font:getHeight() + math.floor(6 * scale),
        math.floor(usableHeight / rowCount))
      for index, field in ipairs(fields) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        drawSummaryField(G, tostring(field[1] or ""), field[2], {
          x=content.x + column * (cellWidth + fieldGap),
          y=content.y + sectionHeight + row * (lineHeight + fieldGap),
          w=cellWidth, h=lineHeight,
        }, font, theme, field[3], scale, layout)
      end
    end
  end
  drawSummaryControls(G, model, layout, font, theme)
  drawModal(G, model, layout, font, theme)
  return true
end

-- Shared by production menu and battle presenters. The descriptor remains
-- data-only; the runtime owns the image loader and palette shader.
MenuRender.drawSprite = drawSprite
MenuRender.drawTypeBadges = drawTypeBadges
MenuRender.drawStatusBadge = drawStatusBadge
MenuRender.drawSprite = drawSprite
MenuRender.resolveGenderIcon = resolveGenderIcon
MenuRender.textStyles = TEXT_STYLES
MenuRender.textStyleOptions = textStyleOptions
MenuRender.drawText = printStyled
MenuRender.resolveTextRun = resolveTextRun
MenuRender.printFitted = printFitted
MenuRender.printStyledFitted = printStyledFitted

function MenuRender.draw(graphics, model, layout, font, theme)
  if model.appShell or model.kind == "device" then
    return drawAppShell(graphics, model, layout, font, theme)
  end
  if model.opaque then
    Color.set(graphics, theme.colors.raised)
    graphics.rectangle("fill", 0, 0, layout.viewport.w, layout.viewport.h)
  end
  Frame.draw(graphics, layout.outer, theme, layout.scale)
  if model.partyLayout == "list" then
    local ok, code, message = drawPartyList(graphics, model, layout, font,
      theme)
    graphics.setColor(1, 1, 1, 1)
    if ok ~= true then return nil, code, message end
    return true
  elseif model.partyLayout == "summary" then
    local ok, code, message = drawSummaryPage(graphics, model, layout, font,
      theme)
    graphics.setColor(1, 1, 1, 1)
    if ok ~= true then return nil, code, message end
    return true
  end
  local titleY = layout.header.y
    + math.floor((layout.header.h - font:getHeight()) / 2)
  printStyledFitted(graphics, layout, font, theme, model.title or "MENU",
    layout.header.x, titleY, layout.header.w, "heading")
  lineAt(graphics, theme.colors.muted, layout.header.x,
    layout.header.y + layout.header.h - 1,
    layout.header.x + layout.header.w,
    layout.header.y + layout.header.h - 1)
  drawMap(graphics, model, layout, font, theme)
  if layout.naming then drawNaming(graphics, model, layout, font, theme)
  else drawRows(graphics, model, layout, font, theme) end
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
  printFitted(graphics, layout, font, theme.colors.muted,
    description or model.controls or "A CHOOSE   B BACK", layout.footer.x,
    layout.footer.y + math.floor((layout.footer.h - font:getHeight()) / 2),
    layout.footer.w)
  drawModal(graphics, model, layout, font, theme)
  graphics.setColor(1, 1, 1, 1)
  return true
end

return MenuRender
