return function(ctx)
  local Common = ctx.load("adapters.specialty_common")
  local Clock = {}

  local DAYS = {
    "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY",
    "THURSDAY", "FRIDAY", "SATURDAY",
  }
  local PHASES = {
    intro=true, hour=true, minute=true, day=true,
    ["confirm-hour"]=true, ["confirm-minute"]=true,
    ["confirm-day"]=true, response=true,
  }

  local function hourString(hour)
    local value = hour % 12
    if value == 0 then value = 12 end
    local daypart = hour < 4 and "NITE" or hour < 10 and "MORN"
      or hour < 18 and "DAY" or "NITE"
    return ("%s %d"):format(daypart, value)
  end

  local function content(phase, hour, minute, day)
    if phase == "intro" then
      return { "Zzz... Hm? Wha...?\nYou woke me up!",
        "Will you check the\nclock for me?" }, nil
    end
    if phase == "hour" then return { "What time is it?" }, hourString(hour) .. " o'clock" end
    if phase == "minute" then return { "How many minutes?" }, ("%d min."):format(minute) end
    if phase == "day" then return { "What day is it?" }, DAYS[day + 1] end
    if phase == "confirm-hour" then
      return { ("What?\n%s?"):format(hourString(hour) .. " o'clock") }, nil
    end
    if phase == "confirm-minute" then
      return { ("Whoa!\n%d min.?"):format(minute) }, nil
    end
    if phase == "confirm-day" then
      return { ("%s, is that right?"):format(DAYS[day + 1]) }, nil
    end
    local complete = ("%s:%02d"):format(hourString(hour), minute)
    local suffix = (hour < 4 or hour >= 18) and "It's so dark!"
      or hour <= 10 and "I overslept!" or "Yikes! I overslept!"
    return { complete .. "\n" .. suffix }, nil
  end

  function Clock.extract(state)
    if type(state) ~= "table" then return Common.fail("state_type", "table") end
    local mode, phase = rawget(state, "mode"), rawget(state, "phase")
    if mode ~= "clock" and mode ~= "day" then return Common.fail("mode_invalid", tostring(mode)) end
    if not PHASES[phase] then return Common.fail("phase_invalid", tostring(phase)) end
    if (mode == "day" and phase ~= "day" and phase ~= "confirm-day")
        or (mode == "clock" and (phase == "day" or phase == "confirm-day")) then
      return Common.fail("phase_invalid", mode .. ":" .. tostring(phase))
    end
    local hour = Common.integer(rawget(state, "hour"), 0, 23)
    local minute = Common.integer(rawget(state, "minute"), 0, 59)
    local day = Common.integer(rawget(state, "day"), 0, 6)
    local yesNo = Common.integer(rawget(state, "yesNo"), 1, 2)
    if not hour or not minute or not day or not yesNo then
      return Common.fail("clock_value_invalid", "hour/minute/day/yesNo")
    end
    if type(rawget(state, "save")) ~= "table"
        or type(rawget(state, "autoConfirm")) ~= "boolean" then
      return Common.fail("shape_type", "save/autoConfirm")
    end
    local pages, display = content(phase, hour, minute, day)
    local page = Common.integer(rawget(state, "page"), 1, #pages)
    if not page then return Common.fail("page_index", "page") end
    local lines = assert(Common.lines(pages[page]))
    local confirming = phase == "confirm-hour" or phase == "confirm-minute"
      or phase == "confirm-day"
    local actions = Common.actionMap("Gen2InitClock", {
      { input="up", id="clock.increment", kind="increment" },
      { input="down", id="clock.decrement", kind="decrement" },
      { input="a", id="clock.accept", kind="accept" },
      { input="b", id="clock.decline", kind="decline", enabled=confirming },
    })
    return Common.bundle("Gen2InitClock", {
      family="services", preset="M", title=mode == "day"
        and "SET DAY" or "SET CLOCK",
      mode=confirming and "confirm" or display and "picker" or "message",
      sourceMode=mode, phase=phase, autoConfirm=rawget(state, "autoConfirm"),
      values={ hour=hour, minute=minute, day=day, dayName=DAYS[day + 1],
        time=("%s:%02d"):format(hourString(hour), minute) },
      question={ page=page, pageCount=#pages, lines=lines }, display=display,
      confirm=confirming and { selectedChoice=yesNo, choices={
        { id="yes", sourceIndex=1, label="YES" },
        { id="no", sourceIndex=2, label="NO" },
      } } or nil,
    }, actions)
  end

  return Clock
end
