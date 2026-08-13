local requireCore = ...
local Rect = requireCore("geometry.rect")

local List = {}

function List.measure(region, itemCount, rowHeight, selection, scrollOffset)
  rowHeight = math.max(1, math.floor(rowHeight))
  local visible = math.max(1, math.floor(region.h / rowHeight))
  local maxOffset = math.max(0, itemCount - visible)
  local offset = math.max(0, math.min(math.floor(scrollOffset or 0), maxOffset))
  if selection then
    if selection <= offset then offset = math.max(0, selection - 1) end
    if selection > offset + visible then offset = math.min(maxOffset, selection - visible) end
  end
  local rows = {}
  for slot = 1, visible do
    local index = offset + slot
    if index > itemCount then break end
    rows[#rows + 1] = {
      index = index,
      rect = Rect.new(region.x, region.y + (slot - 1) * rowHeight,
        region.w, math.min(rowHeight, region.y + region.h
          - (region.y + (slot - 1) * rowHeight))),
    }
  end
  return { rows = rows, offset = offset, maxOffset = maxOffset, visible = visible }
end

return List

