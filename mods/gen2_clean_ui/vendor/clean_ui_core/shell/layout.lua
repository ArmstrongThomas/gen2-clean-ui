local requireCore = ...
local Rect = requireCore("geometry.rect")

local Layout = {}

function Layout.measure(shell, state, viewport, safeArea, rows, font)
  local solved = shell.core.pipeline.solver.solve({
    preset = state:preset(), viewport = viewport, safeArea = safeArea or viewport,
    uiSize = shell:setting(state, "ui_size") or "auto",
    textSize = shell:setting(state, "text_size") or "auto",
    fontFamily = shell:setting(state, "font") or "plain_pixel",
    density = shell:setting(state, "density") or "auto",
    settingsRevision = shell.settingsRevision,
  })
  if not solved.ok then return nil, solved.error end
  local result = solved.value
  local scale = result.scale
  local compact = shell:setting(state, "density") == "compact"
  local pad = math.max(8, math.floor((compact and 10 or 14) * scale))
  local titleH = math.max(font:getHeight() + pad,
    math.floor((compact and 42 or 50) * scale))
  local footerH = math.max(font:getHeight() + pad,
    math.floor((compact and 34 or 42) * scale))
  local frame = math.max(2, math.floor(2 * scale + 0.5))
  local inner = Rect.inset(result.outer, {
    left = frame + pad, right = frame + pad,
    top = frame + pad, bottom = frame + pad,
  })
  local header = Rect.new(inner.x, inner.y, inner.w, titleH)
  local footer = Rect.new(inner.x, inner.y + inner.h - footerH,
    inner.w, footerH)
  local body = Rect.new(inner.x, header.y + header.h, inner.w,
    math.max(0, footer.y - (header.y + header.h)))
  local rowHeight = math.max(font:getHeight() + pad,
    math.floor((compact and 40 or 48) * scale))
  local visible = math.max(1, math.floor(body.h / rowHeight))
  state:ensureVisible(visible, #rows)
  local measuredRows = {}
  for slot = 1, visible do
    local index = state.scroll + slot
    if not rows[index] then break end
    measuredRows[#measuredRows + 1] = {
      index = index, row = rows[index],
      rect = Rect.new(body.x, body.y + (slot - 1) * rowHeight,
        body.w, rowHeight),
    }
  end
  result.inner, result.header, result.body, result.footer =
    inner, header, body, footer
  result.rows, result.rowHeight, result.visibleRows =
    measuredRows, rowHeight, visible
  result.pinWidth = math.max(44, math.floor(72 * scale))
  result.fontHeight = font:getHeight()
  return result
end

function Layout.measureModal(parent, descriptor, font)
  local scale = parent.scale or 1
  local pad = math.max(8, math.floor(12 * scale))
  local rowHeight = math.max(font:getHeight() + pad,
    math.floor(42 * scale))
  local width = math.min(parent.safeArea.w - pad * 2,
    math.max(240, math.floor(400 * scale)))
  local desiredHeight = math.floor(200 * scale)
    + math.max(0, #(descriptor.options or {}) - 2) * rowHeight
  local height = math.min(parent.safeArea.h - pad * 2,
    math.max(math.floor(200 * scale), desiredHeight))
  local rect = Rect.new(parent.safeArea.x + (parent.safeArea.w - width) / 2,
    parent.safeArea.y + (parent.safeArea.h - height) / 2, width, height)
  local inner = Rect.inset(rect, { x = pad })
  local titleHeight = math.max(font:getHeight() + pad,
    math.floor(38 * scale))
  local messageHeight = descriptor.message and math.max(font:getHeight() + pad,
    math.floor(48 * scale)) or 0
  local body = Rect.new(inner.x, inner.y + titleHeight + messageHeight,
    inner.w, math.max(0, inner.h - titleHeight - messageHeight))
  local visible = math.max(1, math.floor(body.h / rowHeight))
  local rows = {}
  local scroll = 0
  for index, option in ipairs(descriptor.options or {}) do
    rows[#rows + 1] = { index=index, option=option,
      rect=Rect.new(body.x, body.y + (index - 1 - scroll) * rowHeight,
        body.w, rowHeight) }
  end
  return { rect=rect, inner=inner, body=body, rows=rows,
    rowHeight=rowHeight, visibleRows=visible,
    maxScroll=math.max(0, #(descriptor.options or {}) - visible),
    scale=scale, titleHeight=titleHeight, messageHeight=messageHeight }
end

return Layout
