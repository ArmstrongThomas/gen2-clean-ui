local requireCore = ...
local Rect = requireCore("geometry.rect")
local List = requireCore("layout.list")
local Details = requireCore("layout.details")

local MenuLayout = {}

local function inset(rect, amount)
  return Rect.inset(rect, { x = amount })
end

local function textWidth(font, value)
  local text = tostring(value or "")
  if font and type(font.getWidth) == "function" then
    local ok, width = pcall(font.getWidth, font, text)
    if ok and type(width) == "number" then return width end
  end
  return #text * math.max(1, (font:getHeight() or 15) * 0.6)
end

local function fontPixelHeight(font)
  if font and type(font.getHeight) == "function" then
    local ok, height = pcall(font.getHeight, font)
    if ok and type(height) == "number" and height > 0 then
      return math.max(1, math.floor(height + 0.5))
    end
  end
  return 1
end

local function fixedBadgeWidth(font, scale, exemplar, minimum)
  local pad = math.max(4, math.floor(6 * scale))
  return math.max(tonumber(minimum) or 0,
    textWidth(font, exemplar) + pad * 2)
end

local function knownGender(value)
  value = tostring(value or ""):lower()
  return value == "female" or value == "f"
    or value == "male" or value == "m"
    or value == "none" or value == "genderless"
    or value == "no_gender" or value == "no-gender"
    or value == "nogender" or value == "no gender"
    or value == "unknown"
end

local function mapMarkers(region, model, scale)
  local map = type(model) == "table"
    and (model.mapCanvas or model.map) or nil
  local rows = type(map) == "table" and map.rows or nil
  if type(rows) ~= "table" or #rows == 0 then return {} end
  local minX, maxX, minY, maxY
  for _, row in ipairs(rows) do
    local x, y = tonumber(row.x), tonumber(row.y)
    if x and y then
      minX, maxX = minX and math.min(minX, x) or x,
        maxX and math.max(maxX, x) or x
      minY, maxY = minY and math.min(minY, y) or y,
        maxY and math.max(maxY, y) or y
    end
  end
  if not (minX and maxX and minY and maxY) then return {} end
  local worldW, worldH = math.max(1, maxX - minX), math.max(1, maxY - minY)
  local marker = math.max(6, math.floor(10 * scale))
  local out = {}
  for index, row in ipairs(rows) do
    local x, y = tonumber(row.x), tonumber(row.y)
    if x and y then
      local px = region.x + (x - minX) / worldW * region.w
      local py = region.y + (maxY - y) / worldH * region.h
      out[#out + 1] = {
        index=index, landmarkIndex=tonumber(row.index) or index,
        name=row.name, selected=row.selected == true,
        nest=row.nest == true,
        player=type(map.player) == "table"
          and tonumber(map.player.index) == tonumber(row.index),
        current=type(map.current) == "table"
          and tonumber(map.current.index) == tonumber(row.index),
        x=px, y=py, rect={
          x=math.max(region.x, math.min(region.x + region.w - marker, px - marker * 0.5)),
          y=math.max(region.y, math.min(region.y + region.h - marker, py - marker * 0.5)),
          w=marker, h=marker,
        },
      }
    end
  end
  return out
end

local function shellGeometry(body, font, scale)
  local pad = math.max(8, math.floor(14 * scale))
  local availableW = math.max(1, body.w - pad * 2)
  local availableH = math.max(1, body.h - pad * 2)
  -- The Pokegear is a handheld device, but the clean UI must not force its
  -- portrait silhouette into a landscape viewport. Choose the device
  -- orientation from the available safe area and preserve a phone-like
  -- aspect ratio in either direction.
  local landscape = availableW >= availableH * 1.15
  local aspectW, aspectH = landscape and 16 or 9, landscape and 9 or 16
  local deviceW = math.min(availableW,
    math.floor(availableH * aspectW / aspectH))
  local deviceH = math.min(availableH,
    math.floor(deviceW * aspectH / aspectW))
  if deviceW < 1 or deviceH < 1 then
    deviceW, deviceH = availableW, availableH
  end
  local device = Rect.new(body.x + (body.w - deviceW) / 2,
    body.y + (body.h - deviceH) / 2, deviceW, deviceH)
  local chrome = math.max(5, math.floor(8 * scale))
  local screen = Rect.inset(device, { x=chrome, y=chrome })
  local statusH = math.max(font:getHeight() + math.floor(8 * scale),
    math.floor(28 * scale))
  local railH = math.max(font:getHeight() * 2 + math.floor(10 * scale),
    math.floor(54 * scale))
  local status = Rect.new(screen.x, screen.y, screen.w,
    math.min(screen.h, statusH))
  local rail = Rect.new(screen.x, screen.y + screen.h - math.min(screen.h,
    railH), screen.w, math.min(screen.h, railH))
  local content = Rect.new(screen.x, status.y + status.h, screen.w,
    math.max(1, rail.y - (status.y + status.h)))
  return {
    device=device, screen=screen, status=status, content=content, rail=rail,
    orientation=landscape and "landscape" or "portrait", scale=scale,
  }
