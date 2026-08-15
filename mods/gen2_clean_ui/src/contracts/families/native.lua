return function(ctx)
  local Record = ctx.load("contracts.record")
  local V = ctx.load("contracts.validators")

  local function native(id, module, family, opaque, reason)
    return Record.native({
      id = id,
      module = module,
      milestone = "native_by_design",
      family = family,
      opaque = opaque,
      nativeReason = reason,
      gallery = { "native_status" },
    })
  end

  local function nativeWithGallery(id, module, family, opaque, reason, gallery)
    return Record.native({
      id = id,
      module = module,
      milestone = "native_by_design",
      family = family,
      opaque = opaque,
      nativeReason = reason,
      gallery = gallery,
    })
  end

  local function deferred(id, module, opaque, reason)
    return Record.deferred({
      id = id,
      module = module,
      milestone = "post_1.0_battle_design",
      family = "battle",
      opaque = opaque,
      nativeReason = reason,
      gallery = { "deferred_status" },
    })
  end

  local function copyrightBase(state)
    local ok, code, detail = V.fields(state, {
      frames = "number", done = "boolean",
    })
    if not ok then return nil, code, detail end
    return V.nonNegative(state.frames, "frames")
  end

  local function titleBase(state)
    local ok, code, detail = V.fields(state, {
      frame = "number", frameCounter = "number", cloudScroll = "number",
      hoohPhase = "number", trails = "table",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.index(state.frame, "frame", 5)
    if not ok then return nil, code, detail end
    for _, field in ipairs({ "frameCounter", "cloudScroll", "hoohPhase" }) do
      ok, code, detail = V.nonNegative(state[field], field)
      if not ok then return nil, code, detail end
    end
    return V.array(state.trails, "trails", 0)
  end

  local function creditsEntry(value, index)
    if type(value) ~= "table" then
      return V.fail("shape_type", "shown[" .. tostring(index) .. "]:table")
    end
    local x = rawget(value, "x")
    local y = rawget(value, "y")
    local ok, code, detail = V.integer(x, "shown.x", 0, 19)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(y, "shown.y", 0, 17)
    if not ok then return nil, code, detail end
    if rawget(value, "theEnd") == true then return true end
    return V.type(rawget(value, "text"), "string", "shown.text")
  end

  local function creditsBase(state)
    local ok, code, detail = V.fields(state, {
      scene = "number", borderFrame = "number", lyOverride = "number",
      frames = "number", shown = "table", done = "boolean",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.scene, "scene", 0, 3)
    if not ok then return nil, code, detail end
    for _, field in ipairs({ "borderFrame", "lyOverride" }) do
      ok, code, detail = V.integer(state[field], field, 0, 255)
      if not ok then return nil, code, detail end
    end
    ok, code, detail = V.nonNegative(state.frames, "frames")
    if not ok then return nil, code, detail end
    return V.array(state.shown, "shown", 0, creditsEntry)
  end

  local function gameFreakOamEntry(value, index)
    if type(value) ~= "table" then
      return V.fail("shape_type", "anims.oam[" .. tostring(index) .. "]:table")
    end
    local ok, code, detail = V.fields(value, {
      x = "number", y = "number", tile = "number", attr = "number",
    })
    if not ok then return nil, code, detail end
    for _, field in ipairs({ "x", "y", "tile", "attr" }) do
      ok, code, detail = V.integer(value[field], "anims.oam." .. field,
        0, 255)
      if not ok then return nil, code, detail end
    end
    return true
  end

  local function gameFreakTileRow(value, key)
    if type(value) ~= "table" then
      return V.fail("shape_type", "tiles[" .. tostring(key) .. "]:table")
    end
    for column, tile in pairs(value) do
      if type(column) ~= "number" or not V.isInteger(column)
          or column < 0 or column > 19 then
        return V.fail("shape_array", "tiles.column")
      end
      local ok, code, detail = V.integer(tile, "tiles.tile", 0, 255)
      if not ok then return nil, code, detail end
    end
    return true
  end

  local function gameFreakTiles(value)
    if type(value) ~= "table" then return V.fail("shape_type", "tiles:table") end
    for row, tiles in pairs(value) do
      if type(row) ~= "number" or not V.isInteger(row)
          or row < 0 or row > 17 then
        return V.fail("shape_array", "tiles.row")
      end
      local ok, code, detail = gameFreakTileRow(tiles, row)
      if not ok then return nil, code, detail end
    end
    return true
  end

  local function gameFreakBase(state)
    local ok, code, detail = V.fields(state, {
      scene = "number", timer = "number", obp1 = "number",
      tiles = "table", anims = "table", frames = "number",
      done = "boolean", exitTail = { "nil", "number" },
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.scene, "scene", 0, 5)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.timer, "timer", 0, 128)
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.obp1, "obp1", 0, 255)
    if not ok then return nil, code, detail end
    ok, code, detail = V.nonNegative(state.frames, "frames")
    if not ok then return nil, code, detail end
    if state.exitTail ~= nil then
      ok, code, detail = V.integer(state.exitTail, "exitTail", 0, 17)
      if not ok then return nil, code, detail end
    end
    ok, code, detail = gameFreakTiles(state.tiles)
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.anims.oam, "anims.oam", 0,
      gameFreakOamEntry)
    if not ok then return nil, code, detail end
    return true
  end

  local function eggHatchSprite(value, index)
    if type(value) ~= "table" then
      return V.fail("shape_type", "sprites[" .. tostring(index) .. "]:table")
    end
    local ok, code, detail = V.fields(value, {
      kind = "string", x = "number", y = "number",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.enum(value.kind, "sprites.kind",
      { "crack", "fragment" })
    if not ok then return nil, code, detail end
    for _, field in ipairs({ "x", "y" }) do
      ok, code, detail = V.integer(value[field], "sprites." .. field, 0, 255)
      if not ok then return nil, code, detail end
    end
    for _, field in ipairs({ "flipX", "flipY" }) do
      ok, code, detail = V.optionalType(value[field], "boolean",
        "sprites." .. field)
      if not ok then return nil, code, detail end
    end
    for _, field in ipairs({ "angle", "var1", "xOffset", "yOffset" }) do
      ok, code, detail = V.optionalType(value[field], "number",
        "sprites." .. field)
      if not ok then return nil, code, detail end
      if value[field] ~= nil then
        ok, code, detail = V.integer(value[field], "sprites." .. field,
          0, 255)
        if not ok then return nil, code, detail end
      end
    end
    return true
  end

  local function eggHatchBeat(value, index)
    if type(value) ~= "table" then
      return V.fail("shape_type", "beats[" .. tostring(index) .. "]:table")
    end
    return V.nonNegative(value.frames, "beats.frames")
  end

  local function eggHatchBase(state)
    local ok, code, detail = V.fields(state, {
      mon = "table", species = "string", showMon = "boolean",
      shakeX = "number", sprites = "table", beats = "table",
      beatIndex = "number", beatLeft = "number", done = "boolean",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.shakeX, "shakeX", -2, 2)
    if not ok then return nil, code, detail end
    ok, code, detail = V.index(state.beatIndex, "beatIndex", #state.beats)
    if not ok then return nil, code, detail end
    ok, code, detail = V.nonNegative(state.beatLeft, "beatLeft")
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.beats, "beats", 1, eggHatchBeat)
    if not ok then return nil, code, detail end
    return V.array(state.sprites, "sprites", 0, eggHatchSprite)
  end

  local function evolutionRound(value, index)
    if type(value) ~= "table" then
      return V.fail("shape_type", "rounds[" .. tostring(index) .. "]:table")
    end
    local ok, code, detail = V.fields(value, {
      wait = "number", flashes = "number",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(value.wait, "rounds.wait", 0, 255)
    if not ok then return nil, code, detail end
    return V.integer(value.flashes, "rounds.flashes", 0, 255)
  end

  local function evolutionBall(value, index)
    if type(value) ~= "table" then
      return V.fail("shape_type", "balls[" .. tostring(index) .. "]:table")
    end
    local ok, code, detail = V.fields(value, {
      angle = "number", radius = "number", age = "number",
    })
    if not ok then return nil, code, detail end
    for _, field in ipairs({ "angle", "radius", "age" }) do
      ok, code, detail = V.integer(value[field], "balls." .. field, 0, 255)
      if not ok then return nil, code, detail end
    end
    for _, field in ipairs({ "x", "y" }) do
      ok, code, detail = V.optionalType(value[field], "number",
        "balls." .. field)
      if not ok then return nil, code, detail end
      if value[field] ~= nil then
        ok, code, detail = V.integer(value[field], "balls." .. field,
          -255, 255)
        if not ok then return nil, code, detail end
      end
    end
    return true
  end

  local function evolutionBase(state)
    local ok, code, detail = V.fields(state, {
      mon = "table", entry = "table", oldSpecies = "string",
      newSpecies = "string", nick = "string", newName = "string",
      rounds = "table", canceled = "boolean", learned = "table",
      full = "table", balls = "table", ballFrame = "number",
      showNew = "boolean", blackout = "boolean", phase = "string",
      timer = "number",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.enum(state.phase, "phase", {
      "evolving", "cry", "flash", "reveal", "stopped", "congrats",
      "paragraph", "evolved", "learn", "done",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.nonNegative(state.ballFrame, "ballFrame")
    if not ok then return nil, code, detail end
    ok, code, detail = V.nonNegative(state.timer, "timer")
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.rounds, "rounds", 1, evolutionRound)
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(state.balls, "balls", 0, evolutionBall)
    if not ok then return nil, code, detail end
    for _, field in ipairs({ "learned", "full" }) do
      ok, code, detail = V.array(state[field], field, 0)
      if not ok then return nil, code, detail end
    end
    return true
  end

  local function introOamEntry(value, index)
    if type(value) ~= "table" then
      return V.fail("shape_type", "anims.oam[" .. tostring(index) .. "]:table")
    end
    local ok, code, detail = V.fields(value, {
      x = "number", y = "number", tile = "number", attr = "number",
    })
    if not ok then return nil, code, detail end
    for _, field in ipairs({ "x", "y", "tile", "attr" }) do
      ok, code, detail = V.integer(value[field], "anims.oam." .. field,
        0, 255)
      if not ok then return nil, code, detail end
    end
    return true
  end

  local function goldSilverIntroBase(state)
    local ok, code, detail = V.fields(state, {
      scene = "number", frames = "number", done = "boolean",
      scx = "number", scy = "number", counter1 = "number",
      counter2 = "number", bgp = "number", obp0 = "number",
      lyActive = "boolean", lyOverrides = "table", bgmap = "table",
      anims = "table",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.integer(state.scene, "scene", 1, 17)
    if not ok then return nil, code, detail end
    ok, code, detail = V.nonNegative(state.frames, "frames")
    if not ok then return nil, code, detail end
    for _, field in ipairs({ "scx", "scy", "counter1", "counter2",
        "bgp", "obp0" }) do
      ok, code, detail = V.integer(state[field], field, 0, 255)
      if not ok then return nil, code, detail end
    end
    if #state.bgmap ~= 32 * 32 then
      return V.fail("shape_range", "bgmap")
    end
    ok, code, detail = V.array(state.bgmap, "bgmap", 32 * 32)
    if not ok then return nil, code, detail end
    if #state.lyOverrides ~= 144 then
      return V.fail("shape_range", "lyOverrides")
    end
    ok, code, detail = V.array(state.lyOverrides, "lyOverrides", 144)
    if not ok then return nil, code, detail end
    local anims = state.anims
    if type(anims.oam) ~= "table" then
      return V.fail("shape_type", "anims.oam:array")
    end
    return V.array(anims.oam, "anims.oam", 0, introOamEntry)
  end

  return {
    deferred("Gen2BattleState", "src.ui.gen2.BattleState", true,
      "battle UI rewrite deferred; keep the official battle renderer native"),
    deferred("Gen2BattleTransition", "src.ui.gen2.BattleTransition", false,
      "battle UI rewrite deferred; keep the official battle transition native"),
    native("Gen2CardFlip", "src.ui.gen2.CardFlip", "minigames", true,
      "spatial animated minigame"),
    native("Gen2CopyrightSplash", "src.ui.gen2.CopyrightSplash", "cinematics",
      true, "native boot splash remains source-owned for the initial release"),
    Record.new({
      id = "Gen2Credits", module = "src.ui.gen2.Credits",
      support = "supported", milestone = "0.2.0", family = "cinematics",
      preset = "ANIMATION", opaque = true, toggle = "menus",
      presentationApi = 3, validateBase = creditsBase,
      gallery = { "credits" },
    }),
    Record.new({
      id = "Gen2EggHatchAnim", module = "src.ui.gen2.EggHatchAnim",
      support = "supported", milestone = "0.2.0", family = "cinematics",
      preset = "ANIMATION", opaque = true, toggle = "menus",
      presentationApi = 3, validateBase = eggHatchBase,
      gallery = { "hatch" },
    }),
    Record.new({
      id = "Gen2EvolutionAnim", module = "src.ui.gen2.EvolutionAnim",
      support = "supported", milestone = "0.2.0", family = "cinematics",
      preset = "ANIMATION", opaque = true, toggle = "menus",
      presentationApi = 3, validateBase = evolutionBase,
      gallery = { "flash", "reveal" },
    }),
    native("Gen2GoldSilverIntro", "src.ui.gen2.GoldSilverIntro", "cinematics",
      true, "native intro remains source-owned until its raster seam is proven"),
    native("Gen2GameFreakPresents", "src.ui.gen2.GameFreakPresents",
      "cinematics", true,
      "native Game Freak intro remains source-owned until its raster seam is proven"),
    native("Gen2MagnetTrainRide", "src.ui.gen2.MagnetTrainRide", "cinematics", true,
      "timed travel and world animation"),
    native("Gen2OakSpeech", "src.ui.gen2.OakSpeech", "cinematics", true,
      "Oak artwork and parent sequence remain source-owned"),
    nativeWithGallery("Gen2Pokegear", "src.ui.gen2.Pokegear", "services", true,
      "Pokegear replacement disabled pending a clean redesign; keep the official device renderer source-owned",
      { "strip", "clock", "map", "fly", "radio", "phone",
        "phone_submenu", "call", "no_signal" }),
    nativeWithGallery("Gen2MapRadio", "src.ui.gen2.MapRadio", "services", false,
      "Pokegear-family replacement disabled pending a clean redesign; keep the official radio renderer source-owned",
      { "station" }),
    native("Gen2SlotMachine", "src.ui.gen2.SlotMachine", "minigames", true,
      "coordinate-driven animated minigame"),
    native("Gen2TitleState", "src.ui.gen2.TitleState", "cinematics", true,
      "native title screen remains source-owned for the initial release"),
    native("Gen2TradeAnim", "src.ui.gen2.TradeAnim", "cinematics", true,
      "animation-heavy trade sequence"),
    native("Gen2UnownPuzzle", "src.ui.gen2.UnownPuzzle", "minigames", true,
      "direct-manipulation spatial puzzle"),
  }
end
