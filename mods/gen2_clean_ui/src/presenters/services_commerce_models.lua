return function(ctx)
  local Data = ctx.load("adapters.data")
  local Models = {}

  local ORDER = {
    "Gen2MartMenu",
    "Gen2ScriptMenu",
    "Gen2BankOfMom",
    "Gen2ContestMenu",
    "Gen2DayCareMenu",
    "Gen2HeldItemMenu",
    "Gen2ElevatorMenu",
    "Gen2MoveDeleter",
  }
  local BY_ID = {
    Gen2MartMenu=ctx.load("adapters.mart"),
    Gen2ScriptMenu=ctx.load("adapters.script_menu"),
    Gen2BankOfMom=ctx.load("adapters.bank_of_mom"),
    Gen2ContestMenu=ctx.load("adapters.contest_menu"),
    Gen2DayCareMenu=ctx.load("adapters.day_care"),
    Gen2HeldItemMenu=ctx.load("adapters.held_item"),
    Gen2ElevatorMenu=ctx.load("adapters.elevator"),
    Gen2MoveDeleter=ctx.load("adapters.move_deleter"),
  }

  function Models.register(provider)
    if type(provider) ~= "table"
        or type(provider.registerModelAdapter) ~= "function" then
      return nil, "invalid_provider", "registerModelAdapter"
    end
    for _, screenId in ipairs(ORDER) do
      local ok, code, detail = provider:registerModelAdapter(screenId,
        BY_ID[screenId])
      if not ok then return nil, code or "model_registration_failed",
        detail or screenId end
    end
    return true
  end

  function Models.adapterFor(screenId)
    return BY_ID[screenId]
  end

  function Models.extract(screenId, state, context)
    local adapter = BY_ID[screenId]
    if not adapter then return nil, "unknown_screen", screenId end
    return adapter.extract(state, context)
  end

  function Models.ids()
    local output = {}
    for index, screenId in ipairs(ORDER) do output[index] = screenId end
    return output
  end

  function Models.isFunctionFree(bundle, screenId)
    return type(bundle) == "table" and type(bundle.model) == "table"
      and bundle.model.screenId == screenId
      and Data.isFunctionFree(bundle.model)
  end

  return Models
end
