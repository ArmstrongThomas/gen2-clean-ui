local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"), "GEN2_CLEAN_UI_ROOT is required")
root = root:gsub("\\", "/")

local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)
local Data = ctx.load("adapters.data")
local MainMenu = ctx.load("adapters.main_menu")
local StartMenu = ctx.load("adapters.start_menu")
local OptionsMenu = ctx.load("adapters.options_menu")
local FoundationModels = ctx.load("presenters.foundation_models")
local FoundationPresenters = ctx.load("presenters.foundation_presenters")
local Catalog = ctx.load("contracts.catalog")
local Shared = ctx.load("contracts.shared")
local Provider = ctx.load("provider.init")
local SourceInput = ctx.load("provider.source_input")
local Gallery = ctx.load("gallery.catalog")

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

local hostile = { label = "SAFE", nested = { value = 7 },
  callback = function() error("must not copy") end }
hostile.self = hostile
local safeCopy = Data.copy(hostile)
check(Data.isFunctionFree(safeCopy), "bounded data copy is function-free")
check(safeCopy.label == "SAFE" and safeCopy.nested.value == 7,
  "bounded data copy preserves safe values")
check(safeCopy.callback == nil and safeCopy.self == nil,
  "bounded data copy omits functions and cycles")
hostile.nested.value = 99
check(safeCopy.nested.value == 7, "bounded data copy is detached")

-- Main Menu: exact phase/list state, detached save data, and deferred actions.
local mainCalls = 0
local mainChoose = function() mainCalls = mainCalls + 1 end
local mainContinue = function() mainCalls = mainCalls + 1 end
local mainItems = {
  { label = "CONTINUE", value = "continue" },
  { label = "NEW GAME", value = "new", ignored = function() end },
  { value = "option" },
}
local mainState = {
  screenId = "Gen2MainMenu", hasSave = true, phase = "confirm",
  confirmDelay = 7,
  save = {
    player = { name = "GOLD", badges = { a = true, b = false, c = true } },
    pokedex = { caught = { [1] = true, [2] = false, [3] = true } },
    playTime = { hours = 44, minutes = 5 },
    position = { map = "CHERRYGROVE CITY" },
    ignored = function() mainCalls = mainCalls + 1 end,
  },
  clock = { hour = 14, minute = 8, weekday = 4 },
  list = { items = mainItems, index = 2, scroll = 1,
    onChoose = mainChoose },
  onContinue = mainContinue,
}
local mainBundle = assert(MainMenu.extract(mainState))
local mainModel = mainBundle.model
check(mainCalls == 0, "Main extraction invokes no source callback")
check(Data.isFunctionFree(mainModel), "Main model is function-free and acyclic")
check(mainModel.phase.present and mainModel.phase.value == "confirm",
  "Main exact phase")
check(mainModel.navigation.selectedIndex == 2
  and mainModel.navigation.scroll == 1, "Main exact selection and scroll")
check(mainModel.navigation.selectedId == "new", "Main selected id")
check(mainModel.items[3].label == "option", "Main defensive label fallback")
check(mainModel.saveSummary.badges == 2 and mainModel.saveSummary.caught == 2,
  "Main save summary derives bounded counts")
check(mainModel.clock.timeLabel == "2:08 PM"
  and mainModel.clock.dayLabel == "WEDNESDAY", "Main pinned clock model")
check(mainModel.confirm.delayFrames == 7 and not mainModel.confirm.ready,
  "Main confirm delay preserved")
check(mainBundle.actions.entries["choose.2"].callback == mainChoose,
  "Main source list callback is mapped")
check(mainBundle.actions.entries["choose.2"].receiver == nil
  and mainBundle.actions.entries["choose.2"].argumentCount == 2,
  "Main list callback preserves plain-call convention and nil-safe arity")
check(mainBundle.actions.entries["choose.2"].arguments[1] == "new",
  "Main source value is mapped without invocation")
check(mainBundle.actions.entries["confirm.continue"].callback == mainContinue,
  "Main continue callback is mapped")
check(descriptor(mainModel, "confirm.continue").enabled == false,
  "Main delayed confirm action is described as disabled")
