return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.service_common")
  local Elevator = {}
  local SCREEN_ID = "Gen2ElevatorMenu"

  local FALLBACK = {
    "B4F", "B3F", "B2F", "B1F", "1F", "2F", "3F", "4F", "5F",
    "6F", "7F", "8F", "9F", "10F", "11F", "ROOF",
  }

  local function floorName(state, floorId)
    local names = rawget(state, "floorNames")
    local numeric = Common.integer(floorId, 0)
    local named = type(names) == "table" and numeric
      and rawget(names, numeric + 1) or nil
    return Data.text(named, numeric and FALLBACK[numeric + 1]
      or Data.text(floorId, "?"))
  end

  function Elevator.extract(state, context)
    local ok, code, detail = Common.exactState(state, SCREEN_ID)
    if not ok then return nil, code, detail end
    if Common.inBattle(context) then return nil, "battle_owned", SCREEN_ID end
    local floors = rawget(state, "floors")
    local count
    count, code, detail = Common.array(floors, 1, 64, "floors")
    if not count then return nil, code, detail end
    local index = Common.integer(rawget(state, "index"), 1, count)
    local scroll = Common.integer(rawget(state, "scroll"), 0,
      math.max(0, count - 1))
    local origin = rawget(state, "origin")
    if origin ~= nil then origin = Common.integer(origin, 1, count) end
    if not index or not scroll or (rawget(state, "origin") ~= nil and not origin) then
      return Common.fail("shape_range", "elevator selection")
    end
    local actions = Common.inputActions(SCREEN_ID, {
      { input="up", kind="navigate" }, { input="down", kind="navigate" },
      { input="a", kind="choose" }, { input="b", kind="cancel" },
    })
    local rows = {}
    for sourceIndex = 1, count do
      local source = rawget(floors, sourceIndex)
      if type(source) ~= "table" then
        return Common.fail("shape_type", "floors[" .. sourceIndex .. "]")
      end
      local floorId = rawget(source, "floorId")
      local destMap = rawget(source, "destMap")
      if (type(floorId) ~= "number" and type(floorId) ~= "string")
          or (type(destMap) ~= "number" and type(destMap) ~= "string") then
        return Common.fail("shape_type", "floors[" .. sourceIndex .. "] fields")
      end
      rows[sourceIndex] = {
        id="floor_" .. sourceIndex, sourceIndex=sourceIndex,
        label=floorName(state, floorId),
        right=sourceIndex == origin and "CURRENT" or "",
        selected=sourceIndex == index,
        destination={ map=Data.scalar(destMap),
          warp=Data.scalar(rawget(source, "destWarp")),
          floorId=Data.scalar(floorId) },
        actionId=Common.sourceInput(actions, "floor." .. sourceIndex,
          "choose", "floor_" .. sourceIndex, "a", sourceIndex),
      }
    end
    return Common.bundle({
      schema="clean_ui.presenter_model.v1",
      screenId=SCREEN_ID, family="services", preset="S",
      title="ELEVATOR", rows=rows,
      navigation={ selectedIndex=index, scroll=scroll, origin=origin },
      currentFloor=origin and rows[origin].label or "?",
    }, actions)
  end

  return Elevator
end
