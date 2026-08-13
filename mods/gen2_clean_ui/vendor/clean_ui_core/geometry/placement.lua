local requireCore = ...
local Rect = requireCore("geometry.rect")

local Placement = {}

function Placement.vertical(trigger, popupWidth, desiredHeight, safeArea, gap)
  gap = gap or 4
  local below = safeArea.y + safeArea.h - (trigger.y + trigger.h) - gap
  local above = trigger.y - safeArea.y - gap
  local side = below >= desiredHeight and "below"
    or (above >= desiredHeight and "above")
    or (below >= above and "below" or "above")
  local available = side == "below" and below or above
  local height = math.max(0, math.min(desiredHeight, available))
  local y = side == "below" and trigger.y + trigger.h + gap
    or trigger.y - gap - height
  local width = math.min(math.max(0, popupWidth), safeArea.w)
  local rect = Rect.clamp(Rect.new(trigger.x, y, width, height), safeArea)
  return { side = side, rect = rect, scroll = height < desiredHeight }
end

return Placement
