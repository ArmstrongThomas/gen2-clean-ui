return function(ctx)
  local Data = ctx.load("adapters.data")
  local Actions = ctx.load("adapters.actions")
  local Common = {}

  local function arrayLength(value)
    return type(value) == "table" and #value or 0
  end

  function Common.lines(value, replacements)
    local output = {}
    local function append(line)
      local text = tostring(line or "")
      for token, replacement in pairs(replacements or {}) do
        text = text:gsub(token, tostring(replacement or ""))
      end
      output[#output + 1] = Data.text(text, "")
    end
    if type(value) == "string" then
      local found = false
      for line in (value .. "\n"):gmatch("(.-)\n") do
        append(line)
        found = true
      end
      if not found then append(value) end
    elseif type(value) == "table" then
      for index = 1, #value do append(rawget(value, index)) end
    end
    return output
  end

  function Common.message(value, replacements)
    if value == nil then return nil end
    if type(value) == "string" then
      return { page=1, pageCount=1,
        lines=Common.lines(value, replacements) }
    end
    if type(value) ~= "table" then return nil end
    local pages = rawget(value, "pages")
    if type(pages) ~= "table" then
      return { page=1, pageCount=1,
        lines=Common.lines(value, replacements) }
    end
    local count = #pages
    local page = Data.integer(rawget(value, "page"), 1)
    page = math.max(1, math.min(page, math.max(1, count)))
    return {
      page = page,
      pageCount = count,
      lines = Common.lines(rawget(pages, page), replacements),
    }
  end

  function Common.inputActions(screenId, specs)
    local map = Actions.new(screenId)
    for _, source in ipairs(specs or {}) do
      local spec = type(source) == "string" and { input=source } or source
      local input = type(spec) == "table" and spec.input or nil
      if type(input) == "string" then
        Actions.add(map, {
          id = spec.id or ("input." .. input),
          source = spec.source or "screen.update",
          kind = spec.kind or "input",
          componentId = spec.componentId,
          sourceIndex = spec.sourceIndex,
          dispatch = "source_input",
          input = input,
          enabled = spec.enabled ~= false,
        })
      end
    end
    return map
  end

  function Common.entryRows(entries, selected, actionMap, prefix)
    local output = {}
    for index = 1, arrayLength(entries) do
      local entry = rawget(entries, index)
      if type(entry) ~= "table" then entry = {} end
      local id = Data.id(rawget(entry, "id"), "row_" .. index)
      local actionId
      if actionMap then
        actionId = Actions.add(actionMap, {
          id = (prefix or "choose") .. "." .. index,
          source = "screen.update",
          kind = "choose",
          componentId = id,
          sourceIndex = index,
          dispatch = "source_input",
          input = "a",
        })
      end
      output[index] = {
        id = id,
        sourceIndex = index,
        label = Data.text(rawget(entry, "label"),
          Data.text(rawget(entry, "name"), id)),
        selected = index == selected,
        disabled = rawget(entry, "disabled") == true,
        actionId = actionId,
        metadata = Data.copy(rawget(entry, "metadata")),
      }
    end
    return output
  end

  function Common.boxName(save, index)
    local names = type(save) == "table" and rawget(save, "boxNames") or nil
    local name = type(names) == "table" and rawget(names, index) or nil
    return Data.text(name, "BOX" .. tostring(index))
  end

  function Common.boxList(save, index)
    local boxes = type(save) == "table" and rawget(save, "boxes") or nil
    local list = type(boxes) == "table" and rawget(boxes, index) or nil
    return type(list) == "table" and list or {}
  end

  function Common.mon(mon, pokemon)
    if type(mon) ~= "table" then return nil end
    local species = Data.text(rawget(mon, "species"), "?")
    local definition = type(pokemon) == "table" and rawget(pokemon, species)
      or nil
    local moves = rawget(mon, "moves")
    return {
      species = species,
      name = Data.text(rawget(mon, "name"), species),
      nickname = Data.text(rawget(mon, "nickname"), ""),
      displayName = Data.text(rawget(mon, "nickname"),
        Data.text(rawget(mon, "name"), species)),
      level = Data.integer(rawget(mon, "level"), 1),
      hp = Data.integer(rawget(mon, "hp"), 0),
      maxHp = Data.integer(rawget(mon, "maxHp"),
        Data.integer(rawget(mon, "maxHP"), 0)),
      status = Data.text(rawget(mon, "status"), ""),
      gender = Data.text(rawget(mon, "gender"), ""),
      heldItem = Data.text(rawget(mon, "heldItem"),
        Data.text(rawget(mon, "item"), "")),
      isEgg = rawget(mon, "isEgg") == true,
      shiny = rawget(mon, "shiny") == true,
      moveCount = type(moves) == "table" and #moves or 0,
      spritePath = type(definition) == "table"
        and Data.scalar(rawget(definition, "spriteFront")) or nil,
    }
  end

  function Common.monRows(list, selected, actionMap, options)
    options = options or {}
    local output = {}
    for index = 1, arrayLength(list) do
      local mon = Common.mon(rawget(list, index), options.pokemon)
      local actionId
      if actionMap then
        actionId = Actions.add(actionMap, {
          id = (options.prefix or "choose") .. "." .. index,
          source = "screen.update",
          kind = options.kind or "choose",
          componentId = "mon_" .. index,
          sourceIndex = index,
          dispatch = "source_input",
          input = "a",
        })
      end
      output[#output + 1] = {
        id = "mon_" .. index,
        sourceIndex = index,
        label = mon and mon.displayName or "?",
        right = mon and (mon.isEgg and "EGG"
          or ("Lv " .. tostring(mon.level))) or "",
        selected = index == selected,
        actionId = actionId,
        mon = mon,
      }
    end
    return output
  end

  function Common.cancelRow(index, selected, actionMap, prefix)
    local actionId
    if actionMap then
      actionId = Actions.add(actionMap, {
        id = (prefix or "choose") .. ".cancel",
        source = "screen.update",
        kind = "cancel",
        componentId = "cancel",
        sourceIndex = index,
        dispatch = "source_input",
        input = "a",
      })
    end
    return { id="cancel", sourceIndex=index, label="CANCEL",
      selected=index == selected, actionId=actionId }
  end

  function Common.detailsForMon(mon)
    if type(mon) ~= "table" then return {} end
    local details = {
      { label="NAME", value=mon.displayName or "?" },
      { label="SPECIES", value=mon.species or "?" },
    }
    if not mon.isEgg then
      details[#details + 1] = { label="LEVEL", value=mon.level or 1 }
      if (mon.maxHp or 0) > 0 then
        details[#details + 1] = {
          label="HP", value=("%d/%d"):format(mon.hp or 0, mon.maxHp),
        }
      end
      if mon.gender and mon.gender ~= "" then
        details[#details + 1] = { label="GENDER", value=mon.gender }
      end
    end
    return details
  end

  function Common.describe(actionMap)
    return Actions.describe(actionMap)
  end

  return Common
end
