return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.service_common")
  local ScriptMenu = {}

  local SCREEN_ID = "Gen2ScriptMenu"
  local BALANCES = { coins=true, money=true, moneycoins=true }

  local function headerSnapshot(source)
    if type(source) ~= "table" then
      return Common.fail("shape_type", "header:table")
    end
    local output = {}
    for _, field in ipairs({ "left", "top", "right", "bottom" }) do
      local value = Common.integer(rawget(source, field), 0, 255)
      if value == nil then
        return Common.fail("shape_range", "header." .. field)
      end
      output[field] = value
    end
    if output.right < output.left or output.bottom < output.top then
      return Common.fail("shape_range", "header.bounds")
    end
    output.dataFlags = Common.integer(rawget(source, "dataFlags"), 0, 255) or 0
    output.cursor = Common.integer(rawget(source, "cursor"), 1) or 1
    return output
  end

  function ScriptMenu.extract(state, context)
    local ok, code, detail = Common.exactState(state, SCREEN_ID)
    if not ok then return nil, code, detail end
    if Common.inBattle(context) then return nil, "battle_owned", SCREEN_ID end
    local style = rawget(state, "style")
    if style ~= "vertical" and style ~= "2d" then
      return Common.fail("unknown_mode", "style=" .. tostring(style))
    end
    local sourceItems = rawget(state, "items")
    local count
    count, code, detail = Common.array(sourceItems, 1, 128, "items")
    if not count then return nil, code, detail end
    local rows = Common.integer(rawget(state, "rows"), 1, 128)
    local cols = Common.integer(rawget(state, "cols"), 1, 128)
    local row = rows and Common.integer(rawget(state, "row"), 1, rows)
    local col = cols and Common.integer(rawget(state, "col"), 1, cols)
    local spacing = Common.integer(rawget(state, "spacing"), 0, 255)
    local textX = Common.integer(rawget(state, "textX"), 0, 255)
    local textY = Common.integer(rawget(state, "textY"), 0, 255)
    if not (rows and cols and row and col and spacing and textX and textY) then
      return Common.fail("shape_range", "grid")
    end
    if style == "vertical" and cols ~= 1 then
      return Common.fail("shape_conflict", "vertical.cols")
    end
    if rows * cols < count then
      return Common.fail("shape_range", "grid.capacity")
    end
    local selectedIndex = (row - 1) * cols + col
    if selectedIndex > count then
      return Common.fail("shape_range", "grid.selection")
    end
    local header
    header, code, detail = headerSnapshot(rawget(state, "header"))
    if not header then return nil, code, detail end
    local balance = rawget(state, "balance")
    if balance ~= nil and (type(balance) ~= "string" or not BALANCES[balance]) then
      return Common.fail("unknown_mode", "balance=" .. tostring(balance))
    end
    for _, field in ipairs({ "showCursor", "wrap", "pageJump", "keyRepeat" }) do
      if type(rawget(state, field)) ~= "boolean" then
        return Common.fail("shape_type", field .. ":boolean")
      end
    end
    local repeatDelay = Common.integer(rawget(state, "repeatDelay"), 0)
    local repeatRate = Common.integer(rawget(state, "repeatRate"), 1)
    if not repeatDelay or not repeatRate then
      return Common.fail("shape_range", "repeat")
    end

    local actions = Common.inputActions(SCREEN_ID, {
      { input="up", kind="navigate" },
      { input="down", kind="navigate" },
      { input="left", kind="navigate" },
      { input="right", kind="navigate" },
      { input="a", kind="choose" },
      { input="b", kind="cancel" },
    })
    local items = {}
    for index = 1, count do
      local label = rawget(sourceItems, index)
      if type(label) ~= "string" then
        return Common.fail("shape_type", "items[" .. index .. "]:string")
      end
      local sourceRow = math.floor((index - 1) / cols) + 1
      local sourceCol = (index - 1) % cols + 1
      items[index] = {
        id="choice_" .. index, sourceIndex=index,
        sourceRow=sourceRow, sourceCol=sourceCol,
        label=Data.text(label, "?"), selected=index == selectedIndex,
        actionId=Common.sourceInput(actions, "choice." .. index,
          "choose", "choice_" .. index, "a", index),
      }
    end
    local player = Common.player(state)
    local model = {
      schema="clean_ui.presenter_model.v1",
      screenId=SCREEN_ID, family="services", preset="M",
      title="SCRIPT MENU", style=style,
      variant=balance or (style == "2d" and "grid" or "vertical"),
      rows=items,
      navigation={ selectedIndex=selectedIndex, row=row, col=col,
        rows=rows, cols=cols, wrap=rawget(state, "wrap") == true,
        pageJump=rawget(state, "pageJump") == true,
        keyRepeat=rawget(state, "keyRepeat") == true,
        repeatDelay=repeatDelay, repeatRate=repeatRate },
      geometry={ header=header, textX=textX, textY=textY, spacing=spacing,
        showCursor=rawget(state, "showCursor") == true },
      balance=balance and {
        kind=balance,
        money=Common.integer(rawget(player, "money"), 0, 999999) or 0,
        coins=Common.integer(rawget(player, "coins"), 0, 9999) or 0,
      } or nil,
    }
    return Common.bundle(model, actions)
  end

  return ScriptMenu
end
