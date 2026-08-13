local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"),
  "GEN2_CLEAN_UI_ROOT is required"):gsub("\\", "/")

local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)
local Compatibility = ctx.load("compatibility.modern_api")

local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, ("check %d failed: %s"):format(checks, message))
end

local function newCanvas(width, height)
  if not (love and love.graphics and type(love.graphics.newCanvas) == "function") then
    return nil
  end
  local ok, canvas = pcall(love.graphics.newCanvas, width, height)
  return ok and canvas or nil
end

local active = {}
local mod = {
  find = function(owner) return active[owner] end,
}
local provider = {
  openGallery = function(_, filter) return { game="gen2", filter=filter } end,
}
local compatibility = Compatibility.new(mod, provider)
local api = compatibility:api()

check(api.version == 1 and api.compatibilityApiVersion == 1,
  "Modern v1 compatibility identity remains stable")
check(api.surfaceApiVersion == 2 and api.supportedApiVersions[2] == 2,
  "Modern v2 surface identity remains stable")
check(api.supports("data_screens", 1), "v1 data screens advertised")
check(api.supports("custom_surface", 2), "v2 custom surfaces advertised")
check(not api.supports("custom_surface", 1), "v2 capability is not advertised as v1")
check(not api.supports("unknown", 2), "unknown compatibility capability rejected")

active.legacy_source = { id="legacy_source", version="1.0.0", exports={} }
local actionPayload
local v1 = {
  apiVersion = 1,
  screens = {
    LegacyMenu = {
      match = function(state) return state.screenId == "LegacyMenu" end,
      model = function(_, state)
        return {
          title = "LEGACY MENU", rows = { "ONE", { label="TWO" } },
          index = state.index or 1, scroll = 0,
        }
      end,
      actions = {
        select = function(_, _, payload) actionPayload = payload return true end,
      },
      canSuppressNative = true,
    },
  },
  themes = {
    midnight = { name="Midnight", colors={ paper="#111111" } },
  },
  frames = { frame = { asset="assets/frame.png" } },
}
check(api.registerAdapter({ owner="legacy_source", contract=v1 }) == true,
  "v1 adapter registers through the unchanged public method")
local state = { screenId="LegacyMenu", index=2 }
local context = compatibility:adapterFor(nil, state)
check(context and context.id == "LegacyMenu", "v1 screen matching remains live")
local model = compatibility:modelFor(nil, state, context)
check(model and model.kind == "menu" and model.rows[1].label == "ONE",
  "v1 model is normalized into the Clean UI data model")
check(model.rows[2].sourceIndex == 2 and model.selected == 2,
  "v1 selection and source indices survive normalization")
local prepared = compatibility:prepareScreen(nil, state)
check(prepared.matched and prepared.result.presentation.kind == "legacy_screen",
  "v1 screen prepares through the product provider seam")
check(prepared.result.suppress == true, "v1 suppressible screen proves native replacement")
check(api.dispatchScreenAction(nil, state, "select", 2) == true
    and actionPayload == 2, "v1 semantic action remains source-owned")
check(compatibility.frames["legacy_source:frame"] == "assets/frame.png",
  "v1 frame assets remain namespaced")
check(compatibility.themes["legacy_source:midnight"].name == "Midnight",
  "v1 theme assets remain namespaced")

local invalidV1 = {
  apiVersion = 1,
  screens = { Bad = {
    match=function() return true end, model=function() return {} end,
    actions={search=function() end},
  } },
}
local rejected, reason = api.registerAdapter({ owner="legacy_source", contract=invalidV1 })
check(rejected == false and tostring(reason):find("unsupported semantic action", 1, true),
  "v1 rejects custom named screen actions")

active.surface_source = { id="surface_source", version="2.0.0", exports={} }
local surfaceAction
local v2 = {
  apiVersion = 2,
  surfaces = {
    Fixture = {
      match = function(state) return state.screenId == "SurfaceFixture" end,
      model = function() return { title="SURFACE", rows={ { label="GRID" } } } end,
      render = function() return true end,
      layout = { virtualWidth=320, virtualHeight=180, fit="contain",
        scaleMode="integer-fit", preset="VIEWPORT" },
      native = { policy="replace", scope="uiCanvas" },
      actions = { choose=function(_, _, payload) surfaceAction=payload return true end },
      gallery = { name="SURFACE FIXTURE", category="Integration" },
    },
  },
}
check(api.registerAdapter({ owner="surface_source", contract=v2 }) == true,
  "v2 custom surface registers through the unchanged public method")
