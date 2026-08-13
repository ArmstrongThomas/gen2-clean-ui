return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.storage_common")
  local Actions = ctx.load("adapters.actions")
  local ItemPc = {}

  local POCKETS = {
    [1] = { id="ITEM", label="ITEMS" },
    [2] = { id="BALL", label="POKE BALLS" },
    [3] = { id="KEY_ITEM", label="KEY ITEMS" },
    [4] = { id="TM_HM", label="TM/HM" },
  }

  local function playerName(state)
    local save = rawget(state, "save")
    local player = type(save) == "table" and rawget(save, "player") or nil
    return Data.text(type(player) == "table" and rawget(player, "name") or nil,
      "GOLD")
  end

  local function listRows(state, actionMap, prefix)
    local rows = rawget(state, "rows")
    if type(rows) ~= "table" then rows = {} end
    local selected = Data.integer(rawget(state, "listIndex"), 1)
    local output = {}
    for index = 1, #rows do
      local source = rawget(rows, index)
      if type(source) ~= "table" then source = {} end
      local id = Data.id(rawget(source, "id"), "item_" .. index)
      local count = Data.integer(rawget(source, "count"), 0)
      local actionId
      if actionMap then
        actionId = Actions.add(actionMap, {
          id = (prefix or "item.choose") .. "." .. index,
          source = "screen.update",
          kind = "choose_item",
          componentId = id,
          sourceIndex = index,
          dispatch = "source_input",
          input = "a",
        })
      end
      output[index] = {
        id=id, sourceIndex=index,
        label=Data.text(rawget(source, "name"), id),
        count=count, right="x" .. tostring(count),
        selected=index == selected, actionId=actionId,
      }
    end
    output[#output + 1] = Common.cancelRow(#rows + 1, selected,
      actionMap, prefix or "item.choose")
    return output
  end

  local function packRows(pack, actionMap)
    if type(pack) ~= "table" then return {}, nil end
    local rows = rawget(pack, "rows")
    if type(rows) ~= "table" then rows = {} end
    local selected = Data.integer(rawget(pack, "index"), 1)
    local output = {}
    for index = 1, #rows do
      local source = rawget(rows, index)
      if type(source) ~= "table" then source = {} end
      local id = Data.id(rawget(source, "id"), "pack_item_" .. index)
      local count = Data.integer(rawget(source, "count"), 0)
      local actionId
      if actionMap then
        actionId = Actions.add(actionMap, {
          id = "pack.choose." .. index,
          source = "screen.pack.update",
          kind = "choose_item",
          componentId = id,
          sourceIndex = index,
          dispatch = "source_input",
          input = "a",
        })
      end
      output[index] = {
        id=id, sourceIndex=index,
        label=Data.text(rawget(source, "name"), id),
        count=count,
        right=rawget(source, "showCount") == false and ""
          or ("x" .. tostring(count)),
        teaches=Data.text(rawget(source, "teaches"), ""),
        selected=index == selected,
        actionId=actionId,
      }
    end
    output[#output + 1] = Common.cancelRow(#rows + 1, selected,
      actionMap, "pack.choose")
    local pocketIndex = Data.integer(rawget(pack, "pocketIndex"), 1)
    pocketIndex = math.max(1, math.min(pocketIndex, #POCKETS))
    return output, {
      pocketIndex=pocketIndex,
      pocket=Data.copy(POCKETS[pocketIndex]),
      selectedIndex=selected,
      scroll=Data.integer(rawget(pack, "scroll"), 0),
    }
  end

  local function itemDescription(state, rows, selected)
    local row = type(rows) == "table" and rawget(rows, selected) or nil
    local id = type(row) == "table" and rawget(row, "id") or nil
    local items = rawget(state, "items")
    local definition = type(items) == "table" and rawget(items, id) or nil
    local description = type(definition) == "table"
      and rawget(definition, "description") or nil
    if type(description) ~= "string" then return {} end
    description = description:gsub("<NEXT>", "\n")
    return Common.lines(description)
  end

  local function confirmSnapshot(value)
    if type(value) ~= "table" then return nil end
    local selected = Data.integer(rawget(value, "choice"), 1)
    selected = math.max(1, math.min(selected, 2))
    return {
      prompt=Common.lines(rawget(value, "prompt")),
      selectedChoice=selected,
      choices={
        { id="yes", label="YES", sourceIndex=1 },
        { id="no", label="NO", sourceIndex=2 },
      },
    }
  end

  local function inputSpecs(state, view)
    if view == "message" then
      return {
        { input="a", id="message.advance", kind="continue" },
        { input="b", id="message.dismiss", kind="continue" },
      }
    end
    if view == "quantity" then
      return {
        { input="up", id="quantity.increment", kind="adjust" },
        { input="down", id="quantity.decrement", kind="adjust" },
        { input="right", id="quantity.increment_ten", kind="adjust" },
        { input="left", id="quantity.decrement_ten", kind="adjust" },
        { input="a", id="quantity.accept", kind="confirm" },
        { input="b", id="quantity.cancel", kind="cancel" },
      }
    end
    if view == "confirm" then
      return {
        { input="up", id="confirm.previous", kind="navigate" },
        { input="down", id="confirm.next", kind="navigate" },
        { input="a", id="confirm.choose", kind="confirm" },
        { input="b", id="confirm.no", kind="cancel" },
      }
    end
    local phase = rawget(state, "phase")
    if phase == "deposit" then
      return {
        { input="up", id="pack.previous", kind="navigate" },
        { input="down", id="pack.next", kind="navigate" },
        { input="left", id="pack.previous_pocket", kind="navigate_pocket" },
        { input="right", id="pack.next_pocket", kind="navigate_pocket" },
        { input="a", id="pack.choose", kind="choose_item" },
        { input="b", id="pack.cancel", kind="cancel" },
      }
    end
    if phase == "withdraw" or phase == "toss" then
      return {
        { input="up", id="list.previous", kind="navigate" },
        { input="down", id="list.next", kind="navigate" },
        { input="a", id="list.choose", kind="choose_item" },
        { input="b", id="list.cancel", kind="cancel" },
      }
    end
    return {
      { input="up", id="menu.previous", kind="navigate" },
      { input="down", id="menu.next", kind="navigate" },
      { input="a", id="menu.choose", kind="choose" },
      { input="b", id="menu.close", kind="cancel" },
    }
  end

  function ItemPc.extract(state)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local phase = rawget(state, "phase")
    if phase ~= "menu" and phase ~= "withdraw"
        and phase ~= "deposit" and phase ~= "toss" then
      return nil, "phase_invalid", tostring(phase)
    end
    local entries = rawget(state, "entries")
    local index = Data.integer(rawget(state, "index"))
    local listIndex = Data.integer(rawget(state, "listIndex"))
    local scroll = Data.integer(rawget(state, "scroll"))
    if type(entries) ~= "table" or index == nil
        or index < 1 or index > #entries then
      return nil, "selection_invalid", "entries/index"
    end
    if listIndex == nil or listIndex < 1 or scroll == nil or scroll < 0 then
      return nil, "selection_invalid", "listIndex/scroll"
    end
    local view = rawget(state, "message") ~= nil and "message"
      or rawget(state, "qtyState") ~= nil and "quantity"
      or rawget(state, "confirm") ~= nil and "confirm" or phase
    local actionMap = Common.inputActions("Gen2ItemPcMenu",
      inputSpecs(state, view))
    local rootRows = Common.entryRows(entries, index,
      view == "menu" and actionMap or nil, "row")
    local itemRows = listRows(state,
      (view == "withdraw" or view == "toss") and actionMap or nil,
      "item.choose")
    local nestedRows, pocket = packRows(rawget(state, "pack"),
      view == "deposit" and actionMap or nil)
    local quantitySource = rawget(state, "qtyState")
    local quantity
    if type(quantitySource) == "table" then
      local maximum = Data.integer(rawget(quantitySource, "max"), 1)
      maximum = math.max(1, maximum)
      local value = Data.integer(rawget(quantitySource, "qty"), 1)
      value = math.max(1, math.min(value, maximum))
      quantity = {
        value=value, maximum=maximum,
        prompt=Common.lines(rawget(quantitySource, "prompt")),
      }
    end
    local replacements = { ["{PLAYER}"]=playerName(state) }
    local model = {
      schema = "clean_ui.presenter_model.v1",
      screenId = "Gen2ItemPcMenu",
      family = "storage",
      preset = "L",
      phase = phase,
      view = view,
      house = rawget(state, "house") == true,
      changedDecorations = rawget(state, "changedDecorations") == true,
      playerName = playerName(state),
      navigation = {
        selectedIndex = phase == "menu" and index or listIndex,
        scroll = scroll,
      },
      entries = rootRows,
      rows = itemRows,
      description = itemDescription(state, rawget(state, "rows"), listIndex),
      deposit = phase == "deposit" and {
        packPresent=type(rawget(state, "pack")) == "table",
        rows=nestedRows,
        pocket=pocket,
      } or nil,
      quantity = quantity,
      confirm = confirmSnapshot(rawget(state, "confirm")),
      message = Common.message(rawget(state, "message"), replacements),
    }
    model.actionDescriptors = Common.describe(actionMap)
    return { model=model, actions=actionMap }
  end

  return ItemPc
end
