local requireCore = ...
local Rect = requireCore("geometry.rect")

local Viewport = {}

function Viewport.dimensions(viewport, graphics)
  local width = viewport and (viewport.width or viewport.w)
  local height = viewport and (viewport.height or viewport.h)
  if (not width or not height) and graphics and graphics.getDimensions then
    width, height = graphics.getDimensions()
  end
  return math.max(1, math.floor(tonumber(width) or 1)),
    math.max(1, math.floor(tonumber(height) or 1))
end

function Viewport.rect(viewport, graphics)
  local width, height = Viewport.dimensions(viewport, graphics)
  return Rect.new(0, 0, width, height)
end

function Viewport.safeArea(viewport, graphics, window)
  local full = Viewport.rect(viewport, graphics)
  if not (window and window.getSafeArea) then return full end
  local ok, x, y, width, height = pcall(window.getSafeArea)
  if not ok or type(x) ~= "number" or type(y) ~= "number"
      or type(width) ~= "number" or type(height) ~= "number"
      or width <= 0 or height <= 0 then
    return full
  end

  -- Some platforms report the safe area in framebuffer pixels while render
  -- hooks use LÖVE window units. Convert only when the values prove that the
  -- two spaces differ; ordinary desktop coordinates remain untouched.
  if (width > full.w + 0.5 or height > full.h + 0.5)
      and graphics and graphics.getPixelDimensions then
    local pixelWidth, pixelHeight = graphics.getPixelDimensions()
    local dpiX = pixelWidth and pixelWidth > 0 and pixelWidth / full.w or 1
    local dpiY = pixelHeight and pixelHeight > 0 and pixelHeight / full.h or 1
    if dpiX > 1.01 or dpiY > 1.01 then
      x, width = x / dpiX, width / dpiX
      y, height = y / dpiY, height / dpiY
    end
  end

  x = math.max(0, math.min(x, full.w))
  y = math.max(0, math.min(y, full.h))
  width = math.max(1, math.min(width, full.w - x))
  height = math.max(1, math.min(height, full.h - y))
  return Rect.new(x, y, width, height)
end

return Viewport
