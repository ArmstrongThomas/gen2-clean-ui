return function(ctx)
  local Data = ctx.load("adapters.data")
  local Models = ctx.load("presenters.mail_specialty_models")
  local Presenters = {}

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
      title=joined(message.lines), selected=1,
      options={{ id="continue", label="CONTINUE", sourceIndex=1 }},
    }
  end

  local function confirmModal(confirm)
    if type(confirm) ~= "table" then return nil end
    return {
      title=joined(confirm.prompt), selected=confirm.selectedChoice,
      options=Data.copy(confirm.choices),
    }
  end

  local function keyboardRows(source)
    local rows = {}
    for rowIndex, cells in ipairs(source.keyboard.rows or {}) do
      rows[rowIndex] = {
        id="keyboard_row_" .. (rowIndex - 1), sourceIndex=rowIndex,
        label=table.concat(cells, "  "),
        right=not source.cursor.bottomRow
          and source.cursor.row == rowIndex - 1
          and ("COL " .. tostring(source.cursor.col)) or "",
      }
    end
    for index, target in ipairs(source.keyboard.bottom or {}) do
      rows[#rows + 1] = {
        id=target.id, sourceIndex=#source.keyboard.rows + index,
        label=target.label,
      }
    end
    return rows
  end

  local function mailCompose(source)
    local selected = source.cursor.bottomRow
      and (#source.keyboard.rows + source.cursor.targetIndex)
      or source.cursor.row + 1
    return {
      kind="menu", preset="XL", opaque=true, title=source.title,
      rows=keyboardRows(source), selected=selected, scroll=0,
      details={
        title="MESSAGE",
        fields={
          { label="LINE 1", value=source.entry.lines[1] },
          { label="LINE 2", value=source.entry.lines[2] },
          { label="LENGTH", value=("%d/%d"):format(
            source.entry.length, source.entry.maximum) },
          { label="CASE", value=source.case:upper() },
          { label="CURSOR", value=("%d,%d"):format(
            source.cursor.col, source.cursor.row) },
        },
      },
      description="A TYPE   SELECT CASE   B DELETE   START FOCUS END",
      specialty=Data.copy(source),
    }
  end

  local function mailMenu(source)
    local fields = {
      { label="POKEMON", value=source.pokemon.name },
      { label="SPECIES", value=source.pokemon.species },
      { label="HELD", value=source.pokemon.heldItem },
    }
    if source.mail then
      fields[#fields + 1] = { label="MAIL", value=source.mail.type }
      fields[#fields + 1] = { label="AUTHOR", value=source.mail.author }
    end
    return {
      kind="menu", preset="M", opaque=false, title=source.title,
      rows=copyRows(source.rows), selected=source.navigation.selectedIndex,
      scroll=0, details={ fields=fields },
      modal=messageModal(source.message) or confirmModal(source.confirm),
      description=source.mode == "child_read" and "READING MAIL"
        or source.mode == "message" and "A/B CONTINUE"
        or source.mode == "confirm" and "A CHOOSE   B NO"
        or "A CHOOSE   B QUIT",
      specialty=Data.copy(source),
    }
  end

  local function mailRead(source)
    return {
      kind="menu", preset="M", opaque=true, title=source.title,
      rows={
        { id="mail_line_1", sourceIndex=1, label=source.lines[1], disabled=true },
        { id="mail_line_2", sourceIndex=2, label=source.lines[2], disabled=true },
      },
      details={ fields={
        { label="AUTHOR", value=source.entry.author },
        { label="STATIONERY", value=source.entry.type },
        { label="POKEMON", value=source.entry.species },
      } },
      description="A/B/START CLOSE", specialty=Data.copy(source),
    }
  end

  local function mailbox(source)
    local selected = source.selectedEntry
    local details = { fields={} }
    if selected then
      details.fields = {
        { label="AUTHOR", value=selected.author },
        { label="STATIONERY", value=selected.type },
        { label="POKEMON", value=selected.species },
        { label="MESSAGE", value=selected.message },
      }
    end
    local modal
    if source.submenu then
      modal = { title="MAIL ACTIONS",
        selected=source.submenu.selectedIndex,
        options=copyRows(source.submenu.rows) }
    else
      modal = messageModal(source.message) or confirmModal(source.confirm)
    end
    return {
      kind="menu", preset="M", opaque=false, title=source.title,
      rows=copyRows(source.rows), selected=source.navigation.selectedIndex,
      scroll=source.navigation.scroll, details=details, modal=modal,
      description=source.mode == "message" and "A/B CONTINUE"
        or source.mode == "confirm" and "A CHOOSE   B NO"
        or source.mode == "submenu" and "A CHOOSE   B CANCEL"
        or "A OPEN   B CLOSE",
      specialty=Data.copy(source),
    }
  end

  local function decoration(source)
    local fields = {
      { label="MODE", value=source.underlyingMode:upper() },
      { label="CHANGED", value=source.changed and "YES" or "NO" },
    }
    if source.category then
      fields[#fields + 1] = { label="CATEGORY",
        value=source.category.label or source.category.pendingName or "" }
    end
    return {
      kind="menu", preset="L", opaque=true, title=source.title,
      rows=copyRows(source.rows), selected=source.navigation.selectedIndex,
      scroll=source.navigation.scroll, details={ fields=fields },
      modal=messageModal(source.message),
      description=source.mode == "message" and "A/B CONTINUE"
        or source.underlyingMode == "side" and "A PLACE   B CANCEL"
        or "A CHOOSE   B BACK",
      specialty=Data.copy(source),
    }
  end

  local function trade(source)
    local rows = {
      { id="give", sourceIndex=1, label="YOU GIVE",
        right=source.offer.give.label, disabled=true },
      { id="receive", sourceIndex=2, label="YOU RECEIVE",
        right=source.offer.receive.nickname ~= ""
          and source.offer.receive.nickname or source.offer.receive.label,
        disabled=true },
    }
    local modal = messageModal(source.message) or confirmModal(source.confirm)
    return {
      kind="menu", preset="L", opaque=false, title=source.title,
      rows=rows, details={ fields={
        { label="WANTED", value=source.offer.give.label },
        { label="OFFERED", value=source.offer.receive.label },
        { label="GENDER", value=source.offer.gender },
        { label="OT", value=source.offer.trainer },
        { label="ID", value=source.offer.trainerId or "?" },
      } }, modal=modal,
      description=source.mode == "confirm" and "A CHOOSE   B NO"
        or "A/B CONTINUE",
      specialty=Data.copy(source),
    }
  end

  local function namePick(source)
    return {
      kind="menu", preset="M", opaque=true, title=source.title,
      rows=copyRows(source.rows), selected=source.navigation.selectedIndex,
      scroll=0, details={ sprite=Data.copy(source.sprite), fields={
        { label="SELECTED", value=source.selectedName },
        { label="CUSTOM NAME", value=source.namingAvailable and "YES" or "NO" },
        { label="ANIMATION", value=source.slide or "READY" },
      } },
      description=source.slide and "PLEASE WAIT"
        or "A/START CHOOSE",
      specialty=Data.copy(source),
    }
  end

  local function clock(source)
    local rows = {}
    for index, line in ipairs(source.question.lines or {}) do
      rows[#rows + 1] = { id="question_" .. index,
        sourceIndex=index, label=line, disabled=true }
    end
    if source.display then
      rows[#rows + 1] = { id="clock_value", sourceIndex=#rows + 1,
        label=source.display }
    end
    return {
      kind="menu", preset="M", opaque=true, title=source.title,
      rows=rows, selected=source.display and #rows or nil, scroll=0,
      details={ fields={
        { label="TIME", value=source.values.time },
        { label="DAY", value=source.values.dayName },
        { label="STEP", value=source.phase:upper() },
      } },
      modal=source.confirm and confirmModal({
        prompt=source.question.lines,
        selectedChoice=source.confirm.selectedChoice,
        choices=source.confirm.choices,
      }) or nil,
      description=source.confirm and "A CHOOSE   B NO"
        or source.display and "UP/DOWN ADJUST   A ACCEPT"
        or "A CONTINUE",
      specialty=Data.copy(source),
    }
  end

  local function diploma(source)
    local rows = {}
    for index, line in ipairs(source.certification or {}) do
      rows[index] = { id="certificate_" .. index,
        sourceIndex=index, label=line, disabled=true }
    end
    return {
      kind="menu", preset="L", opaque=true, title=source.title,
      rows=rows, details={ title="PLAYER", fields={
        { label="NAME", value=source.playerName, style="accent" },
        { label="ACHIEVEMENT", value="POKEDEX COMPLETE" },
      } }, description="A/B CLOSE", specialty=Data.copy(source),
    }
  end

  local function photo(source)
    local mon = source.pokemon
    return {
      kind="menu", preset="L", opaque=true, title=source.title,
      rows={{ id="first_move", sourceIndex=1, label="MOVE",
        right=mon.firstMove.name, disabled=true }},
      details={ title=mon.nickname, sprite=Data.copy(source.artwork), fields={
        { label="NO.", value=("%03d"):format(mon.dex) },
        { label="SPECIES", value=mon.speciesName },
        { label="LEVEL", value=mon.level },
        { label="MAX HP", value=mon.maxHp },
        { label="GENDER", value=mon.gender },
        { label="OT", value=mon.trainer },
        { label="ID", value=("%05d"):format(mon.trainerId) },
      } }, description="A/B CLOSE", specialty=Data.copy(source),
    }
  end

  local function unown(source)
    local rows = {}
    for index, item in ipairs(source.menu or {}) do
      rows[index] = { id="printer_" .. item.input, sourceIndex=index,
        label=item.input:upper(), right=item.label,
        disabled=item.available ~= true }
    end
    return {
      kind="menu", preset="L", opaque=true, title=source.title,
      rows=rows, details={
        title=source.vacant and "VACANT" or ("UNOWN " .. source.letter),
        sprite=Data.copy(source.artwork), fields={
          { label="SLOT", value=("%d/%d"):format(
            source.navigation.slot, source.navigation.slotCount) },
          { label="FORM", value=source.letter or "VACANT" },
        },
      },
      description="LEFT/RIGHT FORM   A PRINT   B CLOSE",
      specialty=Data.copy(source),
    }
  end

  local function hall(source)
    local mon, roster = source.pokemon, source.roster
    return {
      kind="menu", preset="L", opaque=true, title=source.title,
      rows={{ id="record", sourceIndex=1, label="WIN",
        right=tostring(roster.winCount), disabled=true }},
      details={ title=mon.nickname, sprite=Data.copy(source.artwork), fields={
        { label="NO.", value=("%03d"):format(mon.dex) },
        { label="SPECIES", value=mon.speciesName },
        { label="LEVEL", value=mon.level },
        { label="ID", value=("%05d"):format(mon.trainerId) },
        { label="TEAM", value=("%d/%d"):format(
          roster.team, math.max(1, roster.teamCount)) },
        { label="POKEMON", value=("%d/%d"):format(
          roster.pokemonIndex, roster.pokemonCount) },
      } },
      description="A NEXT POKEMON   START NEXT TEAM   B CLOSE",
      specialty=Data.copy(source),
    }
  end

  local CONVERT = {
    Gen2MailCompose=mailCompose,
    Gen2MailMenu=mailMenu,
    Gen2MailRead=mailRead,
    Gen2MailboxMenu=mailbox,
    Gen2DecorationMenu=decoration,
    Gen2TradeMenu=trade,
    Gen2NamePick=namePick,
    Gen2InitClock=clock,
    Gen2Diploma=diploma,
    Gen2PhotoStudio=photo,
    Gen2UnownPrinter=unown,
    Gen2HallOfFame=hall,
  }

  local function presenter(screenId)
    return {
      prepare=function(_, state, context)
        local bundle, code, detail = Models.extract(screenId, state, context)
        if type(bundle) ~= "table" or type(bundle.model) ~= "table" then
          return nil, code or "model_incomplete", detail
        end
        local model = CONVERT[screenId](bundle.model)
        if type(model) ~= "table" or not Data.isFunctionFree(model) then
          return nil, "conversion_failed", screenId
        end
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
      if not ok then return nil, code, detail end
    end
    return true
  end

  function Presenters.convert(screenId, sourceModel)
    local convert = CONVERT[screenId]
    if not convert then return nil, "unknown_screen", screenId end
    local model = convert(sourceModel)
    if type(model) ~= "table" or not Data.isFunctionFree(model) then
      return nil, "conversion_failed", screenId
    end
    return model
  end

  return Presenters
end
