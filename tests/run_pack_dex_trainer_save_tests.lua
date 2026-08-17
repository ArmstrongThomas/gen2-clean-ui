local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"),
  "GEN2_CLEAN_UI_ROOT is required"):gsub("\\", "/")
local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)

local Data = ctx.load("adapters.data")
local Pack = ctx.load("adapters.pack")
local PackPresenter = ctx.load("presenters.pack")
local Pokedex = ctx.load("adapters.pokedex")
local PokedexPresenter = ctx.load("presenters.pokedex")
local TrainerCard = ctx.load("adapters.trainer_card")
local TrainerPresenter = ctx.load("presenters.trainer_card")
local SaveMenu = ctx.load("adapters.save_menu")
local SavePresenter = ctx.load("presenters.save_menu")

local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, ("check %d failed: %s"):format(checks, message))
end

local function descriptor(model, id)
  for _, item in ipairs(model.actionDescriptors or {}) do
    if item.id == id then return item end
  end
end

local callbackCalls = 0
local function forbiddenCallback()
  callbackCalls = callbackCalls + 1
  error("source callback ran during extraction")
end

-- PACK: current pocket/list data and every nested overlay remain source-owned.
local packItems = {
  POTION = { name = "POTION", pocket = "ITEM", description = "Restores HP." },
  POKE_BALL = { name = "POKE BALL", pocket = "BALL" },
  BICYCLE = { name = "BICYCLE", pocket = "KEY_ITEM" },
  TM01 = { name = "TM01", pocket = "TM_HM", teaches = "DYNAMICPUNCH" },
}
local packRows = {
  { id = "POTION", count = 4, name = "POTION", showCount = true },
  { id = "TM01", count = 1, name = "TM01", teaches = "DYNAMICPUNCH",
    tmNumber = 1, showCount = false },
}
local packState = {
  screenId = "Gen2PackMenu",
  save = { player = { name = "GOLD" }, inventory = {
    POTION = 4, POKE_BALL = 10, BICYCLE = 1, TM01 = 1,
  } },
  items = packItems,
  game = { data = { moves = {
    DYNAMICPUNCH = { name = "DYNAMICPUNCH", description = "Powerful punch." },
  } } },
  give = false, battle = false, pocketIndex = 1,
  index = 2, scroll = 1, rows = packRows,
  onChoose = forbiddenCallback, onClose = forbiddenCallback,
  description = forbiddenCallback,
}
local packBundle = assert(Pack.extract(packState))
check(callbackCalls == 0, "Pack extraction invokes no source callback or method")
check(Data.isFunctionFree(packBundle.model), "Pack source model is function-free")
check(packBundle.model.preset == "L" and packBundle.model.mode == "pockets",
  "Pack uses stable L pocket model")
check(packBundle.model.navigation.selectedIndex == 2
  and packBundle.model.navigation.scroll == 1,
  "Pack preserves exact item selection and scroll")
check(packBundle.model.rows[3].id == "cancel"
  and packBundle.model.rows[3].sourceIndex == 3,
  "Pack materializes native CANCEL at its exact source index")
check(packBundle.model.pockets[1].itemCount == 1
  and packBundle.model.pockets[4].itemCount == 1,
  "Pack snapshots all four pocket counts")
check(packBundle.model.selectedItem.description == "Powerful punch.",
  "TM selection uses the taught move description")
check(descriptor(packBundle.model, "item.2.choose").dispatch == "source_input",
  "Pack activation remains owned by screen.update")
local packPresentation = assert(PackPresenter.convert(packBundle.model))
check(packPresentation.schema == "clean_ui.v3.presentation.v1"
  and packPresentation.apiVersion == 3,
  "Pack presenter emits the canonical V3 model")
check(packPresentation.kind == "menu" and packPresentation.preset == "L"
  and packPresentation.selected == 2 and packPresentation.scroll == 1,
  "Pack presenter preserves stable envelope and navigation")
