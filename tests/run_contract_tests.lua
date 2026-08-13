local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"), "GEN2_CLEAN_UI_ROOT is required")
root = root:gsub("\\", "/")

local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)
local Catalog = ctx.load("contracts.catalog")
local Shared = ctx.load("contracts.shared")
local Provider = ctx.load("provider.init")
local Gallery = ctx.load("gallery.catalog")

local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, ("check %d failed: %s"):format(checks, message))
end

local catalog = Catalog.build()
check(catalog.count == 51, "official contract count")
check(#catalog.officialIds == 51, "official id count")

local seen = {}
local counts = { supported = 0, native = 0, deferred = 0 }
for index, record in ipairs(catalog.records) do
  check(record.id == catalog.officialIds[index], "official order " .. index)
  check(not seen[record.id], "unique id " .. record.id)
  seen[record.id] = true
  check(catalog.byId[record.id] == record, "byId identity " .. record.id)
  check(type(record.module) == "string", "official module " .. record.id)
  check(type(record.validateBase) == "function", "base validator " .. record.id)
  check(type(record.validateMode) == "function", "mode validator " .. record.id)
  counts[record.support] = (counts[record.support] or 0) + 1

  local ok, valid = pcall(record.validateBase, {})
  check(ok, "empty state validator is protected " .. record.id)
  check(not valid, "empty state fails open " .. record.id)
end
check(counts.supported == 36, "36 audited target contracts")
check(counts.native == 13, "13 native contracts")
check(counts.deferred == 2, "2 deferred contracts")

local shared = Shared.build()
check(#shared.records == 3, "three shared seams")
check(shared.denyAnonymous.PrizeMenu == true, "anonymous PrizeMenu denied")

local gallery = Gallery.build(catalog, shared)
check(gallery.count > 54, "variant-rich Gallery status catalog")
local galleryIds = {}
for _, fixture in ipairs(gallery.fixtures) do
  check(not galleryIds[fixture.id], "unique Gallery id " .. fixture.id)
  galleryIds[fixture.id] = true
  check(fixture.synthetic == true, "Gallery fixtures are synthetic")
end

local classes = {}
local function classFor(record)
  local class = classes[record.id]
  if not class then
    class = { isOpaque = record.opaque }
    class.__index = class
    classes[record.id] = class
  end
  return class
end

local provider = Provider.new({
  catalog = catalog,
  shared = shared,
  classResolver = function(record) return classFor(record) end,
})

local mainClass = classFor(catalog.byId.Gen2MainMenu)
local validMain = setmetatable({
  screenId = "Gen2MainMenu",
  hasSave = false,
  save = nil,
  phase = "menu",
  list = {
    items = { { label = "NEW GAME", value = "new" } },
    index = 1,
    scroll = 0,
  },
}, mainClass)

local inspected = provider:inspect(validMain, {})
check(inspected.valid, "valid Main contract")
check(not inspected.suppress, "pending presenter remains native")
check(inspected.reason == "presenter_unavailable", "pending presenter reason")

local malformed = setmetatable({
  screenId = "Gen2MainMenu",
  hasSave = false,
  phase = "future_phase",
  list = validMain.list,
}, mainClass)
local malformedResult = provider:inspect(malformed, {})
check(not malformedResult.suppress, "malformed state remains native")
check(malformedResult.reason == "unknown_mode", "unknown phase reported")

local foreign = setmetatable({
  screenId = "Gen2MainMenu",
  hasSave = false,
  phase = "menu",
  list = validMain.list,
  isOpaque = true,
}, {})
check(provider:inspect(foreign, {}).reason == "class_override",
  "foreign exact-id class remains native")

local customDraw = setmetatable({
  screenId = "Gen2MainMenu",
  hasSave = false,
  phase = "menu",
  list = validMain.list,
  draw = function() end,
}, mainClass)
check(provider:inspect(customDraw, {}).reason == "custom_draw",
  "instance draw override remains native")

local overrideResult = provider:inspect(validMain, {
  game = { data = { screens = { Gen2MainMenu = function() end } } },
})
check(overrideResult.reason == "registry_override",
  "mod-owned official id remains native")

local cardClass = classFor(catalog.byId.Gen2CardFlip)
local nativeCard = setmetatable({ screenId = "Gen2CardFlip" }, cardClass)
check(provider:inspect(nativeCard, {}).reason == "native_by_design",
  "native contract never suppresses")

local battleClass = classFor(catalog.byId.Gen2BattleState)
local battle = setmetatable({ screenId = "Gen2BattleState" }, battleClass)
check(provider:inspect(battle, {}).reason == "deferred",
  "deferred battle never suppresses")
check(provider:inspect({ screenId = "Gen2FutureScreen" }, {}).reason == "unknown_screen",
  "future id remains native")

check(provider:registerPresenter("Gen2MainMenu", {
  prepare = function() return { complete = false } end,
}) == true, "presenter registration")
check(provider:prepare(validMain, {}).reason == "presenter_incomplete",
  "incomplete frame remains native")

check(provider:registerPresenter("Gen2MainMenu", {
  prepare = function() error("synthetic presenter failure") end,
}) == true, "exception presenter registration")
check(provider:prepare(validMain, {}).reason == "presenter_error",
  "presenter exception remains native")

check(provider:registerPresenter("Gen2MainMenu", {
  prepare = function() return { complete = true, model = {} } end,
}) == true, "complete presenter registration")
check(provider:prepare(validMain, {}).suppress == true,
  "only a complete prepared frame is suppressible")
check(provider:prepare(malformed, {}).suppress == false,
  "valid-to-invalid drift restores native immediately")

local proved, stackReason = provider:assessStack({ validMain, battle }, {})
check(proved == nil and stackReason == "battle_owned",
  "battle veto covers the complete visible stack")

print(("Gen2 contract tests: %d checks passed"):format(checks))

