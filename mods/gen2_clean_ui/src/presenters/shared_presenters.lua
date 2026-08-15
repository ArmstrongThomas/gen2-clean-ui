return function(ctx)
  local SharedModels = ctx.load("presenters.shared_models")
  local SharedPresenters = {}

  local function convert(id, source)
    if id == "shared.TextBox" then
      return {
        schema="clean_ui.v3.presentation.v1", apiVersion=3,
        kind="dialogue", preset="XS", opaque=false, anchor="bottom",
        lines=source.lines, reflow=source.reflow, more=source.more,
        controls=source.controls, inputReady=source.inputReady,
      }
    end
    if id == "shared.ChoiceBox" then
      return {
        schema="clean_ui.v3.presentation.v1", apiVersion=3,
        kind="choice", preset="XS", opaque=false, anchor=source.anchor,
        selected=source.selected, pending=source.pending,
        inputReady=source.inputReady, options=source.options,
        controls=source.inputReady and "A CHOOSE   B NO" or "",
      }
    end
    return nil, "unknown_screen"
  end

  local function presenter(id)
    return { prepare=function(_, state, context)
      local bundle, code, detail = SharedModels.adapterFor(id).extract(
        state, context)
      if type(bundle) ~= "table" or type(bundle.model) ~= "table" then
        return nil, code or "model_incomplete", detail
      end
      local model = convert(id, bundle.model)
      if not model then return nil, "conversion_failed" end
      return { complete=true, model=model, sourceModel=bundle.model,
        actions=bundle.actions }
    end }
  end

  function SharedPresenters.register(provider)
    for _, id in ipairs(SharedModels.ids()) do
      local ok, code, detail = provider:registerPresenter(id, presenter(id))
      if not ok then return nil, code, detail end
    end
    return true
  end

  function SharedPresenters.convert(id, model) return convert(id, model) end
  return SharedPresenters
end
