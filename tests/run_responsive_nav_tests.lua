local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"),
  "GEN2_CLEAN_UI_ROOT is required")
root = root:gsub("\\", "/")

local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)
local Data = ctx.load("adapters.data")
local MainMenu = ctx.load("adapters.main_menu")
local StartMenu = ctx.load("adapters.start_menu")
local FoundationPresenters = ctx.load("presenters.foundation_presenters")

local vendorRoot = root .. "/mods/gen2_clean_ui/vendor/clean_ui_core"
local coreCache = {}
local function loadCore(name)
  if coreCache[name] ~= nil then return coreCache[name] end
  local path = vendorRoot .. "/" .. name:gsub("%.", "/") .. ".lua"
  local chunk, loadError = loadfile(path)
  assert(chunk, loadError)
  local exported = chunk(loadCore)
  coreCache[name] = exported
  return exported
end

local Solver = loadCore("layout.solver")
local MenuLayout = loadCore("presentation.menu_layout")
local PresentationRuntime = loadCore("presentation.runtime")
local FontCatalog = loadCore("text.font_catalog")

local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, ("check %d failed: %s"):format(checks, message))
end

local sourceState = {
  screenId = "Gen2StartMenu",
  save = { player = { name = "KRIS" } },
  items = {
    { label = "POKEMON", value = "pokemon" },
    { label = "PACK", value = "pack" },
    { label = "POKEGEAR", value = "pokegear" },
  },
  showDescription = false,
  list = { items = {}, index = 1, scroll = 0 },
}
sourceState.list.items = sourceState.items
local sourceBundle = assert(StartMenu.extract(sourceState))
local shortModel = assert(FoundationPresenters.convert(
  "Gen2StartMenu", sourceBundle.model))
local mainBundle = assert(MainMenu.extract({
  screenId="Gen2MainMenu", hasSave=true, phase="menu",
  save={ player={name="KRIS", badges={ZEPHYR=true}},
    pokedex={caught={CYNDAQUIL=true}}, playTime={hours=12,minutes=34},
    position={map="NEW BARK TOWN"} },
  clock={hour=14, minute=8, weekday=4},
  list={ index=1, scroll=0, items={
    {label="CONTINUE", value="continue"},
    {label="NEW GAME", value="new"},
    {label="OPTION", value="option"},
    {label="EXIT GAME", value="exit"},
  }},
}))
local mainModel = assert(FoundationPresenters.convert(
  "Gen2MainMenu", mainBundle.model))
local overflowModel = Data.copy(shortModel)
overflowModel.rows = {}
for index = 1, 24 do
  overflowModel.rows[index] = {
    id = "overflow." .. index,
    label = (index == 1 and string.rep("LONG LABEL ", 8)
      or "ROW " .. index),
    right = index % 2 == 0 and "PINNED" or "",
    pinnable = index % 2 == 0,
  }
end

check(shortModel.kind == "menu" and shortModel.preset == "NAV",
  "responsive test uses the real Gen2 Start Menu production presenter")
