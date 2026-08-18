local requireCore = ...
local Color = requireCore("design.color")
local Frame = requireCore("design.frame")
local MenuRender = requireCore("presentation.menu_render")

local DocumentRender = {}

local function printText(G, layout, font, theme, text, x, y, width, style,
    align)
  return MenuRender.printStyledFitted(G, layout, font, theme, text, x, y,
    width, style or "body", align and { align = align } or nil)
end

local function componentHeight(component, font, pad, regionHeight)
  local kind = component.type
  local line = font:getHeight() + math.floor(pad * 0.35)
  if kind == "image" then
    return math.max(line, math.min(regionHeight, math.floor(regionHeight * 0.58)))
  elseif kind == "text" then
    return math.max(line, #component.lines * line + pad)
  elseif kind == "metadata" or kind == "list" then
    local count = component.visible or #component.items
    return math.max(line, count * line + pad)
  elseif kind == "scrollbar" then
    return math.max(line, regionHeight)
  end
  return line + pad
end

local function drawScrollbar(G, component, rect, layout, theme, pad)
  local railX = component.side == "right"
    and rect.x + rect.w - pad or rect.x + math.floor(rect.w * 0.5)
  local top = rect.y + pad
  local bottom = rect.y + rect.h - pad
  local railWidth = math.max(2, math.floor(layout.scale * 2))
  local arrow = math.max(4, math.floor(6 * layout.scale))
  Color.set(G, theme.colors.muted)
  G.rectangle("fill", railX - math.floor(railWidth / 2), top + arrow,
    railWidth, math.max(1, bottom - top - arrow * 2))
  Color.set(G, theme.colors.ink)
  G.rectangle("fill", railX - arrow, top, arrow * 2, arrow)
  G.rectangle("fill", railX - arrow, bottom - arrow, arrow * 2, arrow)
  local total = math.max(1, component.total or 1)
  local visible = math.max(1, math.min(total, component.visible or 1))
  local track = math.max(1, bottom - top - arrow * 2)
  local thumbHeight = math.max(8, math.floor(track * visible / total))
  local range = math.max(0, track - thumbHeight)
  local index = math.max(0, math.min(total - visible, component.index or 0))
  local thumbY = top + arrow + (total > visible
    and range * index / (total - visible) or 0)
  Color.set(G, theme.colors.gen2Accent or theme.colors.focus)
  G.rectangle("fill", railX - math.floor(5 * layout.scale),
    thumbY, math.max(2, math.floor(10 * layout.scale)), thumbHeight)
end

local function drawComponent(G, component, rect, layout, font, theme)
  local pad = math.max(8, math.floor(10 * layout.scale))
  local x, y, width = rect.x + pad, rect.y + pad, math.max(1, rect.w - pad * 2)
  local kind = component.type
  if kind == "divider" then
    Color.set(G, theme.colors.muted)
    G.rectangle("fill", x, y, width, math.max(1, math.floor(layout.scale)))
    return
  elseif kind == "heading" then
    printText(G, layout, font, theme, component.text, x, y, width, "heading",
      component.align)
  elseif kind == "label" then
    printText(G, layout, font, theme, component.text, x, y, width, "label",
      component.align)
  elseif kind == "tabs" then
    local values = component.values or {}
    local tabWidth = width / math.max(1, #values)
    for index, value in ipairs(values) do
      local tabX = x + (index - 1) * tabWidth
      local style = index == component.active and "accent" or "label"
      printText(G, layout, font, theme, value, tabX, y, tabWidth, style)
      if index == component.active then
        Color.set(G, theme.colors.gen2Accent or theme.colors.focus)
        G.rectangle("fill", tabX, y + font:getHeight() + 2,
          math.max(1, tabWidth - pad), math.max(1, math.floor(layout.scale)))
      end
    end
  elseif kind == "text" then
    for index, line in ipairs(component.lines or {}) do
      printText(G, layout, font, theme, line, x, y
        + (index - 1) * (font:getHeight() + pad * 0.35), width, "body")
    end
  elseif kind == "badges" then
    MenuRender.drawTypeBadges(G, component.values, rect, font, theme,
      layout.scale, component.align)
  elseif kind == "metadata" or kind == "list" then
    local first = kind == "list" and (component.scroll or 0) + 1 or 1
    local last = kind == "list" and math.min(#(component.items or {}),
      first + (component.visible or #component.items) - 1)
      or #(component.items or {})
    for index = first, last do
      local item = component.items[index]
      local rowIndex = index - first + 1
      local rowY = y + (rowIndex - 1) * (font:getHeight() + pad * 0.35)
      if item.selected then
        local selectionInset = math.max(2, math.floor(layout.scale * 2))
        Color.set(G, theme.colors.selection)
        G.rectangle("fill", rect.x + selectionInset,
          rowY - math.floor(pad * 0.35), rect.w - selectionInset * 2,
          font:getHeight() + math.floor(pad * 0.7))
      end
      printText(G, layout, font, theme, item.label, x, rowY, width * 0.55,
        item.selected and "strong" or "label")
      local value = item.value == nil and "" or tostring(item.value)
      printText(G, layout, font, theme, value, x + width * 0.55, rowY,
        width * 0.45, (item.selected or item.tone == "accent")
          and "accent" or "value")
    end
    if kind == "list" and type(component.scrollbar) == "table" then
      drawScrollbar(G, component.scrollbar, rect, layout, theme, pad)
    end
  elseif kind == "scrollbar" then
    drawScrollbar(G, component, rect, layout, theme, pad)
  elseif kind == "image" then
    local ok, code, message = MenuRender.drawSprite(G, {
      path = component.asset or component.path,
    }, rect)
    if ok ~= true then return nil, code, message end
  end
  return true
end

local function drawHeaderSlot(G, component, layout, font, theme, side)
  if type(component) ~= "table" then return true end
  local text = tostring(component.text or "")
  local style = component.style
    or (component.type == "heading" and "heading" or "label")
  local pad = math.max(8, math.floor(10 * layout.scale))
  local width = math.max(1, math.min(layout.header.w - pad * 2,
    font:getWidth(text)))
  local x = side == "right"
    and layout.header.x + layout.header.w - pad - width
    or layout.header.x + pad
  local y = layout.header.y
    + math.floor((layout.header.h - font:getHeight()) / 2)
  printText(G, layout, font, theme, text, x, y, width, style)
  return true
end

local function drawRegionBackground(G, source, region, layout, theme)
  if source.frame then
    local panelTheme = {
      colors = {
        ink = theme.colors.muted,
        paper = theme.colors.raised,
      },
    }
    Frame.draw(G, region.rect, panelTheme, layout.scale)
  else
    Color.set(G, theme.colors.raised)
    G.rectangle("fill", region.rect.x, region.rect.y,
      region.rect.w, region.rect.h)
  end
end

function DocumentRender.draw(G, model, layout, font, theme)
  if model.opaque then
    Color.set(G, theme.colors.raised)
    G.rectangle("fill", 0, 0, layout.viewport.w, layout.viewport.h)
  end
  Frame.draw(G, layout.outer, theme, layout.scale)
  local titleY = layout.header.y
    + math.floor((layout.header.h - font:getHeight()) / 2)
  printText(G, layout, font, theme, model.title or "DOCUMENT",
    layout.header.x, titleY, layout.header.w, "heading")
  local header = model.document and model.document.header
  if type(header) == "table" then
    for _, side in ipairs({ "left", "right" }) do
      local component = header[side]
      if component then
        local ok, code, message = drawHeaderSlot(G, component, layout,
          font, theme, side)
        if ok ~= true then return nil, code, message end
      end
    end
  end
  Color.set(G, theme.colors.muted)
  G.rectangle("fill", layout.header.x,
    layout.header.y + layout.header.h - 1, layout.header.w, 1)
  for _, region in ipairs(layout.document or {}) do
    drawRegionBackground(G, region.source, region, layout, theme)
    local pad = math.max(8, math.floor(10 * layout.scale))
    local clipped = type(G.setScissor) == "function"
    if clipped then
      G.setScissor(region.rect.x, region.rect.y, region.rect.w, region.rect.h)
    end
    local cursor = region.rect.y
    for _, component in ipairs(region.source.components or {}) do
      if component.type == "scrollbar" and component.anchor then
        local ok, code, message = drawComponent(G, component, region.rect,
          layout, font, theme)
        if ok ~= true then return nil, code, message end
      else
        local remaining = math.max(1, region.rect.y + region.rect.h - cursor)
        local height = math.min(remaining,
          componentHeight(component, font, pad, region.rect.h))
        local componentRect = {
          x = region.rect.x, y = cursor, w = region.rect.w, h = height,
        }
        local ok, code, message = drawComponent(G, component, componentRect,
          layout, font, theme)
        if ok ~= true then return nil, code, message end
        cursor = cursor + height
        if cursor >= region.rect.y + region.rect.h then break end
      end
    end
    if clipped then G.setScissor() end
  end
  Color.set(G, theme.colors.muted)
  G.rectangle("fill", layout.footer.x, layout.footer.y - 1,
    layout.footer.w, 1)
  local controls = model.controls or (model.document and model.document.controls)
  if type(controls) == "string" then
    printText(G, layout, font, theme, controls, layout.footer.x,
      layout.footer.y + math.floor((layout.footer.h - font:getHeight()) / 2),
      layout.footer.w, "label")
  end
  return true
end

return DocumentRender
