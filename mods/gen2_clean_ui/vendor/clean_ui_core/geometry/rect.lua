local requireCore = ...

local Rect = {}

local function finite(value)
  return type(value) == "number" and value == value
    and value ~= math.huge and value ~= -math.huge
end

function Rect.new(x, y, w, h)
  assert(finite(x) and finite(y) and finite(w) and finite(h), "finite rect required")
  return { x = x, y = y, w = math.max(0, w), h = math.max(0, h) }
end

function Rect.copy(rect)
  return Rect.new(rect.x, rect.y, rect.w, rect.h)
end

function Rect.inset(rect, insets)
  local left = insets.left or insets.x or 0
  local right = insets.right or insets.x or 0
  local top = insets.top or insets.y or 0
  local bottom = insets.bottom or insets.y or 0
  return Rect.new(rect.x + left, rect.y + top,
    rect.w - left - right, rect.h - top - bottom)
end

function Rect.contains(rect, x, y)
  return x >= rect.x and y >= rect.y
    and x < rect.x + rect.w and y < rect.y + rect.h
end

function Rect.intersect(a, b)
  local x1, y1 = math.max(a.x, b.x), math.max(a.y, b.y)
  local x2 = math.min(a.x + a.w, b.x + b.w)
  local y2 = math.min(a.y + a.h, b.y + b.h)
  return Rect.new(x1, y1, math.max(0, x2 - x1), math.max(0, y2 - y1))
end

function Rect.clamp(rect, bounds)
  local w, h = math.min(rect.w, bounds.w), math.min(rect.h, bounds.h)
  local x = math.max(bounds.x, math.min(rect.x, bounds.x + bounds.w - w))
  local y = math.max(bounds.y, math.min(rect.y, bounds.y + bounds.h - h))
  return Rect.new(x, y, w, h)
end

function Rect.round(rect)
  return Rect.new(math.floor(rect.x + 0.5), math.floor(rect.y + 0.5),
    math.floor(rect.w + 0.5), math.floor(rect.h + 0.5))
end

return Rect

