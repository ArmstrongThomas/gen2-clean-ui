return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.specialty_common")
  local Credits = {}

  local SCREEN_W, SCREEN_H = 160, 144
  local BANNER_H = 32
  local TILE = 8
  local BANNER_ROWS = { 0, 14 * TILE }
  local BORDER_ROWS = { 4 * TILE, 13 * TILE }
  local SPECIES = { "bellossom", "togepi", "elekid", "sentret" }
  local FRAME_MAP = {
    { 1, 2, 1, 3 }, { 1, 2, 1, 3 },
    { 1, 2, 1, 3 }, { 1, 2, 3, 4 },
  }
  local FALLBACK_PALETTES = {
    { {255,255,255}, {239,222,215}, {123, 98, 82}, {56,56,56} },
    { {255,255,255}, {242,213, 135}, {255, 88, 220}, {56,56,56} },
    { {255,255,255}, {255,255,170}, {142,195,255}, {56,56,56} },
    { {255,255,255}, {222,154, 84}, {255,154,  74}, {56,56,56} },
  }

  local function imagePath(value)
    if type(value) == "table" then value = rawget(value, "path") end
    if type(value) ~= "string"
        or value:sub(1, 17) ~= "assets/generated/"
        or value:sub(-4):lower() ~= ".png"
        or value:find("..", 1, true)
        or value:find("\\", 1, true)
        or value:find(":", 1, true) then
      return nil
    end
    return value
  end

  local function generated(state, context)
    local game = context and rawget(context, "game")
    game = type(game) == "table" and game or rawget(state, "game")
    local data = type(game) == "table" and rawget(game, "data")
    if type(data) == "table" and type(data.gen2Credits) == "table" then
      return data.gen2Credits
    end
    local supplied = rawget(state, "gfx")
    return type(supplied) == "table" and supplied or {}
  end

  local function normalizedColor(color)
    if type(color) ~= "table" then return nil end
    local output = {}
    for index = 1, 3 do
      local channel = tonumber(color[index])
      if not channel then return nil end
      output[index] = math.max(0, math.min(1, channel / 255))
    end
    local alpha = tonumber(color[4])
    output[4] = alpha and math.max(0, math.min(1, alpha / 255)) or 1
    return output
  end

  local function paletteFor(gfx, scene)
    local palettes = type(gfx) == "table" and rawget(gfx, "palettes")
    local raw = type(palettes) == "table" and rawget(palettes, scene + 1)
    local palette = Common.palette(raw)
    return palette or FALLBACK_PALETTES[scene + 1] or FALLBACK_PALETTES[1]
  end

  local function overlay(x, y, w, h, color)
    return { x=x / SCREEN_W, y=y / SCREEN_H,
      w=w / SCREEN_W, h=h / SCREEN_H, color=normalizedColor(color) }
  end

  local function sprite(path, x, y, w, h, crop, palette)
    local output = { path=path, rect={x=x / SCREEN_W, y=y / SCREEN_H,
      w=w / SCREEN_W, h=h / SCREEN_H} }
    if crop then output.crop = crop end
    if palette then output.palette = palette end
    return output
  end

  local function sceneEntry(gfx, scene)
    local scenes = type(gfx) == "table" and rawget(gfx, "scenes")
    local entry = type(scenes) == "table" and rawget(scenes, scene + 1)
    if type(entry) ~= "table" then
      entry = { species=SPECIES[scene + 1], frames=scene == 3 and 4 or 3,
        width=32, height=32,
        image="assets/generated/credits/" .. SPECIES[scene + 1] .. ".png" }
    end
    return entry
  end

  local function sceneSprites(gfx, scene, frame, palette)
    local output = {}
    local entry = sceneEntry(gfx, scene)
    local path = imagePath(rawget(entry, "image"))
    local frames = Common.integer(rawget(entry, "frames"), 1, 8) or 3
    local width = Common.integer(rawget(entry, "width"), 1, 64) or 32
    local height = Common.integer(rawget(entry, "height"), 1, 64) or 32
    local graphic = FRAME_MAP[scene + 1]
      and FRAME_MAP[scene + 1][(frame % 4) + 1] or 1
    graphic = math.max(1, math.min(frames, graphic))
    if not path then return output, false end
    for _, y in ipairs(BANNER_ROWS) do
      for repeatIndex = 0, 4 do
        output[#output + 1] = sprite(path, repeatIndex * width, y,
          width, height, { x=0, y=(graphic - 1) * height,
            w=width, h=height }, palette)
      end
    end
    return output, true
  end

  local function borderSprites(gfx, shift, palette)
    local path = imagePath(type(gfx) == "table" and rawget(gfx, "border"))
      or "assets/generated/credits/border.png"
    local output = {}
    local starts = {
      [BORDER_ROWS[1]] = Common.integer(rawget(gfx, "borderTopTile"), 1, 16) or 5,
      [BORDER_ROWS[2]] = Common.integer(rawget(gfx, "borderBottomTile"), 1, 16) or 1,
    }
    shift = (Common.integer(shift, 0, 255) or 0) % 32
    for _, y in ipairs(BORDER_ROWS) do
      for repeatIndex = 0, 4 do
        for tile = 0, 3 do
          local x = (repeatIndex * 32 + tile * TILE - shift) % SCREEN_W
          output[#output + 1] = sprite(path, x, y, TILE, TILE,
            { x=(starts[y] + tile - 1) * TILE, y=0, w=TILE, h=TILE },
            palette)
        end
      end
    end
    return output
  end

  local function labels(shown, palette)
    local output = {}
    local ink = normalizedColor(palette[4])
    for _, entry in ipairs(shown or {}) do
      if type(entry) == "table" then
        local x = Common.integer(rawget(entry, "x"), 0, 19)
        local y = Common.integer(rawget(entry, "y"), 0, 17)
        if x and y and rawget(entry, "theEnd") == true then
          output[#output + 1] = { text="THE END", x=10 / 20,
            y=(y * TILE) / SCREEN_H, align="center", maxWidth=8 / 20,
            color=ink }
        elseif x and y and type(rawget(entry, "text")) == "string" then
          output[#output + 1] = { text=Data.text(rawget(entry, "text"), ""),
            x=x / 20, y=(y * TILE) / SCREEN_H, color=ink }
        end
      end
    end
    return output
  end

  local function animationModel(state, context)
    local gfx = generated(state, context)
    local scene = Common.integer(rawget(state, "scene"), 0, 3) or 0
    local frame = Common.integer(rawget(state, "borderFrame"), 0, 255) or 255
    local scroll = Common.integer(rawget(state, "lyOverride"), 0, 255) or 0
    local palette = paletteFor(gfx, scene)
    local palPaper = palette[1]
    local palBanner = frame == 255 and palette[3] or palette[1]
    local sprites, hasScene = {}, true
    if frame ~= 255 then sprites, hasScene = sceneSprites(gfx, scene, frame, palette) end
    if frame ~= 255 and not hasScene then return nil, "asset_path_missing", "credits scene" end
    local overlays = {
      overlay(0, 0, SCREEN_W, SCREEN_H, palPaper),
      overlay(0, 0, SCREEN_W, BANNER_H, palBanner),
      overlay(0, 14 * TILE, SCREEN_W, BANNER_H, palBanner),
      overlay(0, 4 * TILE, SCREEN_W, TILE, palette[3]),
      overlay(0, 13 * TILE, SCREEN_W, TILE, palette[3]),
    }
    for _, item in ipairs(borderSprites(gfx, scroll, palette)) do
      sprites[#sprites + 1] = item
    end
    local endPath = imagePath(type(gfx) == "table" and rawget(gfx, "theEnd"))
      or "assets/generated/credits/theend.png"
    for _, entry in ipairs(rawget(state, "shown") or {}) do
      if type(entry) == "table" and rawget(entry, "theEnd") == true then
        sprites[#sprites + 1] = sprite(endPath, 6 * TILE, 8 * TILE, 64, 16,
          nil, palette)
        break
      end
    end
    return {
      schema="clean_ui.v3.presentation.v1", apiVersion=3,
      id="credits_roll", kind="animation", preset="ANIMATION",
      title="CREDITS", opaque=true,
      animation={ id="credits.roll", overlay=true,
        frame=Common.integer(rawget(state, "frames"), 0) or 0,
        duration=13, progress=((Common.integer(rawget(state, "frames"), 0) or 0) % 13) / 13,
        overlays=overlays, sprites=sprites,
        labels=labels(rawget(state, "shown"), palette) },
    }
  end

  function Credits.extract(state, context)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    if rawget(state, "done") == true then return Common.fail("state_done", "credits") end
    local model, code, detail = animationModel(state, context)
    if not model then return Common.fail(code, detail) end
    return { model=model, actions={} }
  end

  return Credits
end
