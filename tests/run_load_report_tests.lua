local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"),
  "GEN2_CLEAN_UI_ROOT is required")
root = root:gsub("\\\\", "/")

local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)
local MainMenu = ctx.load("adapters.main_menu")
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

local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, ("check %d failed: %s"):format(checks, message))
end

local bundle = assert(MainMenu.extract({
  screenId = "Gen2MainMenu",
  hasSave = true,
  phase = "confirm",
  confirmDelay = 0,
  save = {
    player = { name = "TOMMY", badges = { ZEPHYR = true } },
    pokedex = { caught = { [1] = true, [4] = true, [7] = true,
      [10] = true, [25] = true } },
    playTime = { hours = 0, minutes = 42 },
  },
  list = { index = 1, scroll = 0, items = {
    { label = "CONTINUE", value = "continue" },
    { label = "NEW GAME", value = "new" },
    { label = "OPTION", value = "option" },
    { label = "EXIT GAME", value = "exit" },
  } },
}))
local model = assert(FoundationPresenters.convert("Gen2MainMenu", bundle.model))
check(model.title == "CONTINUE", "confirm report retains its Clean title")
check(model.rows[1].label == "CONTINUE", "confirm report retains its action row")
check(#model.details == 4 and model.details[1].value == "TOMMY",
  "confirm report exposes the four save fields")

local function fakeFont(candidate)
  local height = candidate.physicalPx
  local width = candidate.family == "openttd_mono"
    and height * 0.58 or height * 0.55
  return {
    getHeight = function() return height end,
    getWidth = function(_, value) return #tostring(value or "") * width end,
  }
end

local request = {
  preset = "M",
  viewport = { x = 0, y = 0, w = 2052, h = 1598 },
  safeArea = { x = 0, y = 0, w = 2052, h = 1598 },
  uiSize = "auto",
  textSize = "auto",
  fontFamily = "openttd_mono",
  density = "auto",
  probe = function(envelope, candidate, density)
    return MenuLayout.fits(envelope, model, fakeFont(candidate), density)
  end,
}
local solved = Solver.solve(request)
check(solved.ok, "confirm report fits the 5K-class viewport")
local font = fakeFont(solved.value.font)
local measured = MenuLayout.measure(solved.value, model, font, "auto")
check(measured and measured.detailRegion,
  "confirm report keeps a measured detail region")
check(MenuLayout.fits(solved.value, model, font, "auto"),
  "confirm report remains fit after the solved envelope is measured")

-- A previous persisted Plain Pixel selection must not make this screen fail
-- ownership when the optional host face is unavailable for one frame. The
-- runtime should keep the same step and resolve to bundled OpenTTD Mono.
local originalNewFont = love.graphics.newFont
local fakeFontOk, fakeFontError = xpcall(function()
  love.graphics.newFont = function(path, size)
    if path == "missing-plain-pixel.ttf" then
      error("optional Plain Pixel asset is unavailable")
    end
    local height = tonumber(size) or 15
    return {
      getHeight = function() return height end,
      getWidth = function(_, value)
        return #tostring(value or "") * height * 0.58
      end,
      setFilter = function() end,
    }
  end
  local runtime = PresentationRuntime.new({
    mod = { ui = {} }, provider = {}, config = {},
    fontPaths = {
      plainPixel = "missing-plain-pixel.ttf",
      openttdMono = "bundled-openttd-mono.ttf",
    },
    setting = function(_, key)
      local values = { ui_size="auto", text_size="auto",
        font="plain_pixel", density="auto" }
      return values[key]
    end,
  })
  local fallbackSolved = runtime:solveModel(model, {
    preset = "M", viewport = { x=0, y=0, w=2052, h=1598 },
    safeArea = { x=0, y=0, w=2052, h=1598 },
    uiSize = "auto", textSize = "auto", fontFamily = "plain_pixel",
    density = "auto",
  })
  check(fallbackSolved.ok, "load report survives an unavailable optional font")
  check(fallbackSolved.value.font.family == "openttd_mono",
    "load report uses the bundled font when Plain Pixel is unavailable")
end, debug.traceback)
love.graphics.newFont = originalNewFont
assert(fakeFontOk, fakeFontError)

print(("Gen2 load report tests: %d checks passed"):format(checks))
