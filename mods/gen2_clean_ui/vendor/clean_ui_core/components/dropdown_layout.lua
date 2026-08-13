local requireCore = ...
local Rect = requireCore("geometry.rect")
local Placement = requireCore("geometry.placement")

local DropdownLayout = {}

function DropdownLayout.measure(descriptor, trigger, safeArea, metrics)
  metrics = metrics or {}
  local rowHeight = metrics.rowHeight or 36
  local descriptionHeight = metrics.descriptionHeight
    or math.max(14, math.floor(rowHeight * 0.55))
  local headingHeight = metrics.headingHeight or 24
  local total = metrics.padding or 8
  local rows = {}
  for _, option in ipairs(descriptor.options or {}) do
    local height = option.heading and headingHeight or rowHeight
    if not option.heading and type(option.description) == "string"
        and option.description ~= "" then
      height = height + descriptionHeight
    end
    rows[#rows + 1] = { option = option, height = height }
    total = total + height
  end
  total = total + (metrics.padding or 8)
  local width = math.min(safeArea.w,
    math.max(trigger.w, metrics.minWidth or 220))
  local placement = Placement.vertical(trigger, width, total, safeArea,
    metrics.gap or 4)
  local y = placement.rect.y + (metrics.padding or 8)
  local measuredRows = {}
  for _, row in ipairs(rows) do
    measuredRows[#measuredRows + 1] = {
      option = row.option,
      rect = Rect.new(placement.rect.x, y, placement.rect.w, row.height),
    }
    y = y + row.height
  end
  placement.rows = measuredRows
  placement.contentHeight = total
  placement.rowHeight = rowHeight
  placement.descriptionHeight = descriptionHeight
  placement.iconWidth = metrics.iconWidth
    or math.max(20, math.floor(rowHeight * 0.75))
  placement.maxScroll = math.max(0, total - placement.rect.h)
  placement.visibleRows = {}
  for _, row in ipairs(measuredRows) do
    local visible = Rect.intersect(row.rect, placement.rect)
    if visible.w > 0 and visible.h > 0 then
      placement.visibleRows[#placement.visibleRows + 1] = {
        option = row.option, rect = visible,
      }
    end
  end
  return placement
end

return DropdownLayout
