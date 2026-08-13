return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.service_common")
  local DayCare = {}
  local SCREEN_ID = "Gen2DayCareMenu"
  local SIDES = { man=true, lady=true, outside=true }

  local function dayCareSnapshot(state)
    local save = rawget(state, "save")
    local source = type(save) == "table" and rawget(save, "dayCare") or nil
    if type(source) ~= "table" then return {} end
    local output = {
      hasEgg=rawget(source, "hasEgg") == true,
      compatible=rawget(source, "compatible") == true,
      stepsToEgg=Common.integer(rawget(source, "stepsToEgg"), 0) or 0,
    }
    for _, side in ipairs({ "man", "lady" }) do
      local slot = rawget(source, side)
      local mon = type(slot) == "table" and rawget(slot, "mon") or nil
      output[side] = {
        introSeen=type(slot) == "table" and rawget(slot, "introSeen") == true,
        mon=Common.mon(mon), artwork=Common.optionalArtwork(state, mon),
      }
    end
    return output
  end

  function DayCare.extract(state, context)
    local ok, code, detail = Common.exactState(state, SCREEN_ID)
    if not ok then return nil, code, detail end
    if Common.inBattle(context) then return nil, "battle_owned", SCREEN_ID end
    for _, field in ipairs({ "save", "data", "textData", "TEXT" }) do
      if type(rawget(state, field)) ~= "table" then
        return Common.fail("shape_type", field .. ":table")
      end
    end
    local side = rawget(state, "side")
    if type(side) ~= "string" or not SIDES[side] then
      return Common.fail("unknown_mode", "side=" .. tostring(side))
    end
    local scriptVar = Common.integer(rawget(state, "scriptVar"), 0)
    local delay = Common.integer(rawget(state, "delay"), 0)
    if not scriptVar or not delay then
      return Common.fail("shape_range", "daycare counters")
    end
    local picking = rawget(state, "picking")
    if picking ~= nil and type(picking) ~= "boolean" then
      return Common.fail("shape_type", "picking:boolean")
    end
    if picking == true then
      return Common.fail("nested_party_picker", "Gen2PartyMenu")
    end
    local message
    message, code, detail = Common.paged(rawget(state, "message"), "message")
    if rawget(state, "message") ~= nil and not message then
      return nil, code, detail
    end
    local confirm
    confirm, code, detail = Common.confirm(rawget(state, "confirm"), "confirm")
    if rawget(state, "confirm") ~= nil and not confirm then
      return nil, code, detail
    end
    if (message and confirm) or (not message and not confirm) then
      return Common.fail("shape_conflict", "daycare overlay")
    end
    local actions = Common.inputActions(SCREEN_ID, {
      { input="up", kind="navigate" }, { input="down", kind="navigate" },
      { input="a", kind="confirm" }, { input="b", kind="cancel" },
    })
    return Common.bundle({
      schema="clean_ui.presenter_model.v1",
      screenId=SCREEN_ID, family="services", preset="L",
      title=side == "lady" and "DAY-CARE LADY"
        or side == "outside" and "DAY-CARE EGG" or "DAY-CARE MAN",
      side=side, mode=confirm and "confirm" or "message",
      scriptVar=scriptVar, delay=delay,
      message=message, confirm=confirm,
      dayCare=dayCareSnapshot(state),
    }, actions)
  end

  return DayCare
end
