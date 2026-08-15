return function(ctx)
  local Adapter = ctx.load("adapters.trainer_card")
  local Presenter = {}

  local function canonical(model)
    model.schema = "clean_ui.v3.presentation.v1"
    model.apiVersion = 3
    return model
  end

  local function trainerRows(model)
    local time = model.playTime or {}
    return {
      { id = "name", sourceIndex = 1, label = "NAME",
        right = model.player.name },
      { id = "id", sourceIndex = 2, label = "ID No.",
        right = ("%05d"):format(model.player.id or 0) },
      { id = "money", sourceIndex = 3, label = "MONEY",
        right = tostring(model.player.money or 0) },
      { id = "pokedex", sourceIndex = 4, label = "POKEDEX",
        right = tostring(model.pokedexCaught or 0) },
      { id = "time", sourceIndex = 5, label = "PLAY TIME",
        right = ("%d:%02d"):format(time.hours or 0, time.minutes or 0) },
      { id = "badges", sourceIndex = 6, label = "BADGES",
        right = "PAGE 2" },
    }
  end

  local function badgeRows(page)
    local output = {}
    for index, badge in ipairs(page.badges or {}) do
      output[index] = {
        id = badge.id,
        sourceIndex = index,
        label = badge.label,
        right = badge.owned and "EARNED" or "----",
      }
    end
    return output
  end

  function Presenter.convert(model)
    if type(model) ~= "table" or model.screenId ~= "Gen2TrainerCard" then
      return nil, "invalid_model"
    end
    if (model.page or 1) > (model.pageCount or 1) then
      return nil, "page_unavailable"
    end
    local page = model.currentPage
    if type(page) ~= "table" then return nil, "page_unavailable" end
    local rows = page.kind == "trainer" and trainerRows(model)
      or badgeRows(page)
    local description = page.kind == "trainer"
      and "A NEXT PAGE   LEFT/RIGHT PAGE   B/START BACK"
      or ("%d / 8 BADGES   LEFT/RIGHT PAGE   A/B BACK"):format(
        page.ownedCount or 0)
    return canonical({
      kind = "menu",
      preset = "L",
      opaque = true,
      title = page.label .. "  /  " .. tostring(model.page)
        .. " OF " .. tostring(model.pageCount),
      rows = rows,
      selected = nil,
      scroll = 0,
      details = {},
      description = description,
      sourcePage = model.page,
      sourcePageId = page.id,
    })
  end

  function Presenter.prepare(_, state, context)
    local bundle, code, detail = Adapter.extract(state, context)
    if not bundle then return nil, code, detail end
    local model, convertCode = Presenter.convert(bundle.model)
    if not model then return nil, convertCode or "conversion_failed" end
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
      "Gen2TrainerCard", Adapter)
    if not ok then return nil, code, detail end
    return provider:registerPresenter("Gen2TrainerCard", Presenter)
  end

  return Presenter
end
