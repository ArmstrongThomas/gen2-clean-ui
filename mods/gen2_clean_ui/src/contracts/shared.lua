return function(ctx)
  local V = ctx.load("contracts.validators")
  local Shared = {}

  local function textBoxBase(state, context)
    local ok, code, detail = V.fields(state, {
      game = "table", pages = "table", pageIndex = "number",
      lineIndex = "number", charIndex = "number", shown = "table",
      codes = "table",
      waiting = "boolean", done = "boolean", blink = "number",
      boxTx = "number", boxTy = "number", boxTw = "number",
      boxTh = "number", maxCols = "number",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.pages(state.pages, "pages")
    if not ok then return nil, code, detail end
    ok, code, detail = V.index(state.pageIndex, "pageIndex", #state.pages)
    if not ok then return nil, code, detail end
    local page = state.pages[state.pageIndex]
    ok, code, detail = V.integer(state.lineIndex, "lineIndex", 1, #page)
    if not ok then return nil, code, detail end
    ok, code, detail = V.nonNegative(state.charIndex, "charIndex")
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.codes, "codes", 0,
      function(value) return V.integer(value, "glyph", 0) end)
    if not ok then return nil, code, detail end
    ok, code, detail = V.number(state.boxTw, "boxTw", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.number(state.boxTh, "boxTh", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.number(state.maxCols, "maxCols", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.shown, "shown", 1)
    if not ok then return nil, code, detail end
    if #state.shown > 2 or #state.shown ~= math.min(2, state.lineIndex) then
      return V.fail("shape_range", "shown")
    end
    for index, line in ipairs(state.shown) do
      ok, code, detail = V.array(line, "shown[" .. index .. "]", 0,
        function(value) return V.integer(value, "glyph", 0) end)
      if not ok then return nil, code, detail end
    end
    if state.charIndex ~= #state.shown[#state.shown]
        or state.charIndex > #state.codes then
      return V.fail("shape_value", "charIndex/shown/codes")
    end
    for _, field in ipairs({ "contAdvance", "instant" }) do
      ok, code, detail = V.optionalType(state[field], "boolean", field)
      if not ok then return nil, code, detail end
    end
    for _, field in ipairs({ "choicePushed", "stayShown" }) do
      ok, code, detail = V.optionalType(state[field], "boolean", field)
      if not ok then return nil, code, detail end
    end
    for _, field in ipairs({ "holdFrames", "preWait" }) do
      if state[field] ~= nil then
        ok, code, detail = V.integer(state[field], field, 0)
        if not ok then return nil, code, detail end
      end
    end
    ok, code, detail = V.optionalType(state.scrollPx, "number", "scrollPx")
    if not ok then return nil, code, detail end
    ok, code, detail = V.optionalType(state.choice, "function", "choice")
    if not ok then return nil, code, detail end
    ok, code, detail = V.optionalType(state.auto, "table", "auto")
    if not ok then return nil, code, detail end
    ok, code, detail = V.optionalType(state.stay, "table", "stay")
    if not ok then return nil, code, detail end
    if context and context.game and state.game ~= context.game then
      return V.fail("shape_value", "game")
    end
    return true
  end

  local function choiceBoxBase(state, context)
    local ok, code, detail = V.fields(state, {
      game = "table", onChoose = "function", index = "number", noSound = "boolean",
      tx = "number", ty = "number", tw = "number", th = "number",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.index, "index", 1, 2)
    if not ok then return nil, code, detail end
    ok, code, detail = V.number(state.tw, "tw", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.number(state.th, "th", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.enum(state.anchor, "anchor", { "bottom" }, true)
    if not ok then return nil, code, detail end
    ok, code, detail = V.optionalType(state.pending, "boolean", "pending")
    if not ok then return nil, code, detail end
    if context and context.game and state.game ~= context.game then
      return V.fail("shape_value", "game")
    end
    if state.pending ~= nil then
      return V.integer(state.holdFrames, "holdFrames", 0)
    end
    return true
  end

  local function callerBase(state)
    local ok, code, detail = V.fields(state, {
      name = "string", isOpaque = "boolean", gen2CallerBox = "boolean",
    })
    if not ok then return nil, code, detail end
    if state.isOpaque or not state.gen2CallerBox then
      return V.fail("shape_value", "caller markers")
    end
    return V.optionalType(state.className, "string", "className")
  end

  function Shared.build()
    local records = {
      {
        id = "shared.TextBox",
        kind = "shared",
        module = "src.render.TextBox",
        uiClass = "TextBox",
        support = "supported",
        implementation = "ready",
        family = "dialogue",
        toggle = "dialogue",
        milestone = "0.1.0",
        preset = "XS",
        opaque = false,
        marker = "isTextBox",
        gallery = { "dialogue", "overflow" },
        validateBase = textBoxBase,
      },
      {
        id = "shared.ChoiceBox",
        kind = "shared",
        module = "src.ui.ChoiceBox",
        uiClass = "ChoiceBox",
        support = "supported",
        implementation = "ready",
        family = "dialogue",
        toggle = "dialogue",
        milestone = "0.1.0",
        preset = "XS",
        opaque = false,
        gallery = { "yes_no" },
        validateBase = choiceBoxBase,
      },
      {
        id = "gold.CallerBox",
        kind = "shared",
        module = "src.ui.gen2.CallerBox",
        uiClass = "CallerBox",
        support = "native",
        implementation = "pending_native",
        family = "pokegear",
        milestone = "0.3.0",
        nativeReason = "The public host API does not expose a proven exact CallerBox identity seam.",
        preset = "XS",
        opaque = false,
        marker = "gen2CallerBox",
        validateBase = callerBase,
      },
    }
    local byId = {}
    for _, record in ipairs(records) do byId[record.id] = record end
    return {
      records = records,
      byId = byId,
      denyAnonymous = { PrizeMenu = true },
    }
  end

  return Shared
end
