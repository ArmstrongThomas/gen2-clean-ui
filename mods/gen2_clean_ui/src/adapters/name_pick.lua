return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.specialty_common")
  local NamePick = {}

  local DEFAULT_PIC = "assets/generated/intro/cal.png"

  function NamePick.extract(state)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    local items = rawget(state, "items")
    local count, code = Common.arrayCount(items, 32)
    if not count or count < 2 then return Common.fail(code or "items_empty", "items") end
    local cursor = Common.integer(rawget(state, "cursor"), 1, count)
    local picX = Common.integer(rawget(state, "picX"), 0, 160)
    local slide = rawget(state, "slide")
    if not cursor then return Common.fail("cursor_invalid", "cursor") end
    if not picX then return Common.fail("pic_position_invalid", "picX") end
    if slide ~= nil and slide ~= "in" and slide ~= "out" then
      return Common.fail("slide_invalid", tostring(slide))
    end
    if slide == "out" and not Common.requiredText(rawget(state, "pendingName")) then
      return Common.fail("pending_name_invalid", "pendingName")
    end
    if type(rawget(state, "fontOk")) ~= "boolean" then
      return Common.fail("shape_type", "fontOk:boolean")
    end
    if rawget(state, "pic") == nil then return Common.fail("sprite_missing", "pic") end
    local suppliedPath = rawget(state, "picPath")
    local path = suppliedPath ~= nil and Common.generatedPath(suppliedPath)
      or DEFAULT_PIC
    if not path then return Common.fail("sprite_path_invalid", tostring(suppliedPath)) end
    local palette = Common.palette(rawget(state, "picColors"))
    if not palette then return Common.fail("sprite_palette_missing", "picColors") end
    local rows = {}
    for index = 1, count do
      local label = Common.requiredText(rawget(items, index))
      if not label then return Common.fail("item_invalid", tostring(index)) end
      rows[index] = Common.row("name_" .. index, label, index, nil,
        slide ~= nil)
      rows[index].selected = index == cursor
    end
    local actions = Common.actionMap("Gen2NamePick", {
      { input="up", id="name.up", kind="navigate", enabled=slide == nil },
      { input="down", id="name.down", kind="navigate", enabled=slide == nil },
      { input="a", id="name.choose", kind="choose", enabled=slide == nil },
      { input="start", id="name.choose_start", kind="choose",
        enabled=slide == nil },
    })
    return Common.bundle("Gen2NamePick", {
      family="services", preset="M", title="CHOOSE YOUR NAME",
      mode=slide and "slide" or "presets", slide=slide, picX=picX,
      navigation={ selectedIndex=cursor, rowCount=count }, rows=rows,
      selectedName=Data.text(rawget(items, cursor), ""),
      sprite={ kind="trainer_front", path=path, palette=palette,
        paletteMode="gen2_2bpp", trueColor=false },
      namingAvailable=rawget(state, "fontOk") == true,
      pendingName=Data.text(rawget(state, "pendingName"), ""),
      controls={ a="CHOOSE", start="CHOOSE", b="DISABLED" },
    }, actions)
  end

  return NamePick
end
