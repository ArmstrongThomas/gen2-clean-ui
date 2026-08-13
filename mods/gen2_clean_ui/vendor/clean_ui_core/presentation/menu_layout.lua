local requireCore = ...
local Rect = requireCore("geometry.rect")
local List = requireCore("layout.list")
local Details = requireCore("layout.details")

local MenuLayout = {}

local function inset(rect, amount)
  return Rect.inset(rect, { x = amount })
end

function MenuLayout.measure(base, model, font, density)
  local scale = base.scale or 1
  local compact = density == "compact"
  local pad = math.max(8, math.floor((compact and 10 or 14) * scale))
  local frame = math.max(2, math.floor(2 * scale + 0.5))
  local inner = inset(base.outer, frame + pad)
  local titleHeight = math.max(font:getHeight() + pad,
    math.floor((compact and 40 or 50) * scale))
  local footerLines = model.description and 2 or 1
  local footerHeight = math.max(font:getHeight() * footerLines + pad,
    math.floor((compact and 38 or 48) * scale))
  local header = Rect.new(inner.x, inner.y, inner.w, titleHeight)
  local footer = Rect.new(inner.x, inner.y + inner.h - footerHeight,
    inner.w, footerHeight)
  local body = Rect.new(inner.x, header.y + header.h, inner.w,
    math.max(0, footer.y - header.y - header.h))
  local richDetails = type(model.details) == "table"
    and (model.details.fields or model.details.custom_fields
      or model.details.footer_lists or model.details.sprite)
  local hasDetails = richDetails or (type(model.details) == "table"
    and #model.details > 0)
  local detailWidth = hasDetails
    and math.min(math.floor(body.w * 0.42), math.floor(250 * scale)) or 0
  local gap = detailWidth > 0 and pad or 0
  local listRegion = Rect.new(body.x, body.y,
    math.max(0, body.w - detailWidth - gap), body.h)
  local detailRegion = detailWidth > 0 and Rect.new(
    body.x + body.w - detailWidth, body.y, detailWidth, body.h) or nil
  local rowHeight = math.max(font:getHeight() + pad,
    math.floor((compact and 40 or 48) * scale))
  local rows = model.rows or {}
  local list = List.measure(listRegion, #rows, rowHeight,
    model.selected, model.scroll)
  local measured = {}
  local hitRegions = {}
  for _, row in ipairs(list.rows) do
    local source = rows[row.index]
    measured[#measured + 1] = {
      index = row.index, row = source, rect = row.rect,
    }
    if source and source.disabled ~= true then
      hitRegions[#hitRegions + 1] = {
        id = tostring(source.id or row.index), index = row.index,
        sourceIndex = source.sourceIndex or row.index,
        rect = Rect.copy(row.rect), role = "menu_row",
      }
    end
  end
  local modal
  if model.modal then
    local mw = math.min(inner.w, math.max(math.floor(280 * scale),
      math.floor(inner.w * 0.62)))
    local optionCount = #(model.modal.options or {})
    local mh = math.min(inner.h, math.max(math.floor(190 * scale),
      font:getHeight() * 3 + pad * 4 + optionCount * rowHeight))
    local rect = Rect.new(inner.x + (inner.w - mw) / 2,
      inner.y + (inner.h - mh) / 2, mw, mh)
    local modalInner = inset(rect, frame + pad)
    local top = math.max(font:getHeight() + pad,
      math.floor(48 * scale))
    local optionsRegion = Rect.new(modalInner.x, modalInner.y + top,
      modalInner.w, math.max(0, modalInner.h - top))
    local optionList = List.measure(optionsRegion, optionCount, rowHeight,
      model.modal.selected, model.modal.scroll)
    local optionRows = {}
    for _, optionRow in ipairs(optionList.rows) do
      local option = model.modal.options[optionRow.index]
      optionRows[#optionRows + 1] = {
        index=optionRow.index, option=option, rect=optionRow.rect,
      }
      if option and not option.disabled then
        hitRegions[#hitRegions + 1] = {
          id=tostring(option.id or optionRow.index), index=optionRow.index,
          rect=Rect.copy(optionRow.rect), role="modal_option",
        }
      end
    end
    modal = { rect=rect, inner=modalInner, options=optionRows,
      selected=model.modal.selected, titleHeight=top,
      scroll=optionList.offset, visible=optionList.visible }
  end
  base.inner, base.header, base.body, base.footer = inner, header, body, footer
  base.listRegion, base.detailRegion = listRegion, detailRegion
  if richDetails and detailRegion then
    base.details = Details.measure(detailRegion, model.details, {
      gap=math.max(6, math.floor(8 * scale)),
      lineHeight=font:getHeight() + math.max(3, math.floor(4 * scale)),
      minimumCellWidth=math.max(72, math.floor(92 * scale)),
    })
  end
  base.rows, base.rowHeight = measured, rowHeight
  base.scroll, base.visibleRows = list.offset, list.visible
  base.hitRegions, base.modal = hitRegions, modal
  return base
end

return MenuLayout
