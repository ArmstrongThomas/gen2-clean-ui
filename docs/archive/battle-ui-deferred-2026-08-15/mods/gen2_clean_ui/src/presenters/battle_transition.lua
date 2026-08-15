return function(ctx)
  local Adapter = ctx.load("adapters.battle_transition")
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
      "Gen2BattleTransition", Adapter)
    if not ok then return nil, code, detail end
    return provider:registerPresenter("Gen2BattleTransition", Presenter)
  end

  return Presenter
end
