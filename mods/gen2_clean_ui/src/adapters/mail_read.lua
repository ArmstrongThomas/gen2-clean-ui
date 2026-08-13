return function(ctx)
  local Data = ctx.load("adapters.data")
  local Common = ctx.load("adapters.specialty_common")
  local MailRead = {}

  local function splitMessage(message)
    local top, bottom = message:match("^(.-)\n(.*)$")
    if top then return top, bottom end
    local chars = Common.characters(message)
    if #chars <= 16 then return message, "" end
    return table.concat(chars, "", 1, 16),
      table.concat(chars, "", 17, math.min(32, #chars))
  end

  function MailRead.extract(state)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    local entry, entryCode = Common.mailEntry(rawget(state, "entry"))
    if not entry then return Common.fail(entryCode, "entry") end
    local mailType, message, author = entry.type, entry.message, entry.author
    local top, bottom = splitMessage(message)
    local actions = Common.actionMap("Gen2MailRead", {
      { input="a", id="mail.close_a", kind="close" },
      { input="b", id="mail.close_b", kind="close" },
      { input="start", id="mail.close_start", kind="close" },
    })
    return Common.bundle("Gen2MailRead", {
      family="mail", preset="M", title="READ MAIL", mode="read",
      entry=Data.copy(entry),
      lines={ top, bottom },
      authorColumn=mailType == "PORTRAITMAIL" and 8
        or mailType == "MORPH_MAIL" and 6 or 5,
    }, actions)
  end

  return MailRead
end
