return function(ctx)
  local Data = ctx.load("adapters.data")
  local Actions = ctx.load("adapters.actions")
  local Party = ctx.load("adapters.party")
  local Common = {}

  local MAX_ARRAY = 256
  local MAX_PAGES = 32
  local MAX_LINES = 8

  function Common.fail(code, detail)
    return nil, code, detail
  end

  function Common.finite(value)
    return type(value) == "number" and value == value
      and value ~= math.huge and value ~= -math.huge
  end

  function Common.integer(value, minimum, maximum)
    if not Common.finite(value) or value ~= math.floor(value) then return nil end
    if minimum ~= nil and value < minimum then return nil end
    if maximum ~= nil and value > maximum then return nil end
    return value
  end

  function Common.exactState(state, screenId)
    if type(state) ~= "table" then
      return Common.fail("state_type", "table")
    end
    if rawget(state, "screenId") ~= screenId then
      return Common.fail("screen_mismatch", tostring(rawget(state, "screenId")))
    end
    if rawget(state, "done") == true then
      return Common.fail("source_done", screenId)
    end
    return true
  end

  function Common.array(value, minimum, maximum, field)
    if type(value) ~= "table" then
      return Common.fail("shape_type", (field or "value") .. ":array")
    end
    local count = 0
    while rawget(value, count + 1) ~= nil do
      count = count + 1
      if count > (maximum or MAX_ARRAY) then
        return Common.fail("shape_range", field or "array")
      end
    end
    if count < (minimum or 0) then
      return Common.fail("shape_range", field or "array")
    end
    local key = next(value, nil)
    while key ~= nil do
      if type(key) == "number"
          and (key ~= math.floor(key) or key < 1 or key > count) then
        return Common.fail("shape_array", field or "array")
      end
      key = next(value, key)
    end
    return count
  end

  function Common.requiredText(value, field)
    if type(value) ~= "string" or value == "" then
      return Common.fail("shape_type", (field or "value") .. ":string")
    end
    return Data.text(value)
  end

  function Common.lines(value, field, allowEmpty)
    local count, code, detail = Common.array(value, allowEmpty and 0 or 1,
      MAX_LINES, field or "lines")
    if not count then return nil, code, detail end
    local output = {}
    for index = 1, count do
      local line = rawget(value, index)
      if type(line) ~= "string" then
        return Common.fail("shape_type",
          (field or "lines") .. "[" .. index .. "]:string")
      end
      output[index] = Data.text(line, "")
    end
    return output
  end

  function Common.paged(value, field)
    if value == nil then return nil end
    if type(value) ~= "table" then
      return Common.fail("shape_type", (field or "message") .. ":table")
    end
    local pages = rawget(value, "pages")
    local count, code, detail = Common.array(pages, 1, MAX_PAGES,
      (field or "message") .. ".pages")
    if not count then return nil, code, detail end
    local page = Common.integer(rawget(value, "page"), 1, count)
    if not page then
      return Common.fail("shape_range", (field or "message") .. ".page")
    end
    local copied = {}
    for index = 1, count do
      local pageLines
      pageLines, code, detail = Common.lines(rawget(pages, index),
        (field or "message") .. ".pages[" .. index .. "]", true)
      if not pageLines then return nil, code, detail end
      copied[index] = pageLines
    end
    return {
      page=page, pageCount=count,
      lines=Data.copy(copied[page]), pages=copied,
    }
  end

  function Common.confirm(value, field)
    if value == nil then return nil end
    local snapshot, code, detail = Common.paged(value, field or "confirm")
    if not snapshot then return nil, code, detail end
    local choice = Common.integer(rawget(value, "choice"), 1, 2)
    if not choice then
      return Common.fail("shape_range", (field or "confirm") .. ".choice")
    end
    snapshot.selectedChoice = choice
    snapshot.choices = {
      { id="yes", sourceIndex=1, label="YES", selected=choice == 1 },
      { id="no", sourceIndex=2, label="NO", selected=choice == 2 },
    }
    return snapshot
  end

  function Common.sourceInput(actions, id, kind, componentId, input,
      sourceIndex)
    return Actions.add(actions, {
      id=id, source="screen.update", kind=kind,
      componentId=componentId, sourceIndex=sourceIndex,
      dispatch="source_input", input=input,
    })
  end

  function Common.inputActions(screenId, specs)
    local actions = Actions.new(screenId)
    for _, spec in ipairs(specs or {}) do
      Common.sourceInput(actions, spec.id or ("input." .. spec.input),
        spec.kind or "input", spec.componentId or screenId,
        spec.input, spec.sourceIndex)
    end
    return actions
  end

  function Common.describe(actions)
    return Actions.describe(actions)
  end

  function Common.gameData(state)
    local game = type(state) == "table" and rawget(state, "game") or nil
    local data = type(game) == "table" and rawget(game, "data") or nil
    return type(data) == "table" and data or {}
  end

  function Common.player(state)
    local save = type(state) == "table" and rawget(state, "save") or nil
    local player = type(save) == "table" and rawget(save, "player") or nil
    return type(player) == "table" and player or {}
  end

  function Common.mon(mon)
    if type(mon) ~= "table" then return nil end
    local species = Data.text(rawget(mon, "species"), "?")
    local stats = rawget(mon, "stats")
    return {
      species=species,
      name=Data.text(rawget(mon, "nickname"),
        Data.text(rawget(mon, "name"), species)),
      level=Common.integer(rawget(mon, "level"), 1, 100) or 1,
      hp=Common.integer(rawget(mon, "hp"), 0) or 0,
      maxHp=Common.integer(rawget(mon, "maxHp"), 0)
        or Common.integer(rawget(mon, "maxHP"), 0)
        or (type(stats) == "table"
          and Common.integer(rawget(stats, "hp"), 0)) or 0,
      item=Data.text(rawget(mon, "item"), ""),
      status=Data.text(rawget(mon, "status"), ""),
      shiny=rawget(mon, "shiny") == true,
      isEgg=rawget(mon, "isEgg") == true,
    }
  end

  -- Service screens do not require art to reproduce their native information,
  -- but when the host exposes a complete generated sprite + palette pair the
  -- descriptor is copied through the same audited Party helper.
  function Common.optionalArtwork(state, mon)
    if type(mon) ~= "table" then return nil end
    local data = Common.gameData(state)
    local descriptor = Party.artworkFor({
      pokemon=rawget(data, "pokemon"),
      palettes=rawget(data, "gen2Palettes"),
      icons=rawget(data, "gen2Icons"),
      menuGfx=rawget(data, "gen2MenuGfx"),
    }, mon)
    return type(descriptor) == "table" and descriptor or nil
  end

  function Common.inBattle(context)
    if type(context) ~= "table" then return false end
    if rawget(context, "battleActive") == true then return true end
    local states = rawget(context, "visibleStack") or rawget(context, "states")
    if type(states) ~= "table" then return false end
    for index = 1, #states do
      local state = rawget(states, index)
      local id = type(state) == "table" and rawget(state, "screenId") or nil
      if id == "Gen2BattleState" or id == "Gen2BattleTransition" then
        return true
      end
    end
    return false
  end

  function Common.bundle(model, actions)
    if type(model) ~= "table" or not Data.isFunctionFree(model) then
      return Common.fail("model_not_data", model and model.screenId or "model")
    end
    model.actionDescriptors = Common.describe(actions)
    if not Data.isFunctionFree(model) then
      return Common.fail("model_not_data", model.screenId or "model")
    end
    return { model=model, actions=actions }
  end

  return Common
end
