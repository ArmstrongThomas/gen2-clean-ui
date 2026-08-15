return function(ctx)
  local Data = ctx.load("adapters.data")
  local Actions = ctx.load("adapters.actions")
  local MainMenu = {}

  local DAYS = {
    "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY",
    "THURSDAY", "FRIDAY", "SATURDAY",
  }

  local function phaseSnapshot(state)
    local present = rawget(state, "phase") ~= nil
    return {
      present = present,
      value = Data.scalar(rawget(state, "phase")),
      effective = Data.text(rawget(state, "phase"), "menu"),
    }
  end

  local function saveSummary(save)
    if type(save) ~= "table" then return nil end
    local player = type(rawget(save, "player")) == "table"
      and rawget(save, "player") or {}
    local pokedex = type(rawget(save, "pokedex")) == "table"
      and rawget(save, "pokedex") or {}
    local playTime = type(rawget(save, "playTime")) == "table"
      and rawget(save, "playTime") or {}
    local position = type(rawget(save, "position")) == "table"
      and rawget(save, "position") or nil
    return {
      name = Data.text(rawget(player, "name"), "?"),
      badges = Data.countTruthy(rawget(player, "badges")),
      caught = Data.countTruthy(rawget(pokedex, "caught")),
      hours = Data.integer(rawget(playTime, "hours"), 0),
      minutes = Data.integer(rawget(playTime, "minutes"), 0),
      map = Data.text(position and rawget(position, "map")
        or rawget(save, "spawn"), ""),
    }
  end

  local function clockSnapshot(state, context)
    local source = rawget(state, "clock")
    local sourceName = "screen"
    if type(source) ~= "table" then
      source = context and context.clock
      sourceName = "context"
    end
    if type(source) ~= "table" then
      return { available = false, source = "unavailable" }
    end

    local hour = Data.integer(rawget(source, "hour"), 0)
    local minute = Data.integer(rawget(source, "minute"), 0)
    local weekday = Data.integer(rawget(source, "weekday"), 1)
    if hour < 0 or hour > 23 then hour = 0 end
    if minute < 0 or minute > 59 then minute = 0 end
    if weekday < 1 or weekday > 7 then weekday = 1 end
    local displayHour = hour % 12
    if displayHour == 0 then displayHour = 12 end
    return {
      available = true,
      source = sourceName,
      hour = hour,
      minute = minute,
      weekday = weekday,
      dayLabel = DAYS[weekday],
      timeLabel = ("%d:%02d %s"):format(
        displayHour, minute, hour < 12 and "AM" or "PM"),
    }
  end

  local function listModel(state, actionMap)
    local list = type(rawget(state, "list")) == "table"
      and rawget(state, "list") or {}
    local items = type(rawget(list, "items")) == "table"
      and rawget(list, "items") or {}
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
        selected = sourceIndex == selectedIndex,
        disabled = rawget(sourceItem, "disabled") == true,
        actionId = actionId,
      }
    end
    return rows, list, selectedIndex
  end

  function MainMenu.extract(state, context)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local actionMap = Actions.new("Gen2MainMenu")
    local rows, list, selectedIndex = listModel(state, actionMap)
    local phase = phaseSnapshot(state)
    local confirmDelay = Data.integer(rawget(state, "confirmDelay"), 0)

    if phase.effective == "confirm" then
      if type(rawget(state, "onContinue")) == "function" then
        Actions.add(actionMap, {
          id = "confirm.continue",
          source = "screen.onContinue",
          kind = "confirm",
          componentId = "continue",
          callback = rawget(state, "onContinue"),
          arguments = { rawget(state, "save") },
          enabled = confirmDelay <= 0,
        })
      end
      Actions.add(actionMap, {
        id = "confirm.back",
        source = "screen.update",
        kind = "cancel",
        componentId = "continue",
        dispatch = "source_input",
        input = "b",
      })
    end

    local selected = rows[selectedIndex]
    local model = {
      schema = "clean_ui.v3.presentation.v1",
      apiVersion = 3,
      screenId = "Gen2MainMenu",
      family = "core",
      preset = "M",
      title = "MAIN MENU",
      phase = phase,
      hasSave = rawget(state, "hasSave") == true,
      navigation = {
        selectedIndex = selectedIndex,
        scroll = Data.integer(rawget(list, "scroll"), 0),
        selectedId = selected and selected.id or nil,
        itemCount = #rows,
      },
      items = rows,
      saveSummary = saveSummary(rawget(state, "save")),
      clock = clockSnapshot(state, context),
      confirm = phase.effective == "confirm" and {
        kind = "continue",
        delayFrames = confirmDelay,
        ready = confirmDelay <= 0,
      } or nil,
    }
    model.actionDescriptors = Actions.describe(actionMap)
    return { model = model, actions = actionMap }
  end

  function MainMenu.fixtures()
    local continueItems = {
      { label = "CONTINUE", value = "continue" },
      { label = "NEW GAME", value = "new" },
      { label = "OPTION", value = "option" },
      { label = "EXIT GAME", value = "exit" },
    }
    local save = {
      player = { name = "GOLD", badges = { ZEPHYR = true, HIVE = true } },
      pokedex = { caught = { [1] = true, [4] = true, [7] = true } },
      playTime = { hours = 12, minutes = 34 },
      position = { map = "NEW BARK TOWN" },
    }
    return {
      {
        variant = "new_game",
        state = {
          screenId = "Gen2MainMenu", hasSave = false, phase = "menu",
          list = { items = {
            { label = "NEW GAME", value = "new" },
            { label = "OPTION", value = "option" },
            { label = "EXIT GAME", value = "exit" },
          }, index = 1, scroll = 0 },
        },
      },
      {
        variant = "continue",
        state = {
          screenId = "Gen2MainMenu", hasSave = true, save = save,
          clock = { hour = 14, minute = 8, weekday = 4 }, phase = "menu",
          list = { items = continueItems, index = 1, scroll = 0 },
        },
      },
      {
        variant = "continue_confirm",
        state = {
          screenId = "Gen2MainMenu", hasSave = true, save = save,
          phase = "confirm", confirmDelay = 0,
          list = { items = continueItems, index = 1, scroll = 0 },
        },
      },
    }
  end

  return MainMenu
end
