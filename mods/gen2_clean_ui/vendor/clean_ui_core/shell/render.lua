local requireCore = ...
local Color = requireCore("design.color")
local Frame = requireCore("design.frame")

local Render = {}

local function textFit(font, value, maximum)
  local text = tostring(value or "")
  if font:getWidth(text) <= maximum then return text end
  local suffix = "..."
  while #text > 0 and font:getWidth(text .. suffix) > maximum do
    text = text:sub(1, -2)
  end
  return text .. suffix
end

local function printAt(G, font, color, text, x, y)
  G.setFont(font)
  Color.set(G, color)
  G.print(tostring(text or ""), math.floor(x), math.floor(y))
end

local function drawRows(shell, state, layout, rows, font, theme)
  local G = love.graphics
  for _, measured in ipairs(layout.rows) do
    local row, rect = measured.row, measured.rect
    local selected = measured.index == state.index
    local hovered = measured.index == state.hover
    if selected or hovered then
      Color.set(G, theme.colors.selection, hovered and 0.65 or 1)
      G.rectangle("fill", rect.x, rect.y + 1, rect.w, rect.h - 2)
    end
    if selected then
      Color.set(G, theme.colors.focus)
      G.rectangle("fill", rect.x, rect.y + 1,
        math.max(2, math.floor(3 * layout.scale)), rect.h - 2)
    end
    local baseline = rect.y + math.floor((rect.h - font:getHeight()) / 2)
    local right = tostring(row.right or "")
    local rightWidth = right ~= "" and font:getWidth(right) or 0
    local gap = math.max(8, math.floor(10 * layout.scale))
    local pinReserve = state.view == "mod_menus" and row.pinnable
      and layout.pinWidth or 0
    local labelMax = math.max(1, rect.w - rightWidth - pinReserve - gap * 3)
    printAt(G, font, theme.colors.ink, textFit(font, row.label, labelMax),
      rect.x + gap, baseline)
    if right ~= "" then
      local color = row.pinnable == false and theme.colors.muted
        or theme.colors.ink
      printAt(G, font, color, textFit(font, right, rect.w * 0.42),
        rect.x + rect.w - gap - math.min(rightWidth, rect.w * 0.42), baseline)
    end
    if state.view == "mod_menus" and row.pinnable then
      local marker = row.pinned and "[P]" or "[ ]"
      printAt(G, font, row.pinned and theme.colors.focus or theme.colors.muted,
        marker, rect.x + rect.w - layout.pinWidth,
        baseline)
    end
    Color.set(G, theme.colors.muted, 0.45)
    G.setLineWidth(1)
    G.line(rect.x + gap, rect.y + rect.h - 1,
      rect.x + rect.w - gap, rect.y + rect.h - 1)
  end
  if state.scroll > 0 then
    printAt(G, font, theme.colors.muted, "^", layout.body.x,
      layout.body.y - font:getHeight())
  end
  if state.scroll + layout.visibleRows < #rows then
    printAt(G, font, theme.colors.muted, "v",
      layout.body.x + layout.body.w - font:getWidth("v"),
      layout.body.y + layout.body.h - font:getHeight())
  end
end

local function drawDropdown(shell, font, theme)
  local dropdown = shell.core.dropdown
  if dropdown.state.phase == "closed" or not dropdown.layout then return end
  local G, layout = love.graphics, dropdown.layout
  Color.set(G, "#000000", 0.25)
  G.rectangle("fill", layout.rect.x + 4, layout.rect.y + 4,
    layout.rect.w, layout.rect.h)
  Frame.draw(G, layout.rect, theme, 1)
  G.setScissor(layout.rect.x, layout.rect.y, layout.rect.w, layout.rect.h)
  local scroll = dropdown.state.scrollOffset or 0
  for _, measured in ipairs(layout.rows) do
    local option = measured.option
    local y = measured.rect.y - scroll
    if y + measured.rect.h > layout.rect.y and y < layout.rect.y + layout.rect.h then
      if option.id == dropdown.state.activeOptionId then
        Color.set(G, theme.colors.selection)
        G.rectangle("fill", measured.rect.x + 2, y,
          measured.rect.w - 4, measured.rect.h)
      end
      local color = (option.disabled or option.heading)
        and theme.colors.muted or theme.colors.ink
      local prefix = option.value == dropdown.descriptor.value and "* " or "  "
      if option.heading then prefix = "" end
      local x = measured.rect.x + 10
      if not option.heading and option.icon ~= nil then
        local icon = tostring(option.icon)
        printAt(G, font, color, textFit(font, icon,
          math.max(1, layout.iconWidth - 10)), x,
          y + math.floor(((layout.rowHeight or measured.rect.h)
            - font:getHeight()) / 2))
        x = x + layout.iconWidth
      end
      local labelY = y + math.floor(((layout.rowHeight or measured.rect.h)
        - font:getHeight()) / 2)
      printAt(G, font, color, prefix .. tostring(option.label or ""), x,
        labelY)
      if type(option.description) == "string"
          and option.description ~= "" and not option.heading then
        printAt(G, font, theme.colors.muted,
          textFit(font, option.description,
            measured.rect.x + measured.rect.w - x - 10),
          x, y + (layout.rowHeight or measured.rect.h)
            + math.floor(((layout.descriptionHeight or 0)
              - font:getHeight()) / 2))
      end
    end
  end
  G.setScissor()
