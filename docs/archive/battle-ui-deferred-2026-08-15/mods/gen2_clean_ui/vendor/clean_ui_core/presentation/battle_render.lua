local requireCore = ...
local Color = requireCore("design.color")
local Frame = requireCore("design.frame")
local MenuRender = requireCore("presentation.menu_render")

local BattleRender = {}
local STATUS_LABELS = {
  poison="PSN", toxic="PSN", burn="BRN", freeze="FRZ",
  paralyze="PAR", sleep="SLP", confusion="CNF", confused="CNF",
}
local PHASE_LABELS = {
  intro="BATTLE START", ["trainer-slide"]="OPPONENT APPROACHES",
  ["locked-in"]="READY", resolving="EXECUTING",
  ["shift-intro"]="SWITCHING POKEMON", ["ask-shift"]="SWITCH POKEMON?",
  ["ask-next-mon"]="SEND OUT NEXT POKEMON?",
  ["learn-intro"]="LEARNING A MOVE", ["ask-forget"]="REPLACE A MOVE?",
  ["stop-learning"]="KEEP CURRENT MOVES?", ["choose-forget"]="CHOOSE A MOVE",
  ["stats-box"]="LEVEL UP", evolving="EVOLUTION", submenu="BATTLE",
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

local function wrapText(font, value, width, maxLines)
  local text = tostring(value or ""):gsub("%s+", " "):gsub("^%s+", "")
    :gsub("%s+$", "")
  width = math.max(1, tonumber(width) or 1)
  maxLines = math.max(1, tonumber(maxLines) or 1)
  if text == "" then return {} end
  local lines, current = {}, ""
  for word in text:gmatch("%S+") do
    local candidate = current == "" and word or current .. " " .. word
    if current ~= "" and font:getWidth(candidate) > width then
      lines[#lines + 1] = textFit(font, current, width)
      current = word
    else
      current = candidate
    end
  end
  if current ~= "" then lines[#lines + 1] = textFit(font, current, width) end
  if #lines > maxLines then
    local remainder = table.concat(lines, " ", maxLines, #lines)
    lines[maxLines] = textFit(font, lines[maxLines] .. " " .. remainder, width)
    for index = #lines, maxLines + 1, -1 do lines[index] = nil end
  end
  return lines
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
  local palette
  if name == "PAL_BATTLE_OB_PLAYER" then
    palette = model.player and model.player.sprite
      and model.player.sprite.palette or nil
  elseif name == "PAL_BATTLE_OB_ENEMY" then
    palette = model.enemy and model.enemy.sprite
      and model.enemy.sprite.palette or nil
  else
    palette = frameData.palettes and frameData.palettes[name]
  end
  return palette
end

local function battleFrame(model)
  return model.sceneFrame
    or (model.animation and (model.animation.sceneFrame
      or model.animation.frameData))
end

local function remapPalette(palette, byte)
  if type(palette) ~= "table" or not byte or byte == 228 then
    return palette
  end
  local shades, output = {}, {}
  for index = 0, 3 do
    shades[index + 1] = math.floor(byte / (4 ^ index)) % 4
  end
  for index = 1, 4 do
    output[index] = palette[shades[index] + 1] or palette[4]
  end
  return output
end

local function spriteForFrame(sprite, frameData, side)
  if type(sprite) ~= "table" then
    return sprite
  end
  local palette = sprite.trueColor and nil or sprite.palette
  if sprite.trueColor == true then
    return sprite
  end
  if type(frameData) == "table" and type(frameData.background) == "table"
      and frameData.background.lcdc == "BGP" then
    palette = remapPalette(palette, tonumber(frameData.background.bgp))
  end
  local pic = type(frameData) == "table" and type(frameData.pics) == "table"
    and frameData.pics[side] or nil
  if type(pic) == "table" and pic.shade ~= nil then
    palette = remapPalette(palette, tonumber(pic.shade))
  end
  if palette == sprite.palette then return sprite end
  local output = {}
  for key, value in pairs(sprite) do output[key] = value end
  output.palette = palette
  return output
end

local function signedByte(value)
  value = tonumber(value) or 0
  return value >= 128 and value - 256 or value
end

local function scanlineOffset(background, row)
  if type(background) ~= "table" then return 0, 0 end
  local dx = -signedByte(background.scx)
  local dy = -signedByte(background.scy)
  local startRow = math.max(0, math.floor(tonumber(background.lyStart) or 0))
  local endRow = math.min(144, math.floor(tonumber(background.lyEnd) or 0))
  local rows = background.lyBackup
  if row >= startRow and row < endRow and type(rows) == "table" then
    local override = signedByte(rows[row + 1])
    if background.lcdc == "SCX" then dx = -override
    elseif background.lcdc == "SCY" then dy = -override end
  end
  return dx, dy
end

local function averageScanlineOffset(background, top, height)
  local dx, dy, count = 0, 0, 0
  for row = math.max(0, math.floor(top)),
      math.min(144, math.ceil(top + height)) - 1 do
    local rowX, rowY = scanlineOffset(background, row)
    dx, dy, count = dx + rowX, dy + rowY, count + 1
  end
  if count == 0 then return 0, 0 end
  return dx / count, dy / count
end

local function paletteVeil(byte)
  byte = tonumber(byte)
  if not byte then return 0 end
  local total = 0
  for index = 0, 3 do
    total = total + math.floor(byte / (4 ^ index)) % 4
  end
  return (total - 6) / 6
end

local function drawBackgroundEffect(G, layout, frameData)
  local background = type(frameData) == "table" and frameData.background
  if type(background) ~= "table" or background.lcdc ~= "BGP" then
    return
  end
  local startRow = math.max(0, math.floor(tonumber(background.lyStart) or 0))
  local endRow = math.min(144, math.floor(tonumber(background.lyEnd) or 0))
  local rows = background.lyBackup
  if endRow <= startRow or type(rows) ~= "table" then return end
  local rowHeight = layout.arena.h / 144
  for row = startRow, endRow - 1 do
    local veil = paletteVeil(rows[row + 1])
    if veil ~= 0 then
      local shade = veil > 0 and 0 or 1
      G.setColor(shade, shade, shade, math.min(1, math.abs(veil)))
      G.rectangle("fill", layout.field.x,
        layout.field.y + row * layout.field.h / 144,
        layout.field.w, math.max(1, rowHeight + 0.5))
    end
  end
  G.setColor(1, 1, 1, 1)
end

local function overlaps(first, second)
  return first and second
    and first.x < second.x + second.w and second.x < first.x + first.w
    and first.y < second.y + second.h and second.y < first.y + first.h
end

local function drawAnimationObjects(G, layout, model)
  local frameData = battleFrame(model)
  if type(frameData) ~= "table" or type(frameData.objects) ~= "table" then
    return true
  end
  local field = layout.field
  local logicalWidth = math.max(1, tonumber(frameData.logicalWidth) or 160)
  local logicalHeight = math.max(1, tonumber(frameData.logicalHeight) or 144)
  local sx, sy = field.w / logicalWidth, field.h / logicalHeight
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
      local shiftX, shiftY = scanlineOffset(frameData and frameData.background,
        math.floor(tonumber(obj.y) or 0) - 16)
      x, y = x + shiftX * sx, y + shiftY * sy
      local size = math.max(1, math.min(sx, sy) * 8)
      local objectRect = { x=x, y=y, w=size, h=size }
      -- OAM is source-authored in the native 160x144 stage. Keep effects in
      -- the protected battlefield and never let an optional tile overwrite a
      -- status rail. Missing/partially offscreen tiles are presentation-only
      -- data; omitting them is safer than tearing down the whole battle frame.
      local inField = objectRect.x + objectRect.w > field.x
        and objectRect.x < field.x + field.w
        and objectRect.y + objectRect.h > field.y
        and objectRect.y < field.y + field.h
      if inField and not overlaps(objectRect, layout.enemyCard)
          and not overlaps(objectRect, layout.playerCard) then
        local ok = MenuRender.drawSprite(G, descriptor, objectRect)
        if ok ~= true then
          -- Animation objects are auxiliary to the battle presentation.  A
          -- missing optional effect sheet must not expose the native battle
          -- renderer for one frame; omit only the unavailable effect tile.
        end
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
  -- Battle presentation is always detached.  The host's canvas is not a
  -- presentation input; source-owned timing arrives through the V3 scene
  -- frame and the clean renderer reconstructs the field below.
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
    local frameData = battleFrame(model)
    local ok, code, message = card(G, rect, mon or {}, font, theme, scale, side)
    if ok ~= true then return nil, code, message end
    return true
  end
  local ok, code, message = drawCard(layout.enemyCard, model.enemy, "enemy")
  if ok ~= true then return nil, code, message end
  ok, code, message = drawCard(layout.playerCard, model.player, "player")
  if ok ~= true then return nil, code, message end
  local frameData = battleFrame(model)
  local function animatedSpriteRect(rect, side, sprite)
    local pic = frameData and frameData.pics and frameData.pics[side]
    -- A transition snapshot can legitimately contain only the native phase
    -- metadata while its optional OAM has not arrived yet.  Never let that
    -- incomplete snapshot hide the clean base sprite and leave an empty
    -- battlefield on screen.
    local output = {
      x=rect.x + (pic and (tonumber(pic.slide) or 0) or 0)
        * layout.field.w / 160,
      y=rect.y, w=rect.w, h=rect.h,
    }
    local sizes = side == "player"
      and { [0]=1, [1]=4/6, [2]=2/6 }
      or { [3]=1, [4]=5/7, [5]=3/7 }
    local factor = pic and sizes[tonumber(pic.size)] or nil
    local baseScale = (pic and tonumber(pic.scale))
      or (type(sprite) == "table" and tonumber(sprite.scale)) or 1
    if pic then
      -- A complete source runner owns hidden/resize/slide state even when its
      -- current OAM list is empty (faint, return-mon, and BG-only effects all
      -- use that path).  The presenter rejects structurally incomplete runners
      -- before suppression, so honoring this flag cannot create a blank frame
      -- from a partial snapshot.
      if pic.hidden and frameData.sourceAvailable == true then return nil end

      if factor then
        output.w, output.h = rect.w * factor * baseScale,
          rect.h * factor * baseScale
        output.x = output.x + (rect.w - output.w) * 0.5
        output.y = rect.y + rect.h - output.h
      elseif baseScale ~= 1 then
        output.w, output.h = rect.w * baseScale, rect.h * baseScale
        output.x = output.x + (rect.w - output.w) * 0.5
        output.y = output.y + rect.h - output.h
      end
    end
    if not pic and baseScale ~= 1 then
      output.w, output.h = rect.w * baseScale, rect.h * baseScale
      output.x = output.x + (rect.w - output.w) * 0.5
      output.y = rect.y + rect.h - output.h
    end
    local animation = model.animation
    if animation and animation.kind == "trainer-slide" and side == "enemy" then
      -- BattleState slides the trainer one native tile every two frames.
      -- Keep the source's integer stepping instead of interpolating the
      -- presentation, which otherwise puts the trainer between cart frames.
      output.x = output.x + math.floor((tonumber(animation.frame) or 0) / 2)
        * 8 * layout.field.w / 160
    elseif animation and animation.kind == "faint"
        and side == animation.side then
      local boxPixels = math.max(1, tonumber(animation.boxPixels)
        or (side == "player" and 48 or 56))
      local sink = tonumber(animation.sink)
      local remaining = sink and math.max(0, math.min(1,
        1 - sink / boxPixels)) or math.max(0, math.min(1,
        1 - (tonumber(animation.progress) or 0)))
      output.y = output.y + output.h * (1 - remaining)
      output.h = output.h * remaining
      if output.h <= 0.5 then return nil end
    end
    local background = frameData and frameData.background
    local nativeTop = side == "enemy" and 0 or 48
    local nativeHeight = side == "enemy" and 56 or 48
    local shiftX, shiftY = averageScanlineOffset(background,
      nativeTop, nativeHeight)
    output.x = output.x + shiftX * layout.field.w / 160
    output.y = output.y + shiftY * layout.field.h / 144
    local intro = animation and animation.intro
    if animation and animation.kind == "intro" and type(intro) == "table" then
      if side == "enemy" then
        local scroll = tonumber(intro.topScroll) or 0
        local delta = scroll > 128 and 256 - scroll or -scroll
        output.x = output.x + delta * layout.field.w / 160
      elseif side == "player" then
        output.x = output.x + (tonumber(intro.backpicOffset) or 0)
          * layout.field.w / 160
      end
    end
    return output
  end
  local introKind = model.animation and model.animation.kind
  local enemySprite = model.enemy and model.enemy.sprite
  if (introKind == "intro" or introKind == "trainer-slide")
      and model.enemyTrainer then
    enemySprite = model.enemyTrainer
  end
  if enemySprite
      and not (model.enemy and model.enemy.hidden) then
    local spriteRect = layout.enemySprite
    spriteRect = animatedSpriteRect(spriteRect, "enemy", enemySprite)
    if spriteRect then
      local ok, code, message = MenuRender.drawSprite(G,
        spriteForFrame(enemySprite, frameData, "enemy"),
        spriteRect)
      if ok ~= true then return nil, code, message end
    end
  end
  local playerSprite = model.player and model.player.sprite
  if introKind == "intro" and model.playerTrainer then
    playerSprite = model.playerTrainer
  end
  if playerSprite
      and not (model.player and model.player.hidden) then
    local spriteRect = layout.playerSprite
    spriteRect = animatedSpriteRect(spriteRect, "player", playerSprite)
    if spriteRect then
      local ok, code, message = MenuRender.drawSprite(G,
        spriteForFrame(playerSprite, frameData, "player"),
        spriteRect)
      if ok ~= true then return nil, code, message end
    end
  end
  local ok, code, message = drawAnimationObjects(G, layout, model)
  if ok ~= true then return nil, code, message end
  drawBackgroundEffect(G, layout, frameData)

  Color.set(G, theme.colors.raised)
  G.rectangle("fill", layout.panel.x, layout.panel.y,
    layout.panel.w, layout.panel.h)
  local dockPad = layout.dockPad or layout.gap
  local title = model.phase == "moves" and "CHOOSE A MOVE"
    or model.phase == "choose-forget" and "CHOOSE A MOVE TO FORGET"
    or model.message and "BATTLE"
    or model.animation and "BATTLE"
    or "CHOOSE AN ACTION"
  printAt(G, font, theme.colors.muted, textFit(font, title,
    layout.panel.w - dockPad * 2), layout.panel.x + dockPad,
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
        item.rect.x + item.rect.w - dockPad - font:getWidth(pp),
        item.rect.y + math.floor((item.rect.h - font:getHeight()) / 2))
    end
  end
  if layout.moveInfoRegion then
    local region = layout.moveInfoRegion
    Color.set(G, theme.colors.paper)
    G.rectangle("fill", region.x, region.y, region.w, region.h)
    local selected = model.actions and model.actions[model.selectedMove or 1]
    if selected then
      local x, y = region.x + dockPad, region.y + dockPad
      local value = actionLabel(selected)
      local pp = ("%d/%d PP"):format(selected.pp or 0, selected.maxPp or 0)
      printAt(G, font, theme.colors.ink,
        textFit(font, value, math.max(1, region.w - dockPad * 2
          - font:getWidth(pp) - dockPad)),
        x, y)
      printAt(G, font, theme.colors.muted, pp,
        region.x + region.w - dockPad - font:getWidth(pp), y)
      y = y + font:getHeight() + math.max(2, math.floor(3 * scale))
      if selected.type then
        local badgeHeight = math.max(font:getHeight() + math.floor(4 * scale),
          math.floor(22 * scale))
        local badgeBottom = MenuRender.drawTypeBadges(G, { selected.type }, {
          x=x, y=y, w=math.max(1, region.w * 0.45),
          h=badgeHeight,
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
          textFit(font, table.concat(meta, "  "), region.w - dockPad * 2),
          x, y)
        y = y + font:getHeight() + math.max(2, math.floor(3 * scale))
      end
      if selected.description and selected.description ~= ""
          and y + font:getHeight() <= region.y + region.h then
        local lineGap = math.max(2, math.floor(3 * scale))
        local remaining = math.max(1, region.y + region.h - y)
        local lineHeight = font:getHeight() + lineGap
        local maxLines = math.max(1, math.floor((remaining + lineGap)
          / lineHeight))
        for lineIndex, line in ipairs(wrapText(font, selected.description,
            region.w - dockPad * 2, maxLines)) do
          printAt(G, font, theme.colors.muted, line, x,
            y + (lineIndex - 1) * lineHeight)
        end
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
      stats.specialAttack and ("SPC " .. tostring(stats.specialAttack)) or nil,
    }
    local y = region.y + dockPad
    for _, row in ipairs(rows) do
      if row and y + font:getHeight() <= region.y + region.h then
        printAt(G, font, theme.colors.ink,
          textFit(font, row, region.w - dockPad * 2),
          region.x + dockPad, y)
        y = y + font:getHeight() + math.max(2, math.floor(3 * scale))
      end
    end
  end
  local stageText = model.message
  -- An animation descriptor is not a substitute for its source frame.  If a
  -- released host cannot provide that frame, preparation fails open or keeps
  -- the prior battle candidate; never paint labels such as ENEMY DAMAGE or
  -- PLAYER DAMAGE over an otherwise empty arena.
  if (not stageText or stageText == "") and not model.animation
      and model.phase then
    stageText = PHASE_LABELS[model.phase]
  end
  if stageText and #layout.menu == 0 and not model.statsBox then
    printAt(G, font, theme.colors.ink, textFit(font, stageText,
      layout.messageRegion.w), layout.messageRegion.x,
      layout.messageRegion.y + math.floor((layout.messageRegion.h
        - font:getHeight()) / 2))
  end
  G.setColor(1, 1, 1, 1)
  return true
end

return BattleRender
