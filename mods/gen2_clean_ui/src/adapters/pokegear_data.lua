return function(ctx)
  local Data = ctx.load("adapters.data")
  local PokegearData = {}

  local DAYS = {
    "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY",
    "SATURDAY",
  }
  local CARD_LABELS = {
    clock = "CLOCK", map = "MAP", phone = "PHONE", radio = "RADIO",
  }
  local CARD_ORDER = { clock=1, map=2, phone=3, radio=4 }
  local CARD_META = {
    clock={ icon="clock", accent="amber", subtitle="TIME & DAY" },
    map={ icon="map", accent="green", subtitle="JOHTO / KANTO" },
    phone={ icon="phone", accent="blue", subtitle="CONTACTS" },
    radio={ icon="radio", accent="violet", subtitle="BROADCAST" },
  }
  local FREQUENCIES = {
    { knob=16, frequency="04.5" },
    { knob=28, frequency="07.5" },
    { knob=32, frequency="08.5" },
    { knob=52, frequency="13.5" },
    { knob=64, frequency="16.5" },
    { knob=72, frequency="18.5" },
    { knob=78, frequency="20.0" },
    { knob=80, frequency="20.5" },
  }
  local STATION_NAMES = {
    OAKS_POKEMON_TALK = "OAK'S POKEMON TALK",
    POKEDEX_SHOW = "POKEDEX SHOW",
    POKEMON_MUSIC = "POKEMON MUSIC",
    LUCKY_CHANNEL = "LUCKY CHANNEL",
    PLACES_AND_PEOPLE = "PLACES & PEOPLE",
    LETS_ALL_SING = "LET'S ALL SING!",
    ROCKET_RADIO = "LET'S ALL SING!",
    POKE_FLUTE_RADIO = "POKE FLUTE",
    UNOWN_RADIO = "?????",
    EVOLUTION_RADIO = "?????",
  }
  local NON_TRAINER_NAMES = {
    [0] = "----------", [1] = "MOM", [2] = "BIKE SHOP",
    [3] = "BILL", [4] = "PROF. ELM",
  }

  local function finite(value)
    return type(value) == "number" and value == value
      and value ~= math.huge and value ~= -math.huge
  end

  local function integer(value, minimum, maximum)
    return finite(value) and value == math.floor(value)
      and (minimum == nil or value >= minimum)
      and (maximum == nil or value <= maximum)
  end

  local function arrayCount(value, maximum)
    if type(value) ~= "table" then return nil end
    for index = 1, maximum + 1 do
      if rawget(value, index) == nil then return index - 1 end
    end
    return nil
  end

  local function tableAt(source, key)
    local value = type(source) == "table" and rawget(source, key) or nil
    return type(value) == "table" and value or nil
  end

  local function numberArray(value, maximum)
    if type(value) ~= "table" then return nil end
    local count = arrayCount(value, maximum)
    if not count then return nil end
    local output = {}
    for index = 1, count do
      local item = Data.integer(rawget(value, index))
      if item == nil then return nil end
      output[index] = item
    end
    return output
  end

  local function nativeGraphic(state)
    local menuGfx = tableAt(state, "menuGfx")
    local gfx = menuGfx and tableAt(menuGfx, "pokegear")
    local directGfx = tableAt(state, "gfx")
    if not gfx then gfx = directGfx and tableAt(directGfx, "pokegear") end
    if not gfx then gfx = directGfx end
    local game = tableAt(state, "game")
    local data = tableAt(game, "data")
    local dataMenuGfx = tableAt(data, "gen2MenuGfx")
      or tableAt(data, "menuGfx")
    if not gfx then gfx = dataMenuGfx and tableAt(dataMenuGfx, "pokegear") end
    if not gfx then return nil end

    local tiles = Data.text(rawget(gfx, "tiles"))
    if tiles == "" then return nil end
    local output = {
      kind="tilemap",
      sheet={
        path=tiles,
        wide=Data.integer(rawget(gfx, "tilesWide"), 16),
        townMapTiles=Data.integer(rawget(gfx, "townMapTiles"), 48),
      },
      width=20,
      height=18,
    }
    local sprites = Data.text(rawget(gfx, "sprites"))
    if sprites ~= "" then
      output.cursorSheet={
        path=sprites,
        wide=Data.integer(rawget(gfx, "spritesWide"), 2),
      }
    end

    local maps = tableAt(gfx, "maps")
    if maps then
      output.maps = {}
      for _, region in ipairs({ "johto", "kanto" }) do
        local values = numberArray(rawget(maps, region), 1024)
        if values then output.maps[region] = values end
      end
    end
    local cards = tableAt(gfx, "cards")
    if cards then
      output.cards = {}
      for _, card in ipairs({ "clock", "phone", "radio" }) do
        local values = numberArray(rawget(cards, card), 1024)
        if values then output.cards[card] = values end
      end
    end
    local palMap = numberArray(rawget(gfx, "palMap"), 256)
    if palMap then output.palMap = palMap end
    if type(rawget(gfx, "palettes")) == "table" then
      output.palettes = Data.copy(rawget(gfx, "palettes"), {
        maxDepth=4, maxEntries=64,
      })
    end
    return output
  end

  local function numberAt(source, key, fallback)
    local value = type(source) == "table" and rawget(source, key) or nil
    if not finite(value) then return fallback end
    return value
  end

  local function modulo(value, divisor)
    return ((value % divisor) + divisor) % divisor
  end

  local function hostNumber(format, fallback)
    local ok, value = pcall(os.date, format)
    value = ok and tonumber(value) or nil
    return finite(value) and value or fallback
  end

  function PokegearData.battleOwned(state, context)
    if context and context.battleActive then return true end
    if type(state) ~= "table" then return false end
    if rawget(state, "battle") == true
        or rawget(state, "wantsBattleSubmenu") == true then
      return true
    end
    local game = tableAt(state, "game")
    local stack = tableAt(game, "stack")
    local states = tableAt(stack, "states")
    if not states then return false end
    for index = 1, math.min(arrayCount(states, 64) or 64, 64) do
      local candidate = rawget(states, index)
      local id = type(candidate) == "table"
        and rawget(candidate, "screenId") or nil
      if id == "Gen2BattleState" or id == "Gen2BattleTransition" then
        return true
      end
    end
    return false
  end

  function PokegearData.rejectCustomDraw(state)
    return type(state) == "table"
      and (rawget(state, "draw") ~= nil
        or rawget(state, "drawWidescreen") ~= nil)
  end

  function PokegearData.cards(state)
    local source = tableAt(state, "cards")
    local count = source and arrayCount(source, 4) or nil
    if not count or count < 1 then
      return nil, "cards_shape", "one to four cards required"
    end
    local cards, seen, previousOrder = {}, {}, 0
    for index = 1, count do
      local row = rawget(source, index)
      local id = type(row) == "table" and Data.id(rawget(row, "id")) or nil
      if not id or not CARD_LABELS[id] or seen[id] then
        return nil, "cards_shape", "unknown or duplicate card"
      end
      if CARD_ORDER[id] <= previousOrder then
        return nil, "cards_shape", "card order"
      end
      previousOrder = CARD_ORDER[id]
      seen[id] = true
      cards[index] = {
        id=id,
        label=Data.text(rawget(row, "label"), CARD_LABELS[id]),
        sourceIndex=index,
      }
    end
    return cards
  end

  function PokegearData.clock(state)
    local supplied = tableAt(state, "clock")
    if supplied then
      local hour = Data.integer(rawget(supplied, "hour"))
      local minute = Data.integer(rawget(supplied, "minute"))
      local weekday = Data.integer(rawget(supplied, "weekday"))
      if not integer(hour, 0, 23) or not integer(minute, 0, 59)
          or not integer(weekday, 1, 7) then
        return nil, "clock_shape"
      end
      return {
        hour=hour, minute=minute, weekday=weekday,
        day=DAYS[weekday], period=hour < 12 and "AM" or "PM",
      }
    end

    local game = tableAt(state, "game") or {}
    local world = tableAt(game, "world") or {}
    local save = tableAt(state, "save") or tableAt(game, "save") or {}
    local rtc = tableAt(save, "rtc") or {}
    local hostMinutes = hostNumber("%H", 0) * 60 + hostNumber("%M", 0)
    local startMinute = tonumber(rawget(rtc, "startMinute")) or 0
    local total = modulo(hostMinutes + startMinute, 24 * 60)
    local hour = Data.integer(rawget(world, "clockHour"),
      math.floor(total / 60))
    local minute = total % 60
    local hostDay = hostNumber("%w", 0)
    local startDay = tonumber(rawget(rtc, "startDay")) or 0
    local dayZero = Data.integer(rawget(world, "clockDay"),
      modulo(hostDay + startDay, 7))
    if not integer(hour, 0, 23) or not integer(dayZero, 0, 6) then
      return nil, "clock_shape"
    end
    local weekday = dayZero + 1
    return {
      hour=hour, minute=minute, weekday=weekday,
      day=DAYS[weekday], period=hour < 12 and "AM" or "PM",
    }
  end

  local function landmarkTable(state)
    local registry = tableAt(state, "landmarks")
    return registry and tableAt(registry, "landmarks") or nil
  end

  local function landmarkByIndex(state, wanted)
    local rows = landmarkTable(state)
    if not rows or not integer(wanted, 1, 94) then return nil end
    local key, row = next(rows, nil)
    local visited = 0
    while key ~= nil and visited < 256 do
      if type(row) == "table" and rawget(row, "index") == wanted then
        return key, row
      end
      visited = visited + 1
      key, row = next(rows, key)
    end
    return nil
  end

  local function landmarkById(state, id)
    local rows = landmarkTable(state)
    local row = rows and rawget(rows, id) or nil
    return type(row) == "table" and row or nil
  end

  function PokegearData.region(state)
    local id = rawget(state, "currentLandmark")
    local current = landmarkById(state, id)
    local index = current and Data.integer(rawget(current, "index"), 0) or 0
    if index == 94 or index < 46 then return "johto" end
    return "kanto"
  end

  local function landmarkSnapshot(id, row)
    if type(row) ~= "table" then return nil end
    return {
      id=Data.id(id),
      index=Data.integer(rawget(row, "index"), 0),
      name=Data.text(rawget(row, "name"), Data.text(id, "UNKNOWN")),
      x=Data.scalar(rawget(row, "x")),
      y=Data.scalar(rawget(row, "y")),
    }
  end

  function PokegearData.map(state)
    if not landmarkTable(state) then return nil, "landmarks_shape" end
    local region = PokegearData.region(state)
    local save = tableAt(state, "save") or {}
    local flags = tableAt(save, "flags") or {}
    local first, last = 1, 45
    if region == "kanto" then
      first = rawget(flags, "HALL_OF_FAME") == true and 46 or 87
      last = 93
    end
    local fly = tableAt(state, "fly")
    local flyCount = fly and arrayCount(fly, 128) or nil
    local selectedIndex = Data.integer(rawget(state, "flyIndex"), 1)
    local cursor = Data.integer(rawget(state, "mapCursor"))
    if fly then
      if not flyCount or flyCount < 1 or not integer(selectedIndex, 1, flyCount) then
        return nil, "fly_shape"
      end
      local selectedFly = rawget(fly, selectedIndex)
      cursor = type(selectedFly) == "table"
        and Data.integer(rawget(selectedFly, "index")) or nil
    end
    local playerId = rawget(state, "currentLandmark")
    local playerRow = landmarkById(state, playerId)
    if not playerRow then return nil, "current_landmark_unavailable" end
    if not cursor then
      cursor = playerRow and Data.integer(rawget(playerRow, "index")) or first
      if not integer(cursor, first, last) then cursor = first end
    end
    local currentId, currentRow = landmarkByIndex(state, cursor)
    if not currentRow then return nil, "map_cursor_unavailable" end
    local rows = {}
    for index = first, last do
      local id, row = landmarkByIndex(state, index)
      if row then
        local snap = landmarkSnapshot(id, row)
        snap.sourceIndex = #rows + 1
        snap.selected = index == cursor
        rows[#rows + 1] = snap
      end
    end
    local flyRows = {}
    if fly then
      for index = 1, flyCount do
        local row = rawget(fly, index)
        if type(row) ~= "table" then return nil, "fly_shape" end
        local name = Data.text(rawget(row, "name"))
        local landmarkIndex = Data.integer(rawget(row, "index"))
        if name == "" or not integer(landmarkIndex, 1, 94) then
          return nil, "fly_shape"
        end
        flyRows[index] = {
          id=Data.id(rawget(row, "id"), "fly." .. index),
          sourceIndex=index, name=name, label=name,
          index=landmarkIndex,
          spawn=Data.scalar(rawget(row, "spawn")),
          selected=index == selectedIndex,
        }
      end
    end
    local graphic = nativeGraphic(state)
    if graphic then
      graphic.region = region
      graphic.map = graphic.maps and graphic.maps[region] or nil
    end
    return {
      region=region,
      firstIndex=first,
      lastIndex=last,
      cursorIndex=cursor,
      current=landmarkSnapshot(currentId, currentRow),
      player=landmarkSnapshot(playerId, playerRow),
      rows=rows,
      flyRows=flyRows,
      flyIndex=fly and selectedIndex or nil,
      graphic=graphic,
    }
  end

  local function clockLabel(clock)
    if type(clock) ~= "table" then return "--:--" end
    local hour = clock.hour % 12
    if hour == 0 then hour = 12 end
    return ("%d:%02d %s"):format(hour, clock.minute or 0,
      clock.period or "")
  end

  function PokegearData.shell(state, cards, cardIndex, view, clock,
      map, radio, phone)
    local apps = {}
    for index, card in ipairs(cards or {}) do
      local meta = CARD_META[card.id] or {}
      apps[index] = {
        id=card.id,
        label=card.label,
        icon=meta.icon or card.id,
        accent=meta.accent or "blue",
        subtitle=meta.subtitle or "APP",
        order=index,
        selected=index == cardIndex,
        actionId=card.actionId,
      }
    end

    local active = apps[cardIndex] or {}
    local region = map and map.region or PokegearData.region(state)
    local service = phone and phone.service ~= false
    local signal = service and "ONLINE" or "NO SIGNAL"
    if radio and radio.on and not radio.current.station then
      signal = "DEAD AIR"
    end
    local shell = {
      schema="clean_ui.pokegear_shell.v1",
      device={
        kind="smartphone",
        family="pokegear",
        orientation="portrait",
        aspect="9:16",
        title="POKEGEAR",
        chrome="rounded",
      },
      launcher={
        kind="app_rail",
        axis="horizontal",
        selected=cardIndex,
        count=#apps,
        cards=Data.copy(apps),
      },
      apps=apps,
      activeApp=Data.copy(active),
      screen={
        id=view,
        kind=view == "strip" and "launcher" or "app",
        title=(view == "fly" and "FLY"
          or CARD_LABELS[active.id] or view):upper(),
      },
      statusBar={
        time=clockLabel(clock),
        day=clock and clock.day or "",
        region=(region or "johto"):upper(),
        signal=signal,
        radioOn=radio and radio.on == true or false,
      },
      navigation={
        source="native_pokegear",
        focus=view == "strip" and "app_rail" or view,
        horizontal=view == "strip" or view == "map",
        primary="a",
        back="b",
      },
    }
    local graphic = nativeGraphic(state)
    if graphic then shell.graphic = graphic end
    return shell
  end

  local function radioContext(state, clock)
    local save = tableAt(state, "save") or {}
    local pokegearFlags = tableAt(save, "pokegearFlags") or {}
    local engineFlags = tableAt(save, "engineFlags") or {}
    local flags = tableAt(save, "flags") or {}
    local hour = clock and clock.hour or 12
    local timeOfDay = Data.integer(rawget(state, "timeOfDay"))
    if timeOfDay == nil then
      timeOfDay = hour >= 4 and hour < 10 and 0
        or hour >= 10 and hour < 18 and 1 or 2
    end
    return {
      inJohto=PokegearData.region(state) == "johto",
      landmark=Data.id(rawget(state, "currentLandmark")),
      timeOfDay=timeOfDay,
      expnCard=rawget(pokegearFlags, "expn") == true
        or rawget(engineFlags, 3) == true,
      rocketSignal=rawget(flags, "ROCKET_SIGNAL") == true,
    }
  end

  local function resolveStation(index, context)
    if index == 1 then
      if not context.inJohto then return nil end
      return context.timeOfDay == 0 and "POKEDEX_SHOW"
        or "OAKS_POKEMON_TALK"
    elseif index == 2 then
      return context.inJohto and "POKEMON_MUSIC" or nil
    elseif index == 3 then
      return context.inJohto and "LUCKY_CHANNEL" or nil
    elseif index == 4 then
      return context.landmark == "LANDMARK_RUINS_OF_ALPH"
        and "UNOWN_RADIO" or nil
    elseif index == 5 then
      return not context.inJohto and "PLACES_AND_PEOPLE" or nil
    elseif index == 6 then
      return not context.inJohto and "LETS_ALL_SING" or nil
    elseif index == 7 then
      return not context.inJohto and context.expnCard
        and "POKE_FLUTE_RADIO" or nil
    elseif index == 8 and context.rocketSignal then
      local here = context.landmark
      if here == "LANDMARK_MAHOGANY_TOWN"
          or here == "LANDMARK_ROUTE_43"
          or here == "LANDMARK_LAKE_OF_RAGE" then
        return "EVOLUTION_RADIO"
      end
    end
    return nil
  end

  function PokegearData.radio(state, clock)
    local selected = Data.integer(rawget(state, "station"))
    if not integer(selected, 1, #FREQUENCIES) then
      return nil, "station_range"
    end
    local context = radioContext(state, clock)
    local tuned = Data.id(rawget(state, "radioShow"))
    local rows = {}
    for index, frequency in ipairs(FREQUENCIES) do
      local station = resolveStation(index, context)
      if index == selected and tuned then station = tuned end
      rows[index] = {
        id="frequency." .. index,
        sourceIndex=index,
        knob=frequency.knob,
        frequency=frequency.frequency,
        station=station,
        name=station and (STATION_NAMES[station] or station) or "DEAD AIR",
        selected=index == selected,
      }
    end
    local radio = tableAt(state, "radio")
    if radio then
      for _, key in ipairs({ "top", "bottom" }) do
        if type(rawget(radio, key)) ~= "string" then
          return nil, "radio_shape", key
        end
      end
    end
    local current = rows[selected]
    return {
      selectedIndex=selected,
      rows=rows,
      current=Data.copy(current),
      on=rawget(state, "radioOn") == true,
      show=tuned,
      top=radio and Data.text(rawget(radio, "top"), "") or "",
      bottom=radio and Data.text(rawget(radio, "bottom"), "") or "",
      music=radio and Data.id(rawget(radio, "music")) or nil,
    }
  end

  local function gameData(state)
    local game = tableAt(state, "game")
    return tableAt(game, "data") or tableAt(state, "data") or {}
  end

  local function contactRecord(state, contactId)
    if contactId == 0 then return { index=0, number=0 } end
    local rows = tableAt(gameData(state), "gen2PhoneContacts")
    if not rows then return nil end
    local key, row = next(rows, nil)
    local visited = 0
    while key ~= nil and visited < 256 do
      if type(row) == "table" and rawget(row, "index") == contactId then
        return row
      end
      visited = visited + 1
      key, row = next(rows, key)
    end
    return nil
  end

  local function trainerName(state, contact)
    local classId = Data.id(rawget(contact, "class"))
    local memberId = Data.id(rawget(contact, "member"))
    if not classId then
      local number = Data.integer(rawget(contact, "number"), 0)
      return NON_TRAINER_NAMES[number] or NON_TRAINER_NAMES[0], nil
    end
    local trainers = tableAt(state, "trainers")
      or tableAt(gameData(state), "trainers")
      or tableAt(gameData(state), "gen2Trainers")
    local classes = tableAt(trainers, "classes")
    local class = classes and tableAt(classes, classId) or nil
    local className = Data.text(class and rawget(class, "name"), classId)
    local rows = class and tableAt(class, "trainers") or nil
    local count = rows and arrayCount(rows, 512) or 0
    for index = 1, count or 0 do
      local row = rawget(rows, index)
      if type(row) == "table" and rawget(row, "id") == memberId then
        return Data.text(rawget(row, "name"), memberId), className
      end
    end
    return memberId or "UNKNOWN", className
  end

  local function contactList(state)
    local save = tableAt(state, "save") or {}
    local phone = tableAt(save, "phone")
    local source = phone and tableAt(phone, "list") or nil
    local output = {}
    if source then
      for slot = 1, 10 do
        local id = Data.integer(rawget(source, slot), 0)
        if not integer(id, 0, 255) then return nil, "phone_list_shape" end
        output[slot] = id
      end
      return output
    end
    for slot = 1, 10 do output[slot] = 0 end
    local legacy = tableAt(save, "phoneContacts")
    if not legacy then return output end
    local slot = 1
    local key, owned = next(legacy, nil)
    local visited = 0
    while key ~= nil and visited < 256 and slot <= 10 do
      local id = tonumber(key)
      if owned and integer(id, 1, 255) then
        output[slot], slot = id, slot + 1
      end
      visited = visited + 1
      key, owned = next(legacy, key)
    end
    return output
  end

  local function mapHasService(state)
    local map = tableAt(state, "mapDef")
    if not map then
      local game = tableAt(state, "game")
      local world = tableAt(game, "world")
      local liveMap = tableAt(world, "map")
      map = liveMap and tableAt(liveMap, "def") or nil
    end
    local service
    if map then service = rawget(map, "phoneService") end
    return service == nil or service == true
  end

  function PokegearData.phone(state)
    local cursor = Data.integer(rawget(state, "phoneCursor"))
    local scroll = Data.integer(rawget(state, "phoneScroll"))
    local submenuCursor = Data.integer(rawget(state, "phoneSubmenuCursor"))
    if not integer(cursor, 0, 3) or not integer(scroll, 0, 6)
        or not integer(submenuCursor, 0, 2) then
      return nil, "phone_navigation_shape"
    end
    local ids, listCode = contactList(state)
    if not ids then return nil, listCode end
    local selectedIndex = scroll + cursor + 1
    local rows = {}
    for slot = 1, 10 do
      local id = ids[slot]
      local contact = contactRecord(state, id)
      if id ~= 0 and not contact then
        return nil, "contact_unavailable", tostring(id)
      end
      contact = contact or { number=0 }
      local name, className = trainerName(state, contact)
      local number = Data.integer(rawget(contact, "number"), 0)
      local deletable = rawget(contact, "class") ~= nil
        or (number ~= 0 and number ~= 1 and number ~= 4)
      rows[slot] = {
        id=id == 0 and ("empty." .. slot) or ("contact." .. id),
        contactId=id,
        sourceIndex=slot,
        label=name,
        className=className,
        right=className or "",
        empty=id == 0,
        disabled=id == 0,
        deletable=deletable,
        selected=slot == selectedIndex,
      }
    end

    local submenuId = rawget(state, "phoneSubmenu")
    local submenu
    if submenuId ~= nil then
      if submenuId ~= "callDeleteCancel" and submenuId ~= "callCancel" then
        return nil, "phone_submenu_shape"
      end
      local labels = submenuId == "callDeleteCancel"
        and { "CALL", "DELETE", "CANCEL" } or { "CALL", "CANCEL" }
      if submenuCursor >= #labels then return nil, "phone_submenu_shape" end
      local submenuRows = {}
      for index, label in ipairs(labels) do
        submenuRows[index] = {
          id=label:lower(), sourceIndex=index, label=label,
          selected=index == submenuCursor + 1,
        }
      end
      submenu = {
        id=submenuId,
        selectedIndex=submenuCursor + 1,
        rows=submenuRows,
      }
    end

    local sourceCall = rawget(state, "call")
    local call
    if sourceCall ~= nil then
      if type(sourceCall) ~= "table" then return nil, "call_shape" end
      local kind = Data.id(rawget(sourceCall, "kind"))
      if not kind then return nil, "call_shape", "kind" end
      call = {
        contact=Data.integer(rawget(sourceCall, "contact"),
          rows[selectedIndex].contactId),
        kind=kind,
        text=Data.text(rawget(sourceCall, "text"), ""),
        name=Data.text(rawget(sourceCall, "name"), rows[selectedIndex].label),
        className=Data.text(rawget(sourceCall, "className"), ""),
        wrongNumber=rawget(sourceCall, "wrongNumber") == true,
      }
    end
    return {
      rows=rows,
      selectedIndex=selectedIndex,
      cursor=cursor,
      scroll=scroll,
      visibleFirst=scroll + 1,
      visibleLast=scroll + 4,
      service=mapHasService(state),
      submenu=submenu,
      call=call,
    }
  end

  function PokegearData.stationName(station)
    return STATION_NAMES[station] or Data.text(station, "UNKNOWN STATION")
  end

  PokegearData.CARD_LABELS = CARD_LABELS
  PokegearData.DAYS = DAYS
  PokegearData.FREQUENCIES = FREQUENCIES
  PokegearData.STATION_NAMES = STATION_NAMES
  PokegearData.arrayCount = arrayCount
  PokegearData.integer = integer
  return PokegearData
end