end

local function drawModal(state, font, theme)
  local modal = state.modal
  local layout = modal and modal.layout
  if not layout then return end
  local G = love.graphics
  local descriptor = modal.descriptor
  if descriptor.dim_background then
    Color.set(G, "#000000", descriptor.dim_opacity)
    G.rectangle("fill", 0, 0, G.getDimensions())
  end
  Frame.draw(G, layout.rect, theme, layout.scale)
  local title = descriptor.title or "CHOOSE"
  printAt(G, font, theme.colors.ink, textFit(font, title, layout.inner.w),
    layout.inner.x, layout.inner.y)
  if descriptor.message then
    Color.set(G, theme.colors.muted)
    G.setFont(font)
    G.printf(tostring(descriptor.message), layout.inner.x,
      layout.inner.y + layout.titleHeight, layout.inner.w, "left")
  end
  G.setScissor(layout.body.x, layout.body.y, layout.body.w, layout.body.h)
  local pixelScroll = (modal.scroll or 0) * layout.rowHeight
  for _, measured in ipairs(layout.rows) do
    local option = measured.option
    local y = measured.rect.y - pixelScroll
    if y + measured.rect.h > layout.body.y
        and y < layout.body.y + layout.body.h then
      if measured.index == modal.index then
        Color.set(G, theme.colors.selection)
        G.rectangle("fill", measured.rect.x, y,
          measured.rect.w, measured.rect.h)
        Color.set(G, theme.colors.focus)
        G.rectangle("fill", measured.rect.x, y,
          math.max(2, math.floor(3 * layout.scale)), measured.rect.h)
      end
      local color = option.disabled and theme.colors.muted or theme.colors.ink
      printAt(G, font, color, textFit(font, option.label,
        measured.rect.w - 20), measured.rect.x + 10,
        y + math.floor((measured.rect.h - font:getHeight()) / 2))
    end
  end
  G.setScissor()
end

function Render.draw(shell, state, layout, rows, font, theme)
  local G = love.graphics
  Color.set(G, theme.colors.raised)
  G.rectangle("fill", 0, 0, layout.viewport.w, layout.viewport.h)
  Frame.draw(G, layout.outer, theme, layout.scale)
  local titleY = layout.header.y
    + math.floor((layout.header.h - font:getHeight()) / 2)
  printAt(G, font, theme.colors.ink, shell.content.title(state.view),
    layout.header.x, titleY)
  Color.set(G, theme.colors.muted, 0.6)
  G.line(layout.header.x, layout.header.y + layout.header.h - 1,
    layout.header.x + layout.header.w, layout.header.y + layout.header.h - 1)
  drawRows(shell, state, layout, rows, font, theme)
  G.line(layout.footer.x, layout.footer.y,
    layout.footer.x + layout.footer.w, layout.footer.y)
  local controls
  if state.view == "mod_menus" then
    controls = "A OPEN   SELECT PIN   B BACK"
  elseif state.view == "gallery" then
    controls = "LEFT/RIGHT FAMILY   A PREVIEW   B BACK"
  elseif state.view == "gallery_preview" then
    controls = "LEFT/RIGHT FIXTURE   UP/DOWN CONTENT   A SIZE   SELECT TEXT   START FONT"
  else
    controls = "A CHOOSE   B BACK"
  end
  if state.notice then controls = state.notice end
  printAt(G, font, theme.colors.muted,
    textFit(font, controls, layout.footer.w), layout.footer.x,
    layout.footer.y + math.floor((layout.footer.h - font:getHeight()) / 2))
  drawModal(state, font, theme)
  drawDropdown(shell, font, theme)
  G.setColor(1, 1, 1, 1)
end

return Render
