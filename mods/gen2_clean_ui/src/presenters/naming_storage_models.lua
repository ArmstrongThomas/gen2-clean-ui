return function(ctx)
  local Data = ctx.load("adapters.data")
  local Naming = ctx.load("adapters.naming_screen")
  local CenterPc = ctx.load("adapters.storage_center_pc")
  local Pc = ctx.load("adapters.storage_pc")
  local Box = ctx.load("adapters.storage_box")
  local ItemPc = ctx.load("adapters.storage_item_pc")
  local Models = {}

  local ORDER = {
    "Gen2NamingScreen",
    "Gen2CenterPcMenu",
    "Gen2PcMenu",
    "Gen2BoxMenu",
    "Gen2ItemPcMenu",
  }
  local BY_ID = {
    Gen2NamingScreen = Naming,
    Gen2CenterPcMenu = CenterPc,
    Gen2PcMenu = Pc,
    Gen2BoxMenu = Box,
    Gen2ItemPcMenu = ItemPc,
  }

  function Models.register(provider)
    assert(type(provider) == "table"
      and type(provider.registerModelAdapter) == "function",
      "naming/storage registration requires a Gen2 provider")
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

  function Models.ids()
    local output = {}
    for index, screenId in ipairs(ORDER) do output[index] = screenId end
    return output
  end

  function Models.assertFunctionFree(bundle, screenId)
    return type(bundle) == "table" and type(bundle.model) == "table"
      and bundle.model.screenId == screenId
      and Data.isFunctionFree(bundle.model)
  end

  return Models
end
