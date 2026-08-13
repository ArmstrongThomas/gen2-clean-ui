return function(ctx)
  local Data = ctx.load("adapters.data")
  local Models = {}

  local ORDER = {
    "Gen2PackMenu",
    "Gen2PartyMenu",
    "Gen2SummaryMenu",
    "Gen2PokedexMenu",
    "Gen2TrainerCard",
    "Gen2SaveMenu",
    "Gen2NamingScreen",
    "Gen2CenterPcMenu",
    "Gen2PcMenu",
    "Gen2BoxMenu",
    "Gen2ItemPcMenu",
  }

  local VARIANTS = {
    Gen2PackMenu = { "pockets", "actions", "quantity", "confirm", "message" },
    Gen2PartyMenu = { "party", "cancel", "actions", "switch", "egg" },
    Gen2SummaryMenu = { "status", "moves", "stats", "move_detail", "egg" },
    Gen2PokedexMenu = { "list", "entry", "area", "options", "search", "unown" },
    Gen2TrainerCard = { "trainer", "johto_badges", "kanto_badges" },
    Gen2SaveMenu = { "confirm", "overwrite", "saving", "done" },
    Gen2NamingScreen = { "pokemon", "box", "name_rater", "caught" },
    Gen2CenterPcMenu = { "root", "message", "confirm" },
    Gen2PcMenu = { "root", "box_picker", "message" },
    Gen2BoxMenu = { "withdraw", "deposit", "move", "submenu", "insert" },
    Gen2ItemPcMenu = { "root", "withdraw", "deposit", "toss" },
  }

  local PALETTE = {
    { 255, 255, 255 },
    { 248, 176, 80 },
    { 56, 120, 200 },
    { 0, 0, 0 },
  }

  local definitions = {}

  local function clone(value)
    return Data.copy(value, { maxDepth=16, maxEntries=4096 })
  end

  local function add(screenId, variant, model)
    assert(type(model) == "table" and model.screenId == screenId,
      screenId .. "." .. variant .. " synthetic source model")
    assert(Data.isFunctionFree(model),
      screenId .. "." .. variant .. " source model must be function-free")
    definitions[#definitions + 1] = {
      screenId=screenId,
      variant=variant,
      model=model,
    }
  end

  local function art(species, path)
    return {
      kind="pokemon_front",
      species=species,
      path=path or ("assets/generated/battle/front/"
        .. species:lower() .. ".png"),
      sprite=path or ("assets/generated/battle/front/"
        .. species:lower() .. ".png"),
      palette=clone(PALETTE),
      paletteMode="gen2_2bpp",
      trueColor=false,
    }
  end

  local function listRow(id, label, sourceIndex, right)
    return {
      id=id, label=label, sourceIndex=sourceIndex,
      right=right, disabled=false,
    }
  end

  -- Pack ------------------------------------------------------------------

  local function packModel(mode)
    local rows = {
      listRow("item_potion", "POTION", 1, "x5"),
      listRow("item_antidote", "ANTIDOTE", 2, "x2"),
      listRow("cancel", "CANCEL", 3, "BACK"),
    }
    local potion = {
      id="POTION", name="POTION", count=5,
      description="Restores 20 HP to one POKEMON.",
    }
    local model = {
      schema="clean_ui.presenter_model.v1",
      screenId="Gen2PackMenu", family="inventory", preset="L",
      title="PACK", mode=mode, chooser=false, battleOwned=false,
      pockets={
        { id="items", label="ITEMS", sourceIndex=1, itemCount=2,
          selected=true },
        { id="balls", label="BALLS", sourceIndex=2, itemCount=3 },
        { id="key_items", label="KEY ITEMS", sourceIndex=3, itemCount=2 },
        { id="tm_hm", label="TM/HM", sourceIndex=4, itemCount=4 },
      },
      pocket={ id="items", label="ITEMS", sourceIndex=1, itemCount=2,
        selected=true },
      navigation={ selectedIndex=1, selectedId="POTION", scroll=0,
        itemCount=2, rowCount=3 },
      rows=rows, selectedItem=potion, message={},
      controls={}, actionDescriptors={},
    }
    if mode == "actions" then
      model.submenu = {
        item=clone(potion), selectedIndex=1,
        rows={
          listRow("use", "USE", 1),
          listRow("give", "GIVE", 2),
          listRow("toss", "TOSS", 3),
          listRow("cancel", "CANCEL", 4),
        },
      }
    elseif mode == "quantity" then
      model.quantity = { item=clone(potion), qty=3, max=5 }
    elseif mode == "confirm" then
      model.confirm = {
        prompt={ "Throw away 3 POTION?" }, selectedChoice=2,
        choices={
          listRow("yes", "YES", 1),
          listRow("no", "NO", 2),
        },
      }
    elseif mode == "message" then
      model.message = { "GOLD put the POTION", "in the ITEMS pocket." }
    end
    return model
  end

  for _, variant in ipairs(VARIANTS.Gen2PackMenu) do
    add("Gen2PackMenu", variant, packModel(variant))
  end

  -- Party and Summary -----------------------------------------------------

  local function pokemon(name, species, level, hp, maxHp)
    return {
      id="party.mon.1", sourceIndex=1, kind="pokemon",
      name=name, species=species, level=level, hp=hp, maxHp=maxHp,
      status="OK", isEgg=false, gender="M",
      types={ { id="WATER", label="WATER" } },
      item={ id="BERRY", name="BERRY" },
    }
  end

  local function eggPokemon()
    return {
      id="party.mon.2", sourceIndex=2, kind="egg",
      name="EGG", species="EGG", level=1, hp=1, maxHp=1,
      status="OK", isEgg=true, types={},
    }
  end

  local function partyRows(selectedIndex, switchFrom)
    return {
      {
        id="party.mon.1", sourceIndex=1, kind="pokemon",
        label="TOTODILE", level=12, hp=34, maxHp=36, status="OK",
        selected=selectedIndex == 1, switchOrigin=switchFrom == 1,
      },
      {
        id="party.mon.2", sourceIndex=2, kind="egg",
        label="EGG", level=1, hp=1, maxHp=1, status="OK",
        selected=selectedIndex == 2, switchOrigin=switchFrom == 2,
      },
      {
        id="party.back", sourceIndex=3, kind="back", label="CANCEL",
        selected=selectedIndex == 3,
      },
    }
  end

  local function partyModel(variant)
    local selectedIndex = variant == "cancel" and 3
      or variant == "egg" and 2 or 1
    local selected = selectedIndex == 1
      and pokemon("TOTODILE", "TOTODILE", 12, 34, 36)
      or selectedIndex == 2 and eggPokemon() or nil
    local model = {
      schema="clean_ui.presenter_model.v1",
      screenId="Gen2PartyMenu", family="party", preset="L",
      title="PARTY", mode=variant == "actions" and "actions"
        or variant == "switch" and "switch" or "party",
      prompt=variant == "switch" and "Move to where?" or "Choose a POKEMON.",
      navigation={ selectedIndex=selectedIndex,
        selectedId=selected and selected.id or "party.back",
        itemCount=3, scroll=0,
        switchFrom=variant == "switch" and 1 or nil },
      rows=partyRows(selectedIndex, variant == "switch" and 1 or nil),
      party={ pokemon("TOTODILE", "TOTODILE", 12, 34, 36),
        eggPokemon() },
      selection=selected and {
        kind=selected.isEgg and "egg" or "pokemon",
        sourceIndex=selectedIndex, id=selected.id, label=selected.name,
      } or {
        kind="back", sourceIndex=3, id="party.back", label="CANCEL",
        description="Return to the previous screen.",
      },
      selectedPokemon=selected,
      artwork=selected and (selected.isEgg
        and art("EGG", "assets/generated/menu/egg.png")
        or art("TOTODILE")) or nil,
      actionDescriptors={},
    }
    if variant == "actions" then
      model.submenu = {
        pokemonName="TOTODILE", sourceSlot=1, selectedIndex=1,
        items={
          { id="summary", label="SUMMARY", sourceIndex=1, kind="summary" },
          { id="switch", label="SWITCH", sourceIndex=2, kind="switch" },
          { id="item", label="ITEM", sourceIndex=3, kind="held_item" },
          { id="cancel", label="CANCEL", sourceIndex=4, kind="cancel" },
        },
      }
      model.heldItemState = {
        active=true, sourceSlot=1, action="held_item",
        held={ id="BERRY", name="BERRY" },
      }
    end
    return model
  end

  for _, variant in ipairs(VARIANTS.Gen2PartyMenu) do
    add("Gen2PartyMenu", variant, partyModel(variant))
  end

  local MOVES = {
    { id="SCRATCH", sourceIndex=1, name="SCRATCH", pp=35, maxPp=35,
      power=40, type={ id="NORMAL", label="NORMAL" },
      description={ "Scratches with sharp claws." } },
    { id="LEER", sourceIndex=2, name="LEER", pp=30, maxPp=30,
      power=0, type={ id="NORMAL", label="NORMAL" },
      description={ "Lowers the target's DEFENSE." } },
    { id="WATER_GUN", sourceIndex=3, name="WATER GUN", pp=25, maxPp=25,
      power=40, type={ id="WATER", label="WATER" },
      description={ "Squirts water to attack." } },
  }

  local function summaryModel(variant)
    if variant == "egg" then
      return {
        schema="clean_ui.presenter_model.v1",
        screenId="Gen2SummaryMenu", family="summary", preset="L",
        title="SUMMARY", mode="egg", purpose="egg",
        navigation={ partyIndex=2, partyCount=2, pageIndex=1,
          pageCount=1, moveIndex=1, moveCount=0 },
        pageTabs={}, pokemon={ name="EGG", isEgg=true },
        artwork=art("EGG", "assets/generated/menu/egg.png"),
        egg={ cycles=12, lines={ "It moves inside sometimes.",
          "It must be close to hatching." } },
        actionDescriptors={},
      }
    end

    local purpose = variant == "move_detail" and "moves" or variant
    local mode = variant == "move_detail" and "move_reorder" or "page"
    local model = {
      schema="clean_ui.presenter_model.v1",
      screenId="Gen2SummaryMenu", family="summary", preset="L",
      title="SUMMARY", mode=mode, purpose=purpose,
      sourcePage=purpose == "status" and 1 or purpose == "moves" and 2 or 3,
      pageTabs={
        { id="status", label="STATUS", sourcePage=1,
          selected=purpose == "status" },
        { id="moves", label="MOVES", sourcePage=2,
          selected=purpose == "moves" },
        { id="stats", label="STATS", sourcePage=3,
          selected=purpose == "stats" },
      },
      navigation={ partyIndex=1, partyCount=2,
        pageIndex=purpose == "status" and 1 or purpose == "moves" and 2 or 3,
        pageCount=3, moveIndex=2, moveCount=#MOVES,
        swapFrom=variant == "move_detail" and 1 or nil },
      pokemon={ species="TOTODILE", speciesName="TOTODILE",
        name="TOTODILE", dex=158, level=12, gender="M", shiny=false,
        isEgg=false },
      artwork=art("TOTODILE"),
      status={ hp=34, maxHp=36, status="OK", pokerus=false,
        types={ { id="WATER", label="WATER" } },
        experience={ experience=1728, toNext=469 } },
      heldItem={ id="BERRY", name="BERRY" },
      moves=clone(MOVES),
      stats={
        trainer={ name="GOLD", id=12345 },
        values={
          { id="attack", label="ATTACK", value=22 },
          { id="defense", label="DEFENSE", value=24 },
          { id="sp_attack", label="SPCL.ATK", value=18 },
          { id="sp_defense", label="SPCL.DEF", value=20 },
          { id="speed", label="SPEED", value=19 },
        },
      },
      actionDescriptors={},
    }
    if variant == "move_detail" then
      model.moveDetail = {
        selectedIndex=2, selectedMove=clone(MOVES[2]), swapFrom=1,
        reorderActive=true, standalone=false,
      }
    end
    return model
  end

  for _, variant in ipairs(VARIANTS.Gen2SummaryMenu) do
    add("Gen2SummaryMenu", variant, summaryModel(variant))
  end

  -- Pokedex ---------------------------------------------------------------

  local function dexArt(species)
    local value = art(species)
    return {
      species=species, sprite=value.path, palette=clone(PALETTE),
      paletteKey=species,
    }
  end

  local function pokedexModel(variant)
    local view = variant == "options" and "option" or variant
    local current = {
      id="CHIKORITA", sourceIndex=1, species="CHIKORITA",
      name="CHIKORITA", dex=152, seen=true, caught=true,
      kind="LEAF POKEMON", types={ "GRASS" }, height="2'11\"",
      weight="14.1 lb", page=1,
      pageLines={ "A sweet aroma gently wafts", "from the leaf on its head." },
      art=dexArt("CHIKORITA"),
    }
    return {
      schema="clean_ui.presenter_model.v1",
      screenId="Gen2PokedexMenu", family="pokedex", preset="L",
      title="POKEDEX", view=view, sortMode="NEW",
      navigation={ selectedIndex=1, selectedId="CHIKORITA", scroll=0,
        itemCount=3 },
      rows={
        { id="CHIKORITA", sourceIndex=1, label="CHIKORITA", dex=152,
          seen=true, caught=true },
        { id="CYNDAQUIL", sourceIndex=2, label="CYNDAQUIL", dex=155,
          seen=true, caught=false },
        { id="TOTODILE", sourceIndex=3, label="TOTODILE", dex=158,
          seen=false, caught=false },
      },
      totals={ seen=2, caught=1 }, current=current,
      entry={ page=1, selectedAction=1, newEntry=false,
        actions={
          listRow("data", "DATA", 1),
          listRow("area", "AREA", 2),
          listRow("cry", "CRY", 3),
          listRow("cancel", "CANCEL", 4),
        } },
      area={ name="CHIKORITA", region="johto", art=dexArt("CHIKORITA"),
        nests={
          { id="route_29", name="ROUTE 29" },
          { id="route_30", name="ROUTE 30" },
        } },
      options={ selectedIndex=2, rows={
        { id="new", sourceIndex=1, label="NEW POKEDEX MODE", mode="NEW",
          description="Sort by the new regional order." },
        { id="old", sourceIndex=2, label="OLD POKEDEX MODE", mode="OLD",
          description="Sort by the original order." },
        { id="a_z", sourceIndex=3, label="A TO Z MODE", mode="A-Z",
          description="Sort alphabetically." },
        { id="unown", sourceIndex=4, label="UNOWN MODE", mode="UNOWN",
          description="Review discovered Unown forms." },
      } },
      search={ selectedIndex=1, message="", resultCount=2,
        resultsActive=true, rows={
          { id="type_1", sourceIndex=1, label="TYPE 1", value="GRASS" },
          { id="type_2", sourceIndex=2, label="TYPE 2", value="ANY" },
          { id="begin", sourceIndex=3, label="BEGIN SEARCH", value="2 FOUND" },
        } },
      unown={ selectedIndex=1, selectedSlot=1, rows={
        { id="unown_a", sourceIndex=1, slot=1, label="A", word="ANGER",
          art=dexArt("UNOWN") },
        { id="unown_b", sourceIndex=2, slot=2, label="B", word="BEAR",
          art=dexArt("UNOWN") },
      } },
      controls={}, actionDescriptors={},
    }
  end

  for _, variant in ipairs(VARIANTS.Gen2PokedexMenu) do
    add("Gen2PokedexMenu", variant, pokedexModel(variant))
  end

  -- Trainer Card and Save -------------------------------------------------

  local JOHTO = { "ZEPHYR", "HIVE", "PLAIN", "FOG",
    "STORM", "MINERAL", "GLACIER", "RISING" }
  local KANTO = { "BOULDER", "CASCADE", "THUNDER", "RAINBOW",
    "SOUL", "MARSH", "VOLCANO", "EARTH" }

  local function badges(names, owned)
    local output = {}
    for index, name in ipairs(names) do
      output[index] = { id=name:lower(), label=name, owned=index <= owned }
    end
    return output
  end

  local function trainerModel(variant)
    local page = variant == "trainer" and 1
      or variant == "johto_badges" and 2 or 3
    local pages = {
      { id="trainer", sourcePage=1, label="TRAINER", kind="trainer" },
      { id="johto_badges", sourcePage=2, label="JOHTO BADGES",
        kind="badges", region="johto", badges=badges(JOHTO, 4),
        ownedCount=4 },
      { id="kanto_badges", sourcePage=3, label="KANTO BADGES",
        kind="badges", region="kanto", badges=badges(KANTO, 2),
        ownedCount=2, available=true },
    }
    return {
      schema="clean_ui.presenter_model.v1",
      screenId="Gen2TrainerCard", family="trainer", preset="L",
      title="TRAINER CARD", page=page, pageCount=3, frames=123456,
      player={ name="GOLD", id=12345, money=24500, gender="M" },
      pokedexCaught=37, playTime={ hours=28, minutes=43 },
      pages=pages, currentPage=clone(pages[page]),
      controls={}, actionDescriptors={},
    }
  end

  for _, variant in ipairs(VARIANTS.Gen2TrainerCard) do
    add("Gen2TrainerCard", variant, trainerModel(variant))
  end

  local function saveModel(phase)
    local interactive = phase == "confirm" or phase == "overwrite"
    local prompts = {
      confirm="Would you like to save the game?",
      overwrite="There is already a save file. Overwrite it?",
      saving="SAVING... DON'T TURN OFF THE POWER.",
      done="GOLD saved the game.",
    }
    return {
      schema="clean_ui.presenter_model.v1",
      screenId="Gen2SaveMenu", family="core", preset="M",
      title="SAVE", phase=phase, existed=phase ~= "confirm",
      selectedChoice=phase == "overwrite" and 2 or 1,
      choices=interactive and {
        listRow("yes", "YES", 1), listRow("no", "NO", 2),
      } or {},
      timer=phase == "saving" and 18 or 0,
      savedPresent=phase == "done", saved=phase == "done",
      summary={ name="GOLD", badges=4, caught=37, hours=28, minutes=43,
        map="GOLDENROD CITY" },
      prompt=prompts[phase], actionDescriptors={},
    }
  end

  for _, variant in ipairs(VARIANTS.Gen2SaveMenu) do
    add("Gen2SaveMenu", variant, saveModel(variant))
  end

  -- Naming ----------------------------------------------------------------

  local NAME_ROWS = {
    { "A", "B", "C", "D", "E", "F", "G", "H", "I" },
    { "J", "K", "L", "M", "N", "O", "P", "Q", "R" },
    { "S", "T", "U", "V", "W", "X", "Y", "Z", " " },
    { "-", "?", "!", "/", ".", ",", " ", " ", " " },
  }

  local function namingModel(variant)
    local isBox = variant == "box"
    local names = {
      pokemon="TOTODILE", box="", name_rater="TOTODILE", caught="HOOTHOOT",
    }
    local prompts = {
      pokemon="POKEMON'S NICKNAME?", box="BOX NAME?",
      name_rater="GIVE IT A BETTER NAME?", caught="NICKNAME THE CAUGHT POKEMON?",
    }
    return {
      schema="clean_ui.presenter_model.v1",
      screenId="Gen2NamingScreen", family="naming", preset="XL",
      context=isBox and "box" or "nickname", isBox=isBox,
      prompt=prompts[variant], monName=names[variant],
      entry={ text=variant == "name_rater" and "TOTO" or "",
        maxLength=isBox and 8 or 10,
        sourceLength=variant == "name_rater" and 4 or 0,
        tile={ x=5, y=isBox and 4 or 6 } },
      case="upper",
      keyboard={ topTile=isBox and 8 or 10, columns=9,
        letterRows=#NAME_ROWS, rows=clone(NAME_ROWS),
        bottom={
          { id="case", label="lower", colStart=0, colEnd=2 },
          { id="delete", label="DEL", colStart=3, colEnd=5 },
          { id="end", label="END", colStart=6, colEnd=8 },
        },
        stockLayouts={ upper=clone(NAME_ROWS), lower=clone(NAME_ROWS) } },
      cursor={ col=0, row=0, bottomRow=false, targetIndex=1 },
      sprite=isBox and { callerProvided=false, nativeImageAvailable=false }
        or { path=variant == "caught"
          and "assets/generated/battle/front/hoothoot.png"
          or "assets/generated/battle/front/totodile.png",
          palette=clone(PALETTE), callerProvided=true,
          nativeImageAvailable=true },
      kindMetadata={ source=variant }, actionDescriptors={},
    }
  end

  for _, variant in ipairs(VARIANTS.Gen2NamingScreen) do
    add("Gen2NamingScreen", variant, namingModel(variant))
  end

  -- PC and storage --------------------------------------------------------

  local function storageEntries()
    return {
      listRow("bill_pc", "BILL'S PC", 1),
      listRow("player_pc", "GOLD'S PC", 2),
      listRow("prof_oak_pc", "PROF.OAK'S PC", 3),
      listRow("turn_off", "TURN OFF", 4),
    }
  end

  local function centerPcModel(mode)
    return {
      schema="clean_ui.presenter_model.v1",
      screenId="Gen2CenterPcMenu", family="storage", preset="M",
      mode=mode, playerName="GOLD",
      navigation={ selectedIndex=1, itemCount=4 },
      entries=storageEntries(),
      message=mode == "message" and {
        page=1, pageCount=1, lines={ "The PC was turned on." },
      } or nil,
      confirm=mode == "confirm" and {
        prompt={ "Change BOX now?" }, selectedChoice=1,
        choices={ listRow("yes", "YES", 1), listRow("no", "NO", 2) },
      } or nil,
      closed=false, actionDescriptors={},
    }
  end

  for _, variant in ipairs(VARIANTS.Gen2CenterPcMenu) do
    add("Gen2CenterPcMenu", variant, centerPcModel(variant))
  end

  local function pcModel(mode)
    local boxes = {}
    for index = 1, 8 do
      boxes[index] = listRow("box_" .. index, "BOX " .. index, index,
        index == 1 and "12/20" or "0/20")
    end
    return {
      schema="clean_ui.presenter_model.v1",
      screenId="Gen2PcMenu", family="storage", preset="M",
      mode=mode, house=false, changedDecorations=false,
      navigation={ selectedIndex=mode == "box_picker" and 2 or 1,
        itemCount=mode == "box_picker" and #boxes or 4 },
      entries={
        listRow("withdraw", "WITHDRAW POKEMON", 1),
        listRow("deposit", "DEPOSIT POKEMON", 2),
        listRow("move", "MOVE POKEMON W/O MAIL", 3),
        listRow("see_ya", "SEE YA!", 4),
      },
      picker={ selectedIndex=2, currentBox=1, boxes=boxes },
      message=mode == "message" and {
        page=1, pageCount=1, lines={ "BOX 1 was selected." }, closes=false,
      } or nil,
      actionDescriptors={},
    }
  end

  for _, variant in ipairs(VARIANTS.Gen2PcMenu) do
    add("Gen2PcMenu", variant, pcModel(variant))
  end

  local function storedMon(name, species, level)
    return {
      species=species, name=species, nickname=name, displayName=name,
      level=level, hp=31, maxHp=35, status="", gender="F",
      heldItem="BERRY", isEgg=false, shiny=false, moveCount=3,
      spritePath="assets/generated/battle/front/" .. species:lower() .. ".png",
    }
  end

  local function boxRows()
    return {
      { id="mon_1", sourceIndex=1, label="MAREEP", right="Lv 14",
        mon=storedMon("MAREEP", "MAREEP", 14) },
      { id="mon_2", sourceIndex=2, label="WOOPER", right="Lv 10",
        mon=storedMon("WOOPER", "WOOPER", 10) },
      listRow("cancel", "CANCEL", 3, "BACK"),
    }
  end

  local function boxModel(variant)
    local mode = variant == "deposit" and "deposit"
      or (variant == "move" or variant == "insert") and "move"
      or "withdraw"
    local view = variant == "submenu" and "submenu"
      or variant == "insert" and "insert" or "browse"
    local rows = boxRows()
    if view == "insert" then
      for index, row in ipairs(rows) do
        row.insert = true
        row.right = index == 2 and "INSERT" or ""
      end
    end
    return {
      schema="clean_ui.presenter_model.v1",
      screenId="Gen2BoxMenu", family="storage", preset="XL",
      mode=mode, view=view, underlyingPhase=view,
      title=mode == "deposit" and "PARTY" or "BOX 1",
      prompt=view == "submenu" and "What's up?"
        or view == "insert" and "Move to where?" or "Choose a POKEMON.",
      navigation={ selectedIndex=view == "insert" and 2 or 1,
        scroll=0, itemCount=#rows, visibleRows=5 },
      rows=rows, selectedMon=storedMon("MAREEP", "MAREEP", 14),
      destination={ boxIndex=mode == "deposit" and 0 or 1,
        name=mode == "deposit" and "PARTY" or "BOX 1",
        count=2, capacity=mode == "deposit" and 6 or 20,
        isParty=mode == "deposit" },
      submenu=view == "submenu" and {
        selectedIndex=1,
        rows={
          listRow("move", "MOVE", 1),
          listRow("stats", "STATS", 2),
          listRow("release", "RELEASE", 3),
          listRow("cancel", "CANCEL", 4),
        },
      } or nil,
      insert=view == "insert" and {
        source={ boxIndex=1, slot=1 },
        backup={ boxIndex=1, index=1, scroll=0 }, positionCount=3,
      } or nil,
      actionDescriptors={},
    }
  end

  for _, variant in ipairs(VARIANTS.Gen2BoxMenu) do
    add("Gen2BoxMenu", variant, boxModel(variant))
  end

  local function itemRows()
    return {
      listRow("POTION", "POTION", 1, "x5"),
      listRow("ANTIDOTE", "ANTIDOTE", 2, "x2"),
      listRow("cancel", "CANCEL", 3, "BACK"),
    }
  end

  local function itemPcModel(variant)
    local phase = variant == "root" and "menu" or variant
    local rows = itemRows()
    return {
      schema="clean_ui.presenter_model.v1",
      screenId="Gen2ItemPcMenu", family="storage", preset="L",
      phase=phase, view=phase, house=false, changedDecorations=false,
      playerName="GOLD", navigation={ selectedIndex=1, scroll=0 },
      entries={
        listRow("withdraw", "WITHDRAW ITEM", 1),
        listRow("deposit", "DEPOSIT ITEM", 2),
        listRow("toss", "TOSS ITEM", 3),
        listRow("log_off", "LOG OFF", 4),
      },
      rows=rows,
      description={ "Restores 20 HP to one POKEMON." },
      deposit=phase == "deposit" and {
        packPresent=true, rows=clone(rows),
        pocket={ id="items", label="ITEMS", selectedIndex=1 },
      } or nil,
      actionDescriptors={},
    }
  end

  for _, variant in ipairs(VARIANTS.Gen2ItemPcMenu) do
    add("Gen2ItemPcMenu", variant, itemPcModel(variant))
  end

  function Models.galleryFixtures()
    local output = {}
    for index, fixture in ipairs(definitions) do
      output[index] = {
        screenId=fixture.screenId,
        variant=fixture.variant,
        model=clone(fixture.model),
      }
      assert(Data.isFunctionFree(output[index]),
        fixture.screenId .. "." .. fixture.variant
          .. " Gallery fixture must be function-free")
    end
    return output
  end

  function Models.ids()
    return clone(ORDER)
  end

  function Models.variantsFor(screenId)
    return clone(VARIANTS[screenId] or {})
  end

  function Models.count()
    return #definitions
  end

  return Models
end
