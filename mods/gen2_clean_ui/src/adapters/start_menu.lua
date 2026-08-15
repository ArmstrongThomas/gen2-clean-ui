return function(ctx)
  local Data = ctx.load("adapters.data")
  local Actions = ctx.load("adapters.actions")
  local StartMenu = {}

  local function phaseSnapshot(state)
    local present = rawget(state, "phase") ~= nil
    return {
      present = present,
      value = Data.scalar(rawget(state, "phase")),
      effective = Data.text(rawget(state, "phase"), "menu"),
    }
  end

  local function description(value)
    local lines = {}
    if type(value) == "table" then
      for index = 1, math.min(#value, 2) do
        lines[#lines + 1] = Data.text(rawget(value, index), "")
      end
    end
    return lines
  end

  function StartMenu.extract(state)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local actionMap = Actions.new("Gen2StartMenu")
    local list = type(rawget(state, "list")) == "table"
      and rawget(state, "list") or {}
    local items = type(rawget(state, "items")) == "table"
      and rawget(state, "items") or {}
    local selectedIndex = Data.integer(rawget(list, "index"), 1)
    local rows = {}

    for sourceIndex = 1, #items do
      local sourceItem = rawget(items, sourceIndex)
      if type(sourceItem) ~= "table" then sourceItem = {} end
      local sourceValue = rawget(sourceItem, "value")
      local rowId = Data.id(rawget(sourceItem, "id"),
        Data.id(sourceValue, "row_" .. sourceIndex))
      local actionId
      if type(rawget(list, "onChoose")) == "function" then
        actionId = Actions.add(actionMap, {
          id = "choose." .. sourceIndex,
          source = "list.onChoose",
          kind = "choose",
          componentId = rowId,
          sourceIndex = sourceIndex,
          callback = rawget(list, "onChoose"),
          arguments = { sourceValue, sourceIndex },
          argumentCount = 2,
        })
      end
      rows[#rows + 1] = {
        id = rowId,
        sourceIndex = sourceIndex,
        label = Data.text(rawget(sourceItem, "label"),
          Data.text(sourceValue, "OPTION " .. sourceIndex)),
        value = Data.copy(sourceValue),
        description = description(rawget(sourceItem, "desc")),
        selected = sourceIndex == selectedIndex,
        disabled = rawget(sourceItem, "disabled") == true,
        pinned = rawget(sourceItem, "pinned") == true,
        actionId = actionId,
      }
    end

    local closeCallback = rawget(list, "onCancel")
    local closeReceiver
    local closeSource = "list.onCancel"
    if type(closeCallback) ~= "function" and type(state.close) == "function" then
      closeCallback, closeReceiver, closeSource = state.close, state, "screen.close"
    end
    if type(closeCallback) == "function" then
      Actions.add(actionMap, {
        id = "menu.back", source = closeSource, kind = "cancel",
        componentId = "back", callback = closeCallback,
        receiver = closeReceiver,
      })
    end

    local phase = phaseSnapshot(state)
    if phase.effective == "confirm" then
      if type(state.confirmQuit) == "function" then
        Actions.add(actionMap, {
          id = "quit.confirm", source = "screen.confirmQuit",
          kind = "confirm", componentId = "quit",
          callback = state.confirmQuit, receiver = state,
        })
      end
      Actions.add(actionMap, {
        id = "quit.cancel", source = "screen.update", kind = "cancel",
        componentId = "quit", dispatch = "source_input", input = "b",
      })
    end

    local selected = rows[selectedIndex]
    local save = type(rawget(state, "save")) == "table"
      and rawget(state, "save") or {}
    local player = type(rawget(save, "player")) == "table"
      and rawget(save, "player") or {}
    local model = {
      schema = "clean_ui.v3.presentation.v1",
      apiVersion = 3,
      screenId = "Gen2StartMenu",
      family = "navigation",
      preset = "NAV",
      title = "START",
      phase = phase,
      playerName = Data.text(rawget(player, "name"), "GOLD"),
      showDescription = rawget(state, "showDescription") == true,
      navigation = {
        selectedIndex = selectedIndex,
        scroll = Data.integer(rawget(list, "scroll"), 0),
        selectedId = selected and selected.id or nil,
        itemCount = #rows,
      },
      items = rows,
      selectedDescription = selected and Data.copy(selected.description) or {},
      confirm = phase.effective == "confirm" and {
        kind = "quit",
        selectedChoice = Data.integer(rawget(state, "confirmChoice"), 2),
        choices = {
          { id = "yes", label = "YES", value = 1,
            actionId = "quit.confirm" },
          { id = "no", label = "NO", value = 2,
            actionId = "quit.cancel" },
        },
      } or nil,
    }
    model.actionDescriptors = Actions.describe(actionMap)
    return { model = model, actions = actionMap }
  end

  local function stockItems()
    return {
      { label = "POKéDEX", value = "pokedex",
        desc = { "POKéMON", "database" } },
      { label = "POKéMON", value = "pokemon",
        desc = { "Party POKéMON", "status" } },
      { label = "PACK", value = "pack", desc = { "Contains", "items" } },
      { label = "POKéGEAR", value = "pokegear",
        desc = { "Trainer's", "key device" } },
      { label = "GOLD", value = "status", desc = { "Your own", "status" } },
      { label = "SAVE", value = "save", desc = { "Save your", "progress" } },
      { label = "OPTION", value = "option", desc = { "Change", "settings" } },
      { label = "QUIT", value = "quit", desc = { "Return to", "the title" } },
    }
  end

  local function stateWith(items, index, scroll, phase, confirmChoice)
    return {
      screenId = "Gen2StartMenu",
      save = { player = { name = "GOLD" } },
      items = items,
      list = { items = items, index = index, scroll = scroll },
      showDescription = true,
      phase = phase,
      confirmChoice = confirmChoice,
    }
  end

  function StartMenu.fixtures()
    local stock = stockItems()
    local pinned = stockItems()
    table.insert(pinned, #pinned, {
      id = "example.quick_menu", label = "QUICK MENU", pinned = true,
      desc = { "Pinned mod", "shortcut" },
    })
    local overflow = stockItems()
    for index = 1, 5 do
      table.insert(overflow, #overflow, {
        id = "example.menu_" .. index,
        label = "MOD MENU " .. index,
        desc = { "Third-party", "menu action" },
      })
    end
    return {
      { variant = "stock", state = stateWith(stock, 1, 0) },
      { variant = "pinned", state = stateWith(pinned, 8, 0) },
      { variant = "overflow", state = stateWith(overflow, 10, 3) },
      { variant = "quit_confirm",
        state = stateWith(stock, #stock, 0, "confirm", 2) },
    }
  end

  return StartMenu
end
