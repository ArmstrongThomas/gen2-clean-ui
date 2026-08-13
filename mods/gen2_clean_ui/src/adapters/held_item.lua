return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.service_common")
  local HeldItem = {}
  local SCREEN_ID = "Gen2HeldItemMenu"

  local function itemName(state, itemId)
    local items = rawget(state, "items")
    local definition = type(items) == "table" and rawget(items, itemId) or nil
    return Data.text(type(definition) == "table"
      and rawget(definition, "name") or nil, Data.text(itemId, "NONE"))
  end

  function HeldItem.extract(state, context)
    local ok, code, detail = Common.exactState(state, SCREEN_ID)
    if not ok then return nil, code, detail end
    if Common.inBattle(context) then return nil, "battle_owned", SCREEN_ID end
    if type(rawget(state, "save")) ~= "table"
        or type(rawget(state, "items")) ~= "table" then
      return Common.fail("shape_type", "held-item data tables")
    end
    if type(rawget(state, "busy")) ~= "boolean" then
      return Common.fail("shape_type", "busy:boolean")
    end
    if rawget(state, "busy") == true then
      return Common.fail("nested_child_active", "Pack or MailCompose")
    end
    local slot = Common.integer(rawget(state, "slot"), 1, 6)
    local index = Common.integer(rawget(state, "index"), 1, 2)
    if not slot or not index then return Common.fail("shape_range", "selection") end
    local save = rawget(state, "save")
    local party = rawget(save, "party")
    local monSource = type(party) == "table" and rawget(party, slot) or nil
    if type(monSource) ~= "table" or rawget(monSource, "isEgg") == true then
      return Common.fail("shape_type", "party[slot]")
    end
    local mon = Common.mon(monSource)
    mon.artwork = Common.optionalArtwork(state, monSource)
    mon.heldName = itemName(state, rawget(monSource, "item"))
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
    if message and confirm then
      return Common.fail("shape_conflict", "message+confirm")
    end
    local actions = Common.inputActions(SCREEN_ID, {
      { input="up", kind="navigate" }, { input="down", kind="navigate" },
      { input="a", kind="choose" }, { input="b", kind="cancel" },
    })
    local rows = {
      { id="give", sourceIndex=1, label="GIVE", selected=index == 1,
        actionId=Common.sourceInput(actions, "choice.give", "choose", "give",
          "a", 1) },
      { id="take", sourceIndex=2, label="TAKE", selected=index == 2,
        actionId=Common.sourceInput(actions, "choice.take", "choose", "take",
          "a", 2) },
    }
    return Common.bundle({
      schema="clean_ui.presenter_model.v1",
      screenId=SCREEN_ID, family="services", preset="L",
      title="HELD ITEM", slot=slot,
      mode=confirm and "confirm" or message and "message" or "give_take",
      rows=rows, navigation={ selectedIndex=index },
      pokemon=mon, message=message, confirm=confirm,
    }, actions)
  end

  return HeldItem
end