end

local function namingGeometry(region, model, font, scale, pad)
  local naming = model.naming or {}
  local keyboard = naming.keyboard or {}
  local rows = keyboard.rows or {}
  local columns = math.max(1, tonumber(keyboard.columns) or 9)
  local gap = math.max(3, math.floor(4 * scale))
  local innerPad = math.max(6, math.floor(8 * scale))
  local slotHeight = math.max(font:getHeight() + innerPad,
    math.floor(28 * scale))
  local entryH = math.max(font:getHeight() + slotHeight
      + math.floor(8 * scale),
    math.floor(54 * scale))
  local entry = Rect.new(region.x + innerPad, region.y + innerPad,
    math.max(1, region.w - innerPad * 2), entryH)
  local gridY = entry.y + entry.h + pad
  local grid = Rect.new(region.x + innerPad, gridY,
    math.max(1, region.w - innerPad * 2),
    math.max(1, region.y + region.h - gridY - innerPad))
  local totalRows = #rows + 1 -- the source-owned CASE/DEL/END row
  local rowGap = math.max(3, math.floor(5 * scale))
  local rowHeight = math.max(font:getHeight() + math.floor(8 * scale),
    (grid.h - math.max(0, totalRows - 1) * rowGap) / totalRows)
  local cellWidth = math.max(1,
    (grid.w - math.max(0, columns - 1) * gap) / columns)
  local cells = {}
  for rowIndex, row in ipairs(rows) do
    local count = #row
    local fullRow = count == 1
    for colIndex, value in ipairs(row) do
      local width = fullRow and grid.w or cellWidth
      local x = fullRow and grid.x
        or grid.x + (colIndex - 1) * (cellWidth + gap)
      local y = grid.y + (rowIndex - 1) * (rowHeight + rowGap)
      cells[#cells + 1] = {
        kind = "key", row = rowIndex - 1, col = colIndex - 1,
        value = value, rect = Rect.new(x, y, width, rowHeight),
      }
    end
  end
  local bottomY = grid.y + (#rows) * (rowHeight + rowGap)
  local bottom = {}
  for index, target in ipairs(keyboard.bottom or {}) do
    local width = (grid.w - 2 * gap) / 3
    bottom[#bottom + 1] = {
      kind = "bottom", index = index, value = target.label,
      rect = Rect.new(grid.x + (index - 1) * (width + gap), bottomY,
        width, rowHeight),
    }
  end
  for _, item in ipairs(bottom) do cells[#cells + 1] = item end
  return {
    region = region, entry = entry, grid = grid, cells = cells,
    rowHeight = rowHeight, gap = gap, columns = columns,
    maxLength = tonumber(naming.entry and naming.entry.maxLength) or 10,
    text = tostring(naming.entry and naming.entry.text or ""),
    glyphs = type(naming.entry and naming.entry.glyphs) == "table"
      and naming.entry.glyphs or nil,
    sourceLength = tonumber(naming.entry and naming.entry.sourceLength),
    cursor = naming.cursor or {},
  }
end

local function partyListGeometry(region, rows, model, font, scale, pad,
    fontStep)
  local visible = {}
  for index, row in ipairs(rows or {}) do
    -- Native adapters may expose a trailing CANCEL/BACK source boundary, but
    -- the Clean party surface uses the fixed six-slot list and B for
    -- returning. Keep this defensive filter for older snapshots.
    if type(row) == "table" and row.kind ~= "back" then
      visible[#visible + 1] = { index=index, row=row }
    end
  end
  -- Keep the party surface a six-slot composition even when the source party
  -- is only partially filled.  A variable row count makes a four-Pokemon
  -- party stretch across the entire envelope and leaves the 1x pixel font
  -- floating in excessive whitespace.
  local slotCount = math.max(6, #visible)
  local gap = math.max(1, math.floor(2 * scale))
  local rowHeight = math.max(1, math.floor((region.h
    - math.max(0, slotCount - 1) * gap) / math.max(1, slotCount)))
  local innerGap = math.max(5, math.floor(8 * scale))
  -- The authored gender sheet is 16px tall, but OpenTTD Mono is 10px at 1x.
  -- Match the selected font's actual pixel height so the asset does not read
  -- as a larger glyph, while still growing with the selected font step.
  local genderIconSize = fontPixelHeight(font)
  local badgeGap = math.max(2, math.floor(4 * scale))
  local typeBadgeWidth = fixedBadgeWidth(font, scale, "ELECTRIC",
    math.floor(30 * scale))
  local statusWidth = fixedBadgeWidth(font, scale, "FNT",
    math.floor(52 * scale))
  local typeWidth = typeBadgeWidth * 2 + badgeGap
  local levelWidth = math.max(math.floor(42 * scale),
    textWidth(font, "Lv.99") + innerGap)
  local maxNameWidth, maxHpWidth = 0, 0
  for _, item in ipairs(visible) do
    local row = item.row or {}
    if row.kind ~= "empty" then
      local label = tostring(row.label or (row.isEgg and "EGG" or "POKEMON"))
      local genderWidth = knownGender(row.gender) and genderIconSize or 0
      maxNameWidth = math.max(maxNameWidth, textWidth(font, label)
        + genderWidth + (genderWidth > 0 and 4 or 0))
      levelWidth = math.max(levelWidth,
        textWidth(font, ("Lv.%s"):format(tostring(row.level or "--")))
          + innerGap)
      if not row.isEgg and row.hp ~= nil and row.maxHp ~= nil then
        local hpLabel = ("%d / %d"):format(tonumber(row.hp) or 0,
          tonumber(row.maxHp) or 0)
        maxHpWidth = math.max(maxHpWidth, textWidth(font, "hp ")
          + math.floor(3 * scale) + 14 + textWidth(font, hpLabel)
          + math.floor(4 * scale))
      end
    end
  end
  local hpWidth = math.max(math.floor(128 * scale), maxHpWidth,
    math.floor(76 * scale))
  local measured, hitRegions = {}, {}
  for slot = 1, slotCount do
    local item = visible[slot]
    local y = region.y + (slot - 1) * (rowHeight + gap)
    local rect = Rect.new(region.x, y, region.w,
      math.min(rowHeight, region.y + region.h - y))
    local row = item and item.row or {
      kind="empty", disabled=true, slot=slot,
    }
    measured[#measured + 1] = {
      index=item and item.index or nil, row=row, rect=rect,
    }
    if item and row.disabled ~= true then
      hitRegions[#hitRegions + 1] = {
        id=tostring(row.id or item.index), index=item.index,
        sourceIndex=row.sourceIndex or item.index,
        rect=Rect.copy(rect), role="menu_row",
      }
    end
  end
  local identityX = region.x + innerGap + math.min(
    math.max(1, rowHeight - innerGap * 2), math.floor(34 * scale)) + innerGap
  local rightX = region.x + region.w - innerGap - typeWidth
  local statusX = rightX - innerGap - statusWidth
  local hpX = statusX - innerGap - hpWidth
  local levelX = hpX - innerGap - levelWidth
  local nameWidth = math.max(1, levelX - identityX - innerGap)
  local textFits = rowHeight >= genderIconSize + innerGap * 2
    and maxNameWidth <= nameWidth and maxHpWidth <= hpWidth
  return {
    region=Rect.copy(region), rows=measured, hitRegions=hitRegions,
    rowHeight=rowHeight, visible=slotCount, gap=gap,
    columns={
      gap=innerGap, pokemonIconSize=math.min(
        math.max(1, rowHeight - innerGap * 2), math.floor(34 * scale)),
      genderIconSize=genderIconSize, statusWidth=statusWidth,
      typeWidth=typeWidth, typeBadgeWidth=typeBadgeWidth,
      hpWidth=hpWidth, levelWidth=levelWidth, nameWidth=nameWidth,
      textFits=textFits,
    },
    textFits=textFits,
  }
end

local function tabGeometry(header, model, font, scale, pad)
  local tabs = model.pageTabs or {}
  local gap = math.max(2, math.floor(5 * scale))
  local tabPad = math.max(5, math.floor(8 * scale))
  local height = math.max(font:getHeight() + math.floor(8 * scale),
    math.floor(28 * scale))
  local widths, total = {}, 0
  for index, tab in ipairs(tabs) do
    local width = math.max(math.floor(36 * scale),
      font:getWidth(tab.label or tab.id or "TAB") + tabPad * 2)
    widths[index] = width
    total = total + width + (index > 1 and gap or 0)
  end
  local x = header.x + header.w - total
  local y = header.y + math.max(0, (header.h - height) / 2)
  local measured, hitRegions = {}, {}
  for index, tab in ipairs(tabs) do
    local rect = Rect.new(x, y, widths[index], height)
    measured[#measured + 1] = { index=index, tab=tab, rect=rect }
    hitRegions[#hitRegions + 1] = {
      id=tostring(tab.id or index), index=index,
      sourcePage=tab.sourcePage, tabId=tab.id,
      rect=Rect.copy(rect), role="party_tab",
    }
    x = x + widths[index] + gap
  end
  return measured, hitRegions
end

local function summaryGeometry(region, model, font, scale, pad, fontStep)
  local gap = math.max(6, math.floor(10 * scale))
  local inner = Rect.inset(region, { x=pad, y=pad })
  -- The identity rail can show a nickname, species caption, type chips, and
  -- two independent progress bars. Keep enough vertical room for all of
  -- those runs without letting the lower page content collapse.
  local identityMinimum = font:getHeight() * 4 + gap * 3
  local identityHeight = math.max(identityMinimum,
    math.min(math.floor(inner.h * 0.31), math.floor(210 * scale)))
  identityHeight = math.min(inner.h, identityHeight)
  local portraitWidth = math.min(math.floor(inner.w * 0.30),
    math.max(font:getHeight() * 4, identityHeight))
  local portrait = Rect.new(inner.x, inner.y, portraitWidth,
    math.max(1, identityHeight))
  local info = Rect.new(portrait.x + portrait.w + gap, inner.y,
    math.max(1, inner.x + inner.w - (portrait.x + portrait.w + gap)),
    identityHeight)
  local output = {
    region=Rect.copy(region), inner=inner, portrait=portrait, info=info,
    identity=Rect.copy(inner), moveRows={}, moveInfo=nil,
    genderIconSize=fontPixelHeight(font),
    typeBadgeWidth=fixedBadgeWidth(font, scale, "ELECTRIC",
      math.floor(30 * scale)),
    statusBadgeWidth=fixedBadgeWidth(font, scale, "FNT",
      math.floor(52 * scale)),
  }
  local genderWidth = knownGender(model.summary and model.summary.pokemon
    and model.summary.pokemon.gender) and output.genderIconSize or 0
  local name = tostring(model.summary and model.summary.pokemon
    and model.summary.pokemon.name or "POKEMON")
  local level = ("Lv.%s"):format(tostring(model.summary
    and model.summary.pokemon and model.summary.pokemon.level or "--"))
  local identityGap = math.max(3, math.floor(4 * scale))
  local nameAvailable = math.max(1, info.w - math.floor(16 * scale)
    - textWidth(font, level) - gap)
  local typeCount = model.summary and model.summary.status
    and #(model.summary.status.types or {}) or 0
  local typeX = info.x + math.floor(8 * scale) + genderWidth
    + (genderWidth > 0 and math.max(3, math.floor(8 * scale)) or 0)
  local typeRequired = typeCount > 0
    and typeCount * output.typeBadgeWidth
      + math.max(0, typeCount - 1) * math.max(2, math.floor(4 * scale)) or 0
  output.textFits = textWidth(font, name) + genderWidth
      + (genderWidth > 0 and identityGap or 0) <= nameAvailable
    and typeX + typeRequired <= info.x + info.w - math.floor(8 * scale)
    and textWidth(font, "HEALTHY") <= info.w - math.floor(16 * scale)
  if model.purpose == "moves" or model.mode == "move_reorder" then
    local moveY = inner.y + identityHeight + gap
    local remaining = math.max(1, inner.y + inner.h - moveY)
    local moveInfoHeight = math.min(math.max(font:getHeight() * 3 + gap,
      math.floor(remaining * 0.34)), remaining)
    local moveListHeight = math.max(1, remaining - moveInfoHeight - gap)
    local moveList = Rect.new(inner.x, moveY, inner.w, moveListHeight)
    local moveInfo = Rect.new(inner.x, moveList.y + moveList.h + gap,
      inner.w, moveInfoHeight)
    local rowGap = math.max(1, math.floor(2 * scale))
    local rows = model.rows or {}
    local rowHeight = math.max(1, math.floor((moveList.h
      - math.max(0, #rows - 1) * rowGap) / math.max(1, #rows)))
    for index, row in ipairs(rows) do
      local y = moveList.y + (index - 1) * (rowHeight + rowGap)
      output.moveRows[#output.moveRows + 1] = {
        index=index, row=row,
        rect=Rect.new(moveList.x, y, moveList.w,
          math.min(rowHeight, moveList.y + moveList.h - y)),
      }
    end
    output.moveList, output.moveInfo = moveList, moveInfo
  else
    output.content = Rect.new(inner.x, inner.y + identityHeight + gap,
      inner.w, math.max(1, inner.y + inner.h
        - (inner.y + identityHeight + gap)))
  end
  return output
end

local function modalGeometry(bounds, model, font, scale, pad, rowHeight)
  if not model.modal then return nil, {} end
  local frame = math.max(2, math.floor(2 * scale + 0.5))
  local optionCount = #(model.modal.options or {})
  local compact = model.modal.compact == true
  local title = model.modal.title or model.modal.message or "CHOOSE"
  local mw
  if compact then
    -- Action menus are short, single-purpose overlays. Size them from the
    -- actual labels instead of borrowing the wide-screen modal width used by
    -- long descriptions and child panels.
    local required = textWidth(font, title) * 1.5
    for _, option in ipairs(model.modal.options or {}) do
      required = math.max(required, textWidth(font,
        type(option) == "table" and option.label or option))
    end
    required = required + pad * 4 + math.floor(20 * scale)
    mw = math.min(bounds.w, math.max(math.floor(260 * scale),
      math.ceil(required)))
  else
    mw = math.min(bounds.w, math.max(math.floor(280 * scale),
      math.floor(bounds.w * 0.82)))
  end
  local modalRowHeight = compact
    and math.max(font:getHeight() + math.floor(4 * scale),
      math.floor(36 * scale)) or rowHeight
  local minimumHeight = compact and math.floor(96 * scale)
    or math.floor(190 * scale)
  local contentHeight = (compact and font:getHeight() * 2
      or font:getHeight() * 3)
    + (compact and pad * 3 or pad * 4)
    + optionCount * modalRowHeight
  local mh = math.min(bounds.h, math.max(minimumHeight, contentHeight))
  local rect = Rect.new(bounds.x + (bounds.w - mw) / 2,
    bounds.y + (bounds.h - mh) / 2, mw, mh)
  local modalInner = inset(rect, frame + pad)
  local top = math.max(font:getHeight() + math.floor(pad * 0.5),
    math.floor((compact and 32 or 48) * scale))
  local optionsRegion = Rect.new(modalInner.x, modalInner.y + top,
    modalInner.w, math.max(0, modalInner.h - top))
  local optionList = List.measure(optionsRegion, optionCount, modalRowHeight,
    model.modal.selected, model.modal.scroll)
  local optionRows, hitRegions = {}, {}
  for _, optionRow in ipairs(optionList.rows) do
    local option = model.modal.options[optionRow.index]
    optionRows[#optionRows + 1] = {
      index=optionRow.index, option=option, rect=optionRow.rect,
    }
    if option and not option.disabled then
      hitRegions[#hitRegions + 1] = {
        id=tostring(option.id or optionRow.index), index=optionRow.index,
        rect=Rect.copy(optionRow.rect), role="modal_option",
      }
    end
  end
  return {
    rect=rect, inner=modalInner, options=optionRows,
    selected=model.modal.selected, titleHeight=top,
    scroll=optionList.offset, visible=optionList.visible,
  }, hitRegions
end

function MenuLayout.contentWidth(base, model, font, density)
  if type(base) ~= "table" or base.widthMode ~= "content"
      or type(model) ~= "table" then return nil end
  local scale = base.scale or 1
  local compact = density == "compact"
  local pad = math.max(8, math.floor((compact and 10 or 14) * scale))
  local frame = math.max(2, math.floor(2 * scale + 0.5))
  local gap = math.max(8, math.floor(10 * scale))
  local required = textWidth(font, model.title)
  local description = model.description or model.controls
  if type(description) == "table" then description = table.concat(description, " ") end
  required = math.max(required, textWidth(font, description))
  for _, row in ipairs(model.rows or {}) do
    local right = tostring(row.right or row.valueLabel or "")
    local rightWidth = right ~= "" and textWidth(font, right) or 0
    local pinReserve = row.pinnable
      and math.max(44, math.floor(72 * scale)) or 0
    required = math.max(required,
      textWidth(font, row.label) + rightWidth + pinReserve + gap * 3,
      rightWidth / 0.45 + pinReserve + gap * 3)
  end
  local listRequired = required
  local details = model.details
  local richDetails = type(details) == "table"
    and (details.fields or details.custom_fields
      or details.footer_lists or details.sprite or details.bars
      or details.typeBadges)
  -- Rich details and sprites have an explicit information-density contract;
  -- keep the preset width for those screens. Plain label/value details can
  -- participate in content sizing, with enough room for both columns.
  if richDetails then return base.logical.w end
  if type(details) == "table" and #details > 0 then
    local detailRequired = 0
    for _, field in ipairs(details) do
      if type(field) == "table" then
        local labelWidth = textWidth(font, field.label)
        local valueWidth = textWidth(font, field.value)
        detailRequired = math.max(detailRequired,
          labelWidth / 0.42, valueWidth / 0.50,
          labelWidth + valueWidth + gap * 2)
      end
    end
    if detailRequired > 0 then
      -- Plain details render in a right-hand column that occupies 42% of
      -- the body. Account for that column and the list column together so
      -- labels and values are measured against the layout they actually use.
      local detailPanel = math.ceil(detailRequired / 0.42)
      required = math.max(listRequired, listRequired + gap + detailPanel)
    end
  end
  local logical = math.ceil((required + 2 * (frame + pad)) / scale)
  local minimum = tonumber(base.minW) or 320
  local maximum = tonumber(base.logical and base.logical.w) or 440
  return math.max(minimum, math.min(maximum, logical))
end

function MenuLayout.measure(base, model, font, density)
  local scale = base.scale or 1
  local compact = density == "compact"
  local pad = math.max(8, math.floor((compact and 10 or 14) * scale))
  local frame = math.max(2, math.floor(2 * scale + 0.5))
  local inner = inset(base.outer, frame + pad)
  local titleHeight = math.max(font:getHeight() + pad,
    math.floor((compact and 40 or 50) * scale))
  local footerLines = model.description and 2 or 1
  local footerHeight = math.max(font:getHeight() * footerLines + pad,
    math.floor((compact and 38 or 48) * scale))
  local header = Rect.new(inner.x, inner.y, inner.w, titleHeight)
  local footer = Rect.new(inner.x, inner.y + inner.h - footerHeight,
    inner.w, footerHeight)
  local body = Rect.new(inner.x, header.y + header.h, inner.w,
    math.max(0, footer.y - header.y - header.h))
  local fontStep = base.font and tonumber(base.font.step) or 1
  local partyList = model.partyLayout == "list"
    and partyListGeometry(body, model.rows or {}, model, font, scale, pad,
      fontStep)
    or nil
  local partySummary = model.partyLayout == "summary"
    and summaryGeometry(body, model, font, scale, pad, fontStep) or nil
  local tabs, tabHitRegions
  if partySummary then
    tabs, tabHitRegions = tabGeometry(header, model, font, scale, pad)
  end
  if partyList or partySummary then
    base.inner, base.header, base.body, base.footer = inner, header, body, footer
    base.shell = nil
    base.listRegion = body
    base.detailRegion = nil
    base.naming = nil
    base.mapView, base.mapRegion, base.mapMarkers = false, body, nil
    base.details = nil
    base.partyList = partyList
    base.summary = partySummary
    base.tabs = tabs
    base.rows = partyList and partyList.rows or {}
    base.rowHeight = partyList and partyList.rowHeight or nil
    base.scroll = 0
    base.visibleRows = partyList and partyList.visible or 0
    base.hitRegions = {}
    if partyList then
      for _, region in ipairs(partyList.hitRegions) do
        base.hitRegions[#base.hitRegions + 1] = region
      end
    end
    for _, region in ipairs(tabHitRegions or {}) do
      base.hitRegions[#base.hitRegions + 1] = region
    end
    local modal, modalHitRegions = modalGeometry(inner, model, font, scale,
      pad, partyList and partyList.rowHeight
        or math.max(font:getHeight() + pad, math.floor(48 * scale)))
    for _, region in ipairs(modalHitRegions) do
      base.hitRegions[#base.hitRegions + 1] = region
    end
    base.modal = modal
    return base
  end
  local shell = (model.appShell or model.kind == "device")
    and shellGeometry(body, font, scale) or nil
  local namingScreen = type(model.naming) == "table"
    and type(model.naming.keyboard) == "table"
    and type(model.naming.keyboard.rows) == "table"
  local richDetails = type(model.details) == "table"
    and (model.details.fields or model.details.custom_fields
      or model.details.footer_lists or model.details.sprite
      or model.details.bars or model.details.typeBadges)
  local hasDetails = richDetails or (type(model.details) == "table"
    and #model.details > 0)
  local detailWidth = (model.appShell or model.kind == "device"
    or namingScreen) and 0 or (hasDetails
    and math.min(math.floor(body.w * 0.42), math.floor(250 * scale)) or 0
  )
  local gap = detailWidth > 0 and pad or 0
  local listRegion = shell and Rect.copy(shell.content) or Rect.new(body.x, body.y,
    math.max(0, body.w - detailWidth - gap), body.h)
  local mapRegion = listRegion
  if shell and model.flyView == true then
    -- Fly keeps the destination list interactive, so give it a dedicated
    -- lower panel instead of painting the list over the native map.
    local splitGap = math.max(6, math.floor(8 * scale))
    local mapHeight = math.max(font:getHeight() * 5,
      math.floor(shell.content.h * 0.58))
    mapHeight = math.min(shell.content.h,
      math.max(1, mapHeight - splitGap))
    mapRegion = Rect.new(shell.content.x, shell.content.y,
      shell.content.w, mapHeight)
    listRegion = Rect.new(shell.content.x, mapRegion.y + mapRegion.h
      + splitGap, shell.content.w,
      math.max(1, shell.content.y + shell.content.h
        - (mapRegion.y + mapRegion.h + splitGap)))
    shell.map = Rect.copy(mapRegion)
    shell.list = Rect.copy(listRegion)
  end
  local detailRegion = detailWidth > 0 and Rect.new(
    body.x + body.w - detailWidth, body.y, detailWidth, body.h) or nil
  local rows = model.rows or {}
  local hasRowBars = model.rowBars == true
  if not hasRowBars then
    for _, row in ipairs(rows) do
      if type(row) == "table" and row.bar ~= nil then
        hasRowBars = true
        break
      end
    end
  end
  local rowHeight = math.max(font:getHeight() + pad,
    math.floor((hasRowBars and (compact and 56 or 64)
      or (compact and 40 or 48)) * scale))
  local list = List.measure(listRegion, #rows, rowHeight,
    model.selected, model.scroll)
  local measured = {}
  local hitRegions = {}
  for _, row in ipairs(list.rows) do
    local source = rows[row.index]
    measured[#measured + 1] = {
      index = row.index, row = source, rect = row.rect,
    }
    if source and source.disabled ~= true and not namingScreen
        and (not model.mapView or model.flyView == true) then
      hitRegions[#hitRegions + 1] = {
        id = tostring(source.id or row.index), index = row.index,
        sourceIndex = source.sourceIndex or row.index,
        rect = Rect.copy(row.rect), role = "menu_row",
      }
    end
  end
  local mapView = model.mapView == true or model.kind == "map"
  local markers = mapView and mapMarkers(mapRegion, model, scale) or nil
  if markers then
    for _, marker in ipairs(markers) do
      hitRegions[#hitRegions + 1] = {
        id="map." .. tostring(marker.landmarkIndex),
        index=marker.index, sourceIndex=marker.landmarkIndex,
        rect=Rect.copy(marker.rect), role="map_marker",
      }
    end
  end
  local modal
  if model.modal then
    local modalBounds = shell and shell.screen or inner
    local mw = math.min(modalBounds.w, math.max(math.floor(280 * scale),
      math.floor(modalBounds.w * 0.82)))
    local optionCount = #(model.modal.options or {})
    local mh = math.min(modalBounds.h, math.max(math.floor(190 * scale),
      font:getHeight() * 3 + pad * 4 + optionCount * rowHeight))
    local rect = Rect.new(modalBounds.x + (modalBounds.w - mw) / 2,
      modalBounds.y + (modalBounds.h - mh) / 2, mw, mh)
    local modalInner = inset(rect, frame + pad)
    local top = math.max(font:getHeight() + pad,
      math.floor(48 * scale))
    local optionsRegion = Rect.new(modalInner.x, modalInner.y + top,
      modalInner.w, math.max(0, modalInner.h - top))
    local optionList = List.measure(optionsRegion, optionCount, rowHeight,
      model.modal.selected, model.modal.scroll)
    local optionRows = {}
    for _, optionRow in ipairs(optionList.rows) do
      local option = model.modal.options[optionRow.index]
      optionRows[#optionRows + 1] = {
        index=optionRow.index, option=option, rect=optionRow.rect,
      }
      if option and not option.disabled then
        hitRegions[#hitRegions + 1] = {
          id=tostring(option.id or optionRow.index), index=optionRow.index,
          rect=Rect.copy(optionRow.rect), role="modal_option",
        }
      end
    end
    modal = { rect=rect, inner=modalInner, options=optionRows,
      selected=model.modal.selected, titleHeight=top,
      scroll=optionList.offset, visible=optionList.visible }
  end
  base.inner, base.header, base.body, base.footer = inner, header, body, footer
  base.shell = shell
  base.listRegion, base.detailRegion = listRegion, detailRegion
  base.naming = namingScreen
    and namingGeometry(listRegion, model, font, scale, pad) or nil
  base.mapView, base.mapRegion, base.mapMarkers = mapView, mapRegion, markers
  if richDetails and detailRegion then
    base.details = Details.measure(detailRegion, model.details, {
      gap=math.max(6, math.floor(8 * scale)),
      lineHeight=font:getHeight() + math.max(3, math.floor(4 * scale)),
      minimumCellWidth=math.max(72, math.floor(92 * scale)),
    })
  end
  base.rows, base.rowHeight = measured, rowHeight
  base.scroll, base.visibleRows = list.offset, list.visible
  base.hitRegions, base.modal = hitRegions, modal
  return base
end

-- The shared solver chooses a base policy for the frame.  Horizontal text is
-- intentionally not part of this predicate: each renderer resolves its own
-- constrained text run through layout.textRun, so one long translation or
-- footer cannot shrink unrelated text on the same screen.
function MenuLayout.fits(base, model, font, density)
  if type(base) ~= "table" or type(model) ~= "table" then return false end
  local measured = MenuLayout.measure(base, model, font, density)
  if type(measured) ~= "table" then return false end
  return true
end

return MenuLayout
