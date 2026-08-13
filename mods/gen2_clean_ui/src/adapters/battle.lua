return function(ctx)
  local Data = ctx.load("adapters.data")
  local Battle = {}
  local EXP_LENGTH = 64

  local NATIVE_PHASES = {
    submenu=true,
    evolving=true,
    ["stats-box"]=true,
    ["forced-switch"]=true,
  }

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
    if type(shown) ~= "table" then return nil, "missing_" .. side end
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
    return {
      species=species,
      name=Data.text(rawget(shown, "nickname"),
        Data.text(rawget(shown, "name"), species or "?")),
      level=level,
      hp=Data.integer(hp, 0), maxHp=Data.integer(maxHp, 1),
      status=Data.text(rawget(shown, "status"), "OK"),
      gender=genderOf(shown),
      caught=side == "enemy" and battleWild and species ~= nil
        and type(caught) == "table" and caught[species] and true or false,
      exp=exp and exp / EXP_LENGTH or nil,
      confused=(tonumber(confuseCount) or 0) > 0
        or rawget(volatile or {}, "confused") == true,
      shiny=rawget(shown, "shiny") == true,
      sprite={ path=path, palette=palette(rawget(state, "palettes"),
        species, rawget(shown, "shiny") == true) },
    }
  end

  local function moveActions(state)
    local battle = rawget(state, "battle") or {}
    local player = rawget(battle, "player") or {}
    local moves = rawget(state, "moveList") or rawget(player, "moves") or {}
    local actions = {}
    for index, move in ipairs(moves) do
      if type(move) == "table" then
        actions[#actions + 1] = {
          id=Data.id(rawget(move, "id"), "move." .. index),
          label=Data.text(rawget(move, "name"),
            Data.text(rawget(move, "id"), "MOVE " .. index)),
          sourceIndex=index,
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
        or phase == "ask-forget" or phase == "stop-learning" then
      return {
        { id="yes", label="YES", sourceIndex=1 },
        { id="no", label="NO", sourceIndex=2 },
      }
    end
    return {}
  end

  function Battle.extract(state, context)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    if rawget(state, "phase") == "done"
        or rawget(state, "battle") and rawget(state, "battle").over then
      return nil, "battle_finished"
    end
    -- The native transition, intro slide, trainer slide, faint slide, and
    -- battle animation remain visible while their source timing owns the
    -- frame. Clean UI takes over only at stable decision/message frames.
    if (tonumber(rawget(state, "slideFrame")) or 0) < 72
        or rawget(state, "trainerSlide") ~= nil
        or rawget(state, "faintSlide") ~= nil
        or rawget(state, "anim") ~= nil
        or rawget(state, "showPlayerTrainer") == true
        or rawget(state, "showEnemyTrainer") == true
        or rawget(state, "showPlayerHud") ~= true
        or rawget(state, "showEnemyHud") ~= true then
      return nil, "native_timing_frame"
    end
    local player, playerCode = mon(state, "player")
    if not player then return nil, playerCode end
    local enemy, enemyCode = mon(state, "enemy")
    if not enemy then return nil, enemyCode end
    local phase = rawget(state, "phase")
    if NATIVE_PHASES[phase] then
      return nil, "native_phase"
    end
    local actionRows = actions(state)
    local selectedAction = Data.integer(rawget(state, "menuIndex"), 1)
    local selectedMove = Data.integer(rawget(state, "moveIndex"), 1)
    if phase == "ask-nickname" then
      selectedAction = Data.integer(rawget(state, "nicknameIndex"), 1)
    elseif phase == "ask-shift" then
      selectedAction = Data.integer(rawget(state, "shiftIndex"), 1)
    elseif phase == "ask-forget" or phase == "stop-learning" then
      selectedAction = Data.integer(rawget(state, "forgetChoice"), 1)
    end
    return { model = {
      schema="clean_ui.presenter_model.v1", kind="battle",
      screenId="Gen2BattleState", family="battle", preset="BATTLE",
      opaque=true, phase=phase,
      player=player, enemy=enemy,
      actions=actionRows,
      selectedAction=(phase == "menu" or phase == "ask-nickname"
        or phase == "ask-shift" or phase == "ask-forget"
        or phase == "stop-learning") and selectedAction or nil,
      selectedMove=(phase == "moves" or phase == "choose-forget")
        and selectedMove or nil,
      message=Data.text(rawget(state, "message"), ""),
      messageTimer=Data.integer(rawget(state, "messageTimer"), 0),
      battleKind=rawget(state, "contest") and "contest"
        or (rawget(state, "music") and "trainer" or "wild"),
    } }
  end

  return Battle
end
