local requireCore = ...
local Rect = requireCore("geometry.rect")
local Presets = requireCore("design.presets")
local Envelope = requireCore("layout.envelope")

local Layout = {}

local function textWidth(font, value)
  local text = tostring(value or "")
  if font and type(font.getWidth) == "function" then
    local ok, width = pcall(font.getWidth, font, text)
    if ok and type(width) == "number" then return width end
  end
  return #text * math.max(1, (font:getHeight() or 15) * 0.6)
end

local function adaptiveWidth(shell, state, result, rows, font, pad, frame)
  local preset = Presets[state:preset()]
  if not preset or preset.widthMode ~= "content" then return result end
  local scale = result.scale or 1
  local gap = math.max(8, math.floor(10 * scale))
  local required = textWidth(font, shell.content.title(state.view))
  for _, row in ipairs(rows or {}) do
    local right = tostring(row.right or "")
    local rightWidth = right ~= "" and textWidth(font, right) or 0
    local pinReserve = state.view == "mod_menus" and row.pinnable
      and math.max(44, math.floor(72 * scale)) or 0
    required = math.max(required,
      textWidth(font, row.label) + rightWidth + pinReserve + gap * 3,
      rightWidth / 0.42 + pinReserve + gap * 3)
  end
  local chrome = 2 * (frame + pad)
  local logical = math.ceil((required + chrome) / scale)
  logical = math.max(preset.minW or 1, math.min(preset.w, logical))
  local context = table.concat({ state.view, result.safeArea.w,
    result.safeArea.h, result.scale, shell.settingsRevision or 0,
    font:getHeight(), shell:setting(state, "density") or "auto" }, ":")
  if state.layoutWidth == nil or state.layoutWidthContext ~= context then
    state.layoutWidth, state.layoutWidthContext = logical, context
  end
  return Envelope.withLogicalWidth(result, state.layoutWidth)
end

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
  result = adaptiveWidth(shell, state, result, rows, font, pad, frame)
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
