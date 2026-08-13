local requireCore = ...
local Color = requireCore("design.color")
local Frame = requireCore("design.frame")
local MenuRender = requireCore("presentation.menu_render")

local BattleRender = {}
local STATUS_LABELS = {
  poison="PSN", toxic="PSN", burn="BRN", freeze="FRZ",
  paralyze="PAR", sleep="SLP", confusion="CNF", confused="CNF",
}

local function printAt(G, font, color, value, x, y)
  G.setFont(font)
  Color.set(G, color)
  G.print(tostring(value or ""), math.floor(x), math.floor(y))
end

local function textFit(font, value, width)
  local text = tostring(value or "")
  if font:getWidth(text) <= width then return text end
  while #text > 1 and font:getWidth(text .. "...") > width do
    text = text:sub(1, #text - 1)
  end
  return text .. "..."
end

local function bar(G, rect, fraction, theme, fillColor)
  Color.set(G, theme.colors.muted)
  G.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
  Color.set(G, fillColor or theme.colors.paper)
  G.rectangle("fill", rect.x + 1, rect.y + 1,
    math.max(0, (rect.w - 2) * math.max(0, math.min(1, fraction))),
    math.max(0, rect.h - 2))
end

local function statusLabel(mon)
  local raw = tostring(mon.status or "")
  local key = raw:lower()
  local label = STATUS_LABELS[key]
  if raw ~= "" and key ~= "ok" and key ~= "none" then
    label = label or raw
  end
  if mon.confused and label ~= "CNF" then
    label = label and (label .. " CNF") or "CNF"
  end
  return label
end

local function genderLabel(mon)
  if mon.gender == "male" then return "\226\153\130" end
  if mon.gender == "female" then return "\226\153\128" end
  return nil
end

local function detailLabel(mon)
  local parts = {}
  local status = statusLabel(mon)
  if status then parts[#parts + 1] = status end
  if mon.caught then parts[#parts + 1] = "CAUGHT" end
  return table.concat(parts, "  ")
end

local function card(G, rect, mon, font, theme, scale, side)
  Color.set(G, theme.colors.raised)
  G.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
  local gap = math.max(6, math.floor(8 * scale))
  local compact = rect.h < font:getHeight() * 2 + gap * 2
  local level = "Lv " .. tostring(mon.level or 1)
  local gender = genderLabel(mon)
  local rightLabel = level .. (gender and (" " .. gender) or "")
  local rightWidth = font:getWidth(rightLabel)
  local nameWidth = math.max(1, rect.w - gap * 2 - rightWidth)
  local name = mon.name or mon.species or "?"
  local detail = detailLabel(mon)
  local detailRoom = font:getHeight() * 3 + gap * 3
  local showDetail = detail ~= "" and rect.h >= detailRoom
  if not showDetail and detail ~= "" then
    name = name .. " [" .. detail .. "]"
  end
  name = textFit(font, name, nameWidth)
  printAt(G, font, theme.colors.ink, name, rect.x + gap, rect.y + gap)
  printAt(G, font, theme.colors.muted, rightLabel,
    rect.x + rect.w - gap - rightWidth, rect.y + gap)
  if showDetail then
    printAt(G, font, theme.colors.gen2Accent or theme.colors.focus, detail,
      rect.x + gap, rect.y + gap + font:getHeight())
  end
  local hp = math.max(0, tonumber(mon.hp) or 0)
  local maxHp = math.max(1, tonumber(mon.maxHp) or 1)
  local hpLabel = ("HP %d/%d"):format(hp, maxHp)
  local barHeight = math.max(4, math.floor(6 * scale))
  local exp = side == "player" and tonumber(mon.exp) or nil
  local expColor = theme.colors.gen2Accent or theme.colors.focus
  local barGap = math.max(2, math.floor(3 * scale))
  local barY = rect.y + rect.h - gap - barHeight
  local stacked = exp ~= nil
    and rect.h >= font:getHeight() * 3 + gap * 3
  if exp ~= nil and stacked then
    local expY = barY
    local hpY = expY - barGap - barHeight
    printAt(G, font, theme.colors.muted, textFit(font, hpLabel,
      rect.w * 0.42), rect.x + gap,
      hpY - font:getHeight())
    bar(G, { x=rect.x + rect.w * 0.48, y=hpY,
      w=rect.w * 0.45, h=barHeight }, hp / maxHp, theme)
    printAt(G, font, theme.colors.muted, "EXP",
      rect.x + gap, expY - font:getHeight())
    bar(G, { x=rect.x + rect.w * 0.48, y=expY,
      w=rect.w * 0.45, h=barHeight }, exp, theme, expColor)
  elseif exp ~= nil then
    local totalW = math.max(1, rect.w - gap * 2)
    local segmentGap = math.max(2, math.floor(3 * scale))
    local segmentW = math.max(1, (totalW - segmentGap) / 2)
    bar(G, { x=rect.x + gap, y=barY, w=segmentW, h=barHeight },
      hp / maxHp, theme)
    bar(G, { x=rect.x + gap + segmentW + segmentGap, y=barY,
      w=segmentW, h=barHeight }, exp, theme, expColor)
  elseif compact then
    bar(G, { x=rect.x + gap, y=rect.y + rect.h - gap - barHeight,
      w=math.max(1, rect.w - gap * 2), h=barHeight }, hp / maxHp, theme)
  else
    printAt(G, font, theme.colors.muted, textFit(font, hpLabel,
      rect.w * 0.42), rect.x + gap,
      rect.y + rect.h - gap - font:getHeight())
    bar(G, { x=rect.x + rect.w * 0.48, y=rect.y + rect.h - gap
        - barHeight, w=rect.w * 0.45, h=barHeight }, hp / maxHp,
      theme)
  end
end

local function actionLabel(action)
  return tostring(action.label or action.name or action.id or "ACTION")
end

function BattleRender.draw(graphics, model, layout, font, theme)
  local G = graphics
  local scale = layout.scale or 1
  if model.opaque then
    Color.set(G, theme.colors.raised)
    G.rectangle("fill", 0, 0, layout.viewport.w, layout.viewport.h)
  end
  Frame.draw(G, layout.outer, theme, scale)
  Color.set(G, theme.colors.paper)
  G.rectangle("fill", layout.field.x, layout.field.y,
    layout.field.w, layout.field.h)
  Color.set(G, theme.colors.selection)
  G.rectangle("fill", layout.arena.x, layout.arena.y + layout.arena.h * 0.58,
    layout.arena.w, layout.arena.h * 0.42)
  Color.set(G, theme.colors.muted, 0.5)
  G.line(layout.arena.x, layout.arena.y + layout.arena.h * 0.58,
    layout.arena.x + layout.arena.w,
    layout.arena.y + layout.arena.h * 0.58)

  card(G, layout.enemyCard, model.enemy or {}, font, theme, scale, "enemy")
  card(G, layout.playerCard, model.player or {}, font, theme, scale, "player")
  if model.enemy and model.enemy.sprite then
    local ok, code, message = MenuRender.drawSprite(G, model.enemy.sprite,
      layout.enemySprite)
    if ok ~= true then return nil, code, message end
  end
  if model.player and model.player.sprite then
    local ok, code, message = MenuRender.drawSprite(G, model.player.sprite,
      layout.playerSprite)
    if ok ~= true then return nil, code, message end
  end

  Color.set(G, theme.colors.raised)
  G.rectangle("fill", layout.panel.x, layout.panel.y,
    layout.panel.w, layout.panel.h)
  local title = model.message and "BATTLE" or "CHOOSE AN ACTION"
  printAt(G, font, theme.colors.muted, textFit(font, title,
    layout.panel.w - layout.gap * 2), layout.panel.x + layout.gap,
    layout.panel.y + math.floor((layout.titleHeight - font:getHeight()) / 2))
  for _, item in ipairs(layout.menu or {}) do
    local selected = item.index == (model.selectedAction or model.selectedMove)
    if selected then
      Color.set(G, theme.colors.selection)
      G.rectangle("fill", item.rect.x, item.rect.y,
        item.rect.w, item.rect.h)
      Color.set(G, theme.colors.focus)
      G.rectangle("fill", item.rect.x, item.rect.y,
        math.max(2, math.floor(3 * scale)), item.rect.h)
    end
    printAt(G, font, theme.colors.ink, textFit(font, actionLabel(item.action),
      item.rect.w - 20), item.rect.x + 10,
      item.rect.y + math.floor((item.rect.h - font:getHeight()) / 2))
  end
  if model.message and #layout.menu == 0 then
    printAt(G, font, theme.colors.ink, textFit(font, model.message,
      layout.messageRegion.w), layout.messageRegion.x,
      layout.messageRegion.y + math.floor((layout.messageRegion.h
        - font:getHeight()) / 2))
  end
  G.setColor(1, 1, 1, 1)
  return true
end

return BattleRender
