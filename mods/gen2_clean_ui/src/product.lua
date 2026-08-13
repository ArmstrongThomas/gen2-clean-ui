return function(ctx)
  local mod = ctx.mod
  local Settings = ctx.load("settings")
  local Catalog = ctx.load("contracts.catalog")
  local Shared = ctx.load("contracts.shared")
  local Provider = ctx.load("provider.init")
  local FoundationModels = ctx.load("presenters.foundation_models")
  local FoundationPresenters = ctx.load("presenters.foundation_presenters")
  local SharedModels = ctx.load("presenters.shared_models")
  local SharedPresenters = ctx.load("presenters.shared_presenters")
  local PartyModels = ctx.load("presenters.party_models")
  local PartyPresenters = ctx.load("presenters.party_presenters")
  local PackPresenter = ctx.load("presenters.pack")
  local PokedexPresenter = ctx.load("presenters.pokedex")
  local TrainerCardPresenter = ctx.load("presenters.trainer_card")
  local SaveMenuPresenter = ctx.load("presenters.save_menu")
  local NamingStorageModels = ctx.load("presenters.naming_storage_models")
  local NamingStoragePresenters = ctx.load(
    "presenters.naming_storage_presenters")
  local PokegearPresenters = ctx.load("presenters.pokegear")
  local MapRadioPresenters = ctx.load("presenters.map_radio")
  local ServicesCommerceModels = ctx.load(
    "presenters.services_commerce_models")
  local ServicesCommercePresenters = ctx.load(
    "presenters.services_commerce_presenters")
  local MailSpecialtyModels = ctx.load("presenters.mail_specialty_models")
  local MailSpecialtyPresenters = ctx.load(
    "presenters.mail_specialty_presenters")
  local BattlePresenter = ctx.load("presenters.battle")
  local ProductionGalleryModels = ctx.load(
    "presenters.production_gallery_models")
  local PokegearGalleryModels = ctx.load(
    "presenters.pokegear_gallery_models")
  local ServicesCommerceGalleryModels = ctx.load(
    "presenters.services_commerce_gallery_models")
  local MailSpecialtyGalleryModels = ctx.load(
    "presenters.mail_specialty_gallery_models")
  local CoreBridge = ctx.load("integration.core_bridge")
  local ModernCompatibility = ctx.load("compatibility.modern_api")
  local Gallery = ctx.load("gallery.catalog")

  local Product = {}

  local function append(target, source)
    for _, value in ipairs(source or {}) do target[#target + 1] = value end
    return target
  end

  local function mustRegister(label, callback)
    local ok, code, detail = callback()
    if not ok then
      error(("unable to register %s: %s: %s"):format(label,
        tostring(code), tostring(detail)), 0)
    end
  end

  local function markImplemented(catalog, ids)
    for _, id in ipairs(ids or {}) do
      local record = catalog.byId[id]
      if record then record.implementation = "production_presenter" end
    end
  end

  function Product.start()
    local settings = Settings.new(mod, ctx)
    local catalog = Catalog.build()
    local shared = Shared.build()
    local provider = Provider.new({
      catalog = catalog,
      shared = shared,
      mod = mod,
    })
    local modernCompatibility = ModernCompatibility.new(mod, provider)
    provider.compatibility = modernCompatibility
    mustRegister("Gen2 foundation models",
      function() return FoundationModels.register(provider) end)
    mustRegister("shared models",
      function() return SharedModels.register(provider) end)
    mustRegister("Gen2 Party/Summary models",
      function() return PartyModels.register(provider) end)
    mustRegister("Gen2 Naming/Storage models",
      function() return NamingStorageModels.register(provider) end)
    mustRegister("Gen2 Pokegear/MapRadio", function()
      local ok, code, detail = PokegearPresenters.register(provider)
      if not ok then return nil, code, detail end
      return MapRadioPresenters.register(provider)
    end)
    mustRegister("Gen2 services/commerce models",
      function() return ServicesCommerceModels.register(provider) end)
    mustRegister("Gen2 mail/specialty models",
      function() return MailSpecialtyModels.register(provider) end)
    mustRegister("Gen2 Pack",
      function() return PackPresenter.register(provider) end)
    mustRegister("Gen2 Pokedex",
      function() return PokedexPresenter.register(provider) end)
    mustRegister("Gen2 Trainer Card",
      function() return TrainerCardPresenter.register(provider) end)
    mustRegister("Gen2 Save",
      function() return SaveMenuPresenter.register(provider) end)
    mustRegister("Gen2 foundation presenters",
      function() return FoundationPresenters.register(provider) end)
    mustRegister("shared presenters",
      function() return SharedPresenters.register(provider) end)
    mustRegister("Gen2 Party/Summary presenters",
      function() return PartyPresenters.register(provider) end)
    mustRegister("Gen2 Naming/Storage presenters",
      function() return NamingStoragePresenters.register(provider) end)
    mustRegister("Gen2 services/commerce presenters",
      function() return ServicesCommercePresenters.register(provider) end)
    mustRegister("Gen2 mail/specialty presenters",
      function() return MailSpecialtyPresenters.register(provider) end)
    mustRegister("Gen2 battle presenter",
      function() return BattlePresenter.register(provider) end)

    local productionScreens = {}
    append(productionScreens, FoundationModels.ids())
    append(productionScreens, PartyModels.ids())
    append(productionScreens, {
      "Gen2BattleState", "Gen2PackMenu", "Gen2PokedexMenu",
      "Gen2TrainerCard", "Gen2SaveMenu",
    })
    append(productionScreens, NamingStorageModels.ids())
    append(productionScreens, { "Gen2Pokegear", "Gen2MapRadio" })
    append(productionScreens, ServicesCommerceModels.ids())
    append(productionScreens, MailSpecialtyModels.ids())
    markImplemented(catalog, productionScreens)
    markImplemented(shared, SharedModels.ids())

    local galleryFixtures = FoundationModels.galleryFixtures()
    append(galleryFixtures, SharedModels.galleryFixtures())
    append(galleryFixtures, ProductionGalleryModels.galleryFixtures())
    append(galleryFixtures, PokegearGalleryModels.galleryFixtures())
    append(galleryFixtures, ServicesCommerceGalleryModels.galleryFixtures())
    append(galleryFixtures, MailSpecialtyGalleryModels.galleryFixtures())
    local gallery = Gallery.build(catalog, shared, galleryFixtures)
    provider.gallery = gallery
    local bridge = CoreBridge.new(mod, ctx, {
      provider = provider,
      settings = settings,
      gallery = gallery,
    })

    if bridge.status == "ready" then mod.exports.cleanUiHost = bridge.host end
    local modernApi = modernCompatibility:api()
    -- Keep the Modern UI v1/v2 registration surface available under the
    -- current Clean UI product. V3 remains the preferred host contract; this
    -- facade exists so source mods can migrate one product lookup at a time.
    for key, value in pairs(modernApi) do mod.exports[key] = value end
    mod.exports.modernUi = modernApi
    mod.exports.gen2ModernUi = modernApi
    mod.exports.gen2CleanUi = {
      version = mod.version,
      contractVersion = "gen2-v0.1.79",
      coreStatus = bridge.status,
      contracts = catalog.records,
      sharedContracts = shared.records,
      gallery = gallery,
      inspect = function(state, context)
        return provider:inspect(state, context)
      end,
      diagnostics = function()
        return provider.diagnostics:snapshot()
      end,
      extractModel = function(state, context)
        return provider:extractModel(state, context)
      end,
      modelScreens = productionScreens,
      presentationScreens = productionScreens,
      sharedPresentationScreens = SharedModels.ids(),
      resetDefaults = function()
        return settings:resetDefaults()
      end,
      modernUi = modernApi,
    }

    bridge:attachProvider(provider)
    if mod.log and mod.log.info then
      mod.log:info("loaded %d Gen2 contracts; core=%s",
        #catalog.records, bridge.status)
    end
    return Product
  end

  return Product
end
