return function(ctx)
  local Data = ctx.load("adapters.data")
  local Boot = {}

  local SCHEMA = "clean_ui.v3.presentation.v1"
  local DEFAULT_SCREEN = "assets/generated/title/title_screen.png"
  local DEFAULT_COPYRIGHT =
    "assets/generated/title/copyright_splash.png"
  local SCREEN_W, SCREEN_H = 160, 144
  local CLOUD_W, CLOUD_H = 160, 48
  local HOOH_SIZE = 64
  local TRAIL_W, TRAIL_H = 8, 16

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

  local function titleData(state, context)
    local game = context and rawget(context, "game")
    local generated = game and rawget(game, "titleData")
    if type(generated) == "table" then return generated end
    local supplied = rawget(state, "title")
    return type(supplied) == "table" and supplied or {}
  end

  local function normalized(value, fallback)
    local number = Data.scalar(value)
    if type(number) ~= "number" or number ~= number
        or number == math.huge or number == -math.huge then
      return fallback
    end
    return number
  end

  local function rect(x, y, w, h)
    return { x=x, y=y, w=w, h=h }
  end

  local function sprite(path, placement, crop)
    local output = { path=path, rect=placement }
    if crop then output.crop = crop end
    return output
  end

  local function cloudSprites(output, path, scroll)
    scroll = scroll % SCREEN_W
    if scroll == 0 then
      output[#output + 1] = sprite(path,
        rect(0, 88 / SCREEN_H, 1, CLOUD_H / SCREEN_H),
        { x=0, y=0, w=CLOUD_W, h=CLOUD_H })
      return
    end
    local left = CLOUD_W - scroll
    output[#output + 1] = sprite(path,
      rect(0, 88 / SCREEN_H, left / SCREEN_W, CLOUD_H / SCREEN_H),
      { x=scroll, y=0, w=left, h=CLOUD_H })
    output[#output + 1] = sprite(path,
      rect(left / SCREEN_W, 88 / SCREEN_H,
        scroll / SCREEN_W, CLOUD_H / SCREEN_H),
      { x=0, y=0, w=scroll, h=CLOUD_H })
  end

  local function hoohPath(title, frame)
    local frames = rawget(title, "hoohFrames")
    local path = type(frames) == "table" and imagePath(frames[frame]) or nil
    return path or imagePath(rawget(title, "hooh"))
  end

  local function titleSprites(state, context)
    local title = titleData(state, context)
    local screen = imagePath(rawget(title, "screen")) or DEFAULT_SCREEN
    local clouds = imagePath(rawget(title, "clouds"))
    local trail = imagePath(rawget(title, "trail"))
    local output = { sprite(screen, rect(0, 0, 1, 1)) }
    if clouds then
      cloudSprites(output, clouds,
        Data.integer(rawget(state, "cloudScroll"), 0))
    end

    local frame = Data.integer(rawget(state, "frame"), 1)
    frame = math.max(1, math.min(5, frame))
    local hooh = hoohPath(title, frame)
    if hooh then
      local x = normalized(rawget(title, "hoohX"), 48)
      local y = normalized(rawget(title, "hoohY"), 56)
      local phase = Data.integer(rawget(state, "hoohPhase"), 0) % 256
      local bob = math.floor(math.sin(phase * math.pi / 32) * 2)
      output[#output + 1] = sprite(hooh,
        rect(x / SCREEN_W, (y + bob) / SCREEN_H,
          HOOH_SIZE / SCREEN_W, HOOH_SIZE / SCREEN_H))
    end

    if trail then
      for _, item in ipairs(Data.array(rawget(state, "trails"), 64)) do
        local x = normalized(rawget(item, "x"))
        local y = normalized(rawget(item, "drawY"),
          normalized(rawget(item, "y")))
        if x and y and x >= 0 and x < SCREEN_W then
          output[#output + 1] = sprite(trail,
            rect(x / SCREEN_W, y / SCREEN_H,
              TRAIL_W / SCREEN_W, TRAIL_H / SCREEN_H))
        end
      end
    end
    return output
  end

  local function animationModel(id, title, animation)
    return {
      schema = SCHEMA, apiVersion = 3, id = id, kind = "animation",
      preset = "ANIMATION", title = title, opaque = true,
      animation = animation,
    }
  end

  function Boot.extractTitle(state, context)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local title = titleData(state, context)
    local screen = imagePath(rawget(title, "screen")) or DEFAULT_SCREEN
    local sprites = titleSprites(state, context)
    if #sprites == 0 or not imagePath(screen) then
      return nil, "asset_path_missing", "title screen art"
    end
    local frame = Data.integer(rawget(state, "frameCounter"), 0)
    return { model = animationModel("title_screen", "GOLD TITLE", {
      id = "boot.title", overlay = true, frame = frame, duration = 60,
      progress = (frame % 60) / 60,
      overlays = {
        { x=0, y=0, w=1, h=88 / SCREEN_H,
          color={123 / 255, 165 / 255, 1, 1} },
        { x=0, y=88 / SCREEN_H, w=1, h=56 / SCREEN_H,
          color={1, 1, 1, 1} },
      },
      sprites = sprites,
    }), actions = {} }
  end

  function Boot.extractCopyright(state, context)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local title = titleData(state, context)
    local path = imagePath(rawget(title, "copyrightSplash"))
      or DEFAULT_COPYRIGHT
    if not path then return nil, "asset_path_missing", "copyright splash art" end
    local frames = Data.integer(rawget(state, "frames"), 0)
    return { model = animationModel("copyright_splash", "COPYRIGHT", {
      id = "boot.copyright", overlay = true, frame = frames,
      duration = 100, progress = math.max(0, math.min(1, frames / 100)),
      overlays = {{ x=0, y=0, w=1, h=1, color={1, 1, 1, 1} }},
      sprites = { sprite(path, rect(0, 0, 1, 1)) },
    }), actions = {} }
  end

  return Boot
end
