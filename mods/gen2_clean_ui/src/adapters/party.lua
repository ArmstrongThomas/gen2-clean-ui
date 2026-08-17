return function(ctx)
  local Data = ctx.load("adapters.data")
  local Actions = ctx.load("adapters.actions")
  local Party = {}

  local STATUS = {
    slp="SLP", sleep="SLP", psn="PSN", poison="PSN", toxic="PSN",
    brn="BRN", burn="BRN", frz="FRZ", freeze="FRZ",
    par="PAR", paralysis="PAR",
  }

  local TYPE_NAMES = { PSYCHIC_TYPE="PSYCHIC", CURSE_TYPE="???" }
  local GENDER_SHEETS = {
    [10] = {
      path="assets/generated/icons/gen2/gender10px.png",
      assetPath="overrides/icons/gen2/gender10px.png",
      size=10,
    },
    [16] = {
      path="assets/generated/icons/gen2/gender16px.png",
      assetPath="overrides/icons/gen2/gender16px.png",
      size=16,
    },
  }
  local MAX_PARTY, MAX_SUBMENU = 6, 64
  -- Extraction runs after the host has advanced its cursor. These weak maps
  -- retain only the last visible cursor for the live host tables, allowing a
  -- hidden terminal/action boundary to preserve directional wraparound without adding
  -- state to the detached presenter model.
  local partyCursorMemory = setmetatable({}, { __mode="k" })
  local submenuCursorMemory = setmetatable({}, { __mode="k" })

  local function genderKind(value)
    local gender = tostring(value or ""):lower()
    if gender == "female" or gender == "f" then return "female" end
    if gender == "male" or gender == "m" then return "male" end
    if gender == "none" or gender == "genderless"
        or gender == "no_gender" or gender == "no-gender"
        or gender == "nogender" or gender == "no gender"
        or gender == "unknown" then
      return "none"
    end
    return nil
  end

  local function genderIconFor(value)
    local kind = genderKind(value)
    if not kind then return nil end
    local slot = kind == "male" and 0
      or (kind == "female" and 1 or 2)
    local variants = {}
    for size, sheet in pairs(GENDER_SHEETS) do
      variants[tostring(size)] = {
        path=sheet.path, assetPath=sheet.assetPath,
        crop={ x=slot * sheet.size, y=0,
          w=sheet.size, h=sheet.size },
        sourceSize=sheet.size,
      }
    end
    -- Keep a 10px descriptor at the top level for older renderers. The
    -- current Clean renderer selects one of the two variants from the active
    -- font's physical pixel height before drawing it.
    local default = variants["10"]
    return {
      kind="gender_icon", gender=kind,
      path=default.path, assetPath=default.assetPath,
      crop=Data.copy(default.crop), sourceSize=default.sourceSize,
      variants=variants,
    }
  end

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

  -- The host's runtime gender is DV-derived for ordinary species, but its
  -- species definition is authoritative for the three endpoint ratios:
  -- 0x00 male-only, 0xFE female-only, and 0xFF genderless.  Use those
  -- presentation facts when V3 exposes them so a forced-gender species does
  -- not inherit a contradictory DV-derived symbol.  Preserve the host value
  -- for ordinary ratios so the mod does not reimplement battle semantics.
  local function genderFor(state, mon)
    if type(mon) ~= "table" or rawget(mon, "isEgg") == true then
      return nil
    end
    local raw = Data.scalar(rawget(mon, "gender"))
    local species = requiredText(rawget(mon, "species"))
    local pokemon = type(state) == "table" and rawget(state, "pokemon")
      or nil
    local definition = species and type(pokemon) == "table"
      and rawget(pokemon, species) or nil
    local ratio = type(definition) == "table"
      and tonumber(rawget(definition, "genderRatio")) or nil
    if ratio == 0xff then return "none" end
    if ratio == 0 then return "male" end
    if ratio == 0xfe then return "female" end
    return raw
  end

  -- Source images are loaded by mod.ui.sourceImage, which intentionally only
  -- accepts generated host assets.  Reject anything outside that namespace
  -- here so a completed model is guaranteed to carry a loadable, sandbox-safe
  -- descriptor rather than relying on the renderer to discover a bad path.
  local function sourceImagePath(value)
    local path = requiredText(value)
    if not path or path:sub(1, 17) ~= "assets/generated/"
        or path:sub(-4):lower() ~= ".png"
        or path:find("..", 1, true)
        or path:find("\\", 1, true)
        or path:find(":", 1, true) then
      return nil
    end
    return path
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
      if type(key) == "number" then
        if key ~= math.floor(key) or key < 1 or key > count then
          return nil, "shape_array"
        end
      end
      key = next(value, key)
    end
    return count
  end

  local function color(value)
    if type(value) ~= "table" then return nil end
    local output = {}
    for index = 1, 3 do
      local channel = integer(rawget(value, index), 0, 255)
      if channel == nil then return nil end
      output[index] = channel
    end
    return output
  end

  local function fourColorPalette(value)
    if type(value) ~= "table" then return nil end
    local output = {}
    for index = 1, 4 do
      output[index] = color(rawget(value, index))
      if not output[index] then return nil end
    end
    return output
  end

  local function monPalette(palettes, species, shiny)
    local pokemon = type(palettes) == "table"
      and rawget(palettes, "pokemon") or nil
    local entry = type(pokemon) == "table" and rawget(pokemon, species) or nil
    local pair = type(entry) == "table"
      and rawget(entry, shiny and "shiny" or "normal") or nil
    if type(pair) ~= "table" then return nil end
    local middle1, middle2 = color(rawget(pair, 1)), color(rawget(pair, 2))
    if not (middle1 and middle2) then return nil end
    return {
      { 255, 255, 255 }, middle1, middle2, { 0, 0, 0 },
    }
  end

  local function unownLetter(mon)
    local stored = rawget(mon, "unownLetter")
    if type(stored) == "string" and #stored == 1 then
      local byte = stored:upper():byte()
      if byte and byte >= 65 and byte <= 90 then return stored:upper() end
    end
    local number = integer(stored, 1, 26)
    if number then return string.char(64 + number) end

    local dvs = rawget(mon, "dvs")
    if type(dvs) ~= "table" then return nil end
    local fields = { "attack", "defense", "speed", "special" }
    local packed = 0
    for index, field in ipairs(fields) do
      local dv = integer(rawget(dvs, field), 0, 15)
      if dv == nil then return nil end
      local bits = math.floor(dv / 2) % 4
      packed = packed + bits * ({ 64, 16, 4, 1 })[index]
    end
    return string.char(64 + math.floor(packed / 10) + 1)
  end

  local function frontPath(mon, definition)
    if rawget(mon, "species") ~= "UNOWN" then
      return sourceImagePath(rawget(definition, "spriteFront"))
    end
    local letter = unownLetter(mon)
    if not letter then return nil, "unown_form" end
    local letters = rawget(definition, "letters")
    local form = type(letters) == "table" and rawget(letters, letter) or nil
    local path = type(form) == "table" and rawget(form, "spriteFront")
      or rawget(definition, "spriteFront")
    path = sourceImagePath(path)
    if not path then return nil, "sprite_path" end
    return path, nil, letter
  end

  local function eggArtwork(state, mon)
    local menuGfx = rawget(state, "menuGfx")
    local hatch = type(menuGfx) == "table" and rawget(menuGfx, "eggHatch")
      or nil
    local path = type(hatch) == "table" and rawget(hatch, "egg") or nil
    local fallback
    if not sourceImagePath(path) then
      local icons = rawget(state, "icons")
      local entries = type(icons) == "table" and rawget(icons, "icons") or nil
      local egg = type(entries) == "table" and rawget(entries, "ICON_EGG")
        or nil
      path = type(egg) == "table" and rawget(egg, "image") or nil
      fallback = sourceImagePath(path) and "party_icon" or nil
    end
    path = sourceImagePath(path)
    local palette = monPalette(rawget(state, "palettes"), "EGG",
      rawget(mon, "shiny") == true)
    if not path then return fail("sprite_incomplete", "egg.path") end
    if not palette then return fail("palette_incomplete", "EGG") end
    return {
      kind="pokemon_front", species="EGG", path=path,
      shiny=rawget(mon, "shiny") == true,
      trueColor=false,
      palette=palette, paletteMode="gen2_2bpp",
      fallback=fallback,
      crop=fallback and { x=0, y=0, width=16, height=16 } or nil,
    }
  end

  function Party.artworkFor(state, mon)
    if type(state) ~= "table" or type(mon) ~= "table" then
      return fail("shape_type", "artwork")
    end
    if rawget(mon, "isEgg") == true then return eggArtwork(state, mon) end
    local species = requiredText(rawget(mon, "species"))
    local pokemon = rawget(state, "pokemon")
    local definition = species and type(pokemon) == "table"
      and rawget(pokemon, species) or nil
    if not species or type(definition) ~= "table" then
      return fail("pokemon_definition", tostring(species))
    end
    local path, pathCode, form = frontPath(mon, definition)
    if not path then return fail("sprite_incomplete", pathCode or species) end
    local trueColor = rawget(definition, "trueColor") == true
    local descriptor = {
      kind="pokemon_front", species=species, path=path,
      shiny=rawget(mon, "shiny") == true,
      trueColor=trueColor, form=form,
    }
    if not trueColor then
      local palette = monPalette(rawget(state, "palettes"), species,
        descriptor.shiny)
      if not palette then return fail("palette_incomplete", species) end
      descriptor.palette = palette
      descriptor.paletteMode = "gen2_2bpp"
    else
      descriptor.paletteMode = "true_color"
    end
    return descriptor
  end

  local function iconFor(state, mon)
    local icons = rawget(state, "icons")
    local speciesMap = type(icons) == "table" and rawget(icons, "species")
      or nil
    local entries = type(icons) == "table" and rawget(icons, "icons") or nil
    local species = requiredText(rawget(mon, "species"))
    local iconId = rawget(mon, "isEgg") == true and "ICON_EGG"
      or (type(speciesMap) == "table" and rawget(speciesMap, species))
    iconId = requiredText(iconId)
    local entry = iconId and type(entries) == "table"
      and rawget(entries, iconId) or nil
    local path = type(entry) == "table" and sourceImagePath(rawget(entry, "image"))
      or nil
    local frames = type(entry) == "table"
      and integer(rawget(entry, "frames"), 1, 64) or nil
    local width = type(entry) == "table"
      and integer(rawget(entry, "width"), 1, 4096) or nil
    local height = type(entry) == "table"
      and integer(rawget(entry, "height"), 1, 4096) or nil
    local partyRows = type(rawget(state, "palettes")) == "table"
      and rawget(rawget(state, "palettes"), "partyMenu") or nil
    local palette = type(partyRows) == "table"
      and fourColorPalette(rawget(partyRows, 1)) or nil
    if not (iconId and path and frames and width and height) then
      return fail("icon_incomplete", species or "EGG")
    end
    local frameHeight = math.floor(height / frames)
    if frameHeight < 1 then
      return fail("icon_incomplete", species or "EGG")
    end
    if not palette then return fail("palette_incomplete", "partyMenu[1]") end
    return {
      kind="party_icon", id=iconId, path=path, frames=frames,
      width=width, height=height,
      crop={ x=0, y=0, w=width, h=frameHeight },
      -- Official Gen2 PartyMenu alternates the two sheet frames every
      -- sixteen fixed update steps.  Keep the timing in the descriptor so
      -- the detached renderer can select a source-sized frame.
      animation={ axis="y", frames=frames, frameDuration=16 },
      palette=palette, paletteMode="gen2_2bpp",
    }
  end

  local function itemFor(state, mon)
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

  local function typesFor(state, mon)
    local pokemon = rawget(state, "pokemon")
    local species = requiredText(rawget(mon, "species"))
    local definition = species and type(pokemon) == "table"
      and rawget(pokemon, species) or nil
    if type(definition) ~= "table" then
      return fail("pokemon_definition", tostring(species))
    end
    local source = type(rawget(mon, "types")) == "table"
      and rawget(mon, "types") or rawget(definition, "types")
    local count = arrayCount(source, 2)
    if not count or count < 1 then return fail("type_incomplete", species) end
    local output = {}
    for index = 1, count do
      local id = requiredText(rawget(source, index))
      if not id then return fail("type_incomplete", species) end
      local label = TYPE_NAMES[id] or id
      if index == 1 or label ~= output[1].label then
        output[#output + 1] = { id=id, label=label }
      end
    end
    return output
  end

  local function statusFor(mon, hp)
    if hp <= 0 then return "FNT" end
    local source = rawget(mon, "status")
    if source == nil or source == false or source == "" then return "OK" end
    local label = STATUS[tostring(source):lower()]
    if not label then return nil, "unknown_status" end
    return label
  end

  local function monSnapshot(state, mon, sourceIndex)
    if type(mon) ~= "table" then return fail("shape_type", "party mon") end
    local species = requiredText(rawget(mon, "species"))
    local level = integer(rawget(mon, "level"), 1, 100)
    local isEgg = rawget(mon, "isEgg") == true
    if not (species and level) then
      return fail("mon_incomplete", "party[" .. sourceIndex .. "]")
    end
    local stats = rawget(mon, "stats")
    local maxHp = integer(rawget(mon, "maxHp"), 1)
      or (type(stats) == "table" and integer(rawget(stats, "hp"), 1))
    local hp = integer(rawget(mon, "hp"), 0, maxHp)
    if not (maxHp and hp) then return fail("hp_incomplete", species) end
    local item, itemCode, itemDetail = itemFor(state, mon)
    if itemCode then return nil, itemCode, itemDetail end
    local icon, iconCode, iconDetail = iconFor(state, mon)
    if not icon then return nil, iconCode, iconDetail end
    local types = {}
    if not isEgg then
      local typeCode, typeDetail
      types, typeCode, typeDetail = typesFor(state, mon)
      if not types then return nil, typeCode, typeDetail end
    end
    local status, statusCode = isEgg and nil or statusFor(mon, hp)
    if statusCode then return fail(statusCode, species) end
    local name = isEgg and "EGG" or requiredText(rawget(mon, "nickname"))
      or requiredText(rawget(mon, "name")) or species
    local gender = genderFor(state, mon)
    return {
      sourceIndex=sourceIndex, species=species, name=name, level=level,
      isEgg=isEgg, gender=gender, genderIcon=genderIconFor(gender),
      hp=hp, maxHp=maxHp, status=status,
      hpFraction=maxHp > 0 and hp / maxHp or 0,
      shiny=rawget(mon, "shiny") == true,
      types=types, item=item, icon=icon,
    }
  end

  local function inputAction(map, id, kind, componentId, sourceIndex, input,
      enabled, source)
    return Actions.add(map, {
      id=id, source=source or "screen.update", kind=kind,
      componentId=componentId, sourceIndex=sourceIndex,
      dispatch="source_input", input=input, enabled=enabled ~= false,
    })
  end

  local function submenuKind(item)
    local id = rawget(item, "id")
    if rawget(item, "fieldMove") == true then return "field_move" end
    if id == "STATS" then return "summary" end
    if id == "SWITCH" then return "switch" end
    if id == "MOVE" then return "move_reorder" end
    if id == "ITEM" then return "held_item" end
    if id == "MAIL" then return "mail" end
    if id == "CANCEL" then return "back" end
    return "extension"
  end

  local function submenuSnapshot(state, sourceParty, party, actionMap)
    local submenu = rawget(state, "submenu")
    if submenu == nil then return nil end
    if type(submenu) ~= "table" then return fail("shape_type", "submenu") end
    local sourceItems = rawget(submenu, "items")
    local count, arrayCode = arrayCount(sourceItems, MAX_SUBMENU)
    if not count then return fail(arrayCode, "submenu.items") end
    if count < 1 then return fail("shape_range", "submenu.items") end
    local selected = integer(rawget(submenu, "index"), 1, count)
    local slot = integer(rawget(submenu, "slot"), 1, #party)
    if not (selected and slot) then return fail("shape_range", "submenu") end
    if rawget(submenu, "mon") ~= rawget(sourceParty, slot) then
      return fail("source_mismatch", "submenu.mon")
    end
    local output = {}
    local displayedSelected
    local firstVisibleSourceIndex
    local lastVisibleSourceIndex
    for sourceIndex = 1, count do
      local item = rawget(sourceItems, sourceIndex)
      if type(item) ~= "table" then
        return fail("shape_type", "submenu.items[" .. sourceIndex .. "]")
      end
      local id = requiredText(rawget(item, "id"))
      local label = requiredText(rawget(item, "label"))
      if not (id and label) then
        return fail("submenu_item_incomplete", tostring(sourceIndex))
      end
      local kind = submenuKind(item)
      if kind ~= "back" and kind ~= "move_reorder" then
        firstVisibleSourceIndex = firstVisibleSourceIndex
          or sourceIndex
        lastVisibleSourceIndex = sourceIndex
        local displayIndex = #output + 1
        local actionId = inputAction(actionMap,
          "submenu.choose." .. sourceIndex, kind, id,
          sourceIndex, "a", rawget(item, "disabled") ~= true,
          "screen.updateSubmenu")
        output[displayIndex] = {
          id=id, label=kind == "summary" and "DETAILS" or label,
          sourceIndex=sourceIndex,
          kind=kind, selected=false,
          disabled=rawget(item, "disabled") == true,
          actionId=actionId,
        }
        if sourceIndex == selected then displayedSelected = displayIndex end
      end
    end
    if #output < 1 then
      return fail("submenu_empty", "submenu.items")
    end
    -- The host can leave its source cursor on CANCEL while the Clean modal
    -- intentionally omits that row. Treat that boundary as a directional
    -- wrap: Down from the last real action goes to the first, and Up from the
    -- first goes to the last. An initial extraction falls back to the last
    -- action, matching the native cursor's current position.
    if displayedSelected == nil then
      local previous = submenuCursorMemory[submenu]
      local wrappedToFirst = previous == #output
      displayedSelected = wrappedToFirst and 1 or #output
      local targetSourceIndex = wrappedToFirst
        and firstVisibleSourceIndex or lastVisibleSourceIndex
      -- Provider extraction runs after the host's update step. Normalize the
      -- live cursor now so the following A press is handled by the selected
      -- real action rather than by the hidden native CANCEL row. This is a
      -- presentation-owned boundary: B still closes the host submenu.
      rawset(submenu, "index", targetSourceIndex)
    end
    submenuCursorMemory[submenu] = displayedSelected
    for displayIndex, item in ipairs(output) do
      item.selected = displayIndex == displayedSelected
    end
    inputAction(actionMap, "submenu.back", "back", "submenu", nil, "b",
      true, "screen.updateSubmenu")
    return {
      selectedIndex=displayedSelected, sourceSelectedIndex=selected,
      sourceSlot=slot,
      pokemonName=party[slot].name, items=output,
    }
  end

  function Party.extract(state)
    if type(state) ~= "table" then return fail("state_type", "table") end
    if type(rawget(state, "wantsSubmenu")) ~= "boolean"
        or type(rawget(state, "wantsBattleSubmenu")) ~= "boolean" then
      return fail("shape_type", "submenu flags")
    end
    if type(rawget(state, "items")) ~= "table"
        or type(rawget(state, "moves")) ~= "table"
        or type(rawget(state, "pokemon")) ~= "table"
        or type(rawget(state, "icons")) ~= "table"
        or type(rawget(state, "palettes")) ~= "table" then
      return fail("shape_type", "party data tables")
    end
    local prompt = requiredText(rawget(state, "prompt"))
    if not prompt then return fail("shape_type", "prompt:string") end
    local sourceParty = rawget(state, "party")
    local count, arrayCode = arrayCount(sourceParty, MAX_PARTY)
    if not count then return fail(arrayCode, "party") end
    if count < 1 then return fail("shape_range", "party") end
    local switching = rawget(state, "switchFrom") ~= nil
    local maximumIndex = switching and count or count + 1
    local sourceSelectedIndex = integer(rawget(state, "index"), 1, maximumIndex)
    local switchFrom = switching
      and integer(rawget(state, "switchFrom"), 1, count) or nil
    if not sourceSelectedIndex or (switching and not switchFrom) then
      return fail("shape_range", "index")
    end
    -- The native party state includes a trailing CANCEL index in normal
    -- mode. It is a source boundary, not a Clean-visible party row; keep
    -- the clean selection attached to a real Pokemon while B remains the
    -- sole back action.
    local selectedIndex = math.min(sourceSelectedIndex, count)
    if sourceSelectedIndex > count then
      local previous = partyCursorMemory[state]
      local wrappedToFirst = previous == count
      selectedIndex = wrappedToFirst and 1 or count
      -- The host updates its cursor before the presentation hook runs. Keep
      -- the source cursor aligned with the visible last row so A cannot
      -- dispatch the host's hidden CANCEL action on the next update. The
      -- target also preserves the direction that caused the boundary wrap.
      rawset(state, "index", selectedIndex)
    end
    partyCursorMemory[state] = selectedIndex

    local actionMap = Actions.new("Gen2PartyMenu")
    local party, rows = {}, {}
    for sourceIndex = 1, count do
      local snapshot, code, detail = monSnapshot(state,
        rawget(sourceParty, sourceIndex), sourceIndex)
      if not snapshot then return nil, code, detail end
      party[sourceIndex] = snapshot
      local actionId = inputAction(actionMap,
        "party.choose." .. sourceIndex, switching and "switch_target"
          or (rawget(state, "wantsSubmenu") and "open_actions" or "choose"),
        "party.mon." .. sourceIndex, sourceIndex, "a", true)
      rows[sourceIndex] = {
        id="party.mon." .. sourceIndex, sourceIndex=sourceIndex,
        kind=snapshot.isEgg and "egg" or "pokemon", label=snapshot.name,
        level=snapshot.level, hp=snapshot.hp, maxHp=snapshot.maxHp,
        status=snapshot.status, hpFraction=snapshot.hpFraction,
        gender=snapshot.gender, genderIcon=Data.copy(snapshot.genderIcon),
        types=Data.copy(snapshot.types),
        icon=Data.copy(snapshot.icon), isEgg=snapshot.isEgg,
        held=snapshot.item ~= nil,
        selected=selectedIndex == sourceIndex,
        switchOrigin=switchFrom == sourceIndex,
        actionId=actionId,
      }
    end
    inputAction(actionMap, "party.back", "back", "party", nil, "b", true)

    local submenu, submenuCode, submenuDetail = submenuSnapshot(
      state, sourceParty, party, actionMap)
    if submenuCode then return nil, submenuCode, submenuDetail end
    local selectedMon = selectedIndex <= count and party[selectedIndex] or nil
    local artwork
    if selectedMon then
      local artCode, artDetail
      artwork, artCode, artDetail = Party.artworkFor(state,
        rawget(sourceParty, selectedIndex))
      if not artwork then return nil, artCode, artDetail end
    end
    local selection = selectedMon and {
      kind=selectedMon.isEgg and "egg" or "pokemon",
      sourceIndex=selectedIndex, id="party.mon." .. selectedIndex,
      label=selectedMon.name,
    }
    local selectedSubmenu = submenu and submenu.items[submenu.selectedIndex]
    local heldItemState = selectedSubmenu
      and (selectedSubmenu.kind == "held_item" or selectedSubmenu.kind == "mail")
      and {
        active=true, sourceSlot=submenu.sourceSlot,
        action=selectedSubmenu.kind,
        held=party[submenu.sourceSlot].item,
      } or nil
    local model = {
      schema="clean_ui.presenter_model.v1", screenId="Gen2PartyMenu",
      family="party", preset="L", title="PARTY",
      mode=submenu and "actions" or (switching and "switch" or "party"),
      prompt=switching and "Move to where?" or prompt,
      navigation={
        selectedIndex=selectedIndex, selectedId=selection.id,
        sourceSelectedIndex=sourceSelectedIndex,
        itemCount=#rows, scroll=0, switchFrom=switchFrom,
      },
      rows=rows, party=party, selection=selection,
      selectedPokemon=selectedMon, artwork=artwork,
      submenu=submenu, heldItemState=heldItemState,
    }
    model.actionDescriptors = Actions.describe(actionMap)
    if not Data.isFunctionFree(model) then
      return fail("model_not_data", "Gen2PartyMenu")
    end
    return { model=model, actions=actionMap }
  end

  Party.genderIconFor = genderIconFor
  Party.genderFor = genderFor
  return Party
end
