return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.service_common")
  local Contest = {}
  local SCREEN_ID = "Gen2ContestMenu"

  local function requiredMon(source, field)
    if type(source) ~= "table" then
      return Common.fail("shape_type", field .. ":table")
    end
    local species, code, detail = Common.requiredText(rawget(source, "species"),
      field .. ".species")
    if not species then return nil, code, detail end
    local level = Common.integer(rawget(source, "level"), 1, 100)
    if not level then return Common.fail("shape_range", field .. ".level") end
    local mon = Common.mon(source)
    mon.species, mon.level = species, level
    return mon
  end

  function Contest.extract(state, context)
    local ok, code, detail = Common.exactState(state, SCREEN_ID)
    if not ok then return nil, code, detail end
    -- The only production route currently originates in Gen2BattleState.
    -- The adapter remains useful for Gallery and future audited non-battle
    -- routes, but never claims a battle-owned stack.
    if Common.inBattle(context) then return nil, "battle_owned", SCREEN_ID end
    if type(rawget(state, "save")) ~= "table" then
      return Common.fail("shape_type", "save:table")
    end
    local stock
    stock, code, detail = requiredMon(rawget(state, "stock"), "stock")
    if not stock then return nil, code, detail end
    local caught
    caught, code, detail = requiredMon(rawget(state, "caught"), "caught")
    if not caught then return nil, code, detail end
    local choice = Common.integer(rawget(state, "choice"), 1, 2)
    if not choice then return Common.fail("shape_range", "choice") end
    stock.artwork = Common.optionalArtwork(state, rawget(state, "stock"))
    caught.artwork = Common.optionalArtwork(state, rawget(state, "caught"))
    local actions = Common.inputActions(SCREEN_ID, {
      { input="up", kind="navigate" }, { input="down", kind="navigate" },
      { input="a", kind="confirm" }, { input="b", kind="cancel" },
    })
    local rows = {
      { id="yes", sourceIndex=1, label="SWITCH", selected=choice == 1,
        actionId=Common.sourceInput(actions, "choice.yes", "confirm", "yes",
          "a", 1) },
      { id="no", sourceIndex=2, label="KEEP STOCK", selected=choice == 2,
        actionId=Common.sourceInput(actions, "choice.no", "cancel", "no",
          "a", 2) },
    }
    return Common.bundle({
      schema="clean_ui.presenter_model.v1",
      screenId=SCREEN_ID, family="services", preset="L",
      title="BUG CONTEST", mode="compare", stock=stock, caught=caught,
      rows=rows, navigation={ selectedIndex=choice },
      prompt="Switch the newly caught POKEMON?",
      battleRouteNative=true,
    }, actions)
  end

  return Contest
end
