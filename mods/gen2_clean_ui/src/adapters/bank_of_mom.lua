return function(ctx)
  local Common = ctx.load("adapters.service_common")
  local Bank = {}
  local SCREEN_ID = "Gen2BankOfMom"
  local PLACES = { 100000, 10000, 1000, 100, 10, 1 }

  function Bank.extract(state, context)
    local ok, code, detail = Common.exactState(state, SCREEN_ID)
    if not ok then return nil, code, detail end
    if Common.inBattle(context) then return nil, "battle_owned", SCREEN_ID end
    local kind = rawget(state, "kind")
    if kind ~= "deposit" and kind ~= "withdraw" then
      return Common.fail("unknown_mode", "kind=" .. tostring(kind))
    end
    local saved = Common.integer(rawget(state, "saved"), 0, 999999)
    local held = Common.integer(rawget(state, "held"), 0, 999999)
    local amount = Common.integer(rawget(state, "amount"), 0, 999999)
    local position = Common.integer(rawget(state, "position"), 0, 5)
    local blink = rawget(state, "blink")
    if not (saved and held and amount and position and Common.finite(blink))
        or blink < 0 then
      return Common.fail("shape_range", "bank fields")
    end
    local actions = Common.inputActions(SCREEN_ID, {
      { input="up", kind="adjust" }, { input="down", kind="adjust" },
      { input="left", kind="navigate" },
      { input="right", kind="navigate" },
      { input="a", kind="confirm" }, { input="b", kind="cancel" },
    })
    local digits = ("%06d"):format(amount)
    local rows = {}
    for index, place in ipairs(PLACES) do
      rows[index] = {
        id="digit_" .. (index - 1), sourceIndex=index,
        label=("%06d PLACE"):format(place), right=digits:sub(index, index),
        selected=position == index - 1,
      }
    end
    return Common.bundle({
      schema="clean_ui.presenter_model.v1",
      screenId=SCREEN_ID, family="services", preset="XS",
      title=kind == "withdraw" and "WITHDRAW" or "DEPOSIT",
      kind=kind, saved=saved, held=held, amount=amount,
      position=position, blink=blink, rows=rows,
      navigation={ selectedIndex=position + 1, digitCount=6 },
    }, actions)
  end

  return Bank
end
