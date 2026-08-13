return function(ctx)
  local Party = ctx.load("adapters.party")
  local Summary = ctx.load("adapters.summary")
  local PartyModels = {}

  local ORDER = { "Gen2PartyMenu", "Gen2SummaryMenu" }
  local BY_ID = {
    Gen2PartyMenu=Party,
    Gen2SummaryMenu=Summary,
  }

  function PartyModels.register(provider)
    if type(provider) ~= "table"
        or type(provider.registerModelAdapter) ~= "function" then
      return nil, "invalid_provider", "registerModelAdapter"
    end
    for _, screenId in ipairs(ORDER) do
      local ok, code, detail = provider:registerModelAdapter(screenId,
        BY_ID[screenId])
      if not ok then
        return nil, code or "model_registration_failed", detail or screenId
      end
    end
    return true
  end

  function PartyModels.adapterFor(screenId)
    return BY_ID[screenId]
  end

  function PartyModels.extract(screenId, state, context)
    local adapter = BY_ID[screenId]
    if not adapter then return nil, "unknown_screen", screenId end
    return adapter.extract(state, context)
  end

  function PartyModels.ids()
    return { ORDER[1], ORDER[2] }
  end

  return PartyModels
end
