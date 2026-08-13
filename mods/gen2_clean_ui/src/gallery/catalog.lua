return function(ctx)
  local FoundationPresenters = ctx.load("presenters.foundation_presenters")
  local SharedPresenters = ctx.load("presenters.shared_presenters")
  local PartyPresenters = ctx.load("presenters.party_presenters")
  local PackPresenter = ctx.load("presenters.pack")
  local PokedexPresenter = ctx.load("presenters.pokedex")
  local TrainerCardPresenter = ctx.load("presenters.trainer_card")
  local SaveMenuPresenter = ctx.load("presenters.save_menu")
  local NamingStoragePresenters = ctx.load(
    "presenters.naming_storage_presenters")
  local Gallery = {}

  local function slug(id)
    local value = id:gsub("^Gen2", "")
    value = value:gsub("(%l)(%u)", "%1_%2")
    return value:lower()
  end

  local function sharedSlug(id)
    return slug(id:gsub("^[^.]+%.", ""))
  end

  local function modelKey(screenId, variant)
    return tostring(screenId) .. "\0" .. tostring(variant)
  end

  local function convert(screenId, sourceModel)
    if screenId == "Gen2PartyMenu" or screenId == "Gen2SummaryMenu" then
      return PartyPresenters.convert(screenId, sourceModel)
    elseif screenId == "Gen2PackMenu" then
      return PackPresenter.convert(sourceModel)
    elseif screenId == "Gen2PokedexMenu" then
      return PokedexPresenter.convert(sourceModel)
    elseif screenId == "Gen2TrainerCard" then
      return TrainerCardPresenter.convert(sourceModel)
    elseif screenId == "Gen2SaveMenu" then
      return SaveMenuPresenter.convert(sourceModel)
    elseif screenId == "Gen2NamingScreen"
        or screenId == "Gen2CenterPcMenu"
        or screenId == "Gen2PcMenu"
        or screenId == "Gen2BoxMenu"
        or screenId == "Gen2ItemPcMenu" then
      return NamingStoragePresenters.convert(screenId, sourceModel)
    end
    return FoundationPresenters.convert(screenId, sourceModel)
  end

  function Gallery.build(catalog, shared, modelFixtures)
    local models = {}
    for _, fixture in ipairs(modelFixtures or {}) do
      if type(fixture) == "table" and type(fixture.model) == "table" then
        models[modelKey(fixture.screenId, fixture.variant)] = fixture.model
      end
    end
    local fixtures = {}
    for _, record in ipairs(catalog.records) do
      for _, variant in ipairs(record.gallery or { "status" }) do
        local sourceModel = models[modelKey(record.id, variant)]
        local model = sourceModel and convert(record.id, sourceModel) or nil
        fixtures[#fixtures + 1] = {
          id = ("gen2.%s.%s.%s"):format(record.family, slug(record.id), variant),
          screenId = record.id,
          game = "gen2",
          family = record.family,
          variant = variant,
          support = record.support,
          implementation = record.implementation,
          milestone = record.milestone,
          preset = record.preset,
          synthetic = true,
          statusOnly = model == nil,
          modelReady = model ~= nil,
          model = model,
          sourceModel = sourceModel,
          nativeReason = record.nativeReason,
        }
      end
    end
    for _, record in ipairs(shared.records) do
      for _, variant in ipairs(record.gallery or { "status" }) do
        local sourceModel = models[modelKey(record.id, variant)]
        local model = sourceModel and SharedPresenters.convert(
          record.id, sourceModel) or nil
        fixtures[#fixtures + 1] = {
          id = ("gen2.shared.%s.%s"):format(sharedSlug(record.id), variant),
          screenId = record.id,
          game = "gen2", family = record.family, variant = variant,
          support = record.support, implementation = record.implementation,
          milestone = record.milestone, preset = record.preset,
          synthetic = true, statusOnly = model == nil,
          modelReady = model ~= nil, model = model, sourceModel = sourceModel,
        }
      end
    end
    return {
      game = "gen2",
      fixtures = fixtures,
      count = #fixtures,
      sourceContract = catalog.version,
    }
  end

  return Gallery
end