mainItems[2].label = "MUTATED"
mainState.save.player.name = "CHANGED"
check(mainModel.items[2].label == "NEW GAME"
  and mainModel.saveSummary.name == "GOLD", "Main model is detached")

-- Start Menu: source nil phase is represented exactly and descriptions copy.
local startCalls = 0
local startChoose = function() startCalls = startCalls + 1 end
local startCancel = function() startCalls = startCalls + 1 end
local injectedSelect = function() startCalls = startCalls + 1 end
local startItems = {
  { label = "<PO><KE>GEAR", value = "pokegear",
    desc = { "Trainer's", "key device" } },
  { label = "OPTION", value = "option", desc = { "Change", "settings" } },
  { id = "third_party.menu", label = "THIRD PARTY",
    desc = { "External", "menu" }, onSelect = injectedSelect, pinned = true },
}
local startState = {
  screenId = "Gen2StartMenu", save = { player = { name = "KRIS" } },
  items = startItems, showDescription = true,
  list = { items = startItems, index = 3, scroll = 2,
    onChoose = startChoose, onCancel = startCancel },
}
local startBundle = assert(StartMenu.extract(startState))
local startModel = startBundle.model
check(startCalls == 0, "Start extraction invokes no source callback")
check(Data.isFunctionFree(startModel), "Start model is function-free and acyclic")
check(not startModel.phase.present and startModel.phase.value == nil
  and startModel.phase.effective == "menu", "Start nil phase preserved")
check(startModel.navigation.selectedIndex == 3
  and startModel.navigation.scroll == 2, "Start exact selection and scroll")
check(startModel.items[1].label == "POKéGEAR", "Start host token expansion")
check(startModel.items[3].pinned and startModel.items[3].id == "third_party.menu",
  "Start stable injected identity and pin state")
check(startModel.selectedDescription[1] == "External",
  "Start selected description")
check(startBundle.actions.entries["choose.3"].callback == startChoose,
  "Start routes injected row through source list")
check(startBundle.actions.entries["choose.3"].receiver == nil
  and startBundle.actions.entries["choose.3"].argumentCount == 2,
  "Start list callback preserves plain-call convention and nil-safe arity")
check(startBundle.actions.entries["choose.3"].arguments[2] == 3,
  "Start action preserves exact source index")
check(startBundle.actions.entries["menu.back"].callback == startCancel,
  "Start source cancel callback is mapped")
check(startBundle.actions.entries["menu.back"].receiver == nil,
  "Start source cancel remains a plain callback")
startItems[3].desc[1] = "MUTATED"
check(startModel.selectedDescription[1] == "External",
  "Start descriptions are detached")

local quitCalls = 0
local quitState = {
  screenId = "Gen2StartMenu", save = {}, items = startItems,
  showDescription = false, phase = "confirm", confirmChoice = 2,
  list = { items = startItems, index = 1, scroll = 0 },
  confirmQuit = function() quitCalls = quitCalls + 1 end,
}
local quitBundle = assert(StartMenu.extract(quitState))
check(quitCalls == 0, "Start quit extraction does not confirm")
check(quitBundle.model.phase.present
  and quitBundle.model.confirm.selectedChoice == 2,
  "Start confirm phase and choice preserved")
check(quitBundle.actions.entries["quit.confirm"].callback
  == quitState.confirmQuit, "Start quit source method is mapped")
check(quitBundle.actions.entries["quit.cancel"].dispatch == "source_input",
  "Start quit cancellation remains source-input owned")

-- Options: formatter/action functions are never called during extraction.
local optionCalls = 0
local function forbiddenFormatter()
  optionCalls = optionCalls + 1
  return "BAD"
