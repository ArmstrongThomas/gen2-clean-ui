return function(ctx)
  local Data = ctx.load("adapters.data")
  local PartyModels = ctx.load("presenters.party_models")
  local PartyPresenters = {}

  local function canonical(model)
    model.schema = "clean_ui.v3.presentation.v1"
    model.apiVersion = 3
    return model
  end

  local function typeLabel(types)
    local labels = {}
    for _, entry in ipairs(types or {}) do
      labels[#labels + 1] = tostring(entry.label or entry.id or "")
    end
    return table.concat(labels, " / ")
  end

  -- The party and summary screens intentionally use a new Clean UI control
  -- contract.  These are descriptors only: the V3 host still owns the live
  -- state machine and source-input dispatch.
  local PARTY_CONTROL_SCHEME = {
    id="gen2_party_clean_v1", focus="pokemon",
    up="previous_pokemon", down="next_pokemon",
    a="open_actions", b="back",
  }
  local SUMMARY_CONTROL_SCHEME = {
    id="gen2_summary_clean_v1", focus="tabs",
    left="previous_tab", right="next_tab",
    up="previous_pokemon", down="next_pokemon",
    a="activate", b="back",
    moves={ up="previous_move", down="next_move",
      a="pick_or_place_move", b="back", select="open_move_detail" },
  }

  local function spriteDetails(artwork)
    if type(artwork) ~= "table" or type(artwork.path) ~= "string" then
      return nil
    end
    local descriptor = { path=artwork.path }
    if type(artwork.palette) == "table" then
      descriptor.palette = Data.copy(artwork.palette)
    end
    return descriptor
  end

  local function partyRows(source)
    local output = {}
    for index, row in ipairs(source.rows or {}) do
      local right
      if row.kind == "back" then
        right = "BACK"
      elseif row.kind == "egg" then
        right = "EGG"
      else
        right = ("Lv %d  %d/%d"):format(row.level, row.hp, row.maxHp)
        if row.status and row.status ~= "OK" then
          right = right .. "  " .. row.status
        end
      end
      output[index] = {
        id=row.id, sourceIndex=row.sourceIndex, kind=row.kind,
        label=row.label, right=right, disabled=row.disabled == true,
        icon=Data.copy(row.icon), gender=row.gender,
        genderIcon=Data.copy(row.genderIcon),
        types=Data.copy(row.types), level=row.level,
        hp=row.hp, maxHp=row.maxHp, hpFraction=row.hpFraction,
        status=(row.status and row.status ~= "OK") and row.status or nil,
        isEgg=row.isEgg == true,
        bar=row.kind ~= "back" and row.kind ~= "egg" and {
          fraction=row.hpFraction or 0,
        } or nil,
        barLabel=row.kind ~= "back" and row.kind ~= "egg"
          and ("HP " .. tostring(row.hp) .. "/" .. tostring(row.maxHp))
          or nil,
        selected=row.selected == true, switchOrigin=row.switchOrigin == true,
        actionId=row.actionId,
      }
    end
    return output
  end

  local function partyDetails(source)
    local mon = source.selectedPokemon
    if not mon then
      return {
        { label="BACK", value="PREVIOUS SCREEN", style="accent" },
        { label="ACTION", value="RETURN" },
      }
    end
    if mon.isEgg then
      return {
        title="EGG",
        sprite=spriteDetails(source.artwork),
        fields={ { label="STATUS", value="EGG", style="accent" } },
      }
    end
    return {
      title=mon.name,
      sprite=spriteDetails(source.artwork),
      fields={
        { label="SPECIES", value=mon.species },
        { label="HELD", value=mon.item and mon.item.name or "NONE" },
        { label="STATUS", value=mon.status,
          style=mon.status ~= "OK" and "accent" or nil },
      },
      typeBadges=Data.copy(mon.types),
      bars={
        { label="HP", value=("%d/%d"):format(mon.hp, mon.maxHp),
          fraction=mon.hpFraction or 0 },
      },
    }
  end

  local function partyModal(source)
    local submenu = source.submenu
    if not submenu then return nil end
    local options = {}
    local selected
    for index, item in ipairs(submenu.items or {}) do
      if item.kind ~= "back" then
        local displayIndex = #options + 1
        options[displayIndex] = {
          id=item.id, label=item.label, sourceIndex=item.sourceIndex,
          kind=item.kind, disabled=item.disabled == true,
          actionId=item.actionId,
        }
        if index == submenu.selectedIndex then selected = displayIndex end
      end
    end
    if #options < 1 then return nil end
    return {
      title=(submenu.pokemonName or "POKEMON") .. " ACTIONS",
      selected=selected or #options, options=options, compact=true,
      dim_opacity=0.3,
    }
  end

  local function convertParty(source)
    if type(source) ~= "table" or source.preset ~= "L" then
      return nil, "preset_mismatch"
    end
    local description
    if source.mode == "actions" then
      description = "A CHOOSE   B BACK"
    elseif source.mode == "switch" then
      description = "A MOVE HERE   B CANCEL"
    else
      description = "A CHOOSE   B BACK"
    end
    local model = {
      kind="menu", screenId="Gen2PartyMenu", preset="L", opaque=true,
      title="PARTY", rows=partyRows(source), rowBars=true,
      selected=source.navigation and source.navigation.selectedIndex,
      scroll=0, details=partyDetails(source), description=description,
      purpose="party", mode=source.mode, prompt=source.prompt,
      selection=Data.copy(source.selection),
      party=Data.copy(source.party), partyLayout="list",
      partyCount=#(source.party or {}),
      partyCountText=("%d / 6"):format(#(source.party or {})),
      controlScheme=Data.copy(PARTY_CONTROL_SCHEME),
      artwork=Data.copy(source.artwork),
      modal=partyModal(source),
      heldItemState=Data.copy(source.heldItemState),
    }
    if not Data.isFunctionFree(model) then return nil, "model_not_data" end
    return canonical(model)
  end

  local function summaryDetails(source)
    local mon = source.pokemon or {}
    if mon.isEgg then
      local flavor = {}
      for _, line in ipairs(source.egg and source.egg.lines or {}) do
        flavor[#flavor + 1] = { label=line }
      end
      return {
        title="EGG",
        sprite=spriteDetails(source.artwork),
        fields={ { label="STATUS", value="EGG", style="accent" } },
        footer_lists={ { title="HATCHING", items=flavor } },
      }
    end

    local details = {
      title=mon.name,
      sprite=spriteDetails(source.artwork),
      fields={
        { label="SPECIES", value=mon.speciesName },
        { label="LEVEL", value=mon.level },
      },
      custom_fields={ columns=2, data={} },
    }
    local fields = details.custom_fields.data
    if source.purpose == "status" then
      local status, exp = source.status or {},
        source.status and source.status.experience or {}
      fields[#fields + 1] = {
        label="HP", value=("%d/%d"):format(status.hp, status.maxHp),
      }
      fields[#fields + 1] = {
        label="STATUS", value=status.status,
        style=status.status ~= "OK" and "accent" or nil,
      }
      fields[#fields + 1] = { label="TYPE", value=typeLabel(status.types) }
      fields[#fields + 1] = { label="EXP", value=exp.experience }
      fields[#fields + 1] = { label="NEXT", value=exp.toNext }
      fields[#fields + 1] = { label="DEX", value=mon.dex }
      fields[#fields + 1] = {
        label="HELD", value=source.heldItem and source.heldItem.name or "NONE",
      }
      fields[#fields + 1] = {
        label="POKERUS", value=status.pokerus or "NONE",
      }
    elseif source.purpose == "moves" then
      fields[#fields + 1] = {
        label="HELD", value=source.heldItem and source.heldItem.name or "NONE",
      }
      fields[#fields + 1] = {
        label="MOVES", value=source.navigation and source.navigation.moveCount
          or #(source.moves or {}),
      }
      local selected = source.moveDetail and source.moveDetail.selectedMove
      if selected then
        fields[#fields + 1] = {
          label="TYPE", value=selected.type and selected.type.label or "---",
        }
        fields[#fields + 1] = {
          label="POWER", value=selected.power or "---",
        }
        fields[#fields + 1] = {
          label="PP", value=("%d/%d"):format(selected.pp, selected.maxPp),
        }
        local description = {}
        for _, line in ipairs(selected.description or {}) do
          description[#description + 1] = { label=line }
        end
        if #description > 0 then
          details.footer_lists = {
            { title=selected.name .. " INFO", items=description },
          }
        end
      end
    elseif source.purpose == "stats" then
      local trainer = source.stats and source.stats.trainer or {}
      fields[#fields + 1] = { label="OT", value=trainer.name }
      fields[#fields + 1] = { label="ID", value=trainer.id }
      fields[#fields + 1] = { label="TYPE", value=typeLabel(source.status and source.status.types) }
      fields[#fields + 1] = { label="DEX", value=mon.dex }
      for _, stat in ipairs(source.stats and source.stats.values or {}) do
        fields[#fields + 1] = {
          label=stat.label, value=stat.value,
        }
      end
      fields[#fields + 1] = {
        label="HELD", value=source.heldItem and source.heldItem.name or "NONE",
      }
    end
    return details
  end

  local function statusRows(source)
    local status = source.status
    local exp = status.experience
    return {
      { id="status.hp", label="HP",
        right=("%d/%d"):format(status.hp, status.maxHp), disabled=true },
      { id="status.condition", label="STATUS", right=status.status,
        disabled=true },
      { id="status.type", label="TYPE", right=typeLabel(status.types),
        disabled=true },
      { id="status.experience", label="EXP POINTS", right=exp.experience,
        disabled=true },
      { id="status.next", label="TO NEXT LEVEL", right=exp.toNext,
        disabled=true },
    }
  end

  local function moveRows(source)
    local output = {}
    for slot = 1, 4 do
      local move = source.moves and source.moves[slot]
      output[slot] = move and {
        id="move." .. slot, sourceIndex=move.sourceIndex,
        label=move.name, right=("PP %d/%d"):format(move.pp, move.maxPp),
        actionId=move.actionId,
      } or {
        id="move." .. slot, sourceIndex=slot,
        label="---", right="--", disabled=true,
      }
    end
    return output
  end

  local function statRows(source)
    local output = {}
    for index, stat in ipairs(source.stats.values or {}) do
      output[index] = {
        id="stat." .. stat.id, label=stat.label,
        right=stat.value, disabled=true,
      }
    end
    return output
  end

  local function eggRows(source)
    local output = {}
    for index, line in ipairs(source.egg.lines or {}) do
      output[index] = {
        id="egg.line." .. index, label=line, disabled=true,
      }
    end
    return output
  end

  local function summaryDescription(source)
    if source.mode == "egg" then
      return "A/B BACK   UP/DOWN POKEMON"
    end
    if source.mode == "move_reorder" then
      if source.moveDetail and source.moveDetail.reorderActive then
        return "A PLACE MOVE   UP/DOWN MOVE   B CANCEL"
      end
      return "A PICK MOVE   UP/DOWN MOVE   B BACK"
    end
    if source.purpose == "moves" then
      return "SELECT VIEW MOVES   UP/DOWN POKEMON   B BACK"
    end
    return "LEFT/RIGHT PAGE   UP/DOWN POKEMON   B BACK"
  end

  local function summaryControlLegend(source)
    if source.mode == "egg" then
      return {
        { label="A/B BACK" },
        { label="UP/DOWN POKEMON" },
      }
    end
    if source.mode == "move_reorder" then
      if source.moveDetail and source.moveDetail.reorderActive then
        return {
          { label="A PLACE MOVE" },
          { label="UP/DOWN MOVE" },
          { label="B CANCEL" },
        }
      end
      return {
        { label="A PICK MOVE" },
        { label="UP/DOWN MOVE" },
        { label="B BACK" },
      }
    end
    if source.purpose == "moves" then
      return {
        { label="SELECT VIEW MOVES" },
        { label="UP/DOWN POKEMON" },
        { label="B BACK" },
      }
    end
    return {
      { label="LEFT/RIGHT PAGE" },
      { label="UP/DOWN POKEMON" },
      { label="B BACK" },
    }
  end

  local function convertSummary(source)
    if type(source) ~= "table" or source.preset ~= "L" then
      return nil, "preset_mismatch"
    end
    local rows
    if source.mode == "egg" then
      rows = eggRows(source)
    elseif source.purpose == "status" then
      rows = statusRows(source)
    elseif source.purpose == "moves" then
      rows = moveRows(source)
    elseif source.purpose == "stats" then
      rows = statRows(source)
    else
      return nil, "unknown_purpose"
    end
    local selected = source.mode == "move_reorder"
      and source.navigation.moveIndex or nil
    local titleName = source.pokemon and source.pokemon.name or "POKEMON"
    -- Gen2's source pages are navigated in this order: pink/status,
    -- green/moves, blue/stats. Keep the Clean labels in that same order so
    -- host-owned LEFT/RIGHT edges never land on a different visual tab.
    local visualTabs = {
      { id="journal", label="JOURNAL", sourcePage=1,
        selected=source.sourcePage == 1 },
      { id="moves", label="MOVES", sourcePage=2,
        selected=source.sourcePage == 2 },
      { id="details", label="DETAILS", sourcePage=3,
        selected=source.sourcePage == 3 },
    }
    local model = {
      kind="menu", screenId="Gen2SummaryMenu", preset="L", opaque=true,
      title=("%s - %s"):format(titleName,
        tostring(source.purpose or "summary"):upper()),
      rows=rows, selected=selected, scroll=0,
      details=summaryDetails(source),
      description=summaryDescription(source),
      controlLegend=summaryControlLegend(source),
      purpose=source.purpose, mode=source.mode,
      partyLayout="summary", pageTabs=visualTabs,
      sourcePage=source.sourcePage,
      summary={
        pokemon=Data.copy(source.pokemon), status=Data.copy(source.status),
        heldItem=Data.copy(source.heldItem), moves=Data.copy(source.moves),
        stats=Data.copy(source.stats), artwork=Data.copy(source.artwork),
        egg=Data.copy(source.egg), moveDetail=Data.copy(source.moveDetail),
        purpose=source.purpose,
      },
      controlScheme=Data.copy(SUMMARY_CONTROL_SCHEME),
      navigation=Data.copy(source.navigation),
      artwork=Data.copy(source.artwork),
      heldItem=Data.copy(source.heldItem),
      moveDetail=Data.copy(source.moveDetail),
    }
    if not Data.isFunctionFree(model) then return nil, "model_not_data" end
    return canonical(model)
  end

  local CONVERT = {
    Gen2PartyMenu=convertParty,
    Gen2SummaryMenu=convertSummary,
  }

  local function presenter(screenId)
    return {
      prepare=function(_, state, context)
        local adapter = PartyModels.adapterFor(screenId)
        if not adapter then return nil, "adapter_unavailable", screenId end
        local bundle, code, detail = adapter.extract(state, context)
        if type(bundle) ~= "table" or type(bundle.model) ~= "table" then
          return nil, code or "model_incomplete", detail
        end
        local model, conversionCode = CONVERT[screenId](bundle.model)
        if not model then return nil, conversionCode or "conversion_failed" end
        return {
          complete=true, model=model, sourceModel=bundle.model,
          actions=bundle.actions,
        }
      end,
    }
  end

  function PartyPresenters.register(provider)
    if type(provider) ~= "table"
        or type(provider.registerPresenter) ~= "function" then
      return nil, "invalid_provider", "registerPresenter"
    end
    for _, screenId in ipairs(PartyModels.ids()) do
      local ok, code, detail = provider:registerPresenter(screenId,
        presenter(screenId))
      if not ok then return nil, code, detail end
    end
    return true
  end

  function PartyPresenters.convert(screenId, sourceModel)
    local convert = CONVERT[screenId]
    if not convert then return nil, "unknown_screen", screenId end
    return convert(sourceModel)
  end

  return PartyPresenters
end
