return function(ctx)
  local Data = ctx.load("adapters.data")
  local MainMenu = ctx.load("adapters.main_menu")
  local StartMenu = ctx.load("adapters.start_menu")
  local OptionsMenu = ctx.load("adapters.options_menu")
  local FoundationModels = {}

  local ORDER = {
    "Gen2MainMenu",
    "Gen2StartMenu",
    "Gen2OptionsMenu",
  }
  local BY_ID = {
    Gen2MainMenu = MainMenu,
    Gen2StartMenu = StartMenu,
    Gen2OptionsMenu = OptionsMenu,
  }

  function FoundationModels.register(provider)
    assert(type(provider) == "table"
      and type(provider.registerModelAdapter) == "function",
      "foundation model registration requires a Gen2 provider")
    for _, screenId in ipairs(ORDER) do
      local ok, code, detail = provider:registerModelAdapter(screenId,
        BY_ID[screenId])
      if not ok then
        return nil, code or "model_registration_failed", detail or screenId
      end
    end
    return true
  end

  function FoundationModels.galleryFixtures()
    local fixtures = {}
    for _, screenId in ipairs(ORDER) do
      local adapter = BY_ID[screenId]
      for _, fixture in ipairs(adapter.fixtures()) do
        local bundle, code, detail = adapter.extract(fixture.state, {
          synthetic = true,
        })
        assert(type(bundle) == "table" and type(bundle.model) == "table",
          ("invalid %s Gallery model: %s %s"):format(
            screenId, tostring(code), tostring(detail)))
        assert(Data.isFunctionFree(bundle.model),
          screenId .. " Gallery model must be function-free")
        fixtures[#fixtures + 1] = {
          screenId = screenId,
          variant = fixture.variant,
          model = bundle.model,
        }
      end
    end
    return fixtures
  end

  function FoundationModels.adapterFor(screenId)
    return BY_ID[screenId]
  end

  function FoundationModels.ids()
    local ids = {}
    for index, screenId in ipairs(ORDER) do ids[index] = screenId end
    return ids
  end

  return FoundationModels
end
