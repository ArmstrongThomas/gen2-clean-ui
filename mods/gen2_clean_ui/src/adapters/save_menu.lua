return function(ctx)
  local Data = ctx.load("adapters.data")
  local Actions = ctx.load("adapters.actions")
  local SaveMenu = {}

  local function sourceInput(actions, id, kind, componentId, input, sourceIndex)
    return Actions.add(actions, {
      id = id, source = "screen.update", kind = kind,
      componentId = componentId, sourceIndex = sourceIndex,
      dispatch = "source_input", input = input,
    })
  end

  local function child(source, key)
    local value = type(source) == "table" and rawget(source, key) or nil
    return type(value) == "table" and value or {}
  end

  local function summary(save)
    local player = child(save, "player")
    local pokedex = child(save, "pokedex")
    local time = child(save, "playTime")
    local position = child(save, "position")
    return {
      name = Data.text(rawget(player, "name"), "?"),
      badges = Data.countTruthy(rawget(player, "badges")),
      caught = Data.countTruthy(rawget(pokedex, "caught")),
      hours = Data.integer(rawget(time, "hours"), 0),
      minutes = Data.integer(rawget(time, "minutes"), 0),
      map = Data.text(rawget(position, "map"),
        Data.text(rawget(save, "spawn"), "")),
    }
  end

  local function prompt(phase, playerName, saved)
    if phase == "overwrite" then
      return { "There is already a save file.", "Overwrite it?" }
    end
    if phase == "saving" then
      return { "SAVING... DO NOT TURN", "OFF THE POWER." }
    end
    if phase == "done" then
      if saved then return { playerName .. " saved", "the game." } end
      return { "Could not save.", "" }
    end
    return { "Would you like to", "save the game?" }
  end

  function SaveMenu.extract(state)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local save = rawget(state, "save")
    if type(save) ~= "table" then return nil, "save_type", "table" end
    local phase = Data.text(rawget(state, "phase"), "confirm")
    local choice = Data.integer(rawget(state, "choice"), 1)
    local actions = Actions.new("Gen2SaveMenu")
    local choices = {}
    if phase == "confirm" or phase == "overwrite" then
      choices = {
        {
          id = "yes", sourceIndex = 1, label = "YES", selected = choice == 1,
          actionId = sourceInput(actions, "choice.yes", "confirm", "yes", "a", 1),
        },
        {
          id = "no", sourceIndex = 2, label = "NO", selected = choice == 2,
          actionId = sourceInput(actions, "choice.no", "cancel", "no", "a", 2),
        },
      }
      sourceInput(actions, "choice.previous", "navigate", "save_choice", "up")
      sourceInput(actions, "choice.next", "navigate", "save_choice", "down")
      sourceInput(actions, "save.cancel", "cancel", "save", "b")
    end
    local info = summary(save)
    local savedPresent = rawget(state, "saved") ~= nil
    local saved = rawget(state, "saved") == true
    local model = {
      schema = "clean_ui.presenter_model.v1",
      screenId = "Gen2SaveMenu",
      family = "core",
      preset = "M",
      title = "SAVE",
      phase = phase,
      existed = rawget(state, "existed") == true,
      selectedChoice = choice,
      choices = choices,
      timer = Data.integer(rawget(state, "timer"), 0),
      savedPresent = savedPresent,
      saved = saved,
      summary = info,
      prompt = prompt(phase, info.name, saved),
    }
    model.actionDescriptors = Actions.describe(actions)
    return { model = model, actions = actions }
  end

  return SaveMenu
end
