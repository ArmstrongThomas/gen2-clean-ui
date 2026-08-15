local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"), "GEN2_CLEAN_UI_ROOT is required")
root = root:gsub("\\", "/")

local definedSchema
local stored = {}
local hookWrappers, registeredScreens, eventListeners = {}, {}, {}
local fakeStack = { states = {} }
function fakeStack:push(screen) self.states[#self.states + 1] = screen end
function fakeStack:pop() return table.remove(self.states) end
function fakeStack:top() return self.states[#self.states] end
local fakeGame = { stack = fakeStack,
  input = { wasPressed = function() return false end } }
local fakeTextBoxClass = { isOpaque=false, isTextBox=true }
fakeTextBoxClass.__index = fakeTextBoxClass
local fakeChoiceBoxClass = { isOpaque=false }
fakeChoiceBoxClass.__index = fakeChoiceBoxClass
local mod = {
  id = "gen2_clean_ui",
  version = "0.1.0",
  path = root .. "/mods/gen2_clean_ui",
  exports = {},
  save = {
    get = function(_, _, fallback) return fallback end,
    set = function() return true end,
  },
  options = {
    define = function(_, schema) definedSchema = schema return schema end,
    get = function(_, key) return stored[key] end,
  },
  log = {
    info = function() end,
    warn = function() end,
    error = function() end,
  },
  hooks = {
    wrap = function(_, name, callback)
      hookWrappers[name] = callback
      return function() hookWrappers[name] = nil end
    end,
  },
  events = {
    on = function(_, name, callback)
      eventListeners[name] = eventListeners[name] or {}
      eventListeners[name][#eventListeners[name] + 1] = callback
      return function() end
    end,
  },
  input = {
    tap = function(_, game, button)
      game.tapped = button
      return true
    end,
  },
  content = {
    screens = {
      register = function(_, id, record)
        registeredScreens[id] = record
        return record
      end,
    },
  },
  ui = {
    TextBox = fakeTextBoxClass,
    ChoiceBox = fakeChoiceBoxClass,
    isBuiltinScreen = function(state, id)
      local class = getmetatable(state)
      return rawget(state, "screenId") == id
        and type(class) == "table" and class.__cleanUiBuiltinId == id
        and rawget(state, "draw") == nil
    end,
    push = function(game, id, ...)
      local factory = assert(registeredScreens[id], "unknown fake screen: " .. id)
      local screen = assert(factory.new(game, ...))
      game.stack:push(screen)
      return screen
    end,
  },
  game = fakeGame,
}
function mod:read(relative)
  local file = io.open(self.path .. "/" .. relative, "rb")
  if not file then return nil, "not found: " .. relative end
  local source = file:read("*a")
  file:close()
  return source
end

local SandboxEnv = assert(loadfile(root .. "/tests/sandbox_env.lua"))()
local sandbox = SandboxEnv.new({ love=love, require=require })
assert(sandbox.env._G == sandbox.env and sandbox.env.io == nil
  and sandbox.env.package == nil and sandbox.env.debug == nil,
  "product test uses private sandbox globals")
local entrySource = assert(mod:read("main.lua"))
local entry = assert(sandbox.compile(entrySource, "@gen2_clean_ui/main.lua"))()
assert(type(entry) == "function", "main.lua must return an installer")
local product = entry(mod)
assert(type(product) == "table", "product bootstrap result")
assert(type(definedSchema) == "table" and #definedSchema == 11,
  "clean settings schema")
for _, row in ipairs(definedSchema) do
  assert(row.key ~= "pointer_touch", "pointer/touch is hidden from settings")
end
assert(mod.exports.cleanUiHost.apiVersion == 3, "V3 host surface")
assert(mod.exports.cleanUiHost.productId == "gen2_clean_ui", "exact product id")
assert(mod.exports.cleanUiHost.coreVersion == "0.1.0-alpha.12",
  "vendored V3 core version")
local coreModel = assert(loadfile(root
  .. "/mods/gen2_clean_ui/vendor/clean_ui_core/presentation/model.lua"))(
    function() end)
local validModel = {
  schema="clean_ui.v3.presentation.v1", apiVersion=3, kind="menu",
  preset="M", rows={{ id="ok", label="OK" }}, selected=1,
}
assert(coreModel.validate(validModel) == true,
  "vendored V3 model validator accepts a canonical menu")
local sparseModel = {
  schema="clean_ui.v3.presentation.v1", apiVersion=3, kind="menu",
  preset="M", rows={ [2]={ id="gap", label="GAP" } }, selected=1,
}
local sparseOk, sparseCode = coreModel.validate(sparseModel)
assert(not sparseOk and sparseCode == "invalid_model",
  "vendored V3 model validator rejects sparse collections")
local invalidSelection = {
  schema="clean_ui.v3.presentation.v1", apiVersion=3, kind="battle",
  preset="BATTLE", player={}, enemy={}, actions={}, selectedAction="1",
}
local selectionOk, selectionCode = coreModel.validate(invalidSelection)
assert(not selectionOk and selectionCode == "invalid_model",
  "vendored V3 model validator rejects non-integer selections")
assert(mod.exports.cleanUiHost:supports("contract_catalog", "0.1.0")
  and type(mod.exports.cleanUiHost.listContracts) == "function",
  "V3 editor contract catalog surface")
assert(mod.exports.cleanUiHost:supports("presentation_models", "0.1.0"),
  "V3 canonical presentation-model capability")
local sharedV3 = assert(mod.exports.cleanUiHost:listContracts({
  ownerId = "gen2_clean_ui" }))
assert(#sharedV3 == 11, "production V3 contract count")
local v3ById = {}
local directV3Screens = 0
for _, descriptor in ipairs(sharedV3) do v3ById[descriptor.id] = descriptor end
for _, descriptor in ipairs(sharedV3) do
  for _, screen in ipairs(descriptor.screens or {}) do
    if screen.kind then
      directV3Screens = directV3Screens + 1
      assert(coreModel.validate(screen) == true,
        "every catalog direct V3 screen validates: " .. descriptor.id
          .. "/" .. tostring(screen.id))
    end
  end
end
assert(directV3Screens >= 30, "production catalog has broad direct V3 examples")
local dialogueV3 = v3ById.gen2_shared_dialogue
local foundationV3 = v3ById.gen2_foundation_menus
local partyV3 = v3ById.gen2_party_menus
local inventoryDeviceV3 = v3ById.gen2_inventory_device
local progressV3 = v3ById.gen2_progress_menus
local battleV3 = v3ById.gen2_battle_preview
local animationV3 = v3ById.gen2_battle_animations
local extendedV3 = v3ById.gen2_extended_menus
local bootV3 = v3ById.gen2_boot_animations
local cinematicV3 = v3ById.gen2_cinematic_animations
local officialV3 = v3ById.gen2_official_catalog
assert(dialogueV3 and dialogueV3.screens[1].kind == "dialogue"
  and dialogueV3.screens[2].kind == "choice",
  "production shared V3 screen kinds")
assert(dialogueV3.actionIds[1] == "open_choice"
  and dialogueV3.actionIds[2] == "open_dialogue",
  "production shared V3 action catalog")
assert(dialogueV3.actions == nil,
  "production shared dialogue is registered as callback-free V3 catalog data")
assert(foundationV3 and #foundationV3.screens == 3
  and foundationV3.screens[1].kind == "menu"
  and foundationV3.screens[2].preset == "NAV"
  and foundationV3.screens[3].rows[1].right == "MID"
  and foundationV3.actions == nil,
  "foundation menus are registered as callback-free V3 catalog data")
assert(partyV3 and #partyV3.screens == 2
  and partyV3.screens[1].kind == "menu"
  and partyV3.screens[1].rows[1].barLabel == "HP 34/36"
  and partyV3.screens[2].details.bars[2].label == "EXP"
  and partyV3.actions == nil,
  "party and summary menus are registered as callback-free V3 catalog data")
assert(inventoryDeviceV3 and #inventoryDeviceV3.screens == 3
  and inventoryDeviceV3.screens[1].rows[1].right == "x12"
  and inventoryDeviceV3.screens[2].title == "POKEGEAR"
  and inventoryDeviceV3.screens[3].opaque == false
  and inventoryDeviceV3.actions == nil,
  "pack, Pokegear, and Map Radio are registered as callback-free V3 data")
assert(progressV3 and #progressV3.screens == 3
  and progressV3.screens[1].rows[2].right == "No.155  OWNED"
  and progressV3.screens[2].title == "TRAINER CARD / 1 OF 2"
  and progressV3.screens[3].preset == "M"
  and progressV3.actions == nil,
  "Pokedex, Trainer Card, and Save are registered as callback-free V3 data")
assert(battleV3 and #battleV3.screens == 1
  and battleV3.screens[1].kind == "battle"
  and battleV3.screens[1].player.expCurrent == 1728
  and battleV3.actions == nil,
  "battle is registered as callback-free V3 catalog data")
assert(animationV3 and #animationV3.screens == 2
  and animationV3.screens[1].kind == "animation"
  and animationV3.screens[1].animation.id == "battle.move"
  and animationV3.screens[2].animation.id == "battle.transition"
  and animationV3.screens[2].animation.overlay == true
  and #animationV3.gallery == 6
  and animationV3.actions == nil,
  "battle animation states are registered as callback-free V3 catalog data")
assert(bootV3 and #bootV3.screens == 4
  and bootV3.screens[1].animation.id == "boot.copyright"
  and bootV3.screens[2].animation.id == "boot.gamefreak"
  and bootV3.screens[3].animation.id == "boot.title"
  and bootV3.screens[4].animation.id == "credits.roll"
  and #bootV3.gallery == 4 and bootV3.actions == nil,
  "boot splash, Game Freak, title, and credits are registered as callback-free V3 catalog data")
assert(cinematicV3 and #cinematicV3.screens == 4
  and cinematicV3.screens[1].animation.id == "cinematic.egg_hatch"
  and cinematicV3.screens[1].animation.sprites[1].normalized == true
  and cinematicV3.screens[2].animation.id == "cinematic.evolution"
  and cinematicV3.screens[2].animation.blackout == true
  and cinematicV3.screens[3].animation.circles[1].radius == 4 / 160
  and cinematicV3.screens[4].animation.tilemap.mapWidth == 32
  and #cinematicV3.gallery == 4 and cinematicV3.actions == nil,
  "egg hatch, evolution, and Gold/Silver intro are callback-free V3 cinematic data")
assert(extendedV3 and #extendedV3.screens == 7
  and extendedV3.screens[1].preset == "XL"
  and extendedV3.screens[1].title == "TOTODILE'S NICKNAME"
  and extendedV3.screens[7].opaque == false
  and extendedV3.actions == nil,
  "extended naming, storage, service, mail, clock, and Hall of Fame screens are registered as callback-free V3 data")
assert(officialV3 and #officialV3.screens == 0
  and #officialV3.gallery == 51 and officialV3.actions == nil,
  "all official Gen2 screen statuses are exposed as callback-free V3 catalog data")
local officialSeen = {}
local officialSupported, officialNative = 0, 0
for index, entry in ipairs(officialV3.gallery) do
  assert(entry.screen_id == mod.exports.gen2CleanUi.contracts[index].id
    and not officialSeen[entry.screen_id]
    and entry.statusOnly == true
    and entry.preset ~= nil,
    "official V3 catalog preserves exact screen order and status shape " .. index)
  officialSeen[entry.screen_id] = true
  if entry.support == "supported" then
    officialSupported = officialSupported + 1
    assert(entry.implementation == "production_presenter")
  elseif entry.support == "native" then
    officialNative = officialNative + 1
    assert(type(entry.reason) == "string" and entry.reason ~= "")
  end
end
assert(officialSupported == 41 and officialNative == 10,
  "official V3 catalog preserves the 41/10 production/native split")
local expectedNative = {
  "Gen2CardFlip", "Gen2CopyrightSplash", "Gen2GoldSilverIntro",
  "Gen2GameFreakPresents", "Gen2MagnetTrainRide", "Gen2OakSpeech",
  "Gen2SlotMachine", "Gen2TitleState", "Gen2TradeAnim", "Gen2UnownPuzzle",
}
for _, screenId in ipairs(expectedNative) do
  local entry
  for _, candidate in ipairs(officialV3.gallery) do
    if candidate.screen_id == screenId then entry = candidate break end
  end
  assert(entry and entry.support == "native"
      and entry.implementation == "native"
      and type(entry.reason) == "string" and entry.reason ~= "",
    "official V3 catalog keeps the exact native boundary: " .. screenId)
end
local editorSmokeContract = {
  id = "editor_smoke",
  version = "1.0.0",
  games = { "gen2" },
  screens = { { id = "editor_smoke_screen", type = "panel",
    title = "EDITOR SMOKE", preset = "M", components = {
      { id = "noop", type = "button", label = "NOOP", action = "noop" },
    } } },
  actions = { noop = function() end },
}
assert(mod.exports.cleanUiHost:register("editor_smoke_owner",
  editorSmokeContract), "V3 editor contract registration")
local editorSmoke = assert(mod.exports.cleanUiHost:listContracts({
  ownerId = "editor_smoke_owner" }))
assert(#editorSmoke == 1 and editorSmoke[1].actionIds[1] == "noop"
  and editorSmoke[1].actions == nil,
  "V3 editor catalog strips runtime callbacks")
assert(mod.exports.cleanUiHost:unregister("editor_smoke_owner", "editor_smoke"),
  "V3 editor contract cleanup")
assert(mod.exports.compatibilityApiVersion == 1
  and mod.exports.surfaceApiVersion == 2,
  "Modern UI v1/v2 compatibility surface")
assert(type(mod.exports.registerAdapter) == "function"
  and type(mod.exports.unregisterAdapter) == "function"
  and type(mod.exports.registerTheme) == "function"
  and type(mod.exports.registerFrame) == "function",
  "Modern UI compatibility registration methods")
assert(mod.exports.modernUi == mod.exports.gen2ModernUi
  and mod.exports.gen2CleanUi.modernUi == mod.exports.modernUi,
  "Modern UI compatibility aliases share one registry")
assert(mod.exports.gen2CleanUi.coreStatus == "ready", "vendored core status")
assert(type(hookWrappers["render.ui.prepare"]) == "function"
  and type(hookWrappers["screen.render_visible"]) == "function"
  and type(hookWrappers["render.hud"]) == "function"
  and type(hookWrappers["input.step"]) == "function"
  and type(hookWrappers["input.pointer"]) == "function"
  and type(hookWrappers["input.wheel"]) == "function",
  "sandbox-safe presentation and shell hooks")
assert(eventListeners["screen.pushed"] and #eventListeners["screen.pushed"] > 0
  and eventListeners["screen.popped"] and #eventListeners["screen.popped"] > 0,
  "screen stack lifecycle invalidation listeners")
assert(type(registeredScreens.Gen2CleanUiShell) == "table",
  "Gen2 shell registration")
assert(#mod.exports.gen2CleanUi.contracts == 51, "51 exported contracts")
assert(type(mod.exports.gen2CleanUi.extractModel) == "function",
  "foundation model extractor export")
assert(type(mod.exports.gen2CleanUi.coverage) == "function",
  "read-only presenter coverage export")
assert(#mod.exports.gen2CleanUi.modelScreens == 41,
  "foundation, 0.2, 0.3, and battle model contracts")
assert(#mod.exports.gen2CleanUi.presentationScreens == 41,
  "foundation, 0.2, 0.3, and battle production presenters")
local coverage = mod.exports.gen2CleanUi.coverage()
assert(#coverage == 51, "coverage reports the complete official catalog")
local coverageById = {}
for _, row in ipairs(coverage) do coverageById[row.id] = row end
for _, record in ipairs(mod.exports.gen2CleanUi.contracts) do
  local row = coverageById[record.id]
  assert(row and row.support == record.support,
    "coverage preserves exact support metadata: " .. record.id)
  if record.support == "supported" then
    assert(row.modelAdapter and row.presenter,
      "every supported official screen has a V3 adapter and presenter: "
        .. record.id)
  end
end
local implemented = {}
local v3OfficialCount = 0
for _, record in ipairs(mod.exports.gen2CleanUi.contracts) do
  implemented[record.id] = record.implementation
  if record.presentationApi == 3 then v3OfficialCount = v3OfficialCount + 1 end
end
assert(v3OfficialCount == 41,
  "all integrated official production presenters require V3 models")
assert(implemented.Gen2PartyMenu == "production_presenter"
  and implemented.Gen2BoxMenu == "production_presenter"
  and implemented.Gen2Pokegear == "production_presenter"
  and implemented.Gen2MartMenu == "production_presenter"
  and implemented.Gen2MailCompose == "production_presenter"
  and implemented.Gen2BattleTransition == "production_presenter"
  and implemented.Gen2Credits == "production_presenter"
  and implemented.Gen2EggHatchAnim == "production_presenter"
  and implemented.Gen2EvolutionAnim == "production_presenter"
  and implemented.Gen2CopyrightSplash == "native"
  and implemented.Gen2TitleState == "native"
  and implemented.Gen2GameFreakPresents == "native"
  and implemented.Gen2GoldSilverIntro == "native",
  "runtime metadata distinguishes production and native/pending contracts")
local modelFixtureCount = 0
for _, fixture in ipairs(mod.exports.gen2CleanUi.gallery.fixtures) do
  if fixture.modelReady then
    modelFixtureCount = modelFixtureCount + 1
    assert(type(fixture.model) == "table", "model-backed Gallery fixture")
    assert(fixture.model.schema == "clean_ui.v3.presentation.v1"
      and fixture.model.apiVersion == 3
      and type(fixture.model.kind) == "string"
      and fixture.model.kind ~= "",
      "model-backed Gallery fixture uses canonical V3 markers: "
        .. tostring(fixture.id))
    assert(coreModel.validate(fixture.model) == true,
      "model-backed Gallery fixture validates as V3: " .. tostring(fixture.id))
  end
end
assert(modelFixtureCount == 117,
  "foundation, shared, and all integrated 0.2/0.3 Gallery fixtures")
assert(#mod.exports.gen2CleanUi.sharedPresentationScreens == 2,
  "TextBox and ChoiceBox shared presenters are exported")

-- The product's real provider and vendored core prepare a complete frame
-- before the exact native source becomes suppressible. A mixed/unknown stack
-- clears that proof immediately.
local contracts = {}
for _, record in ipairs(mod.exports.gen2CleanUi.contracts) do
  contracts[record.id] = record
end
local classes = {}
for _, id in ipairs({ "Gen2MainMenu", "Gen2OptionsMenu",
    "Gen2BattleTransition" }) do
  classes[id] = { __index = nil, isOpaque = contracts[id].opaque,
    __cleanUiBuiltinId = id }
  classes[id].__index = classes[id]
end
package.preload[contracts.Gen2MainMenu.module] = function()
  return classes.Gen2MainMenu
end
package.preload[contracts.Gen2OptionsMenu.module] = function()
  return classes.Gen2OptionsMenu
end
package.preload[contracts.Gen2BattleTransition.module] = function()
  return classes.Gen2BattleTransition
end
local mainItems = {
  { label = "NEW GAME", value = "new" },
  { label = "OPTION", value = "option" },
}
local liveMain = setmetatable({
  game = fakeGame, screenId = "Gen2MainMenu", hasSave = false, phase = "menu",
  list = { items = mainItems, index = 1, scroll = 0 },
}, classes.Gen2MainMenu)
fakeStack.states = { liveMain }
stored.font = "system"
local headless = os.getenv("GEN2_CLEAN_UI_HEADLESS") == "1"
-- Hosted CI runs without a graphics context; keep the model/stack checks but
-- leave frame composition to the normal local hidden-window smoke run.
if not headless then
  -- The v0.1.86 host's legacy visibility hook supplies the state, not the
  -- game. The compatibility path must use the state's public game field so
  -- every screen family still gets a complete frame when the facade fallback
  -- is absent.
  local savedModGame = mod.game
  mod.game = nil
  fakeStack.states = { liveMain }
  assert(hookWrappers["screen.render_visible"](
    function() return true end, liveMain) == false,
    "v0.1.86 fallback resolves game from the live state for every UI")
  mod.game = savedModGame

  hookWrappers["render.ui.prepare"](function() end, fakeGame,
    { width=640, height=360 })
  assert(hookWrappers["screen.render_visible"](function() return true end,
    liveMain) == false, "complete production frame suppresses exact source")
  hookWrappers["render.hud"](function() end, fakeGame,
    { width=640, height=360 })

  fakeStack.states[2] = { screenId = "Gen2FutureMenu" }
  hookWrappers["render.ui.prepare"](function() end, fakeGame,
    { width=640, height=360 })
  assert(hookWrappers["screen.render_visible"](function() return true end,
    liveMain) == true, "unknown retained layer keeps complete stack native")

  fakeStack.states = { liveMain, { screenId="Gen2BattleState" } }
  hookWrappers["render.ui.prepare"](function() end, fakeGame,
    { width=640, height=360 })
  assert(hookWrappers["screen.render_visible"](function() return true end,
    liveMain) == true, "battle-owned stack veto restores native UI")

  fakeStack.states = { liveMain, setmetatable({
    screenId="Gen2BattleTransition", phase="outro", style="spin",
    frame=4, step=2, trainer=true, black={},
  }, classes.Gen2BattleTransition) }
  hookWrappers["render.ui.prepare"](function() end, fakeGame,
    { width=640, height=360 })
  local transitionMainVisible = hookWrappers["screen.render_visible"](
    function() return true end, liveMain)
  local transitionSourceVisible = hookWrappers["screen.render_visible"](
    function() return true end, fakeStack.states[2])
  local transitionInspection = mod.exports.gen2CleanUi.inspect(
    fakeStack.states[2], {})
  assert(transitionMainVisible == true and transitionSourceVisible == false,
    "transparent battle transition suppresses only its native source: main="
      .. tostring(transitionMainVisible) .. " source="
      .. tostring(transitionSourceVisible) .. " inspect="
      .. tostring(transitionInspection and transitionInspection.reason))
end

if not headless then
  local malformedText = setmetatable({
    game=fakeGame, pages={{ "HELLO" }}, pageIndex=1, lineIndex=1,
    codes={ 1, 2, 3, 4, 5 }, charIndex=0, shown={},
    waiting=false, done=false, blink=0,
    boxTx=0, boxTy=12, boxTw=20, boxTh=6, maxCols=18,
  }, fakeTextBoxClass)
  fakeStack.states = { malformedText }
  hookWrappers["render.ui.prepare"](function() end, fakeGame,
    { width=640, height=360 })
  assert(hookWrappers["screen.render_visible"](function() return true end,
    malformedText) == true,
    "malformed shared TextBox fails open through the installed runtime")

  local validText = setmetatable({
    game=fakeGame, pages={{ "HELLO" }}, pageIndex=1, lineIndex=1,
    codes={ 1, 2, 3, 4, 5 }, charIndex=0, shown={{}},
    waiting=false, done=false, blink=0,
    boxTx=0, boxTy=12, boxTw=20, boxTh=6, maxCols=18,
  }, fakeTextBoxClass)
  fakeStack.states = { validText }
  hookWrappers["render.ui.prepare"](function() end, fakeGame,
    { width=640, height=360 })
  assert(hookWrappers["screen.render_visible"](function() return true end,
    validText) == false,
    "dialogue-capable core replaces a valid shared TextBox atomically")
  stored.native_dialogue = true
  fakeStack.states = { validText }
  hookWrappers["render.ui.prepare"](function() end, fakeGame,
    { width=640, height=360 })
  assert(hookWrappers["screen.render_visible"](function() return true end,
    validText) == true,
    "Native Dialogue keeps an otherwise valid shared TextBox native")
  stored.native_dialogue = nil
end

local continuation = {
  waiting = true, contAdvance = true, preWait = 0, done = false,
}
fakeStack.states = { continuation }
fakeGame.tapped = nil
hookWrappers["input.step"](function() return true end, fakeGame, 1 / 60)
assert(fakeGame.tapped == "a",
  "Clean UI auto-advances a native continuation break")
stored.native_dialogue = true
fakeGame.tapped = nil
hookWrappers["input.step"](function() return true end, fakeGame, 1 / 60)
assert(fakeGame.tapped == nil,
  "native dialogue keeps ownership of continuation breaks")
stored.native_dialogue = nil
fakeStack.states = {}
stored.font = nil
assert(mod.exports.gen2CleanUi.resetDefaults() == true, "public reset defaults")
assert(stored.font == nil,
  "v0.1.86 read-only options API remains untouched by reset defaults")

print("Gen2 product bootstrap smoke test passed")
