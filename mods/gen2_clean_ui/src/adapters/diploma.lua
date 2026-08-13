return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.specialty_common")
  local Diploma = {}

  local CERTIFICATION = {
    "This certifies",
    "that you have",
    "completed the",
    "new POKEDEX.",
    "Congratulations!",
  }

  local function sourceArt(gfx)
    if gfx == nil then return nil end
    if type(gfx) ~= "table" then return nil, "gfx_type" end
    local path = Common.generatedPath(rawget(gfx, "image"))
    local palettes = rawget(gfx, "palettes")
    local palette = type(palettes) == "table"
      and Common.palette(rawget(palettes, 1)) or nil
    local page = rawget(gfx, "page1")
    local width = Common.integer(rawget(gfx, "width"), 1, 64)
    local height = Common.integer(rawget(gfx, "height"), 1, 64)
    local sheetTiles = Common.integer(rawget(gfx, "sheetTiles"), 1, 256)
    if not (path and palette and type(page) == "table"
        and width and height and sheetTiles) then
      return nil
    end
    return {
      kind="certificate_tilemap", path=path, palette=palette,
      paletteMode="gen2_2bpp", width=width, height=height,
      sheetTiles=sheetTiles,
    }
  end

  function Diploma.extract(state)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    local playerName = rawget(state, "playerName")
    if type(playerName) ~= "string" then
      return Common.fail("shape_type", "playerName:string")
    end
    if type(rawget(state, "images")) ~= "table"
        or type(rawget(state, "done")) ~= "boolean" then
      return Common.fail("shape_type", "images/done")
    end
    if rawget(state, "done") then return Common.fail("state_done", "diploma") end
    local art, artCode = sourceArt(rawget(state, "gfx"))
    if artCode then return Common.fail(artCode, "gfx") end
    local actions = Common.actionMap("Gen2Diploma", {
      { input="a", id="diploma.close_a", kind="close" },
      { input="b", id="diploma.close_b", kind="close" },
    })
    return Common.bundle("Gen2Diploma", {
      family="services", preset="L", title="DIPLOMA", mode="diploma",
      playerName=Data.text(playerName, "?"),
      certification=Data.copy(CERTIFICATION), sourceArtwork=art,
      controls={ a="CLOSE", b="CLOSE" },
    }, actions)
  end

  return Diploma
end
