return function(ctx)
  local Data = ctx.load("adapters.data")
  local Actions = ctx.load("adapters.actions")
  local OptionsMenu = {}

  local FILTERS = { "OFF", "1X", "2X", "3X" }
  local TILTS = { "OFF", "15", "35", "50" }
  local COLORS = { gbc = "GBC", dmg = "DMG", classic = "CLASSIC" }

  local function phaseSnapshot(state)
    local present = rawget(state, "phase") ~= nil
    return {
      present = present,
      value = Data.scalar(rawget(state, "phase")),
      effective = Data.text(rawget(state, "phase"), "menu"),
    }
  end

  local function genericValue(value)
    if value == nil then return "N/A" end
    if type(value) == "boolean" then return value and "ON" or "OFF" end
    return Data.text(value, "N/A")
  end

  local function knownValue(key, value)
    if key == "musicVol" or key == "sfxVol" then
      local number = Data.integer(value, 7)
      return number == 0 and "OFF" or tostring(number)
    elseif key == "musicFilter" then
      return FILTERS[Data.integer(value, 0) + 1] or "OFF"
    elseif key == "speed" then
      local number = tonumber(value) or 1
      return number == 1 and "NORMAL" or tostring(number) .. "X"
    elseif key == "zoom" then
      local number = Data.integer(value, 0)
      if number == 0 then return "FIT" end
      return number < 0 and ("OUT" .. -number) or ("IN" .. number)
    elseif key == "tilt" then
      return TILTS[Data.integer(value, 0) + 1] or "OFF"
    elseif key == "color" then
      return COLORS[value] or Data.text(value, "GBC"):upper()
    elseif key == "gbcfx" then
      local number = Data.integer(value, 0)
      return number == 0 and "OFF" or tostring(number)
    end
    return nil
  end

  local function displayValue(row, options)
    if rawget(row, "cancel") == true then return nil end
    if rawget(row, "frame") == true then
      return tostring(Data.integer(rawget(options, "frame"), 1))
    end

    local key = Data.id(rawget(row, "key"))
    local value
    if key ~= nil then value = rawget(options, key) end
    local display = rawget(row, "display")
    if type(display) == "table" then
      local mapped = rawget(display, value)
      if mapped ~= nil then return Data.text(mapped, genericValue(value)) end
    end
    local known = knownValue(key, value)
    if known then return known end
    if rawget(row, "activate") ~= nil then return "OPEN" end
    return genericValue(value)
  end

  local function choices(row)
    local values = rawget(row, "values")
    if type(values) ~= "table" then return {} end
    local display = rawget(row, "display")
    local output = {}
    for index = 1, #values do
      local value = rawget(values, index)
      local label = type(display) == "table" and rawget(display, value) or nil
      output[#output + 1] = {
        value = Data.copy(value),
        label = Data.text(label, genericValue(value)),
      }
    end
    return output
  end

  local function rowKind(row)
    if rawget(row, "cancel") == true then return "cancel" end
    if rawget(row, "activate") ~= nil then return "action" end
    if rawget(row, "frame") == true then return "frame" end
    if type(rawget(row, "values")) == "table" then return "choice" end
    return "value"
  end

  local function addActions(actionMap, state, row, rowId, sourceIndex)
    local ids = {}
    local kind = rowKind(row)
    if kind == "cancel" then
      if type(state.leave_) == "function" then
        ids.primary = Actions.add(actionMap, {
          id = "row." .. sourceIndex .. ".close",
          source = "screen.leave_", kind = "close",
          componentId = rowId, sourceIndex = sourceIndex,
          callback = state.leave_, receiver = state,
        })
      end
      return ids
    end

    local activate = rawget(row, "activate")
    if type(activate) == "function" then
      ids.primary = Actions.add(actionMap, {
        id = "row." .. sourceIndex .. ".activate",
        source = "row.activate", kind = "activate",
        componentId = rowId, sourceIndex = sourceIndex,
        callback = activate, arguments = { rawget(state, "game") },
      })
      return ids
    end

    local adjustable = rawget(row, "frame") == true
      or type(rawget(row, "values")) == "table"
      or type(rawget(row, "step")) == "function"
      or type(rawget(row, "cycle")) == "function"
    if adjustable and type(state.cycle) == "function" then
      ids.previous = Actions.add(actionMap, {
        id = "row." .. sourceIndex .. ".previous",
        source = "screen.cycle", kind = "adjust",
        componentId = rowId, sourceIndex = sourceIndex,
        callback = state.cycle, receiver = state,
        arguments = { row, -1 },
      })
      ids.next = Actions.add(actionMap, {
        id = "row." .. sourceIndex .. ".next",
        source = "screen.cycle", kind = "adjust",
        componentId = rowId, sourceIndex = sourceIndex,
        callback = state.cycle, receiver = state,
        arguments = { row, 1 },
      })
      ids.primary = ids.next
    end
    return ids
  end

  function OptionsMenu.extract(state)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local actionMap = Actions.new("Gen2OptionsMenu")
    local rows = type(rawget(state, "rows")) == "table"
      and rawget(state, "rows") or {}
    local options = type(rawget(state, "options")) == "table"
      and rawget(state, "options") or {}
    local selectedIndex = Data.integer(rawget(state, "index"), 1)
    local output, optionSnapshot = {}, {}

    for sourceIndex = 1, #rows do
      local sourceRow = rawget(rows, sourceIndex)
      if type(sourceRow) ~= "table" then sourceRow = {} end
      local key = Data.id(rawget(sourceRow, "key"))
      local rowId = Data.id(rawget(sourceRow, "id"),
        key or (rawget(sourceRow, "cancel") and "cancel"
          or "row_" .. sourceIndex))
      local value
      if key ~= nil then value = rawget(options, key) end
      if key then optionSnapshot[key] = Data.copy(value) end
      output[#output + 1] = {
        id = rowId,
        sourceIndex = sourceIndex,
        key = key,
        kind = rowKind(sourceRow),
        label = Data.text(rawget(sourceRow, "label"),
          "OPTION " .. sourceIndex),
        value = Data.copy(value),
        valuePresent = key ~= nil and rawget(options, key) ~= nil,
        displayValue = displayValue(sourceRow, options),
        choices = choices(sourceRow),
        selected = sourceIndex == selectedIndex,
        disabled = rawget(sourceRow, "disabled") == true,
        actions = addActions(actionMap, state, sourceRow, rowId, sourceIndex),
      }
    end

    if type(state.leave_) == "function" then
      Actions.add(actionMap, {
        id = "menu.back", source = "screen.leave_", kind = "close",
        componentId = "back", callback = state.leave_, receiver = state,
      })
    else
      Actions.add(actionMap, {
        id = "menu.back", source = "screen.update", kind = "close",
        componentId = "back", dispatch = "source_input", input = "b",
      })
    end

    local selected = output[selectedIndex]
    local model = {
      schema = "clean_ui.v3.presentation.v1",
      apiVersion = 3,
      screenId = "Gen2OptionsMenu",
      family = "core",
      preset = "M",
      title = "OPTIONS",
      phase = phaseSnapshot(state),
      navigation = {
        selectedIndex = selectedIndex,
        scroll = Data.integer(rawget(state, "scroll"), 0),
        selectedId = selected and selected.id or nil,
        itemCount = #output,
      },
      rows = output,
      options = optionSnapshot,
    }
    model.actionDescriptors = Actions.describe(actionMap)
    return { model = model, actions = actionMap }
  end

  local function baseRows()
    return {
      { label = "TEXT SPEED", key = "textSpeed",
        values = { "FAST", "MID", "SLOW" } },
      { label = "BATTLE SCENE", key = "battleScene",
        values = { true, false }, display = { [true] = "ON", [false] = "OFF" } },
      { label = "BATTLE STYLE", key = "battleStyle",
        values = { "SHIFT", "SET" } },
      { label = "SOUND", key = "sound", values = { "MONO", "STEREO" } },
      { label = "PRINT", key = "print",
        values = { "LIGHTEST", "LIGHTER", "NORMAL", "DARKER", "DARKEST" } },
      { label = "MENU ACCOUNT", key = "menuAccount",
        values = { false, true }, display = { [false] = "OFF", [true] = "ON" } },
      { label = "FRAME", key = "frame", frame = true },
      { id = "cancel", label = "CANCEL", cancel = true },
    }
  end

  local function baseOptions()
    return {
      textSpeed = "MID", battleScene = true, battleStyle = "SHIFT",
      sound = "MONO", print = "NORMAL", menuAccount = true, frame = 1,
      musicVol = 7, sfxVol = 7, musicFilter = 0, speed = 1,
      zoom = 0, tilt = 0, color = "gbc", gbcfx = 0,
    }
  end

  function OptionsMenu.fixtures()
    local shortRows = baseRows()
    local overflowRows = baseRows()
    table.remove(overflowRows, #overflowRows)
    local portRows = {
      { id = "controls", label = "CONTROLS", activate = true },
      { label = "MUSIC VOL", key = "musicVol" },
      { label = "SFX VOL", key = "sfxVol" },
      { label = "MUSIC FILTER", key = "musicFilter" },
      { label = "GAME SPEED", key = "speed" },
      { label = "ZOOM", key = "zoom" },
      { label = "TILT", key = "tilt" },
      { label = "COLOR", key = "color" },
      { label = "GBC FX", key = "gbcfx" },
      { id = "cancel", label = "CANCEL", cancel = true },
    }
    for _, row in ipairs(portRows) do overflowRows[#overflowRows + 1] = row end
    return {
      {
        variant = "options",
        state = { screenId = "Gen2OptionsMenu", rows = shortRows,
          options = baseOptions(), index = 1, scroll = 0 },
      },
      {
        variant = "overflow",
        state = { screenId = "Gen2OptionsMenu", rows = overflowRows,
          options = baseOptions(), index = 12, scroll = 6 },
      },
    }
  end

  return OptionsMenu
end
