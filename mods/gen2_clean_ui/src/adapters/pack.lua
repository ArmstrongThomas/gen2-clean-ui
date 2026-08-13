return function(ctx)
  local Data = ctx.load("adapters.data")
  local Actions = ctx.load("adapters.actions")
  local Pack = {}

  local POCKETS = {
    { id = "ITEM", label = "ITEMS" },
    { id = "BALL", label = "POKE BALLS" },
    { id = "KEY_ITEM", label = "KEY ITEMS" },
    { id = "TM_HM", label = "TM/HM" },
  }
  local SUBMENU_LABELS = {
    use = "USE", give = "GIVE", toss = "TOSS",
    sel = "REGISTER", quit = "QUIT",
  }

  local function sourceInput(actions, id, kind, componentId, input, sourceIndex)
    return Actions.add(actions, {
      id = id, source = "screen.update", kind = kind,
      componentId = componentId, sourceIndex = sourceIndex,
      dispatch = "source_input", input = input,
    })
  end

  local function itemDefinition(state, itemId)
    local items = rawget(state, "items")
    if type(items) ~= "table" or itemId == nil then return nil end
    local value = rawget(items, itemId)
    return type(value) == "table" and value or nil
  end

  local function moveDefinition(state, moveId)
    if moveId == nil then return nil end
    local game = rawget(state, "game")
    local data = type(game) == "table" and rawget(game, "data") or nil
    local moves = type(data) == "table" and rawget(data, "moves") or nil
    local value = type(moves) == "table" and rawget(moves, moveId) or nil
    return type(value) == "table" and value or nil
  end

  local function pocketCounts(state)
    local counts = { ITEM = 0, BALL = 0, KEY_ITEM = 0, TM_HM = 0 }
    local save = rawget(state, "save")
    local inventory = type(save) == "table" and rawget(save, "inventory") or nil
    if type(inventory) ~= "table" then return counts end
    local itemId, amount = next(inventory, nil)
    local visited = 0
    while itemId ~= nil and visited < 4096 do
      local count = type(amount) == "number" and amount
        or (amount and 1 or 0)
      if count > 0 then
        local definition = itemDefinition(state, itemId)
        local pocket = definition and Data.id(rawget(definition, "pocket"), "ITEM")
          or "ITEM"
        if counts[pocket] ~= nil then counts[pocket] = counts[pocket] + 1 end
      end
      visited = visited + 1
      itemId, amount = next(inventory, itemId)
    end
    return counts
  end

  local function playerName(state)
    local save = rawget(state, "save")
    local player = type(save) == "table" and rawget(save, "player") or nil
    return Data.text(type(player) == "table" and rawget(player, "name") or nil,
      "GOLD")
  end

  local function lines(value, name)
    local output = {}
    if type(value) ~= "table" then return output end
    for index = 1, math.min(#value, 16) do
      local line = Data.text(rawget(value, index), "")
      output[#output + 1] = line:gsub("{PLAYER}", name)
    end
    return output
  end

  local function itemDetails(state, sourceRow)
    if type(sourceRow) ~= "table" then return nil end
    local itemId = Data.id(rawget(sourceRow, "id"))
    local definition = itemDefinition(state, itemId)
    local moveId = definition and rawget(definition, "teaches") or nil
    local move = moveDefinition(state, moveId)
    local description = move and rawget(move, "description")
      or (definition and rawget(definition, "description"))
    return {
      id = itemId,
      name = Data.text(rawget(sourceRow, "name"), itemId or "ITEM"),
      count = Data.integer(rawget(sourceRow, "count"), 0),
      teaches = Data.text(rawget(sourceRow, "teaches"), ""),
      tmNumber = Data.integer(rawget(sourceRow, "tmNumber")),
      description = Data.text(description, ""),
    }
  end

  local function mainRows(state, actions)
    local sourceRows = rawget(state, "rows")
    local selected = Data.integer(rawget(state, "index"), 1)
    local output = {}
    for sourceIndex = 1, #sourceRows do
      local sourceRow = rawget(sourceRows, sourceIndex)
      if type(sourceRow) ~= "table" then sourceRow = {} end
      local id = Data.id(rawget(sourceRow, "id"), "item_" .. sourceIndex)
      local count = Data.integer(rawget(sourceRow, "count"), 0)
      local teaches = Data.text(rawget(sourceRow, "teaches"), "")
      output[#output + 1] = {
        id = id,
        sourceIndex = sourceIndex,
        label = Data.text(rawget(sourceRow, "name"), id),
        count = count,
        teaches = teaches,
        showCount = rawget(sourceRow, "showCount") == true,
        right = teaches ~= "" and teaches
          or (rawget(sourceRow, "showCount") == true and ("x" .. count) or ""),
        selected = sourceIndex == selected,
        actionId = sourceInput(actions, "item." .. sourceIndex .. ".choose",
          "choose", id, "a", sourceIndex),
      }
    end
    local cancelIndex = #sourceRows + 1
    output[#output + 1] = {
      id = "cancel", sourceIndex = cancelIndex, label = "CANCEL",
      selected = selected == cancelIndex,
      actionId = sourceInput(actions, "item.cancel", "close", "cancel", "a",
        cancelIndex),
    }
    return output
  end

  local function submenuSnapshot(state, actions)
    local submenu = rawget(state, "submenu")
    if type(submenu) ~= "table" then return nil end
    local sourceRows = rawget(submenu, "rows")
    local selected = Data.integer(rawget(submenu, "index"), 1)
    local output = {}
    for sourceIndex = 1, #(type(sourceRows) == "table" and sourceRows or {}) do
      local value = Data.id(rawget(sourceRows, sourceIndex),
        "action_" .. sourceIndex)
      output[#output + 1] = {
        id = value, sourceIndex = sourceIndex,
        label = SUBMENU_LABELS[value] or Data.text(value, "ACTION"),
        selected = sourceIndex == selected,
        actionId = sourceInput(actions, "submenu." .. sourceIndex .. ".choose",
          "choose", value, "a", sourceIndex),
      }
    end
    local sourceItem = rawget(submenu, "row")
    return {
      selectedIndex = selected,
      item = itemDetails(state, sourceItem),
      rows = output,
      backActionId = sourceInput(actions, "submenu.back", "close",
        "submenu", "b"),
    }
  end

  local function quantitySnapshot(state, actions)
    local quantity = rawget(state, "qtyState")
    if type(quantity) ~= "table" then return nil end
    return {
      qty = Data.integer(rawget(quantity, "qty"), 1),
      max = Data.integer(rawget(quantity, "max"), 1),
      item = itemDetails(state, rawget(quantity, "row")),
      actions = {
        increase = sourceInput(actions, "quantity.increase", "adjust",
          "quantity", "up"),
        decrease = sourceInput(actions, "quantity.decrease", "adjust",
          "quantity", "down"),
        increaseTen = sourceInput(actions, "quantity.increase_ten", "adjust",
          "quantity", "right"),
        decreaseTen = sourceInput(actions, "quantity.decrease_ten", "adjust",
          "quantity", "left"),
        accept = sourceInput(actions, "quantity.accept", "confirm",
          "quantity", "a"),
        cancel = sourceInput(actions, "quantity.cancel", "cancel",
          "quantity", "b"),
      },
    }
  end

  local function confirmSnapshot(state, actions)
    local confirm = rawget(state, "confirm")
    if type(confirm) ~= "table" then return nil end
    return {
      prompt = lines(rawget(confirm, "prompt"), playerName(state)),
      selectedChoice = Data.integer(rawget(confirm, "choice"), 1),
      choices = {
        { id = "yes", sourceIndex = 1, label = "YES" },
        { id = "no", sourceIndex = 2, label = "NO" },
      },
      actions = {
        toggleUp = sourceInput(actions, "confirm.up", "adjust", "confirm", "up"),
        toggleDown = sourceInput(actions, "confirm.down", "adjust", "confirm", "down"),
        accept = sourceInput(actions, "confirm.accept", "confirm", "confirm", "a"),
        cancel = sourceInput(actions, "confirm.cancel", "cancel", "confirm", "b"),
      },
    }
  end

  function Pack.extract(state)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local sourceRows = rawget(state, "rows")
    if type(sourceRows) ~= "table" then return nil, "rows_type", "table" end

    local actions = Actions.new("Gen2PackMenu")
    local selectedIndex = Data.integer(rawget(state, "index"), 1)
    local selectedSource = selectedIndex <= #sourceRows
      and rawget(sourceRows, selectedIndex) or nil
    local counts = pocketCounts(state)
    local pocketIndex = Data.integer(rawget(state, "pocketIndex"), 1)
    local pockets = {}
    for index, pocket in ipairs(POCKETS) do
      pockets[index] = {
        id = pocket.id, label = pocket.label, sourceIndex = index,
        itemCount = counts[pocket.id] or 0, selected = index == pocketIndex,
      }
    end

    local model = {
      schema = "clean_ui.presenter_model.v1",
      screenId = "Gen2PackMenu",
      family = "inventory",
      preset = "L",
      title = "PACK",
      mode = rawget(state, "qtyState") ~= nil and "quantity"
        or rawget(state, "message") ~= nil and "message"
        or rawget(state, "confirm") ~= nil and "confirm"
        or rawget(state, "submenu") ~= nil and "actions"
        or "pockets",
      chooser = rawget(state, "give") == true,
      battleOwned = rawget(state, "battle") == true,
      pockets = pockets,
      pocket = Data.copy(pockets[pocketIndex] or pockets[1]),
      navigation = {
        selectedIndex = selectedIndex,
        selectedId = type(selectedSource) == "table"
          and Data.id(rawget(selectedSource, "id")) or "cancel",
        scroll = Data.integer(rawget(state, "scroll"), 0),
        itemCount = #sourceRows,
        rowCount = #sourceRows + 1,
      },
      rows = mainRows(state, actions),
      selectedItem = itemDetails(state, selectedSource),
      message = lines(rawget(state, "message"), playerName(state)),
      submenu = submenuSnapshot(state, actions),
      quantity = quantitySnapshot(state, actions),
      confirm = confirmSnapshot(state, actions),
      controls = {
        previousPocket = sourceInput(actions, "pocket.previous", "navigate",
          "pockets", "left"),
        nextPocket = sourceInput(actions, "pocket.next", "navigate",
          "pockets", "right"),
        back = sourceInput(actions, "pack.back", "close", "pack", "b"),
        register = sourceInput(actions, "pack.register", "action", "pack",
          "select"),
      },
    }
    model.actionDescriptors = Actions.describe(actions)
    return { model = model, actions = actions }
  end

  Pack.POCKETS = POCKETS
  return Pack
end