local surfaceState = { screenId="SurfaceFixture" }
local surfaceContext = compatibility:surfaceFor(nil, surfaceState)
check(surfaceContext and surfaceContext.id == "Fixture",
  "v2 surface matching remains live")
local surfaceModel = compatibility:surfaceModelFor(nil, surfaceState, surfaceContext)
check(surfaceModel and surfaceModel.title == "SURFACE",
  "v2 surface model is data-only and detached")
local surfacePrepared = compatibility:prepareScreen(nil, surfaceState)
check(surfacePrepared.matched and surfacePrepared.surface
    and surfacePrepared.result.presentation.kind == "legacy_surface",
  "v2 surface prepares through the private-canvas seam")
check(surfacePrepared.result.suppress == true,
  "v2 replace policy proves native suppression")
local surfaceLayout = compatibility:layoutFor(v2.surfaces.Fixture,
  { w=640, h=360 }, { x=0, y=0, w=640, h=360 })
check(surfaceLayout.virtual.width == 320 and surfaceLayout.output.width == 640,
  "v2 contain layout resolves to the available safe viewport")
check(api.dispatchSurfaceAction(nil, surfaceState, "choose", { id="grid" }) == true
    and surfaceAction.id == "grid", "v2 named surface action remains source-owned")
local target = newCanvas(640, 360)
if target then
  local rendered, renderReason = compatibility:renderSurface(surfaceState,
    surfacePrepared.result.presentation, target, { w=640, h=360 },
    { x=0, y=0, w=640, h=360 }, { colors={} })
  check(rendered == true, "v2 surface commits a private canvas: " .. tostring(renderReason))
  check(compatibility.commits[surfaceState] ~= nil,
    "v2 surface commit records virtual layout and pointer regions")
else
  print("Gen2 Modern UI compatibility: surface render skipped without LÖVE canvas")
end
local gallery = api.uiGalleryCatalog()
check(#gallery == 1 and gallery[1].kind == "custom_surface",
  "v2 Gallery fixture remains discoverable")

active.failure_source = { id="failure_source", version="2.0.0", exports={} }
local failing = {
  apiVersion = 2,
  surfaces = { Failure = {
    match = function(state) return state.screenId == "FailSurface" end,
    model = function() return { title="FAIL" } end,
    render = function() return false end,
    layout = { virtualWidth=160, virtualHeight=90, fit="contain",
      scaleMode="integer-fit" },
    native = { policy="replace" },
  } },
}
check(api.registerAdapter({ owner="failure_source", contract=failing }) == true,
  "v2 failing surface fixture registers")
local failureTarget = newCanvas(320, 180)
if failureTarget then
  local failureState = { screenId="FailSurface" }
  local failurePrepared = compatibility:prepareScreen(nil, failureState)
  local failureRendered = compatibility:renderSurface(failureState,
    failurePrepared.result.presentation, failureTarget, { w=320, h=180 },
    { x=0, y=0, w=320, h=180 }, { colors={} })
  check(failureRendered == nil and compatibility.commits[failureState] == nil,
    "v2 render failure leaves native UI and no committed surface")
end
check(api.unregisterAdapter("failure_source") == true,
  "failing v2 fixture unregisters cleanly")

local invalidV2 = {
  apiVersion = 2,
  surfaces = { Bad = {
    match=function() return true end, model=function() return {} end,
    render=function() return true end,
    layout={ virtualWidth=320, virtualHeight=180, fit="cover" },
    native={ policy="replace" },
  } },
}
rejected, reason = api.registerAdapter({ owner="surface_source", contract=invalidV2 })
check(rejected == false and tostring(reason):find("layout.fit", 1, true),
  "v2 rejects unsupported surface fit modes")

check(api.unregisterAdapter("surface_source") == true,
  "v2 adapter unregisters cleanly")
check(compatibility:surfaceFor(nil, surfaceState) == nil,
  "unregistered v2 surface no longer matches")
check(api.unregisterAdapter("legacy_source") == true,
  "v1 adapter unregisters cleanly")

print(("Gen2 Modern UI compatibility: %d checks passed"):format(checks))