check(MenuLayout.contentWidth({ preset="NAV", scale=1, minW=320,
  widthMode="content", logical={ w=440, h=560 } }, shortModel,
  { getHeight=function() return 15 end,
    getWidth=function(_, value) return #tostring(value or "") * 8 end },
  "comfortable") == 320,
  "short production Start Menu uses the compact NAV width")
check(MenuLayout.contentWidth({ preset="NAV", scale=1, minW=320,
  widthMode="content", logical={ w=440, h=560 } }, overflowModel,
  { getHeight=function() return 15 end,
    getWidth=function(_, value) return #tostring(value or "") * 8 end },
  "comfortable") == 440,
  "content that requires it can use the full NAV width")

local fallbackSteps = {}
local fallbackResult = Solver.solve({
  preset="NAV", viewport={x=0,y=0,w=1280,h=720},
  safeArea={x=0,y=0,w=1280,h=720}, uiSize="auto",
  textSize="3", fontFamily="openttd_mono", density="comfortable",
  probe=function(_, candidate)
    fallbackSteps[#fallbackSteps + 1] = candidate.step
    return candidate.step == 1
  end,
})
check(fallbackResult.ok and fallbackResult.value.font.step == 1,
  "shared solver falls back to the next fitting font step")
check(table.concat(fallbackSteps, ",") == "3,2,1",
  "shared solver probes every lower font step in descending order")

local catalogGraphics = {}
function catalogGraphics.newFont(path, size)
  local font = { path=path, size=size }
  function font:getWidth(value)
    return #tostring(value or "") * self.size * 0.5
  end
  function font:getHeight() return self.size end
  function font:setFilter() end
  return font
end
local catalog = FontCatalog.new(catalogGraphics, {
  openttdMono="assets/fonts/openttd-mono/otm.ttf",
})
local mixedPolicy = { family="openttd_mono", step=3, physicalPx=30 }
local shortRun = catalog:fit(mixedPolicy, "POKEMON", 120)
local longRun = catalog:fit(mixedPolicy, "Party Pokemon status", 120)
check(shortRun and longRun and shortRun.font ~= longRun.font,
  "per-run catalog fitting keeps multiple font faces available")
check(shortRun.policy.step == 3,
  "short text keeps the frame's solved/base font step")
check(longRun.policy.step == 1,
  "only the long constrained text steps down")
check(mixedPolicy.step == 3,
  "per-run fitting does not mutate the shared frame policy")

local viewports = {
  { 320, 180 }, { 640, 360 }, { 360, 640 }, { 390, 844 },
  { 1024, 768 }, { 1280, 720 }, { 1280, 1024 }, { 1600, 1000 },
  { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
  { 3840, 2160 }, { 5120, 2784 },
}
local uiSizes = { "auto", "small", "medium", "large" }
local textSizes = { "auto", "1", "2", "3" }
local fonts = { "openttd_mono", "plain_pixel", "system" }
local densities = { "auto", "comfortable", "compact" }

local function fakeFont(layout)
  local height = layout.font.physicalPx
  local base = layout.font.family == "openttd_mono" and 10 or 15
  local step = height / base
  return {
    getHeight = function() return height end,
    getWidth = function(_, value) return #tostring(value or "") * 8 * step end,
  }
end

local function solve(model, viewport, safeArea, uiSize, textSize, font, density)
  local request = {
    preset = model.preset, viewport = viewport, safeArea = safeArea,
    uiSize = uiSize, textSize = textSize, fontFamily = font,
    density = density,
  }
  local baseResult = Solver.solve(request)
  check(baseResult.ok, "base NAV matrix layout solves")
  local base = baseResult.value
  local width = MenuLayout.contentWidth(base, model, fakeFont(base), density)
  check(width >= 320 and width <= 440,
    "NAV width remains inside the adaptive logical bounds")
  request.logicalWidth = width
  local narrowedResult = Solver.solve(request)
  check(narrowedResult.ok, "narrowed NAV matrix layout solves")
  local narrowed = narrowedResult.value
  check(narrowed.logical.h == 560 and base.logical.h == 560,
    "adaptive width preserves the full NAV logical height")
  check(narrowed.outer.h == base.outer.h,
    "adaptive width never shortens the physical menu height")
  check(narrowed.outer.w <= base.outer.w,
    "adaptive width never exceeds the fixed NAV maximum")
  check(narrowed.outer.x >= safeArea.x
      and narrowed.outer.y >= safeArea.y
      and narrowed.outer.x + narrowed.outer.w <= safeArea.x + safeArea.w
      and narrowed.outer.y + narrowed.outer.h <= safeArea.y + safeArea.h,
    "adaptive NAV remains inside the safe area")
  if font == "plain_pixel" then
    check(({ [15]=true, [30]=true, [45]=true, [60]=true })
      [narrowed.font.physicalPx] == true,
      "Plain Pixel responsive matrix keeps authored whole steps")
  end
end

local function solveM(model, viewport, safeArea, uiSize, textSize, font, density)
  local request = {
    preset = model.preset, viewport = viewport, safeArea = safeArea,
    uiSize = uiSize, textSize = textSize, fontFamily = font,
    density = density,
  }
  local baseResult = Solver.solve(request)
  check(baseResult.ok, "base M matrix layout solves")
  local base = baseResult.value
  local width = MenuLayout.contentWidth(base, model, fakeFont(base), density)
  check(width >= 320 and width <= 600,
    "M width remains inside the adaptive logical bounds")
  request.logicalWidth = width
  local narrowedResult = Solver.solve(request)
  check(narrowedResult.ok, "narrowed M matrix layout solves")
  local narrowed = narrowedResult.value
  check(narrowed.logical.h == 420 and base.logical.h == 420,
    "adaptive M width preserves the full logical height")
  check(narrowed.outer.h == base.outer.h,
    "adaptive M width never shortens the physical menu height")
  check(narrowed.outer.w <= base.outer.w,
    "adaptive M width never exceeds the fixed M maximum")
  check(narrowed.outer.x >= safeArea.x
      and narrowed.outer.y >= safeArea.y
      and narrowed.outer.x + narrowed.outer.w <= safeArea.x + safeArea.w
      and narrowed.outer.y + narrowed.outer.h <= safeArea.y + safeArea.h,
    "adaptive M remains inside the safe area")
end

for _, dimensions in ipairs(viewports) do
  local width, height = dimensions[1], dimensions[2]
  local viewport = { x=0, y=0, w=width, h=height }
  local inset = math.max(0, math.floor(math.min(width, height) * 0.03))
  local safeArea = { x=inset, y=inset, w=math.max(1, width - inset * 2),
    h=math.max(1, height - inset * 2) }
  for _, uiSize in ipairs(uiSizes) do
    for _, textSize in ipairs(textSizes) do
      for _, font in ipairs(fonts) do
        for _, density in ipairs(densities) do
          solve(shortModel, viewport, safeArea, uiSize, textSize, font, density)
          solve(overflowModel, viewport, safeArea, uiSize, textSize, font, density)
          solveM(mainModel, viewport, safeArea, uiSize, textSize, font, density)
        end
      end
    end
  end
end

local optionValues = {
  ui_size = "auto", text_size = "auto", font = "openttd_mono",
}
local runtime = PresentationRuntime.new({
  config = {}, provider = {},
  mod = { options = { get = function(_, key) return optionValues[key] end } },
  setting = function(_, key) return optionValues[key] end,
})
local stateToken = {}
local baseResult = Solver.solve({ preset="NAV",
  viewport={x=0,y=0,w=1280,h=720}, safeArea={x=0,y=0,w=1280,h=720},
  uiSize="auto", textSize="auto" })
local base = assert(baseResult.value)
local font = fakeFont(base)
local first = runtime:lockedMenuWidth(stateToken, base, shortModel, font,
  "comfortable", base.viewport, base.safeArea)
local second = runtime:lockedMenuWidth(stateToken, base, overflowModel, font,
  "comfortable", base.viewport, base.safeArea)
check(first == 320 and second == first,
  "production presentation locks NAV width across row changes")

local mBase = assert(Solver.solve({ preset="M", viewport={x=0,y=0,w=1280,h=720},
  safeArea={x=0,y=0,w=1280,h=720}, uiSize="auto", textSize="auto" })).value
local mFont = fakeFont(mBase)
local mToken = {}
local mFirst = runtime:lockedMenuWidth(mToken, mBase, mainModel, mFont,
  "comfortable", mBase.viewport, mBase.safeArea)
local mLong = Data.copy(mainModel)
mLong.rows = {}
for index = 1, 24 do
  mLong.rows[index] = { id="m.row." .. index,
    label=(index == 1 and string.rep("LONG LABEL ", 8) or "ROW " .. index),
    right=index % 2 == 0 and "PINNED" or "" }
end
local mSecond = runtime:lockedMenuWidth(mToken, mBase, mLong, mFont,
  "comfortable", mBase.viewport, mBase.safeArea)
check(mFirst < 600 and mSecond == mFirst,
  "production presentation locks M width across row changes")

print(("Gen2 responsive NAV/M matrix: %d checks passed"):format(checks))