end
local function activate() optionCalls = optionCalls + 1 end
local optionRows = {
  { label = "BATTLE SCENE", key = "battleScene",
    values = { true, false }, display = { [true] = "ON ", [false] = "OFF" } },
  { label = "MUSIC VOL", key = "musicVol", text = forbiddenFormatter },
  { id = "controls", label = "CONTROLS", activate = activate },
  { id = "custom", label = "CUSTOM", value = forbiddenFormatter },
  { id = "cancel", label = "CANCEL", cancel = true },
}
local cycle = function() optionCalls = optionCalls + 1 end
local leave = function() optionCalls = optionCalls + 1 end
local optionState = {
  screenId = "Gen2OptionsMenu", rows = optionRows,
  options = { battleScene = false, musicVol = 0 },
  index = 2, scroll = 1, cycle = cycle, leave_ = leave,
  game = { marker = "source-game" },
}
local optionBundle = assert(OptionsMenu.extract(optionState))
local optionModel = optionBundle.model
check(optionCalls == 0, "Options extraction invokes no row/source function")
check(Data.isFunctionFree(optionModel), "Options model is function-free and acyclic")
check(not optionModel.phase.present and optionModel.phase.effective == "menu",
  "Options absent phase represented exactly")
check(optionModel.navigation.selectedIndex == 2
  and optionModel.navigation.scroll == 1, "Options exact selection and scroll")
check(optionModel.rows[1].displayValue == "OFF",
  "Options static display table formatting")
check(optionModel.rows[2].displayValue == "OFF",
  "Options known formatter without calling row.text")
check(optionModel.rows[3].displayValue == "OPEN",
  "Options action row display")
check(optionModel.rows[4].displayValue == "N/A",
  "Options unknown function value is not invoked")
check(optionBundle.actions.entries["row.1.previous"].callback == cycle,
  "Options previous action maps source cycle method")
check(optionBundle.actions.entries["row.1.previous"].arguments[1] == optionRows[1]
  and optionBundle.actions.entries["row.1.previous"].arguments[2] == -1,
  "Options cycle mapping retains source row and delta")
check(optionBundle.actions.entries["row.3.activate"].callback == activate,
  "Options activate callback is mapped")
check(optionBundle.actions.entries["menu.back"].callback == leave,
  "Options close source method is mapped")
check(optionCalls == 0, "Inspecting mappings still invokes nothing")
optionRows[1].display[false] = "MUTATED"
optionState.options.musicVol = 7
check(optionModel.rows[1].displayValue == "OFF"
  and optionModel.rows[2].displayValue == "OFF",
  "Options labels and values are detached")

-- Provider composition exposes models but cannot suppress or prepare a frame.
local catalog, shared = Catalog.build(), Shared.build()
local classes = {}
local function classFor(record)
  classes[record.id] = classes[record.id] or { isOpaque = record.opaque }
  classes[record.id].__index = classes[record.id]
  return classes[record.id]
end
local provider = Provider.new({
  catalog = catalog,
  shared = shared,
  classResolver = function(record) return classFor(record) end,
})
check(FoundationModels.register(provider) == true,
  "foundation adapters register")
local providerMain = setmetatable({
  screenId = "Gen2MainMenu", hasSave = false, phase = "menu",
  list = { items = { { label = "NEW GAME", value = "new" } },
    index = 1, scroll = 0 },
}, classFor(catalog.byId.Gen2MainMenu))
local inspected = provider:inspect(providerMain, {})
check(inspected.valid and not inspected.suppress
  and inspected.reason == "model_ready_native",
  "registered model remains explicitly native")
local extracted = provider:extractModel(providerMain, {})
check(extracted.valid and not extracted.suppress
  and extracted.reason == "model_ready_native",
  "provider extracts without suppression")
check(extracted.presentation.model.screenId == "Gen2MainMenu",
  "provider returns the production model bundle")
check(provider:prepare(providerMain, {}).suppress == false,
  "model adapter alone cannot prepare a suppressible frame")
providerMain.phase = "future"
check(provider:extractModel(providerMain, {}).reason == "unknown_mode",
  "provider validates before model extraction")
providerMain.phase = "menu"
check(FoundationPresenters.register(provider) == true,
  "foundation presenters register")
local prepared = provider:prepare(providerMain, {})
check(prepared.valid and prepared.suppress
  and prepared.presentation.complete == true,
  "production presenter prepares a complete suppressible model")
check(prepared.presentation.model.kind == "menu"
  and prepared.presentation.model.preset == "M",
  "Main production model uses the stable M menu envelope")
check(Data.isFunctionFree(prepared.presentation.model),
  "production presentation model remains function-free")

