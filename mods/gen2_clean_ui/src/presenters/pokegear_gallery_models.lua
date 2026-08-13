return function(ctx)
  local Data = ctx.load("adapters.data")
  local Pokegear = ctx.load("adapters.pokegear")
  local MapRadio = ctx.load("adapters.map_radio")
  local Models = {}

  local function clone(value)
    return Data.copy(value, { maxDepth=16, maxEntries=8192 })
  end

  local function gameData()
    return {
      gen2PhoneContacts={
        PHONE_MOM={ index=1, number=1 },
        PHONE_ELM={ index=4, number=4 },
        PHONE_YOUNGSTER_JOEY={
          index=15, class="YOUNGSTER", member="JOEY1",
        },
      },
      gen2Trainers={ classes={
        YOUNGSTER={ name="YOUNGSTER", trainers={
          { id="JOEY1", name="JOEY" },
        } },
      } },
    }
  end

  local function landmarks()
    return { landmarks={
      LANDMARK_NEW_BARK_TOWN={
        index=1, name="NEW BARK TOWN", x=112, y=88,
      },
      LANDMARK_ROUTE_29={ index=2, name="ROUTE 29", x=96, y=88 },
      LANDMARK_CHERRYGROVE_CITY={
        index=3, name="CHERRYGROVE CITY", x=80, y=88,
      },
      LANDMARK_ROUTE_30={ index=4, name="ROUTE 30", x=80, y=72 },
      LANDMARK_VIOLET_CITY={ index=5, name="VIOLET CITY", x=64, y=56 },
      LANDMARK_RUINS_OF_ALPH={
        index=6, name="RUINS OF ALPH", x=56, y=64,
      },
    } }
  end

  local function saveData()
    return {
      phone={ list={ 1, 4, 15, 0, 0, 0, 0, 0, 0, 0 } },
      phoneContacts={ [1]=true, [4]=true, [15]=true },
      pokegearFlags={ map=true, phone=true, radio=true },
      engineFlags={ [0]=true, [1]=true, [2]=true },
      flags={},
      rtc={ startMinute=0, startDay=0 },
    }
  end

  local function cards()
    return {
      { id="clock", label="CLOCK" },
      { id="map", label="MAP" },
      { id="phone", label="PHONE" },
      { id="radio", label="RADIO" },
    }
  end

  local function baseState()
    local data = gameData()
    local save = saveData()
    local game = {
      data=data,
      save=save,
      world={ map={ def={ id="NEW_BARK_TOWN", phoneService=true } } },
      stack={ states={} },
    }
    return {
      screenId="Gen2Pokegear",
      game=game,
      save=save,
      cards=cards(),
      cardIndex=1,
      mode="strip",
      station=1,
      phoneCursor=0,
      phoneScroll=0,
      phoneSubmenuCursor=0,
      radioOn=false,
      landmarks=landmarks(),
      currentLandmark="LANDMARK_NEW_BARK_TOWN",
      clock={ hour=10, minute=37, weekday=2 },
      trainers=data.gen2Trainers,
      mapDef={ id="NEW_BARK_TOWN", phoneService=true },
    }
  end

  local function forCard(index)
    local state = baseState()
    state.mode = "card"
    state.cardIndex = index
    return state
  end

  local definitions = {}
  local function add(screenId, variant, state)
    assert(Data.isFunctionFree(state),
      screenId .. "." .. variant .. " source fixture must be function-free")
    definitions[#definitions + 1] = {
      screenId=screenId,
      variant=variant,
      state=state,
    }
  end

  add("Gen2Pokegear", "strip", baseState())
  add("Gen2Pokegear", "clock", forCard(1))

  local map = forCard(2)
  map.mapCursor = 4
  add("Gen2Pokegear", "map", map)

  local fly = baseState()
  fly.mode = "card"
  fly.cards = { { id="map", label="FLY" } }
  fly.cardIndex = 1
  fly.fly = {
    { id="new_bark", index=1, name="NEW BARK TOWN", spawn="SPAWN_HOME" },
    { id="cherrygrove", index=3, name="CHERRYGROVE CITY",
      spawn="SPAWN_CHERRYGROVE" },
    { id="violet", index=5, name="VIOLET CITY", spawn="SPAWN_VIOLET" },
  }
  fly.flyIndex = 2
  add("Gen2Pokegear", "fly", fly)

  local radio = forCard(4)
  radio.station = 1
  radio.radioOn = true
  radio.radioShow = "OAKS_POKEMON_TALK"
  radio.radio = {
    top="PROF. OAK'S POKEMON TALK!",
    bottom="POKEMON may be seen near ROUTE 29.",
    music="Music_ProfOaksPokemonTalk",
    cur="RADIO_SCROLL", delay=48,
  }
  add("Gen2Pokegear", "radio", radio)

  add("Gen2Pokegear", "phone", forCard(3))

  local submenu = forCard(3)
  submenu.phoneCursor = 2
  submenu.phoneSubmenu = "callDeleteCancel"
  submenu.phoneSubmenuCursor = 1
  add("Gen2Pokegear", "phone_submenu", submenu)

  local call = forCard(3)
  call.phoneCursor = 2
  call.call = {
    contact=15, kind="connected", name="JOEY", className="YOUNGSTER",
    text="My RATTATA is looking awesome!",
  }
  add("Gen2Pokegear", "call", call)

  local noSignal = forCard(3)
  noSignal.mapDef.phoneService = false
  noSignal.call = {
    contact=1, kind="nosignal", name="MOM",
    text="You're out of the service area.",
  }
  add("Gen2Pokegear", "no_signal", noSignal)

  local wallGear = baseState()
  local wallRadio = {
    screenId="Gen2MapRadio",
    game=wallGear.game,
    gear=wallGear,
    station="LUCKY_CHANNEL",
    stationName="Lucky Channel",
    radio={
      top="Your lucky number is 12345!",
      bottom="Check the Radio Tower.",
      music="Music_GameCorner", cur="RADIO_SCROLL", delay=32,
    },
    hold=0,
    radioMusicPlaying="Music_GameCorner",
  }
  add("Gen2MapRadio", "station", wallRadio)

  local function adapterFor(screenId)
    return screenId == "Gen2Pokegear" and Pokegear or MapRadio
  end

  function Models.sourceFixtures()
    local output = {}
    for index, fixture in ipairs(definitions) do
      output[index] = {
        screenId=fixture.screenId,
        variant=fixture.variant,
        state=clone(fixture.state),
      }
    end
    return output
  end

  function Models.galleryFixtures()
    local output = {}
    for index, fixture in ipairs(Models.sourceFixtures()) do
      local adapter = adapterFor(fixture.screenId)
      local bundle, code, detail = adapter.extract(fixture.state, {
        synthetic=true,
      })
      assert(type(bundle) == "table" and type(bundle.model) == "table",
        ("invalid %s.%s Gallery model: %s %s"):format(
          fixture.screenId, fixture.variant, tostring(code), tostring(detail)))
      assert(Data.isFunctionFree(bundle.model),
        fixture.screenId .. "." .. fixture.variant
          .. " Gallery model must be function-free")
      output[index] = {
        screenId=fixture.screenId,
        variant=fixture.variant,
        model=bundle.model,
      }
    end
    return output
  end

  function Models.count()
    return #definitions
  end

  function Models.variantsFor(screenId)
    local output = {}
    for _, fixture in ipairs(definitions) do
      if fixture.screenId == screenId then
        output[#output + 1] = fixture.variant
      end
    end
    return output
  end

  return Models
end
