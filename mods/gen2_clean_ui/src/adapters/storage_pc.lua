return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.storage_common")
  local Pc = {}

  local NUM_BOXES = 14
  local BOX_CAPACITY = 20

  local function boxRows(save, selected, actionMap)
    local output = {}
    for index = 1, NUM_BOXES do
      local list = Common.boxList(save, index)
      local actionId
      if actionMap then
        local Actions = ctx.load("adapters.actions")
        actionId = Actions.add(actionMap, {
          id = "box.choose." .. index,
          source = "screen.update",
          kind = "choose_box",
          componentId = "box_" .. index,
          sourceIndex = index,
          dispatch = "source_input",
          input = "a",
        })
      end
      output[index] = {
        id = "box_" .. index,
        sourceIndex = index,
        label = Common.boxName(save, index),
        count = #list,
        capacity = BOX_CAPACITY,
        right = ("%d/%d"):format(#list, BOX_CAPACITY),
        selected = index == selected,
        actionId = actionId,
      }
    end
    return output
  end

  function Pc.extract(state)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local entries = rawget(state, "entries")
    local index = Data.integer(rawget(state, "index"))
    if type(entries) ~= "table" or index == nil
        or index < 1 or index > #entries then
      return nil, "selection_invalid", "entries/index"
    end
    local mode = rawget(state, "message") ~= nil and "message"
      or rawget(state, "picking") == true and "box_picker" or "root"
    local inputs
    if mode == "message" then
      inputs = {
        { input="a", id="message.advance", kind="continue" },
        { input="b", id="message.dismiss", kind="continue" },
      }
    elseif mode == "box_picker" then
      inputs = {
        { input="up", id="box.previous", kind="navigate" },
        { input="down", id="box.next", kind="navigate" },
        { input="a", id="box.choose", kind="choose_box" },
        { input="b", id="box.cancel", kind="cancel" },
      }
    else
      inputs = {
        { input="up", id="menu.previous", kind="navigate" },
        { input="down", id="menu.next", kind="navigate" },
        { input="a", id="menu.choose", kind="choose" },
        { input="b", id="menu.close", kind="cancel" },
      }
    end
    local actionMap = Common.inputActions("Gen2PcMenu", inputs)
    local rootRows = Common.entryRows(entries, index,
      mode == "root" and actionMap or nil, "row")
    local pickIndex = Data.integer(rawget(state, "pickIndex"),
      Data.integer(type(rawget(state, "save")) == "table"
        and rawget(rawget(state, "save"), "currentBox"), 1))
    pickIndex = math.max(1, math.min(pickIndex, NUM_BOXES))
    local picker = boxRows(rawget(state, "save"), pickIndex,
      mode == "box_picker" and actionMap or nil)
    local pages = rawget(state, "messagePages")
    local page = Data.integer(rawget(state, "messagePage"), 1)
    local message
    if rawget(state, "message") ~= nil then
      message = {
        page = page,
        pageCount = type(pages) == "table" and #pages or 1,
        lines = Common.lines(rawget(state, "message")),
        closes = rawget(state, "messageCloses") == true,
      }
    end
    local model = {
      schema = "clean_ui.presenter_model.v1",
      screenId = "Gen2PcMenu",
      family = "storage",
      preset = "M",
      mode = mode,
      house = rawget(state, "house") == true,
      changedDecorations = rawget(state, "changedDecorations") == true,
      navigation = {
        selectedIndex = mode == "box_picker" and pickIndex or index,
        itemCount = mode == "box_picker" and #picker or #rootRows,
      },
      entries = rootRows,
      picker = {
        selectedIndex = pickIndex,
        currentBox = Data.integer(type(rawget(state, "save")) == "table"
          and rawget(rawget(state, "save"), "currentBox"), 1),
        boxes = picker,
      },
      message = message,
    }
    model.actionDescriptors = Common.describe(actionMap)
    return { model=model, actions=actionMap }
  end

  return Pc
end