local tapped
local pointerProvider = {
  pointerPress = {},
  mod = { input = { tap = function(_, _, button)
    tapped = button
    return true
  end } },
}
local pointerState = {
  screenId = "Gen2StartMenu",
  list = { index = 1, ensureVisible = function() end },
}
local pointerLayout = { hitRegions = {{
  id = "filtered", role = "menu_row", index = 1, sourceIndex = 4,
  rect = { x=10, y=20, w=100, h=40 },
}} }
check(SourceInput.pointer(pointerProvider, pointerState, nil, pointerLayout,
  { phase="pressed", source="mouse", button=1, x=20, y=30 }, {}) == true,
  "pointer press accepts production row geometry")
check(pointerState.list.index == 4,
  "pointer routes a filtered production row to its native source index")
check(SourceInput.pointer(pointerProvider, pointerState, nil, pointerLayout,
  { phase="released", source="mouse", button=1, x=20, y=30 }, {}) == true
  and tapped == "a",
  "pointer release activates the selected native row through mod.input")

local liveGame = { stack = { states = { providerMain } } }
check(provider:visibleStack(liveGame, {})[1] == providerMain,
  "complete exact foundation stack is eligible")
local unknownState = { screenId = "Gen2FutureMenu" }
liveGame.stack.states[2] = unknownState
check(#provider:visibleStack(liveGame, {}) == 0,
  "unknown layer fails the complete stack open to native")
liveGame.stack.states = { providerMain,
  setmetatable({ screenId = "Gen2BattleState" }, {}) }
check(#provider:visibleStack(liveGame, {}) == 0,
  "battle-owned stack remains wholly native")

local convertedStart = assert(FoundationPresenters.convert(
  "Gen2StartMenu", quitBundle.model))
check(convertedStart.preset == "NAV" and convertedStart.opaque == false,
  "Start production model keeps the tall NAV overlay")
check(convertedStart.modal and convertedStart.modal.selected == 2,
  "Start confirmation becomes a stable modal overlay")
local convertedOptions = assert(FoundationPresenters.convert(
  "Gen2OptionsMenu", optionBundle.model))
check(convertedOptions.rows[2].right == "OFF"
  and convertedOptions.selected == 2,
  "Options production rows preserve values and source selection")

-- Gallery models come from the same production adapters and contain no calls.
local galleryModels = FoundationModels.galleryFixtures()
check(#galleryModels == 9, "nine focused foundation Gallery models")
local gallery = Gallery.build(catalog, shared, galleryModels)
local expected = {
  ["gen2.core.main_menu.new_game"] = "Gen2MainMenu",
  ["gen2.core.main_menu.continue"] = "Gen2MainMenu",
  ["gen2.core.main_menu.continue_confirm"] = "Gen2MainMenu",
  ["gen2.navigation.start_menu.stock"] = "Gen2StartMenu",
  ["gen2.navigation.start_menu.pinned"] = "Gen2StartMenu",
  ["gen2.navigation.start_menu.overflow"] = "Gen2StartMenu",
  ["gen2.navigation.start_menu.quit_confirm"] = "Gen2StartMenu",
  ["gen2.core.options_menu.options"] = "Gen2OptionsMenu",
  ["gen2.core.options_menu.overflow"] = "Gen2OptionsMenu",
}
local found = 0
for _, fixture in ipairs(gallery.fixtures) do
  local screenId = expected[fixture.id]
  if screenId then
    found = found + 1
    check(fixture.modelReady and not fixture.statusOnly,
      "Gallery fixture has model " .. fixture.id)
    check(fixture.sourceModel.screenId == screenId,
      "Gallery exact source model screen " .. fixture.id)
    check(fixture.model.kind == "menu"
      and fixture.model.preset == catalog.byId[screenId].preset,
      "Gallery uses the production presenter " .. fixture.id)
    check(Data.isFunctionFree(fixture.model),
      "Gallery model is function-free " .. fixture.id)
    check(fixture.sourceModel.actionDescriptors ~= nil,
      "Gallery source model exposes action descriptors " .. fixture.id)
  end
end
check(found == 9, "all focused Gallery fixture ids found")
check(Data.isFunctionFree(gallery), "complete Gallery payload is function-free")

print(("Gen2 foundation model tests: %d checks passed"):format(checks))
