return function(ctx)
  local Data = ctx.load("adapters.data")
  local TextBox = ctx.load("adapters.shared_textbox")
  local ChoiceBox = ctx.load("adapters.shared_choicebox")
  local SharedModels = {}
  local ORDER = { "shared.TextBox", "shared.ChoiceBox" }
  local BY_ID = { ["shared.TextBox"]=TextBox, ["shared.ChoiceBox"]=ChoiceBox }

  function SharedModels.register(provider)
    for _, id in ipairs(ORDER) do
      local ok, code, detail = provider:registerModelAdapter(id, BY_ID[id])
      if not ok then return nil, code, detail end
    end
    return true
  end

  function SharedModels.galleryFixtures()
    local output = {}
    for _, id in ipairs(ORDER) do
      for _, fixture in ipairs(BY_ID[id].fixtures()) do
        local bundle = assert(BY_ID[id].extract(fixture.state, { synthetic=true }))
        assert(Data.isFunctionFree(bundle.model), id .. " Gallery model")
        output[#output + 1] = {
          screenId=id, variant=fixture.variant, model=bundle.model,
        }
      end
    end
    return output
  end

  function SharedModels.adapterFor(id) return BY_ID[id] end
  function SharedModels.ids()
    return { ORDER[1], ORDER[2] }
  end
  return SharedModels
end
