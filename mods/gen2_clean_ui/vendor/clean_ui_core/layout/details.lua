local requireCore = ...
local Rect = requireCore("geometry.rect")

local Details = {}

local function inset(rect, amount)
  return Rect.inset(rect, { x=amount, y=amount })
end

function Details.measure(region, model, metrics)
  model, metrics = model or {}, metrics or {}
  local gap = metrics.gap or 8
  local lineHeight = metrics.lineHeight or 18
  local inner = inset(region, gap)
  local footerHeight = 0
  for _, section in ipairs(model.footer_lists or {}) do
    footerHeight = footerHeight + lineHeight
    footerHeight = footerHeight + #(section.items or {}) * lineHeight + gap
  end
  footerHeight = math.min(inner.h, footerHeight)
  local footer = Rect.new(inner.x, inner.y + inner.h - footerHeight,
    inner.w, footerHeight)
  local topHeight = math.max(0, inner.h - footerHeight
    - (footerHeight > 0 and gap or 0))
  local top = Rect.new(inner.x, inner.y, inner.w, topHeight)
  local fieldCount = #(model.custom_fields and model.custom_fields.data or {})
  local columns = math.max(1, math.floor(model.custom_fields
    and model.custom_fields.columns or 1))
  local minimumCell = metrics.minimumCellWidth or math.max(80, lineHeight * 5)
  columns = math.min(columns, math.max(1,
    math.floor((top.w + gap) / (minimumCell + gap))))
  local rows = math.ceil(fieldCount / columns)
  local titleLines = model.title and model.title ~= ""
    and (metrics.titleLines or 1) or 0
  local standardFields = model.fields or {}
  local textReserve = titleLines * lineHeight
    + #standardFields * lineHeight + rows * lineHeight
    + ((titleLines + #standardFields + rows) > 0 and gap or 0)
  local spriteSize = math.max(0, math.min(top.w * 0.45,
    topHeight - textReserve))
  local sprite = Rect.new(top.x, top.y + textReserve,
    spriteSize, spriteSize)
  local fieldX = spriteSize > 0 and sprite.x + sprite.w + gap or top.x
  local fieldWidth = math.max(0, top.x + top.w - fieldX)
  local cells = {}
  local cellWidth = columns > 0
    and math.max(0, (fieldWidth - gap * (columns - 1)) / columns) or 0
  local fieldY = top.y + titleLines * lineHeight
    + #standardFields * lineHeight + gap
  for index, field in ipairs(model.custom_fields
      and model.custom_fields.data or {}) do
    local column = (index - 1) % columns
    local row = math.floor((index - 1) / columns)
    cells[index] = {
      field = field,
      rect = Rect.new(fieldX + column * (cellWidth + gap),
        fieldY + row * lineHeight, cellWidth, lineHeight),
    }
  end
  local footerSections, y = {}, footer.y
  for _, section in ipairs(model.footer_lists or {}) do
    local measured = { section=section,
      title=Rect.new(footer.x, y, footer.w, lineHeight), items={} }
    y = y + lineHeight
    for _, item in ipairs(section.items or {}) do
      measured.items[#measured.items + 1] = {
        item=item, rect=Rect.new(footer.x, y, footer.w, lineHeight),
      }
      y = y + lineHeight
    end
    y = y + gap
    footerSections[#footerSections + 1] = measured
  end
  return {
    inner = inner,
    top = top,
    footer = footer,
    sprite = sprite,
    columns = columns,
    fieldRows = rows,
    cells = cells,
    footerSections = footerSections,
    fieldX = fieldX,
    fieldWidth = fieldWidth,
    barLineHeight = lineHeight,
    overflow = y > footer.y + footer.h + 0.01,
  }
end

return Details
