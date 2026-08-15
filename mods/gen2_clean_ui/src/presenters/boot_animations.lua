return function(ctx)
  local Data = ctx.load("adapters.data")
  local Adapter = ctx.load("adapters.boot_animations")
  local GameFreakAdapter = ctx.load("adapters.gamefreak")
  local Presenter = {}

  local EXTRACTORS = {
    Gen2CopyrightSplash = Adapter.extractCopyright,
    Gen2GameFreakPresents = GameFreakAdapter.extract,
    Gen2TitleState = Adapter.extractTitle,
  }

  function Presenter.prepare(_, state, context)
    local extractor = EXTRACTORS[state and state.screenId]
    if type(extractor) ~= "function" then
      return nil, "unknown_boot_screen", tostring(state and state.screenId)
    end
    local bundle, code, detail = extractor(state, context)
    if not bundle then return nil, code, detail end
    return { complete=true, model=bundle.model, sourceModel=bundle.model,
      actions=bundle.actions }
  end

  function Presenter.register(provider)
    if type(provider) ~= "table" then return nil, "invalid_provider" end
    for screenId in pairs(EXTRACTORS) do
      local ok, code, detail = provider:registerModelAdapter(screenId, {
        extract = EXTRACTORS[screenId],
      })
      if not ok then return nil, code, detail end
      ok, code, detail = provider:registerPresenter(screenId, Presenter)
      if not ok then return nil, code, detail end
    end
    return true
  end

  function Presenter.convert(screenId, sourceModel)
    if screenId ~= "Gen2CopyrightSplash"
        and screenId ~= "Gen2GameFreakPresents"
        and screenId ~= "Gen2TitleState" then
      return nil, "unknown_screen"
    end
    if type(sourceModel) ~= "table"
        or sourceModel.schema ~= "clean_ui.v3.presentation.v1" then
      return nil, "invalid_source_model"
    end
    return Data.copy(sourceModel)
  end

  return Presenter
end