check(packPresentation.sourcePocket == "ITEM"
  and packPresentation.details[1].value == "TM01",
  "Pack presenter exposes selected item details")
check(Data.isFunctionFree(packPresentation),
  "Pack presentation model is function-free")

packState.submenu = {
  row = packRows[1], rows = { "use", "give", "toss", "quit" }, index = 3,
}
local packActions = assert(Pack.extract(packState))
check(packActions.model.mode == "actions"
  and packActions.model.submenu.selectedIndex == 3,
  "Pack action submenu preserves exact selection")
check(PackPresenter.convert(packActions.model).modal.options[3].label == "TOSS",
  "Pack action submenu becomes a stable modal")
packState.submenu = nil
packState.message = { "Throw away how", "many?" }
packState.qtyState = { row = packRows[1], qty = 4, max = 12 }
local packQuantity = assert(Pack.extract(packState))
check(packQuantity.model.mode == "quantity"
  and packQuantity.model.quantity.qty == 4
  and packQuantity.model.quantity.max == 12,
  "Pack quantity selector preserves current and maximum quantity")
check(PackPresenter.convert(packQuantity.model).modal.options[1].label == "x4 / 12",
  "Pack quantity presenter exposes the exact count")
packState.qtyState, packState.message = nil, nil
packState.confirm = {
  prompt = { "Throw away 4", "POTION(S)?" }, choice = 2,
  onYes = forbiddenCallback, onNo = forbiddenCallback,
}
local packConfirm = assert(Pack.extract(packState))
check(callbackCalls == 0 and packConfirm.model.mode == "confirm",
  "Pack confirmation extraction does not execute confirmation callbacks")
check(packConfirm.model.confirm.selectedChoice == 2
  and PackPresenter.convert(packConfirm.model).modal.selected == 2,
  "Pack confirmation preserves the native YES/NO selection")
packState.confirm = nil
packState.message = { "{PLAYER} used the", "POTION." }
local packMessage = assert(Pack.extract(packState))
check(packMessage.model.mode == "message"
  and packMessage.model.message[1] == "GOLD used the",
  "Pack message snapshots source text with player substitution")
packRows[2].name = "MUTATED"
check(packBundle.model.rows[2].label == "TM01",
  "Pack model is detached from source rows")

