local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"),
  "GEN2_CLEAN_UI_ROOT is required")
root = root:gsub("\\", "/")

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

local MenuRender = loadCore("presentation.menu_render")
local PresentationRuntime = loadCore("presentation.runtime")
local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, ("check %d failed: %s"):format(checks, message))
end

local originalNewImage = assert(love and love.graphics
  and love.graphics.newImage, "LÖVE graphics.newImage is required")
local loadedPaths = {}
local filterCalls = 0
local draws = {}
local fakeImage = {
  getWidth = function() return 56 end,
  getHeight = function() return 56 end,
  setFilter = function() filterCalls = filterCalls + 1 end,
}
local fakeGraphics = {
  setColor = function() end,
  draw = function(...) draws[#draws + 1] = {...} end,
  newQuad = function(x, y, w, h, iw, ih)
    return { x=x, y=y, w=w, h=h, iw=iw, ih=ih }
  end,
  getShader = function() return nil end,
  setShader = function() end,
}

local ok, testError = xpcall(function()
  love.graphics.newImage = function(path)
    loadedPaths[#loadedPaths + 1] = path
    return fakeImage
  end

  PresentationRuntime.new({
    mod = { ui = {} },
    provider = {},
    config = {},
    setting = function() return nil end,
  })

  local frontPath = "assets/generated/battle/front/totodile.png"
  local backPath = "assets/generated/battle/back/totodile.png"
  local rect = { x=0, y=0, w=112, h=112 }
  local frontOk, frontCode = MenuRender.drawSprite(fakeGraphics,
    { path=frontPath }, rect)
  local backOk, backCode = MenuRender.drawSprite(fakeGraphics,
    { path=backPath }, rect)
  check(frontOk == true and frontCode == nil,
    "v0.1.86 fallback loads a Party/front generated sprite")
  check(backOk == true and backCode == nil,
    "v0.1.86 fallback loads a Battle/back generated sprite")
  check(loadedPaths[1] == frontPath and loadedPaths[2] == backPath,
    "fallback forwards only the declared generated sprite paths")
  check(draws[1] ~= nil and math.abs(56 * draws[1][5] - 112) < 0.0001
      and math.abs(56 * draws[1][6] - 112) < 0.0001,
    "magnified sprites use a whole-pixel scale factor")
  check(filterCalls == 2,
    "every loaded sprite enables nearest-neighbor filtering")

  local cropOk, cropCode = MenuRender.drawSprite(fakeGraphics, {
    path=frontPath, crop={ x=0, y=0, w=16, h=16 },
  }, { x=1.4, y=2.6, w=10.4, h=10.4 })
  local cropDraw = draws[#draws]
  check(cropOk == true and cropCode == nil and cropDraw ~= nil,
    "cropped sprites render through the shared image path")
  check(cropDraw[3] == 3 and cropDraw[4] == 4,
    "cropped sprites snap their destination origin to pixel boundaries")
  check(math.abs(16 * cropDraw[6] - 8) < 0.0001
      and math.abs(16 * cropDraw[7] - 8) < 0.0001,
    "cropped sprites use exact reciprocal reduction without mixels")

  for _, invalidPath in ipairs({
    "assets/generated/../secret.png",
    "assets/generated/battle/front/totodile.jpg",
    "assets/generated\\battle\\front\\totodile.png",
    "C:/assets/generated/battle/front/totodile.png",
    "assets/pokemon/totodile.png",
  }) do
    local before = #loadedPaths
    local spriteOk, code = MenuRender.drawSprite(fakeGraphics,
      { path=invalidPath }, rect)
    check(spriteOk == nil and code == "sprite_image_unavailable",
      "fallback rejects unsafe or out-of-namespace path: " .. invalidPath)
    check(#loadedPaths == before,
      "rejected path never reaches love.graphics.newImage: " .. invalidPath)
  end
end, debug.traceback)

love.graphics.newImage = originalNewImage
MenuRender.setSourceImageLoader(nil)
assert(ok, testError)
print(("Gen2 v0.1.86 sprite fallback: %d checks passed"):format(checks))
