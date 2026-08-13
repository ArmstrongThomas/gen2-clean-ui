return function(ctx)
  local Data = ctx.load("adapters.data")
  local Adapter = ctx.load("adapters.pack")
  local Presenter = {}

  local function rows(source)
    local output = {}
    for index, item in ipairs(source or {}) do
      output[index] = {
        id = item.id,
        sourceIndex = item.sourceIndex,
        label = item.label,
        right = item.right,
        disabled = item.disabled == true,
      }
    end
    return output
  end

  local function details(item)
    if type(item) ~= "table" then return {} end
    local output = {
      { label = "ITEM", value = item.name or item.id or "?" },
    }
    if (item.count or 0) > 0 then
      output[#output + 1] = { label = "QUANTITY", value = item.count }
    end
    if item.teaches and item.teaches ~= "" then
      output[#output + 1] = {
        label = "TEACHES", value = item.teaches, style = "accent",
      }
    end
    return output
  end

  local function modal(model)
    if model.mode == "actions" and model.submenu then
      return {
        title = (model.submenu.item and model.submenu.item.name) or "ITEM",
        dim_opacity = 0.4,
        selected = model.submenu.selectedIndex,
        options = rows(model.submenu.rows),
      }
    end
    if model.mode == "quantity" and model.quantity then
      local item = model.quantity.item or {}
      return {
        title = "HOW MANY " .. tostring(item.name or "ITEM") .. "?",
        dim_opacity = 0.4,
        selected = 1,
        options = {{
          id = "quantity", sourceIndex = 1,
          label = ("x%d / %d"):format(model.quantity.qty or 1,
            model.quantity.max or 1),
        }},
      }
    end
    if model.mode == "confirm" and model.confirm then
      return {
        title = table.concat(model.confirm.prompt or {}, " "),
        dim_opacity = 0.4,
        selected = model.confirm.selectedChoice,
        options = rows(model.confirm.choices),
      }
    end
    if model.mode == "message" and model.message and #model.message > 0 then
      return {
        title = table.concat(model.message, " "),
        dim_opacity = 0.25,
        options = {},
      }
    end
    return nil
  end

  function Presenter.convert(model)
    if type(model) ~= "table" or model.screenId ~= "Gen2PackMenu" then
      return nil, "invalid_model"
    end
    if model.battleOwned then return nil, "battle_owned" end
    local pocket = model.pocket or {}
    local selected = model.selectedItem
    local description = selected and selected.description or ""
    if description == "" then
      description = "LEFT/RIGHT POCKET   A CHOOSE   B BACK"
    end
    return {
      kind = "menu",
      preset = "L",
      opaque = true,
      title = "PACK  /  " .. tostring(pocket.label or "ITEMS"),
      rows = rows(model.rows),
      selected = model.navigation and model.navigation.selectedIndex or 1,
      scroll = model.navigation and model.navigation.scroll or 0,
      details = details(selected),
      description = description,
      modal = modal(model),
      sourceMode = model.mode,
      sourcePocket = pocket.id,
    }
  end

  function Presenter.prepare(_, state, context)
    local bundle, code, detail = Adapter.extract(state, context)
    if not bundle then return nil, code, detail end
    local model, convertCode = Presenter.convert(bundle.model)
    if not model then return nil, convertCode or "conversion_failed" end
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
      "Gen2PackMenu", Adapter)
    if not ok then return nil, code, detail end
    return provider:registerPresenter("Gen2PackMenu", Presenter)
  end

  return Presenter
end
