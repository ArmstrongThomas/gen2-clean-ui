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
    sourceLength = tonumber(naming.entry and naming.entry.sourceLength),
    cursor = naming.cursor or {},
  }
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

return MenuLayout
