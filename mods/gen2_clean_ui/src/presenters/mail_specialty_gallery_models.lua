return function(ctx)
  local Data = ctx.load("adapters.data")
  local Models = ctx.load("presenters.mail_specialty_models")
  local Presenters = ctx.load("presenters.mail_specialty_presenters")
  local GalleryModels = {}

  local FOUR_COLORS = {
    { 255, 255, 255 }, { 160, 200, 248 },
    { 48, 96, 192 }, { 0, 0, 0 },
  }
  local PAIR = {
    normal={ { 160, 200, 248 }, { 48, 96, 192 } },
    shiny={ { 248, 216, 120 }, { 176, 104, 40 } },
  }
  local VARIANTS = {
    Gen2MailCompose={ "compose" },
    Gen2MailMenu={ "actions", "message", "confirm" },
    Gen2MailRead={ "read" },
    Gen2MailboxMenu={ "list", "submenu", "message", "confirm" },
    Gen2DecorationMenu={ "category", "items", "side", "message" },
    Gen2TradeMenu={ "offer", "confirm", "party_picker" },
    Gen2NamePick={ "presets", "slide" },
    Gen2InitClock={ "clock", "day", "confirm" },
    Gen2Diploma={ "diploma" },
    Gen2PhotoStudio={ "photo" },
    Gen2UnownPrinter={ "forms" },
    Gen2HallOfFame={ "viewer", "induction_native" },
  }
  local NATIVE = {
    ["Gen2TradeMenu\0party_picker"]="native_child",
    ["Gen2HallOfFame\0induction_native"]="native_scope",
  }

  local function clone(value)
    return Data.copy(value, { maxDepth=18, maxEntries=8192 })
  end

  local function pages(...)
    return { pages={ ... }, page=1 }
  end

  local function confirm(...)
    return { pages={ ... }, page=1, choice=1 }
  end

  local function mailEntry()
    return {
      type="FLOWER_MAIL", message="MEET ME IN\nGOLDENROD CITY",
      author="LYRA", authorId=2468, species="MAREEP",
    }
  end

  local function mailSave()
    return {
      party={{ species="TOTODILE", nickname="TOTO", item="FLOWER_MAIL" }},
      mail={ party={ mailEntry() }, box={ mailEntry(), {
        type="SURF_MAIL", message="THE WAVES ARE\nGREAT TODAY",
        author="KRIS", authorId=1357, species="LAPRAS",
      } } },
    }
  end

  local function pokemonData()
    local letters = {}
    for index = 1, 26 do
      local letter = string.char(64 + index)
      letters[letter] = {
        spriteFront="assets/generated/battle/front/unown_"
          .. letter:lower() .. ".png",
      }
    end
    return {
      TOTODILE={ name="TOTODILE", dex=158,
        spriteFront="assets/generated/battle/front/totodile.png" },
      UNOWN={ name="UNOWN", dex=201,
        spriteFront="assets/generated/battle/front/unown_a.png",
        letters=letters },
      ABRA={ name="ABRA" }, MACHOP={ name="MACHOP" },
    }
  end

  local function palettes()
    return { pokemon={ TOTODILE=clone(PAIR), UNOWN=clone(PAIR) } }
  end

  local function base(screenId)
    if screenId == "Gen2MailCompose" then
      return { text="HELLO, GOLD!", lower=false, row=0, col=0,
        gfx={}, tiles={} }
    end
    if screenId == "Gen2MailMenu" then
      return { save=mailSave(), slot=1, index=1, reading=false }
    end
    if screenId == "Gen2MailRead" then return { entry=mailEntry() } end
    if screenId == "Gen2MailboxMenu" then
      return { save=mailSave(), index=1, scroll=0, picking=false }
    end
    if screenId == "Gen2DecorationMenu" then
      return {
        save={}, state={ bed=2, poster=16 }, changed=false,
        mode="category", index=1, scroll=0,
        categories={
          { id=1, label="BED", members={ 2, 3, 4, 5 } },
          { id=29, label="ORNAMENT", members={ 30, 31, 32 } },
        },
      }
    end
    if screenId == "Gen2TradeMenu" then
      return {
        save={}, data={ pokemon=pokemonData() }, eventTables={}, id=0,
        row={ id=0, give="ABRA", get="MACHOP", nickname="MUSCLE",
          gender="TRADE_GENDER_EITHER", dialog="TRADE_DIALOG_INTRO",
          otName="MIKE", otId=37460 },
        message=pages({ "I COLLECT POKEMON.", "Do you have ABRA?" }),
      }
    end
    if screenId == "Gen2NamePick" then
      return {
        items={ "NEW NAME", "GOLD", "HIRO", "TAYLOR", "KARL" },
        cursor=1, pic={ synthetic=true }, picColors=clone(FOUR_COLORS),
        fontOk=true, picX=13,
      }
    end
    if screenId == "Gen2InitClock" then
      return { mode="clock", save={}, autoConfirm=false,
        hour=10, minute=30, day=0, yesNo=1, phase="hour", page=1 }
    end
    if screenId == "Gen2Diploma" then
      return { playerName="GOLD", gfx=nil, images={}, done=false }
    end
    if screenId == "Gen2PhotoStudio" then
      return {
        mon={ species="TOTODILE", nickname="TOTO", level=18,
          hp=50, maxHp=52, gender="male", shiny=false,
          ot="GOLD", otId=2468, moves={{ id="SCRATCH", pp=35 }} },
        playerName="GOLD", pokemon=pokemonData(),
        moves={ SCRATCH={ name="SCRATCH" } }, palettes=palettes(),
        done=false, picCache={},
      }
    end
    if screenId == "Gen2UnownPrinter" then
      return { pokemon=pokemonData(), palettes=palettes(), index=3,
        done=false, picCache={} }
    end
    if screenId == "Gen2HallOfFame" then
      local entry = { winCount=2, mons={{
        species="TOTODILE", nickname="TOTO", level=42, otId=2468,
        gender="male", shiny=false,
        dvs={ attack=12, defense=10, speed=11, special=13 },
      }} }
      return {
        mode="view", phase="display", save={ hallOfFame={
          count=2, teams={ clone(entry) },
        } }, entry=entry, team=1, index=1,
        pokemon=pokemonData(), palettes=palettes(), picCache={},
        frames=12, done=false,
      }
    end
    error("missing Gallery source-state builder for " .. tostring(screenId))
  end

  local function stateFor(screenId, variant)
    local state = base(screenId)
    state.screenId = screenId
    if screenId == "Gen2MailMenu" then
      if variant == "message" then
        state.message = pages({ "The MAIL was sent", "to your PC." })
      elseif variant == "confirm" then
        state.confirm = confirm({ "Send the removed MAIL", "to your PC?" })
      end
    elseif screenId == "Gen2MailboxMenu" then
      if variant == "submenu" then state.submenu = { index=2 }
      elseif variant == "message" then
        state.message = pages({ "The MAIL was put", "in the PACK." })
      elseif variant == "confirm" then
        state.confirm = confirm({ "The message will be", "lost. OK?" })
      end
    elseif screenId == "Gen2DecorationMenu" then
      if variant == "items" or variant == "message" then
        state.mode, state.index, state.scroll = "items", 2, 0
        state.category = state.categories[1]
        state.rows = { 2, 3, 1, 0 }
      elseif variant == "side" then
        state.mode, state.pendingDeco, state.sideIndex = "side", 30, 1
      end
      if variant == "message" then
        state.pages, state.pageIndex = { "Set up the\nPINK BED." }, 1
      end
    elseif screenId == "Gen2TradeMenu" then
      if variant == "confirm" then
        state.message = nil
        state.confirm = confirm({ "Would you like to", "trade POKEMON?" })
      elseif variant == "party_picker" then
        state.message, state.picking = nil, true
      end
    elseif screenId == "Gen2NamePick" and variant == "slide" then
      state.slide, state.picX, state.pendingName = "out", 9, "GOLD"
    elseif screenId == "Gen2InitClock" then
      if variant == "day" then
        state.mode, state.phase, state.day = "day", "day", 3
      elseif variant == "confirm" then
        state.phase, state.yesNo = "confirm-minute", 2
      end
    elseif screenId == "Gen2HallOfFame"
        and variant == "induction_native" then
      state.mode, state.phase, state.team = "induct", "backpic", nil
    end
    return state
  end

  local definitions = {}
  for _, screenId in ipairs(Models.ids()) do
    for _, variant in ipairs(VARIANTS[screenId] or {}) do
      local state = stateFor(screenId, variant)
      local expectedNative = NATIVE[screenId .. "\0" .. variant]
      local bundle, code, detail = Models.extract(screenId, state)
      local fixture = {
        id="gen2.services." .. screenId:gsub("^Gen2", ""):gsub("(%u)",
          function(letter) return "_" .. letter:lower() end):gsub("^_", "")
          .. "." .. variant,
        game="gen2", family="services", screenId=screenId,
        variant=variant, sourceState=clone(state),
        synthetic=true, expectedNative=expectedNative ~= nil,
      }
      if expectedNative then
        assert(bundle == nil and code == expectedNative,
          ("%s.%s must remain native (%s/%s)"):format(
            screenId, variant, tostring(code), tostring(detail)))
        fixture.modelReady=false
        fixture.statusOnly=true
        fixture.nativeCode=code
        fixture.nativeDetail=detail
      else
        assert(type(bundle) == "table" and type(bundle.model) == "table",
          ("%s.%s adapter: %s %s"):format(
            screenId, variant, tostring(code), tostring(detail)))
        local presentation, convertCode, convertDetail = Presenters.convert(
          screenId, bundle.model)
        assert(type(presentation) == "table",
          ("%s.%s presenter: %s %s"):format(
            screenId, variant, tostring(convertCode), tostring(convertDetail)))
        -- `model` follows the existing product Gallery source-fixture
        -- convention. `presentation` proves that this exact source snapshot
        -- has already traversed the production converter.
        fixture.sourceModel=clone(bundle.model)
        fixture.model=clone(bundle.model)
        fixture.presentation=presentation
        fixture.preset=bundle.model.preset
        fixture.modelReady=true
        fixture.statusOnly=false
      end
      assert(Data.isFunctionFree(fixture),
        screenId .. "." .. variant .. " Gallery fixture must be data-only")
      definitions[#definitions + 1] = fixture
    end
  end

  function GalleryModels.galleryFixtures()
    return clone(definitions)
  end

  function GalleryModels.variantsFor(screenId)
    return clone(VARIANTS[screenId] or {})
  end

  function GalleryModels.count()
    return #definitions
  end

  return GalleryModels
end
