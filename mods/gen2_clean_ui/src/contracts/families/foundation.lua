return function(ctx)
  local Record = ctx.load("contracts.record")
  local V = ctx.load("contracts.validators")

  local function mainBase(state)
    local ok, code, detail = V.fields(state, {
      hasSave = "boolean",
      phase = "string",
      list = "table",
    })
    if not ok then return nil, code, detail end
    if state.save ~= nil and type(state.save) ~= "table" then
      return V.fail("shape_type", "save:table")
    end
    return V.chromeList(state.list, "list")
  end

  local function mainMode(state)
    local ok, code, detail = V.enum(state.phase, "phase", { "menu", "confirm" })
    if not ok then return nil, code, detail end
    if state.phase == "confirm" and (not state.hasSave or type(state.save) ~= "table") then
      return V.fail("shape_missing", "confirm.save")
    end
    return true
  end

  local function startBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table",
      items = "table",
      list = "table",
      showDescription = "boolean",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.items, "items", 1)
    if not ok then return nil, code, detail end
    return V.chromeList(state.list, "list")
  end

  local function startMode(state)
    local ok, code, detail = V.enum(state.phase, "phase", { "confirm" }, true)
    if not ok then return nil, code, detail end
    if state.phase == "confirm" then
      return V.integer(state.confirmChoice, "confirmChoice", 1, 2)
    end
    return true
  end

  local function optionsBase(state)
    local ok, code, detail = V.fields(state, {
      rows = "table",
      options = "table",
      index = "number",
      scroll = "number",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.rows, "rows", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.index(state.index, "index", #state.rows)
    if not ok then return nil, code, detail end
    return V.nonNegative(state.scroll, "scroll")
  end

  return {
    Record.new({
      id = "Gen2MainMenu",
      module = "src.ui.gen2.MainMenu",
      support = "supported",
      milestone = "0.1.0",
      family = "core",
      preset = "M",
      opaque = true,
      toggle = "menus",
      implementation = "presenter_ready",
      presentationApi = 3,
      validateBase = mainBase,
      validateMode = mainMode,
      gallery = { "new_game", "continue", "continue_confirm" },
    }),
    Record.new({
      id = "Gen2StartMenu",
      module = "src.ui.gen2.StartMenu",
      support = "supported",
      milestone = "0.1.0",
      family = "navigation",
      preset = "NAV",
      opaque = false,
      toggle = "menus",
      implementation = "presenter_ready",
      presentationApi = 3,
      validateBase = startBase,
      validateMode = startMode,
      gallery = { "stock", "pinned", "overflow", "quit_confirm" },
    }),
    Record.new({
      id = "Gen2OptionsMenu",
      module = "src.ui.gen2.OptionsMenu",
      support = "supported",
      milestone = "0.1.0",
      family = "core",
      preset = "M",
      opaque = true,
      toggle = "menus",
      implementation = "presenter_ready",
      presentationApi = 3,
      validateBase = optionsBase,
      gallery = { "options", "overflow" },
    }),
  }
end
