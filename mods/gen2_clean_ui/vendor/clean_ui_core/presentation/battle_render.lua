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

local function animationSheet(frameData, tile)
  for index = #(frameData.sheets or {}), 1, -1 do
    local sheet = frameData.sheets[index]
    local first = tonumber(sheet.tile) or 0
    local count = math.max(1, tonumber(sheet.tiles) or 0)
    if tile >= first and tile < first + count then
      return sheet, tile - first
    end
  end
  return nil
end

local function animationPalette(frameData, obj, model)
  local name = obj.palette
  if name == "PAL_BATTLE_OB_PLAYER" then
    return model.player and model.player.sprite
      and model.player.sprite.palette or nil
  elseif name == "PAL_BATTLE_OB_ENEMY" then
    return model.enemy and model.enemy.sprite
      and model.enemy.sprite.palette or nil
  end
  return frameData.palettes and frameData.palettes[name]
end

local function drawAnimationObjects(G, layout, model)
  local animation = model.animation
  local frameData = animation and animation.frameData
  if type(frameData) ~= "table" or type(frameData.objects) ~= "table" then
    return true
  end
  local field = layout.field
  local sx, sy = field.w / 160, field.h / 144
  for _, obj in ipairs(frameData.objects) do
    local tile = tonumber(obj.tile)
    -- Keep both returns from animationSheet.  Using `tile and
    -- animationSheet(...)` here would collapse the second return value in
    -- Lua, leaving the crop index nil and aborting the frame during a live
    -- move/ball animation.
    local entry, index
    if tile then entry, index = animationSheet(frameData, tile) end
    if entry and not entry.battler and type(entry.path) == "string" then
      local wide = math.max(1, tonumber(entry.wide) or 8)
      local descriptor = {
        path=entry.path,
        crop={ x=(index % wide) * 8,
          y=math.floor(index / wide) * 8, w=8, h=8 },
        palette=animationPalette(frameData, obj, model),
        flipX=type(obj.attr) == "number" and (obj.attr % 64 >= 32),
        flipY=type(obj.attr) == "number" and (obj.attr % 128 >= 64),
      }
      local x = field.x + ((tonumber(obj.x) or 0) - 8) * sx
      local y = field.y + ((tonumber(obj.y) or 0) - 16) * sy
      local size = math.max(1, math.min(sx, sy) * 8)
      local ok, code, message = MenuRender.drawSprite(G, descriptor, {
        x=x, y=y, w=size, h=size,
      })
      if ok ~= true then
        -- Animation objects are auxiliary to the battle presentation.  A
        -- missing optional effect sheet must not tear down the whole Clean UI
        -- candidate and expose the native battle renderer for one frame;
        -- keep the HUD and battlers owned by this renderer and omit only the
        -- unavailable effect tile.
      end
    end
  end
  return true
end

