local requireCore = ...
local Color = requireCore("design.color")
local Frame = requireCore("design.frame")
local MenuRender = requireCore("presentation.menu_render")

local DialogueRender = {}

local function removeLastCodepoint(text)
  local index = #text
  while index > 1 do
    local byte = text:byte(index)
    if not byte or byte < 128 or byte >= 192 then break end
    index = index - 1
  end
  return text:sub(1, index - 1)
end

local function fit(font, value, width)
  local text = tostring(value or "")
  if font:getWidth(text) <= width then return text end
  local suffix = "..."
  while #text > 0 and font:getWidth(text .. suffix) > width do
    text = removeLastCodepoint(text)
  end
  return text .. suffix
end

local function printAt(G, font, color, value, x, y)
  G.setFont(font)
  Color.set(G, color)
  G.print(tostring(value or ""), math.floor(x), math.floor(y))
end

local function lineAt(G, color, x1, y1, x2, y2)
  Color.set(G, color, 0.55)
  G.setLineWidth(1)
  G.line(x1, y1, x2, y2)
end

local function drawDialogue(G, model, layout, font, theme)
  local lines = layout.displayLines or model.lines or {}
  local total = #lines * font:getHeight()
    + math.max(0, #lines - 1) * layout.lineGap
  local y = layout.body.y + math.max(0, math.floor((layout.body.h - total) / 2))
  for _, line in ipairs(lines) do
    local run = MenuRender.resolveTextRun(layout, font, line, layout.body.w)
    printAt(G, run.font, theme.colors.ink, run.text, layout.body.x,
      y + math.floor((font:getHeight() - run.height) / 2))
    y = y + font:getHeight() + layout.lineGap
  end
end

local function drawChoice(G, model, layout, font, theme)
  for _, measured in ipairs(layout.optionRows or {}) do
    local option, rect = measured.option, measured.rect
    if measured.index == model.selected then
      Color.set(G, theme.colors.selection)
      G.rectangle("fill", rect.x, rect.y + 1, rect.w, rect.h - 2)
      Color.set(G, theme.colors.focus)
      G.rectangle("fill", rect.x, rect.y + 1,
        math.max(2, math.floor(3 * layout.scale)), rect.h - 2)
    end
    local text = option.label or option.value or (measured.index == 1 and "YES" or "NO")
    local run = MenuRender.resolveTextRun(layout, font, text, rect.w - 20)
    printAt(G, run.font,
      option.disabled and theme.colors.muted or theme.colors.ink,
      run.text, rect.x + 10,
      rect.y + math.floor((rect.h - run.height) / 2))
  end
end

function DialogueRender.draw(G, model, layout, font, theme)
  Frame.draw(G, layout.outer, theme, layout.scale)
  if model.kind == "choice" then
    drawChoice(G, model, layout, font, theme)
  else
    drawDialogue(G, model, layout, font, theme)
  end
  lineAt(G, theme.colors.muted, layout.footer.x, layout.footer.y,
    layout.footer.x + layout.footer.w, layout.footer.y)
  local controls = model.controls or (model.kind == "choice"
    and "A CHOOSE   B NO" or "A/B CONTINUE")
  local controlsRun = MenuRender.resolveTextRun(layout, font, controls,
    layout.footer.w)
  printAt(G, controlsRun.font, theme.colors.muted, controlsRun.text,
    layout.footer.x,
    layout.footer.y + math.floor((layout.footer.h - controlsRun.height) / 2))
  if model.more or layout.textOverflow then
    local marker = "..."
    printAt(G, font, theme.colors.focus, marker,
      layout.footer.x + layout.footer.w - font:getWidth(marker),
      layout.footer.y + math.floor((layout.footer.h - font:getHeight()) / 2))
  end
  G.setColor(1, 1, 1, 1)
  return true
end

return DialogueRender
