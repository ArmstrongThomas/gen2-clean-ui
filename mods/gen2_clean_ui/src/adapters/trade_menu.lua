return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.specialty_common")
  local Trade = {}

  local GENDERS = {
    TRADE_GENDER_EITHER="EITHER",
    TRADE_GENDER_MALE="MALE",
    TRADE_GENDER_FEMALE="FEMALE",
  }

  local function speciesName(state, id)
    local data = rawget(state, "data")
    local pokemon = type(data) == "table" and rawget(data, "pokemon") or nil
    local definition = type(pokemon) == "table" and rawget(pokemon, id) or nil
    return type(definition) == "table"
      and Common.requiredText(rawget(definition, "name")) or nil
  end

  function Trade.extract(state)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    if rawget(state, "animating") == true then
      return Common.fail("native_child", "Gen2TradeAnim")
    end
    if rawget(state, "picking") == true then
      return Common.fail("native_child", "Gen2PartyMenu")
    end
    if rawget(state, "closed") == true then return Common.fail("state_closed", "trade") end
    if type(rawget(state, "save")) ~= "table"
        or type(rawget(state, "data")) ~= "table"
        or type(rawget(state, "eventTables")) ~= "table" then
      return Common.fail("shape_type", "save/data/eventTables")
    end
    local id = Common.integer(rawget(state, "id"), 0, 5)
    local row = rawget(state, "row")
    if not id or type(row) ~= "table" then return Common.fail("trade_incomplete", "id/row") end
    if Common.integer(rawget(row, "id"), 0, 5) ~= id then
      return Common.fail("trade_incomplete", "row.id")
    end
    local give = Common.requiredText(rawget(row, "give"))
    local receive = Common.requiredText(rawget(row, "get"))
    if not give or not receive then return Common.fail("trade_incomplete", "species") end
    local giveName, receiveName = speciesName(state, give), speciesName(state, receive)
    local nickname = Common.requiredText(rawget(row, "nickname"))
    local genderId = Common.requiredText(rawget(row, "gender"))
    local trainer = Common.requiredText(rawget(row, "otName"))
    local trainerId = Common.integer(rawget(row, "otId"), 0, 65535)
    local dialog = Common.requiredText(rawget(row, "dialog"))
    if not giveName or not receiveName or not nickname or not GENDERS[genderId]
        or not trainer or trainerId == nil or not dialog then
      return Common.fail("trade_incomplete",
        "pokemon/nickname/gender/ot/dialog")
    end

    local message, confirm
    if rawget(state, "message") ~= nil then
      local code
      message, code = Common.paged(rawget(state, "message"), false)
      if not message then return Common.fail(code, "message") end
    end
    if rawget(state, "confirm") ~= nil then
      local code
      confirm, code = Common.paged(rawget(state, "confirm"), true)
      if not confirm then return Common.fail(code, "confirm") end
    end
    if message and confirm then return Common.fail("mode_conflict", "message+confirm") end
    if not message and not confirm then return Common.fail("dialog_missing", "trade") end

    local actions = Common.actionMap("Gen2TradeMenu", {
      { input="up", id="trade.up", kind="navigate" },
      { input="down", id="trade.down", kind="navigate" },
      { input="a", id="trade.choose", kind="choose" },
      { input="b", id="trade.back", kind="back" },
    })
    return Common.bundle("Gen2TradeMenu", {
      family="services", preset="L", title="POKEMON TRADE",
      mode=confirm and "confirm" or "offer", tradeId=id,
      offer={ give={ id=give, label=giveName },
        receive={ id=receive, label=receiveName, nickname=nickname },
        genderId=genderId, gender=GENDERS[genderId],
        trainer=trainer, trainerId=trainerId, dialog=dialog },
      message=message, confirm=confirm,
    }, actions)
  end

  return Trade
end
