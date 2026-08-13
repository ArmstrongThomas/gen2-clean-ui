return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.storage_common")
  local Models = ctx.load("presenters.naming_storage_models")
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

  local function messageRows(message)
    local output = {}
    for index, line in ipairs(message and message.lines or {}) do
      output[index] = {
        id="message_" .. index, sourceIndex=index,
        label=line, disabled=true,
      }
    end
    return output
  end

  local function messageModal(message)
    if type(message) ~= "table" then return nil end
    return {
      title=joined(message.lines),
      selected=1,
      options={{ id="continue", label="CONTINUE", sourceIndex=1 }},
    }
  end

  local function confirmModal(confirm)
    if type(confirm) ~= "table" then return nil end
    return {
      title=joined(confirm.prompt),
      selected=confirm.selectedChoice,
      options=Data.copy(confirm.choices),
    }
  end

  local function naming(source)
    local rows = {}
    local cursor = source.cursor or {}
    for rowIndex, cells in ipairs(source.keyboard.rows or {}) do
      local labels = {}
      for col = 1, #cells do
        local value = cells[col]
        labels[col] = value == " " and " "
          or Data.text(value, tostring(value or ""))
      end
      rows[#rows + 1] = {
        id="keyboard_row_" .. (rowIndex - 1),
        sourceIndex=rowIndex,
        label=table.concat(labels, "  "),
        right=not cursor.bottomRow and cursor.row == rowIndex - 1
          and ("COL " .. tostring(cursor.col)) or "",
      }
    end
    for index, target in ipairs(source.keyboard.bottom or {}) do
      rows[#rows + 1] = {
        id=target.id, sourceIndex=#source.keyboard.rows + index,
        label=target.label,
      }
    end
    local selected = cursor.bottomRow
      and (#source.keyboard.rows + (cursor.targetIndex or 1))
      or ((cursor.row or 0) + 1)
    local details = {
      sprite=source.sprite and source.sprite.path and {
        path=source.sprite.path, palette=Data.copy(source.sprite.palette),
      } or nil,
      fields={
        { label="ENTRY", value=source.entry.text },
        { label="LENGTH", value=("%d/%d"):format(
          source.entry.sourceLength or 0, source.entry.maxLength or 0) },
        { label="CASE", value=(source.case or "upper"):upper() },
        { label="CURSOR", value=("%d,%d"):format(
          cursor.col or 0, cursor.row or 0) },
      },
    }
    return {
      kind="menu", preset="XL", opaque=true,
      title=source.monName ~= "" and (source.monName .. "'S NICKNAME")
        or source.prompt,
      rows=rows, selected=selected, scroll=0, details=details,
      description="A TYPE   SELECT CASE   B DELETE   START FOCUS END",
      naming=Data.copy({
        context=source.context, isBox=source.isBox,
        entry=source.entry, case=source.case, keyboard=source.keyboard,
        cursor=source.cursor, sprite=source.sprite,
      }),
    }
  end

  local function centerPc(source)
    local rows = source.mode == "message"
      and messageRows(source.message) or copyRows(source.entries)
    return {
      kind="menu", preset="M", opaque=true,
      title=source.mode == "message" and "PC MESSAGE" or "ACCESS WHOSE PC?",
      rows=rows,
      selected=source.mode == "message" and nil
        or source.navigation.selectedIndex,
      scroll=0,
      modal=source.mode == "confirm" and confirmModal(source.confirm) or nil,
      description=source.mode == "message" and "A/B CONTINUE"
        or source.mode == "confirm" and "A CHOOSE   B NO"
        or "A CHOOSE   B TURN OFF",
      storage=Data.copy(source),
    }
  end

  local function pc(source)
    local rows, selected, title
    if source.mode == "message" then
      rows, selected, title = messageRows(source.message), nil, "PC MESSAGE"
    elseif source.mode == "box_picker" then
      rows = copyRows(source.picker.boxes)
      selected, title = source.picker.selectedIndex, "CHANGE BOX"
    else
      rows = copyRows(source.entries)
      selected, title = source.navigation.selectedIndex, "POKEMON STORAGE"
    end
    return {
      kind="menu", preset="M", opaque=true,
      title=title, rows=rows, selected=selected,
      scroll=source.mode == "box_picker"
        and math.max(0, (selected or 1) - 6) or 0,
      description=source.mode == "message" and "A/B CONTINUE"
        or source.mode == "box_picker" and "A CHANGE   B CANCEL"
        or "A CHOOSE   B CLOSE",
      storage=Data.copy(source),
    }
  end

  local function box(source)
    local modal
    if source.view == "submenu" and source.submenu then
      modal = {
        title=source.prompt,
        selected=source.submenu.selectedIndex,
        options=copyRows(source.submenu.rows),
      }
    elseif source.view == "message" then
      modal = messageModal(source.message)
    end
    return {
      kind="menu", preset="XL", opaque=true,
      title=(source.title or "BOX") .. "  " .. (source.mode or ""):upper(),
      rows=copyRows(source.rows),
      selected=source.navigation.selectedIndex,
      scroll=source.navigation.scroll,
      details=(function()
        local mon = source.selectedMon
        if type(mon) ~= "table" then return {} end
        return {
          sprite=type(mon.artwork) == "table"
            and Data.copy(mon.artwork) or nil,
          fields=Common.detailsForMon(mon),
        }
      end)(),
      modal=modal,
      description=source.view == "insert"
        and "UP/DOWN SLOT   LEFT/RIGHT BOX   A MOVE   B CANCEL"
        or source.view == "submenu" and "A CHOOSE   B CANCEL"
        or source.view == "message" and "A/B CONTINUE"
        or source.mode == "withdraw"
          and "A ACTIONS   SELECT RELEASE   START NICKNAME   B BACK"
        or "A CHOOSE   B BACK",
      storage=Data.copy(source),
    }
  end

  local function itemPc(source)
    local rows, selected, title
    if source.phase == "menu" then
      rows, selected, title = copyRows(source.entries),
        source.navigation.selectedIndex, "ITEM STORAGE"
    elseif source.phase == "deposit" then
      rows = copyRows(source.deposit and source.deposit.rows or {})
      selected = source.deposit and source.deposit.pocket
        and source.deposit.pocket.selectedIndex or source.navigation.selectedIndex
      title = "DEPOSIT ITEM"
      if source.deposit and source.deposit.pocket
          and source.deposit.pocket.pocket then
        title = title .. "  " .. source.deposit.pocket.pocket.label
      end
    else
      rows, selected = copyRows(source.rows), source.navigation.selectedIndex
      title = source.phase == "toss" and "TOSS ITEM" or "WITHDRAW ITEM"
    end
    local details = {}
    for _, line in ipairs(source.description or {}) do
      details[#details + 1] = { label="INFO", value=line }
    end
    if source.quantity then
      details[#details + 1] = {
        label="QUANTITY",
        value=("%d/%d"):format(source.quantity.value,
          source.quantity.maximum),
        style="accent",
      }
    end
    local modal = source.view == "confirm" and confirmModal(source.confirm)
      or source.view == "message" and messageModal(source.message) or nil
    return {
      kind="menu", preset="L", opaque=true,
      title=title, rows=rows, selected=selected,
      scroll=source.navigation.scroll, details=details, modal=modal,
      description=source.view == "quantity"
          and (joined(source.quantity.prompt)
            .. "   LEFT/RIGHT x10   A OK   B CANCEL")
        or source.view == "confirm" and "A CHOOSE   B NO"
        or source.view == "message" and "A/B CONTINUE"
        or source.phase == "deposit"
          and "LEFT/RIGHT POCKET   A CHOOSE   B BACK"
        or "A CHOOSE   B BACK",
      storage=Data.copy(source),
    }
  end

  local CONVERT = {
    Gen2NamingScreen=naming,
    Gen2CenterPcMenu=centerPc,
    Gen2PcMenu=pc,
    Gen2BoxMenu=box,
    Gen2ItemPcMenu=itemPc,
  }

  local function presenter(screenId)
    return {
      prepare=function(_, state, context)
        local adapter = Models.adapterFor(screenId)
        local bundle, code, detail = adapter.extract(state, context)
        if type(bundle) ~= "table" or type(bundle.model) ~= "table" then
          return nil, code or "model_incomplete", detail
        end
        local model = CONVERT[screenId](bundle.model)
        if type(model) ~= "table" or not Data.isFunctionFree(model) then
          return nil, "conversion_failed"
        end
        return {
          complete=true, model=model,
          sourceModel=bundle.model, actions=bundle.actions,
        }
      end,
    }
  end

  function Presenters.register(provider)
    for _, screenId in ipairs(Models.ids()) do
      local ok, code, detail = provider:registerPresenter(screenId,
        presenter(screenId))
      if not ok then return nil, code, detail end
    end
    return true
  end

  function Presenters.convert(screenId, sourceModel)
    local convert = CONVERT[screenId]
    if not convert then return nil, "unknown_screen" end
    local model = convert(sourceModel)
    if not Data.isFunctionFree(model) then return nil, "conversion_failed" end
    return model
  end

  return Presenters
end
