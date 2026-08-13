return function(ctx)
  local Record = ctx.load("contracts.record")
  local V = ctx.load("contracts.validators")

  local function optionalPaged(state, key, confirm)
    if state[key] == nil then return true end
    if confirm then return V.pagedConfirm(state[key], key) end
    return V.pagedMessage(state[key], key)
  end

  local function packBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table",
      items = "table",
      give = "boolean",
      battle = "boolean",
      pocketIndex = "number",
      index = "number",
      scroll = "number",
      rows = "table",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.pocketIndex, "pocketIndex", 1, 4)
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.rows, "rows", 0)
    if not ok then return nil, code, detail end
    ok, code, detail = V.index(state.index, "index", #state.rows, 1)
    if not ok then return nil, code, detail end
    return V.nonNegative(state.scroll, "scroll")
  end

  local function packMode(state)
    if state.battle or (type(state.world) == "table" and state.world.battleActive) then
      return V.fail("battle_owned", "pack")
    end
    if state.submenu ~= nil then
      local ok, code, detail = V.fields(state.submenu, {
        row = "table", rows = "table", index = "number",
      })
      if not ok then return nil, code, detail end
      ok, code, detail = V.array(state.submenu.rows, "submenu.rows", 1,
        function(row) return V.type(row, "string", "submenu.row") end)
      if not ok then return nil, code, detail end
      ok, code, detail = V.index(state.submenu.index, "submenu.index",
        #state.submenu.rows)
      if not ok then return nil, code, detail end
    end
    if state.message ~= nil then
      local ok, code, detail = V.lines(state.message, "message")
      if not ok then return nil, code, detail end
    end
    if state.qtyState ~= nil then
      local ok, code, detail = V.fields(state.qtyState, {
        row = "table", qty = "number", max = "number",
      })
      if not ok then return nil, code, detail end
      ok, code, detail = V.integer(state.qtyState.max, "qtyState.max", 1)
      if not ok then return nil, code, detail end
      ok, code, detail = V.integer(state.qtyState.qty, "qtyState.qty", 1,
        state.qtyState.max)
      if not ok then return nil, code, detail end
    end
    if state.confirm ~= nil then
      local ok, code, detail = V.fields(state.confirm, {
        prompt = "table", choice = "number",
      })
      if not ok then return nil, code, detail end
      ok, code, detail = V.lines(state.confirm.prompt, "confirm.prompt")
      if not ok then return nil, code, detail end
      return V.integer(state.confirm.choice, "confirm.choice", 1, 2)
    end
    return true
  end

  local function partyBase(state)
    local ok, code, detail = V.fields(state, {
      party = "table",
      index = "number",
      prompt = "string",
      wantsSubmenu = "boolean",
      wantsBattleSubmenu = "boolean",
      items = "table",
      moves = "table",
      pokemon = "table",
    })
    if not ok then return nil, code, detail end
    return V.array(state.party, "party", 1, function(mon, index)
      return V.mon(mon, "party[" .. index .. "]")
    end)
  end

  local function partyMode(state)
    if state.wantsBattleSubmenu then return V.fail("battle_owned", "party") end
    if state.switchFrom ~= nil then
      local ok, code, detail = V.index(state.switchFrom, "switchFrom", #state.party)
      if not ok then return nil, code, detail end
      ok, code, detail = V.index(state.index, "index", #state.party)
      if not ok then return nil, code, detail end
    else
      local ok, code, detail = V.index(state.index, "index", #state.party, 1)
      if not ok then return nil, code, detail end
    end
    if state.submenu ~= nil then
      local ok, code, detail = V.fields(state.submenu, {
        items = "table", index = "number", mon = "table", slot = "number",
      })
      if not ok then return nil, code, detail end
      if state.submenu.battle then return V.fail("battle_owned", "party.submenu") end
      ok, code, detail = V.array(state.submenu.items, "submenu.items", 1)
      if not ok then return nil, code, detail end
      ok, code, detail = V.index(state.submenu.index, "submenu.index",
        #state.submenu.items)
      if not ok then return nil, code, detail end
      ok, code, detail = V.index(state.submenu.slot, "submenu.slot", #state.party)
      if not ok then return nil, code, detail end
      return V.mon(state.submenu.mon, "submenu.mon")
    end
    return true
  end

  local function summaryBase(state)
    local ok, code, detail = V.fields(state, {
      party = "table", index = "number", mon = "table", page = "number",
      moveScreen = "boolean", moveDetail = "boolean", moveIndex = "number",
      pokemon = "table", moves = "table", items = "table",
      palettes = "table", menuGfx = "table", icons = "table",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.party, "party", 1, function(mon, index)
      return V.mon(mon, "party[" .. index .. "]")
    end)
    if not ok then return nil, code, detail end
    ok, code, detail = V.index(state.index, "index", #state.party)
    if not ok then return nil, code, detail end
    ok, code, detail = V.mon(state.mon, "mon")
    if not ok then return nil, code, detail end
    return V.integer(state.page, "page", 1, 3)
  end

  local function summaryMode(state)
    local moves = type(state.mon.moves) == "table" and state.mon.moves or {}
    local maximum = math.max(1, #moves)
    local ok, code, detail = V.integer(state.moveIndex, "moveIndex", 1, maximum)
    if not ok then return nil, code, detail end
    if state.swapFrom ~= nil then
      return V.integer(state.swapFrom, "swapFrom", 1, maximum)
    end
    return true
  end

  local function pokedexBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table", data = "table", dex = "table", pokemon = "table",
      palettes = "table", rows = "table", modeIndex = "number",
      index = "number", scroll = "number", view = "string", page = "number",
      entryAction = "number", optionIndex = "number", searchIndex = "number",
      unownIndex = "number", searchType = "table",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.rows, "rows", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.modeIndex, "modeIndex", 1, 3)
    if not ok then return nil, code, detail end
    ok, code, detail = V.index(state.index, "index", #state.rows)
    if not ok then return nil, code, detail end
    ok, code, detail = V.nonNegative(state.scroll, "scroll")
    if not ok then return nil, code, detail end
    return V.array(state.searchType, "searchType", 2, function(value)
      return V.integer(value, "searchType", 0)
    end)
  end

  local function pokedexMode(state)
    local ok, code, detail = V.enum(state.view, "view",
      { "list", "entry", "area", "option", "search", "unown" })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.page, "page", 1, 2)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.entryAction, "entryAction", 1, 4)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.optionIndex, "optionIndex", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.searchIndex, "searchIndex", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.unownIndex, "unownIndex", 0)
    if not ok then return nil, code, detail end
    if state.searchResults ~= nil then
      ok, code, detail = V.array(state.searchResults, "searchResults", 0)
      if not ok then return nil, code, detail end
    end
    return V.optionalType(state.searchMessage, "string", "searchMessage")
  end

  local function trainerBase(state)
    local ok, code, detail = V.fields(state, { save = "table", page = "number", frames = "number" })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.page, "page", 1, 3)
    if not ok then return nil, code, detail end
    return V.number(state.frames, "frames", 0)
  end

  local function saveBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table", existed = "boolean", phase = "string", choice = "number",
    })
    if not ok then return nil, code, detail end
    return V.integer(state.choice, "choice", 1, 2)
  end

  local function saveMode(state)
    return V.enum(state.phase, "phase", { "confirm", "overwrite", "saving", "done" })
  end

  local function namingBase(state)
    local ok, code, detail = V.fields(state, {
      kind = "table", isBox = "boolean", maxLength = "number",
      prompt = "string", lower = "boolean", text = "string",
      col = "number", row = "number", tiles = "table",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.maxLength, "maxLength", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.nonNegative(state.col, "col")
    if not ok then return nil, code, detail end
    return V.nonNegative(state.row, "row")
  end

  local function centerPcBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table", items = "table", data = "table",
      entries = "table", index = "number",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.entries, "entries", 1)
    if not ok then return nil, code, detail end
    return V.index(state.index, "index", #state.entries)
  end

  local function centerPcMode(state)
    local ok, code, detail = optionalPaged(state, "message", false)
    if not ok then return nil, code, detail end
    if state.confirm ~= nil and type(state.confirm) ~= "table" then
      return V.fail("shape_type", "confirm:table")
    end
    return true
  end

  local function pcBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table", house = "boolean", entries = "table", index = "number",
      messageCloses = "boolean", changedDecorations = "boolean",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.entries, "entries", 1)
    if not ok then return nil, code, detail end
    return V.index(state.index, "index", #state.entries)
  end

  local function pcMode(state)
    if state.picking then return V.integer(state.pickIndex, "pickIndex", 1) end
    if state.pickIndex ~= nil and not V.isInteger(state.pickIndex) then
      return V.fail("shape_type", "pickIndex:integer")
    end
    if state.message ~= nil and type(state.message) ~= "string" then
      return V.fail("shape_type", "message:string")
    end
    if state.messagePages ~= nil then return V.lines(state.messagePages, "messagePages") end
    return true
  end

  local function boxBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table", mode = "string", boxIndex = "number",
      index = "number", scroll = "number", pokemon = "table",
      palettes = "table", menuGfx = "table", icons = "table",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.enum(state.mode, "mode", { "withdraw", "deposit", "move" })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.boxIndex, "boxIndex", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.index, "index", 1)
    if not ok then return nil, code, detail end
    return V.nonNegative(state.scroll, "scroll")
  end

  local function boxMode(state)
    local ok, code, detail = V.enum(state.phase, "phase", { "submenu", "insert" }, true)
    if not ok then return nil, code, detail end
    if state.phase == "submenu" then
      return V.integer(state.submenuIndex, "submenuIndex", 1)
    end
    return true
  end

  local function itemPcBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table", items = "table", entries = "table", index = "number",
      phase = "string", rows = "table", listIndex = "number",
      scroll = "number", house = "boolean",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.entries, "entries", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.index(state.index, "index", #state.entries)
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.rows, "rows", 0)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.listIndex, "listIndex", 1,
      math.max(1, #state.rows + 1))
    if not ok then return nil, code, detail end
    return V.nonNegative(state.scroll, "scroll")
  end

  local function itemPcMode(state)
    local ok, code, detail = V.enum(state.phase, "phase",
      { "menu", "deposit", "withdraw", "toss" })
    if not ok then return nil, code, detail end
    ok, code, detail = optionalPaged(state, "message", false)
    if not ok then return nil, code, detail end
    if state.qtyState ~= nil and type(state.qtyState) ~= "table" then
      return V.fail("shape_type", "qtyState:table")
    end
    if state.confirm ~= nil and type(state.confirm) ~= "table" then
      return V.fail("shape_type", "confirm:table")
    end
    if state.phase == "deposit" and type(state.pack) ~= "table" then
      return V.fail("nested_child_invalid", "pack")
    end
    return true
  end

  local function supported(id, module, family, preset, opaque, base, mode, gallery)
    return Record.new({
      id = id, module = module, support = "supported", milestone = "0.2.0",
      family = family, preset = preset, opaque = opaque,
      toggle = family == "storage" and "storage" or "pokemon",
      validateBase = base, validateMode = mode, gallery = gallery,
    })
  end

  return {
    supported("Gen2PackMenu", "src.ui.gen2.PackMenu", "inventory", "L", true,
      packBase, packMode, { "pockets", "actions", "quantity", "confirm", "message" }),
    supported("Gen2PartyMenu", "src.ui.gen2.PartyMenu", "party", "L", true,
      partyBase, partyMode, { "party", "cancel", "actions", "switch", "egg" }),
    supported("Gen2SummaryMenu", "src.ui.gen2.SummaryMenu", "summary", "L", true,
      summaryBase, summaryMode, { "status", "moves", "stats", "move_detail", "egg" }),
    supported("Gen2PokedexMenu", "src.ui.gen2.PokedexMenu", "pokedex", "L", true,
      pokedexBase, pokedexMode, { "list", "entry", "area", "options", "search", "unown" }),
    supported("Gen2TrainerCard", "src.ui.gen2.TrainerCard", "trainer", "L", true,
      trainerBase, nil, { "trainer", "johto_badges", "kanto_badges" }),
    supported("Gen2SaveMenu", "src.ui.gen2.SaveMenu", "core", "M", true,
      saveBase, saveMode, { "confirm", "overwrite", "saving", "done" }),
    supported("Gen2NamingScreen", "src.ui.gen2.NamingScreen", "naming", "XL", true,
      namingBase, nil, { "pokemon", "box", "name_rater", "caught" }),
    supported("Gen2CenterPcMenu", "src.ui.gen2.CenterPcMenu", "storage", "M", true,
      centerPcBase, centerPcMode, { "root", "message", "confirm" }),
    supported("Gen2PcMenu", "src.ui.gen2.PcMenu", "storage", "M", true,
      pcBase, pcMode, { "root", "box_picker", "message" }),
    supported("Gen2BoxMenu", "src.ui.gen2.BoxMenu", "storage", "XL", true,
      boxBase, boxMode, { "withdraw", "deposit", "move", "submenu", "insert" }),
    supported("Gen2ItemPcMenu", "src.ui.gen2.ItemPcMenu", "storage", "L", true,
      itemPcBase, itemPcMode, { "root", "withdraw", "deposit", "toss" }),
  }
end
