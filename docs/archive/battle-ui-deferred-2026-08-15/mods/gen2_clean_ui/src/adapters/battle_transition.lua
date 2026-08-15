return function(ctx)
  local Data = ctx.load("adapters.data")
  local Transition = {}

  local COLS, ROWS = 20, 18
  local FLASH_PALS = {
    { 3, 3, 2, 1 }, { 3, 3, 3, 2 }, { 3, 3, 3, 3 },
    { 3, 3, 3, 2 }, { 3, 3, 2, 1 }, { 3, 2, 1, 0 },
    { 2, 1, 0, 0 }, { 1, 0, 0, 0 }, { 0, 0, 0, 0 },
    { 1, 0, 0, 0 }, { 2, 1, 0, 0 }, { 3, 2, 1, 0 },
  }
  local POKEBALL_ROWS = {
    "......XXXX......", "....XXXXXXXX....",
    "..XXXX....XXXX..", "..XX........XX..",
    ".XX..........XX.", ".XX...XXXX...XX.",
    "XX...XX..XX...XX", "XXXXXX....XXXXXX",
    "XXXXXX....XXXXXX", "XX...XX..XX...XX",
    ".XX...XXXX...XX.", ".XX..........XX.",
    "..XX........XX..", "..XXXX....XXXX..",
    "....XXXXXXXX....", "......XXXX......",
  }

  local function overlay(x, y, w, h, color)
    return { x=x, y=y, w=w, h=h, color=color }
  end

  local function full(color)
    return overlay(0, 0, 1, 1, color)
  end

  local function blackGrid(state)
    local output = {}
    local black = rawget(state, "black")
    if type(black) ~= "table" then return output end
    for row = 0, ROWS - 1 do
      for col = 0, COLS - 1 do
        if black[row * COLS + col] == true then
          output[#output + 1] = overlay(col / COLS, row / ROWS,
            1 / COLS, 1 / ROWS, { 0, 0, 0, 1 })
        end
      end
    end
    return output
  end

  local function pokeball()
    local output = {}
    for row, bits in ipairs(POKEBALL_ROWS) do
      for col = 1, #bits do
        if bits:sub(col, col) == "X" then
          output[#output + 1] = overlay((col + 1) / COLS,
            (row - 1) / ROWS, 1 / COLS, 1 / ROWS, { 0.96, 0.86, 0.3, 1 })
        end
      end
    end
    return output
  end

  local function flash(state)
    if rawget(state, "phase") ~= "flash" then return nil end
    local frame = Data.integer(rawget(state, "frame"), 0)
    local pal = FLASH_PALS[math.floor(frame / 2) % #FLASH_PALS + 1]
    local sum = 0
    for _, shade in ipairs(pal) do sum = sum + shade end
    local veil = (sum - 6) / 6
    if veil > 0 then return full({ 0, 0, 0, math.abs(veil) }) end
    if veil < 0 then return full({ 1, 1, 1, math.abs(veil) }) end
    return nil
  end

  local function duration(style, phase)
    if phase == "pokeball" then return 2 end
    if phase == "flash" then return 72 end
    if phase == "black" then return 16 end
    if style == "spin" then return 40 end
    if style == "zoom" then return 9 end
    if style == "speckle" then return 16 end
    return 24
  end

  local function transitionOverlays(state)
    local phase = rawget(state, "phase")
    local style = Data.text(rawget(state, "style"), "spin")
    local output = blackGrid(state)
    local flashOverlay = flash(state)
    if flashOverlay then output[#output + 1] = flashOverlay end
    if phase == "pokeball" and rawget(state, "trainer") == true then
      for _, item in ipairs(pokeball()) do output[#output + 1] = item end
    elseif phase == "black" then
      output[#output + 1] = full({ 0, 0, 0, 1 })
    elseif phase == "outro" and style == "sine" then
      local step = Data.integer(rawget(state, "step"), 0)
      local alpha = math.min(0.85, step / 24 * 0.85)
      if alpha > 0 then output[#output + 1] = full({ 0, 0, 0, alpha }) end
    end
    return output
  end

  function Transition.extract(state)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local phase = rawget(state, "phase")
    local style = rawget(state, "style")
    if type(phase) ~= "string" or type(style) ~= "string" then
      return nil, "shape_type", "phase/style:string"
    end
    local frame = Data.integer(rawget(state, "frame"), 0)
    local model = {
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      id = "battle_transition", kind = "animation", preset = "ANIMATION",
      title = "BATTLE TRANSITION", opaque = false,
      animation = {
        id = "battle.transition", overlay = true, style = style,
        phase = phase, frame = frame,
        duration = duration(style, phase),
        progress = math.max(0, math.min(1,
          frame / math.max(1, duration(style, phase)))),
        overlays = transitionOverlays(state),
      },
    }
    return { model = model, actions = {} }
  end

  return Transition
end
