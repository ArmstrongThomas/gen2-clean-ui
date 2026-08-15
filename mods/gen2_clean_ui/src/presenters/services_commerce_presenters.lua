return function(ctx)
  local Data = ctx.load("adapters.data")
  local Models = ctx.load("presenters.services_commerce_models")
  local PackPresenter = ctx.load("presenters.pack")
  local Presenters = {}

  local function canonical(model)
    if type(model) ~= "table" then return model end
    model.schema = "clean_ui.v3.presentation.v1"
    model.apiVersion = 3
    return model
  end

  local function copyRows(source)
    local output = {}
    for index, row in ipairs(source or {}) do
      output[index] = {
        id=row.id, sourceIndex=row.sourceIndex,
        label=row.label, right=row.right,
        disabled=row.disabled == true,
      }
    end
    return output
  end

  local function joined(lines)
    return table.concat(type(lines) == "table" and lines or {}, " ")
  end

  local function messageModal(message)
    if type(message) ~= "table" then return nil end
    return {
      title=joined(message.lines), selected=nil, options={},
      page=message.page, pageCount=message.pageCount,
    }
  end

  local function confirmModal(confirm)
    if type(confirm) ~= "table" then return nil end
    return {
      title=joined(confirm.lines), selected=confirm.selectedChoice,
      options=copyRows(confirm.choices),
      page=confirm.page, pageCount=confirm.pageCount,
    }
  end

  local function quantityModal(quantity, verb)
    if type(quantity) ~= "table" then return nil end
    local item = quantity.item or {}
    return {
      title=(verb or "CHOOSE") .. " " .. tostring(item.name or "ITEM"),
      selected=1,
      options={{ id="quantity", sourceIndex=1,
        label=("x%d / %d"):format(quantity.value or 1,
          quantity.maximum or 1),
        right="Y" .. tostring(quantity.total or 0) }},
    }
  end

  local function ownedCount(item)
    if type(item) ~= "table" then return 0 end
    return tonumber(item.ownedCount or item.count) or 0
  end

  local function entryFor(source, item)
    if type(source) ~= "table" or type(item) ~= "table" then return nil end
    for _, entry in ipairs(source.entries or {}) do
      if entry.id == item.id then return entry end
    end
    return nil
  end

  local function mart(source)
    local rows = copyRows(source.rows)
    local selected = source.navigation and source.navigation.selectedIndex or nil
    local scroll = source.navigation and source.navigation.scroll or 0
    local details = {
      { label="MONEY", value="Y" .. tostring(source.money or 0),
        style="accent" },
    }
    local item = source.selectedItem
    if type(item) ~= "table" and type(source.quantity) == "table" then
      item = source.quantity.item
    end
    if type(item) == "table" then
      details[#details + 1] = { label="ITEM", value=item.name or item.id }
      details[#details + 1] = { label="OWNED", value="x" .. tostring(
        ownedCount(item)) }
      details[#details + 1] = { label="PRICE", value="Y" .. tostring(item.price) }
      if item.soldOut then
        details[#details + 1] = { label="STATUS", value="SOLD OUT" }
      end
    end
    local title = source.title
    if source.phase == "sell" or source.phase == "sellQuantity" then
      local nested, code, detail = PackPresenter.convert(source.nestedPack)
      if type(nested) ~= "table" then
        return nil, code or "nested_conversion_failed", detail or "pack"
      end
      rows, selected, scroll = copyRows(nested.rows), nested.selected,
        nested.scroll or 0
      local sellEntry = entryFor(source, item)
      local sellOwned = ownedCount(item)
      if sellOwned == 0 and sellEntry then
        sellOwned = ownedCount(sellEntry)
      end
      details = {
        { label="MONEY", value="Y" .. tostring(source.money or 0),
          style="accent" },
        { label="ITEM", value=item and (item.name or item.id) or "ITEM" },
        { label="OWNED", value="x" .. tostring(sellOwned) },
        { label="SELL VALUE", value="Y" .. tostring(
          math.floor((sellEntry and sellEntry.price or item and item.price or 0)
            / 2)) },
      }
      title = source.title .. "  /  SELL"
    elseif source.phase == "buy" or source.phase == "buyQuantity" then
      title = source.title .. "  /  BUY"
    end
    local modal = confirmModal(source.confirm)
      or messageModal(source.message)
      or quantityModal(source.quantity,
        source.phase == "sellQuantity" and "SELL" or "BUY")
    local description = type(item) == "table" and item.description or ""
    if description == "" then
      description = source.phase == "top" and joined(source.topLines)
        or "A CHOOSE   B BACK"
    end
    return {
      kind="menu", preset="L", opaque=true,
      title=title, rows=rows, selected=selected, scroll=scroll,
      details=details, modal=modal, description=description,
      commerce=Data.copy({ martType=source.martType, martId=source.martId,
        phase=source.phase, mode=source.mode, quantity=source.quantity }),
    }
  end

  local function scriptMenu(source)
    local details = {}
    local balance = source.balance
    if type(balance) == "table" then
      if balance.kind == "money" or balance.kind == "moneycoins" then
        details[#details + 1] = {
          label="MONEY", value="Y" .. tostring(balance.money or 0),
          style="accent",
        }
      end
      if balance.kind == "coins" or balance.kind == "moneycoins" then
        details[#details + 1] = {
          label="COINS", value=balance.coins or 0, style="accent",
        }
      end
    end
    local navigation = source.navigation or {}
    return {
      kind="menu", preset="M", opaque=false,
      title=source.variant == "prizes" and "PRIZE COUNTER" or source.title,
      rows=copyRows(source.rows), selected=navigation.selectedIndex,
      scroll=0, details=details,
      description=source.style == "2d"
        and "D-PAD MOVE   A CHOOSE   B BACK"
        or "UP/DOWN CHOOSE   A OK   B BACK",
      script=Data.copy({ style=source.style, variant=source.variant,
        navigation=source.navigation, geometry=source.geometry,
        balance=source.balance }),
    }
  end

  local function bank(source)
    return {
      kind="menu", preset="XS", opaque=false,
      title=source.title, rows=copyRows(source.rows),
      selected=source.navigation.selectedIndex, scroll=0,
      details={
        { label="SAVED", value="Y" .. tostring(source.saved) },
        { label="HELD", value="Y" .. tostring(source.held) },
        { label=source.kind:upper(), value=("Y%06d"):format(source.amount),
          style="accent" },
      },
      description="LEFT/RIGHT DIGIT   UP/DOWN VALUE   A OK   B CANCEL",
      bank=Data.copy({ kind=source.kind, amount=source.amount,
        position=source.position, blink=source.blink }),
    }
  end

  local function contest(source)
    local stock, caught = source.stock or {}, source.caught or {}
    return {
      kind="menu", preset="L", opaque=true,
      title=source.title, rows=copyRows(source.rows),
      selected=source.navigation.selectedIndex, scroll=0,
      details={ fields={
        { label="STOCK", value=("%s  Lv %d  HP %d"):format(
          stock.name or "?", stock.level or 1, stock.maxHp or 0) },
        { label="NEW CATCH", value=("%s  Lv %d  HP %d"):format(
          caught.name or "?", caught.level or 1, caught.maxHp or 0),
          style="accent" },
      } },
      description=source.prompt,
      contest=Data.copy({ stock=stock, caught=caught,
        battleRouteNative=source.battleRouteNative }),
    }
  end

  local function dayCare(source)
    if source.nativeOnly then
      return {
        kind="menu", preset="L", opaque=false,
        title="DAY-CARE PARTY PICKER",
        rows={{ id="native", sourceIndex=1,
          label="USES NATIVE PARTY STACK", disabled=true }},
        selected=nil, scroll=0, details={},
        description=source.nativeReason or "NESTED PARTY PICKER REMAINS NATIVE",
        nativeStatus=true,
      }
    end
    local dc = source.dayCare or {}
    local details = {
      { label="SIDE", value=(source.side or "man"):upper() },
      { label="MAN", value=dc.man and dc.man.mon
        and dc.man.mon.name or "EMPTY" },
      { label="LADY", value=dc.lady and dc.lady.mon
        and dc.lady.mon.name or "EMPTY" },
      { label="EGG", value=dc.hasEgg and "READY" or "NOT READY",
        style=dc.hasEgg and "accent" or nil },
    }
    return {
      kind="menu", preset="L", opaque=false,
      title=source.title, rows={}, selected=nil, scroll=0,
      details=details,
      modal=confirmModal(source.confirm) or messageModal(source.message),
      description=source.mode == "confirm" and "A CHOOSE   B NO"
        or "A/B CONTINUE",
      dayCare=Data.copy(source.dayCare),
    }
  end

  local function heldItem(source)
    local mon = source.pokemon or {}
    return {
      kind="menu", preset="L", opaque=false,
      title=(mon.name or "POKEMON") .. "  /  HELD ITEM",
      rows=copyRows(source.rows), selected=source.navigation.selectedIndex,
      scroll=0,
      details={
        sprite=type(mon.artwork) == "table" and Data.copy(mon.artwork) or nil,
        fields={
          { label="POKEMON", value=mon.name or mon.species or "?" },
          { label="HELD", value=mon.heldName or "NONE", style="accent" },
        },
      },
      modal=confirmModal(source.confirm) or messageModal(source.message),
      description=source.mode == "confirm" and "A CHOOSE   B NO"
        or source.mode == "message" and "A/B CONTINUE"
        or "A CHOOSE   B BACK",
      heldItem=Data.copy({ slot=source.slot, mode=source.mode,
        pokemon=source.pokemon }),
    }
  end

  local function elevator(source)
    return {
      kind="menu", preset="S", opaque=false,
      title=source.title, rows=copyRows(source.rows),
      selected=source.navigation.selectedIndex,
      scroll=source.navigation.scroll or 0,
      details={{ label="NOW ON", value=source.currentFloor }},
      description="A SELECT FLOOR   B CANCEL",
      elevator=Data.copy(source.navigation),
    }
  end

  local function moveDeleter(source)
    local move = source.selectedMove or {}
    local details = {
      { label="POKEMON", value=source.pokemon and source.pokemon.name or "?" },
      { label="MOVE", value=move.label or move.id or "?", style="accent" },
      { label="PP", value=("%d/%d"):format(move.pp or 0, move.maxPp or 0) },
    }
    if move.type and move.type ~= "" then
      details[#details + 1] = { label="TYPE", value=move.type }
    end
    return {
      kind="menu", preset="L", opaque=false,
      title=source.title, rows=copyRows(source.rows),
      selected=source.navigation.selectedIndex, scroll=0,
      details=details, description=move.description ~= "" and move.description
        or "A CHOOSE   B CANCEL",
      moves=Data.copy({ pokemon=source.pokemon, selectedMove=move }),
    }
  end

  local CONVERT = {
    Gen2MartMenu=mart,
    Gen2ScriptMenu=scriptMenu,
    Gen2BankOfMom=bank,
    Gen2ContestMenu=contest,
    Gen2DayCareMenu=dayCare,
    Gen2HeldItemMenu=heldItem,
    Gen2ElevatorMenu=elevator,
    Gen2MoveDeleter=moveDeleter,
  }

  local function convert(screenId, source)
    if type(source) ~= "table" or source.screenId ~= screenId
        or source.schema ~= "clean_ui.presenter_model.v1" then
      return nil, "invalid_model", screenId
    end
    local converter = CONVERT[screenId]
    if not converter then return nil, "unknown_screen", screenId end
    local model, code, detail = converter(source)
    if type(model) ~= "table" then
      return nil, code or "conversion_failed", detail
    end
    if not Data.isFunctionFree(model) then
      return nil, "conversion_not_data", screenId
    end
    return canonical(model)
  end

  local function presenter(screenId)
    return {
      prepare=function(_, state, context)
        local adapter = Models.adapterFor(screenId)
        local bundle, code, detail = adapter.extract(state, context)
        if type(bundle) ~= "table" or type(bundle.model) ~= "table" then
          return nil, code or "model_incomplete", detail
        end
        local model
        model, code, detail = convert(screenId, bundle.model)
        if not model then return nil, code, detail end
        return { complete=true, model=model,
          sourceModel=bundle.model, actions=bundle.actions }
      end,
    }
  end

  function Presenters.register(provider)
    if type(provider) ~= "table"
        or type(provider.registerPresenter) ~= "function" then
      return nil, "invalid_provider", "registerPresenter"
    end
    for _, screenId in ipairs(Models.ids()) do
      local ok, code, detail = provider:registerPresenter(screenId,
        presenter(screenId))
      if not ok then return nil, code or "presenter_registration_failed",
        detail or screenId end
    end
    return true
  end

  function Presenters.convert(screenId, sourceModel)
    return convert(screenId, sourceModel)
  end

  function Presenters.presenterFor(screenId)
    if not CONVERT[screenId] then return nil end
    return presenter(screenId)
  end

  return Presenters
end
