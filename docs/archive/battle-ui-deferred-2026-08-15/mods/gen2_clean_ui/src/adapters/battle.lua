return function(ctx)
  local Data = ctx.load("adapters.data")
  local Battle = {}
  local EXP_LENGTH = 64
  local MAX_BATTLE_MOVES = 4
  local GENDER_SHEET = "assets/generated/icons/gen2/gender.png"

  -- Generation II stores physical/special on the move's type, not on each
  -- move record.  Keep explicit metadata when a later data pack supplies it,
  -- then fall back to the cartridge rule for the stock catalog.
  local PHYSICAL_TYPES = {
    NORMAL=true, FIGHTING=true, FLYING=true, POISON=true, GROUND=true,
    ROCK=true, BUG=true, GHOST=true, STEEL=true,
  }
  local SPECIAL_TYPES = {
    FIRE=true, WATER=true, GRASS=true, ELECTRIC=true, PSYCHIC=true,
    ICE=true, DRAGON=true, DARK=true,
  }

  local function cleanMoveText(value)
    return Data.text(value):gsub("%s*<NEXT>%s*", " ")
  end

  -- BattleState uses the same native pagination marker for a number of
  -- post-action messages.  The clean presenter has room to wrap these as a
  -- single message, so do not expose the cartridge-era marker to the font.
  local function cleanBattleText(value)
    return Data.text(value):gsub("%s*<NEXT>%s*", " ")
  end

  local function volatileOf(state, side, shown)
    local volatile = type(shown) == "table" and rawget(shown, "volatile")
    if type(volatile) == "table" then return volatile end
    local battle = rawget(state, "battle")
    local current = type(battle) == "table" and rawget(battle, side)
    return type(current) == "table" and rawget(current, "volatile") or nil
  end

  local function genderOf(shown)
    local gender = type(shown) == "table" and rawget(shown, "gender")
    if gender == "male" or gender == "female" then return gender end
    return nil
  end

  local function typeEntries(value)
    local entries = {}
    local function add(raw)
      if #entries >= 2 or raw == nil then return end
      local id, label
      if type(raw) == "table" then
        id = Data.id(rawget(raw, "id"), Data.id(rawget(raw, "name")))
        label = Data.text(rawget(raw, "label"),
          Data.text(rawget(raw, "name"), id))
      else
        id = Data.id(raw)
        label = Data.text(raw, id)
      end
      if id and label then
        for _, entry in ipairs(entries) do
          if entry.id == id then return end
        end
        entries[#entries + 1] = { id=id, label=label }
      end
    end
    if type(value) == "table" then
      for _, raw in ipairs(value) do add(raw) end
    else
      add(value)
    end
    return entries
  end

  local function typesOf(shown, def)
    local value = rawget(shown, "types")
      or (type(def) == "table" and rawget(def, "types"))
    if value == nil then
      value = {
        rawget(shown, "type"),
        rawget(shown, "type2"),
      }
    end
    return typeEntries(value)
  end

  local function generatedPath(value)
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

  local function color(value)
    if type(value) ~= "table" then return nil end
    local output = {}
    for index = 1, 3 do
      local channel = tonumber(rawget(value, index))
      if channel == nil or channel < 0 or channel > 255 then return nil end
      output[index] = channel
    end
    return output
  end

  local function byte(value, fallback)
    value = tonumber(value)
    if value == nil or value ~= math.floor(value)
        or value < 0 or value > 255 then
      return fallback
    end
    return value
  end

  -- AnimRunner keeps the LCD override table zero-based, just like the
  -- released source.  Convert it to a dense detached array so the V3 model
  -- remains function-free and the responsive renderer can consume the exact
  -- per-scanline values without touching the host runner.
  local function scanlines(value, count)
    if type(value) ~= "table" then return nil end
    local output, present = {}, false
    local zeroBased = rawget(value, 0) ~= nil
    for row = 0, count - 1 do
      local raw = zeroBased and rawget(value, row) or rawget(value, row + 1)
      if raw ~= nil then present = true end
      output[row + 1] = byte(raw, 0)
    end
    return present and output or nil
  end

  local function pictureScale(state, path, species, back)
    local game = rawget(state, "game")
    local data = type(game) == "table" and rawget(game, "data") or nil
    local scales = type(data) == "table"
      and rawget(data, "battle_sprite_scales") or nil
    if type(scales) == "table" and type(path) == "string" then
      for id, record in pairs(scales) do
        if id ~= "_owners" and type(record) == "table"
            and rawget(record, "path") == path then
          local value = tonumber(rawget(record, "scale"))
          if value and value > 0 then return value end
        end
      end
    end
    local defs = rawget(state, "pokemon")
    local def = type(defs) == "table" and species and rawget(defs, species)
    local key = back and "battleScaleBack" or "battleScaleFront"
    local value = type(def) == "table" and tonumber(rawget(def, key))
    return value and value > 0 and value or 1
  end

  local function trainerPalette(palettes, className)
    local trainers = type(palettes) == "table"
      and rawget(palettes, "trainers") or nil
    local pair = type(trainers) == "table"
      and rawget(trainers, className or "PLAYER") or nil
    if type(pair) ~= "table" then return nil end
    local first, second = color(rawget(pair, 1)), color(rawget(pair, 2))
    if not first or not second then return nil end
    return {{255,255,255}, first, second, {0,0,0}}
  end

  local function trainerSprite(state, side)
    local path, className
    if side == "player" then
      if rawget(state, "showPlayerTrainer") ~= true then return nil end
      path = generatedPath(rawget(state, "playerBackPath"))
      className = "PLAYER"
    else
      if rawget(state, "showEnemyTrainer") ~= true then return nil end
      path = generatedPath(rawget(state, "enemyTrainerPath"))
      className = Data.id(rawget(state, "enemyTrainerClass"))
      if not className then
        local battle = rawget(state, "battle")
        local trainer = type(battle) == "table"
          and rawget(battle, "trainer") or nil
        className = Data.id(type(trainer) == "table"
          and (rawget(trainer, "classId") or rawget(trainer, "class")))
      end
    end
    if not path then return nil end
    return {
      path=path, palette=trainerPalette(rawget(state, "palettes"), className),
      paletteMode="gen2_2bpp",
      trueColor=(side == "player" and rawget(state, "playerBackTrueColor")
        or rawget(state, "enemyTrainerTrueColor")) == true,
      scale=pictureScale(state, path, nil, side == "player"),
    }
  end

  local function animationFrame(state, anim)
    local extracted = rawget(state, "anims")
    local loaded = rawget(anim, "loaded")
    local gfx = type(extracted) == "table" and rawget(extracted, "gfx")
    local sheets = {}
    if type(loaded) == "table" then
      for _, entry in ipairs(loaded) do
        local source = type(gfx) == "table"
          and rawget(gfx, rawget(entry, "gfx")) or nil
        local path = type(source) == "table"
          and (rawget(source, "image") or rawget(source, "path")) or nil
        local sourceWidth = type(source) == "table"
          and tonumber(rawget(source, "width")) or nil
        local sourceWide = type(source) == "table"
          and tonumber(rawget(source, "wide")) or nil
        local width = sourceWidth or (sourceWide and sourceWide * 8) or 64
        sheets[#sheets + 1] = {
          gfx=rawget(entry, "gfx"), tile=tonumber(rawget(entry, "tile")) or 0,
          tiles=tonumber(rawget(entry, "tiles")) or 0,
          battler=rawget(entry, "battler"),
          path=type(path) == "string" and path ~= "" and path or nil,
          wide=math.max(1, math.floor(width / 8)),
        }
      end
    end
    local objects = rawget(anim, "objects")
    local bg = rawget(anim, "bg")
    local pictureOverrides = Data.copy(rawget(anim, "picOverride"))
    local hasPictureOverride = type(pictureOverrides) == "table"
      and (rawget(pictureOverrides, "player") ~= nil
        or rawget(pictureOverrides, "enemy") ~= nil)
    local background = type(bg) == "table" and {
      scx=byte(rawget(bg, "scx"), 0),
      scy=byte(rawget(bg, "scy"), 0),
      lcdc=Data.text(rawget(bg, "lcdc")),
      lyStart=byte(rawget(bg, "lyStart"), 0),
      lyEnd=byte(rawget(bg, "lyEnd"), 0),
      lyBackup=scanlines(rawget(bg, "lyBackup"), 144),
      bgp=byte(rawget(bg, "bgp"), 228),
      obp0=byte(rawget(bg, "obp0"), 228),
      obp1=byte(rawget(bg, "obp1"), 228),
      surfWave=scanlines(rawget(bg, "surfWave"), 64),
    } or nil
    local pics = type(bg) == "table" and {
      player={
        hidden=type(rawget(bg, "hidden")) == "table"
          and rawget(rawget(bg, "hidden"), "player") or false,
        size=type(rawget(bg, "picSize")) == "table"
          and rawget(rawget(bg, "picSize"), "player") or nil,
        slide=type(rawget(bg, "slide")) == "table"
          and rawget(rawget(bg, "slide"), "player") or 0,
        shade=type(rawget(bg, "monShade")) == "table"
          and rawget(rawget(bg, "monShade"), "player") or nil,
      },
      enemy={
        hidden=type(rawget(bg, "hidden")) == "table"
          and rawget(rawget(bg, "hidden"), "enemy") or false,
        size=type(rawget(bg, "picSize")) == "table"
          and rawget(rawget(bg, "picSize"), "enemy") or nil,
        slide=type(rawget(bg, "slide")) == "table"
          and rawget(rawget(bg, "slide"), "enemy") or 0,
        shade=type(rawget(bg, "monShade")) == "table"
          and rawget(rawget(bg, "monShade"), "enemy") or nil,
      },
    } or nil
    local requiredSheets = true
    if type(loaded) ~= "table" or type(objects) ~= "table"
        or type(bg) ~= "table" then
      requiredSheets = false
    elseif type(rawget(objects, "oam")) == "table" then
      for _, object in ipairs(rawget(objects, "oam")) do
        local tile = tonumber(rawget(object, "tile"))
        local selected
        for index = #sheets, 1, -1 do
          local sheet = sheets[index]
          local first = tonumber(sheet.tile) or 0
          local count = math.max(1, tonumber(sheet.tiles) or 0)
          if tile and tile >= first and tile < first + count then
            selected = sheet
            break
          end
        end
        if selected and not selected.battler and not selected.path then
          requiredSheets = false
        end
      end
    end
    return {
      objects=Data.copy(type(objects) == "table" and rawget(objects, "oam")),
      sheets=sheets,
      palettes=Data.copy(type(rawget(state, "palettes")) == "table"
        and rawget(rawget(state, "palettes"), "battleObjects")),
      coordinateSpace="native_battle",
      logicalWidth=160, logicalHeight=144,
      pics=pics,
      background=background,
      pictureOverrides=pictureOverrides,
      -- These are the source-owned frame containers.  A structurally
      -- incomplete runner is not safe to suppress: the presenter will fail
      -- open (or retain the prior battle frame) instead of painting a text
      -- substitute over the native animation.
      sourceAvailable=requiredSheets and not hasPictureOverride,
      clearsHud=rawget(anim, "clearsHud") == true,
      hudSide=rawget(anim, "hudSide"),
    }
  end

  local function animationOf(state, phase)
    local liveAnim = rawget(state, "anim")
    local liveAnimPresent = type(liveAnim) == "table"
      and (rawget(liveAnim, "stopped") ~= true
        or rawget(liveAnim, "keepSprites") == true)
    local liveFrameData = liveAnimPresent
      and animationFrame(state, liveAnim) or nil
    local slideFrame = tonumber(rawget(state, "slideFrame")) or 0
    if slideFrame < 72 then
      local top = (0x90 - slideFrame * 2) % 256
      local middle = (0x70 + slideFrame * 2) % 256
      return { kind="intro", progress=math.max(0, math.min(1,
        slideFrame / 72)), frame=slideFrame, label="BATTLE START",
        intro={topScroll=top, middleScroll=middle,
          backpicOffset=(72 - math.max(0, math.min(72, slideFrame))) * 2},
        frameData=liveFrameData, sceneFrame=liveFrameData }
    end
    local trainerSlide = rawget(state, "trainerSlide")
    if trainerSlide ~= nil then
      local frame = tonumber(trainerSlide) or 0
      return { kind="trainer-slide", progress=math.max(0, math.min(1,
        frame / 16)), frame=frame, label="OPPONENT IN",
        frameData=liveFrameData, sceneFrame=liveFrameData }
    end
    local faintSlide = rawget(state, "faintSlide")
    if type(faintSlide) == "table" then
      local frame = tonumber(rawget(faintSlide, "frames")) or 0
      local side = Data.text(rawget(faintSlide, "side"), "enemy")
      return { kind="faint", side=side, progress=math.max(0, math.min(1,
        frame / (side == "player" and 12 or 14))), frame=frame,
        sink=math.floor(math.max(0, frame) / 2) * 8,
        boxPixels=side == "player" and 48 or 56,
        label="FAINT" }
    end
    local anim = rawget(state, "anim")
    if type(anim) == "table" and (rawget(anim, "stopped") ~= true
        or rawget(anim, "keepSprites") == true) then
      local env = rawget(anim, "env")
      local id = Data.text(rawget(anim, "animId"),
        Data.text(type(env) == "table" and rawget(env, "animId"),
          Data.text(rawget(anim, "id"), "BATTLE ANIMATION")))
      local upper = id:upper()
      local kind = "move"
      local label = id:gsub("^ANIM_", ""):gsub("_", " ")
      if upper:find("THROW_POKE_BALL", 1, true)
          or upper:find("THROW_PARK_BALL", 1, true)
          or upper:find("THROW_BALL", 1, true) then
        kind, label = "pokeball", "POKE BALL"
      elseif upper == "RECOVER" or upper:find("HEAL", 1, true)
          or upper:find("USE_ITEM", 1, true)
          or upper:find("ITEM", 1, true) then
        kind, label = "item", "ITEM USED"
      elseif upper:find("SEND_OUT", 1, true) then
        kind, label = "send-out", "SEND OUT"
      end
      local turn = type(env) == "table" and tonumber(rawget(env, "battleTurn"))
      local frameData = liveFrameData or animationFrame(state, anim)
      return { kind=kind, id=id,
        side=Data.text(rawget(anim, "side"), turn == 1 and "enemy" or "player"),
        frame=tonumber(rawget(anim, "frames")) or 0, label=label,
        frameData=frameData, sceneFrame=frameData }
    end
    local expAnim = rawget(state, "expAnim")
    if type(expAnim) == "table" then
      local pixels = tonumber(rawget(expAnim, "pixels")) or 0
      return { kind="experience", progress=math.max(0, math.min(1,
        pixels / 64)), frame=tonumber(rawget(expAnim, "frames")) or 0,
        label="EXPERIENCE" }
    end
    if phase == "stats-box" then
      return { kind="level-up", label="LEVEL UP" }
    elseif phase == "evolving" then
      return { kind="evolution", label="EVOLUTION" }
    end
    return nil
  end

  local function palette(palettes, species, shiny)
    local entry = palettes and palettes.pokemon and palettes.pokemon[species]
    local pair = type(entry) == "table"
      and ((shiny and entry.shiny) or entry.normal) or nil
    if type(pair) ~= "table" or type(pair[1]) ~= "table"
        or type(pair[2]) ~= "table" then return nil end
    local function rgb(value)
      if type(value) ~= "table" then return nil end
      local out = {}
      for index = 1, 3 do
        if type(value[index]) ~= "number" then return nil end
        out[index] = value[index]
      end
      return out
    end
    local light, dark = rgb(pair[1]), rgb(pair[2])
    if not (light and dark) then return nil end
    return { {255,255,255}, light, dark, {0,0,0} }
  end

  local function emptyMon(side, reason)
    -- The source can briefly publish a BattleState before the active
    -- battler/sprite snapshot is populated (intro, item, and finishing-hit
    -- transitions do this). Keep the V3 battle owner alive with an invisible
    -- placeholder instead of exposing the native renderer for one frame.
    return {
      species="", name="", level=1, hp=0, maxHp=1, status="",
      gender=nil, genderIcon=nil, types={}, caught=false, exp=nil,
      expCurrent=nil, expRequired=nil, expText=nil, confused=false,
      shiny=false, sprite=nil, hudVisible=false,
      incomplete=true, missingSide=side, missingReason=reason,
    }
  end

  local function mon(state, side)
    local battle = rawget(state, "battle") or {}
    local shown = type(rawget(state, "shownMon")) == "table"
      and rawget(state, "shownMon")[side] or rawget(battle, side)
    if type(shown) ~= "table" then
      local tutorial = rawget(state, "tutorial") == true
        or rawget(state, "battleTutorial") == true
      if side == "player" and tutorial then
        -- The Dude's catch tutorial intentionally has no player battler. The
        -- native BattleState still owns the enemy field and message panel,
        -- so keep that complete battle page clean while leaving the absent
        -- player HUD/sprite empty rather than failing back to native.
        return {
          species="DUDE", name="", level=1, hp=0, maxHp=1,
          status="", gender=nil, genderIcon=nil, types={},
          hudVisible=false, caught=false, exp=nil, expCurrent=nil,
          expRequired=nil, expText=nil, confused=false, shiny=false,
          sprite=nil,
        }
      end
      return emptyMon(side, "missing_" .. side)
    end
    local species = Data.id(rawget(shown, "species"))
    local defs = rawget(state, "pokemon")
    local def = type(defs) == "table" and species and defs[species] or nil
    local back = side == "player"
    local path = type(def) == "table"
      and (back and rawget(def, "spriteBack") or rawget(def, "spriteFront"))
      or nil
    if type(path) ~= "string" or path == "" then
      return emptyMon(side, "missing_" .. side .. "_sprite")
    end
    local shownHp = rawget(state, "shownHp")
    local hp = type(shownHp) == "table" and rawget(shownHp, side)
      or rawget(shown, "hp")
    local stats = rawget(shown, "stats")
    local maxHp = rawget(shown, "maxHp")
      or (type(stats) == "table" and rawget(stats, "hp")) or hp
    local shownLevel = side == "player" and rawget(state, "shownLevel")
      or nil
    local level = Data.integer(shownLevel,
      Data.integer(rawget(shown, "level"), 1))
    local volatile = volatileOf(state, side, shown)
    local confuseCount = type(volatile) == "table"
      and rawget(volatile, "confuseCount") or nil
    local battleWild = rawget(battle, "wild") == true
    local save = rawget(state, "save")
    local pokedex = type(save) == "table" and rawget(save, "pokedex")
    local caught = type(pokedex) == "table" and rawget(pokedex, "caught")
    local shownExp = side == "player" and rawget(state, "shownExp") or nil
    local exp = tonumber(shownExp)
    if exp ~= nil then exp = math.max(0, math.min(EXP_LENGTH, exp)) end
    local gender = genderOf(shown)
    return {
      species=species,
      name=Data.text(rawget(shown, "nickname"),
        Data.text(rawget(shown, "name"), species or "?")),
      level=level,
      hp=Data.integer(hp, 0), maxHp=Data.integer(maxHp, 1),
      status=Data.text(rawget(shown, "status"), "OK"),
      gender=gender,
      genderIcon=gender == "male" and {
        path=GENDER_SHEET, crop={ x=0, y=0, w=16, h=16 },
      } or gender == "female" and {
        path=GENDER_SHEET, crop={ x=16, y=0, w=16, h=16 },
      } or nil,
      types=typesOf(shown, def),
      hudVisible=(tonumber(rawget(state, "slideFrame")) or 0) >= 72
        and ((side == "player" and rawget(state, "showPlayerHud")
          or rawget(state, "showEnemyHud")) ~= false),
      caught=side == "enemy" and battleWild and species ~= nil
        and type(caught) == "table" and caught[species] and true or false,
      exp=exp and exp / EXP_LENGTH or nil,
      expCurrent=exp and math.floor(exp + 0.5) or nil,
      expRequired=exp and EXP_LENGTH or nil,
      expText=exp and ("EXP %d/%d"):format(math.floor(exp + 0.5),
        EXP_LENGTH) or nil,
      confused=(tonumber(confuseCount) or 0) > 0
        or rawget(volatile or {}, "confused") == true,
      shiny=rawget(shown, "shiny") == true,
      hidden=type(rawget(state, "picHidden")) == "table"
        and rawget(rawget(state, "picHidden"), side) == true or false,
      sprite={ path=path, palette=palette(rawget(state, "palettes"),
        species, rawget(shown, "shiny") == true),
        scale=pictureScale(state, path, species, back),
        trueColor=type(def) == "table"
          and rawget(def, "trueColor") == true or false },
    }
  end

  local function moveDefinition(state, move)
    local game = rawget(state, "game")
    local data = type(game) == "table" and rawget(game, "data")
    local defs = type(data) == "table" and rawget(data, "moves")
    local id = type(move) == "table" and rawget(move, "id") or nil
    if type(defs) ~= "table" or id == nil then return nil end
    return rawget(defs, id) or rawget(defs, tostring(id):upper())
  end

  local function moveActions(state)
    local battle = rawget(state, "battle") or {}
    local player = rawget(battle, "player") or {}
    local source = player
    if rawget(state, "phase") == "choose-forget" then
      -- LearnMove can pause on a benched participant after shared EXP. The
      -- native picker reads pendingLearn.index, not the active battler.
      local pending = rawget(state, "pendingLearn")
      local index = type(pending) == "table"
        and tonumber(rawget(pending, "index")) or nil
      local party = rawget(battle, "party")
      if index and type(party) == "table" and type(party[index]) == "table" then
        source = party[index]
      end
    end
    local moves = rawget(state, "moveList") or rawget(source, "moves") or {}
    local actions = {}
    for index, move in ipairs(moves) do
      if index > MAX_BATTLE_MOVES then break end
      if type(move) == "table" then
        local def = moveDefinition(state, move) or {}
        local moveType = rawget(move, "type") or rawget(def, "type")
        local typeList = typeEntries(moveType)
        local explicitCategory = Data.text(rawget(move, "category"),
          Data.text(rawget(def, "category")))
        local category = explicitCategory ~= "" and explicitCategory or nil
        if not category and typeList[1] then
          local typeId = tostring(typeList[1].id or ""):upper()
          if PHYSICAL_TYPES[typeId] then category = "PHYSICAL"
          elseif SPECIAL_TYPES[typeId] then category = "SPECIAL" end
        end
        local pp = Data.integer(rawget(move, "pp"),
          Data.integer(rawget(def, "pp"), 0))
        local maxPp = Data.integer(rawget(move, "maxPp"),
          Data.integer(rawget(move, "maxPP"),
            Data.integer(rawget(def, "maxPp"),
              Data.integer(rawget(def, "maxPP"), pp))))
        actions[#actions + 1] = {
          id=Data.id(rawget(move, "id"), "move." .. index),
          label=Data.text(rawget(move, "name"),
            Data.text(rawget(move, "id"), "MOVE " .. index)),
          sourceIndex=index,
          pp=pp, maxPp=maxPp,
          type=typeList[1],
          power=Data.integer(rawget(move, "power"),
            Data.integer(rawget(def, "power"))),
          accuracy=Data.integer(rawget(move, "accuracy"),
            Data.integer(rawget(def, "accuracy"))),
          category=category,
          description=cleanMoveText(Data.text(rawget(move, "description"),
            Data.text(rawget(def, "description")))),
        }
      end
    end
    return actions
  end

  local function actions(state)
    local phase = rawget(state, "phase")
    if phase == "menu" then
      return {
        { id="fight", label="FIGHT", sourceIndex=1 },
        { id="pokemon", label="POKEMON", sourceIndex=2 },
        { id="pack", label="PACK", sourceIndex=3 },
        { id="run", label="RUN", sourceIndex=4 },
      }
    elseif phase == "moves" or phase == "choose-forget" then
      return moveActions(state)
    elseif phase == "ask-nickname" or phase == "ask-shift"
        or phase == "ask-forget" or phase == "stop-learning"
        or phase == "ask-next-mon" then
      return {
        { id="yes", label="YES", sourceIndex=1 },
        { id="no", label="NO", sourceIndex=2 },
      }
    end
    return {}
  end

  function Battle.extract(state, context)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    -- BattleState marks the underlying battle over as soon as the finishing
    -- hit resolves, but it remains on the stack for the victory line, EXP
    -- crawl, level-up stats, and evolution hand-off. Stay attached until the
    -- presentation phase is actually done.
    if rawget(state, "phase") == "done" then
      return nil, "battle_finished"
    end
    local player, playerCode = mon(state, "player")
    if not player then return nil, playerCode end
    local enemy, enemyCode = mon(state, "enemy")
    if not enemy then return nil, enemyCode end
    local phase = rawget(state, "phase")
    local actionRows = actions(state)
    local selectedAction = Data.integer(rawget(state, "menuIndex"), 1)
    local selectedMove = Data.integer(rawget(state, "moveIndex"), 1)
    if phase == "choose-forget" then
      -- The learn flow has its own cursor; reusing moveIndex can highlight a
      -- different slot when a Pokémon is asked to forget a move.
      selectedMove = Data.integer(rawget(state, "forgetIndex"), 1)
    end
    if phase == "ask-nickname" then
      selectedAction = Data.integer(rawget(state, "nicknameIndex"), 1)
    elseif phase == "ask-shift" then
      selectedAction = Data.integer(rawget(state, "shiftIndex"), 1)
    elseif phase == "ask-forget" or phase == "stop-learning" then
      selectedAction = Data.integer(rawget(state, "forgetChoice"), 1)
    elseif phase == "ask-next-mon" then
      selectedAction = Data.integer(rawget(state, "nextMonIndex"), 1)
    end
    local animation = animationOf(state, phase)
    local tutorial = rawget(state, "tutorial") == true
      or rawget(state, "battleTutorial") == true
    local transientReason
    if not tutorial then
      if player.incomplete then
        transientReason = "battle_snapshot_incomplete:player"
      elseif enemy.incomplete then
        transientReason = "battle_snapshot_incomplete:enemy"
      end
    end
    return { model = {
      schema="clean_ui.v3.presentation.v1", apiVersion=3, kind="battle",
      screenId="Gen2BattleState", family="battle", preset="BATTLE",
      opaque=true, sourceBacked=false,
      phase=phase,
      transient=transientReason ~= nil,
      transientReason=transientReason,
      animation=animation,
      -- Keep the live native-stage frame available at the battle-model level
      -- as well as under animation. This is the stable V3 seam for tools and
      -- alternate presenters that do not want to know the animation subtype.
      sceneFrame=animation and animation.sceneFrame or nil,
      statsBox=type(rawget(state, "statsBoxMon")) == "table" and {
        name=Data.text(rawget(rawget(state, "statsBoxMon"), "nickname"),
          Data.text(rawget(rawget(state, "statsBoxMon"), "species"), "POKEMON")),
        level=Data.integer(rawget(rawget(state, "statsBoxMon"), "level"), 1),
        stats=rawget(rawget(state, "statsBoxMon"), "stats"),
      } or nil,
      player=player, enemy=enemy,
      playerTrainer=trainerSprite(state, "player"),
      enemyTrainer=trainerSprite(state, "enemy"),
      actions=actionRows,
      selectedAction=(phase == "menu" or phase == "ask-nickname"
        or phase == "ask-shift" or phase == "ask-forget"
        or phase == "stop-learning" or phase == "ask-next-mon")
        and selectedAction or nil,
      selectedMove=(phase == "moves" or phase == "choose-forget")
        and selectedMove or nil,
      message=cleanBattleText(rawget(state, "message")),
      messageTimer=Data.integer(rawget(state, "messageTimer"), 0),
      battleKind=rawget(state, "contest") and "contest"
        or (rawget(state, "music") and "trainer" or "wild"),
    } }
  end

  return Battle
end
