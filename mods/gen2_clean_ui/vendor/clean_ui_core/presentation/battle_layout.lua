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
  local moveList = model.phase == "moves" or model.phase == "choose-forget"
    or model.moveList == true
  -- The command menu keeps the native Gen II 2x2 navigation in every
  -- orientation. Move selection is the one intentional exception: four
  -- moves remain a vertical list so the detail panel can stay readable.
  local columns = moveList and 1 or math.min(2, #actions)
  local rows = #actions > 0 and math.ceil(#actions / math.max(1, columns)) or 0
  local titleH = math.max(fontHeight + pad, math.floor(30 * scale + 0.5))
  local menuRowH = math.max(fontHeight + pad,
    math.floor((moveList and 32 or 36) * scale + 0.5))
  local menuH = rows > 0
    and rows * menuRowH + math.max(0, rows - 1) * gap or 0
  local desiredMoveInfoH = moveList and math.max(fontHeight * 3 + pad,
    math.floor(78 * scale + 0.5)) or 0
  local moveContentH
  if moveList and portrait then
    -- Portrait phones do not have enough horizontal room for a readable
    -- detail pane beside a four-row move list. Stack the detail pane above
    -- the list and reserve both regions before splitting the field/panel.
    moveContentH = desiredMoveInfoH + gap + menuH
  else
    moveContentH = math.max(menuH, moveList and desiredMoveInfoH or 0)
  end
  -- Reserve the largest battle panel up front.  The field/HUD must not move
  -- when the player opens the command menu or enters move selection: changing
  -- phases is a state transition, not a reason to resize the battlefield.
  -- Four rows is the Gen II maximum even when a particular Pokémon knows fewer
  -- moves, and the detail pane is reserved in both orientations so the move
  -- screen cannot steal height from the sprites and status cards.
  local commandRowH = math.max(fontHeight + pad,
    math.floor(36 * scale + 0.5))
  local commandMenuH = 2 * commandRowH + gap
  local worstMoveRowH = math.max(fontHeight + pad,
    math.floor(32 * scale + 0.5))
  local worstMoveMenuH = 4 * worstMoveRowH + 3 * gap
  local worstMoveContentH = portrait
    and (desiredMoveInfoH + gap + worstMoveMenuH)
    or math.max(desiredMoveInfoH, worstMoveMenuH)
  local messagePanelH = math.max(titleH + pad * 2,
    fontHeight * 2 + pad * 3)
  local commandPanelH = titleH + pad + commandMenuH + pad
  local movePanelH = titleH + pad + worstMoveContentH + pad
  local panelH = math.max(messagePanelH, commandPanelH, movePanelH)
  -- A very small viewport may be unable to hold the full four-move reserve.
  -- Keep the cap phase-independent there too; the solver can step down the
  -- font as needed, while comfortable viewports retain the invariant height.
  local minimumCard = fontHeight + gap * 2
  local minimumField = minimumCard * 2 + gap
  local panelCap = math.floor(inner.h * (portrait and 0.68 or 0.58))
  panelCap = math.min(panelCap,
    math.max(1, inner.h - gap - minimumField))
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
  -- Keep the row boundary on whole pixels. Fractional row heights can make
  -- the lower card/sprite exceed the field by a floating-point epsilon at
  -- the smallest landscape viewport.
  local fieldRowH = math.max(1, math.floor((field.h - rowGap) / 2))
  local topRow = Rect.new(field.x, field.y, field.w, fieldRowH)
  local bottomRow = Rect.new(field.x, field.y + fieldRowH + rowGap,
    field.w, fieldRowH)
  local columnGap = math.max(gap, math.floor(field.w * 0.05))
  local cardW = math.max(1, math.floor((field.w - columnGap) * 0.46))
  local spriteW = math.max(1, field.w - columnGap - cardW)
  local cardTargetH = model.player and model.player.exp ~= nil and 124 or 100
  local cardH = math.max(fontHeight + gap * 2,
    math.floor(cardTargetH * scale + 0.5))
  cardH = math.min(cardH, math.max(1, fieldRowH))
  local spriteInset = math.max(1, math.floor(gap * 0.35))
  local hud = Rect.copy(field)
  local arena = Rect.copy(field)
  local enemyCard, playerCard, enemySprite, playerSprite
    -- side of the wide arena and the player's active Pokémon owns the
    -- lower-right side. The card and sprite for each side share that anchor.
  -- Both orientations keep the native diagonal: enemy status upper-left and
  -- sprite upper-right, player sprite lower-left and status lower-right.
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
  local contentBottom = panel.y + panel.h - pad
  local moveInfoRegion
  local menuLeft = panel.x + pad
  local menuWidth = math.max(1, panel.w - pad * 2)
  local menuBottom = contentBottom
  if moveList and portrait then
    local available = math.max(1, panel.w - pad * 2)
    local infoH = math.min(desiredMoveInfoH,
      math.max(1, contentBottom - menuTop - gap - math.max(1, menuH)))
    moveInfoRegion = Rect.new(panel.x + pad, menuTop, available,
      math.max(1, infoH))
    menuTop = moveInfoRegion.y + moveInfoRegion.h + gap
    menuLeft = panel.x + pad
    menuWidth = available
  elseif moveList then
    -- Detail on the left, four-row move list on the right in landscape.
    -- Portrait uses the stacked arrangement above so the detail text does
    -- not become a narrow, overlapping column.
    local available = math.max(1, panel.w - pad * 2)
    local splitGap = math.min(gap, math.max(2, math.floor(available * 0.06)))
    local infoW = math.floor((available - splitGap) * 0.42)
    infoW = math.max(1, math.min(infoW, available - splitGap - 1))
    moveInfoRegion = Rect.new(panel.x + pad, menuTop, infoW,
      math.max(1, contentBottom - menuTop))
    menuLeft = moveInfoRegion.x + moveInfoRegion.w + splitGap
    menuWidth = math.max(1, panel.x + panel.w - pad - menuLeft)
  end
  if #actions > 0 then
    local cellW = (menuWidth - gap * (columns - 1)) / columns
    local cellH = math.max(1,
      (menuBottom - menuTop - gap * (rows - 1)) / rows)
    for index, action in ipairs(actions) do
      local column = (index - 1) % columns
      local row = math.floor((index - 1) / columns)
      local rect = Rect.new(menuLeft + column * (cellW + gap),
        menuTop + row * (cellH + gap), cellW, cellH)
      menu[#menu + 1] = { index=index, action=action, rect=rect }
      hitRegions[#hitRegions + 1] = {
        id=tostring(action.id or index), index=index,
        sourceIndex=action.sourceIndex or index,
        rect=Rect.copy(rect), role="battle_action",
      }
    end
  elseif not model.animation and type(model.message) == "string"
      and model.message ~= "" then
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
  base.moveInfoRegion = moveInfoRegion
  base.menuRegion = Rect.new(menuLeft, menuTop, menuWidth,
    math.max(1, menuBottom - menuTop))
  base.moveList = moveList
  base.menuColumns = columns
  base.menu, base.hitRegions, base.orientation = menu, hitRegions,
    portrait and "portrait" or "landscape"
  base.scale, base.fontHeight = scale, fontHeight
  base.titleHeight, base.gap = titleH, gap
  base.hudStable = true
  base.stablePanelHeight = panelH
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
