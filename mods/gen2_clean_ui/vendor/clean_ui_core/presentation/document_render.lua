local requireCore = ...
local Color = requireCore("design.color")
local Frame = requireCore("design.frame")
local MenuRender = requireCore("presentation.menu_render")

local DocumentRender = {}

local function printText(G, layout, font, theme, text, x, y, width, style)
  return MenuRender.printStyledFitted(G, layout, font, theme, text, x, y,
    width, style or "body")
end

local function componentHeight(component, font, pad, regionHeight)
  local kind = component.type
  local line = font:getHeight() + math.floor(pad * 0.35)
  if kind == "image" then
    return math.max(line, math.min(regionHeight, math.floor(regionHeight * 0.58)))
  elseif kind == "text" then
    return math.max(line, #component.lines * line + pad)
  elseif kind == "metadata" or kind == "list" then
    return math.max(line, #component.items * line + pad)
  end
  return line + pad
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
    printText(G, layout, font, theme, component.text, x, y, width, "heading")
  elseif kind == "label" then
    printText(G, layout, font, theme, component.text, x, y, width, "label")
  elseif kind == "tabs" then
    local values = component.values or {}
    local tabWidth = width / math.max(1, #values)
    for index, value in ipairs(values) do
      local tabX = x + (index - 1) * tabWidth
      local style = index == component.active and "accent" or "label"
      printText(G, layout, font, theme, value, tabX, y, tabWidth, style)
      if index == component.active then
        Color.set(G, theme.colors.accent)
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
      layout.scale)
  elseif kind == "metadata" or kind == "list" then
    for index, item in ipairs(component.items or {}) do
      local rowY = y + (index - 1) * (font:getHeight() + pad * 0.35)
      if item.selected then
        Color.set(G, theme.colors.selection)
        G.rectangle("fill", rect.x, rowY - math.floor(pad * 0.35),
          rect.w, font:getHeight() + math.floor(pad * 0.7))
      end
      printText(G, layout, font, theme, item.label, x, rowY, width * 0.55,
        item.selected and "strong" or "label")
      local value = item.value == nil and "" or tostring(item.value)
      printText(G, layout, font, theme, value, x + width * 0.55, rowY,
        width * 0.45, (item.selected or item.tone == "accent")
          and "accent" or "value")
    end
  elseif kind == "image" then
    local ok, code, message = MenuRender.drawSprite(G, {
      path = component.asset or component.path,
    }, rect)
    if ok ~= true then return nil, code, message end
  end
  return true
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
  Color.set(G, theme.colors.muted)
  G.rectangle("fill", layout.header.x,
    layout.header.y + layout.header.h - 1, layout.header.w, 1)
  for _, region in ipairs(layout.document or {}) do
    Color.set(G, theme.colors.raised)
    G.rectangle("fill", region.rect.x, region.rect.y,
      region.rect.w, region.rect.h)
    local pad = math.max(8, math.floor(10 * layout.scale))
    local cursor = region.rect.y
    for _, component in ipairs(region.source.components or {}) do
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
  local controls = model.controls or (model.document and model.document.controls)
  if type(controls) == "string" then
    printText(G, layout, font, theme, controls, layout.footer.x,
      layout.footer.y + math.floor((layout.footer.h - font:getHeight()) / 2),
      layout.footer.w, "label")
  end
  return true
end

return DocumentRender
