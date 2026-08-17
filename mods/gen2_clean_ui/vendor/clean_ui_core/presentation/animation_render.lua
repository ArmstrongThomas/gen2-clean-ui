local requireCore = ...
local Color = requireCore("design.color")
local Frame = requireCore("design.frame")
local MenuRender = requireCore("presentation.menu_render")

local AnimationRender = {}

local function textFit(font, value, width)
  local text = tostring(value or "")
  if font:getWidth(text) <= width then return text end
  while #text > 1 and font:getWidth(text .. "...") > width do
    text = text:sub(1, #text - 1)
  end
  return text .. "..."
end

local function printAt(G, font, color, value, x, y)
  G.setFont(font)
  Color.set(G, color)
  G.print(tostring(value or ""), math.floor(x), math.floor(y))
end

local function drawLabels(G, layout, font, theme, stage, labels)
  for _, label in ipairs(labels or {}) do
    if type(label) == "table" and type(label.text) == "string" then
      local width = stage.w * (tonumber(label.maxWidth) or 1)
      local run = MenuRender.resolveTextRun(layout, font, label.text,
        math.max(1, width))
      local text = run.text
      local x = stage.x + stage.w * (tonumber(label.x) or 0)
      local textWidth = run.width
      if label.align == "center" then
        x = x - textWidth * 0.5
      elseif label.align == "right" then
        x = x - textWidth
      end
      local y = stage.y + stage.h * (tonumber(label.y) or 0)
      printAt(G, run.font, label.color or theme.colors.ink, text, x,
        y + math.floor((font:getHeight() - run.height) / 2))
    end
  end
end

local function number(value)
  local result = tonumber(value)
  if not result or result ~= result then return nil end
  return result
end

local function spriteRect(stage, sprite)
  local rect = type(sprite.rect) == "table" and sprite.rect or sprite
  local x, y = number(rect.x), number(rect.y)
  local w, h = number(rect.w or rect.width), number(rect.h or rect.height)
  if not (x and y and w and h) then return nil end
  -- Normalized rectangles make the same animation portable across every
  -- viewport; pixel rectangles remain useful for source OAM data. An
  -- explicit flag keeps normalized source coordinates that begin just off
  -- screen (for example an OAM sprite entering from x=-8) from being
  -- mistaken for pixel coordinates.
  if sprite.normalized == true or (x >= 0 and x <= 1 and y >= 0 and y <= 1
      and w > 0 and w <= 1 and h > 0 and h <= 1) then
    return { x=stage.x + stage.w * x, y=stage.y + stage.h * y,
      w=stage.w * w, h=stage.h * h }
  end
  return { x=stage.x + x, y=stage.y + y, w=w, h=h }
end

local function progressOf(animation)
  local progress = number(animation.progress)
  if progress == nil then
    local frame, duration = number(animation.frame), number(animation.duration)
    if frame and duration and duration > 0 then progress = frame / duration end
  end
  if progress == nil then return nil end
  return math.max(0, math.min(1, progress))
end

local function tileAt(tilemap, x, y)
  local width, height = tilemap.mapWidth, tilemap.mapHeight
  x = x % width
  y = y % height
  return tilemap.tiles[y * width + x + 1]
end

local function drawTile(G, stage, tilemap, tile, x, y, w, h, cropY,
    cropHeight)
  if tile == nil then return true end
  local sourceTileWidth = tilemap.tileWidth
  local columns = tilemap.sheetColumns
  local crop = {
    x = (tile % columns) * sourceTileWidth,
    y = math.floor(tile / columns) * tilemap.tileHeight + (cropY or 0),
    w = sourceTileWidth,
    h = cropHeight,
  }
  local sprite = {
    path = tilemap.path, crop = crop, palette = tilemap.palette,
    normalized = true, rect = { x=x, y=y, w=w, h=h },
  }
  local ok, code, message = MenuRender.drawSprite(G, sprite, {
    x = stage.x + stage.w * x,
    y = stage.y + stage.h * y,
    w = stage.w * w,
    h = stage.h * h,
  })
  if ok ~= true then return nil, code, message end
  return true
end

local function drawTilemap(G, stage, tilemap)
  local logicalWidth = number(tilemap.logicalWidth) or 160
  local logicalHeight = number(tilemap.logicalHeight) or 144
  local tileWidth = tilemap.tileWidth
  local tileHeight = tilemap.tileHeight
  local scrollX = number(tilemap.scrollX) or 0
  local scrollY = number(tilemap.scrollY) or 0
  local screenW = math.ceil(logicalWidth / tileWidth) + 2
  local screenH = math.ceil(logicalHeight / tileHeight) + 2
  local scanlines = tilemap.scanlineOffsets
  if type(scanlines) == "table" then
    for line = 0, logicalHeight - 1 do
      local offset = scanlines[line + 1] or { x=0, y=0 }
      local sourceX = scrollX + (number(offset.x) or 0)
      local sourceY = line + scrollY + (number(offset.y) or 0)
      local mapRow = math.floor(sourceY / tileHeight)
      local cropY = sourceY - mapRow * tileHeight
      local firstCol = math.floor(sourceX / tileWidth)
      local fractionX = sourceX - firstCol * tileWidth
      for column = 0, screenW - 1 do
        local mapCol = firstCol + column
        local x = (column * tileWidth - fractionX) / logicalWidth
        local y = line / logicalHeight
        local width = tileWidth / logicalWidth
        local height = 1 / logicalHeight
        local tile = tileAt(tilemap, mapCol, mapRow)
        local ok, code, message = drawTile(G, stage, tilemap, tile, x, y,
          width, height, cropY, 1)
        if ok ~= true then return nil, code, message end
      end
    end
    return true
  end
  local firstCol = math.floor(scrollX / tileWidth)
  local firstRow = math.floor(scrollY / tileHeight)
  local fractionX = scrollX - firstCol * tileWidth
  local fractionY = scrollY - firstRow * tileHeight
  for row = 0, screenH - 1 do
    for column = 0, screenW - 1 do
      local tile = tileAt(tilemap, firstCol + column, firstRow + row)
      local x = (column * tileWidth - fractionX) / logicalWidth
      local y = (row * tileHeight - fractionY) / logicalHeight
      local ok, code, message = drawTile(G, stage, tilemap, tile, x, y,
        tileWidth / logicalWidth, tileHeight / logicalHeight, 0,
        tileHeight)
      if ok ~= true then return nil, code, message end
    end
  end
  return true
end

local function drawSprites(G, stage, sprites)
  for _, sprite in ipairs(sprites or {}) do
    if type(sprite) == "table" and type(sprite.path) == "string" then
      local rect = spriteRect(stage, sprite)
      if rect then
        local ok, code, message = MenuRender.drawSprite(G, sprite, rect)
        if ok ~= true then return nil, code, message end
      end
    end
  end
  return true
end

function AnimationRender.draw(graphics, model, layout, font, theme)
  local G = graphics
  local scale = layout.scale or 1
  local animation = model.animation or {}
  local overlay = animation.overlay == true
  if model.opaque and not overlay then
    Color.set(G, theme.colors.raised)
    G.rectangle("fill", 0, 0, layout.viewport.w, layout.viewport.h)
  end
  if not overlay then
    Frame.draw(G, layout.outer, theme, scale)
    Color.set(G, theme.colors.paper)
    G.rectangle("fill", layout.stage.x, layout.stage.y,
      layout.stage.w, layout.stage.h)
  end

  -- Overlay rectangles are normalized data, so a transition can describe a
  -- grid wipe once and remain correct on landscape, portrait, and high-DPI
  -- viewports.  Colors are RGBA arrays in the V3 model.
  for _, rectangle in ipairs(animation.overlays or {}) do
    if type(rectangle) == "table" then
      local rect = spriteRect(layout.stage, rectangle)
      local color = rectangle.color
      if rect and type(color) == "table" then
        G.setColor(color[1] or 0, color[2] or 0, color[3] or 0,
          color[4] == nil and 1 or color[4])
        G.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
      end
    end
  end

  -- Circles are normalized source-authored primitives for effects such as
  -- expanding particles. Radius is normalized against the stage width so the
  -- same data remains stable across landscape, portrait, and high-DPI views.
  for _, circle in ipairs(animation.circles or {}) do
    if type(circle) == "table" then
      local x = number(circle.x)
      local y = number(circle.y)
      local radius = number(circle.radius)
      local color = circle.color or theme.colors.focus
      if x and y and radius and type(color) == "table" then
        G.setColor(color[1] or 0, color[2] or 0, color[3] or 0,
          color[4] == nil and 1 or color[4])
        G.circle("fill", stage.x + stage.w * x, stage.y + stage.h * y,
          math.max(1, stage.w * radius))
      end
    end
  end

  local ok, code, message = drawSprites(G, layout.stage,
    animation.backgroundSprites)
  if ok ~= true then return nil, code, message end

  if animation.tilemap then
    local ok, code, message = drawTilemap(G, layout.stage, animation.tilemap)
    if ok ~= true then return nil, code, message end
  end

  ok, code, message = drawSprites(G, layout.stage, animation.sprites)
  if ok ~= true then return nil, code, message end

  drawLabels(G, layout, font, theme, layout.stage, animation.labels)

  if not overlay then
    local label = animation.label or model.title or animation.id
    local message = animation.message or model.message
    if label and label ~= "" then
      local labelRun = MenuRender.resolveTextRun(layout, font, label,
        layout.stage.w - layout.gap * 2)
      local labelY = layout.stage.y + layout.stage.h * 0.5
        - font:getHeight() * (message and 0.9 or 0.5)
      printAt(G, labelRun.font, theme.colors.ink, labelRun.text,
        layout.stage.x + layout.gap, labelY)
    end
    if message and message ~= "" then
      local messageRun = MenuRender.resolveTextRun(layout, font, message,
        layout.stage.w - layout.gap * 2)
      printAt(G, messageRun.font, theme.colors.muted, messageRun.text,
        layout.stage.x + layout.gap,
        layout.stage.y + layout.stage.h * 0.5 + math.max(2, font:getHeight()))
    end
  end

  if not overlay then
    Color.set(G, theme.colors.raised)
    G.rectangle("fill", layout.caption.x, layout.caption.y,
      layout.caption.w, layout.caption.h)
    local captionRun = MenuRender.resolveTextRun(layout, font,
      model.title or animation.id, layout.caption.w - layout.gap * 2)
    printAt(G, captionRun.font, theme.colors.ink, captionRun.text,
      layout.caption.x + layout.gap,
      layout.caption.y + layout.gap
        + math.floor((font:getHeight() - captionRun.height) / 2))
    local progress = progressOf(animation)
    if progress ~= nil then
      Color.set(G, theme.colors.muted)
      G.rectangle("fill", layout.progress.x, layout.progress.y,
        layout.progress.w, layout.progress.h)
      Color.set(G, theme.colors.gen2Accent or theme.colors.focus)
      G.rectangle("fill", layout.progress.x, layout.progress.y,
        layout.progress.w * progress, layout.progress.h)
    end
  end
  G.setColor(1, 1, 1, 1)
  return true
end

return AnimationRender
