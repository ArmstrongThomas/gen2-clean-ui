return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.specialty_common")
  local Party = ctx.load("adapters.party")
  local Photo = {}

  local function optionalGender(value)
    if value == nil then return "UNKNOWN" end
    if value == "male" then return "MALE" end
    if value == "female" then return "FEMALE" end
    if value == "genderless" then return "GENDERLESS" end
    return nil
  end

  local function firstMove(state, mon)
    local source = rawget(mon, "moves")
    if source == nil then return { id="-", name="-" } end
    local count, code = Common.arrayCount(source, 4)
    if not count then return nil, code end
    if count == 0 then return { id="-", name="-" } end
    local entry = rawget(source, 1)
    if type(entry) ~= "table" then return nil, "move_entry_type" end
    local id = Common.requiredText(rawget(entry, "id"))
    if not id then return nil, "move_id" end
    local definition = rawget(state, "moves")
    definition = type(definition) == "table" and rawget(definition, id) or nil
    local name = type(definition) == "table"
      and Common.requiredText(rawget(definition, "name")) or nil
    if not name then return nil, "move_definition" end
    return { id=id, name=name }
  end

  function Photo.extract(state)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    for _, key in ipairs({ "mon", "pokemon", "moves", "palettes", "picCache" }) do
      if type(rawget(state, key)) ~= "table" then
        return Common.fail("shape_type", key .. ":table")
      end
    end
    if type(rawget(state, "playerName")) ~= "string"
        or type(rawget(state, "done")) ~= "boolean" then
      return Common.fail("shape_type", "playerName/done")
    end
    if rawget(state, "done") then return Common.fail("state_done", "photo") end

    local mon = rawget(state, "mon")
    local species = Common.requiredText(rawget(mon, "species"))
    local level = Common.integer(rawget(mon, "level"), 1, 100)
    local maxHp = Common.integer(rawget(mon, "maxHp") or rawget(mon, "hp"), 0, 65535)
    local gender = optionalGender(rawget(mon, "gender"))
    if not species or not level or maxHp == nil or not gender then
      return Common.fail("pokemon_incomplete", "species/level/maxHp/gender")
    end
    local definition = rawget(rawget(state, "pokemon"), species)
    if type(definition) ~= "table" then
      return Common.fail("pokemon_definition", species)
    end
    local dex = Common.integer(rawget(definition, "dex"), 1, 251)
    local speciesName = Common.requiredText(rawget(definition, "name"))
    if not dex or not speciesName then
      return Common.fail("pokemon_definition", species .. ".dex/name")
    end
    local artwork, artCode, artDetail = Party.artworkFor(state, mon)
    if not artwork then return Common.fail(artCode, artDetail) end
    local move, moveCode = firstMove(state, mon)
    if not move then return Common.fail(moveCode, species) end

    local actions = Common.actionMap("Gen2PhotoStudio", {
      { input="a", id="photo.close_a", kind="close" },
      { input="b", id="photo.close_b", kind="close" },
    })
    return Common.bundle("Gen2PhotoStudio", {
      family="services", preset="L", title="PHOTO STUDIO", mode="photo",
      pokemon={
        species=species, speciesName=speciesName, dex=dex,
        nickname=Data.text(rawget(mon, "nickname"),
          Data.text(rawget(mon, "name"), speciesName)),
        level=level, maxHp=maxHp, gender=gender,
        shiny=rawget(mon, "shiny") == true,
        trainer=Data.text(rawget(mon, "ot"),
          Data.text(rawget(state, "playerName"), "?")),
        trainerId=Common.integer(rawget(mon, "otId"), 0, 65535) or 0,
        firstMove=move,
      },
      artwork=artwork, controls={ a="CLOSE", b="CLOSE" },
    }, actions)
  end

  return Photo
end
