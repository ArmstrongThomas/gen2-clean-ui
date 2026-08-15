local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"),
  "GEN2_CLEAN_UI_ROOT is required"):gsub("\\", "/")

local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)
local Data = ctx.load("adapters.data")
local Catalog = ctx.load("contracts.catalog")
local Shared = ctx.load("contracts.shared")
local Gallery = ctx.load("gallery.catalog")
local PokegearGallery = ctx.load("presenters.pokegear_gallery_models")
local ServicesGallery = ctx.load(
  "presenters.services_commerce_gallery_models")
local MailGallery = ctx.load("presenters.mail_specialty_gallery_models")

local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, ("check %d failed: %s"):format(checks, message))
end

local function key(screenId, variant)
  return tostring(screenId) .. "\0" .. tostring(variant)
end

local source = {}
local groups = { PokegearGallery, ServicesGallery, MailGallery }
for _, module in ipairs(groups) do
  for _, fixture in ipairs(module.galleryFixtures()) do
    source[#source + 1] = fixture
  end
end

check(#source == 59, "all 0.3 Gallery fixtures are exported")
check(Data.isFunctionFree(source), "0.3 Gallery fixtures are function-free")

local gallery = Gallery.build(Catalog.build(), Shared.build(), source)
local byKey, ready, status = {}, 0, 0
for _, fixture in ipairs(gallery.fixtures) do
  byKey[key(fixture.screenId, fixture.variant)] = fixture
end

for _, fixture in ipairs(source) do
  local product = byKey[key(fixture.screenId, fixture.variant)]
  check(product ~= nil,
    "product Gallery contains " .. fixture.screenId .. "." .. fixture.variant)
  if type(fixture.model) == "table" and fixture.expectedNative ~= true then
    ready = ready + 1
    check(product.modelReady == true and product.statusOnly == false,
      "integrated 0.3 fixture is model-ready " .. fixture.screenId .. "."
        .. fixture.variant)
    check(product.sourceModel ~= nil and product.model ~= nil
      and product.sourceModel.screenId == fixture.screenId
      and (product.model.kind == "menu"
        or product.model.kind == "device" or product.model.kind == "map")
      and Data.isFunctionFree(product.model),
      "integrated 0.3 fixture uses a production presentation "
        .. fixture.screenId .. "." .. fixture.variant)
  else
    status = status + 1
    check(product.modelReady == false and product.statusOnly == true,
      "incomplete 0.3 fixture remains Gallery status-only "
        .. fixture.screenId .. "." .. fixture.variant)
    check(product.nativeCode == fixture.nativeCode
      and product.nativeReason == fixture.nativeDetail,
      "native 0.3 fixture keeps its exact reason "
        .. fixture.screenId .. "." .. fixture.variant)
  end
end

check(ready == 46 and status == 13,
  ("0.3 Gallery has 46 production fixtures and 13 explicit native statuses "
    .. "(ready=%d status=%d)"):format(ready, status))
print(("Gen2 integrated 0.3 Gallery: %d checks passed"):format(checks))
