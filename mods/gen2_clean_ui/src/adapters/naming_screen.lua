return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.storage_common")
  local Naming = {}

  local NAME_UPPER = {
    { "A", "B", "C", "D", "E", "F", "G", "H", "I" },
    { "J", "K", "L", "M", "N", "O", "P", "Q", "R" },
    { "S", "T", "U", "V", "W", "X", "Y", "Z", " " },
    { "-", "?", "!", "/", ".", ",", " ", " ", " " },
  }
  local NAME_LOWER = {
    { "a", "b", "c", "d", "e", "f", "g", "h", "i" },
    { "j", "k", "l", "m", "n", "o", "p", "q", "r" },
    { "s", "t", "u", "v", "w", "x", "y", "z", " " },
    { "\xc3\x97", "(", ")", ":", ";", "[", "]", "<PK>", "<MN>" },
  }
  local BOX_UPPER = {
    NAME_UPPER[1], NAME_UPPER[2], NAME_UPPER[3],
    { "\xc3\x97", "(", ")", ":", ";", "[", "]", "<PK>", "<MN>" },
    { "-", "?", "!", "\xe2\x99\x82", "\xe2\x99\x80", "/", ".", ",", "&" },
  }
  local BOX_LOWER = {
    NAME_LOWER[1], NAME_LOWER[2], NAME_LOWER[3],
    { "\xc3\xa9", "'d", "'l", "'m", "'r", "'s", "'t", "'v", "0" },
    { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
  }
  local BOTTOM_CURSOR_X = { 2, 8, 14 }
  local BOTTOM_LABEL_X = { 2, 9, 15 }

  local function sourceImagePath(value)
    if type(value) ~= "string"
        or value:sub(1, 17) ~= "assets/generated/"
        or value:sub(-4):lower() ~= ".png"
        or value:find("..", 1, true)
        or value:find("\\", 1, true)
        or value:find(":", 1, true) then
      return nil
    end
    return value
  end

  local function palette(value)
    if type(value) ~= "table" then return nil end
    local output = {}
    for colorIndex = 1, 4 do
      local source = rawget(value, colorIndex)
      if type(source) ~= "table" then return nil end
      local color = {}
      for channel = 1, 3 do
        local number = rawget(source, channel)
        if type(number) ~= "number" or number ~= math.floor(number)
            or number < 0 or number > 255 then return nil end
        color[channel] = number
      end
      output[colorIndex] = color
    end
    return output
  end

  local function copyGrid(source)
    local output = {}
    for row = 1, #source do
      output[row] = {}
      for col = 1, 9 do output[row][col] = source[row][col] end
    end
    return output
  end

  local function layout(isBox, lower)
    if isBox then return copyGrid(lower and BOX_LOWER or BOX_UPPER) end
    return copyGrid(lower and NAME_LOWER or NAME_UPPER)
  end

  local function targetFor(col)
    if col < 3 then return 1 end
    if col < 6 then return 2 end
    return 3
  end

  local function contextName(state)
    if rawget(state, "isBox") == true then return "box" end
    if rawget(state, "monName") ~= nil then return "nickname" end
    local prompt = Data.text(rawget(state, "prompt"), "")
    if prompt == "YOUR NAME?" then return "player" end
    if prompt == "RIVAL'S NAME?" then return "rival" end
    if prompt == "MOTHER'S NAME?" then return "mom" end
    return "nickname"
  end

  local function spriteMetadata(state)
    local sourcePath = Data.scalar(rawget(state, "iconPath"))
      or Data.scalar(rawget(state, "spritePath"))
    local path = sourcePath and sourceImagePath(sourcePath) or nil
    local nativeImageAvailable = rawget(state, "iconImage") ~= nil
    if sourcePath and not path then
      return nil, "sprite_path_invalid", tostring(sourcePath)
    end
    if nativeImageAvailable and not path then
      return nil, "sprite_path_missing", "native image has no source path"
    end
    local colors = rawget(state, "iconColors")
    local safePalette = colors ~= nil and palette(colors) or nil
    if colors ~= nil and not safePalette then
      return nil, "sprite_palette_invalid", "iconColors"
    end
    if path and not safePalette then
      return nil, "sprite_palette_missing", path
    end
    local supplied = Data.copy(rawget(state, "iconMetadata"))
      or Data.copy(rawget(state, "spriteMetadata"))
    return {
      path = path,
      palette = safePalette,
      metadata = supplied,
      nativeImageAvailable = nativeImageAvailable,
      callerProvided = path ~= nil or colors ~= nil
        or supplied ~= nil or nativeImageAvailable,
    }
  end

  local function cursorSnapshot(board, col, row, keyboardTop)
    local bottomRow = #board
    if row == bottomRow then
      local target = targetFor(col)
      local ids = { "case", "delete", "end" }
      return {
        zeroBased = true, col = col, row = row, bottomRow = true,
        target = ids[target], targetIndex = target,
        tile = { x=BOTTOM_CURSOR_X[target],
          y=keyboardTop + bottomRow * 2, width=5, height=1 },
      }
    end
    local sourceRow = board[row + 1]
    return {
      zeroBased = true, col = col, row = row, bottomRow = false,
      value = sourceRow and sourceRow[col + 1] or nil,
      tile = { x=2 + col * 2, y=keyboardTop + row * 2,
        width=1, height=1 },
    }
  end

  function Naming.extract(state)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local col = Data.integer(rawget(state, "col"))
    local row = Data.integer(rawget(state, "row"))
    local maxLength = Data.integer(rawget(state, "maxLength"))
    if col == nil or col < 0 or col > 8 then
      return nil, "cursor_invalid", "col"
    end
    local isBox = rawget(state, "isBox") == true
    local lower = rawget(state, "lower") == true
    local board = layout(isBox, lower)
    if row == nil or row < 0 or row > #board then
      return nil, "cursor_invalid", "row"
    end
    if maxLength == nil or maxLength < 1 then
      return nil, "length_invalid", "maxLength"
    end

    local keyboardTop = isBox and 6 or 8
    local actionMap = Common.inputActions("Gen2NamingScreen", {
      { input="left", id="cursor.left", kind="navigate" },
      { input="right", id="cursor.right", kind="navigate" },
      { input="up", id="cursor.up", kind="navigate" },
      { input="down", id="cursor.down", kind="navigate" },
      { input="a", id="entry.activate", kind="type_or_activate" },
      { input="select", id="entry.case", kind="toggle_case" },
      { input="b", id="entry.delete", kind="delete" },
      { input="start", id="entry.focus_end", kind="focus_end" },
    })
    local labels = lower and { "UPPER", "DEL", "END" }
      or { "lower", "DEL", "END" }
    local bottom = {}
    for index = 1, 3 do
      bottom[index] = {
        id = ({ "case", "delete", "end" })[index],
        label = labels[index],
        colStart = (index - 1) * 3,
        colEnd = (index - 1) * 3 + 2,
        cursorTileX = BOTTOM_CURSOR_X[index],
        labelTileX = BOTTOM_LABEL_X[index],
        tileY = keyboardTop + #board * 2,
        tileWidth = 5,
      }
    end

    local sprite, spriteCode, spriteDetail = spriteMetadata(state)
    if not sprite then return nil, spriteCode, spriteDetail end
    local model = {
      schema = "clean_ui.presenter_model.v1",
      screenId = "Gen2NamingScreen",
      family = "naming",
      preset = "XL",
      context = contextName(state),
      isBox = isBox,
      prompt = Data.text(rawget(state, "prompt"), "NICKNAME?"),
      monName = Data.text(rawget(state, "monName"), ""),
      entry = {
        text = Data.text(rawget(state, "text"), ""),
        maxLength = maxLength,
        -- The source screen itself uses byte length; preserve that exact
        -- cursor/full-field contract rather than silently changing behavior.
        sourceLength = #(tostring(rawget(state, "text") or "")),
        tile = { x=5, y=isBox and 4 or 6 },
      },
      case = lower and "lower" or "upper",
      keyboard = {
        topTile = keyboardTop,
        columns = 9,
        letterRows = #board,
        rows = board,
        bottom = bottom,
        stockLayouts = {
          upper = layout(isBox, false),
          lower = layout(isBox, true),
        },
      },
      cursor = cursorSnapshot(board, col, row, keyboardTop),
      sprite = sprite,
      kindMetadata = Data.copy(rawget(state, "kind")),
    }
    model.actionDescriptors = Common.describe(actionMap)
    return { model=model, actions=actionMap }
  end

  return Naming
end
