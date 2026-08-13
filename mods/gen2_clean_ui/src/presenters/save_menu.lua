return function(ctx)
  local Adapter = ctx.load("adapters.save_menu")
  local Presenter = {}

  local TITLES = {
    confirm = "SAVE THE GAME?",
    overwrite = "OVERWRITE SAVE?",
    saving = "SAVING",
    done = "SAVE COMPLETE",
  }

  local function choiceRows(model)
    local output = {}
    for index, source in ipairs(model.choices or {}) do
      output[index] = {
        id = source.id,
        sourceIndex = source.sourceIndex,
        label = source.label,
      }
    end
    return output
  end

  local function summaryDetails(summary)
    summary = summary or {}
    local output = {
      { label = "PLAYER", value = summary.name or "?" },
      { label = "BADGES", value = summary.badges or 0 },
      { label = "POKEDEX", value = summary.caught or 0 },
      { label = "TIME", value = ("%d:%02d"):format(
        summary.hours or 0, summary.minutes or 0), style = "accent" },
    }
    if summary.map and summary.map ~= "" then
      output[#output + 1] = { label = "PLACE", value = summary.map }
    end
    return output
  end

  function Presenter.convert(model)
    if type(model) ~= "table" or model.screenId ~= "Gen2SaveMenu" then
      return nil, "invalid_model"
    end
    if TITLES[model.phase] == nil then return nil, "unknown_phase", model.phase end
    local interactive = model.phase == "confirm" or model.phase == "overwrite"
    return {
      kind = "menu",
      preset = "M",
      opaque = true,
      title = TITLES[model.phase],
      rows = interactive and choiceRows(model) or {},
      selected = interactive and model.selectedChoice or nil,
      scroll = 0,
      details = summaryDetails(model.summary),
      description = model.prompt,
      sourcePhase = model.phase,
      timer = model.timer,
      saved = model.savedPresent and model.saved or nil,
    }
  end

  function Presenter.prepare(_, state, context)
    local bundle, code, detail = Adapter.extract(state, context)
    if not bundle then return nil, code, detail end
    local model, convertCode, convertDetail = Presenter.convert(bundle.model)
    if not model then return nil, convertCode, convertDetail end
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
      "Gen2SaveMenu", Adapter)
    if not ok then return nil, code, detail end
    return provider:registerPresenter("Gen2SaveMenu", Presenter)
  end

  return Presenter
end
