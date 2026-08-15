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
  local NamingKeyboard = ctx.load("adapters.naming_keyboard")
  local ServicesCommerceModels = ctx.load(
    "presenters.services_commerce_models")
  local ServicesCommercePresenters = ctx.load(
    "presenters.services_commerce_presenters")
  local MailSpecialtyModels = ctx.load("presenters.mail_specialty_models")
  local MailSpecialtyPresenters = ctx.load(
    "presenters.mail_specialty_presenters")
  local BootAnimationPresenter = ctx.load("presenters.boot_animations")
  local CreditsPresenter = ctx.load("presenters.credits")
  local EggHatchPresenter = ctx.load("presenters.egg_hatch")
  local EvolutionPresenter = ctx.load("presenters.evolution")
  local GoldSilverIntroPresenter = ctx.load("presenters.gold_silver_intro")
  local BootAnimationGalleryModels = ctx.load(
    "presenters.boot_animation_gallery_models")
  local CreditsGalleryModels = ctx.load(
    "presenters.credits_gallery_models")
  local EggHatchGalleryModels = ctx.load(
    "presenters.egg_hatch_gallery_models")
  local EvolutionGalleryModels = ctx.load(
    "presenters.evolution_gallery_models")
  local GoldSilverIntroGalleryModels = ctx.load(
    "presenters.gold_silver_intro_gallery_models")
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

  local function installDialogueContinuationHook(settings)
    if not (mod.hooks and type(mod.hooks.wrap) == "function") then
      return nil
    end
    return mod.hooks:wrap("input.step", function(nextFn, game, dt)
      if settings:get("native_dialogue") ~= true
          and type(game) == "table"
          and mod.input and type(mod.input.tap) == "function" then
        local stack = rawget(game, "stack")
        local state = type(stack) == "table" and type(stack.top) == "function"
          and stack:top() or nil
        if type(state) == "table"
            and rawget(state, "waiting") == true
            and rawget(state, "contAdvance") == true
            and (tonumber(rawget(state, "preWait")) or 0) <= 0
            and rawget(state, "done") ~= true then
          pcall(mod.input.tap, mod.input, game, "a")
        end
      end
      return nextFn(game, dt)
    end, 90000)
  end

  local function installNicknameKeyboardHook()
    if not (mod.hooks and type(mod.hooks.wrap) == "function") then
      return false
    end
    local ok = pcall(function()
      mod.hooks:wrap("ui.naming.grid", function(nextFn, grid, context)
        local original = nextFn(grid, context)
        if type(context) == "table"
            and context.box ~= true
            and context.title == "NICKNAME?" then
          return NamingKeyboard.nickname(context.lower == true)
        end
        return original
      end, 100)
    end)
    return ok
  end

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
    mustRegister("Gen2 credits presenter",
      function() return CreditsPresenter.register(provider) end)
    mustRegister("Gen2 egg hatch presenter",
      function() return EggHatchPresenter.register(provider) end)
    mustRegister("Gen2 evolution presenter",
      function() return EvolutionPresenter.register(provider) end)

    local productionScreens = {}
    append(productionScreens, FoundationModels.ids())
    append(productionScreens, PartyModels.ids())
    append(productionScreens, {
      "Gen2Credits",
      "Gen2EggHatchAnim", "Gen2EvolutionAnim",
      "Gen2PackMenu", "Gen2PokedexMenu",
      "Gen2TrainerCard", "Gen2SaveMenu",
    })
    append(productionScreens, NamingStorageModels.ids())
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
    append(galleryFixtures, BootAnimationGalleryModels.galleryFixtures())
    append(galleryFixtures, CreditsGalleryModels.galleryFixtures())
    append(galleryFixtures, EggHatchGalleryModels.galleryFixtures())
    append(galleryFixtures, EvolutionGalleryModels.galleryFixtures())
    append(galleryFixtures, GoldSilverIntroGalleryModels.galleryFixtures())
    local gallery = Gallery.build(catalog, shared, galleryFixtures)
    provider.gallery = gallery
    local bridge = CoreBridge.new(mod, ctx, {
      provider = provider,
      settings = settings,
      gallery = gallery,
    })
    -- Gen2's released NamingScreen exposes the same draw-only grid hook used
    -- by Gen1 Modern. Keep player/rival/box naming native, and only extend
    -- the caught-Pokemon nickname board with the modern compact keyboard.
    local nicknameKeyboardHook = installNicknameKeyboardHook()
    NamingKeyboard.setNicknameHookAvailable(nicknameKeyboardHook == true)

    if bridge.status == "ready" then mod.exports.cleanUiHost = bridge.host end
    if bridge.status == "ready" then
      installDialogueContinuationHook(settings)
    end
    local modernApi = modernCompatibility:api()
    -- Keep the Modern UI v1/v2 registration surface available under the
    -- current Clean UI product. V3 remains the preferred host contract; this
    -- facade exists so source mods can migrate one product lookup at a time.
    for key, value in pairs(modernApi) do mod.exports[key] = value end
    mod.exports.modernUi = modernApi
    mod.exports.gen2ModernUi = modernApi
    mod.exports.gen2CleanUi = {
      version = mod.version,
      contractVersion = catalog.version,
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
      nicknameKeyboardHook = nicknameKeyboardHook == true,
      coverage = function()
        return provider:coverage()
      end,
      extractModel = function(state, context)
        return provider:extractModel(state, context)
      end,
      modelScreens = productionScreens,
      presentationScreens = productionScreens,
      sharedPresentationScreens = SharedModels.ids(),
      resetDefaults = function()
        -- The v0.1.86 host exposes options:define/get, but not options:set.
        -- Prefer the shared V3 runtime so reset remains usable through its
        -- session-local compatibility fallback on that public API surface.
        if bridge.runtime and type(bridge.runtime.resetDefaults) == "function" then
          return bridge.runtime:resetDefaults()
        end
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
