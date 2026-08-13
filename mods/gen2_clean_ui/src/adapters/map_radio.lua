return function(ctx)
  local Data = ctx.load("adapters.data")
  local Actions = ctx.load("adapters.actions")
  local GearData = ctx.load("adapters.pokegear_data")
  local MapRadio = {}

  local function sourceInput(actions, id, input)
    return Actions.add(actions, {
      id=id, source="screen.update", kind="close",
      componentId="map_radio", dispatch="source_input", input=input,
    })
  end

  function MapRadio.extract(state, context)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    if rawget(state, "screenId") ~= "Gen2MapRadio" then
      return nil, "screen_id_mismatch", tostring(rawget(state, "screenId"))
    end
    if GearData.rejectCustomDraw(state) then return nil, "custom_draw" end
    if GearData.battleOwned(state, context) then return nil, "battle_owned" end
    local gear = rawget(state, "gear")
    if type(gear) ~= "table" then
      return nil, "gear_shape", "table"
    end
    if type(rawget(gear, "save")) ~= "table"
        or type(rawget(gear, "cards")) ~= "table"
        or not GearData.integer(Data.integer(rawget(gear, "station")), 1, 8)
        or type(rawget(gear, "radioOn")) ~= "boolean" then
      return nil, "gear_shape", "Pokegear state"
    end
    local station = Data.id(rawget(state, "station"))
    local radio = rawget(state, "radio")
    local hold = Data.integer(rawget(state, "hold"))
    if not station or type(radio) ~= "table"
        or not GearData.integer(hold, 0, 100) then
      return nil, "map_radio_shape"
    end
    local top = rawget(radio, "top")
    local bottom = rawget(radio, "bottom")
    if type(top) ~= "string" or type(bottom) ~= "string" then
      return nil, "map_radio_shape", "radio lines"
    end
    local name = Data.text(rawget(state, "stationName"),
      GearData.stationName(station))
    if name == "" then return nil, "map_radio_shape", "station name" end

    local actions = Actions.new("Gen2MapRadio")
    local controls = {
      closeA=sourceInput(actions, "map_radio.close_a", "a"),
      closeB=sourceInput(actions, "map_radio.close_b", "b"),
    }
    local lines = {}
    if top ~= "" then lines[#lines + 1] = Data.text(top) end
    if bottom ~= "" then lines[#lines + 1] = Data.text(bottom) end
    if #lines == 0 then lines[1] = "\226\128\156" .. name .. "\226\128\157" end
    local model = {
      schema="clean_ui.presenter_model.v1",
      screenId="Gen2MapRadio",
      family="pokegear",
      preset="L",
      title="RADIO",
      view="station",
      station={
        id=station,
        name=name,
        channel=Data.integer(rawget(state, "channel")),
      },
      broadcast={
        lines=lines,
        top=Data.text(top),
        bottom=Data.text(bottom),
        music=Data.id(rawget(radio, "music")),
        current=Data.id(rawget(radio, "cur")),
        delay=Data.integer(rawget(radio, "delay"), 0),
      },
      hold=hold,
      inputReady=hold == 0,
      controls=controls,
    }
    model.actionDescriptors = Actions.describe(actions)
    if not Data.isFunctionFree(model) then return nil, "model_not_data_only" end
    return { model=model, actions=actions }
  end

  return MapRadio
end
