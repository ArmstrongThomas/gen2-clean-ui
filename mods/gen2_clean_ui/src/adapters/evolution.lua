return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.specialty_common")
  local Evolution = {}

  local SCREEN_W, SCREEN_H = 160, 144
  local PIC_X, PIC_Y, PIC_BOX = 56, 16, 56
  local BALL_X, BALL_Y = 80, 56
  local BLACKOUT = {
    {255,255,255}, {58,58,58}, {16,25,25}, {0,0,0},
  }
  local PHASE_DURATION = {
    evolving=50, cry=80, flash=144, reveal=64, stopped=48,
    congrats=48, paragraph=20, evolved=40, learn=48,
  }

  local function gameData(state, context)
    local game = context and rawget(context, "game")
    game = type(game) == "table" and game or rawget(state, "game")
    local data = type(game) == "table" and rawget(game, "data") or nil
    if type(data) == "table" then return data end
    local supplied = rawget(state, "data")
    return type(supplied) == "table" and supplied or {}
  end

  local function generatedPath(value)
    if type(value) == "table" then value = rawget(value, "path") end
    return Common.generatedPath(value)
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
    return { {255,255,255}, light, dark, {0,0,0} }
  end

  local function normalized(value)
    local number = tonumber(value)
    if not number or number ~= number
        or number == math.huge or number == -math.huge then return nil end
    return math.max(0, math.min(1, number / 255))
  end

  local function ballColor(colors)
    local color = type(colors) == "table" and colors[3]
    return {
      normalized(type(color) == "table" and color[1] or 0),
      normalized(type(color) == "table" and color[2] or 0),
      normalized(type(color) == "table" and color[3] or 0), 1,
    }
  end

  local function picture(data, species, shiny, colors)
    local defs = type(data.pokemon) == "table" and data.pokemon or {}
    local def = species and rawget(defs, species)
    if type(def) ~= "table" then return nil end
    local path = generatedPath(rawget(def, "spriteFront"))
    local tiles = Common.integer(rawget(def, "picSize"), 5, 7) or 7
    local size = tiles * 8
    if not path then return nil end
    local output = {
      path=path, normalized=true,
      rect={x=(PIC_X + math.floor((PIC_BOX - size) / 2)) / SCREEN_W,
        y=(PIC_Y + PIC_BOX - size) / SCREEN_H,
        w=size / SCREEN_W, h=size / SCREEN_H},
    }
    if colors then output.palette = colors end
    return output
  end

  local function labels(state)
    local output = {}
    local lines = rawget(state, "lines")
    if type(lines) ~= "table" then return output end
    for index, value in ipairs(lines) do
      if type(value) == "string" then
        output[#output + 1] = {
          text=Data.text(value, ""), x=8 / SCREEN_W,
          y=(112 + (index - 1) * 16) / SCREEN_H,
          maxWidth=144 / SCREEN_W, color={0,0,0,1},
        }
      end
    end
    return output
  end

  local function textBox(state)
    local lines = rawget(state, "lines")
    if type(lines) ~= "table" or #lines == 0 then return {} end
    return {
      {x=0, y=96 / SCREEN_H, w=1, h=48 / SCREEN_H,
        color={0.08,0.09,0.1,1}},
      {x=4 / SCREEN_W, y=100 / SCREEN_H, w=152 / SCREEN_W,
        h=40 / SCREEN_H, color={1,1,1,1}},
    }
  end

  local function circles(state, colors)
    local output = {}
    if rawget(state, "phase") ~= "reveal" then return output end
    local balls = rawget(state, "balls")
    if type(balls) ~= "table" then return output end
    local color = ballColor(colors)
    for _, ball in ipairs(balls) do
      if type(ball) == "table" then
        local x, y = tonumber(rawget(ball, "x")), tonumber(rawget(ball, "y"))
        local age = Common.integer(rawget(ball, "age"), 0)
        if x and y and age then
          local radius = (math.floor(age / 2) % 2 == 0) and 4 or 3
          output[#output + 1] = {
            x=(BALL_X + x + 4) / SCREEN_W,
            y=(BALL_Y + y + 4) / SCREEN_H,
            radius=radius / SCREEN_W, color=color,
          }
        end
      end
    end
    return output
  end

  local function phaseFrame(state, phase)
    local duration = PHASE_DURATION[phase] or 1
    local timer = Common.integer(rawget(state, "timer"), 0) or 0
    if phase == "reveal" then
      return Common.integer(rawget(state, "ballFrame"), 0) or 0, duration
    end
    if phase == "flash" then
      local round = Common.integer(rawget(state, "round"), 1) or 1
      local rounds = rawget(state, "rounds")
      local frame = 0
      if type(rounds) == "table" then
        for index, entry in ipairs(rounds) do
          if index < round and type(entry) == "table" then
            frame = frame + (Common.integer(rawget(entry, "wait"), 0) or 0)
              + (Common.integer(rawget(entry, "flashes"), 0) or 0) * 2
          end
        end
      end
      local current = type(rounds) == "table" and rawget(rounds, round) or nil
      if type(current) == "table" then
        local wait = Common.integer(rawget(current, "wait"), 0) or 0
        local flashes = Common.integer(rawget(current, "flashes"), 0) or 0
        if rawget(state, "step") == "wait" then
          frame = frame + math.max(0, wait - timer)
        else
          frame = frame + wait + math.max(0, flashes * 2 -
            (Common.integer(rawget(state, "swapsLeft"), 0) or 0))
        end
      end
      return math.max(0, math.min(duration, frame)), duration
    end
    return math.max(0, math.min(duration, duration - timer)), duration
  end

  function Evolution.extract(state, context)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    if rawget(state, "done") == true then
      return Common.fail("state_done", "evolution")
    end
    local data = gameData(state, context)
    local oldSpecies = Data.id(rawget(state, "oldSpecies"))
    local newSpecies = Data.id(rawget(state, "newSpecies"))
    local mon = rawget(state, "mon")
    local shiny = type(mon) == "table" and rawget(mon, "shiny") == true
    if not oldSpecies or not newSpecies then
      return Common.fail("shape_type", "oldSpecies/newSpecies:string")
    end
    local oldColors = palette(data.gen2Palettes
      and rawget(data.gen2Palettes, "pokemon"), oldSpecies, shiny)
    local newColors = palette(data.gen2Palettes
      and rawget(data.gen2Palettes, "pokemon"), newSpecies, shiny)
    local oldPic = picture(data, oldSpecies, shiny,
      rawget(state, "blackout") == true and BLACKOUT or oldColors)
    local newPic = picture(data, newSpecies, shiny,
      rawget(state, "blackout") == true and BLACKOUT or newColors)
    if not oldPic or not newPic then
      return Common.fail("asset_path_missing", "evolution species art")
    end
    local phase = Data.id(rawget(state, "phase"), "evolving")
    local frame, duration = phaseFrame(state, phase)
    local showingNew = rawget(state, "showNew") == true
    local displayed = showingNew and newPic or oldPic
    local model = {
      schema="clean_ui.v3.presentation.v1", apiVersion=3,
      id="evolution", kind="animation", preset="ANIMATION",
      title="EVOLUTION", opaque=true,
      animation={id="cinematic.evolution", overlay=true,
        phase=phase, frame=frame, duration=duration,
        progress=frame / math.max(1, duration),
        showNew=showingNew, blackout=rawget(state, "blackout") == true,
        overlays={{x=0, y=0, w=1, h=1, color={1,1,1,1}}},
        sprites={}, circles=circles(state, newColors), labels=labels(state)},
    }
    if phase ~= "evolving" and phase ~= "learn" then
      model.animation.sprites[1] = displayed
    end
    for _, overlay in ipairs(textBox(state)) do
      model.animation.overlays[#model.animation.overlays + 1] = overlay
    end
    return { model=model, actions={} }
  end

  return Evolution
end
