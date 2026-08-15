return function(ctx)
  local Data = ctx.load("adapters.data")
  local FoundationModels = ctx.load("presenters.foundation_models")
  local FoundationPresenters = {}

  local ORDER = {
    "Gen2MainMenu",
    "Gen2StartMenu",
    "Gen2OptionsMenu",
  }

  local function row(source)
    return {
      id = source.id,
      sourceIndex = source.sourceIndex,
      label = source.label,
      disabled = source.disabled == true,
      right = source.pinned and "PINNED" or source.displayValue,
    }
  end

  local function rows(source)
    local output = {}
    for index, item in ipairs(source or {}) do
      output[index] = row(item)
    end
    return output
  end

  local function saveDetails(summary)
    if type(summary) ~= "table" then return {} end
    local time = ("%d:%02d"):format(summary.hours or 0,
      summary.minutes or 0)
    local output = {
      { label = "PLAYER", value = summary.name or "?" },
      { label = "BADGES", value = summary.badges or 0 },
      { label = "POKEDEX", value = summary.caught or 0 },
      { label = "TIME", value = time },
    }
    if summary.map and summary.map ~= "" then
      output[#output + 1] = { label = "PLACE", value = summary.map }
    end
    return output
  end

  local function main(model)
    local confirm = model.confirm
    if confirm then
      return {
        schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
        kind = "menu", preset = "M", opaque = true,
        title = "CONTINUE", selected = 1, scroll = 0,
        rows = {{
          id = "continue", sourceIndex = model.navigation.selectedIndex,
          label = "CONTINUE", disabled = not confirm.ready,
          right = confirm.ready and "READY" or "PLEASE WAIT",
        }},
        details = saveDetails(model.saveSummary),
        description = confirm.ready
          and "A CONTINUE   B BACK" or "PLEASE WAIT...",
      }
    end

    local details = {}
    if model.clock and model.clock.available then
      details = {
        { label = "DAY", value = model.clock.dayLabel },
        { label = "TIME", value = model.clock.timeLabel, style = "accent" },
      }
    end
    return {
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      kind = "menu", preset = "M", opaque = true,
      title = model.title or "MAIN MENU",
      rows = rows(model.items),
      selected = model.navigation.selectedIndex,
      scroll = model.navigation.scroll,
      details = details,
      description = "A CHOOSE",
    }
  end

  local function start(model)
    local modal
    if model.confirm then
      modal = {
        title = "RETURN TO TITLE?", dim_opacity = 0.4,
        selected = model.confirm.selectedChoice,
        options = Data.copy(model.confirm.choices),
      }
    end
    return {
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      kind = "menu", preset = "NAV", opaque = false,
      title = (model.title or "START") .. "  " .. (model.playerName or ""),
      rows = rows(model.items),
      selected = model.navigation.selectedIndex,
      scroll = model.navigation.scroll,
      description = model.showDescription and model.selectedDescription
        or "A CHOOSE   B BACK   SELECT PIN",
      modal = modal,
    }
  end

  local function options(model)
    return {
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      kind = "menu", preset = "M", opaque = true,
      title = model.title or "OPTIONS",
      rows = rows(model.rows),
      selected = model.navigation.selectedIndex,
      scroll = model.navigation.scroll,
      description = "LEFT/RIGHT ADJUST   A CHOOSE   B BACK",
    }
  end

  local CONVERT = {
    Gen2MainMenu = main,
    Gen2StartMenu = start,
    Gen2OptionsMenu = options,
  }

  local function presenter(screenId)
    return {
      prepare = function(_, state, context)
        local adapter = FoundationModels.adapterFor(screenId)
        local bundle, code, detail = adapter.extract(state, context)
        if type(bundle) ~= "table" or type(bundle.model) ~= "table" then
          return nil, code or "model_incomplete", detail
        end
        local model = CONVERT[screenId](bundle.model)
        if type(model) ~= "table" then return nil, "conversion_failed" end
        return {
          complete = true,
          model = model,
          actions = bundle.actions,
          sourceModel = bundle.model,
        }
      end,
    }
  end

  function FoundationPresenters.register(provider)
    for _, screenId in ipairs(ORDER) do
      local ok, code, detail = provider:registerPresenter(screenId,
        presenter(screenId))
      if not ok then return nil, code, detail end
    end
    return true
  end

  function FoundationPresenters.convert(screenId, model)
    local convert = CONVERT[screenId]
    if type(convert) ~= "function" then return nil, "unknown_screen" end
    return convert(model)
  end

  return FoundationPresenters
end
