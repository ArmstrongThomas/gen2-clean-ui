return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.storage_common")
  local Party = ctx.load("adapters.party")
  local Box = {}

  local BOX_COUNT = 14
  local BOX_CAPACITY = 20
  local PARTY_CAPACITY = 6
  local MOVE_SUBMENU = { "MOVE", "STATS", "CANCEL" }
  local WITHDRAW_SUBMENU = { "WITHDRAW", "STATS", "RELEASE", "CANCEL" }

  local function listAt(state, boxIndex)
    local save = rawget(state, "save")
    if rawget(state, "mode") == "move" and boxIndex == 0 then
      local party = type(save) == "table" and rawget(save, "party") or nil
      return type(party) == "table" and party or {}
    end
    return Common.boxList(save, boxIndex)
  end

  local function currentList(state)
    local save = rawget(state, "save")
    if rawget(state, "mode") == "deposit" then
      local party = type(save) == "table" and rawget(save, "party") or nil
      return type(party) == "table" and party or {}
    end
    return listAt(state, Data.integer(rawget(state, "boxIndex"), 1))
  end

  local function boxName(state, boxIndex)
    if rawget(state, "mode") == "deposit"
        or (rawget(state, "mode") == "move" and boxIndex == 0) then
      return "PARTY <PK><MN>"
    end
    return Common.boxName(rawget(state, "save"), boxIndex)
  end

  local function inputSpecs(state, view)
    if view == "message" then
      return {
        { input="a", id="message.dismiss", kind="continue" },
        { input="b", id="message.dismiss_b", kind="continue" },
      }
    end
    if view == "submenu" then
      return {
        { input="up", id="submenu.previous", kind="navigate" },
        { input="down", id="submenu.next", kind="navigate" },
        { input="a", id="submenu.choose", kind="choose" },
        { input="b", id="submenu.cancel", kind="cancel" },
      }
    end
    if view == "insert" then
      return {
        { input="up", id="insert.previous", kind="navigate" },
        { input="down", id="insert.next", kind="navigate" },
        { input="left", id="insert.previous_box", kind="navigate_box" },
        { input="right", id="insert.next_box", kind="navigate_box" },
        { input="a", id="insert.commit", kind="insert" },
        { input="b", id="insert.cancel", kind="cancel" },
      }
    end
    local specs = {
      { input="up", id="list.previous", kind="navigate" },
      { input="down", id="list.next", kind="navigate" },
      { input="a", id="list.choose", kind="choose" },
      { input="b", id="list.close", kind="cancel" },
    }
    if rawget(state, "mode") ~= "deposit" then
      specs[#specs + 1] =
        { input="left", id="list.previous_box", kind="navigate_box" }
      specs[#specs + 1] =
        { input="right", id="list.next_box", kind="navigate_box" }
    end
    if rawget(state, "mode") == "withdraw" then
      specs[#specs + 1] =
        { input="select", id="list.release", kind="release" }
      specs[#specs + 1] =
        { input="start", id="list.nickname", kind="nickname" }
    end
    return specs
  end

  local function submenu(state)
    local labels = rawget(state, "mode") == "move"
      and MOVE_SUBMENU or WITHDRAW_SUBMENU
    local selected = Data.integer(rawget(state, "submenuIndex"), 1)
    selected = math.max(1, math.min(selected, #labels))
    local rows = {}
    for index, label in ipairs(labels) do
      rows[index] = {
        id = label:lower(), sourceIndex=index, label=label,
        selected=index == selected,
      }
    end
    return { selectedIndex=selected, rows=rows }
  end

  local function panelMon(state)
    local phase = rawget(state, "phase")
    local from = rawget(state, "moveFrom")
    if phase == "insert" and type(from) == "table" then
      local source = listAt(state, Data.integer(rawget(from, "box"), 1))
      return rawget(source, Data.integer(rawget(from, "slot"), 1))
    end
    return rawget(currentList(state), Data.integer(rawget(state, "index"), 1))
  end

  function Box.extract(state)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local mode = rawget(state, "mode")
    if mode ~= "withdraw" and mode ~= "deposit" and mode ~= "move" then
      return nil, "mode_invalid", tostring(mode)
    end
    local boxIndex = Data.integer(rawget(state, "boxIndex"))
    local index = Data.integer(rawget(state, "index"))
    local scroll = Data.integer(rawget(state, "scroll"))
    local minimumBox = mode == "move" and 0 or 1
    if boxIndex == nil or boxIndex < minimumBox or boxIndex > BOX_COUNT then
      return nil, "box_invalid", tostring(boxIndex)
    end
    if index == nil or index < 1 or scroll == nil or scroll < 0 then
      return nil, "selection_invalid", "index/scroll"
    end
    local phase = rawget(state, "phase")
    if phase ~= nil and phase ~= "submenu" and phase ~= "insert" then
      return nil, "phase_invalid", tostring(phase)
    end
    local view = rawget(state, "message") ~= nil and "message"
      or phase or "browse"
    local actionMap = Common.inputActions("Gen2BoxMenu",
      inputSpecs(state, view))
    local list = currentList(state)
    local rows = Common.monRows(list, index,
      view == "browse" and actionMap or nil, {
        pokemon=rawget(state, "pokemon"), prefix="list.choose",
      })
    if phase ~= "insert" then
      rows[#rows + 1] = Common.cancelRow(#list + 1, index,
        view == "browse" and actionMap or nil, "list.choose")
    elseif #rows == 0 then
      rows[1] = {
        id="insert_1", sourceIndex=1, label="INSERT HERE",
        selected=true, insert=true,
      }
    else
      for rowIndex, row in ipairs(rows) do
        row.insert = true
        row.right = rowIndex == index and "INSERT" or ""
      end
    end
    local sourceMon = panelMon(state)
    local selectedMon = Common.mon(sourceMon, rawget(state, "pokemon"))
    if type(sourceMon) == "table" then
      local artwork, artCode, artDetail = Party.artworkFor(state, sourceMon)
      if not artwork then return nil, artCode, artDetail end
      selectedMon.artwork = artwork
    end
    local moveFrom = rawget(state, "moveFrom")
    local backup = rawget(state, "backup")
    local destinationCapacity = mode == "move" and boxIndex == 0
      and PARTY_CAPACITY or BOX_CAPACITY
    local model = {
      schema = "clean_ui.presenter_model.v1",
      screenId = "Gen2BoxMenu",
      family = "storage",
      preset = "XL",
      mode = mode,
      view = view,
      underlyingPhase = phase or "browse",
      title = boxName(state, boxIndex),
      prompt = phase == "submenu" and "What's up?"
        or phase == "insert" and "Move to where?"
        or "Choose a <PK><MN>.",
      navigation = {
        selectedIndex = index,
        scroll = scroll,
        itemCount = #rows,
        visibleRows = 5,
      },
      rows = rows,
      selectedMon = selectedMon,
      destination = {
        boxIndex = boxIndex,
        name = boxName(state, boxIndex),
        count = #list,
        capacity = destinationCapacity,
        isParty = mode == "move" and boxIndex == 0,
      },
      submenu = phase == "submenu" and submenu(state) or nil,
      insert = phase == "insert" and {
        source = type(moveFrom) == "table" and {
          boxIndex=Data.integer(rawget(moveFrom, "box"), 1),
          slot=Data.integer(rawget(moveFrom, "slot"), 1),
        } or nil,
        backup = type(backup) == "table" and {
          boxIndex=Data.integer(rawget(backup, "box"), 1),
          index=Data.integer(rawget(backup, "index"), 1),
          scroll=Data.integer(rawget(backup, "scroll"), 0),
        } or nil,
        positionCount = math.max(1, #list),
      } or nil,
      message = rawget(state, "message") ~= nil
        and Common.message(rawget(state, "message")) or nil,
    }
    model.actionDescriptors = Common.describe(actionMap)
    return { model=model, actions=actionMap }
  end

  return Box
end
