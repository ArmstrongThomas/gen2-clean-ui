return function(ctx)
  local Data = ctx.load("adapters.data")
  local Battle = {}
  local EXP_LENGTH = 64
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
      paletteMode="gen2_2bpp", trueColor=false,
    }
  end

  local function animationFrame(state, anim)
    local extracted = rawget(state, "anims")
    local loaded = rawget(anim, "loaded")
    local gfx = type(extracted) == "table" and rawget(extracted, "gfx")
    local sheets = {}
    if type(loaded) == "table" and type(gfx) == "table" then
      for _, entry in ipairs(loaded) do
        local source = rawget(gfx, rawget(entry, "gfx"))
        local path = type(source) == "table"
          and (rawget(source, "image") or rawget(source, "path")) or nil
        if type(path) == "string" and path ~= "" then
          local width = tonumber(type(source) == "table"
            and rawget(source, "width")) or 64
          sheets[#sheets + 1] = {
            gfx=rawget(entry, "gfx"), tile=tonumber(rawget(entry, "tile")) or 0,
            tiles=tonumber(rawget(entry, "tiles")) or 0,
            battler=rawget(entry, "battler"), path=path,
            wide=math.max(1, math.floor(width / 8)),
          }
        end
      end
    end
    local objects = rawget(anim, "objects")
    local bg = rawget(anim, "bg")
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
    return {
      objects=Data.copy(type(objects) == "table" and rawget(objects, "oam")),
      sheets=sheets,
      palettes=Data.copy(type(rawget(state, "palettes")) == "table"
        and rawget(rawget(state, "palettes"), "battleObjects")),
      pics=pics,
      clearsHud=rawget(anim, "clearsHud") == true,
      hudSide=rawget(anim, "hudSide"),
    }
  end

  local function animationOf(state, phase)
    local slideFrame = tonumber(rawget(state, "slideFrame")) or 0
    if slideFrame < 72 then
      return { kind="intro", progress=math.max(0, math.min(1,
        slideFrame / 72)), frame=slideFrame, label="BATTLE START" }
    end
    local trainerSlide = rawget(state, "trainerSlide")
    if trainerSlide ~= nil then
      local frame = tonumber(trainerSlide) or 0
      return { kind="trainer-slide", progress=math.max(0, math.min(1,
        frame / 16)), frame=frame, label="OPPONENT IN" }
    end
    local faintSlide = rawget(state, "faintSlide")
    if type(faintSlide) == "table" then
      local frame = tonumber(rawget(faintSlide, "frames")) or 0
      local side = Data.text(rawget(faintSlide, "side"), "enemy")
      return { kind="faint", side=side, progress=math.max(0, math.min(1,
        frame / (side == "player" and 12 or 14))), frame=frame,
        label="FAINT" }
    end
    local anim = rawget(state, "anim")
    if type(anim) == "table" and rawget(anim, "stopped") ~= true then
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
      return { kind=kind, id=id,
        side=Data.text(rawget(anim, "side"), turn == 1 and "enemy" or "player"),
        frame=tonumber(rawget(anim, "frames")) or 0, label=label,
        frameData=animationFrame(state, anim) }
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
      return nil, "missing_" .. side
    end
    local species = Data.id(rawget(shown, "species"))
    local defs = rawget(state, "pokemon")
    local def = type(defs) == "table" and species and defs[species] or nil
    local back = side == "player"
    local path = type(def) == "table"
      and (back and rawget(def, "spriteBack") or rawget(def, "spriteFront"))
      or nil
    if type(path) ~= "string" or path == "" then
      return nil, "missing_" .. side .. "_sprite"
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
      sprite={ path=path, palette=palette(rawget(state, "palettes"),
        species, rawget(shown, "shiny") == true) },
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
    return { model = {
      schema="clean_ui.v3.presentation.v1", apiVersion=3, kind="battle",
      screenId="Gen2BattleState", family="battle", preset="BATTLE",
      opaque=true, phase=phase,
      animation=animationOf(state, phase),
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
