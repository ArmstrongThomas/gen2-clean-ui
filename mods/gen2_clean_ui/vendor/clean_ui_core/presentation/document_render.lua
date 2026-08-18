local requireCore = ...
local Color = requireCore("design.color")
local Frame = requireCore("design.frame")
local MenuRender = requireCore("presentation.menu_render")

local DocumentRender = {}

local function printText(G, layout, font, theme, text, x, y, width, style,
    align, options)
  return MenuRender.printStyledFitted(G, layout, font, theme, text, x, y,
    width, style or "body", options
      or (align and { align = align } or nil))
end

local function componentHeight(component, font, pad, regionHeight)
  local kind = component.type
  local line = font:getHeight() + math.floor(pad * 0.35)
  if kind == "image" then
    return math.max(line, regionHeight)
  elseif kind == "text" then
    local lines = component.renderLines or component.lines
    local lineHeight = component.renderLineHeight or line
    return math.max(line, #(lines or {}) * lineHeight + pad)
  elseif kind == "metadata" or kind == "list" then
    local count = component.visible or #component.items
    if kind == "metadata" and component.columns then
      count = math.ceil(count / component.columns)
    end
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
    if component.orientation == "vertical" then
      G.rectangle("fill", x, rect.y + pad, math.max(1, math.floor(layout.scale)),
        math.max(1, rect.h - pad * 2))
    else
      G.rectangle("fill", x, y, width, math.max(1, math.floor(layout.scale)))
    end
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
    local textStyle = component.style or "body"
    local textX = x + math.floor((tonumber(component.marginLeft) or 0)
      * layout.scale)
    local rightInset = math.floor((tonumber(component.marginRight) or 0)
      * layout.scale)
    local textWidth = math.max(1, width - (textX - x) - rightInset)
    local lines = component.renderLines or component.lines or {}
    local lineHeight = component.renderLineHeight or
      (font:getHeight() + pad * 0.35)
    for index, line in ipairs(lines) do
      printText(G, layout, font, theme, line, textX, y
        + (index - 1) * lineHeight, textWidth,
        textStyle, nil, component.truncate == false
          and { truncate = false } or nil)
    end
  elseif kind == "badges" then
    local scissor = {}
    if type(G.getScissor) == "function" then
      scissor.x, scissor.y, scissor.w, scissor.h = G.getScissor()
    end
    if type(G.setScissor) == "function" then G.setScissor() end
    MenuRender.drawTypeBadges(G, component.values, rect, font, theme,
      layout.scale, component.align)
    if scissor.x and type(G.setScissor) == "function" then
      G.setScissor(scissor.x, scissor.y, scissor.w, scissor.h)
    end
  elseif kind == "metadata" or kind == "list" then
    local first = kind == "list" and (component.scroll or 0) + 1 or 1
    local last = kind == "list" and math.min(#(component.items or {}),
      first + (component.visible or #component.items) - 1)
      or #(component.items or {})
    local metadataRows = component.columns
      and math.ceil(#(component.items or {}) / component.columns) or 0
    for index = first, last do
      local item = component.items[index]
      local rowIndex, columnIndex
      if kind == "metadata" and component.columns then
        rowIndex = (index - 1) % metadataRows + 1
        columnIndex = math.floor((index - 1) / metadataRows)
      else
        rowIndex = index - first + 1
        columnIndex = 0
      end
      local columnWidth = width / math.max(1, component.columns or 1)
      local rowY = y + (rowIndex - 1) * (font:getHeight() + pad * 0.35)
      local rowX = x + columnIndex * columnWidth
      if item.selected then
        local selectionInset = math.max(2, math.floor(layout.scale * 2))
        Color.set(G, theme.colors.selection)
        G.rectangle("fill", rowX - selectionInset,
          rowY - math.floor(pad * 0.35), columnWidth - selectionInset * 2,
          font:getHeight() + math.floor(pad * 0.7))
      end
      local value = item.value == nil and "" or tostring(item.value)
      local labelWidth, valueX = columnWidth * 0.55, rowX + columnWidth * 0.55
      if component.leaders then
        labelWidth, valueX = columnWidth * 0.35, rowX + columnWidth * 0.6
        printText(G, layout, font, theme, ". . . .", rowX + columnWidth * 0.37,
          rowY, columnWidth * 0.2, "muted")
      end
      printText(G, layout, font, theme, item.label, rowX, rowY, labelWidth,
        item.selected and "strong" or "label")
      printText(G, layout, font, theme, value, valueX, rowY,
        columnWidth * (component.leaders and 0.4 or 0.45),
        (item.selected or item.tone == "accent")
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
  if component.type == "tabs" then
    local values = component.values or {}
    local pad = math.max(8, math.floor(10 * layout.scale))
    local groupX = layout.header.x + layout.header.w * 0.5
    local groupW = layout.header.x + layout.header.w - pad - groupX
    local tabWidth = groupW / math.max(1, #values)
    local y = layout.header.y
      + math.floor((layout.header.h - font:getHeight()) / 2)
    for index, value in ipairs(values) do
      local tabX = groupX + (index - 1) * tabWidth
      local style = index == component.active and "accent" or "label"
      printText(G, layout, font, theme, value, tabX, y, tabWidth, style)
      if index == component.active then
        Color.set(G, theme.colors.gen2Accent or theme.colors.focus)
        G.rectangle("fill", tabX, y + font:getHeight() + 2,
          math.max(1, tabWidth - pad), math.max(1, math.floor(layout.scale)))
      end
    end
    return true
  end
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
  if source.transparent then
    return
  elseif source.frame then
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
    for componentIndex, component in ipairs(region.source.components or {}) do
      if component.type == "scrollbar" and component.anchor then
        local ok, code, message = drawComponent(G, component, region.rect,
          layout, font, theme)
        if ok ~= true then return nil, code, message end
      else
        local remaining = math.max(1, region.rect.y + region.rect.h - cursor)
        if component.type == "text" and component.wrap then
          component.renderLines = {}
          for _, sourceLine in ipairs(component.lines or {}) do
            local wrapped = MenuRender.wrapStyledLines(layout, font, sourceLine,
              region.rect.w - pad * 2
                - math.floor((tonumber(component.marginLeft) or 0)
                  * layout.scale)
                - math.floor((tonumber(component.marginRight) or 0)
                  * layout.scale),
              component.style or "body")
            for _, wrappedLine in ipairs(wrapped) do
              component.renderLines[#component.renderLines + 1] = wrappedLine
            end
          end
        end
        if component.type == "text" then
          component.renderLineHeight = font:getHeight() + pad * 0.35
          local firstLine = component.renderLines
            and component.renderLines[1] or (component.lines or {})[1]
          if firstLine then
            local run = MenuRender.resolveTextRun(layout, font, firstLine,
              math.huge, MenuRender.textStyleOptions(component.style or "body"))
            component.renderLineHeight = math.max(component.renderLineHeight,
              run.height + pad * 0.35)
          end
        end
        local desiredHeight = componentHeight(component, font, pad,
          region.rect.h)
        if component.type == "image" then
          local reserved = 0
          for following = componentIndex + 1,
              #(region.source.components or {}) do
            reserved = reserved + componentHeight(
              region.source.components[following], font, pad, region.rect.h)
          end
          desiredHeight = math.min(desiredHeight,
            math.max(1, remaining - reserved))
        end
        local height = math.min(remaining, desiredHeight)
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