-- POKEDEX: all six source views share one detached, full-color data snapshot.
local dexSave = {
  player = { name = "GOLD" },
  position = { map = "NEW_BARK_TOWN" },
  pokedex = { seen = { CHIKORITA=true, CYNDAQUIL=true },
    caught = { CHIKORITA=true } },
  engineFlags = { [12] = true },
  unownDex = { 1, 24 },
  roamers = { { species = "CYNDAQUIL", map = "ROUTE_30" } },
}
local dexData = {
  gen2Maps = {
    NEW_BARK_TOWN = { landmark = 1 },
    ROUTE_29 = { landmark = 2 },
    ROUTE_30 = { landmark = 3 },
  },
  gen2Encounters = {
    grass = { ROUTE_29 = { slots = {
      morning = { { species = "CHIKORITA" } },
      day = { { species = "PIDGEY" } },
    } } },
    water = {},
  },
  gen2Landmarks = {
    order = { [2]="NEW_BARK_TOWN", [3]="ROUTE_29", [4]="ROUTE_30" },
    landmarks = {
      NEW_BARK_TOWN = { index=1, name="NEW BARK TOWN", x=12, y=20 },
      ROUTE_29 = { index=2, name="ROUTE 29", x=20, y=20 },
      ROUTE_30 = { index=3, name="ROUTE 30", x=28, y=20 },
    },
  },
}
local dexRows = {
  { species="CHIKORITA", dex=152, seen=true, caught=true },
  { species="CYNDAQUIL", dex=155, seen=true, caught=false },
  { species="TOTODILE", dex=158, seen=false, caught=false },
}
local dexState = {
  screenId = "Gen2PokedexMenu",
  save = dexSave,
  data = dexData,
  game = { save=dexSave, data=dexData },
  dex = { entries = {
    CHIKORITA = { dex=152, kind="LEAF", height=9, weight=64,
      text="A sweet aroma", text2="Its leaf senses warmth." },
    CYNDAQUIL = { dex=155, kind="FIRE MOUSE", height=5, weight=79,
      text="It is timid.", text2="Flames protect it." },
    TOTODILE = { dex=158, kind="BIG JAW", height=6, weight=95,
      text="Its jaws are strong.", text2="It is playful." },
  } },
  pokemon = {
    CHIKORITA = { name="CHIKORITA", types={"GRASS"},
      evolutions = { { method="LEVEL", into="BAYLEEF", level=16 } },
      levelMoves = { { level=1, move="TACKLE" },
        { level=6, move="RAZOR_LEAF" } },
      tmhm = { "TM01" },
      spriteFront="pokemon/chikorita/front.png" },
    CYNDAQUIL = { name="CYNDAQUIL", types={"FIRE"},
      spriteFront="pokemon/cyndaquil/front.png" },
    TOTODILE = { name="TOTODILE", types={"WATER", "WATER"},
      spriteFront="pokemon/totodile/front.png" },
  },
  moves = {
    TACKLE = { name="TACKLE", type="NORMAL", power=35, accuracy=95,
      description="A physical attack." },
    RAZOR_LEAF = { name="RAZOR LEAF", type="GRASS", power=55, accuracy=95,
      description="Sharp leaves strike." },
    TM01 = { name="DYNAMICPUNCH", type="FIGHTING", power=100, accuracy=50,
      description="A powerful punch." },
  },
  palettes = { pokemon = {
    CHIKORITA = { normal={ {120,210,100}, {40,120,55} } },
    CYNDAQUIL = { normal={ {240,165,80}, {145,55,35} } },
    TOTODILE = { normal={ {95,185,225}, {35,85,155} } },
  } },
  rows = dexRows, modeIndex = 1, index = 1, scroll = 0,
  view = "list", page = 1, entryAction = 2,
  optionIndex = 4, searchIndex = 2, unownIndex = 1,
  searchType = { 12, 0 },
  onClose = forbiddenCallback, playCry = forbiddenCallback,
  printEntry = forbiddenCallback, beginSearch = forbiddenCallback,
}
local dexList = assert(Pokedex.extract(dexState))
check(callbackCalls == 0, "Pokedex extraction invokes no source behavior")
check(Data.isFunctionFree(dexList.model), "Pokedex source model is function-free")
check(dexList.model.navigation.selectedIndex == 1
  and dexList.model.navigation.scroll == 0,
  "Pokedex preserves exact list selection and scroll")
check(dexList.model.rows[1].art.sprite == "pokemon/chikorita/front.png"
  and dexList.model.rows[1].art.paletteKey == "CHIKORITA",
  "Pokedex carries full-color sprite and palette identity")
check(dexList.model.rows[3].disabled and dexList.model.totals.seen == 2
  and dexList.model.totals.caught == 1,
  "Pokedex snapshots seen/caught visibility and totals")
check(dexList.model.current.reference.evolutions[1].into == "BAYLEEF"
  and dexList.model.current.reference.evolutions[1].requirement == "LEVEL 16"
  and true,
  "Pokedex snapshots evolution targets and readable requirements")
check(dexList.model.current.reference.levelMoves[2].name == "RAZOR LEAF"
  and dexList.model.current.reference.levelMoves[2].power == 55,
  "Pokedex resolves level-up move metadata from game data")
check(dexList.model.current.reference.tmhm[1].move == "TM01"
  and dexList.model.current.reference.tmhm[1].type == "FIGHTING",
  "Pokedex snapshots TM/HM compatibility and move metadata")
