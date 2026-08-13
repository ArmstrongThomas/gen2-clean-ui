return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.service_common")
  local MoveDeleter = {}
  local SCREEN_ID = "Gen2MoveDeleter"

  function MoveDeleter.extract(state, context)
    local ok, code, detail = Common.exactState(state, SCREEN_ID)
    if not ok then return nil, code, detail end
    if Common.inBattle(context) then return nil, "battle_owned", SCREEN_ID end
    local monSource = rawget(state, "mon")
    local moves = rawget(state, "moves")
    local list = rawget(state, "list")
    if type(monSource) ~= "table" or type(moves) ~= "table" then
      return Common.fail("shape_type", "move-deleter data")
    end
    local count
    count, code, detail = Common.array(list, 1, 4, "list")
    if not count then return nil, code, detail end
    local selected = Common.integer(rawget(state, "row"), 1, count)
    if not selected then return Common.fail("shape_range", "row") end
    local actions = Common.inputActions(SCREEN_ID, {
      { input="up", kind="navigate" }, { input="down", kind="navigate" },
      { input="a", kind="choose" }, { input="b", kind="cancel" },
    })
    local rows = {}
    for index = 1, count do
      local source = rawget(list, index)
      if type(source) ~= "table" then
        return Common.fail("shape_type", "list[" .. index .. "]:table")
      end
      local moveId, idCode, idDetail = Common.requiredText(rawget(source, "id"),
        "list[" .. index .. "].id")
      if not moveId then return nil, idCode, idDetail end
      local definition = rawget(moves, moveId)
      local pp = Common.integer(rawget(source, "pp"), 0, 99)
      local maxPp = Common.integer(rawget(source, "maxPp"), 0, 99) or pp
      if not pp or not maxPp then
        return Common.fail("shape_range", "list[" .. index .. "].pp")
      end
      rows[index] = {
        id=moveId, sourceIndex=index,
        label=Data.text(type(definition) == "table"
          and rawget(definition, "name") or nil, moveId),
        right=("PP %d/%d"):format(pp, maxPp),
        pp=pp, maxPp=maxPp,
        type=Data.text(type(definition) == "table"
          and rawget(definition, "type") or nil, ""),
        power=Common.integer(type(definition) == "table"
          and rawget(definition, "power") or nil, 0),
        accuracy=Common.integer(type(definition) == "table"
          and rawget(definition, "accuracy") or nil, 0),
        description=Data.text(type(definition) == "table"
          and rawget(definition, "description") or nil, ""),
        selected=index == selected,
        actionId=Common.sourceInput(actions, "move." .. index, "choose",
          moveId, "a", index),
      }
    end
    local mon = Common.mon(monSource)
    return Common.bundle({
      schema="clean_ui.presenter_model.v1",
      screenId=SCREEN_ID, family="services", preset="L",
      title="CHOOSE A MOVE", rows=rows,
      navigation={ selectedIndex=selected }, pokemon=mon,
      selectedMove=Data.copy(rows[selected]),
    }, actions)
  end

  return MoveDeleter
end
