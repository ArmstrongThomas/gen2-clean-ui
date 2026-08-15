return function(ctx)
  local Data = ctx.load("adapters.data")
  local SharedTextBox = {}
  local collapsedPages = setmetatable({}, { __mode = "k" })

  local function glyphPrefix(text, count)
    if count <= 0 then return "" end
    local font = ctx.mod and ctx.mod.ui and ctx.mod.ui.Font
    local split = font and font.split
    if type(split) == "function" then
      local ok, spans = pcall(split, text)
      if ok and type(spans) == "table" then
        local span = spans[math.min(count, #spans)]
        return span and text:sub(1, span.to) or ""
      end
    end
    local position, seen, last = 1, 0, 0
    while position <= #text and seen < count do
      local byte = text:byte(position)
      local width = byte and byte >= 240 and 4
        or byte and byte >= 224 and 3
        or byte and byte >= 192 and 2 or 1
      last, position, seen = position + width - 1, position + width, seen + 1
    end
    return text:sub(1, last)
  end

  local function glyphCount(text)
    local font = ctx.mod and ctx.mod.ui and ctx.mod.ui.Font
    local split = font and font.split
    if type(split) == "function" then
      local ok, spans = pcall(split, text)
      if ok and type(spans) == "table" then return #spans end
    end
    local count, position = 0, 1
    while position <= #text do
      local byte = text:byte(position)
      local width = byte and byte >= 240 and 4
        or byte and byte >= 224 and 3
        or byte and byte >= 192 and 2 or 1
      position, count = position + width, count + 1
    end
    return count
  end

  local function glyphsFor(text)
    local output = {}
    for index = 1, glyphCount(text) do output[index] = 0 end
    return output
  end

  local function displayText(text)
    -- Host pages retain tile-font ligatures. Expand only after cutting at
    -- the source glyph boundary: expanding first would turn one <PK> glyph
    -- into several system-font characters and reveal the wrong prefix.
    text = tostring(text or "")
      :gsub("<PO>", "PO")
      :gsub("<KE>", "K\195\169")
      :gsub("<PK>", "POK\195\169")
      :gsub("<MN>", "MON")
      :gsub("#", "POK\195\169")
    return Data.text(text, "")
  end

  local function visibleLines(state)
    local pages = rawget(state, "pages")
    local pageIndex = Data.integer(rawget(state, "pageIndex"), 1)
    local page = type(pages) == "table" and rawget(pages, pageIndex) or nil
    if type(page) ~= "table" then return {} end
    local lineIndex = math.max(1, math.min(
      Data.integer(rawget(state, "lineIndex"), 1), #page))
    local shown = rawget(state, "shown")
    local current = type(shown) == "table" and rawget(shown, #shown) or nil
    -- A native CONT line is a pagination affordance, not authored prose.
    -- Once Clean UI sees that boundary, retain the complete source page while
    -- the host consumes the synthetic continuation advance and types its
    -- hidden final line. This prevents the already-reflowed sentence from
    -- appearing again as a second message during that handoff.
    local collapseContinuation = rawget(state, "waiting") == true
      and rawget(state, "contAdvance") == true
      and lineIndex < #page
    local collapsed = collapsedPages[state]
    if collapsed and collapsed.pageIndex ~= pageIndex then
      collapsed = nil
      collapsedPages[state] = nil
    end
    if collapseContinuation then
      collapsed = { pageIndex = pageIndex }
      collapsedPages[state] = collapsed
    end
    if collapsed then
      local output = {}
      for index = 1, #page do
        output[#output + 1] = displayText(tostring(page[index] or ""))
      end
      return output
    end

    local output = {}
    for index = 1, lineIndex do
      local text = tostring(rawget(page, index) or "")
      if index == lineIndex then
        -- Earlier lines on this source page are already fully revealed, even
        -- though the host keeps only its last two raster lines in `shown`.
        -- The active line still respects the live typewriter prefix.
        text = glyphPrefix(text, type(current) == "table" and #current or 0)
      end
      output[#output + 1] = displayText(text)
    end
    return output
  end

  function SharedTextBox.extract(state)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local done = rawget(state, "done") == true
    local waiting = rawget(state, "waiting") == true
    local passive = rawget(state, "stay") ~= nil or rawget(state, "auto") ~= nil
      or (rawget(state, "choice") ~= nil and done)
    local held = Data.integer(rawget(state, "holdFrames"), 0) > 0
    local preWait = Data.integer(rawget(state, "preWait"), 0) > 0
    local inputReady = not held and ((waiting and not preWait)
      or (done and not passive))
    return {
      model = {
        schema = "clean_ui.v3.presentation.v1",
        apiVersion = 3,
        screenId = "shared.TextBox",
        family = "dialogue",
        preset = "XS",
        lines = visibleLines(state),
        reflow = true,
        waiting = waiting,
        done = done,
        inputReady = inputReady,
        more = waiting or (done and not passive),
        controls = inputReady and "A/B CONTINUE" or "",
      },
      actions = { screenId="shared.TextBox", entries={}, order={} },
    }
  end

  function SharedTextBox.fixtures()
    local function state(lines, options)
      options = options or {}
      local shown = {}
      local first = math.max(1, #lines - 1)
      for index = first, #lines do
        shown[#shown + 1] = glyphsFor(tostring(lines[index] or ""))
      end
      local codes = shown[#shown] or {}
      return {
        pages = { lines }, pageIndex=1, lineIndex=#lines,
        charIndex=#codes, codes=codes, shown=shown,
        waiting=options.waiting == true, done=options.done == true,
        blink=0, boxTx=0, boxTy=12, boxTw=20, boxTh=6, maxCols=18,
      }
    end
    return {
      { variant="dialogue", state=state({
        "I like bugs, so", "I'm going back to train." }, { waiting=true }) },
      { variant="overflow", state=state({
        "This is a deliberately long dialogue fixture that verifies Clean UI",
        "reflows source control-code lines without bleeding outside the frame." },
        { done=true }) },
    }
  end

  return SharedTextBox
end
