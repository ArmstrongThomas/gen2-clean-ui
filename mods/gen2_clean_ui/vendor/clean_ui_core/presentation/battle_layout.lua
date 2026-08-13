local requireCore = ...
local Rect = requireCore("geometry.rect")

local BattleLayout = {}

local function inset(rect, amount)
  return Rect.inset(rect, { x=amount, y=amount })
end

local function overlaps(first, second)
  return first and second
    and first.x < second.x + second.w and second.x < first.x + first.w
    and first.y < second.y + second.h and second.y < first.y + first.h
end

function BattleLayout.measure(base, model, font, density)
  local scale = base.scale or 1
  local compact = density == "compact"
  local frame = math.max(2, math.floor(2 * scale + 0.5))
  local pad = math.max(8, math.floor((compact and 10 or 14) * scale))
  local gap = math.max(6, math.floor(8 * scale + 0.5))
  local fontHeight = math.max(1, font:getHeight())
  local inner = inset(base.outer, frame + pad)
  local portrait = base.orientation == "portrait"
  local actions = model.actions or {}
  local columns = portrait and 1 or math.min(2, #actions)
  local rows = #actions > 0 and math.ceil(#actions / math.max(1, columns)) or 0
  local titleH = math.max(fontHeight + pad, math.floor(30 * scale + 0.5))
  local rowH = math.max(fontHeight + pad, math.floor(36 * scale + 0.5))
  local menuH = rows > 0
    and rows * rowH + math.max(0, rows - 1) * gap or 0
  local panelH = titleH + pad + menuH + pad
  if rows == 0 then
    panelH = math.max(panelH, fontHeight * 2 + pad * 3)
  end
  -- The command panel must not consume the entire arena on short screens.
  -- If the requested font cannot fit inside this cap, the runtime probe will
  -- choose the next whole font step instead of producing a text-free battle.
  local panelCap = math.floor(inner.h * (portrait and 0.48 or 0.46))
  panelH = math.min(panelH, math.max(1,
    math.min(inner.h - gap - 1, panelCap)))
  local field = Rect.new(inner.x, inner.y, inner.w,
    math.max(1, inner.h - panelH - gap))
  local panel = Rect.new(inner.x, field.y + field.h + gap,
    inner.w, math.max(1, inner.h - field.h - gap))

  -- Use the native Gen II diagonal: enemy status upper-left with enemy
  -- sprite upper-right; player sprite lower-left with player status
  -- lower-right. Keeping each row as a separate pair gives the sprites
  -- room to breathe without making the cards collide at large text sizes.
  local rowGap = math.max(gap, math.floor(field.h * 0.04))
  local rowH = math.max(1, (field.h - rowGap) / 2)
  local topRow = Rect.new(field.x, field.y, field.w, rowH)
  local bottomRow = Rect.new(field.x, field.y + rowH + rowGap,
    field.w, rowH)
  local columnGap = math.max(gap, math.floor(field.w * 0.05))
  local cardW = math.max(1, math.floor((field.w - columnGap) * 0.46))
  local spriteW = math.max(1, field.w - columnGap - cardW)
  local cardH = math.max(fontHeight + gap * 2,
    math.floor(54 * scale + 0.5))
  cardH = math.min(cardH, math.max(1, rowH))
  local spriteInset = math.max(1, math.floor(gap * 0.35))
  local hud = Rect.copy(field)
  local arena = Rect.copy(field)
  local enemyCard, playerCard, enemySprite, playerSprite
  if portrait then
    enemyCard = Rect.new(hud.x, hud.y, hud.w, cardH)
    playerCard = Rect.new(hud.x, hud.y + cardH + gap, hud.w, cardH)
    enemySprite = Rect.new(arena.x + arena.w * 0.54,
      arena.y + arena.h * 0.04, arena.w * 0.38, arena.h * 0.44)
    playerSprite = Rect.new(arena.x + arena.w * 0.08,
      arena.y + arena.h * 0.46, arena.w * 0.38, arena.h * 0.50)
  else
    local cardW = math.max(1, (hud.w - gap) / 2)
    -- Keep the Gen II battle convention: the opponent owns the upper-left
    -- side of the wide arena and the player's active Pokémon owns the
    -- lower-right side. The card and sprite for each side share that anchor.
    enemyCard = Rect.new(hud.x, hud.y, cardW, cardH)
    playerCard = Rect.new(hud.x + cardW + gap, hud.y, cardW, cardH)
    enemySprite = Rect.new(arena.x + arena.w * 0.08,
      arena.y + arena.h * 0.04, arena.w * 0.38, arena.h * 0.72)
    playerSprite = Rect.new(arena.x + arena.w * 0.54,
      arena.y + arena.h * 0.24, arena.w * 0.38, arena.h * 0.72)
  end

  -- The status/sprite order is intentionally diagonal, matching the native
  -- Gen II battle field: enemy card then enemy sprite on the top row, player
  -- sprite then player card on the bottom row. Keep the old orientation
  -- branches above as a conservative fallback for malformed envelopes, then
  -- apply the bounded row geometry used by the responsive composition.
  enemyCard = Rect.new(topRow.x, topRow.y
    + math.max(0, (topRow.h - cardH) / 2), cardW, cardH)
  enemySprite = Rect.new(topRow.x + cardW + columnGap,
    topRow.y + spriteInset, spriteW,
    math.max(1, topRow.h - spriteInset * 2))
  playerSprite = Rect.new(bottomRow.x + spriteInset,
    bottomRow.y + spriteInset, spriteW,
    math.max(1, bottomRow.h - spriteInset * 2))
  playerCard = Rect.new(bottomRow.x + spriteW + columnGap,
    bottomRow.y + math.max(0, (bottomRow.h - cardH) / 2), cardW, cardH)

  local menu, hitRegions = {}, {}
  local menuTop = panel.y + titleH
  local menuBottom = panel.y + panel.h - pad
  if #actions > 0 then
    local cellW = (panel.w - gap * (columns - 1)) / columns
    local cellH = math.max(1,
      (menuBottom - menuTop - gap * (rows - 1)) / rows)
    for index, action in ipairs(actions) do
      local column = (index - 1) % columns
      local row = math.floor((index - 1) / columns)
      local rect = Rect.new(panel.x + column * (cellW + gap),
        menuTop + row * (cellH + gap), cellW, cellH)
      menu[#menu + 1] = { index=index, action=action, rect=rect }
      hitRegions[#hitRegions + 1] = {
        id=tostring(action.id or index), index=index,
        sourceIndex=action.sourceIndex or index,
        rect=Rect.copy(rect), role="battle_action",
      }
    end
  elseif type(model.message) == "string" and model.message ~= "" then
    hitRegions[#hitRegions + 1] = {
      id="advance", index=1, sourceIndex=1,
      rect=Rect.copy(panel), role="battle_advance",
    }
  end

  local messageRegion = Rect.new(panel.x + pad, panel.y + titleH,
    math.max(1, panel.w - pad * 2),
    math.max(1, panel.h - titleH - pad))
  base.inner, base.field, base.hud, base.arena, base.panel =
    inner, field, hud, arena, panel
  base.enemyCard, base.playerCard = enemyCard, playerCard
  base.enemySprite, base.playerSprite = enemySprite, playerSprite
  base.messageRegion = messageRegion
  base.menu, base.hitRegions, base.orientation = menu, hitRegions,
    portrait and "portrait" or "landscape"
  base.scale, base.fontHeight = scale, fontHeight
  base.titleHeight, base.gap = titleH, gap
  base.compactCards = cardH < fontHeight * 2 + gap * 2
  base.overlaps = {
    cardSprite = overlaps(enemyCard, enemySprite)
      or overlaps(enemyCard, playerSprite)
      or overlaps(playerCard, enemySprite)
      or overlaps(playerCard, playerSprite),
  }
  return base
end

return BattleLayout
