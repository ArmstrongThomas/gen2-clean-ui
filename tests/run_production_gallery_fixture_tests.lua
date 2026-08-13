local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"),
  "GEN2_CLEAN_UI_ROOT is required")
root = root:gsub("\\", "/")

local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)
local Data = ctx.load("adapters.data")
local Catalog = ctx.load("contracts.catalog")
local Shared = ctx.load("contracts.shared")
local Gallery = ctx.load("gallery.catalog")
local Models = ctx.load("presenters.production_gallery_models")
local PartyPresenters = ctx.load("presenters.party_presenters")
local PackPresenter = ctx.load("presenters.pack")
local PokedexPresenter = ctx.load("presenters.pokedex")
local TrainerCardPresenter = ctx.load("presenters.trainer_card")
local SaveMenuPresenter = ctx.load("presenters.save_menu")
local NamingStoragePresenters = ctx.load(
  "presenters.naming_storage_presenters")

local TARGETS = {
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

local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, ("check %d failed: %s"):format(checks, message))
end

local function key(screenId, variant)
  return tostring(screenId) .. "\0" .. tostring(variant)
end

local function deepEqual(left, right, active)
  if type(left) ~= type(right) then return false end
  if type(left) ~= "table" then return left == right end
  if getmetatable(left) ~= nil or getmetatable(right) ~= nil then return false end
  active = active or {}
  active[left] = active[left] or {}
  if active[left][right] then return true end
  active[left][right] = true
  local count = 0
  for itemKey, value in next, left do
    count = count + 1
    if not deepEqual(value, right[itemKey], active) then return false end
  end
  local rightCount = 0
  for _ in next, right do rightCount = rightCount + 1 end
  return count == rightCount
end

local function convert(screenId, sourceModel)
  if screenId == "Gen2PartyMenu" or screenId == "Gen2SummaryMenu" then
    return PartyPresenters.convert(screenId, sourceModel)
  elseif screenId == "Gen2PackMenu" then
    return PackPresenter.convert(sourceModel)
  elseif screenId == "Gen2PokedexMenu" then
    return PokedexPresenter.convert(sourceModel)
  elseif screenId == "Gen2TrainerCard" then
    return TrainerCardPresenter.convert(sourceModel)
  elseif screenId == "Gen2SaveMenu" then
    return SaveMenuPresenter.convert(sourceModel)
  end
  return NamingStoragePresenters.convert(screenId, sourceModel)
end

local catalog = Catalog.build()
local shared = Shared.build()
local sourceFixtures = Models.galleryFixtures()
local expected = {}
local expectedCount = 0

check(Models.count() == 47, "the requested production fixture set has 47 variants")
check(#sourceFixtures == 47, "all production source fixtures are exported")
check(Data.isFunctionFree(sourceFixtures),
  "the complete synthetic source-fixture collection is function-free")

local targetIds = {}
for _, screenId in ipairs(TARGETS) do
  targetIds[screenId] = true
  local record = assert(catalog.byId[screenId], "missing target " .. screenId)
  check(record.support == "supported", screenId .. " is production-supported")
  local moduleVariants = Models.variantsFor(screenId)
  check(deepEqual(moduleVariants, record.gallery),
    screenId .. " synthetic variants exactly match its Gallery contract")
  for _, variant in ipairs(record.gallery) do
    expected[key(screenId, variant)] = true
    expectedCount = expectedCount + 1
  end
end
check(expectedCount == 47, "contract-derived production variant count")

local sourceByKey = {}
for _, fixture in ipairs(sourceFixtures) do
  local fixtureKey = key(fixture.screenId, fixture.variant)
  check(targetIds[fixture.screenId] == true,
    "source fixture belongs to a requested production screen")
  check(expected[fixtureKey] == true,
    "source fixture maps to a declared production variant " .. fixtureKey)
  check(sourceByKey[fixtureKey] == nil,
    "source fixture key is unique " .. fixtureKey)
  check(type(fixture.model) == "table"
      and fixture.model.screenId == fixture.screenId,
    "source fixture has the exact presenter-source screen ID " .. fixtureKey)
  check(fixture.model.schema == "clean_ui.presenter_model.v1",
    "source fixture uses the production presenter-model schema " .. fixtureKey)
  check(Data.isFunctionFree(fixture),
    "source fixture contains no functions, userdata, threads, or metatables "
      .. fixtureKey)
  check(rawget(fixture, "state") == nil and rawget(fixture, "actions") == nil,
    "source fixture does not construct a live screen or carry callbacks "
      .. fixtureKey)
  sourceByKey[fixtureKey] = fixture
end

local gallery = Gallery.build(catalog, shared, sourceFixtures)
local galleryByKey = {}
local readyCount = 0
for _, fixture in ipairs(gallery.fixtures) do
  if targetIds[fixture.screenId] then
    local fixtureKey = key(fixture.screenId, fixture.variant)
    check(galleryByKey[fixtureKey] == nil,
      "Gallery production fixture key is unique " .. fixtureKey)
    galleryByKey[fixtureKey] = fixture
    check(fixture.synthetic == true and fixture.modelReady == true
        and fixture.statusOnly == false,
      "Gallery production fixture is model-ready " .. fixtureKey)
    check(Data.isFunctionFree(fixture.sourceModel),
      "Gallery source snapshot remains function-free " .. fixtureKey)
    check(Data.isFunctionFree(fixture.model),
      "converted production presentation remains function-free " .. fixtureKey)
    check(Data.isFunctionFree(fixture),
      "complete Gallery production fixture remains function-free " .. fixtureKey)

    local converted, code, detail = convert(fixture.screenId,
      fixture.sourceModel)
    check(type(converted) == "table",
      ("production converter accepts %s: %s %s"):format(
        fixtureKey, tostring(code), tostring(detail)))
    check(deepEqual(converted, fixture.model),
      "Gallery uses the exact existing production converter result "
        .. fixtureKey)
    readyCount = readyCount + 1
  end
end

check(readyCount == 47,
  "every requested production screen variant is Gallery model-ready")
for fixtureKey in pairs(expected) do
  check(sourceByKey[fixtureKey] ~= nil,
    "source fixture covers declared production variant " .. fixtureKey)
  check(galleryByKey[fixtureKey] ~= nil,
    "Gallery covers declared production variant " .. fixtureKey)
end

print(("Gen2 production Gallery fixtures: %d checks passed"):format(checks))