local dexListView = assert(PokedexPresenter.convert(dexList.model))
check(dexListView.schema == "clean_ui.v3.presentation.v1"
  and dexListView.apiVersion == 3,
  "Pokedex presenter emits the canonical V3 model")
check(dexListView.kind == "menu" and dexListView.preset == "L"
  and dexListView.selected == 1,
  "Pokedex list uses stable L presentation")
check(dexListView.details.sprite.path == "pokemon/chikorita/front.png"
  and dexListView.details.sprite.palette[2][1] == 120,
  "Pokedex presentation carries its full-color sprite descriptor")
check(dexListView.details.title == "CHIKORITA"
  and dexListView.details.fields[1].label == "NUMBER"
  and dexListView.details.fields[1].value == "No.152"
  and dexListView.details.fields[2].value == "OWNED"
  and dexListView.details.typeBadges[1] == "GRASS"
  and dexListView.rows[1].label == "No.152 CHIKORITA"
  and dexListView.rows[1].right == "OWNED",
  "Pokedex list uses a Gen1 Modern-inspired number/status preview rail")
check(dexListView.description:find("SEEN 2", 1, true)
  and dexListView.description:find("OWNED 1", 1, true),
  "Pokedex footer keeps totals and clean navigation hints")
local duplicateTypeState = Data.copy(dexState)
duplicateTypeState.index = 3
local duplicateType = assert(Pokedex.extract(duplicateTypeState))
check(#duplicateType.model.current.types == 1
  and duplicateType.model.current.types[1] == "WATER",
  "Pokedex removes duplicate single-type data from the snapshot")

dexState.view, dexState.page, dexState.entryAction = "entry", 2, 3
local dexEntry = assert(Pokedex.extract(dexState))
check(dexEntry.model.current.page == 2
  and dexEntry.model.current.pageLines[1] == "Its leaf senses warmth.",
  "Pokedex entry snapshots the exact source page")
check(dexEntry.model.entry.selectedAction == 3
  and dexEntry.model.entry.actions[3].id == "cry",
  "Pokedex entry preserves the native action cursor")
local dexEntryView = assert(PokedexPresenter.convert(dexEntry.model))
check(dexEntryView.sourceView == "entry" and dexEntryView.kind == "document"
  and dexEntryView.selected == 3
  and dexEntryView.art.paletteKey == "CHIKORITA"
  and dexEntryView.details.title == "CHIKORITA"
  and dexEntryView.title == "CHIKORITA  /  INFO 2"
  and dexEntryView.details.typeBadges[1] == "GRASS"
  and dexEntryView.details.fields[1].value == "No.152",
  "Pokedex entry presenter retains action, preview, and color-art data")
check(dexEntryView.document.regions[1].components[1].type == "tabs"
  and dexEntryView.document.regions[1].components[1].values[1] == "INFO"
  and dexEntryView.document.regions[1].components[1].values[4] == "MOVES/TM"
  and dexEntryView.document.regions[1].components[1].values[5] == "CRY"
  and dexEntryView.document.regions[1].components[1].values[6] == "PRNT"
  and dexEntryView.document.regions[1].components[1].active == 5
  and dexEntryView.document.regions[4].components[2].lines[1]
    == "Its leaf senses warmth.",
  "Pokedex INFO uses the shared document page contract")

dexState.view, dexState.areaRegion = "area", "johto"
local dexArea = assert(Pokedex.extract(dexState))
check(#dexArea.model.area.nests == 1
  and dexArea.model.area.nests[1].name == "ROUTE 29",
  "Pokedex AREA computes read-only native grass nests")
check(dexArea.model.area.region == "johto"
  and PokedexPresenter.convert(dexArea.model).sourceView == "area"
  and PokedexPresenter.convert(dexArea.model).mapView == true
  and PokedexPresenter.convert(dexArea.model).map.rows[1].name == "ROUTE 29",
  "Pokedex AREA preserves region and produces a map-backed view")

