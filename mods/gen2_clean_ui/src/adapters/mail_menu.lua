return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.specialty_common")
  local MailMenu = {}

  local ENTRIES = {
    { id="read", label="READ" },
    { id="take", label="TAKE" },
    { id="quit", label="QUIT" },
  }

  local function mailEntry(save, slot)
    local mail = type(save) == "table" and rawget(save, "mail") or nil
    local party = type(mail) == "table" and rawget(mail, "party") or nil
    local entry = type(party) == "table" and rawget(party, slot) or nil
    return Common.mailEntry(entry, slot)
  end

  function MailMenu.extract(state, context)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    local save = rawget(state, "save")
    local slot = Common.integer(rawget(state, "slot"), 1, 6)
    local index = Common.integer(rawget(state, "index"), 1, 3)
    local reading = rawget(state, "reading")
    if type(save) ~= "table" then return Common.fail("shape_type", "save:table") end
    if not slot then return Common.fail("slot_invalid", "slot") end
    if not index then return Common.fail("cursor_invalid", "index") end
    if type(reading) ~= "boolean" then return Common.fail("shape_type", "reading:boolean") end
    if reading and Common.activeScreenId(context) ~= "Gen2MailRead" then
      return Common.fail("native_child", "Gen2MailRead")
    end
    local party = rawget(save, "party")
    local mon = type(party) == "table" and rawget(party, slot) or nil
    if type(mon) ~= "table" then return Common.fail("party_missing", tostring(slot)) end
    local mail, mailCode = mailEntry(save, slot)
    if not mail then return Common.fail(mailCode, "save.mail.party[slot]") end
    if rawget(mon, "item") ~= mail.type then
      return Common.fail("mail_item_mismatch", tostring(rawget(mon, "item")))
    end

    local message, confirm
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
    if message and confirm then return Common.fail("mode_conflict", "message+confirm") end

    local mode = reading and "child_read" or message and "message"
      or confirm and "confirm" or "actions"
    local rows = {}
    for rowIndex, entry in ipairs(ENTRIES) do
      rows[rowIndex] = Common.row(entry.id, entry.label, rowIndex)
      rows[rowIndex].selected = rowIndex == index
    end
    local actions = Common.actionMap("Gen2MailMenu", {
      { input="up", id="menu.up", kind="navigate" },
      { input="down", id="menu.down", kind="navigate" },
      { input="a", id="menu.choose", kind="choose" },
      { input="b", id="menu.back", kind="back" },
    })
    return Common.bundle("Gen2MailMenu", {
      family="mail", preset="M", title="HELD MAIL", mode=mode,
      navigation={ selectedIndex=index, rowCount=3 }, rows=rows,
      pokemon={ slot=slot,
        name=Data.text(rawget(mon, "nickname"),
          Data.text(rawget(mon, "name"), Data.text(rawget(mon, "species"), "POKEMON"))),
        species=Data.text(rawget(mon, "species"), ""),
        heldItem=Data.text(rawget(mon, "item"), "") },
      mail=mail, message=message, confirm=confirm,
      child={ active=reading, screenId=reading and "Gen2MailRead" or nil },
    }, actions)
  end

  return MailMenu
end
