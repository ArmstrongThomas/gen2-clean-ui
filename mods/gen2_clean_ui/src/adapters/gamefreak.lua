return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.specialty_common")
  local GameFreak = {}

  local SCREEN_W, SCREEN_H = 160, 144
  local TILE = 8
  local OAM_XFLIP, OAM_YFLIP = 0x20, 0x40
  local DEFAULT_PATHS = {
    presents = "assets/generated/splash/presents.png",
    logo = "assets/generated/splash/logo.png",
    star = "assets/generated/splash/star.png",
    sparkle = "assets/generated/splash/sparkle.png",
  }
  local DEFAULT_OB = {
    {255,255,255}, {255,255,255}, {206,247,0}, {206,247,0},
  }
  local DEFAULT_BG = {
    {0,0,0}, {66,90,90}, {173,173,173}, {255,255,255},
  }

  local function imagePath(value, fallback)
    if type(value) == "table" then value = rawget(value, "path") end
    return Common.generatedPath(value) or fallback
  end

  local function generated(state, context)
    local game = context and rawget(context, "game")
    game = type(game) == "table" and game or rawget(state, "game")
    if type(game) == "table" then
      local oak = rawget(game, "oakSpeechData")
      if type(oak) == "table" then return oak end
      local data = rawget(game, "data")
      if type(data) == "table" then
        oak = rawget(data, "gen2OakSpeech")
        if type(oak) == "table" then return oak end
      end
    end
    local supplied = rawget(state, "oakSpeech")
    if type(supplied) == "table" then return supplied end
    return rawget(state, "gfx") or {}
  end

  local function splashData(state, context)
    local data = generated(state, context)
    local splash = type(data) == "table" and rawget(data, "splash")
    return type(splash) == "table" and splash or data
  end

  local function palette(value, fallback)
    return Common.palette(value) or fallback
  end

  local function normalizedColor(value)
    if type(value) ~= "table" then return nil end
    local output = {}
    for index = 1, 3 do
      local channel = tonumber(value[index])
      if not channel then return nil end
      output[index] = math.max(0, math.min(1, channel / 255))
    end
    output[4] = 1
    return output
  end

  local function permute(colors, byte)
    local output = {}
    byte = Common.integer(byte, 0, 255) or 0
    for index = 0, 3 do
      output[index + 1] = colors[math.floor(byte / (4 ^ index)) % 4 + 1]
        or colors[1]
    end
    return output
  end

  local function overlay(color)
    return { x=0, y=0, w=1, h=1, color=normalizedColor(color) }
  end

  local function sheetFor(splash, tile)
    local sheets = {
      { first=0x80, last=0x8c, wide=13,
        path=imagePath(rawget(splash, "presents"), DEFAULT_PATHS.presents) },
      { first=0x8d, last=0x9b, wide=3,
        path=imagePath(rawget(splash, "logo"), DEFAULT_PATHS.logo) },
      { first=0x9c, last=0x9d, wide=1,
        path=imagePath(rawget(splash, "star"), DEFAULT_PATHS.star) },
      { first=0x9e, last=0xa0, wide=3,
        path=imagePath(rawget(splash, "sparkle"), DEFAULT_PATHS.sparkle) },
    }
    for _, sheet in ipairs(sheets) do
      if tile >= sheet.first and tile <= sheet.last then
        local index = tile - sheet.first
        return sheet.path, {
          x=(index % sheet.wide) * TILE,
          y=math.floor(index / sheet.wide) * TILE,
          w=TILE, h=TILE,
        }
      end
    end
    return nil
  end

  local function sprite(path, x, y, paletteValue, crop, flipX, flipY)
    return {
      path=path,
      normalized=true,
      rect={x=x / SCREEN_W, y=y / SCREEN_H,
        w=TILE / SCREEN_W, h=TILE / SCREEN_H},
      crop=crop,
      palette=paletteValue,
      flipX=flipX == true,
      flipY=flipY == true,
    }
  end

  local function tileSprites(splash, tiles, bgPalette)
    local output = {}
    if type(tiles) ~= "table" then return output end
    -- The source tilemap is sparse, but its logical BG is still a 20x18
    -- screen. Numeric iteration gives Gallery and runtime models a stable
    -- painter order instead of depending on Lua's table traversal order.
    for ty = 0, 17 do
      local row = rawget(tiles, ty)
      if type(row) == "table" then
        for tx = 0, 19 do
          local tile = rawget(row, tx)
          if type(tile) == "number" and tile == math.floor(tile) then
            local path, crop = sheetFor(splash, tile)
            if path then
              output[#output + 1] = sprite(path, tx * TILE, ty * TILE,
                bgPalette, crop)
            end
          end
        end
      end
    end
    return output
  end

  local function objectSprites(splash, anims, obPalette, obp1)
    local output = {}
    local oam = type(anims) == "table" and rawget(anims, "oam")
    if type(oam) ~= "table" then return output end
    -- GameFreakPresents draws the shadow OAM backwards. Preserve that order:
    -- the first source object is the topmost one when sprites overlap.
    for index = #oam, 1, -1 do
      local entry = rawget(oam, index)
      if type(entry) == "table" then
        local tile = Common.integer(rawget(entry, "tile"), 0, 255)
        local x = Common.integer(rawget(entry, "x"), 0, 255)
        local y = Common.integer(rawget(entry, "y"), 0, 255)
        local attr = Common.integer(rawget(entry, "attr"), 0, 255)
        local path, crop
        if tile then path, crop = sheetFor(splash, tile) end
        if path and x and y and attr then
          local isLogo = attr % 8 == 1
          output[#output + 1] = sprite(path, x - TILE, y - 2 * TILE,
            permute(obPalette, isLogo and obp1 or 0xf8), crop,
            math.floor(attr / OAM_XFLIP) % 2 == 1,
            math.floor(attr / OAM_YFLIP) % 2 == 1)
        end
      end
    end
    return output
  end

  local function animationModel(state, context)
    local splash = splashData(state, context)
    local obPalette = palette(rawget(splash, "obPalette"), DEFAULT_OB)
    local bgPalette = palette(rawget(splash, "bgPalette"), DEFAULT_BG)
    local sprites = tileSprites(splash, rawget(state, "tiles"), bgPalette)
    local obp1 = Data.integer(rawget(state, "obp1"), 0x24)
    local objects = objectSprites(splash, rawget(state, "anims"), obPalette,
      obp1)
    for _, item in ipairs(objects) do sprites[#sprites + 1] = item end
    local frame = Data.integer(rawget(state, "frames"), 0)
    local timer = Data.integer(rawget(state, "timer"), 0)
    local scene = Data.integer(rawget(state, "scene"), 0)
    return {
      schema="clean_ui.v3.presentation.v1", apiVersion=3,
      id="gamefreak_presents", kind="animation", preset="ANIMATION",
      title="GAME FREAK PRESENTS", opaque=true,
      animation={id="boot.gamefreak", overlay=true, frame=frame,
        duration=128, progress=(timer % 128) / 128,
        overlays={overlay(bgPalette[1])}, sprites=sprites,
      },
    }
  end

  function GameFreak.extract(state, context)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    if rawget(state, "done") == true then
      return Common.fail("state_done", "gamefreak presents")
    end
    return { model=animationModel(state, context), actions={} }
  end

  return GameFreak
end
