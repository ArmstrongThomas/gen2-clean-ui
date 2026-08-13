return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.specialty_common")
  local Mailbox = {}

  local SUBMENU = {
    { id="read", label="READ MAIL" },
    { id="pack", label="PUT IN PACK" },
    { id="attach", label="ATTACH MAIL" },
    { id="cancel", label="CANCEL" },
  }

  local function entrySnapshot(entry, index)
    return Common.mailEntry(entry, index)
  end

  function Mailbox.extract(state, context)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    if rawget(state, "picking") == true then
      local childId = Common.activeScreenId(context)
      if childId ~= "Gen2MailRead" then
        return Common.fail("native_child", "Gen2PartyMenu")
      end
    end
    if type(rawget(state, "picking")) ~= "boolean" then
      return Common.fail("shape_type", "picking:boolean")
    end
    local save = rawget(state, "save")
    local mail = type(save) == "table" and rawget(save, "mail") or nil
    local source = type(mail) == "table" and rawget(mail, "box") or nil
    local count, countCode = Common.arrayCount(source, 10)
    if not count then return Common.fail(countCode, "save.mail.box") end
    local index = Common.integer(rawget(state, "index"), 1, math.max(1, count))
    local scroll = Common.integer(rawget(state, "scroll"), 0,
      math.max(0, count - 1))
    if not index then return Common.fail("cursor_invalid", "index") end
    if not scroll then return Common.fail("scroll_invalid", "scroll") end

    local entries, rows = {}, {}
    for entryIndex = 1, count do
      local entry, code = entrySnapshot(rawget(source, entryIndex), entryIndex)
      if not entry then return Common.fail(code, tostring(entryIndex)) end
      entries[entryIndex] = entry
      rows[entryIndex] = Common.row("mail_" .. entryIndex,
        entry.author ~= "" and entry.author or "(NO AUTHOR)", entryIndex,
        entry.type)
      rows[entryIndex].selected = entryIndex == index
    end

    local submenu, message, confirm
    local sourceSubmenu = rawget(state, "submenu")
    if sourceSubmenu ~= nil then
      if type(sourceSubmenu) ~= "table" then
        return Common.fail("shape_type", "submenu:table")
      end
      local selected = Common.integer(rawget(sourceSubmenu, "index"), 1, 4)
      if not selected then return Common.fail("cursor_invalid", "submenu.index") end
      submenu = { selectedIndex=selected, rows=Data.copy(SUBMENU) }
    end
    if rawget(state, "message") ~= nil then
      local code
      message, code = Common.paged(rawget(state, "message"), false)
      if not message then return Common.fail(code, "message") end
    end
    if rawget(state, "confirm") ~= nil then
      local code
      confirm, code = Common.paged(rawget(state, "confirm"), true)
      if not confirm then return Common.fail(code, "confirm") end
    end
    local overlays = (submenu and 1 or 0) + (message and 1 or 0)
      + (confirm and 1 or 0)
    if overlays > 1 then return Common.fail("mode_conflict", "mailbox overlays") end
    local childRead = rawget(state, "picking") == true
      and Common.activeScreenId(context) == "Gen2MailRead"
    local mode = childRead and "child_read" or message and "message" or confirm and "confirm"
      or submenu and "submenu" or "list"
    if count == 0 and not message then
      return Common.fail("empty_without_message", "mailbox")
    end
    local actions = Common.actionMap("Gen2MailboxMenu", {
      { input="up", id="mailbox.up", kind="navigate" },
      { input="down", id="mailbox.down", kind="navigate" },
      { input="a", id="mailbox.choose", kind="choose" },
      { input="b", id="mailbox.back", kind="back" },
    })
    return Common.bundle("Gen2MailboxMenu", {
      family="mail", preset="M", title="MAILBOX", mode=mode,
      navigation={ selectedIndex=index, scroll=scroll, count=count,
        visibleRows=4 }, rows=rows, entries=entries,
      selectedEntry=entries[index], submenu=submenu,
      message=message, confirm=confirm,
      child={ active=childRead, screenId=childRead and "Gen2MailRead" or nil },
    }, actions)
  end

  return Mailbox
end
