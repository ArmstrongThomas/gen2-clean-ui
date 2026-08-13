return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.service_common")
  local Pack = ctx.load("adapters.pack")
  local Mart = {}

  local SCREEN_ID = "Gen2MartMenu"
  local MART_TYPES = {
    STANDARD=true, BITTER=true, BARGAIN=true, PHARMACY=true,
  }
  local PHASES = {
    top=true, intro=true, outro=true, buy=true, buyQuantity=true,
    sell=true, sellQuantity=true,
  }

  local function itemDefinition(state, itemId)
    local items = rawget(state, "items")
    local definition = type(items) == "table" and rawget(items, itemId) or nil
    return type(definition) == "table" and definition or nil
  end

  local function moveDefinition(state, moveId)
    local data = Common.gameData(state)
    local moves = rawget(data, "moves")
    local definition = type(moves) == "table" and rawget(moves, moveId) or nil
    return type(definition) == "table" and definition or nil
  end

  local function entrySnapshot(state, source, sourceIndex)
    if type(source) ~= "table" then
      return Common.fail("shape_type", "entries[" .. sourceIndex .. "]:table")
    end
    local itemId, code, detail = Common.requiredText(rawget(source, "id"),
      "entries[" .. sourceIndex .. "].id")
    if not itemId then return nil, code, detail end
    local price = Common.integer(rawget(source, "price"), 0, 999999)
    if price == nil then
      return Common.fail("shape_range", "entries[" .. sourceIndex .. "].price")
    end
    local definition = itemDefinition(state, itemId)
    local moveId = definition and rawget(definition, "teaches") or nil
    local move = moveDefinition(state, moveId)
    return {
      id=itemId,
      sourceIndex=sourceIndex,
      name=Data.text(rawget(source, "name"),
        Data.text(definition and rawget(definition, "name"), itemId)),
      price=price,
      soldOut=rawget(source, "soldOut") == true,
      description=Data.text(move and rawget(move, "description")
        or (definition and rawget(definition, "description")), ""),
    }
  end

  local function entries(state)
    local source = rawget(state, "entries")
    local count, code, detail = Common.array(source, 0, 128, "entries")
    if not count then return nil, code, detail end
    local output = {}
    for index = 1, count do
      local row
      row, code, detail = entrySnapshot(state, rawget(source, index), index)
      if not row then return nil, code, detail end
      output[index] = row
    end
    return output
  end

  local function selectedItem(state, output)
    local index = Common.integer(rawget(state, "index"), 1, #output + 1)
    if not index then return Common.fail("shape_range", "index") end
    return output[index], index
  end

  local function quantity(state)
    local source = rawget(state, "qtyItem")
    if type(source) ~= "table" then
      return Common.fail("shape_type", "qtyItem:table")
    end
    local row, code, detail = entrySnapshot(state, source, 1)
    if not row then return nil, code, detail end
    row.sourceIndex = nil
    local value = Common.integer(rawget(state, "qty"), 1, 99)
    local maximum = Common.integer(rawget(state, "qtyMax"), 1, 99)
    if not value or not maximum or value > maximum then
      return Common.fail("shape_range", "quantity")
    end
    return {
      item=row, value=value, maximum=maximum,
      total=math.floor(row.price * value),
    }
  end

  local function nestedPack(state, context)
    local pack = rawget(state, "pack")
    if type(pack) ~= "table" then
      return Common.fail("nested_child_invalid", "pack")
    end
    if rawget(pack, "screenId") ~= "Gen2PackMenu" then
      return Common.fail("nested_child_invalid", "pack.screenId")
    end
    if Common.inBattle(context) or rawget(pack, "battle") == true then
      return Common.fail("battle_owned", "Gen2PackMenu")
    end
    local bundle, code, detail = Pack.extract(pack, context)
    if type(bundle) ~= "table" or type(bundle.model) ~= "table" then
      return Common.fail(code or "nested_child_invalid", detail or "pack")
    end
    if bundle.model.battleOwned then
      return Common.fail("battle_owned", "Gen2PackMenu")
    end
    local copied = Data.copy(bundle.model, { maxDepth=16, maxEntries=4096 })
    if type(copied) ~= "table" or not Data.isFunctionFree(copied) then
      return Common.fail("nested_child_invalid", "pack.model")
    end
    return copied
  end

  local function topRows(state, actions)
    local selected = Common.integer(rawget(state, "topIndex"), 1, 3)
    if not selected then return Common.fail("shape_range", "topIndex") end
    local labels = { "BUY", "SELL", "QUIT" }
    local output = {}
    for index, label in ipairs(labels) do
      output[index] = {
        id=label:lower(), sourceIndex=index, label=label,
        selected=index == selected,
        actionId=Common.sourceInput(actions, "top.choose." .. index,
          "choose", label:lower(), "a", index),
      }
    end
    return output, selected
  end

  local function buyRows(output, selected, actions)
    local rows = {}
    for index, item in ipairs(output) do
      rows[index] = {
        id=item.id, sourceIndex=index, label=item.name,
        right=item.soldOut and "SOLD OUT" or ("Y" .. tostring(item.price)),
        selected=index == selected,
        actionId=Common.sourceInput(actions, "buy.choose." .. index,
          "choose", item.id, "a", index),
      }
    end
    local cancelIndex = #output + 1
    rows[cancelIndex] = {
      id="cancel", sourceIndex=cancelIndex, label="CANCEL",
      selected=selected == cancelIndex,
      actionId=Common.sourceInput(actions, "buy.cancel", "close", "cancel",
        "a", cancelIndex),
    }
    return rows
  end

  function Mart.extract(state, context)
    local ok, code, detail = Common.exactState(state, SCREEN_ID)
    if not ok then return nil, code, detail end
    if Common.inBattle(context) then return nil, "battle_owned", SCREEN_ID end
    for _, field in ipairs({ "save", "items", "marts" }) do
      if type(rawget(state, field)) ~= "table" then
        return Common.fail("shape_type", field .. ":table")
      end
    end

    local martType = rawget(state, "martType")
    local phase = rawget(state, "phase")
    if type(martType) ~= "string" or not MART_TYPES[martType] then
      return Common.fail("unknown_mode", "martType=" .. tostring(martType))
    end
    if type(phase) ~= "string" or not PHASES[phase] then
      return Common.fail("unknown_mode", "phase=" .. tostring(phase))
    end
    local martId = Common.integer(rawget(state, "martId"), 0)
    local scroll = Common.integer(rawget(state, "scroll"), 0)
    if not martId then return Common.fail("shape_range", "martId") end
    if not scroll then return Common.fail("shape_range", "scroll") end

    local itemRows
    itemRows, code, detail = entries(state)
    if not itemRows then return nil, code, detail end
    local selected, selectedIndex, selectionDetail = selectedItem(state,
      itemRows)
    if type(selectedIndex) ~= "number" then
      return nil, selectedIndex or "shape_range", selectionDetail or "index"
    end

    local message
    message, code, detail = Common.paged(rawget(state, "message"), "message")
    if rawget(state, "message") ~= nil and not message then
      return nil, code, detail
    end
    local confirm
    confirm, code, detail = Common.confirm(rawget(state, "confirm"), "confirm")
    if rawget(state, "confirm") ~= nil and not confirm then
      return nil, code, detail
    end
    if message and confirm then
      return Common.fail("shape_conflict", "message+confirm")
    end

    local actions = Common.inputActions(SCREEN_ID, {
      { input="up", kind="navigate" },
      { input="down", kind="navigate" },
      { input="left", kind="adjust" },
      { input="right", kind="adjust" },
      { input="a", kind="confirm" },
      { input="b", kind="cancel" },
    })
    local rows, navigationSelected, nested, qty, topLines
    if phase == "top" then
      rows, navigationSelected = topRows(state, actions)
      if not rows then return nil, navigationSelected end
      topLines, code, detail = Common.lines(rawget(state, "topLines"),
        "topLines", true)
      if not topLines then return nil, code, detail end
    elseif phase == "buy" or phase == "buyQuantity" then
      rows = buyRows(itemRows, selectedIndex, actions)
      navigationSelected = selectedIndex
      if phase == "buyQuantity" then
        qty, code, detail = quantity(state)
        if not qty then return nil, code, detail end
      end
    elseif phase == "sell" or phase == "sellQuantity" then
      nested, code, detail = nestedPack(state, context)
      if not nested then return nil, code, detail end
      rows = {}
      navigationSelected = nested.navigation
        and nested.navigation.selectedIndex or 1
      selected = nested.selectedItem
      if phase == "sellQuantity" then
        qty, code, detail = quantity(state)
        if not qty then return nil, code, detail end
        qty.total = math.floor(qty.item.price * qty.value / 2)
      end
    else
      rows = {}
      navigationSelected = nil
      if not message then
        return Common.fail("shape_missing", phase .. ".message")
      end
    end

    local player = Common.player(state)
    local model = {
      schema="clean_ui.presenter_model.v1",
      screenId=SCREEN_ID, family="commerce", preset="L",
      title=martType == "BITTER" and "HERB SHOP"
        or martType == "BARGAIN" and "BARGAIN SHOP"
        or martType == "PHARMACY" and "PHARMACY" or "POKE MART",
      martType=martType, martId=martId, phase=phase,
      mode=confirm and "confirm" or message and "message"
        or qty and "quantity" or phase,
      money=Common.integer(rawget(player, "money"), 0, 999999) or 0,
      rows=rows,
      entries=itemRows,
      navigation={ selectedIndex=navigationSelected, scroll=scroll,
        itemCount=#rows },
      selectedItem=selected and Data.copy(selected) or nil,
      topLines=topLines,
      quantity=qty,
      message=message,
      confirm=confirm,
      nestedPack=nested,
    }
    return Common.bundle(model, actions)
  end

  return Mart
end