dexState.view, dexState.areaRegion = "option", nil
local dexOptions = assert(Pokedex.extract(dexState))
check(#dexOptions.model.options.rows == 4
  and dexOptions.model.options.selectedIndex == 4,
  "Pokedex options includes unlocked Unown mode and exact selection")
check(PokedexPresenter.convert(dexOptions.model).selected == 4,
  "Pokedex options presenter preserves selection")

dexState.view = "search"
dexState.searchMessage = "No Pokemon found!"
dexState.searchResults = {}
local dexSearch = assert(Pokedex.extract(dexState))
check(dexSearch.model.search.rows[1].value == "GRASS"
  and dexSearch.model.search.selectedIndex == 2,
  "Pokedex search snapshots type wheels and cursor")
check(PokedexPresenter.convert(dexSearch.model).description == "No Pokemon found!",
  "Pokedex search presenter surfaces native result message")

dexState.view = "unown"
local dexUnown = assert(Pokedex.extract(dexState))
check(#dexUnown.model.unown.rows == 2
  and dexUnown.model.unown.rows[2].label == "X"
  and dexUnown.model.unown.rows[2].word == "XXXXX",
  "Pokedex Unown mode preserves caught order, form, and word")
local dexUnownView = assert(PokedexPresenter.convert(dexUnown.model))
check(dexUnownView.selected == 2
  and dexUnownView.details.fields[1].value == "X",
  "Pokedex Unown presenter maps zero-based source slot correctly")
check(callbackCalls == 0, "All Pokedex modes remain callback-free")
dexRows[1].species = "MUTATED"
check(dexList.model.rows[1].species == "CHIKORITA",
  "Pokedex model is detached from source rows")

-- TRAINER CARD: source page is stable and Johto/Kanto data remain distinct.
local trainerState = {
  screenId = "Gen2TrainerCard",
  save = {
    player = {
      name="GOLD", id=123, money=4567, gender="boy",
      badges={ ZEPHYR=true, HIVE=true },
      kantoBadges={ BOULDER=true, CASCADE=true, THUNDER=false },
    },
    pokedex={ caught={ CHIKORITA=true, CYNDAQUIL=true } },
    playTime={ hours=27, minutes=5 },
  },
  page=1, frames=96, onClose=forbiddenCallback,
}
local trainer = assert(TrainerCard.extract(trainerState))
check(callbackCalls == 0 and Data.isFunctionFree(trainer.model),
  "Trainer Card extraction is callback-free and function-free")
check(trainer.model.pageCount == 3 and trainer.model.currentPage.id == "trainer",
  "Trainer Card detects all three native pages")
check(trainer.model.pokedexCaught == 2
  and trainer.model.playTime.hours == 27,
  "Trainer Card snapshots trainer summary")
local trainerView = assert(TrainerPresenter.convert(trainer.model))
check(trainerView.schema == "clean_ui.v3.presentation.v1"
  and trainerView.apiVersion == 3,
  "Trainer Card presenter emits the canonical V3 model")
check(trainerView.preset == "L" and trainerView.sourcePage == 1
  and trainerView.rows[2].right == "00123",
  "Trainer page uses stable L layout and padded source ID")
trainerState.page = 2
local johto = assert(TrainerCard.extract(trainerState))
check(johto.model.currentPage.ownedCount == 2
  and TrainerPresenter.convert(johto.model).rows[1].right == "EARNED",
  "Trainer Johto page snapshots badges")
trainerState.page = 3
local kanto = assert(TrainerCard.extract(trainerState))
check(kanto.model.currentPage.region == "kanto"
  and kanto.model.currentPage.ownedCount == 2
  and kanto.model.currentPage.badges[1].name == "BOULDER",
  "Trainer Kanto page uses Kanto badge data rather than Johto aliases")
check(TrainerPresenter.convert(kanto.model).sourcePageId == "kanto_badges",
  "Trainer Kanto presenter keeps exact source page identity")

