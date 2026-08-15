return function(ctx)
  local Data = ctx.load("adapters.data")
  local Adapter = ctx.load("adapters.egg_hatch")
  local Presenter = {}

  function Presenter.prepare(_, state, context)
    local bundle, code, detail = Adapter.extract(state, context)
    if not bundle then return nil, code, detail end
    return { complete=true, model=bundle.model, sourceModel=bundle.model,
      actions=bundle.actions }
  end

  function Presenter.register(provider)
    if type(provider) ~= "table" then return nil, "invalid_provider" end
    local ok, code, detail = provider:registerModelAdapter(
      "Gen2EggHatchAnim", { extract=Adapter.extract })
    if not ok then return nil, code, detail end
    return provider:registerPresenter("Gen2EggHatchAnim", Presenter)
  end

  function Presenter.convert(sourceModel)
    if type(sourceModel) ~= "table"
        or sourceModel.schema ~= "clean_ui.v3.presentation.v1" then
      return nil, "invalid_source_model"
    end
    return Data.copy(sourceModel)
  end

  return Presenter
end
