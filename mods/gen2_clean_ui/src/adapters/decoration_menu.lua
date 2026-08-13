return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.specialty_common")
  local Decoration = {}

  local NAMES = {
    [0]="CANCEL", [1]="PUT IT AWAY", [2]="FEATHERY BED",
    [3]="PINK BED", [4]="POLKADOT BED", [5]="PIKACHU BED",
    [6]="PUT IT AWAY", [7]="RED CARPET", [8]="BLUE CARPET",
    [9]="YELLOW CARPET", [10]="GREEN CARPET", [11]="PUT IT AWAY",
    [12]="MAGNAPLANT", [13]="TROPICPLANT", [14]="JUMBOPLANT",
    [15]="PUT IT AWAY", [16]="TOWN MAP", [17]="PIKACHU POSTER",
    [18]="CLEFAIRY POSTER", [19]="JIGGLYPUFF POSTER",
    [20]="PUT IT AWAY", [21]="NES", [22]="SUPER NES",
    [23]="NINTENDO64", [24]="VIRTUAL BOY", [25]="PUT IT AWAY",
    [26]="BIG SNORLAX", [27]="BIG ONIX", [28]="BIG LAPRAS",
    [29]="PUT IT AWAY", [30]="PIKACHU DOLL",
    [31]="SURF PIKACHU DOLL", [32]="CLEFAIRY DOLL",
    [33]="JIGGLYPUFF DOLL", [34]="BULBASAUR DOLL",
    [35]="CHARMANDER DOLL", [36]="SQUIRTLE DOLL",
    [37]="POLIWAG DOLL", [38]="DIGLETT DOLL", [39]="STARYU DOLL",
    [40]="MAGIKARP DOLL", [41]="ODDISH DOLL", [42]="GENGAR DOLL",
    [43]="SHELLDER DOLL", [44]="GRIMER DOLL", [45]="VOLTORB DOLL",
    [46]="WEEDLE DOLL", [47]="UNOWN DOLL", [48]="GEODUDE DOLL",
    [49]="MACHOP DOLL", [50]="TENTACOOL DOLL",
    [51]="GOLD TROPHY", [52]="SILVER TROPHY",
  }
  local SIDES = {
    { id="right", label="RIGHT SIDE", sourceIndex=1 },
    { id="left", label="LEFT SIDE", sourceIndex=2 },
    { id="cancel", label="CANCEL", sourceIndex=3 },
  }

  local function pageSnapshot(state)
    local pages = rawget(state, "pages")
    if pages == nil then return nil end
    local count, code = Common.arrayCount(pages, 32)
    if not count or count < 1 then return nil, code or "pages_empty" end
    local page = Common.integer(rawget(state, "pageIndex"), 1, count)
    if not page then return nil, "page_index" end
    local lines, lineCode = Common.lines(rawget(pages, page))
    if not lines then return nil, lineCode end
    return { page=page, pageCount=count, lines=lines }
  end

  function Decoration.extract(state)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    local mode = rawget(state, "mode")
    if mode ~= "category" and mode ~= "items" and mode ~= "side" then
      return Common.fail("unknown_mode", tostring(mode))
    end
    if type(rawget(state, "save")) ~= "table"
        or type(rawget(state, "state")) ~= "table" then
      return Common.fail("shape_type", "save/state")
    end
    if type(rawget(state, "changed")) ~= "boolean" then
      return Common.fail("shape_type", "changed:boolean")
    end
    local categories = rawget(state, "categories")
    local categoryCount, categoryCode = Common.arrayCount(categories, 7)
    if not categoryCount then return Common.fail(categoryCode, "categories") end

    local rows, selected, scroll, category
    if mode == "category" then
      selected = Common.integer(rawget(state, "index"), 1, categoryCount + 1)
      if not selected then return Common.fail("cursor_invalid", "index") end
      rows = {}
      for index = 1, categoryCount do
        local source = rawget(categories, index)
        if type(source) ~= "table" then
          return Common.fail("category_type", tostring(index))
        end
        local id = Common.integer(rawget(source, "id"), 1, 52)
        local label = Common.requiredText(rawget(source, "label"))
        if not id or not label then return Common.fail("category_incomplete", tostring(index)) end
        rows[index] = Common.row("category_" .. id, label, index)
      end
      rows[#rows + 1] = Common.row("exit", "EXIT", categoryCount + 1)
      scroll = 0
    elseif mode == "items" then
      local sourceRows = rawget(state, "rows")
      local count, code = Common.arrayCount(sourceRows, 64)
      if not count or count < 1 then return Common.fail(code or "rows_empty", "rows") end
      selected = Common.integer(rawget(state, "index"), 1, count)
      scroll = Common.integer(rawget(state, "scroll"), 0,
        math.max(0, count - 1))
      if not selected then return Common.fail("cursor_invalid", "index") end
      if not scroll then return Common.fail("scroll_invalid", "scroll") end
      rows = {}
      for index = 1, count do
        local id = Common.integer(rawget(sourceRows, index), 0, 52)
        if not id or not NAMES[id] then
          return Common.fail("decoration_invalid", tostring(rawget(sourceRows, index)))
        end
        rows[index] = Common.row("decoration_" .. id, NAMES[id], index)
      end
      local sourceCategory = rawget(state, "category")
      if type(sourceCategory) ~= "table" then
        return Common.fail("category_incomplete", "category")
      end
      local categoryId = Common.integer(rawget(sourceCategory, "id"), 1, 52)
      local categoryLabel = Common.requiredText(rawget(sourceCategory, "label"))
      if not categoryId or not categoryLabel then
        return Common.fail("category_incomplete", "category.id/label")
      end
      category = { id=categoryId, label=categoryLabel }
    else
      selected = Common.integer(rawget(state, "sideIndex"), 1, 3)
      if not selected then return Common.fail("cursor_invalid", "sideIndex") end
      local pending = Common.integer(rawget(state, "pendingDeco"), 0, 52)
      if not pending then return Common.fail("decoration_invalid", "pendingDeco") end
      rows, scroll = Data.copy(SIDES), 0
      category = { pendingId=pending, pendingName=NAMES[pending] }
    end
    for index, row in ipairs(rows) do row.selected = index == selected end

    local message, messageCode = pageSnapshot(state)
    if rawget(state, "pages") ~= nil and not message then
      return Common.fail(messageCode, "pages")
    end
    local actions = Common.actionMap("Gen2DecorationMenu", {
      { input="up", id="decoration.up", kind="navigate" },
      { input="down", id="decoration.down", kind="navigate" },
      { input="a", id="decoration.choose", kind="choose" },
      { input="b", id="decoration.back", kind="back" },
    })
    return Common.bundle("Gen2DecorationMenu", {
      family="services", preset="L", title="DECORATION",
      mode=message and "message" or mode, underlyingMode=mode,
      changed=rawget(state, "changed"),
      navigation={ selectedIndex=selected, scroll=scroll, rowCount=#rows,
        visibleRows=8 }, rows=rows, category=category,
      placement=Data.copy(rawget(state, "state")), message=message,
    }, actions)
  end

  return Decoration
end
