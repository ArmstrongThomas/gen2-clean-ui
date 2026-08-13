return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.specialty_common")
  local Party = ctx.load("adapters.party")
  local Hall = {}

  local function rosterCount(save)
    local hall = type(save) == "table" and rawget(save, "hallOfFame") or nil
    local teams = type(hall) == "table" and rawget(hall, "teams") or nil
    if type(teams) ~= "table" then return 0 end
    local count = 0
    for index = 1, 30 do
      local entry = rawget(teams, index)
      if type(entry) ~= "table"
          or not Common.integer(rawget(entry, "winCount"), 1, 200) then break end
      count = count + 1
    end
    return count
  end

  function Hall.extract(state)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    if rawget(state, "mode") ~= "view" or rawget(state, "phase") ~= "display" then
      return Common.fail("native_scope", "hall_of_fame_induction")
    end
    for _, key in ipairs({ "save", "pokemon", "palettes", "picCache", "entry" }) do
      if type(rawget(state, key)) ~= "table" then
        return Common.fail("shape_type", key .. ":table")
      end
    end
    if type(rawget(state, "done")) ~= "boolean" then
      return Common.fail("shape_type", "done:boolean")
    end
    if rawget(state, "done") then return Common.fail("state_done", "hall") end
    local frames = Common.integer(rawget(state, "frames"), 0)
    local team = Common.integer(rawget(state, "team"), 1, 30)
    local entry = rawget(state, "entry")
    local mons = rawget(entry, "mons")
    local count, countCode = Common.arrayCount(mons, 6)
    if not count or count < 1 then
      return Common.fail(countCode or "roster_empty", "entry.mons")
    end
    local index = Common.integer(rawget(state, "index"), 1, count)
    local winCount = Common.integer(rawget(entry, "winCount"), 1, 200)
    if not frames or not team or not index or not winCount then
      return Common.fail("hall_value_invalid", "frames/team/index/winCount")
    end
    local mon = rawget(mons, index)
    if type(mon) ~= "table" then return Common.fail("pokemon_incomplete", "entry") end
    local species = Common.requiredText(rawget(mon, "species"))
    local level = Common.integer(rawget(mon, "level"), 1, 100)
    local otId = Common.integer(rawget(mon, "otId"), 0, 65535)
    if not species or not level or otId == nil then
      return Common.fail("pokemon_incomplete", "species/level/otId")
    end
    local definition = rawget(rawget(state, "pokemon"), species)
    if type(definition) ~= "table" then
      return Common.fail("pokemon_definition", species)
    end
    local speciesName = Common.requiredText(rawget(definition, "name")) or species
    local dex = Common.integer(rawget(definition, "dex"), 1, 251)
    if not dex then return Common.fail("pokemon_definition", species .. ".dex") end
    local artwork, artCode, artDetail = Party.artworkFor(state, mon)
    if not artwork then return Common.fail(artCode, artDetail) end

    local teamCount = rosterCount(rawget(state, "save"))
    if teamCount < team then
      return Common.fail("roster_incomplete", "save.hallOfFame.teams")
    end
    local actions = Common.actionMap("Gen2HallOfFame", {
      { input="a", id="hall.next_pokemon", kind="next_pokemon" },
      { input="start", id="hall.next_team", kind="next_team" },
      { input="b", id="hall.close", kind="close" },
    })
    return Common.bundle("Gen2HallOfFame", {
      family="services", preset="L", title="HALL OF FAME", mode="viewer",
      roster={ team=team, teamCount=teamCount,
        pokemonIndex=index, pokemonCount=count, winCount=winCount,
        frames=frames },
      pokemon={ species=species, speciesName=speciesName, dex=dex,
        nickname=Data.text(rawget(mon, "nickname"), speciesName),
        level=level, trainerId=otId,
        gender=Data.text(rawget(mon, "gender"), "UNKNOWN"),
        shiny=rawget(mon, "shiny") == true,
        dvs=Data.copy(rawget(mon, "dvs")),
      },
      artwork=artwork,
      controls={ a="NEXT POKEMON", start="NEXT TEAM", b="CLOSE" },
    }, actions)
  end

  return Hall
end
