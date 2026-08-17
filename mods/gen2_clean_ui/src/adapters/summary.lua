return function(ctx)
  local Data = ctx.load("adapters.data")
  local Actions = ctx.load("adapters.actions")
  local Party = ctx.load("adapters.party")
  local Summary = {}

  local PAGE_PURPOSE = { [1]="status", [2]="moves", [3]="stats" }
  local TYPE_NAMES = { PSYCHIC_TYPE="PSYCHIC", CURSE_TYPE="???" }
  local STATUS = {
    slp="SLP", sleep="SLP", psn="PSN", poison="PSN", toxic="PSN",
    brn="BRN", burn="BRN", frz="FRZ", freeze="FRZ",
    par="PAR", paralysis="PAR",
  }
  local STAT_FIELDS = {
    { id="attack", label="ATTACK" },
    { id="defense", label="DEFENSE" },
    { id="specialAttack", label="SPCL. ATK" },
    { id="specialDefense", label="SPCL. DEF" },
    { id="speed", label="SPEED" },
  }
  local MAX_PARTY, MAX_MOVES = 6, 4

  local function fail(code, detail)
    return nil, code, detail
  end

  local function finite(value)
    return type(value) == "number" and value == value
      and value ~= math.huge and value ~= -math.huge
  end

  local function integer(value, minimum, maximum)
    if not finite(value) or value ~= math.floor(value) then return nil end
    if minimum ~= nil and value < minimum then return nil end
    if maximum ~= nil and value > maximum then return nil end
    return value
  end

  local function requiredText(value)
    if type(value) ~= "string" or value == "" then return nil end
    return Data.text(value)
  end

  local function arrayCount(value, maximum)
    if type(value) ~= "table" then return nil, "shape_type" end
    local count = 0
    while rawget(value, count + 1) ~= nil do
      count = count + 1
      if maximum and count > maximum then return nil, "shape_range" end
    end
    local key = next(value, nil)
    while key ~= nil do
      if type(key) == "number"
          and (key ~= math.floor(key) or key < 1 or key > count) then
        return nil, "shape_array"
      end
      key = next(value, key)
    end
    return count
  end

  local function inputAction(map, id, kind, componentId, sourceIndex, input,
      enabled, source)
    return Actions.add(map, {
      id=id, source=source or "screen.update", kind=kind,
      componentId=componentId, sourceIndex=sourceIndex,
      dispatch="source_input", input=input, enabled=enabled ~= false,
    })
  end

  local function typeSnapshot(state, mon, definition)
    local source = type(rawget(mon, "types")) == "table"
      and rawget(mon, "types") or rawget(definition, "types")
    local count = arrayCount(source, 2)
    if not count or count < 1 then return fail("type_incomplete", "types") end
    local output = {}
    for index = 1, count do
      local id = requiredText(rawget(source, index))
      if not id then return fail("type_incomplete", tostring(index)) end
      local label = TYPE_NAMES[id] or id
      if index == 1 or label ~= output[1].label then
        output[#output + 1] = { id=id, label=label }
      end
    end
    return output
  end

  local function itemSnapshot(state, mon)
    local itemId = rawget(mon, "item")
    if itemId == nil or itemId == 0 or itemId == "" then return nil end
    itemId = requiredText(itemId)
    local items = rawget(state, "items")
    local definition = itemId and type(items) == "table"
      and rawget(items, itemId) or nil
    local name = type(definition) == "table"
      and requiredText(rawget(definition, "name")) or nil
    if not (itemId and name) then return fail("item_definition", tostring(itemId)) end
    return { id=itemId, name=name }
  end

  local function descriptionLines(value)
    if type(value) ~= "string" then return nil end
    local output = {}
    for line in (value .. "<NEXT>"):gmatch("(.-)<NEXT>") do
      if line ~= "" then output[#output + 1] = Data.text(line) end
    end
    if #output == 0 and value ~= "" then output[1] = Data.text(value) end
    return output
  end

  local function moveSnapshot(state, entry, sourceIndex)
    if type(entry) ~= "table" then
      return fail("shape_type", "moves[" .. sourceIndex .. "]")
    end
    local id = requiredText(rawget(entry, "id"))
    local definitions = rawget(state, "moves")
    local definition = id and type(definitions) == "table"
      and rawget(definitions, id) or nil
    local name = type(definition) == "table"
      and requiredText(rawget(definition, "name")) or nil
    local pp = integer(rawget(entry, "pp"), 0)
    local maxPp = integer(rawget(entry, "maxPp"), 0) or pp
    local typeId = type(definition) == "table"
      and requiredText(rawget(definition, "type")) or nil
    local power = type(definition) == "table"
      and integer(rawget(definition, "power"), 0) or nil
    local description = type(definition) == "table"
      and descriptionLines(rawget(definition, "description")) or nil
    if not (id and name and pp and maxPp and typeId and power and description)
        or pp > maxPp then
      return fail("move_incomplete", id or tostring(sourceIndex))
    end
    return {
      id=id, name=name, sourceIndex=sourceIndex, pp=pp, maxPp=maxPp,
      type={ id=typeId, label=TYPE_NAMES[typeId] or typeId },
      power=power >= 2 and power or nil,
      description=description,
    }
  end

  local function growthThreshold(curve, level)
    local n = math.max(1, math.floor(level))
    local threshold = math.floor(curve.numerator * n * n * n
      / curve.denominator) + curve.squared * n * n
      + curve.linear * n - curve.constant
    return math.max(0, math.floor(threshold))
  end

  local function growthSnapshot(state, definition, level, experience)
    if level >= 100 then
      return {
        level=level, nextLevel=100, experience=experience,
        currentThreshold=experience, nextThreshold=experience,
        progress=0, progressSpan=0, fraction=1, toNext=0,
      }
    end
    local pokemon = rawget(state, "pokemon")
    local curves = type(pokemon) == "table" and rawget(pokemon, "growthRates")
      or nil
    local curveId = requiredText(rawget(definition, "growthRate"))
    local curve = curveId and type(curves) == "table" and rawget(curves, curveId)
      or nil
    if type(curve) ~= "table" then
      return fail("growth_incomplete", tostring(curveId))
    end
    local numerator = finite(rawget(curve, "numerator"))
      and rawget(curve, "numerator") or nil
    local denominator = finite(rawget(curve, "denominator"))
      and rawget(curve, "denominator") or nil
    local squared = finite(rawget(curve, "squared"))
      and rawget(curve, "squared") or nil
    local linear = finite(rawget(curve, "linear"))
      and rawget(curve, "linear") or nil
    local constant = finite(rawget(curve, "constant"))
      and rawget(curve, "constant") or nil
    if not (numerator and denominator and denominator ~= 0
        and squared and linear and constant) then
      return fail("growth_incomplete", curveId)
    end
    local curveValues = {
      numerator=numerator, denominator=denominator, squared=squared,
      linear=linear, constant=constant,
    }
    local currentThreshold = growthThreshold(curveValues, level)
    local threshold = growthThreshold(curveValues, level + 1)
    local progressSpan = math.max(0, threshold - currentThreshold)
    local progress = math.max(0, math.min(progressSpan,
      experience - currentThreshold))
    return {
      curveId=curveId, level=level, nextLevel=level + 1,
      experience=experience, nextThreshold=threshold,
      currentThreshold=currentThreshold, progress=progress,
      progressSpan=progressSpan,
      fraction=progressSpan > 0 and progress / progressSpan or 0,
      toNext=math.max(0, threshold - experience),
    }
  end

  local function statusSnapshot(mon, hp)
    local sourcePokerus = rawget(mon, "pokerus")
    local pokerus = sourcePokerus == nil and 0
      or integer(sourcePokerus, 0, 255)
    if pokerus == nil then
      return fail("pokerus_incomplete", tostring(sourcePokerus))
    end
    local days = pokerus % 16
    local status
    if hp <= 0 then
      status = "FNT"
    elseif days ~= 0 then
      status = "POKERUS"
    else
      local source = rawget(mon, "status")
      if source == nil or source == false or source == "" then
        status = "OK"
      else
        status = STATUS[tostring(source):lower()]
        if not status then return fail("unknown_status", tostring(source)) end
      end
    end
    return status, pokerus == 0 and nil
      or (days ~= 0 and "infected" or "immune")
  end

  local function trainerSnapshot(state, mon)
    local save = rawget(state, "save")
    local player = type(save) == "table" and rawget(save, "player") or nil
    local name = requiredText(rawget(mon, "otName"))
      or (type(player) == "table" and requiredText(rawget(player, "name")))
    local id = integer(rawget(mon, "otId"), 0, 99999)
      or (type(player) == "table" and integer(rawget(player, "id"), 0, 99999))
    if not (name and id) then return fail("trainer_incomplete", "OT") end
    return { name=name, id=id }
  end

  local function statSnapshot(mon)
    local source = rawget(mon, "stats")
    if type(source) ~= "table" then return fail("stats_incomplete", "stats") end
    local output = {}
    for index, field in ipairs(STAT_FIELDS) do
      local value = integer(rawget(source, field.id), 1)
      if not value then return fail("stats_incomplete", field.id) end
      output[index] = { id=field.id, label=field.label, value=value }
    end
    return output
  end

  local function eggFlavor(cycles)
    if cycles < 0x6 then
      return { "It's making sounds inside.", "It's going to hatch soon!" }
    elseif cycles < 0xb then
      return { "It moves around inside sometimes.",
        "It must be close to hatching." }
    elseif cycles < 0x29 then
      return { "Wonder what's inside?", "It needs more time, though." }
    end
    return { "This EGG needs a lot more time to hatch." }
  end

  local function validateParty(state)
    local party = rawget(state, "party")
    local count, arrayCode = arrayCount(party, MAX_PARTY)
    if not count then return fail(arrayCode, "party") end
    if count < 1 then return fail("shape_range", "party") end
    for index = 1, count do
      local mon = rawget(party, index)
      if type(mon) ~= "table" or not requiredText(rawget(mon, "species")) then
        return fail("mon_incomplete", "party[" .. index .. "]")
      end
    end
    local selected = integer(rawget(state, "index"), 1, count)
    if not selected then return fail("shape_range", "index") end
    if rawget(state, "mon") ~= rawget(party, selected) then
      return fail("source_mismatch", "mon")
    end
    return party, count, selected
  end

  local function addPageActions(actionMap, page, partyIndex, partyCount)
    inputAction(actionMap, "summary.back", "back", "summary", nil, "b", true)
    inputAction(actionMap, "summary.page.previous", "previous_page", "tabs",
      nil, "left", true)
    inputAction(actionMap, "summary.page.next", "next_page", "tabs",
      nil, "right", true)
    inputAction(actionMap, "summary.pokemon.previous", "previous_pokemon",
      "pokemon", partyIndex - 1, "up", partyIndex > 1)
    inputAction(actionMap, "summary.pokemon.next", "next_pokemon", "pokemon",
      partyIndex + 1, "down", partyIndex < partyCount)
    inputAction(actionMap, "summary.primary",
      page == 3 and "close" or "next_page", "summary", nil, "a", true)
    if page == 2 then
      inputAction(actionMap, "summary.moves.open", "move_reorder", "moves",
        nil, "select", true)
    end
  end

  local function addMoveActions(actionMap, moves, moveIndex, swapFrom,
      partyIndex, partyCount)
    for sourceIndex, move in ipairs(moves) do
      move.actionId = inputAction(actionMap,
        "summary.move." .. sourceIndex, swapFrom and "drop_move" or "pick_move",
        "move." .. sourceIndex, sourceIndex, "a", true,
        "screen.updateMoveDetail")
    end
    inputAction(actionMap, "summary.move.up", "previous_move", "moves", nil,
      "up", true, "screen.updateMoveDetail")
    inputAction(actionMap, "summary.move.down", "next_move", "moves", nil,
      "down", true, "screen.updateMoveDetail")
    inputAction(actionMap, "summary.move.back",
      swapFrom and "cancel_reorder" or "back", "moves", nil, "b", true,
      "screen.updateMoveDetail")
    inputAction(actionMap, "summary.move.select_back",
      swapFrom and "cancel_reorder" or "back", "moves", nil, "select", true,
      "screen.updateMoveDetail")
    inputAction(actionMap, "summary.move.pokemon.previous", "previous_pokemon",
      "pokemon", partyIndex - 1, "left", not swapFrom and partyIndex > 1,
      "screen.updateMoveDetail")
    inputAction(actionMap, "summary.move.pokemon.next", "next_pokemon",
      "pokemon", partyIndex + 1, "right",
      not swapFrom and partyIndex < partyCount, "screen.updateMoveDetail")
    return moves[moveIndex]
  end

  function Summary.extract(state)
    if type(state) ~= "table" then return fail("state_type", "table") end
    for _, key in ipairs({ "pokemon", "moves", "items", "palettes",
        "menuGfx", "icons" }) do
      if type(rawget(state, key)) ~= "table" then
        return fail("shape_type", key .. ":table")
      end
    end
    if type(rawget(state, "moveScreen")) ~= "boolean"
        or type(rawget(state, "moveDetail")) ~= "boolean" then
      return fail("shape_type", "move flags")
    end
    if rawget(state, "moveScreen") and not rawget(state, "moveDetail") then
      return fail("source_mismatch", "moveScreen")
    end
    local party, partyCount, partyIndex = validateParty(state)
    if not party then return nil, partyCount, partyIndex end
    local mon = rawget(state, "mon")
    local page = integer(rawget(state, "page"), 1, 3)
    if not page then return fail("shape_range", "page") end
    local isEgg = rawget(mon, "isEgg") == true
    if isEgg and (rawget(state, "moveScreen") or rawget(state, "moveDetail")) then
      return fail("unknown_mode", "egg move detail")
    end
    local actionMap = Actions.new("Gen2SummaryMenu")
    local artwork, artCode, artDetail = Party.artworkFor(state, mon)
    if not artwork then return nil, artCode, artDetail end

    if isEgg then
      local cycles = integer(rawget(mon, "eggSteps"), 0, 255)
      if cycles == nil then return fail("egg_incomplete", "eggSteps") end
      inputAction(actionMap, "summary.egg.close", "close", "egg", nil, "a", true)
      inputAction(actionMap, "summary.back", "back", "egg", nil, "b", true)
      inputAction(actionMap, "summary.pokemon.previous", "previous_pokemon",
        "pokemon", partyIndex - 1, "up", partyIndex > 1)
      inputAction(actionMap, "summary.pokemon.next", "next_pokemon", "pokemon",
        partyIndex + 1, "down", partyIndex < partyCount)
      local model = {
        schema="clean_ui.presenter_model.v1", screenId="Gen2SummaryMenu",
        family="summary", preset="L", title="SUMMARY",
        mode="egg", purpose="egg",
        navigation={ partyIndex=partyIndex, partyCount=partyCount,
          pageIndex=page, pageCount=1, moveIndex=1, moveCount=0 },
        pageTabs={}, pokemon={ name="EGG", isEgg=true }, artwork=artwork,
        egg={ cycles=cycles, lines=eggFlavor(cycles) },
      }
      model.actionDescriptors = Actions.describe(actionMap)
      if not Data.isFunctionFree(model) then
        return fail("model_not_data", "Gen2SummaryMenu.egg")
      end
      return { model=model, actions=actionMap }
    end

    local species = requiredText(rawget(mon, "species"))
    local definition = species and rawget(rawget(state, "pokemon"), species)
      or nil
    local level = integer(rawget(mon, "level"), 1, 100)
    local dex = type(definition) == "table"
      and integer(rawget(definition, "dex"), 1, 9999) or nil
    local speciesName = type(definition) == "table"
      and requiredText(rawget(definition, "name")) or nil
    local nickname = requiredText(rawget(mon, "nickname"))
    local sourceName = requiredText(rawget(mon, "name"))
    if not nickname and sourceName and speciesName
        and sourceName:upper() ~= speciesName:upper() then
      nickname = sourceName
    end
    if nickname and speciesName and nickname:upper() == speciesName:upper() then
      nickname = nil
    end
    local name = nickname or speciesName or sourceName or species
    if not (species and type(definition) == "table" and level and name
        and dex and speciesName) then
      return fail("pokemon_definition", tostring(species))
    end
    local stats = rawget(mon, "stats")
    local maxHp = integer(rawget(mon, "maxHp"), 1)
      or (type(stats) == "table" and integer(rawget(stats, "hp"), 1))
    local hp = integer(rawget(mon, "hp"), 0, maxHp)
    local experience = integer(rawget(mon, "experience"), 0)
    if not (maxHp and hp and experience) then
      return fail("status_incomplete", species)
    end
    local status, pokerus, statusDetail = statusSnapshot(mon, hp)
    if not status then return nil, pokerus, statusDetail end
    local types, typeCode, typeDetail = typeSnapshot(state, mon, definition)
    if not types then return nil, typeCode, typeDetail end
    local item, itemCode, itemDetail = itemSnapshot(state, mon)
    if itemCode then return nil, itemCode, itemDetail end
    local growth, growthCode, growthDetail = growthSnapshot(
      state, definition, level, experience)
    if not growth then return nil, growthCode, growthDetail end
    local trainer, trainerCode, trainerDetail = trainerSnapshot(state, mon)
    if not trainer then return nil, trainerCode, trainerDetail end
    local statRows, statCode, statDetail = statSnapshot(mon)
    if not statRows then return nil, statCode, statDetail end

    local sourceMoves = rawget(mon, "moves")
    local moveCount, moveArrayCode = arrayCount(sourceMoves, MAX_MOVES)
    if not moveCount then return fail(moveArrayCode, "mon.moves") end
    local moveIndex = integer(rawget(state, "moveIndex"), 1,
      math.max(1, moveCount))
    if not moveIndex then return fail("shape_range", "moveIndex") end
    local swapFrom = rawget(state, "swapFrom") ~= nil
      and integer(rawget(state, "swapFrom"), 1, moveCount) or nil
    if rawget(state, "swapFrom") ~= nil and not swapFrom then
      return fail("shape_range", "swapFrom")
    end
    if rawget(state, "moveDetail") and moveCount == 0 then
      return fail("move_detail_empty", "moves")
    end
    local moves = {}
    for sourceIndex = 1, moveCount do
      local snapshot, code, detail = moveSnapshot(state,
        rawget(sourceMoves, sourceIndex), sourceIndex)
      if not snapshot then return nil, code, detail end
      moves[sourceIndex] = snapshot
    end

    local purpose = rawget(state, "moveDetail") and "moves"
      or PAGE_PURPOSE[page]
    if rawget(state, "moveDetail") then
      addMoveActions(actionMap, moves, moveIndex, swapFrom,
        partyIndex, partyCount)
    else
      addPageActions(actionMap, page, partyIndex, partyCount)
    end
    local gender = Party.genderFor(state, mon)
    local model = {
      schema="clean_ui.presenter_model.v1", screenId="Gen2SummaryMenu",
      family="summary", preset="L", title="SUMMARY",
      mode=rawget(state, "moveDetail") and "move_reorder" or "page",
      purpose=purpose,
      sourcePage=page,
      pageTabs={
        { id="status", label="STATUS", sourcePage=1, selected=page == 1 },
        { id="moves", label="MOVES", sourcePage=2, selected=page == 2 },
        { id="stats", label="STATS", sourcePage=3, selected=page == 3 },
      },
      navigation={
        partyIndex=partyIndex, partyCount=partyCount,
        pageIndex=page, pageCount=3,
        moveIndex=moveIndex, moveCount=moveCount, swapFrom=swapFrom,
      },
      pokemon={
        species=species, speciesName=speciesName, nickname=nickname,
        name=name, dex=dex,
        level=level, gender=gender,
        genderIcon=Party.genderIconFor(gender),
        shiny=rawget(mon, "shiny") == true, isEgg=false,
      },
      artwork=artwork,
      status={ hp=hp, maxHp=maxHp, status=status, pokerus=pokerus,
        types=types, experience=growth },
      heldItem=item,
      moves=moves,
      stats={ trainer=trainer, values=statRows },
      moveDetail=rawget(state, "moveDetail") and {
        selectedIndex=moveIndex, selectedMove=moves[moveIndex],
        swapFrom=swapFrom, reorderActive=swapFrom ~= nil,
        standalone=rawget(state, "moveScreen") == true,
      } or nil,
    }
    model.actionDescriptors = Actions.describe(actionMap)
    if not Data.isFunctionFree(model) then
      return fail("model_not_data", "Gen2SummaryMenu")
    end
    return { model=model, actions=actionMap }
  end

  Summary.PAGE_PURPOSE = PAGE_PURPOSE
  return Summary
end
