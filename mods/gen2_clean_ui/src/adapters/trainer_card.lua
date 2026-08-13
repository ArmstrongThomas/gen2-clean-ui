return function(ctx)
  local Data = ctx.load("adapters.data")
  local Actions = ctx.load("adapters.actions")
  local TrainerCard = {}

  local JOHTO_BADGES = {
    "ZEPHYR", "HIVE", "PLAIN", "FOG",
    "STORM", "MINERAL", "GLACIER", "RISING",
  }
  local KANTO_BADGES = {
    "BOULDER", "CASCADE", "THUNDER", "RAINBOW",
    "SOUL", "MARSH", "VOLCANO", "EARTH",
  }

  local function sourceInput(actions, id, kind, componentId, input)
    return Actions.add(actions, {
      id = id, source = "screen.update", kind = kind,
      componentId = componentId, dispatch = "source_input", input = input,
    })
  end

  local function child(source, key)
    local value = type(source) == "table" and rawget(source, key) or nil
    return type(value) == "table" and value or {}
  end

  local function badgeRows(names, owned)
    local output = {}
    for index, name in ipairs(names) do
      local earned = rawget(owned, name) == true or rawget(owned, index) == true
      output[index] = {
        id = name:lower(), sourceIndex = index,
        name = name, label = name, owned = earned,
      }
    end
    return output
  end

  local function countOwned(rows)
    local count = 0
    for _, row in ipairs(rows) do if row.owned then count = count + 1 end end
    return count
  end

  local function hasEntries(value)
    return type(value) == "table" and next(value, nil) ~= nil
  end

  function TrainerCard.extract(state)
    if type(state) ~= "table" then return nil, "state_type", "table" end
    local save = rawget(state, "save")
    if type(save) ~= "table" then return nil, "save_type", "table" end
    local player = child(save, "player")
    local pokedex = child(save, "pokedex")
    local playTime = child(save, "playTime")
    local johto = badgeRows(JOHTO_BADGES, child(player, "badges"))
    local kantoSource = child(player, "kantoBadges")
    local kanto = badgeRows(KANTO_BADGES, kantoSource)
    local pageCount = hasEntries(kantoSource) and 3 or 2
    local page = Data.integer(rawget(state, "page"), 1)
    local actions = Actions.new("Gen2TrainerCard")

    local model = {
      schema = "clean_ui.presenter_model.v1",
      screenId = "Gen2TrainerCard",
      family = "trainer",
      preset = "L",
      title = "TRAINER CARD",
      page = page,
      pageCount = pageCount,
      frames = Data.integer(rawget(state, "frames"), 0),
      player = {
        name = Data.text(rawget(player, "name"), "GOLD"),
        id = Data.integer(rawget(player, "id"), 0),
        money = math.max(0, Data.integer(rawget(player, "money"), 0)),
        gender = Data.text(rawget(player, "gender"), ""),
      },
      pokedexCaught = Data.countTruthy(rawget(pokedex, "caught")),
      playTime = {
        hours = Data.integer(rawget(playTime, "hours"), 0),
        minutes = Data.integer(rawget(playTime, "minutes"), 0),
      },
      pages = {
        {
          id = "trainer", sourcePage = 1, label = "TRAINER",
          kind = "trainer",
        },
        {
          id = "johto_badges", sourcePage = 2, label = "JOHTO BADGES",
          kind = "badges", region = "johto", badges = johto,
          ownedCount = countOwned(johto),
        },
        {
          id = "kanto_badges", sourcePage = 3, label = "KANTO BADGES",
          kind = "badges", region = "kanto", badges = kanto,
          ownedCount = countOwned(kanto), available = pageCount == 3,
        },
      },
      controls = {
        previousPage = sourceInput(actions, "page.previous", "navigate",
          "trainer_card", "left"),
        nextPage = sourceInput(actions, "page.next", "navigate",
          "trainer_card", "right"),
        accept = sourceInput(actions, "page.accept", "action", "trainer_card",
          "a"),
        back = sourceInput(actions, "trainer_card.back", "close",
          "trainer_card", "b"),
        closeWithStart = sourceInput(actions, "trainer_card.start", "close",
          "trainer_card", "start"),
      },
    }
    model.currentPage = Data.copy(model.pages[page])
    model.actionDescriptors = Actions.describe(actions)
    return { model = model, actions = actions }
  end

  TrainerCard.JOHTO_BADGES = JOHTO_BADGES
  TrainerCard.KANTO_BADGES = KANTO_BADGES
  return TrainerCard
end
