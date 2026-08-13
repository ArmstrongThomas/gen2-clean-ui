return function(ctx)
  local Data = ctx.load("adapters.data")
  local Actions = ctx.load("adapters.actions")
  local Common = {}

  local MAIL_TYPES = {
    FLOWER_MAIL=true, SURF_MAIL=true, LITEBLUEMAIL=true, PORTRAITMAIL=true,
    LOVELY_MAIL=true, EON_MAIL=true, MORPH_MAIL=true, BLUESKY_MAIL=true,
    MUSIC_MAIL=true, MIRAGE_MAIL=true,
  }

  function Common.fail(code, detail)
    return nil, code, detail
  end

  function Common.finite(value)
    return type(value) == "number" and value == value
      and value ~= math.huge and value ~= -math.huge
  end

  function Common.integer(value, minimum, maximum)
    if not Common.finite(value) or value ~= math.floor(value) then return nil end
    if minimum ~= nil and value < minimum then return nil end
    if maximum ~= nil and value > maximum then return nil end
    return value
  end

  function Common.requiredText(value)
    if type(value) ~= "string" or value == "" then return nil end
    return Data.text(value)
  end

  function Common.arrayCount(value, maximum)
    if type(value) ~= "table" then return nil, "shape_type" end
    local count = 0
    while rawget(value, count + 1) ~= nil do
      count = count + 1
      if maximum and count > maximum then return nil, "shape_range" end
    end
    local key = next(value, nil)
    while key ~= nil do
      if type(key) == "number"
          and (key ~= math.floor(key) or key < 1 or key > count) then
        return nil, "shape_array"
      end
      key = next(value, key)
    end
    return count
  end

  function Common.characters(text)
    text = type(text) == "string" and text or ""
    local output, index = {}, 1
    while index <= #text do
      local byte = text:byte(index)
      local width = 1
      if byte and byte >= 0xF0 then width = 4
      elseif byte and byte >= 0xE0 then width = 3
      elseif byte and byte >= 0xC0 then width = 2 end
      output[#output + 1] = text:sub(index, index + width - 1)
      index = index + width
    end
    return output
  end

  function Common.lines(value)
    local output = {}
    local function append(line)
      output[#output + 1] = Data.text(line, "")
    end
    if type(value) == "string" then
      for line in (value .. "\n"):gmatch("(.-)\n") do append(line) end
    elseif type(value) == "table" then
      local count, code = Common.arrayCount(value, 32)
      if not count then return nil, code end
      for index = 1, count do
        local line = rawget(value, index)
        if type(line) ~= "string" then return nil, "line_type" end
        append(line)
      end
    else
      return nil, "line_type"
    end
    return output
  end

  function Common.paged(value, choice)
    if type(value) ~= "table" then return nil, "shape_type" end
    local pages = rawget(value, "pages")
    local count, code = Common.arrayCount(pages, 32)
    if not count or count < 1 then return nil, code or "pages_empty" end
    local page = Common.integer(rawget(value, "page"), 1, count)
    if not page then return nil, "page_index" end
    local lines, lineCode = Common.lines(rawget(pages, page))
    if not lines then return nil, lineCode end
    local output = { page=page, pageCount=count, lines=lines }
    if choice then
      output.selectedChoice = Common.integer(rawget(value, "choice"), 1, 2)
      if not output.selectedChoice then return nil, "choice_index" end
      output.choices = {
        { id="yes", sourceIndex=1, label="YES" },
        { id="no", sourceIndex=2, label="NO" },
      }
    end
    return output
  end

  function Common.generatedPath(value)
    if type(value) ~= "string"
        or value:sub(1, 17) ~= "assets/generated/"
        or value:sub(-4):lower() ~= ".png"
        or value:find("..", 1, true)
        or value:find("\\", 1, true)
        or value:find(":", 1, true) then
      return nil
    end
    return value
  end

  local function color(value)
    if type(value) ~= "table" then return nil end
    local output = {}
    for index = 1, 3 do
      output[index] = Common.integer(rawget(value, index), 0, 255)
      if output[index] == nil then return nil end
    end
    return output
  end

  function Common.palette(value)
    if type(value) ~= "table" then return nil end
    local output = {}
    for index = 1, 4 do
      output[index] = color(rawget(value, index))
      if not output[index] then return nil end
    end
    return output
  end

  function Common.mailEntry(value, index)
    if type(value) ~= "table" then return nil, "entry_type" end
    local mailType = Common.requiredText(rawget(value, "type"))
    local message, author = rawget(value, "message"), rawget(value, "author")
    local authorId = Common.integer(rawget(value, "authorId"), 0, 65535)
    local species = Common.requiredText(rawget(value, "species"))
    if not mailType or not MAIL_TYPES[mailType] then
      return nil, "mail_type_invalid"
    end
    if type(message) ~= "string" or #Common.characters(message) > 32 then
      return nil, "mail_message_invalid"
    end
    if type(author) ~= "string" then return nil, "mail_author_invalid" end
    if authorId == nil then return nil, "mail_author_id_invalid" end
    if not species then return nil, "mail_species_invalid" end
    return {
      index=index, type=mailType, message=Data.text(message, ""),
      author=Data.text(author, ""), authorId=authorId, species=species,
    }
  end

  function Common.activeScreenId(context)
    local game = type(context) == "table" and rawget(context, "game") or nil
    local stack = type(game) == "table" and rawget(game, "stack") or nil
    local states = type(stack) == "table" and rawget(stack, "states") or nil
    local top = type(states) == "table" and rawget(states, #states) or nil
    return type(top) == "table" and rawget(top, "screenId") or nil
  end

  function Common.actionMap(screenId, specs)
    local map = Actions.new(screenId)
    for _, spec in ipairs(specs or {}) do
      Actions.add(map, {
        id=spec.id or ("input." .. tostring(spec.input)),
        source="screen.update", kind=spec.kind or "input",
        componentId=spec.componentId, sourceIndex=spec.sourceIndex,
        dispatch="source_input", input=spec.input,
        enabled=spec.enabled ~= false,
      })
    end
    return map
  end

  function Common.bundle(screenId, model, actionMap)
    if type(model) ~= "table" then return Common.fail("model_type", screenId) end
    model.schema = "clean_ui.presenter_model.v1"
    model.screenId = screenId
    model.actionDescriptors = Actions.describe(actionMap)
    if not Data.isFunctionFree(model) then
      return Common.fail("model_not_data", screenId)
    end
    return { model=model, actions=actionMap }
  end

  function Common.row(id, label, index, right, disabled)
    return {
      id=id, label=label, sourceIndex=index, right=right,
      disabled=disabled == true,
    }
  end

  return Common
end
