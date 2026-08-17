local requireCore = ...
local Color = requireCore("design.color")
local Frame = requireCore("design.frame")
local MenuRender = requireCore("presentation.menu_render")

local DocumentRender = {}

local function printText(G, layout, font, theme, text, x, y, width, style)
  return MenuRender.printStyledFitted(G, layout, font, theme, text, x, y,
    width, style or "body")
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
      printText(G, layout, font, theme, item.label, x, rowY, width * 0.55,
        "label")
      local value = item.value == nil and "" or tostring(item.value)
      printText(G, layout, font, theme, value, x + width * 0.55, rowY,
        width * 0.45, item.tone == "accent" and "accent" or "value")
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
    for _, component in ipairs(region.source.components or {}) do
      local ok, code, message = drawComponent(G, component, region.rect,
        layout, font, theme)
      if ok ~= true then return nil, code, message end
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
