return function(ctx)
  local Data = ctx.load("adapters.data")
  local Actions = ctx.load("adapters.actions")
  local GearData = ctx.load("adapters.pokegear_data")
  local Pokegear = {}

  local function fail(code, detail)
    return nil, code, detail
  end

  local function sourceInput(actions, id, kind, componentId, input, sourceIndex)
    return Actions.add(actions, {
      id=id, source="screen.update", kind=kind,
      componentId=componentId, sourceIndex=sourceIndex,
      dispatch="source_input", input=input,
    })
  end

  local function addControls(actions, view)
    local controls = {}
    local function add(id, kind, input)
      controls[id] = sourceInput(actions, "pokegear." .. view .. "." .. id,
        kind, view, input)
    end
    if view == "strip" then
      add("previous", "navigate", "left")
      add("next", "navigate", "right")
      add("open", "open", "a")
      add("back", "close", "b")
    elseif view == "clock" then
      add("back", "close", "b")
    elseif view == "map" then
      add("previous", "navigate", "down")
      add("next", "navigate", "up")
      add("leftCard", "navigate", "left")
      add("rightCard", "navigate", "right")
      add("back", "close", "b")
    elseif view == "fly" then
      add("previous", "navigate", "down")
      add("next", "navigate", "up")
      add("choose", "choose", "a")
      add("back", "close", "b")
    elseif view == "radio" then
      add("down", "navigate", "down")
      add("up", "navigate", "up")
      add("back", "close", "b")
    elseif view == "phone" then
      add("previous", "navigate", "up")
      add("next", "navigate", "down")
      add("choose", "choose", "a")
      add("back", "close", "b")
    elseif view == "phone_submenu" then
      add("previous", "navigate", "up")
      add("next", "navigate", "down")
      add("choose", "choose", "a")
      add("back", "close", "b")
    elseif view == "call" or view == "no_signal" then
      add("finishA", "close", "a")
      add("finishB", "close", "b")
    end
    return controls
  end

  local function viewFor(state, cards, cardIndex)
    if rawget(state, "fly") ~= nil then return "fly" end
    if rawget(state, "mode") == "strip" then return "strip" end
    local card = cards[cardIndex]
    if not card then return nil end
    if card.id ~= "phone" then return card.id end
    local call = rawget(state, "call")
    if type(call) == "table" then
      return rawget(call, "kind") == "nosignal" and "no_signal" or "call"
    end
    if rawget(state, "phoneSubmenu") ~= nil then return "phone_submenu" end
    return "phone"
  end

  function Pokegear.extract(state, context)
    if type(state) ~= "table" then return fail("state_type", "table") end
    if rawget(state, "screenId") ~= "Gen2Pokegear" then
      return fail("screen_id_mismatch", tostring(rawget(state, "screenId")))
    end
    if GearData.rejectCustomDraw(state) then return fail("custom_draw") end
    if GearData.battleOwned(state, context) then return fail("battle_owned") end
    if type(rawget(state, "save")) ~= "table" then
      return fail("save_shape", "table")
    end
    local mode = rawget(state, "mode")
    if mode ~= "strip" and mode ~= "card" then return fail("mode_shape") end
    if type(rawget(state, "radioOn")) ~= "boolean" then
      return fail("radio_on_shape")
    end
    if not GearData.integer(Data.integer(rawget(state, "station")), 1, 8) then
      return fail("station_range")
    end
    if not GearData.integer(Data.integer(rawget(state, "phoneCursor")), 0, 3)
        or not GearData.integer(Data.integer(rawget(state, "phoneScroll")), 0, 6)
        or not GearData.integer(
          Data.integer(rawget(state, "phoneSubmenuCursor")), 0, 2) then
      return fail("phone_navigation_shape")
    end

    local cards, cardCode, cardDetail = GearData.cards(state)
    if not cards then return fail(cardCode, cardDetail) end
    local cardIndex = Data.integer(rawget(state, "cardIndex"))
    if not GearData.integer(cardIndex, 1, #cards) then
      return fail("card_index_shape")
    end
    local view = viewFor(state, cards, cardIndex)
    if not view then return fail("view_unavailable") end
    if rawget(state, "fly") ~= nil and mode ~= "card" then
      return fail("fly_mode_shape")
    end
    if rawget(state, "fly") ~= nil and type(rawget(state, "fly")) ~= "table" then
      return fail("fly_shape")
    end
    if rawget(state, "fly") ~= nil
        and (#cards ~= 1 or cards[1].id ~= "map") then
      return fail("fly_cards_shape")
    end
    if mode == "strip" and (rawget(state, "call") ~= nil
        or rawget(state, "phoneSubmenu") ~= nil) then
      return fail("strip_busy_shape")
    end

    local clock, clockCode = GearData.clock(state)
    if not clock then return fail(clockCode) end
    local map, mapCode
    if view == "map" or view == "fly" then
      map, mapCode = GearData.map(state)
      if not map then return fail(mapCode) end
    end
    local radio, radioCode, radioDetail
    if view == "radio" then
      radio, radioCode, radioDetail = GearData.radio(state, clock)
      if not radio then return fail(radioCode, radioDetail) end
    end
    local phone, phoneCode, phoneDetail
    if view == "phone" or view == "phone_submenu"
        or view == "call" or view == "no_signal" then
      phone, phoneCode, phoneDetail = GearData.phone(state)
      if not phone then return fail(phoneCode, phoneDetail) end
      if view == "phone_submenu" and not phone.submenu then
        return fail("phone_submenu_shape")
      end
      if (view == "call" or view == "no_signal") and not phone.call then
        return fail("call_shape")
      end
    end

    local actions = Actions.new("Gen2Pokegear")
    for index, card in ipairs(cards) do
      card.selected = index == cardIndex
      card.actionId = sourceInput(actions, "pokegear.card." .. index,
        "open", card.id, "a", index)
    end
    if map then
      for index, row in ipairs(map.flyRows or {}) do
        row.actionId = sourceInput(actions, "pokegear.fly." .. index,
          "choose", row.id, "a", index)
      end
    end
    if phone then
      for index, row in ipairs(phone.rows) do
        if not row.empty then
          row.actionId = sourceInput(actions, "pokegear.phone." .. index,
            "choose", row.id, "a", index)
        end
      end
      for index, row in ipairs(phone.submenu and phone.submenu.rows or {}) do
        row.actionId = sourceInput(actions,
          "pokegear.phone.submenu." .. index, "choose", row.id, "a", index)
      end
    end

    local shell = GearData.shell(state, cards, cardIndex, view, clock,
      map, radio, phone)

    local model = {
      schema="clean_ui.presenter_model.v1",
      screenId="Gen2Pokegear",
      family="pokegear",
      preset="L",
      title="POKEGEAR",
      view=view,
      sourceMode=mode,
      cards=cards,
      activeCard=Data.copy(cards[cardIndex]),
      cardIndex=cardIndex,
      clock=clock,
      map=map,
      radio=radio,
      phone=phone,
      shell=shell,
      controls=addControls(actions, view),
    }
    model.actionDescriptors = Actions.describe(actions)
    if not Data.isFunctionFree(model) then return fail("model_not_data_only") end
    return { model=model, actions=actions }
  end

  return Pokegear
end
