return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.specialty_common")
  local Intro = {}

  local SCREEN_W, SCREEN_H = 160, 144
  local TILE = 8
  local OAM_XFLIP, OAM_YFLIP, OAM_PRIO = 0x20, 0x40, 0x80
  local BLACK = { {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0} }

  local function generated(value)
    return Common.generatedPath(value)
  end

  local function gameData(state, context)
    local game = context and rawget(context, "game")
    game = type(game) == "table" and game or rawget(state, "game")
    local data = type(game) == "table" and rawget(game, "data") or nil
    if type(data) == "table" then return data end
    local supplied = rawget(state, "data")
    return type(supplied) == "table" and supplied or {}
  end

  local function introData(state, context)
    local data = gameData(state, context)
    local intro = rawget(data, "gen2Intro")
    if type(intro) == "table" then return intro end
    intro = rawget(state, "intro")
    return type(intro) == "table" and intro or {}
  end

  local function finite(value, fallback)
    local number = tonumber(value)
    if not number or number ~= number
        or number == math.huge or number == -math.huge then
      return fallback
    end
    return number
  end

  local function registerPalette(value, register)
    local source = Common.palette(value) or BLACK
    local output = {}
    register = Common.integer(register, 0, 255) or 0xe4
    for index = 0, 3 do
      local slot = math.floor(register / (4 ^ index)) % 4
      output[index + 1] = source[slot + 1] or source[1]
    end
    return output
  end

  local function tileArray(value)
    if type(value) ~= "table" or #value ~= 32 * 32 then return nil end
    local output = {}
    for index = 1, #value do
      local tile = Common.integer(rawget(value, index), 0, 255)
      if tile == nil then return nil end
      output[index] = tile
    end
    return output
  end

  local function scanlineOffsets(state)
    if rawget(state, "lyActive") ~= true then return nil end
    local values = rawget(state, "lyOverrides")
    if type(values) ~= "table" or #values ~= SCREEN_H then return nil end
    local output = {}
    for line = 1, SCREEN_H do
      local value = finite(rawget(values, line))
      if value == nil then return nil end
      output[line] = { x=0, y=value }
    end
    return output
  end

  local function sprite(source, entry, palette)
    local tile = Common.integer(rawget(entry, "tile"), 0, 255)
    local x = Common.integer(rawget(entry, "x"), 0, 255)
    local y = Common.integer(rawget(entry, "y"), 0, 255)
    local attr = Common.integer(rawget(entry, "attr"), 0, 255)
    if not (tile and x and y and attr) then return nil end
    local path = generated(rawget(source, "sprites"))
    if not path then return nil end
    return {
      path=path, normalized=true,
      rect={x=(x - TILE) / SCREEN_W, y=(y - 2 * TILE) / SCREEN_H,
        w=TILE / SCREEN_W, h=TILE / SCREEN_H},
      crop={x=(tile % 16) * TILE, y=math.floor(tile / 16) * TILE,
        w=TILE, h=TILE},
      palette=palette,
      flipX=math.floor(attr / OAM_XFLIP) % 2 == 1,
      flipY=math.floor(attr / OAM_YFLIP) % 2 == 1,
    }, attr
  end

  local function objects(state, source)
    local anims = rawget(state, "anims")
    local oam = type(anims) == "table" and rawget(anims, "oam")
    local obPals = rawget(state, "obPals")
    local output, background = {}, {}
    if type(oam) ~= "table" then return output, background end
    for index = #oam, 1, -1 do
      local entry = rawget(oam, index)
      if type(entry) == "table" then
        local attr = Common.integer(rawget(entry, "attr"), 0, 255)
        local slot = attr and (attr % 8) + 1 or 1
        local palette = registerPalette(type(obPals) == "table"
          and rawget(obPals, slot), rawget(state, "obp0"))
        local item, actualAttr = sprite(source, entry, palette)
        if item and actualAttr then
          if actualAttr >= OAM_PRIO then
            background[#background + 1] = item
          else
            output[#output + 1] = item
          end
        end
      end
    end
    return output, background
  end

  function Intro.extract(state, context)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    if rawget(state, "done") == true then
      return Common.fail("state_done", "gold/silver intro")
    end
    local act = rawget(state, "act")
    local root = introData(state, context)
    local source = type(act) == "string" and rawget(root, act) or nil
    local path = type(source) == "table" and generated(rawget(source, "tiles"))
    local tiles = tileArray(rawget(state, "bgmap"))
    if not (source and path and tiles) then
      return Common.fail("asset_path_missing", "gold/silver intro tilemap")
    end
    local bgPalette = registerPalette(type(state.bgPals) == "table"
      and rawget(state.bgPals, 1), rawget(state, "bgp"))
    local front, behind = objects(state, source)
    local frame = Common.integer(rawget(state, "frames"), 0) or 0
    local tilemap = {
      path=path, tileWidth=TILE, tileHeight=TILE,
      mapWidth=32, mapHeight=32, sheetColumns=16, tiles=tiles,
      logicalWidth=SCREEN_W, logicalHeight=SCREEN_H,
      scrollX=rawget(state, "lyActive") == true and 0
        or (finite(rawget(state, "scx"), 0)),
      scrollY=rawget(state, "lyActive") == true and 0
        or (finite(rawget(state, "scy"), 0)),
      scanlineOffsets=scanlineOffsets(state), palette=bgPalette,
    }
    local color = bgPalette[1] or {0,0,0}
    local duration = 2335
    return { model={
      schema="clean_ui.v3.presentation.v1", apiVersion=3,
      id="gold_silver_intro", kind="animation", preset="ANIMATION",
      title="GOLD / SILVER INTRO", opaque=true,
      animation={id="cinematic.gold_silver_intro", overlay=true,
        phase=Data.id(rawget(state, "scene"), "movie"), frame=frame,
        duration=duration, progress=math.min(1, frame / duration),
        overlays={{x=0, y=0, w=1, h=1,
          color={color[1] / 255, color[2] / 255, color[3] / 255, 1}}},
        backgroundSprites=behind, tilemap=tilemap, sprites=front,
      },
    }, actions={} }
  end

  return Intro
end