local function detailLabel(mon)
  local parts = {}
  local status = statusLabel(mon)
  if status then parts[#parts + 1] = status end
  if mon.caught then parts[#parts + 1] = "CAUGHT" end
  return table.concat(parts, "  ")
end

local function hpColor(fraction)
  if fraction <= 0.25 then return "#D94A4A" end
  if fraction <= 0.5 then return "#E0B64A" end
  return "#4DBB63"
end

local function card(G, rect, mon, font, theme, scale, side)
  Color.set(G, theme.colors.raised)
  G.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
  local gap = math.max(6, math.floor(8 * scale))
  local line = font:getHeight()
  local level = "Lv " .. tostring(mon.level or 1)
  local rightLabel = level
  local rightWidth = font:getWidth(rightLabel)
  local genderSize = math.min(16 * scale, math.max(line, rect.h - gap * 2))
  local genderWidth = mon.genderIcon and (genderSize + gap) or 0
  local nameWidth = math.max(1, rect.w - gap * 2 - rightWidth - genderWidth)
  local name = mon.name or mon.species or "?"
  local detail = detailLabel(mon)
  name = textFit(font, name, nameWidth)
  local topY = rect.y + gap
  printAt(G, font, theme.colors.ink, name, rect.x + gap, topY)
  printAt(G, font, theme.colors.muted, rightLabel,
    rect.x + rect.w - gap - rightWidth, rect.y + gap)
  if mon.genderIcon then
    local iconRect = {
      x=rect.x + rect.w - gap - rightWidth - genderSize - gap * 0.25,
      y=topY + math.max(0, math.floor((line - genderSize) * 0.5)),
      w=genderSize, h=genderSize,
    }
    local ok, code, message = MenuRender.drawSprite(G, mon.genderIcon,
      iconRect)
    if ok ~= true then return nil, code, message end
  end

  local hp = math.max(0, tonumber(mon.hp) or 0)
  local maxHp = math.max(1, tonumber(mon.maxHp) or 1)
  local hpFraction = math.max(0, math.min(1, hp / maxHp))
  local hpLabel = mon.hpText or ("HP %d/%d"):format(hp, maxHp)
  local barHeight = math.max(4, math.floor(6 * scale))
  local exp = side == "player" and tonumber(mon.exp) or nil
  local expColor = theme.colors.gen2Accent or theme.colors.focus
  local barGap = math.max(2, math.floor(3 * scale))
  -- Reserve the status bars first. Content above them is allowed to become
  -- less detailed on a short card, but bars and labels must never collide
  -- with a badge or another line of text.
  local expLabel, hpY, hpLabelY, expY, expLabelY
  if exp ~= nil then
    expLabel = mon.expText or ("EXP %d/%d"):format(
      math.floor(exp * 64 + 0.5), 64)
  end
  -- Keep HP above EXP in the player card.  The footer is laid out from the
  -- bottom of the card so the two bars remain a stable, readable stack while
  -- badges and status text use the space above them.
  local function footerMetrics(height, spacing)
    local footerBottom = rect.y + rect.h - gap
    local total = height + spacing + line
    if exp ~= nil then
      total = total + spacing + height + spacing + line
    end
    local top = footerBottom - total
    local hpBarY = top
    local hpTextY = hpBarY + height + spacing
    local expBarY, expTextY
    if exp ~= nil then
      expBarY = hpTextY + line + spacing
      expTextY = expBarY + height + spacing
    end
    return top, hpBarY, hpTextY, expBarY, expTextY
  end
  local footerTop
  footerTop, hpY, hpLabelY, expY, expLabelY = footerMetrics(
    barHeight, barGap)
  local badgeHeight = math.max(1, line + gap)
  local contentY = topY + line + math.max(2, math.floor(3 * scale))
  local badgeGap = math.max(2, math.floor(3 * scale))
  local contentNeed = contentY + (type(mon.types) == "table"
    and #mon.types > 0 and (badgeHeight + badgeGap) or 0)
  if detail ~= "" then contentNeed = contentNeed + line end
  contentNeed = contentNeed + gap
  if footerTop < contentNeed then
    -- Preserve both metadata rows on narrow cards by shrinking the bars to a
    -- legible minimum before dropping any label or badge.
    barHeight = math.max(3, math.floor(barHeight * 0.5))
    barGap = math.max(2, math.floor(barGap * 0.67))
    footerTop, hpY, hpLabelY, expY, expLabelY = footerMetrics(
      barHeight, barGap)
  end
  local contentBottom = footerTop - gap
  if type(mon.types) == "table" and #mon.types > 0
      and contentY + badgeHeight <= contentBottom then
    contentY = MenuRender.drawTypeBadges(G, mon.types, {
      x=rect.x + gap, y=contentY,
      w=math.max(1, rect.w - gap * 2), h=badgeHeight,
    }, font, theme, scale) + math.max(2, math.floor(3 * scale))
  end
  if detail ~= "" and contentY + line <= contentBottom then
    printAt(G, font, theme.colors.gen2Accent or theme.colors.focus,
      textFit(font, detail, rect.w - gap * 2), rect.x + gap, contentY)
  end
  bar(G, { x=rect.x + gap, y=hpY,
    w=math.max(1, rect.w - gap * 2), h=barHeight }, hpFraction, theme,
    hpColor(hpFraction))
  printAt(G, font, theme.colors.muted,
    textFit(font, hpLabel, rect.w - gap * 2),
    rect.x + gap, hpLabelY)
  if expY then
    bar(G, { x=rect.x + gap, y=expY,
      w=math.max(1, rect.w - gap * 2), h=barHeight }, exp, theme, expColor)
    printAt(G, font, theme.colors.muted,
      textFit(font, expLabel, rect.w - gap * 2),
      rect.x + gap, expLabelY)
  end
  return true
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

  local function drawCard(rect, mon, side)
    if mon and mon.hudVisible == false then return true end
    local frameData = model.animation and model.animation.frameData
    if frameData and frameData.clearsHud and frameData.hudSide == side then
      return true
    end
    local ok, code, message = card(G, rect, mon or {}, font, theme, scale, side)
    if ok ~= true then return nil, code, message end
    return true
  end
  local ok, code, message = drawCard(layout.enemyCard, model.enemy, "enemy")
  if ok ~= true then return nil, code, message end
  ok, code, message = drawCard(layout.playerCard, model.player, "player")
  if ok ~= true then return nil, code, message end
  local frameData = model.animation and model.animation.frameData
  local function animatedSpriteRect(rect, side)
    local pic = frameData and frameData.pics and frameData.pics[side]
    if not pic then return rect end
    if pic.hidden then return nil end
    local output = {
      x=rect.x + (tonumber(pic.slide) or 0) * layout.field.w / 160,
      y=rect.y, w=rect.w, h=rect.h,
    }
    local sizes = side == "player"
      and { [0]=1, [1]=4/6, [2]=2/6 }
      or { [3]=1, [4]=5/7, [5]=3/7 }
    local factor = sizes[tonumber(pic.size)]
    if factor then
      output.w, output.h = rect.w * factor, rect.h * factor
      output.x = output.x + (rect.w - output.w) * 0.5
      output.y = rect.y + rect.h - output.h
    end
    return output
  end

  local function trainerRect(rect, side)
    local animation = model.animation
    if not animation then return rect end
    if animation.kind == "intro" then
      local progress = animation.progress or 0
      return {
        x=rect.x + (side == "enemy" and 1 or -1)
          * (1 - progress) * layout.field.w * 0.35,
        y=rect.y, w=rect.w, h=rect.h,
      }
    elseif animation.kind == "trainer-slide" and side == "enemy" then
      local progress = animation.progress or 0
      return {
        x=rect.x + progress * layout.field.w * 0.35,
        y=rect.y, w=rect.w, h=rect.h,
      }
    end
    return rect
  end

  local function drawBattler(side, mon, trainer, rect)
    local descriptor = trainer or (mon and mon.sprite)
    if not descriptor then return true end
    local spriteRect = trainerRect(rect, side)
    spriteRect = animatedSpriteRect(spriteRect, side)
    if not spriteRect then return true end
    local ok, code, message = MenuRender.drawSprite(G, descriptor, spriteRect)
    if ok ~= true then return nil, code, message end
    return true
  end

  if model.enemy and (model.enemyTrainer or model.enemy.sprite) then
    local spriteRect = layout.enemySprite
    local ok, code, message = drawBattler("enemy", model.enemy,
      model.enemyTrainer, spriteRect)
    if ok ~= true then return nil, code, message end
  end
  if model.player and (model.playerTrainer or model.player.sprite) then
    local spriteRect = layout.playerSprite
    local ok, code, message = drawBattler("player", model.player,
      model.playerTrainer, spriteRect)
    if ok ~= true then return nil, code, message end
  end
  local ok, code, message = drawAnimationObjects(G, layout, model)
  if ok ~= true then return nil, code, message end

  Color.set(G, theme.colors.raised)
  G.rectangle("fill", layout.panel.x, layout.panel.y,
    layout.panel.w, layout.panel.h)
  local title = model.phase == "moves" and "CHOOSE A MOVE"
    or model.phase == "choose-forget" and "CHOOSE A MOVE TO FORGET"
    or model.message and "BATTLE" or "CHOOSE AN ACTION"
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
    if layout.moveList and item.action and item.action.pp ~= nil then
      local pp = ("%d/%d"):format(item.action.pp or 0,
        item.action.maxPp or 0)
      printAt(G, font, theme.colors.muted, pp,
        item.rect.x + item.rect.w - layout.gap - font:getWidth(pp),
        item.rect.y + math.floor((item.rect.h - font:getHeight()) / 2))
    end
  end
  if layout.moveInfoRegion then
    local region = layout.moveInfoRegion
    Color.set(G, theme.colors.paper)
    G.rectangle("fill", region.x, region.y, region.w, region.h)
    local selected = model.actions and model.actions[model.selectedMove or 1]
    if selected then
      local x, y = region.x + layout.gap, region.y + layout.gap
      local value = actionLabel(selected)
      local pp = ("%d/%d PP"):format(selected.pp or 0, selected.maxPp or 0)
      printAt(G, font, theme.colors.ink,
        textFit(font, value, math.max(1, region.w - layout.gap * 2
          - font:getWidth(pp) - layout.gap)),
        x, y)
      printAt(G, font, theme.colors.muted, pp,
        region.x + region.w - layout.gap - font:getWidth(pp), y)
      y = y + font:getHeight() + math.max(2, math.floor(3 * scale))
      if selected.type then
        local badgeBottom = MenuRender.drawTypeBadges(G, { selected.type }, {
          x=x, y=y, w=math.max(1, region.w * 0.45),
          h=math.max(1, region.h - (y - region.y)),
        }, font, theme, scale)
        y = badgeBottom + math.max(2, math.floor(3 * scale))
      end
      local meta = {}
      if selected.power then meta[#meta + 1] = "POWER " .. selected.power end
      if selected.accuracy then meta[#meta + 1] = "ACC " .. selected.accuracy end
      if selected.category and selected.category ~= "" then
        meta[#meta + 1] = selected.category
      end
      if #meta > 0 and y + font:getHeight() <= region.y + region.h then
        printAt(G, font, theme.colors.muted,
          textFit(font, table.concat(meta, "  "), region.w - layout.gap * 2),
          x, y)
        y = y + font:getHeight() + math.max(2, math.floor(3 * scale))
      end
      if selected.description and selected.description ~= ""
          and y + font:getHeight() <= region.y + region.h then
        printAt(G, font, theme.colors.muted,
          textFit(font, selected.description, region.w - layout.gap * 2),
          x, y)
      end
    end
  end
  if model.statsBox and layout.messageRegion then
    local region = layout.messageRegion
    Color.set(G, theme.colors.paper)
    G.rectangle("fill", region.x, region.y, region.w, region.h)
    local stats = model.statsBox.stats or {}
    local rows = {
      tostring(model.statsBox.name or "POKEMON"),
      "LEVEL " .. tostring(model.statsBox.level or 1),
      stats.attack and ("ATK " .. tostring(stats.attack)) or nil,
      stats.defense and ("DEF " .. tostring(stats.defense)) or nil,
      stats.speed and ("SPD " .. tostring(stats.speed)) or nil,
      stats.specialAttack and ("SPCL ATK " .. tostring(stats.specialAttack))
        or nil,
      stats.specialDefense and ("SPCL DEF " .. tostring(stats.specialDefense))
        or nil,
    }
    local y = region.y + layout.gap
    for _, row in ipairs(rows) do
      if row and y + font:getHeight() <= region.y + region.h then
        printAt(G, font, theme.colors.ink,
          textFit(font, row, region.w - layout.gap * 2),
          region.x + layout.gap, y)
        y = y + font:getHeight() + math.max(2, math.floor(3 * scale))
      end
    end
  end
  if model.message and #layout.menu == 0 and not model.statsBox then
    printAt(G, font, theme.colors.ink, textFit(font, model.message,
      layout.messageRegion.w), layout.messageRegion.x,
      layout.messageRegion.y + math.floor((layout.messageRegion.h
        - font:getHeight()) / 2))
  end
  G.setColor(1, 1, 1, 1)
  return true
end

return BattleRender
