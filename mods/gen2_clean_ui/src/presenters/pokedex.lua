return function(ctx)
  local Data = ctx.load("adapters.data")
  local Adapter = ctx.load("adapters.pokedex")
  local Presenter = {}

  local function row(source, right)
    return {
      id = source.id,
      sourceIndex = source.sourceIndex,
      label = source.label,
      right = right or source.right or source.value,
      disabled = source.disabled == true,
    }
  end

  local function sprite(art)
    if type(art) ~= "table" or type(art.sprite) ~= "string"
        or art.sprite == "" then return nil end
    local descriptor = { path=art.sprite }
    if type(art.palette) == "table" then
      descriptor.palette = Data.copy(art.palette)
    end
    return descriptor
  end

  local function richDetails(art, fields)
    return {
      sprite=sprite(art),
      fields=fields or {},
    }
  end

  local function listPresentation(model)
    local rows = {}
    for index, source in ipairs(model.rows or {}) do
      local number = source.dex and source.dex > 0
        and ("No.%03d"):format(source.dex) or ""
      local owned = source.caught and "  OWNED" or ""
      rows[index] = row(source, number .. owned)
    end
    local current = model.current or {}
    return {
      rows = rows,
      selected = model.navigation.selectedIndex,
      scroll = model.navigation.scroll,
      details = richDetails(current.art, {
        { label = "MODE", value = model.sortMode },
        { label = "SEEN", value = model.totals.seen },
        { label = "OWNED", value = model.totals.caught, style = "accent" },
        { label = "SELECTED", value = current.name or "-----" },
      }),
      description = "A DATA   SELECT OPTIONS   START SEARCH   B BACK",
      art = Data.copy(current.art),
    }
  end

  local function entryPresentation(model)
    local current = model.current
    if type(current) ~= "table" then return nil, "entry_unavailable" end
    local rows = {}
    if not model.entry.newEntry then
      for index, source in ipairs(model.entry.actions or {}) do
        rows[index] = row(source)
      end
    end
    local typeLabel = table.concat(current.types or {}, " / ")
    local details = richDetails(current.art, {
      { label = "NUMBER", value = current.dex or 0 },
      { label = "SPECIES", value = current.kind or "" },
      { label = "TYPE", value = typeLabel },
      { label = "HEIGHT", value = current.caught and current.height or "?" },
      { label = "WEIGHT", value = current.caught and current.weight or "?" },
      { label = "STATUS", value = current.caught and "OWNED" or "SEEN",
        style = "accent" },
    })
    return {
      rows = rows,
      selected = model.entry.newEntry and nil or model.entry.selectedAction,
      scroll = 0,
      details = details,
      description = current.pageLines and #current.pageLines > 0
        and current.pageLines or (model.entry.newEntry
          and "A/B CONTINUE" or "LEFT/RIGHT ACTION   A CHOOSE   B LIST"),
      title = (current.name or "ENTRY") .. "  /  PAGE "
        .. tostring(current.page or 1),
      art = Data.copy(current.art),
      entry = Data.copy(current),
    }
  end

  local function areaPresentation(model)
    local area = model.area
    if type(area) ~= "table" then return nil, "area_unavailable" end
    local rows = {}
    for index, nest in ipairs(area.nests or {}) do
      rows[index] = {
        id = nest.id,
        sourceIndex = index,
        label = nest.name,
        right = (area.region or ""):upper(),
        disabled = true,
      }
    end
    if #rows == 0 then
      rows[1] = {
        id = "area_unknown", sourceIndex = 1,
        label = "AREA UNKNOWN", disabled = true,
      }
    end
    return {
      rows = rows,
      selected = nil,
      scroll = 0,
      details = richDetails(area.art, {
        { label = "POKEMON", value = area.name },
        { label = "REGION", value = (area.region or "johto"):upper(),
          style = "accent" },
        { label = "KNOWN NESTS", value = #area.nests },
      }),
      description = "LEFT/RIGHT REGION   A/B RETURN",
      title = (area.name or "POKEMON") .. " NESTS",
      art = Data.copy(area.art),
      area = Data.copy(area),
    }
  end

  local function optionPresentation(model)
    local rows = {}
    local selectedDescription
    for index, source in ipairs(model.options.rows or {}) do
      rows[index] = row(source, source.mode)
      if index == model.options.selectedIndex then
        selectedDescription = Data.copy(source.description)
      end
    end
    return {
      rows = rows,
      selected = model.options.selectedIndex,
      scroll = 0,
      details = {},
      description = selectedDescription or "A CHOOSE   B/SELECT BACK",
      title = "POKEDEX OPTIONS",
    }
  end

  local function searchPresentation(model)
    local rows = {}
    for index, source in ipairs(model.search.rows or {}) do
      rows[index] = row(source, source.value)
    end
    local description = model.search.message ~= ""
      and model.search.message
      or "LEFT/RIGHT TYPE   A CHOOSE   B/START BACK"
    return {
      rows = rows,
      selected = model.search.selectedIndex,
      scroll = 0,
      details = {
        { label = "RESULTS", value = model.search.resultCount or 0,
          style = model.search.resultsActive and "accent" or nil },
      },
      description = description,
      title = "POKEDEX SEARCH",
    }
  end

  local function unownPresentation(model)
    local rows = {}
    local selected
    for index, source in ipairs(model.unown.rows or {}) do
      rows[index] = row(source, source.word)
      if source.slot == model.unown.selectedSlot then selected = source end
    end
    return {
      rows = rows,
      selected = model.unown.selectedIndex,
      scroll = math.max(0, (model.unown.selectedIndex or 1) - 7),
      details = selected and richDetails(selected.art, {
        { label = "FORM", value = selected.label, style = "accent" },
        { label = "WORD", value = selected.word },
        { label = "CAUGHT ORDER", value = selected.sourceIndex },
      }) or {},
      description = "LEFT/RIGHT FORM   A/B OPTIONS",
      title = "UNOWN MODE",
      art = selected and Data.copy(selected.art) or nil,
    }
  end

  local CONVERT = {
    list = listPresentation,
    entry = entryPresentation,
    area = areaPresentation,
    option = optionPresentation,
    search = searchPresentation,
    unown = unownPresentation,
  }

  function Presenter.convert(model)
    if type(model) ~= "table" or model.screenId ~= "Gen2PokedexMenu" then
      return nil, "invalid_model"
    end
    local convert = CONVERT[model.view]
    if not convert then return nil, "unknown_view", model.view end
    local content, code = convert(model)
    if not content then return nil, code or "conversion_failed" end
    content.kind = "menu"
    content.preset = "L"
    content.opaque = true
    content.title = content.title or ("POKEDEX  /  " .. tostring(model.sortMode))
    content.sourceView = model.view
    content.sourceMode = model.sortMode
    return content
  end

  function Presenter.prepare(_, state, context)
    local bundle, code, detail = Adapter.extract(state, context)
    if not bundle then return nil, code, detail end
    local model, convertCode, convertDetail = Presenter.convert(bundle.model)
    if not model then return nil, convertCode, convertDetail end
    return {
      complete = true,
      model = model,
      sourceModel = bundle.model,
      actions = bundle.actions,
    }
  end

  function Presenter.register(provider)
    if type(provider) ~= "table" then return nil, "invalid_provider" end
    local ok, code, detail = provider:registerModelAdapter(
      "Gen2PokedexMenu", Adapter)
    if not ok then return nil, code, detail end
    return provider:registerPresenter("Gen2PokedexMenu", Presenter)
  end

  return Presenter
end