-- SAVE: every phase is a snapshot; writer/onDone are never touched.
local saveState = {
  screenId = "Gen2SaveMenu",
  save = {
    player={ name="GOLD", badges={ ZEPHYR=true, HIVE=true } },
    pokedex={ caught={ CHIKORITA=true } },
    playTime={ hours=9, minutes=7 },
    position={ map="VIOLET_CITY" },
  },
  existed=true, phase="confirm", choice=2, timer=0,
  writer=forbiddenCallback, onDone=forbiddenCallback,
}
local saveConfirm = assert(SaveMenu.extract(saveState))
check(callbackCalls == 0 and Data.isFunctionFree(saveConfirm.model),
  "Save extraction never writes, finishes, or calls source callbacks")
check(saveConfirm.model.selectedChoice == 2
  and #saveConfirm.model.choices == 2,
  "Save confirm preserves native YES/NO selection")
check(saveConfirm.model.summary.badges == 2
  and saveConfirm.model.summary.map == "VIOLET_CITY",
  "Save snapshots continue-card data")
local saveConfirmView = assert(SavePresenter.convert(saveConfirm.model))
check(saveConfirmView.schema == "clean_ui.v3.presentation.v1"
  and saveConfirmView.apiVersion == 3,
  "Save presenter emits the canonical V3 model")
check(saveConfirmView.preset == "M" and saveConfirmView.selected == 2
  and saveConfirmView.sourcePhase == "confirm",
  "Save confirm uses stable M presentation")

saveState.phase, saveState.choice = "overwrite", 1
local overwrite = assert(SaveMenu.extract(saveState))
check(overwrite.model.prompt[2] == "Overwrite it?"
  and SavePresenter.convert(overwrite.model).selected == 1,
  "Save overwrite phase has its own prompt and selection")
saveState.phase, saveState.timer = "saving", 11
local saving = assert(SaveMenu.extract(saveState))
local savingView = assert(SavePresenter.convert(saving.model))
check(#saving.model.choices == 0 and savingView.timer == 11
  and savingView.sourcePhase == "saving",
  "Save timed saving phase has no interactive rows")
saveState.phase, saveState.timer, saveState.saved = "done", 17, true
local done = assert(SaveMenu.extract(saveState))
local doneView = assert(SavePresenter.convert(done.model))
check(done.model.prompt[1] == "GOLD saved" and doneView.saved == true
  and #doneView.rows == 0,
  "Save done phase snapshots successful completion without invoking onDone")
check(callbackCalls == 0, "No adapter invoked any hostile source callback")

-- Each focused presenter is ready for explicit production registration.
local registeredModels, registeredPresenters = {}, {}
local fakeProvider = {
  registerModelAdapter = function(_, id, adapter)
    registeredModels[id] = adapter
    return true
  end,
  registerPresenter = function(_, id, presenter)
    registeredPresenters[id] = presenter
    return true
  end,
}
for _, presenter in ipairs({
  PackPresenter, PokedexPresenter, TrainerPresenter, SavePresenter,
}) do
  check(presenter.register(fakeProvider) == true,
    "focused presenter registers its adapter and presenter")
end
for _, id in ipairs({
  "Gen2PackMenu", "Gen2PokedexMenu", "Gen2TrainerCard", "Gen2SaveMenu",
}) do
  check(type(registeredModels[id]) == "table"
    and type(registeredPresenters[id]) == "table",
    id .. " production registration is complete")
end

check(Pack.extract(nil) == nil and Pokedex.extract(nil) == nil
  and TrainerCard.extract(nil) == nil and SaveMenu.extract(nil) == nil,
  "focused adapters reject invalid root state")
check(PokedexPresenter.convert({ screenId="Gen2PokedexMenu", view="future" })
  == nil, "unknown Pokedex views fail open")
check(SavePresenter.convert({ screenId="Gen2SaveMenu", phase="future" }) == nil,
  "unknown Save phases fail open")

print(("Gen2 Pack/Dex/Trainer/Save tests: %d checks passed"):format(checks))
