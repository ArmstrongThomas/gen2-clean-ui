return function(ctx)
  local Adapter = ctx.load("adapters.map_radio")
  local Presenter = {}

  local function canonical(model)
    model.schema = "clean_ui.v3.presentation.v1"
    model.apiVersion = 3
    return model
  end

  function Presenter.convert(model)
    if type(model) ~= "table" or model.screenId ~= "Gen2MapRadio"
        or model.view ~= "station" or type(model.station) ~= "table"
        or type(model.broadcast) ~= "table" then
      return nil, "invalid_model"
    end
    local lines = model.broadcast.lines or {}
    return canonical({
      kind="menu",
      preset="L",
      opaque=false,
      title="RADIO / " .. tostring(model.station.name or "STATION"),
      rows={{
        id=model.station.id,
        sourceIndex=1,
        label=model.station.name or model.station.id,
        right="ON AIR",
        disabled=true,
      }},
      selected=nil,
      scroll=0,
      details={
        { label="STATION", value=model.station.name or "?", style="accent" },
        { label="STATUS", value=model.hold > 0 and "TUNING" or "PLAYING" },
      },
      description=#lines > 0 and lines or "A/B CLOSE",
      sourceView="station",
      hold=model.hold,
      inputReady=model.inputReady == true,
    })
  end

  function Presenter.prepare(_, state, context)
    local bundle, code, detail = Adapter.extract(state, context)
    if not bundle then return nil, code, detail end
    local model, convertCode = Presenter.convert(bundle.model)
    if not model then return nil, convertCode or "conversion_failed" end
    return {
      complete=true,
      model=model,
      sourceModel=bundle.model,
      actions=bundle.actions,
    }
  end

  function Presenter.register(provider)
    if type(provider) ~= "table" then return nil, "invalid_provider" end
    local ok, code, detail = provider:registerModelAdapter(
      "Gen2MapRadio", Adapter)
    if not ok then return nil, code, detail end
    return provider:registerPresenter("Gen2MapRadio", Presenter)
  end

  return Presenter
end
