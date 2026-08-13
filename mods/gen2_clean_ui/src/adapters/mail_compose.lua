return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.specialty_common")
  local MailCompose = {}

  local UPPER = {
    { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J" },
    { "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T" },
    { "U", "V", "W", "X", "Y", "Z", " ", ",", "?", "!" },
    { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
    { "<PK>", "<MN>", "<PO>", "<KE>", "é", "♂", "♀", "¥", "…", "×" },
  }
  local LOWER = {
    { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" },
    { "k", "l", "m", "n", "o", "p", "q", "r", "s", "t" },
    { "u", "v", "w", "x", "y", "z", " ", ".", "-", "/" },
    { "'d", "'l", "'m", "'r", "'s", "'t", "'v", "&", "(", ")" },
    { "“", "”", "[", "]", "'", ":", ";", " ", " ", " " },
  }

  local function bottomTarget(col)
    if col < 3 then return 1, "case" end
    if col < 6 then return 2, "delete" end
    return 3, "end"
  end

  function MailCompose.extract(state)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    local text = rawget(state, "text")
    local lower = rawget(state, "lower")
    local row = Common.integer(rawget(state, "row"), 0, 5)
    local col = Common.integer(rawget(state, "col"), 0, 9)
    if type(text) ~= "string" then return Common.fail("shape_type", "text:string") end
    if type(lower) ~= "boolean" then return Common.fail("shape_type", "lower:boolean") end
    if type(rawget(state, "tiles")) ~= "table"
        or (rawget(state, "gfx") ~= nil and type(rawget(state, "gfx")) ~= "table") then
      return Common.fail("shape_type", "tiles/gfx")
    end
    if not row then return Common.fail("cursor_invalid", "row") end
    if not col then return Common.fail("cursor_invalid", "col") end
    local chars = Common.characters(text)
    if #chars > 32 then return Common.fail("entry_too_long", tostring(#chars)) end
    local entryLines = {
      table.concat(chars, "", 1, math.min(16, #chars)),
      #chars > 16 and table.concat(chars, "", 17, #chars) or "",
    }

    local board = lower and LOWER or UPPER
    local targetIndex, target = bottomTarget(col)
    local value = row == 5 and target or rawget(rawget(board, row + 1), col + 1)
    local actions = Common.actionMap("Gen2MailCompose", {
      { input="left", id="cursor.left", kind="navigate" },
      { input="right", id="cursor.right", kind="navigate" },
      { input="up", id="cursor.up", kind="navigate" },
      { input="down", id="cursor.down", kind="navigate" },
      { input="a", id="entry.choose", kind="choose" },
      { input="b", id="entry.delete", kind="delete" },
      { input="select", id="entry.toggle_case", kind="toggle_case" },
      { input="start", id="entry.focus_end", kind="focus_end" },
    })
    return Common.bundle("Gen2MailCompose", {
      family="mail", preset="XL", title="COMPOSE MAIL", mode="compose",
      entry={ text=text, lines=entryLines, length=#chars,
        maximum=32, lineLength=16 },
      case=lower and "lower" or "upper",
      keyboard={ columns=10, letterRows=5, rows=Data.copy(board), bottom={
        { id="case", label=lower and "UPPER" or "lower", colStart=0, colEnd=2 },
        { id="delete", label="DEL", colStart=3, colEnd=5 },
        { id="end", label="END", colStart=6, colEnd=9 },
      } },
      cursor={ zeroBased=true, row=row, col=col, bottomRow=row == 5,
        target=row == 5 and target or nil,
        targetIndex=row == 5 and targetIndex or nil,
        value=Data.text(value, "") },
      controls={ a="TYPE/CHOOSE", b="DELETE", select="CASE", start="END" },
    }, actions)
  end

  return MailCompose
end
