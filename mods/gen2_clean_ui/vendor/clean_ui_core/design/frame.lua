local requireCore = ...
local Color = requireCore("design.color")

local Frame = {}

local function points(rect, cut)
  local x, y, w, h = rect.x, rect.y, rect.w, rect.h
  cut = math.max(0, math.min(cut, w / 2, h / 2))
  return { x + cut, y, x + w - cut, y, x + w, y + cut,
    x + w, y + h - cut, x + w - cut, y + h,
    x + cut, y + h, x, y + h - cut, x, y + cut }
end

function Frame.draw(graphics, rect, theme, scale)
  local width = math.max(1, math.floor(2 * scale + 0.5))
  local cut = math.max(width * 2, math.floor(7 * scale + 0.5))
  Color.set(graphics, theme.colors.ink)
  graphics.polygon("fill", points(rect, cut))
  local inner = {
    x = rect.x + width, y = rect.y + width,
    w = math.max(0, rect.w - width * 2),
    h = math.max(0, rect.h - width * 2),
  }
  if inner.w > 0 and inner.h > 0 then
    Color.set(graphics, theme.colors.paper)
    graphics.polygon("fill", points(inner, math.max(0, cut - width)))
  end
  return { width = width, cut = cut, inner = inner }
end

return Frame
