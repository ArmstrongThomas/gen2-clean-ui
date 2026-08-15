local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"), "GEN2_CLEAN_UI_ROOT is required")
root = root:gsub("\\", "/")

local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)
local Catalog = ctx.load("contracts.catalog")
local Shared = ctx.load("contracts.shared")
local Provider = ctx.load("provider.init")
local Identity = ctx.load("provider.identity")
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
check(counts.supported == 37, "37 audited target contracts")
check(counts.native == 12, "12 native contracts")
check(counts.deferred == 2, "battle contracts remain explicitly deferred")

local shared = Shared.build()
check(#shared.records == 3, "three shared seams")
check(shared.denyAnonymous.PrizeMenu == true, "anonymous PrizeMenu denied")
check(shared.byId["gold.CallerBox"].support == "native"
  and shared.byId["gold.CallerBox"].implementation == "pending_native"
  and type(shared.byId["gold.CallerBox"].nativeReason) == "string",
  "CallerBox remains explicitly native without an exact host identity seam")

local function accepts(recordId, state, message)
  local record = catalog.byId[recordId]
  local ok, accepted = pcall(record.validateBase, state)
  check(ok and accepted == true, message)
end

accepts("Gen2MartMenu", {
  save={}, items={}, marts={}, martType="STANDARD", martId=0,
  entries={}, index=1, scroll=0, phase="buy",
}, "Mart accepts the host's zero-based martId")
local mart = {
  save={}, items={}, marts={}, martType="STANDARD", martId=-1,
  entries={}, index=1, scroll=0, phase="buy",
}
check(select(2, catalog.byId.Gen2MartMenu.validateBase(mart))
  == "shape_range", "Mart rejects negative martId")

accepts("Gen2MailCompose", {
  text="", lower=false, row=0, col=0, tiles={},
}, "Mail Compose accepts the host's zero-based origin")
accepts("Gen2MailCompose", {
  text="", lower=false, row=5, col=9, tiles={},
}, "Mail Compose accepts the host's zero-based maximum cursor")

accepts("Gen2TradeMenu", {
  save={}, data={}, eventTables={}, id=0, row={},
}, "Trade accepts the host's zero-based first trade id")
accepts("Gen2TradeMenu", {
  save={}, data={}, eventTables={}, id=5, row={},
}, "Trade accepts the host's zero-based maximum trade id")
local tradeInvalid = { save={}, data={}, eventTables={}, id=6, row={} }
check(select(2, catalog.byId.Gen2TradeMenu.validateBase(tradeInvalid))
  == "shape_range", "Trade rejects ids outside the host range")

local gallery = Gallery.build(catalog, shared)
check(gallery.count > 54, "variant-rich Gallery status catalog")
local galleryIds = {}
for _, fixture in ipairs(gallery.fixtures) do
  check(not galleryIds[fixture.id], "unique Gallery id " .. fixture.id)
  galleryIds[fixture.id] = true
  check(fixture.synthetic == true, "Gallery fixtures are synthetic")
end

local classes = {}
local HOST_OPAQUE = { Gen2MartMenu = false }
local function classFor(record)
  local class = classes[record.id]
  if not class then
    local hostOpaque = HOST_OPAQUE[record.id]
    class = { isOpaque = hostOpaque == nil and record.opaque or hostOpaque }
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

local martClass = classFor(catalog.byId.Gen2MartMenu)
local validMart = setmetatable({
  screenId = "Gen2MartMenu",
  save = {}, items = {}, marts = {}, martType = "STANDARD", martId = 0,
  entries = {}, index = 1, scroll = 0, phase = "buy",
}, martClass)
local martInspected = provider:inspect(validMart, {})
check(martInspected.valid,
  "official transparent Mart identity is accepted")

-- Bryan's v0.1.86 host has the exact screen ids and native screen registry,
-- but predates the optional mod.ui.isBuiltinScreen predicate. The default
-- provider must still validate official records on that host.
local legacyProvider = Provider.new({
  catalog = catalog,
  shared = shared,
  mod = { ui = {} },
})
local legacyInspected = legacyProvider:inspect(validMain, {})
check(legacyInspected.valid,
  "official screen identity falls back when isBuiltinScreen is unavailable")

-- Apply the same v0.1.86 identity fallback to every official record. This is
-- deliberately independent of presenter coverage: native-by-design screens
-- must still be recognized as the host's screens, and supported screens must
-- not regress because only one fixture happened to exercise the fallback.
local legacyIdentityContext = {
  game = { data = { screens = {} } },
  mod = { ui = {} },
}
local legacyIdentityCount = 0
for _, record in ipairs(catalog.records) do
  local hostOpaque = HOST_OPAQUE[record.id]
  local state = { screenId = record.id,
    isOpaque = hostOpaque == nil and record.opaque or hostOpaque }
  local ok, code, detail = Identity.validate(state, record,
    legacyIdentityContext, true)
  check(ok == true,
    "v0.1.86 exact-id identity accepts " .. record.id .. " ("
      .. tostring(code or detail or "unknown") .. ")")
  legacyIdentityCount = legacyIdentityCount + 1
end
check(legacyIdentityCount == 51,
  "v0.1.86 identity fallback covers all 51 official screens")

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

local copyrightClass = classFor(catalog.byId.Gen2CopyrightSplash)
local copyright = setmetatable({ screenId = "Gen2CopyrightSplash",
  frames = 0, done = false }, copyrightClass)
check(provider:inspect(copyright, {}).reason == "native_by_design",
  "copyright splash remains source-owned native")
local titleClass = classFor(catalog.byId.Gen2TitleState)
local title = setmetatable({ screenId = "Gen2TitleState", frame = 1,
  frameCounter = 0, cloudScroll = 0, hoohPhase = 0, trails = {} }, titleClass)
check(provider:inspect(title, {}).reason == "native_by_design",
  "title state remains source-owned native")

local BootAnimations = ctx.load("adapters.boot_animations")
local copyrightBundle = assert(BootAnimations.extractCopyright(copyright, {}))
check(copyrightBundle.model.kind == "animation"
  and copyrightBundle.model.animation.id == "boot.copyright"
  and copyrightBundle.model.animation.overlay == true
  and copyrightBundle.model.animation.sprites[1].rect.w == 1,
  "copyright splash extracts a full-viewport V3 animation")
local titleBundle = assert(BootAnimations.extractTitle(title, {}))
check(titleBundle.model.kind == "animation"
  and titleBundle.model.animation.id == "boot.title"
  and #titleBundle.model.animation.sprites >= 1,
  "title state extracts a V3 animation with source art")
local gameFreakClass = classFor(catalog.byId.Gen2GameFreakPresents)
local gameFreak = setmetatable({ screenId = "Gen2GameFreakPresents",
  scene = 0, timer = 0, obp1 = 0x24, tiles = {},
  anims = { oam = {} }, frames = 0, done = false }, gameFreakClass)
check(provider:inspect(gameFreak, {}).reason == "native_by_design",
  "Game Freak splash remains source-owned native")
local GameFreakAdapter = ctx.load("adapters.gamefreak")
local gameFreakBundle = assert(GameFreakAdapter.extract(gameFreak, {}))
check(gameFreakBundle.model.kind == "animation"
  and gameFreakBundle.model.animation.id == "boot.gamefreak"
  and gameFreakBundle.model.animation.overlay == true,
  "Game Freak splash extracts a callback-free V3 animation")
local gameFreakFrame = setmetatable({ screenId = "Gen2GameFreakPresents",
  scene = 2, timer = 63, obp1 = 0x24,
  tiles = { [12] = { [5] = 0x80 } },
  anims = { oam = {{ x = 4, y = 16, tile = 0x9c, attr = 0 }} },
  frames = 63, done = false }, gameFreakClass)
local frameBundle = assert(GameFreakAdapter.extract(gameFreakFrame, {}))
local croppedOffscreen
for _, sprite in ipairs(frameBundle.model.animation.sprites) do
  if sprite.crop and sprite.crop.w == 8 and sprite.rect.x < 0 then
    croppedOffscreen = sprite
    break
  end
end
check(#frameBundle.model.animation.sprites == 2
  and croppedOffscreen and croppedOffscreen.normalized == true,
  "Game Freak preserves sparse tiles, cropped OAM, and normalized offscreen placement")
local creditsClass = classFor(catalog.byId.Gen2Credits)
local credits = setmetatable({ screenId = "Gen2Credits", scene = 0,
  borderFrame = 0, lyOverride = 0, frames = 0, shown = {
    { text = "PORT STAFF", x = 0, y = 6 },
  }, done = false }, creditsClass)
check(provider:inspect(credits, {}).reason == "presenter_unavailable",
  "valid credits state awaits its production presenter")
local CreditsAdapter = ctx.load("adapters.credits")
local creditsBundle = assert(CreditsAdapter.extract(credits, {}))
check(creditsBundle.model.kind == "animation"
  and creditsBundle.model.animation.id == "credits.roll"
  and creditsBundle.model.animation.overlay == true
  and #creditsBundle.model.animation.labels == 1,
  "credits extracts source text into a V3 animation model")

local eggHatchClass = classFor(catalog.byId.Gen2EggHatchAnim)
local eggHatch = setmetatable({ screenId = "Gen2EggHatchAnim",
  mon = { species = "TOGEPI", shiny = false }, species = "TOGEPI",
  showMon = false, shakeX = 0, sprites = {
    { kind = "crack", x = 88, y = 72 },
    { kind = "fragment", x = 88, y = 72, xOffset = 0xf8,
      yOffset = 0xf4, flipX = true, flipY = false },
  }, beats = { { frames = 80 }, { frames = 1 } }, beatIndex = 1,
  beatLeft = 80, done = false }, eggHatchClass)
check(provider:inspect(eggHatch, {}).reason == "presenter_unavailable",
  "valid egg hatch state awaits its production presenter")
local EggHatchAdapter = ctx.load("adapters.egg_hatch")
local eggHatchContext = { game = { data = {
  gen2MenuGfx = { eggHatch = {
    egg = "assets/generated/battle/front/egg.png",
    shell = "assets/generated/menu/egg_hatch.png",
  } },
  pokemon = { TOGEPI = {
    spriteFront = "assets/generated/battle/front/togepi.png", picSize = 5,
  } },
  gen2Palettes = { pokemon = {
    EGG = { normal = { { 240, 208, 88 }, { 184, 128, 0 } } },
    TOGEPI = { normal = { { 248, 240, 224 }, { 120, 88, 144 } } },
  } },
} } }
local eggHatchBundle = assert(EggHatchAdapter.extract(eggHatch,
  eggHatchContext))
check(eggHatchBundle.model.kind == "animation"
  and eggHatchBundle.model.animation.id == "cinematic.egg_hatch"
  and eggHatchBundle.model.animation.overlay == true
  and #eggHatchBundle.model.animation.sprites == 3
  and eggHatchBundle.model.animation.sprites[2].crop.y == 0
  and eggHatchBundle.model.animation.sprites[3].normalized == true
  and eggHatchBundle.model.animation.sprites[3].flipX == true,
  "egg hatch extracts the egg, cracks, and normalized shell fragments")
eggHatch.showMon = true
eggHatch.sprites = {}
local hatchlingBundle = assert(EggHatchAdapter.extract(eggHatch,
  eggHatchContext))
check(hatchlingBundle.model.animation.sprites[1].path
  == "assets/generated/battle/front/togepi.png"
  and hatchlingBundle.model.animation.sprites[1].palette[2][1] == 248,
  "egg hatch swaps to the extracted hatchling art and palette")

local evolutionClass = classFor(catalog.byId.Gen2EvolutionAnim)
local evolution = setmetatable({ screenId = "Gen2EvolutionAnim",
  mon = { species = "CYNDAQUIL", shiny = false },
  entry = { into = "QUILAVA" }, oldSpecies = "CYNDAQUIL",
  newSpecies = "QUILAVA", nick = "CINDY", newName = "QUILAVA",
  rounds = {
    { wait = 16, flashes = 1 }, { wait = 14, flashes = 2 },
    { wait = 12, flashes = 3 }, { wait = 10, flashes = 4 },
    { wait = 8, flashes = 5 }, { wait = 6, flashes = 6 },
    { wait = 4, flashes = 7 }, { wait = 2, flashes = 8 },
  }, canceled = false, learned = {}, full = {}, balls = {},
  ballFrame = 0, showNew = false, blackout = true,
  phase = "flash", timer = 16 }, evolutionClass)
check(provider:inspect(evolution, {}).reason == "presenter_unavailable",
  "valid evolution state awaits its production presenter")
local EvolutionAdapter = ctx.load("adapters.evolution")
local evolutionContext = { game = { data = {
  pokemon = {
    CYNDAQUIL = { spriteFront = "assets/generated/battle/front/cyndaquil.png",
      picSize = 5 },
    QUILAVA = { spriteFront = "assets/generated/battle/front/quilava.png",
      picSize = 6 },
  },
  gen2Palettes = { pokemon = {
    CYNDAQUIL = { normal = { { 248, 144, 80 }, { 168, 72, 32 } } },
    QUILAVA = { normal = { { 248, 144, 80 }, { 168, 72, 32 } } },
  } },
} } }
local evolutionBundle = assert(EvolutionAdapter.extract(evolution,
  evolutionContext))
check(evolutionBundle.model.kind == "animation"
  and evolutionBundle.model.animation.id == "cinematic.evolution"
  and evolutionBundle.model.animation.blackout == true
  and #evolutionBundle.model.animation.circles == 0
  and evolutionBundle.model.animation.sprites[1].path
    == "assets/generated/battle/front/cyndaquil.png",
  "evolution flash preserves blackout state and old species art")
evolution.phase = "reveal"
evolution.timer = 32
evolution.ballFrame = 12
evolution.blackout = false
evolution.showNew = true
evolution.balls = {{ angle = 4, radius = 32, age = 4, x = 8, y = -4 }}
local revealBundle = assert(EvolutionAdapter.extract(evolution,
  evolutionContext))
check(revealBundle.model.animation.sprites[1].path
  == "assets/generated/battle/front/quilava.png"
  and #revealBundle.model.animation.circles == 1
  and revealBundle.model.animation.circles[1].radius == 4 / 160,
  "evolution reveal emits the new species art and source light circle")

local introClass = classFor(catalog.byId.Gen2GoldSilverIntro)
local introTiles = {}
for index = 1, 32 * 32 do introTiles[index] = 0 end
local introLines = {}
for index = 1, 144 do introLines[index] = 0 end
local goldIntro = setmetatable({ screenId = "Gen2GoldSilverIntro",
  scene = 2, frames = 48, done = false, act = "water", scx = 88, scy = 0,
  counter1 = 64, counter2 = 4, bgp = 0xe4, obp0 = 0xe4,
  lyActive = true, lyOverrides = introLines, bgmap = introTiles,
  bgPals = {{{0,0,0},{64,96,128},{160,192,224},{255,255,255}}},
  obPals = {}, anims = { oam = {} } }, introClass)
check(provider:inspect(goldIntro, {}).reason == "native_by_design",
  "Gold/Silver intro remains source-owned native")
local GoldSilverIntroAdapter = ctx.load("adapters.gold_silver_intro")
local introBundle = assert(GoldSilverIntroAdapter.extract(goldIntro, {
  game = { data = { gen2Intro = { water = {
    tiles = "assets/generated/intro/water_tiles.png",
    sprites = "assets/generated/intro/water_sprites.png",
  } } } },
}))
check(introBundle.model.kind == "animation"
  and introBundle.model.animation.id == "cinematic.gold_silver_intro"
  and introBundle.model.animation.tilemap.mapWidth == 32
  and #introBundle.model.animation.tilemap.tiles == 32 * 32
  and #introBundle.model.animation.tilemap.scanlineOffsets == 144,
  "Gold/Silver intro extracts its scrolling tilemap and scanline offsets")

local battleClass = classFor(catalog.byId.Gen2BattleState)
local battle = setmetatable({ screenId = "Gen2BattleState" }, battleClass)
check(provider:inspect(battle, {}).reason == "deferred",
  "incomplete battle remains explicitly deferred")
local validBattle = setmetatable({
  screenId = "Gen2BattleState", phase = "menu", battle = {},
}, battleClass)
check(provider:inspect(validBattle, {}).reason == "deferred",
  "battle remains explicitly deferred")
local transitionClass = classFor(catalog.byId.Gen2BattleTransition)
local validTransition = setmetatable({
  screenId = "Gen2BattleTransition", phase = "flash", style = "spin",
  frame = 4, step = 0, trainer = false, black = {},
}, transitionClass)
check(provider:inspect(validTransition, {}).reason == "deferred",
  "battle transition remains explicitly deferred")
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
  prepare = function() return { complete = true,
    model = { apiVersion = 3 } } end,
}) == true, "complete presenter registration")
check(provider:prepare(validMain, {}).reason == "presentation_model_not_v3"
    and provider:prepare(validMain, {}).suppress == false,
  "an incomplete V3 marker fails open before rendering")
check(provider:registerPresenter("Gen2MainMenu", {
  prepare = function() return { complete = true, model = {
    schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
    kind = "menu", preset = "M", rows = {
      { id = "continue", label = "CONTINUE" },
    }, selected = 1, scroll = 0,
  } } end,
}) == true, "canonical V3 presenter registration")
check(provider:prepare(validMain, {}).suppress == true,
  "only a canonical V3 prepared frame is suppressible")
check(provider:prepare(malformed, {}).suppress == false,
  "valid-to-invalid drift restores native immediately")

local proved, stackReason = provider:assessStack({ validMain, battle }, {})
check(proved == nil and stackReason == "deferred",
  "deferred battle keeps the complete visible stack native")

print(("Gen2 contract tests: %d checks passed"):format(checks))
