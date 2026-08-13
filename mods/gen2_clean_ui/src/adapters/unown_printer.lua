return function(ctx)
  local Common = ctx.load("adapters.specialty_common")
  local Party = ctx.load("adapters.party")
  local Printer = {}

  function Printer.extract(state)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    for _, key in ipairs({ "pokemon", "palettes", "picCache" }) do
      if type(rawget(state, key)) ~= "table" then
        return Common.fail("shape_type", key .. ":table")
      end
    end
    if type(rawget(state, "done")) ~= "boolean" then
      return Common.fail("shape_type", "done:boolean")
    end
    if rawget(state, "done") then return Common.fail("state_done", "printer") end
    local index = Common.integer(rawget(state, "index"), 0, 26)
    if not index then return Common.fail("cursor_invalid", "index") end

    local letter, artwork
    if index < 26 then
      letter = string.char(65 + index)
      local code, detail
      artwork, code, detail = Party.artworkFor(state, {
        species="UNOWN", unownLetter=letter, shiny=false,
      })
      if not artwork then return Common.fail(code, detail) end
    end
    local actions = Common.actionMap("Gen2UnownPrinter", {
      { input="left", id="printer.previous", kind="previous" },
      { input="right", id="printer.next", kind="next" },
      { input="a", id="printer.print", kind="printer_unavailable" },
      { input="b", id="printer.close", kind="close" },
    })
    return Common.bundle("Gen2UnownPrinter", {
      family="services", preset="L", title="ALPH RUINS STAMP",
      mode="forms", navigation={ zeroBased=true, index=index,
        slot=index + 1, slotCount=27 },
      letter=letter, vacant=letter == nil, artwork=artwork,
      menu={
        { input="a", label="PRINT", available=false },
        { input="b", label="CANCEL", available=true },
        { input="left", label="BEFORE", available=true },
        { input="right", label="NEXT", available=true },
      },
      controls={ a="PRINTER UNAVAILABLE", b="CLOSE",
        left="BEFORE", right="NEXT" },
    }, actions)
  end

  return Printer
end
