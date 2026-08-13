return function(ctx)
  local Data = ctx.load("adapters.data")
  local Models = {}

  local ORDER = {
    "Gen2MailCompose",
    "Gen2MailMenu",
    "Gen2MailRead",
    "Gen2MailboxMenu",
    "Gen2DecorationMenu",
    "Gen2TradeMenu",
    "Gen2NamePick",
    "Gen2InitClock",
    "Gen2Diploma",
    "Gen2PhotoStudio",
    "Gen2UnownPrinter",
    "Gen2HallOfFame",
  }
  local BY_ID = {
    Gen2MailCompose=ctx.load("adapters.mail_compose"),
    Gen2MailMenu=ctx.load("adapters.mail_menu"),
    Gen2MailRead=ctx.load("adapters.mail_read"),
    Gen2MailboxMenu=ctx.load("adapters.mailbox_menu"),
    Gen2DecorationMenu=ctx.load("adapters.decoration_menu"),
    Gen2TradeMenu=ctx.load("adapters.trade_menu"),
    Gen2NamePick=ctx.load("adapters.name_pick"),
    Gen2InitClock=ctx.load("adapters.init_clock"),
    Gen2Diploma=ctx.load("adapters.diploma"),
    Gen2PhotoStudio=ctx.load("adapters.photo_studio"),
    Gen2UnownPrinter=ctx.load("adapters.unown_printer"),
    Gen2HallOfFame=ctx.load("adapters.hall_of_fame"),
  }

  function Models.register(provider)
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
