return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.storage_common")
  local CenterPc = {}

  local function playerName(state)
    local save = rawget(state, "save")
    local player = type(save) == "table" and rawget(save, "player") or nil
    return Data.text(type(player) == "table" and rawget(player, "name") or nil,
      "GOLD")
  end

  local function confirmSnapshot(value, replacements)
    if type(value) ~= "table" then return nil end
    local choice = Data.integer(rawget(value, "choice"), 1)
    choice = math.max(1, math.min(choice, 2))
    return {
      prompt = Common.lines(rawget(value, "prompt"), replacements),
      selectedChoice = choice,
      choices = {
        { id="yes", label="YES", sourceIndex=1 },
        { id="no", label="NO", sourceIndex=2 },
      },
    }
  end

  function CenterPc.extract(state)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local entries = rawget(state, "entries")
    local index = Data.integer(rawget(state, "index"))
    if type(entries) ~= "table" or index == nil
        or index < 1 or index > #entries then
      return nil, "selection_invalid", "entries/index"
    end
    local replacements = { ["{PLAYER}"]=playerName(state) }
    local sourceMessage = rawget(state, "message")
    local sourceConfirm = rawget(state, "confirm")
    local mode = sourceMessage ~= nil and "message"
      or sourceConfirm ~= nil and "confirm" or "root"
    local inputs
    if mode == "message" then
      inputs = {
        { input="a", id="message.advance", kind="continue" },
        { input="b", id="message.dismiss", kind="continue" },
      }
    elseif mode == "confirm" then
      inputs = {
        { input="up", id="confirm.previous", kind="navigate" },
        { input="down", id="confirm.next", kind="navigate" },
        { input="a", id="confirm.choose", kind="confirm" },
        { input="b", id="confirm.no", kind="cancel" },
      }
    else
      inputs = {
        { input="up", id="menu.previous", kind="navigate" },
        { input="down", id="menu.next", kind="navigate" },
        { input="a", id="menu.choose", kind="choose" },
        { input="b", id="menu.shutdown", kind="cancel" },
      }
    end
    local actionMap = Common.inputActions("Gen2CenterPcMenu", inputs)
    local rows = Common.entryRows(entries, index,
      mode == "root" and actionMap or nil, "row")
    local model = {
      schema = "clean_ui.presenter_model.v1",
      screenId = "Gen2CenterPcMenu",
      family = "storage",
      preset = "M",
      mode = mode,
      playerName = playerName(state),
      navigation = {
        selectedIndex = index,
        itemCount = #rows,
      },
      entries = rows,
      message = Common.message(sourceMessage, replacements),
      confirm = confirmSnapshot(sourceConfirm, replacements),
      closed = rawget(state, "closed") == true,
    }
    model.actionDescriptors = Common.describe(actionMap)
    return { model=model, actions=actionMap }
  end

  return CenterPc
end
