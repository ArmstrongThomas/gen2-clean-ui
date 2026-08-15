return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.specialty_common")
  local EggHatch = {}

  local SCREEN_W, SCREEN_H = 160, 144
  local TILE = 8
  local EGG_X, EGG_Y = 7 * TILE, 4 * TILE
  local MON_X, MON_Y = 6 * TILE, 3 * TILE
  local OAM_X, OAM_Y = -8 - 4, -16 - 4
  local PIC_PAD = {
    [5] = { 1, 2 }, [6] = { 1, 1 }, [7] = { 0, 0 },
  }
  local DEFAULT_EGG = "assets/generated/battle/front/egg.png"
  local DEFAULT_SHELL = "assets/generated/menu/egg_hatch.png"
  local WHITE = { 255, 255, 255 }
  local BLACK = { 0, 0, 0 }

  local function generatedPath(value, fallback)
    if type(value) == "table" then value = rawget(value, "path") end
    return Common.generatedPath(value) or fallback
  end

  local function gameData(state, context)
    local game = context and rawget(context, "game")
    game = type(game) == "table" and game or rawget(state, "game")
    local data = type(game) == "table" and rawget(game, "data") or nil
    if type(data) == "table" then return data end
    local supplied = rawget(state, "data")
    return type(supplied) == "table" and supplied or {}
  end

  local function monRecord(state)
    local mon = rawget(state, "mon")
    return type(mon) == "table" and mon or {}
  end

  local function palette(palettes, species, shiny)
    local entry = type(palettes) == "table" and rawget(palettes, species)
    local pair = type(entry) == "table"
      and ((shiny and rawget(entry, "shiny")) or rawget(entry, "normal"))
      or nil
    if type(pair) ~= "table" or type(pair[1]) ~= "table"
        or type(pair[2]) ~= "table" then
      return nil
    end
    local function rgb(value)
      if type(value) ~= "table" then return nil end
      local output = {}
      for index = 1, 3 do
        local channel = tonumber(value[index])
        if not channel then return nil end
        output[index] = channel
      end
      return output
    end
    local light, dark = rgb(pair[1]), rgb(pair[2])
    if not (light and dark) then return nil end
    return { WHITE, light, dark, BLACK }
  end

  local function signed(value)
    value = tonumber(value) or 0
    return value > 0x7f and value - 0x100 or value
  end

  local function timeline(state)
    local beats = rawget(state, "beats")
    local index = Common.integer(rawget(state, "beatIndex"), 1) or 1
    local left = Common.integer(rawget(state, "beatLeft"), 0) or 0
    local total, elapsed = 0, 0
    if type(beats) == "table" then
      for beatIndex, beat in ipairs(beats) do
        local frames = type(beat) == "table"
          and Common.integer(rawget(beat, "frames"), 0) or 0
        total = total + (frames or 0)
        if beatIndex < index then
          elapsed = elapsed + (frames or 0)
        elseif beatIndex == index then
          elapsed = elapsed + math.max(0, (frames or 0) - left)
        end
      end
    end
    if total <= 0 then
      total = math.max(1, index)
      elapsed = math.max(0, math.min(total, index - 1))
    end
    return elapsed, total
  end

  local function sprite(path, x, y, w, h, crop, paletteValue,
      flipX, flipY)
    local output = {
      path=path, normalized=true,
      rect={x=x / SCREEN_W, y=y / SCREEN_H,
        w=w / SCREEN_W, h=h / SCREEN_H},
    }
    if crop then output.crop = crop end
    if paletteValue then output.palette = paletteValue end
    if flipX ~= nil then output.flipX = flipX == true end
    if flipY ~= nil then output.flipY = flipY == true end
    return output
  end

  local function paths(state, data)
    local entry = type(data.gen2MenuGfx) == "table"
      and rawget(data.gen2MenuGfx, "eggHatch") or {}
    local egg = generatedPath(rawget(state, "eggPath"), nil)
      or generatedPath(rawget(entry, "egg"), DEFAULT_EGG)
    local shell = generatedPath(rawget(state, "shellPath"), nil)
      or generatedPath(rawget(entry, "shell"), DEFAULT_SHELL)
    return egg, shell
  end

  local function picture(state, data, shake)
    local showMon = rawget(state, "showMon") == true
    local mon = monRecord(state)
    local species = Data.id(rawget(state, "species"),
      Data.id(rawget(mon, "species")))
    local path, width, height, paletteValue
    if showMon then
      local defs = type(data.pokemon) == "table" and data.pokemon or {}
      local def = species and rawget(defs, species) or nil
      path = generatedPath(type(def) == "table"
        and rawget(def, "spriteFront") or nil, nil)
      local tiles = type(def) == "table"
        and Common.integer(rawget(def, "picSize"), 5, 7) or 6
      width, height = (tiles or 6) * TILE, (tiles or 6) * TILE
      paletteValue = palette(data.gen2Palettes
        and rawget(data.gen2Palettes, "pokemon"), species,
        rawget(mon, "shiny") == true)
      local pad = PIC_PAD[tiles or 6] or PIC_PAD[6]
      if path then
        return sprite(path, MON_X + pad[1] * TILE + shake,
          MON_Y + pad[2] * TILE, width, height, nil, paletteValue), true
      end
      return nil, false
    end
    path = paths(state, data)
    width, height = 5 * TILE, 5 * TILE
    local eggPalette = palette(data.gen2Palettes
      and rawget(data.gen2Palettes, "pokemon"), "EGG",
      rawget(mon, "shiny") == true)
    return sprite(path, EGG_X + TILE + shake, EGG_Y + 2 * TILE,
      width, height, nil, eggPalette), path ~= nil
  end

  local function shellSprites(state, shellPath, shake)
    local output = {}
    local entries = rawget(state, "sprites")
    if type(entries) ~= "table" or not shellPath then return output end
    for _, entry in ipairs(entries) do
      if type(entry) == "table" then
        local kind = rawget(entry, "kind")
        local x = tonumber(rawget(entry, "x"))
        local y = tonumber(rawget(entry, "y"))
        if (kind == "crack" or kind == "fragment") and x and y then
          local dx = signed(rawget(entry, "xOffset"))
          local dy = signed(rawget(entry, "yOffset"))
          output[#output + 1] = sprite(shellPath,
            x + dx + OAM_X + shake, y + dy + OAM_Y,
            TILE, TILE,
            { x=0, y=(kind == "fragment" and TILE or 0), w=TILE, h=TILE },
            nil, rawget(entry, "flipX"), rawget(entry, "flipY"))
        end
      end
    end
    return output
  end

  function EggHatch.extract(state, context)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    if rawget(state, "done") == true then
      return Common.fail("state_done", "egg hatch")
    end
    local data = gameData(state, context)
    local egg, shell = paths(state, data)
    local shake = Common.integer(rawget(state, "shakeX"), -2, 2) or 0
    local pictureModel, hasPicture = picture(state, data, shake)
    if not hasPicture or not egg or not shell then
      return Common.fail("asset_path_missing", "egg hatch art")
    end
    local sprites = { pictureModel }
    for _, item in ipairs(shellSprites(state, shell, shake)) do
      sprites[#sprites + 1] = item
    end
    local frame, duration = timeline(state)
    return {
      model={
        schema="clean_ui.v3.presentation.v1", apiVersion=3,
        id="egg_hatch", kind="animation", preset="ANIMATION",
        title="EGG HATCH", opaque=true,
        animation={id="cinematic.egg_hatch", overlay=true,
          frame=frame, duration=duration, progress=frame / duration,
          overlays={{ x=0, y=0, w=1, h=1, color={1,1,1,1} }},
          sprites=sprites,
        },
      },
      actions={},
    }
  end

  return EggHatch
end
