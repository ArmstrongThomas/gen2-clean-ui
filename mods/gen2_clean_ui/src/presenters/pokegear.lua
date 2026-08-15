return function(ctx)
  local Data = ctx.load("adapters.data")
  local Adapter = ctx.load("adapters.pokegear")
  local Presenter = {}

  local function canonical(model)
    model.schema = "clean_ui.v3.presentation.v1"
    model.apiVersion = 3
    return model
  end

  local VIEW_TITLES = {
    strip="POKEGEAR",
    clock="POKEGEAR / CLOCK",
    map="POKEGEAR / MAP",
    fly="FLY MAP",
    radio="POKEGEAR / RADIO",
    phone="POKEGEAR / PHONE",
    phone_submenu="POKEGEAR / PHONE",
    call="PHONE CALL",
    no_signal="NO SIGNAL",
  }

  local function row(source, right)
    return {
      id=source.id,
      sourceIndex=source.sourceIndex,
      label=source.label or source.name or source.id,
      right=right or source.right,
      icon=source.icon,
      accent=source.accent,
      subtitle=source.subtitle,
      disabled=source.disabled == true,
    }
  end

  local function applyShell(model, content)
    local shell = model.shell
    if type(shell) ~= "table" then return content end
    content.appShell=true
    local function copy(value)
      return Data.copy(value, { maxDepth=8, maxEntries=4096 })
    end
    content.shell=copy(shell)
    content.device=copy(shell.device)
    content.launcher=copy(shell.launcher)
    content.apps=copy(shell.apps)
    content.activeApp=copy(shell.activeApp)
    content.statusBar=copy(shell.statusBar)
    content.navigation=copy(shell.navigation)
    content.nativeGraphic=copy(shell.graphic)
    return canonical(content)
  end

  local function strip(model)
    local rows = {}
    for index, card in ipairs(model.cards or {}) do
      rows[index] = row(model.shell and model.shell.apps
        and model.shell.apps[index] or card,
        card.selected and "OPEN" or "")
    end
    local active = model.activeCard or {}
    return {
      rows=rows,
      selected=model.cardIndex,
      scroll=0,
      details={
        { label="CARD", value=active.label or active.id or "?",
          style="accent" },
        { label="AVAILABLE", value=#rows },
      },
      launcher=true,
      description="LEFT/RIGHT CARD   A OPEN   B BACK",
    }
  end

  local function clock(model)
    local value = model.clock
    if type(value) ~= "table" then return nil, "clock_unavailable" end
    local hour = value.hour % 12
    if hour == 0 then hour = 12 end
    return {
      rows={}, selected=nil, scroll=0,
      details={
        { label="DAY", value=value.day or "?", style="accent" },
        { label="TIME", value=("%d:%02d %s"):format(
          hour, value.minute or 0, value.period or "") },
      },
      description="B RETURN TO CARD STRIP",
    }
  end

  local function map(model)
    local value = model.map
    if type(value) ~= "table" then return nil, "map_unavailable" end
    local rows, selected = {}, nil
    for index, landmark in ipairs(value.rows or {}) do
      rows[index] = row(landmark, landmark.selected and "CURSOR" or "")
      if landmark.selected then selected = index end
    end
    local current, player = value.current or {}, value.player or {}
    return {
      rows=rows,
      selected=selected,
      scroll=selected and math.max(0, selected - 4) or 0,
      mapView=true,
      mapCanvas=Data.copy(value, { maxDepth=8, maxEntries=4096 }),
      mapGraphic=Data.copy(value.graphic, { maxDepth=8, maxEntries=4096 }),
      details={
        { label="REGION", value=(value.region or "johto"):upper(),
          style="accent" },
        { label="CURSOR", value=current.name or "UNKNOWN" },
        { label="YOU ARE HERE", value=player.name or "UNKNOWN" },
      },
      description="UP/DOWN LANDMARK   LEFT/RIGHT CARD   B BACK",
      map=Data.copy(value, { maxDepth=8, maxEntries=4096 }),
      mapGraphic=Data.copy(value.graphic, { maxDepth=8, maxEntries=4096 }),
    }
  end

  local function fly(model)
    local value = model.map
    if type(value) ~= "table" or type(value.flyRows) ~= "table"
        or #value.flyRows == 0 then
      return nil, "fly_unavailable"
    end
    local rows = {}
    for index, destination in ipairs(value.flyRows) do
      rows[index] = row(destination,
        destination.selected and "DESTINATION" or "")
    end
    local current = value.flyRows[value.flyIndex or 1] or {}
    return {
      rows=rows,
      selected=value.flyIndex,
      scroll=math.max(0, (value.flyIndex or 1) - 5),
      mapView=true,
      flyView=true,
      mapCanvas=Data.copy(value, { maxDepth=8, maxEntries=4096 }),
      details={
        { label="REGION", value=(value.region or "johto"):upper() },
        { label="DESTINATION", value=current.name or "?", style="accent" },
      },
      description="UP/DOWN DESTINATION   A FLY   B CANCEL",
      map=Data.copy(value, { maxDepth=8, maxEntries=4096 }),
      mapGraphic=Data.copy(value.graphic, { maxDepth=8, maxEntries=4096 }),
    }
  end

  local function radio(model)
    local value = model.radio
    if type(value) ~= "table" or type(value.rows) ~= "table" then
      return nil, "radio_unavailable"
    end
    local rows = {}
    for index, frequency in ipairs(value.rows) do
      rows[index] = row({
        id=frequency.id,
        sourceIndex=frequency.sourceIndex,
        label=frequency.frequency,
      }, frequency.name)
    end
    local current = value.current or {}
    local lines = {}
    if value.top and value.top ~= "" then lines[#lines + 1] = value.top end
    if value.bottom and value.bottom ~= "" then lines[#lines + 1] = value.bottom end
    return {
      rows=rows,
      selected=value.selectedIndex,
      scroll=math.max(0, (value.selectedIndex or 1) - 4),
      details={
        { label="FREQUENCY", value=current.frequency or "?" },
        { label="STATION", value=current.name or "DEAD AIR",
          style=current.station and "accent" or nil },
        { label="STATUS", value=value.on and "ON AIR" or "NO SIGNAL" },
      },
      description=#lines > 0 and lines
        or "UP/DOWN TUNE   B RETURN TO CARD STRIP",
    }
  end

  local function phoneRows(value)
    local rows = {}
    for index, contact in ipairs(value.rows or {}) do
      rows[index] = row(contact, contact.className or "")
    end
    return rows
  end

  local function phoneModal(model)
    local value = model.phone or {}
    if model.view == "phone_submenu" and value.submenu then
      local options = {}
      for index, option in ipairs(value.submenu.rows or {}) do
        options[index] = row(option)
      end
      return {
        title=(value.rows[value.selectedIndex] or {}).label or "CONTACT",
        dim_opacity=0.4,
        selected=value.submenu.selectedIndex,
        options=options,
      }
    end
    if (model.view == "call" or model.view == "no_signal") and value.call then
      local title = model.view == "no_signal" and "NO SIGNAL"
        or (value.call.name ~= "" and value.call.name or "PHONE CALL")
      return {
        title=title,
        dim_opacity=0.3,
        selected=nil,
        options={},
        description=value.call.text,
      }
    end
    return nil
  end

  local function phone(model)
    local value = model.phone
    if type(value) ~= "table" or type(value.rows) ~= "table" then
      return nil, "phone_unavailable"
    end
    local selected = value.rows[value.selectedIndex] or {}
    local description
    if model.view == "call" or model.view == "no_signal" then
      description=(value.call and value.call.text) or "A/B HANG UP"
    elseif model.view == "phone_submenu" then
      description="UP/DOWN ACTION   A CHOOSE   B CANCEL"
    else
      description="UP/DOWN CONTACT   A ACTIONS   B BACK"
    end
    return {
      rows=phoneRows(value),
      selected=value.selectedIndex,
      scroll=value.scroll or 0,
      details={
        { label="CONTACT", value=selected.label or "----------",
          style=not selected.empty and "accent" or nil },
        { label="CLASS", value=selected.className or "" },
        { label="SERVICE", value=value.service and "AVAILABLE" or "NO SIGNAL" },
      },
      description=description,
      modal=phoneModal(model),
    }
  end

  local CONVERT = {
    strip=strip, clock=clock, map=map, fly=fly, radio=radio,
    phone=phone, phone_submenu=phone, call=phone, no_signal=phone,
  }

  function Presenter.convert(model)
    if type(model) ~= "table" or model.screenId ~= "Gen2Pokegear" then
      return nil, "invalid_model"
    end
    local convert = CONVERT[model.view]
    if not convert then return nil, "unknown_view", model.view end
    local content, code = convert(model)
    if not content then return nil, code or "conversion_failed" end
    content.kind = (model.view == "map" or model.view == "fly")
      and "map" or "device"
    content.preset = "L"
    content.opaque = true
    content.title = VIEW_TITLES[model.view]
    content.view = model.view
    content.sourceView = model.view
    content.sourceMode = model.sourceMode
    applyShell(model, content)
    return content
  end

  function Presenter.prepare(_, state, context)
    local bundle, code, detail = Adapter.extract(state, context)
    if not bundle then return nil, code, detail end
    local model, convertCode, convertDetail = Presenter.convert(bundle.model)
    if not model then return nil, convertCode, convertDetail end
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
      "Gen2Pokegear", Adapter)
    if not ok then return nil, code, detail end
    return provider:registerPresenter("Gen2Pokegear", Presenter)
  end

  return Presenter
end
