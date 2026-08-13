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
    set = function(_, key, value) stored[key] = value return true end,
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
assert(type(definedSchema) == "table" and #definedSchema == 12,
  "clean settings schema")
assert(mod.exports.cleanUiHost.apiVersion == 3, "V3 host surface")
assert(mod.exports.cleanUiHost.productId == "gen2_clean_ui", "exact product id")
assert(mod.exports.gen2CleanUi.coreStatus == "ready", "vendored core status")
assert(type(hookWrappers["render.ui.prepare"]) == "function"
  and type(hookWrappers["screen.render_visible"]) == "function"
  and type(hookWrappers["render.hud"]) == "function"
  and type(hookWrappers["input.pointer"]) == "function"
  and type(hookWrappers["input.wheel"]) == "function",
  "sandbox-safe presentation and shell hooks")
assert(type(registeredScreens.Gen2CleanUiShell) == "table",
  "Gen2 shell registration")
assert(#mod.exports.gen2CleanUi.contracts == 51, "51 exported contracts")
assert(type(mod.exports.gen2CleanUi.extractModel) == "function",
  "foundation model extractor export")
assert(#mod.exports.gen2CleanUi.modelScreens == 14,
  "foundation and 0.2 gameplay model contracts")
assert(#mod.exports.gen2CleanUi.presentationScreens == 14,
  "foundation and 0.2 production presenters")
local implemented = {}
for _, record in ipairs(mod.exports.gen2CleanUi.contracts) do
  implemented[record.id] = record.implementation
end
assert(implemented.Gen2PartyMenu == "production_presenter"
  and implemented.Gen2BoxMenu == "production_presenter"
  and implemented.Gen2Pokegear == "pending_presenter",
  "runtime metadata distinguishes production and pending contracts")
local modelFixtureCount = 0
for _, fixture in ipairs(mod.exports.gen2CleanUi.gallery.fixtures) do
  if fixture.modelReady then
    modelFixtureCount = modelFixtureCount + 1
    assert(type(fixture.model) == "table", "model-backed Gallery fixture")
  end
end
assert(modelFixtureCount == 59,
  "foundation, shared, and all 47 gameplay/storage Gallery fixtures")
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
for _, id in ipairs({ "Gen2MainMenu", "Gen2OptionsMenu" }) do
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
local mainItems = {
  { label = "NEW GAME", value = "new" },
  { label = "OPTION", value = "option" },
}
local liveMain = setmetatable({
  screenId = "Gen2MainMenu", hasSave = false, phase = "menu",
  list = { items = mainItems, index = 1, scroll = 0 },
}, classes.Gen2MainMenu)
fakeStack.states = { liveMain }
stored.font = "system"
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
fakeStack.states = {}
stored.font = nil
assert(mod.exports.gen2CleanUi.resetDefaults() == true, "public reset defaults")
for _, row in ipairs(definedSchema) do
  assert(stored[row.key] == row.default, "default reset: " .. row.key)
end

print("Gen2 product bootstrap smoke test passed")
