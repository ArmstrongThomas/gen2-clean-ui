return function(ctx)
  local Record = ctx.load("contracts.record")
  local V = ctx.load("contracts.validators")

  local function optionalPaged(state, key, confirm)
    if state[key] == nil then return true end
    if confirm then return V.pagedConfirm(state[key], key) end
    return V.pagedMessage(state[key], key)
  end

  local function bankBase(state)
    local ok, code, detail = V.fields(state, {
      kind = "string", saved = "number", held = "number", amount = "number",
      position = "number", blink = "number",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.enum(state.kind, "kind", { "deposit", "withdraw" })
    if not ok then return nil, code, detail end
    for _, key in ipairs({ "saved", "held", "amount" }) do
      ok, code, detail = V.number(state[key], key, 0)
      if not ok then return nil, code, detail end
    end
    ok, code, detail = V.integer(state.position, "position", 0, 5)
    if not ok then return nil, code, detail end
    return V.number(state.blink, "blink", 0)
  end

  local function contestBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table", stock = "table", caught = "table", choice = "number",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.mon(state.stock, "stock")
    if not ok then return nil, code, detail end
    ok, code, detail = V.mon(state.caught, "caught")
    if not ok then return nil, code, detail end
    return V.integer(state.choice, "choice", 1, 2)
  end

  local function daycareBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table", data = "table", textData = "table", TEXT = "table",
      side = "string", scriptVar = "number", delay = "number",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.enum(state.side, "side", { "man", "lady", "outside" })
    if not ok then return nil, code, detail end
    ok, code, detail = V.number(state.scriptVar, "scriptVar")
    if not ok then return nil, code, detail end
    return V.number(state.delay, "delay", 0)
  end

  local function daycareMode(state)
    local ok, code, detail = optionalPaged(state, "message", false)
    if not ok then return nil, code, detail end
    ok, code, detail = optionalPaged(state, "confirm", true)
    if not ok then return nil, code, detail end
    if state.picking and type(state.picking) ~= "boolean" then
      return V.fail("shape_type", "picking:boolean")
    end
    return true
  end

  local function decorationBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table", state = "table", changed = "boolean", mode = "string",
      index = "number", scroll = "number", categories = "table",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.enum(state.mode, "mode", { "category", "items", "side" })
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.categories, "categories", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.index, "index", 1)
    if not ok then return nil, code, detail end
    return V.nonNegative(state.scroll, "scroll")
  end

  local function decorationMode(state)
    if state.mode == "items" then
      local ok, code, detail = V.array(state.rows, "rows", 0, function(row)
        return V.type(row, "string", "rows.item")
      end)
      if not ok then return nil, code, detail end
    elseif state.mode == "side" then
      local ok, code, detail = V.integer(state.sideIndex, "sideIndex", 1)
      if not ok then return nil, code, detail end
    end
    if state.pages ~= nil then
      local ok, code, detail = V.pages(state.pages, "pages")
      if not ok then return nil, code, detail end
      return V.index(state.pageIndex, "pageIndex", #state.pages)
    end
    return true
  end

  local function diplomaBase(state)
    local ok, code, detail = V.fields(state, {
      playerName = "string", images = "table", done = "boolean",
    })
    if not ok then return nil, code, detail end
    return V.optionalType(state.gfx, "table", "gfx")
  end

  local function elevatorBase(state)
    local ok, code, detail = V.fields(state, {
      floors = "table", index = "number", scroll = "number",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.floors, "floors", 1, function(row)
      return V.fields(row, { destMap = { "string", "number" }, floorId = { "string", "number" } })
    end)
    if not ok then return nil, code, detail end
    ok, code, detail = V.index(state.index, "index", #state.floors)
    if not ok then return nil, code, detail end
    ok, code, detail = V.nonNegative(state.scroll, "scroll")
    if not ok then return nil, code, detail end
    if state.origin ~= nil then return V.index(state.origin, "origin", #state.floors) end
    return true
  end

  local function hallBase(state)
    local ok, code, detail = V.fields(state, {
      mode = "string", save = "table", index = "number", phase = "string",
      pokemon = "table", palettes = "table", frames = "number", done = "boolean",
    })
    if not ok then return nil, code, detail end
    return V.enum(state.mode, "mode", { "view", "induct" })
  end

  local function hallMode(state)
    if state.mode ~= "view" or state.phase ~= "display" then
      return V.fail("native_scope", "hall_of_fame_induction")
    end
    if type(state.entry) ~= "table" or type(state.entry.mons) ~= "table" then
      return V.fail("shape_missing", "entry.mons")
    end
    local ok, code, detail = V.integer(state.team, "team", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.entry.mons, "entry.mons", 1)
    if not ok then return nil, code, detail end
    return V.index(state.index, "index", #state.entry.mons)
  end

  local function heldBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table", slot = "number", items = "table",
      index = "number", busy = "boolean",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.slot, "slot", 1)
    if not ok then return nil, code, detail end
    return V.integer(state.index, "index", 1, 2)
  end

  local function heldMode(state)
    local ok, code, detail = optionalPaged(state, "message", false)
    if not ok then return nil, code, detail end
    return optionalPaged(state, "confirm", true)
  end

  local function clockBase(state)
    local ok, code, detail = V.fields(state, {
      mode = "string", save = "table", autoConfirm = "boolean",
      hour = "number", minute = "number", day = "number",
      yesNo = "number", phase = "string", page = "number",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.enum(state.mode, "mode", { "clock", "day" })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.hour, "hour", 0, 23)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.minute, "minute", 0, 59)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.day, "day", 0, 6)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.yesNo, "yesNo", 1, 2)
    if not ok then return nil, code, detail end
    return V.integer(state.page, "page", 1)
  end

  local function clockMode(state)
    return V.enum(state.phase, "phase", {
      "intro", "hour", "minute", "day", "confirm-hour",
      "confirm-minute", "confirm-day", "response",
    })
  end

  local function mailComposeBase(state)
    local ok, code, detail = V.fields(state, {
      text = "string", lower = "boolean", row = "number",
      col = "number", tiles = "table",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.row, "row", 0, 5)
    if not ok then return nil, code, detail end
    return V.integer(state.col, "col", 0, 9)
  end

  local function mailMenuBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table", slot = "number", index = "number", reading = "boolean",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.slot, "slot", 1)
    if not ok then return nil, code, detail end
    return V.integer(state.index, "index", 1, 3)
  end

  local function mailMenuMode(state)
    local ok, code, detail = optionalPaged(state, "message", false)
    if not ok then return nil, code, detail end
    return optionalPaged(state, "confirm", true)
  end

  local function mailReadBase(state)
    return V.fields(state, { entry = "table" })
  end

  local function mailboxBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table", index = "number", scroll = "number", picking = "boolean",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.index, "index", 1)
    if not ok then return nil, code, detail end
    return V.nonNegative(state.scroll, "scroll")
  end

  local function mailboxMode(state)
    if state.submenu ~= nil then
      local ok, code, detail = V.fields(state.submenu, { index = "number" })
      if not ok then return nil, code, detail end
      ok, code, detail = V.integer(state.submenu.index, "submenu.index", 1, 4)
      if not ok then return nil, code, detail end
    end
    local ok, code, detail = optionalPaged(state, "message", false)
    if not ok then return nil, code, detail end
    return optionalPaged(state, "confirm", true)
  end

  local function mapRadioBase(state)
    local ok, code, detail = V.fields(state, {
      gear = "table", station = "string", radio = "table", hold = "number",
    })
    if not ok then return nil, code, detail end
    return V.number(state.hold, "hold", 0)
  end

  local function martBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table", items = "table", marts = "table", martType = "string",
      martId = "number", entries = "table", index = "number",
      scroll = "number", phase = "string",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.enum(state.martType, "martType",
      { "STANDARD", "BITTER", "BARGAIN", "PHARMACY" })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.martId, "martId", 0)
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.entries, "entries", 0)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.index, "index", 1,
      math.max(1, #state.entries + 1))
    if not ok then return nil, code, detail end
    return V.nonNegative(state.scroll, "scroll")
  end

  local function martMode(state)
    local ok, code, detail = V.enum(state.phase, "phase", {
      "top", "intro", "outro", "buy", "buyQuantity", "sell", "sellQuantity",
    })
    if not ok then return nil, code, detail end
    if state.phase == "sell" or state.phase == "sellQuantity" then
      if type(state.pack) ~= "table" then return V.fail("nested_child_invalid", "pack") end
    end
    ok, code, detail = optionalPaged(state, "message", false)
    if not ok then return nil, code, detail end
    return optionalPaged(state, "confirm", true)
  end

  local function deleterBase(state)
    local ok, code, detail = V.fields(state, {
      mon = "table", moves = "table", list = "table", row = "number",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.mon(state.mon, "mon")
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.list, "list", 1)
    if not ok then return nil, code, detail end
    return V.index(state.row, "row", #state.list)
  end

  local function namePickBase(state)
    local ok, code, detail = V.fields(state, {
      items = "table", cursor = "number", picX = "number", fontOk = "boolean",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.items, "items", 1, function(item)
      return V.type(item, "string", "items.name")
    end)
    if not ok then return nil, code, detail end
    ok, code, detail = V.index(state.cursor, "cursor", #state.items)
    if not ok then return nil, code, detail end
    return V.enum(state.slide, "slide", { "in", "out" }, true)
  end

  local function photoBase(state)
    local ok, code, detail = V.fields(state, {
      mon = "table", playerName = "string", pokemon = "table",
      moves = "table", palettes = "table", done = "boolean", picCache = "table",
    })
    if not ok then return nil, code, detail end
    return V.mon(state.mon, "mon")
  end

  local function pokegearBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table", cards = "table", cardIndex = "number", mode = "string",
      station = "number", phoneCursor = "number", phoneScroll = "number",
      phoneSubmenuCursor = "number", radioOn = "boolean",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.cards, "cards", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.index(state.cardIndex, "cardIndex", #state.cards)
    if not ok then return nil, code, detail end
    ok, code, detail = V.enum(state.mode, "mode", { "strip", "card" })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.station, "station", 1)
    if not ok then return nil, code, detail end
    for _, key in ipairs({ "phoneCursor", "phoneScroll", "phoneSubmenuCursor" }) do
      ok, code, detail = V.nonNegative(state[key], key)
      if not ok then return nil, code, detail end
    end
    return true
  end

  local function pokegearMode(state)
    local ok, code, detail = V.enum(state.phoneSubmenu, "phoneSubmenu",
      { "callDeleteCancel", "callCancel" }, true)
    if not ok then return nil, code, detail end
    if state.fly ~= nil then
      ok, code, detail = V.integer(state.flyIndex, "flyIndex", 1)
      if not ok then return nil, code, detail end
    end
    if state.call ~= nil and type(state.call) ~= "table" then
      return V.fail("shape_type", "call:table")
    end
    return true
  end

  local function scriptBase(state)
    local ok, code, detail = V.fields(state, {
      header = "table", style = "string", items = "table", rows = "number",
      cols = "number", spacing = "number", textX = "number", textY = "number",
      showCursor = "boolean", row = "number", col = "number", wrap = "boolean",
      pageJump = "boolean", keyRepeat = "boolean", repeatDelay = "number",
      repeatRate = "number",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.enum(state.style, "style", { "vertical", "2d" })
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.items, "items", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.rows, "rows", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.cols, "cols", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.row, "row", 1, state.rows)
    if not ok then return nil, code, detail end
    return V.integer(state.col, "col", 1, state.cols)
  end

  local function tradeBase(state)
    local ok, code, detail = V.fields(state, {
      save = "table", data = "table", eventTables = "table",
      id = "number", row = "table",
    })
    if not ok then return nil, code, detail end
    return V.integer(state.id, "id", 0, 5)
  end

  local function tradeMode(state)
    if state.animating then return V.fail("native_child", "Gen2TradeAnim") end
    local ok, code, detail = optionalPaged(state, "message", false)
    if not ok then return nil, code, detail end
    return optionalPaged(state, "confirm", true)
  end

  local function printerBase(state)
    local ok, code, detail = V.fields(state, {
      pokemon = "table", palettes = "table", index = "number",
      done = "boolean", picCache = "table",
    })
    if not ok then return nil, code, detail end
    return V.integer(state.index, "index", 0, 26)
  end

  local function supported(id, module, preset, opaque, base, mode, gallery, extra)
    local spec = {
      id = id, module = module, support = "supported", milestone = "0.3.0",
        family = "services", preset = preset, opaque = opaque,
        toggle = "services", validateBase = base, validateMode = mode,
        gallery = gallery, presentationApi = 3,
    }
    for key, value in pairs(extra or {}) do spec[key] = value end
    return Record.new(spec)
  end

  return {
    supported("Gen2BankOfMom", "src.ui.gen2.BankOfMom", "XS", false,
      bankBase, nil, { "deposit", "withdraw" }),
    supported("Gen2ContestMenu", "src.ui.gen2.ContestMenu", "L", true,
      contestBase, nil, { "compare" }),
    supported("Gen2DayCareMenu", "src.ui.gen2.DayCareMenu", "L", false,
      daycareBase, daycareMode, { "message", "confirm", "party_picker" }),
    supported("Gen2DecorationMenu", "src.ui.gen2.DecorationMenu", "L", true,
      decorationBase, decorationMode, { "category", "items", "side", "message" }),
    supported("Gen2Diploma", "src.ui.gen2.Diploma", "L", true,
      diplomaBase, nil, { "diploma" }),
    supported("Gen2ElevatorMenu", "src.ui.gen2.ElevatorMenu", "S", false,
      elevatorBase, nil, { "floors" }),
    supported("Gen2HallOfFame", "src.ui.gen2.HallOfFame", "L", true,
      hallBase, hallMode, { "viewer", "induction_native" },
      { scope = "viewer_only" }),
    supported("Gen2HeldItemMenu", "src.ui.gen2.HeldItemMenu", "L", false,
      heldBase, heldMode, { "give_take", "message", "confirm" }),
    supported("Gen2InitClock", "src.ui.gen2.InitClock", "M", true,
      clockBase, clockMode, { "clock", "day", "confirm" }),
    supported("Gen2MailCompose", "src.ui.gen2.MailCompose", "XL", true,
      mailComposeBase, nil, { "compose" }),
    supported("Gen2MailMenu", "src.ui.gen2.MailMenu", "M", false,
      mailMenuBase, mailMenuMode, { "actions", "message", "confirm" }),
    supported("Gen2MailRead", "src.ui.gen2.MailRead", "M", true,
      mailReadBase, nil, { "read" }),
    supported("Gen2MailboxMenu", "src.ui.gen2.MailboxMenu", "M", false,
      mailboxBase, mailboxMode, { "list", "submenu", "message", "confirm" }),
    -- Official MartMenu keeps the overworld visible underneath the shop
    -- surface (`MartMenu.isOpaque = false`). A true value makes identity
    -- validation reject every live Mart state as opacity_mismatch.
    supported("Gen2MartMenu", "src.ui.gen2.MartMenu", "L", false,
      martBase, martMode, { "standard", "buy", "herb", "bargain", "pharmacy",
        "sell", "sell_quantity" }),
    supported("Gen2MoveDeleter", "src.ui.gen2.MoveDeleter", "L", false,
      deleterBase, nil, { "moves" }),
    supported("Gen2NamePick", "src.ui.gen2.NamePick", "M", true,
      namePickBase, nil, { "presets", "slide" }),
    supported("Gen2PhotoStudio", "src.ui.gen2.PhotoStudio", "L", true,
      photoBase, nil, { "photo" }),
    supported("Gen2ScriptMenu", "src.ui.gen2.ScriptMenu", "M", false,
      scriptBase, nil, { "vertical", "grid", "money", "coins", "prizes" }),
    supported("Gen2TradeMenu", "src.ui.gen2.TradeMenu", "L", false,
      tradeBase, tradeMode, { "offer", "confirm", "party_picker" }),
    supported("Gen2UnownPrinter", "src.ui.gen2.UnownPrinter", "L", true,
      printerBase, nil, { "forms" }),
  }
end
