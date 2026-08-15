return function(ctx)
  local V3 = {}
  local Catalog = ctx and ctx.load and ctx.load("contracts.catalog")

  -- The editor needs the complete official screen inventory, not only the
  -- screens that currently have callback-free preview models. Keep this
  -- descriptor data-only: it describes production/native boundaries without
  -- inventing a V3 replacement or exposing source-owned callbacks.
  local function officialCatalogContract()
    assert(Catalog and type(Catalog.build) == "function",
      "Gen2 official catalog requires the contract catalog")
    local records = Catalog.build().records
    local gallery = {}
    for _, record in ipairs(records) do
      gallery[#gallery + 1] = {
        id = ("gen2.official.%02d"):format(record.officialIndex),
        family = record.family,
        title = record.id,
        support = record.support,
        implementation = record.support == "supported"
          and "production_presenter" or "native",
        milestone = record.milestone,
        preset = record.preset or "M",
        statusOnly = true,
        screen_id = record.id,
        reason = record.nativeReason,
      }
    end
    return {
      id = "gen2_official_catalog",
      version = "0.1.0",
      games = { "gen2" },
      screens = {},
      gallery = gallery,
    }
  end

  local function dialogueScreen()
    return {
      id = "shared_dialogue_preview",
      kind = "dialogue",
      schema = "clean_ui.v3.presentation.v1",
      apiVersion = 3,
      preset = "XS",
      opaque = false,
      anchor = "bottom",
      lines = {
        "V3 keeps the complete source message together and reflows it to the",
        "available surface instead of inheriting native pagination breaks.",
      },
      inputReady = true,
      more = true,
      controls = "A/B CONTINUE",
    }
  end

  local function choiceScreen()
    return {
      id = "shared_choice_preview",
      kind = "choice",
      schema = "clean_ui.v3.presentation.v1",
      apiVersion = 3,
      preset = "XS",
      opaque = false,
      anchor = "bottom",
      selected = 1,
      inputReady = true,
      options = {
        { id = "yes", label = "YES", value = true },
        { id = "no", label = "NO", value = false },
      },
    }
  end

  local function animationScreen()
    return {
      id = "battle_animation_preview", kind = "animation",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "ANIMATION", title = "BATTLE ANIMATION PREVIEW",
      animation = {
        id = "battle.move", frame = 12, duration = 32,
        progress = 0.375, label = "MOVE EFFECT",
        message = "The source owns timing; V3 owns the visual frame.",
      },
    }
  end

  local function transitionAnimationScreen()
    return {
      id = "battle_transition_preview", kind = "animation",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "ANIMATION", title = "BATTLE TRANSITION", opaque = false,
      animation = {
        id = "battle.transition", overlay = true, style = "spin",
        phase = "outro", frame = 8, duration = 40, progress = 0.2,
        overlays = {
          { x=0, y=0, w=0.1, h=0.1, color={0,0,0,1} },
          { x=0.9, y=0.9, w=0.1, h=0.1, color={0,0,0,1} },
        },
      },
    }
  end

  local function bootCopyrightScreen()
    return {
      id = "copyright_splash_preview", kind = "animation",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "ANIMATION", title = "COPYRIGHT", opaque = true,
      animation = {
        id = "boot.copyright", overlay = true, frame = 0,
        duration = 100, progress = 0,
        overlays = {{ x=0, y=0, w=1, h=1, color={1,1,1,1} }},
        sprites = {{ path = "assets/generated/title/copyright_splash.png",
          rect = { x=0, y=0, w=1, h=1 } }},
      },
    }
  end

  local function bootTitleScreen()
    return {
      id = "title_screen_preview", kind = "animation",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "ANIMATION", title = "GOLD TITLE", opaque = true,
      animation = {
        id = "boot.title", overlay = true, frame = 0,
        duration = 60, progress = 0,
        overlays = {
          { x=0, y=0, w=1, h=88/144, color={123/255,165/255,1,1} },
          { x=0, y=88/144, w=1, h=56/144, color={1,1,1,1} },
        },
        sprites = {{ path = "assets/generated/title/title_screen.png",
          rect = { x=0, y=0, w=1, h=1 } }},
      },
    }
  end

  local function bootGameFreakScreen()
    return {
      id = "gamefreak_presents_preview", kind = "animation",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "ANIMATION", title = "GAME FREAK PRESENTS", opaque = true,
      animation = {
        id = "boot.gamefreak", overlay = true, frame = 96,
        duration = 128, progress = 0.75,
        overlays = {{ x=0, y=0, w=1, h=1, color={0,0,0,1} }},
        sprites = {{ path = "assets/generated/splash/logo.png",
          normalized = true,
          rect = { x=64/160, y=48/144, w=24/160, h=40/144 },
          crop = { x=0, y=0, w=24, h=40 } }},
        labels = {{ text="GAME FREAK PRESENTS", x=0.5, y=0.78,
          align="center", maxWidth=0.8, color={1,1,1,1} }},
      },
    }
  end

  local function creditsScreen()
    return {
      id = "credits_roll_preview", kind = "animation",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "ANIMATION", title = "CREDITS", opaque = true,
      animation = {
        id = "credits.roll", overlay = true, frame = 72,
        duration = 13, progress = 0.5,
        overlays = {
          { x=0, y=0, w=1, h=1, color={1,1,1,1} },
          { x=0, y=0, w=1, h=32/144, color={0.94,0.87,0.84,1} },
          { x=0, y=14*8/144, w=1, h=32/144,
            color={0.94,0.87,0.84,1} },
          { x=0, y=4*8/144, w=1, h=8/144,
            color={0.48,0.38,0.32,1} },
          { x=0, y=13*8/144, w=1, h=8/144,
            color={0.48,0.38,0.32,1} },
        },
        sprites = {
          { path="assets/generated/credits/bellossom.png",
            rect={x=0, y=0, w=0.2, h=32/144},
            crop={x=0, y=0, w=32, h=32} },
          { path="assets/generated/credits/theend.png",
            rect={x=6*8/160, y=8*8/144, w=64/160, h=16/144} },
        },
        labels = {
          { text="PORT STAFF", x=0.5, y=6*8/144,
            align="center", maxWidth=0.8, color={0.22,0.22,0.22,1} },
          { text="THE END", x=0.5, y=8*8/144,
            align="center", maxWidth=0.4, color={0.22,0.22,0.22,1} },
        },
      },
    }
  end

  local function menuRows(items)
    local rows = {}
    for index, item in ipairs(items) do
      rows[index] = {
        id = item[1], label = item[2], right = item[3],
      }
    end
    return rows
  end

  local function mainMenuScreen()
    return {
      id = "main_menu_preview", kind = "menu",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "M", opaque = true, title = "MAIN MENU",
      selected = 1, scroll = 0,
      rows = menuRows({
        { "new_game", "NEW GAME" },
        { "option", "OPTION" },
        { "exit_game", "EXIT GAME" },
      }),
      description = "A CHOOSE",
    }
  end

  local function startMenuScreen()
    return {
      id = "start_menu_preview", kind = "menu",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "NAV", opaque = false, title = "START  GOLD",
      selected = 1, scroll = 0,
      rows = menuRows({
        { "pokedex", "POKéDEX", "DATABASE" },
        { "pokemon", "POKéMON", "PARTY" },
        { "pack", "PACK", "ITEMS" },
        { "pokegear", "POKéGEAR", "KEY DEVICE" },
        { "save", "SAVE", "PROGRESS" },
        { "option", "OPTION", "SETTINGS" },
        { "quit", "QUIT", "TITLE" },
      }),
      description = "A CHOOSE   B BACK   SELECT PIN",
    }
  end

  local function optionsMenuScreen()
    return {
      id = "options_menu_preview", kind = "menu",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "M", opaque = true, title = "OPTIONS",
      selected = 1, scroll = 0,
      rows = menuRows({
        { "text_speed", "TEXT SPEED", "MID" },
        { "battle_scene", "BATTLE SCENE", "ON" },
        { "battle_style", "BATTLE STYLE", "SHIFT" },
        { "sound", "SOUND", "MONO" },
        { "print", "PRINT", "NORMAL" },
        { "frame", "FRAME", "1" },
        { "cancel", "CANCEL" },
      }),
      description = "LEFT/RIGHT ADJUST   A CHOOSE   B BACK",
    }
  end

  local function partyScreen()
    return {
      id = "party_menu_preview", kind = "menu",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "L", opaque = true, title = "PARTY", selected = 1,
      scroll = 0,
      rows = {
        { id = "party.1", label = "TOTODILE", right = "Lv 12",
          bar = { fraction = 0.94 }, barLabel = "HP 34/36" },
        { id = "party.2", label = "EGG", right = "EGG" },
        { id = "party.back", label = "CANCEL", right = "BACK" },
      },
      details = {
        title = "TOTODILE",
        fields = {
          { label = "SPECIES", value = "TOTODILE" },
          { label = "STATUS", value = "OK" },
          { label = "TYPE", value = "WATER", style = "accent" },
        },
        bars = { { label = "HP", value = "34/36", fraction = 0.94 } },
      },
      description = "A CHOOSE   B BACK",
    }
  end

  local function summaryScreen()
    return {
      id = "summary_menu_preview", kind = "menu",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "L", opaque = true, title = "TOTODILE - STATUS",
      selected = 1, scroll = 0,
      rows = {
        { id = "status.hp", label = "HP", right = "34/36" },
        { id = "status.condition", label = "STATUS", right = "OK" },
        { id = "status.type", label = "TYPE", right = "WATER" },
        { id = "status.exp", label = "EXP POINTS", right = "1728" },
        { id = "status.next", label = "TO NEXT LEVEL", right = "469" },
      },
      details = {
        title = "TOTODILE",
        fields = {
          { label = "LEVEL", value = 12 },
          { label = "TYPE", value = "WATER", style = "accent" },
          { label = "HELD", value = "BERRY" },
        },
        bars = {
          { label = "HP", value = "34/36", fraction = 0.94 },
          { label = "EXP", value = "1728", fraction = 0.63 },
        },
      },
      description = "LEFT/RIGHT PAGE   B BACK",
    }
  end

  local function packScreen()
    return {
      id = "pack_menu_preview", kind = "menu",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "L", opaque = true, title = "PACK / ITEMS", selected = 1,
      scroll = 0,
      rows = {
        { id = "item.potion", label = "POTION", right = "x12" },
        { id = "item.poke_ball", label = "POKE BALL", right = "x5" },
        { id = "item.bicycle", label = "BICYCLE", right = "KEY ITEM" },
      },
      details = {
        title = "POTION",
        fields = {
          { label = "ITEM", value = "POTION" },
          { label = "QUANTITY", value = 12, style = "accent" },
          { label = "USE", value = "RESTORE 20 HP" },
        },
      },
      description = "LEFT/RIGHT POCKET   A CHOOSE   B BACK",
    }
  end

  local function pokegearScreen()
    return {
      id = "pokegear_menu_preview", kind = "menu",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "L", opaque = true, title = "POKEGEAR", selected = 1,
      scroll = 0,
      rows = {
        { id = "clock", label = "CLOCK", right = "OPEN" },
        { id = "map", label = "MAP", right = "OPEN" },
        { id = "phone", label = "PHONE", right = "3 CONTACTS" },
        { id = "radio", label = "RADIO", right = "ON AIR" },
      },
      details = {
        title = "CLOCK",
        fields = {
          { label = "DAY", value = "MONDAY" },
          { label = "TIME", value = "10:37 AM", style = "accent" },
          { label = "REGION", value = "JOHTO" },
        },
      },
      description = "LEFT/RIGHT CARD   A OPEN   B BACK",
    }
  end

  local function mapRadioScreen()
    return {
      id = "map_radio_preview", kind = "menu",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "L", opaque = false, title = "RADIO / LUCKY CHANNEL",
      selected = 1, scroll = 0,
      rows = {
        { id = "lucky_channel", label = "LUCKY CHANNEL", right = "ON AIR",
          disabled = true },
      },
      details = {
        title = "LUCKY CHANNEL",
        fields = {
          { label = "STATION", value = "LUCKY CHANNEL", style = "accent" },
          { label = "STATUS", value = "PLAYING" },
        },
      },
      description = "A/B CLOSE",
    }
  end

  local function pokedexScreen()
    return {
      id = "pokedex_menu_preview", kind = "menu",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "L", opaque = true, title = "POKEDEX", selected = 1,
      scroll = 0,
      rows = {
        { id = "dex.152", label = "CHIKORITA", right = "No.152" },
        { id = "dex.155", label = "CYNDAQUIL", right = "No.155  OWNED" },
        { id = "dex.158", label = "TOTODILE", right = "No.158  OWNED" },
      },
      details = {
        title = "TOTODILE",
        fields = {
          { label = "MODE", value = "NATIONAL" },
          { label = "SEEN", value = 3 },
          { label = "OWNED", value = 2, style = "accent" },
        },
      },
      description = "A DATA   SELECT OPTIONS   START SEARCH   B BACK",
    }
  end

  local function trainerCardScreen()
    return {
      id = "trainer_card_preview", kind = "menu",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "L", opaque = true, title = "TRAINER CARD / 1 OF 2",
      selected = nil, scroll = 0,
      rows = {
        { id = "name", label = "NAME", right = "GOLD" },
        { id = "id", label = "ID NO.", right = "01234" },
        { id = "pokedex", label = "POKEDEX", right = "2" },
        { id = "badges", label = "BADGES", right = "PAGE 2" },
      },
      details = {
        title = "GOLD",
        fields = {
          { label = "MONEY", value = 3000 },
          { label = "PLAY TIME", value = "12:34", style = "accent" },
        },
      },
      description = "A NEXT PAGE   LEFT/RIGHT PAGE   B BACK",
    }
  end

  local function saveScreen()
    return {
      id = "save_menu_preview", kind = "menu",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "M", opaque = true, title = "SAVE THE GAME?", selected = 1,
      scroll = 0,
      rows = {
        { id = "yes", label = "YES" },
        { id = "no", label = "NO" },
      },
      details = {
        title = "GOLD",
        fields = {
          { label = "BADGES", value = 2 },
          { label = "POKEDEX", value = 2 },
          { label = "TIME", value = "12:34", style = "accent" },
        },
      },
      description = "A CHOOSE   B BACK",
    }
  end

  local function battleScreen()
    return {
      id = "battle_preview", kind = "battle",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = "BATTLE", opaque = true, phase = "menu",
      enemy = {
        name = "PIDGEY", level = 4, gender = "female",
        caught = true, hp = 18, maxHp = 18,
        types = { { id = "NORMAL", label = "NORMAL" },
          { id = "FLYING", label = "FLYING" } },
      },
      player = {
        name = "TOTODILE", level = 12, gender = "male",
        hp = 34, maxHp = 36, exp = 0.63, expCurrent = 1728,
        expRequired = 2736,
        types = { { id = "WATER", label = "WATER" } },
      },
      actions = {
        { id = "fight", label = "FIGHT" },
        { id = "pokemon", label = "POKEMON" },
        { id = "pack", label = "PACK" },
        { id = "run", label = "RUN" },
      },
      selectedAction = 1,
      message = "WHAT WILL TOTODILE DO?",
    }
  end

  local function menuScreen(id, preset, title, rows, details, description,
      opaque)
    return {
      id = id, kind = "menu",
      schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
      preset = preset, opaque = opaque ~= false, title = title,
      selected = 1, scroll = 0, rows = rows, details = details,
      description = description,
    }
  end

  local function namingScreen()
    return menuScreen("naming_menu_preview", "XL", "TOTODILE'S NICKNAME", {
      { id = "keyboard.1", label = "Q  W  E  R  T  Y  U  I  O  P" },
      { id = "keyboard.2", label = "A  S  D  F  G  H  J  K  L" },
      { id = "keyboard.3", label = "Z  X  C  V  B  N  M" },
      { id = "done", label = "DONE", right = "5/10" },
    }, {
      title = "NICKNAME",
      fields = {
        { label = "ENTRY", value = "TOTODILE", style = "accent" },
        { label = "LENGTH", value = "8/10" },
        { label = "CASE", value = "UPPER" },
      },
    }, "A TYPE   B DELETE   START FINISH")
  end

  local function storageScreen()
    return menuScreen("box_menu_preview", "XL", "BOX 1 / MEADOW", {
      { id = "box.1", label = "TOTODILE", right = "Lv 12" },
      { id = "box.2", label = "PIKACHU", right = "Lv 8" },
      { id = "box.3", label = "EGG", right = "EGG" },
      { id = "box.empty", label = "EMPTY", disabled = true },
    }, {
      title = "TOTODILE",
      fields = {
        { label = "SPECIES", value = "TOTODILE" },
        { label = "HP", value = "34/36", style = "accent" },
        { label = "HELD", value = "BERRY" },
      },
    }, "A CHOOSE   B BACK   SELECT MOVE")
  end

  local function martScreen()
    return menuScreen("mart_menu_preview", "L", "MART / BUY", {
      { id = "potion", label = "POTION", right = "Y 300" },
      { id = "super_potion", label = "SUPER POTION", right = "Y 700" },
      { id = "poke_ball", label = "POKE BALL", right = "Y 200" },
    }, {
      title = "POTION",
      fields = {
        { label = "MONEY", value = "Y 3000", style = "accent" },
        { label = "PRICE", value = "Y 300" },
        { label = "EFFECT", value = "RESTORE 20 HP" },
      },
    }, "A BUY   B BACK")
  end

  local function mailScreen()
    return menuScreen("mail_menu_preview", "M", "MAILBOX", {
      { id = "mail.1", label = "GOLD'S MAIL", right = "BERRY" },
      { id = "mail.2", label = "JOEY'S MAIL", right = "FLOWER" },
      { id = "mail.empty", label = "EMPTY", disabled = true },
    }, {
      title = "GOLD'S MAIL",
      fields = {
        { label = "POKEMON", value = "TOTODILE" },
        { label = "AUTHOR", value = "GOLD", style = "accent" },
        { label = "TYPE", value = "BERRY" },
      },
    }, "A READ   B QUIT")
  end

  local function mailComposeScreen()
    return menuScreen("mail_compose_preview", "XL", "WRITE MAIL", {
      { id = "line.1", label = "MEET ME AT GOLDENROD" },
      { id = "line.2", label = "CITY!", right = "2/2" },
      { id = "case", label = "CASE", right = "UPPER" },
      { id = "done", label = "DONE" },
    }, {
      title = "MESSAGE",
      fields = {
        { label = "LENGTH", value = "25/32" },
        { label = "CURSOR", value = "7,1", style = "accent" },
      },
    }, "A TYPE   B DELETE   START FINISH")
  end

  local function clockScreen()
    return menuScreen("clock_menu_preview", "M", "SET CLOCK", {
      { id = "day", label = "DAY", right = "MONDAY" },
      { id = "time", label = "TIME", right = "10:37 AM" },
      { id = "confirm", label = "DONE" },
    }, {
      title = "CLOCK",
      fields = {
        { label = "DAY", value = "MONDAY" },
        { label = "TIME", value = "10:37 AM", style = "accent" },
      },
    }, "UP/DOWN ADJUST   A CONFIRM   B BACK")
  end

  local function hallScreen()
    return menuScreen("hall_of_fame_preview", "L", "HALL OF FAME", {
      { id = "team.1", label = "TOTODILE", right = "Lv 36" },
      { id = "team.2", label = "PIDGEOT", right = "Lv 38" },
      { id = "team.3", label = "AMPHAROS", right = "Lv 37" },
    }, {
      title = "CHAMPION TEAM",
      fields = {
        { label = "TRAINER", value = "GOLD", style = "accent" },
        { label = "POKEMON", value = "3/6" },
        { label = "REGION", value = "JOHTO" },
      },
    }, "A NEXT POKEMON   B CLOSE", false)
  end

  function V3.contract()
    return {
      id = "gen2_shared_dialogue",
      version = "0.1.0",
      games = { "gen2" },
      screens = { dialogueScreen(), choiceScreen() },
      gallery = {
        { id = "gen2.shared.dialogue.v3", family = "dialogue",
          title = "V3 Dialogue", support = "supported", variant = "normal",
          screen = "shared_dialogue_preview", preset = "XS" },
        { id = "gen2.shared.choice.v3", family = "dialogue",
          title = "V3 Choice", support = "supported", variant = "yes_no",
          screen = "shared_choice_preview", preset = "XS" },
      },
      actions = {
        open_dialogue = dialogueScreen,
        open_choice = choiceScreen,
      },
    }
  end

  function V3.foundationContract()
    return {
      id = "gen2_foundation_menus",
      version = "0.1.0",
      games = { "gen2" },
      screens = {
        mainMenuScreen(), startMenuScreen(), optionsMenuScreen(),
      },
      gallery = {
        { id = "gen2.foundation.main_menu.v3", family = "core",
          title = "V3 Main Menu", support = "supported", variant = "new_game",
          screen = "main_menu_preview", preset = "M" },
        { id = "gen2.foundation.start_menu.v3", family = "navigation",
          title = "V3 Start Menu", support = "supported", variant = "stock",
          screen = "start_menu_preview", preset = "NAV" },
        { id = "gen2.foundation.options_menu.v3", family = "core",
          title = "V3 Options", support = "supported", variant = "options",
          screen = "options_menu_preview", preset = "M" },
      },
      actions = {
        open_main_menu = mainMenuScreen,
        open_start_menu = startMenuScreen,
        open_options_menu = optionsMenuScreen,
      },
    }
  end

  function V3.partyContract()
    return {
      id = "gen2_party_menus",
      version = "0.1.0",
      games = { "gen2" },
      screens = { partyScreen(), summaryScreen() },
      gallery = {
        { id = "gen2.party.menu.v3", family = "party",
          title = "V3 Party", support = "supported", variant = "party",
          screen = "party_menu_preview", preset = "L" },
        { id = "gen2.summary.status.v3", family = "summary",
          title = "V3 Summary", support = "supported", variant = "status",
          screen = "summary_menu_preview", preset = "L" },
      },
      actions = {
        open_party = partyScreen,
        open_summary = summaryScreen,
      },
    }
  end

  function V3.inventoryDeviceContract()
    return {
      id = "gen2_inventory_device",
      version = "0.1.0",
      games = { "gen2" },
      screens = { packScreen(), pokegearScreen(), mapRadioScreen() },
      gallery = {
        { id = "gen2.pack.menu.v3", family = "inventory",
          title = "V3 Pack", support = "supported", variant = "items",
          screen = "pack_menu_preview", preset = "L" },
        { id = "gen2.pokegear.menu.v3", family = "device",
          title = "V3 Pokegear", support = "supported", variant = "clock",
          screen = "pokegear_menu_preview", preset = "L" },
        { id = "gen2.map_radio.v3", family = "device",
          title = "V3 Map Radio", support = "supported", variant = "station",
          screen = "map_radio_preview", preset = "L" },
      },
      actions = {
        open_pack = packScreen,
        open_pokegear = pokegearScreen,
        open_map_radio = mapRadioScreen,
      },
    }
  end

  function V3.progressContract()
    return {
      id = "gen2_progress_menus",
      version = "0.1.0",
      games = { "gen2" },
      screens = { pokedexScreen(), trainerCardScreen(), saveScreen() },
      gallery = {
        { id = "gen2.pokedex.menu.v3", family = "pokedex",
          title = "V3 Pokedex", support = "supported", variant = "list",
          screen = "pokedex_menu_preview", preset = "L" },
        { id = "gen2.trainer.card.v3", family = "trainer",
          title = "V3 Trainer Card", support = "supported", variant = "trainer",
          screen = "trainer_card_preview", preset = "L" },
        { id = "gen2.save.menu.v3", family = "core",
          title = "V3 Save", support = "supported", variant = "confirm",
          screen = "save_menu_preview", preset = "M" },
      },
      actions = {
        open_pokedex = pokedexScreen,
        open_trainer_card = trainerCardScreen,
        open_save = saveScreen,
      },
    }
  end

  function V3.battleContract()
    return {
      id = "gen2_battle_preview",
      version = "0.1.0",
      games = { "gen2" },
      screens = { battleScreen() },
      gallery = {
        { id = "gen2.battle.menu.v3", family = "battle",
          title = "V3 Battle", support = "supported", variant = "wild_menu",
          screen = "battle_preview", preset = "BATTLE" },
      },
      actions = { open_battle = battleScreen },
    }
  end

  function V3.animationContract()
    return {
      id = "gen2_battle_animations",
      version = "0.1.0",
      games = { "gen2" },
      screens = { animationScreen(), transitionAnimationScreen() },
      gallery = {
        { id = "gen2.battle.animation.intro", family = "battle",
          title = "V3 Battle Intro", support = "supported", variant = "intro",
          screen = "battle_animation_preview", preset = "ANIMATION" },
        { id = "gen2.battle.animation.move", family = "battle",
          title = "V3 Move Animation", support = "supported", variant = "move",
          screen = "battle_animation_preview", preset = "ANIMATION" },
        { id = "gen2.battle.animation.item", family = "battle",
          title = "V3 Item Animation", support = "supported", variant = "item",
          screen = "battle_animation_preview", preset = "ANIMATION" },
        { id = "gen2.battle.animation.experience", family = "battle",
          title = "V3 Experience Animation", support = "supported", variant = "experience",
          screen = "battle_animation_preview", preset = "ANIMATION" },
        { id = "gen2.battle.animation.level_up", family = "battle",
          title = "V3 Level Up Animation", support = "supported", variant = "level_up",
          screen = "battle_animation_preview", preset = "ANIMATION" },
        { id = "gen2.battle.transition.v3", family = "battle",
          title = "V3 Battle Transition", support = "supported", variant = "transition",
          screen = "battle_transition_preview", preset = "ANIMATION" },
      },
      actions = { open_animation = animationScreen },
    }
  end

  function V3.bootContract()
    return {
      id = "gen2_boot_animations",
      version = "0.1.0",
      games = { "gen2" },
      screens = { bootCopyrightScreen(), bootGameFreakScreen(),
        bootTitleScreen(), creditsScreen() },
      gallery = {
        { id = "gen2.boot.copyright.v3", family = "cinematics",
          title = "V3 Copyright Splash", support = "supported",
          variant = "splash", screen = "copyright_splash_preview",
          preset = "ANIMATION" },
        { id = "gen2.boot.title.v3", family = "cinematics",
          title = "V3 Gold Title", support = "supported", variant = "title",
          screen = "title_screen_preview", preset = "ANIMATION" },
        { id = "gen2.boot.gamefreak.v3", family = "cinematics",
          title = "V3 Game Freak Presents", support = "supported",
          variant = "gamefreak", screen = "gamefreak_presents_preview",
          preset = "ANIMATION" },
        { id = "gen2.credits.v3", family = "cinematics",
          title = "V3 Credits Roll", support = "supported", variant = "credits",
          screen = "credits_roll_preview", preset = "ANIMATION" },
      },
      actions = {
        open_copyright = bootCopyrightScreen,
        open_gamefreak = bootGameFreakScreen,
        open_title = bootTitleScreen,
        open_credits = creditsScreen,
      },
    }
  end

  function V3.cinematicContract()
    local introTiles = {}
    for index = 1, 32 * 32 do introTiles[index] = 0 end
    return {
      id = "gen2_cinematic_animations",
      version = "0.1.0",
      games = { "gen2" },
      screens = {
        {
          id = "egg_hatch_preview", kind = "animation",
          schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
          preset = "ANIMATION", title = "EGG HATCH", opaque = true,
          animation = {
            id = "cinematic.egg_hatch", overlay = true, frame = 80,
            duration = 482, progress = 80 / 482,
            overlays = {{ x=0, y=0, w=1, h=1, color={1,1,1,1} }},
            sprites = {
              { path="assets/generated/battle/front/egg.png",
                normalized=true,
                rect={x=(7*8+8)/160, y=(4*8+16)/144,
                  w=40/160, h=40/144},
                crop={x=0, y=0, w=40, h=40} },
              { path="assets/generated/menu/egg_hatch.png",
                normalized=true,
                rect={x=(11*8-12)/160, y=(9*8-20)/144,
                  w=8/160, h=8/144},
                crop={x=0, y=0, w=8, h=8} },
            },
          },
        },
        {
          id = "evolution_preview", kind = "animation",
          schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
          preset = "ANIMATION", title = "EVOLUTION", opaque = true,
          animation = {
            id = "cinematic.evolution", overlay = true, phase = "flash",
            frame = 80, duration = 144, progress = 80 / 144,
            blackout = true, showNew = true,
            overlays = {{ x=0, y=0, w=1, h=1, color={1,1,1,1} }},
            sprites = {{ path = "assets/generated/battle/front/cyndaquil.png",
              normalized = true,
              rect = { x=(56+8)/160, y=(16+56-48)/144,
                w=48/160, h=48/144 },
              palette={{255,255,255}, {58,58,58}, {16,25,25}, {0,0,0}} }},
          },
        },
        {
          id = "evolution_reveal_preview", kind = "animation",
          schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
          preset = "ANIMATION", title = "EVOLUTION REVEAL", opaque = true,
          animation = {
            id = "cinematic.evolution", overlay = true, phase = "reveal",
            frame = 26, duration = 64, progress = 26 / 64,
            overlays = {{ x=0, y=0, w=1, h=1, color={1,1,1,1} }},
            sprites = {{ path = "assets/generated/battle/front/quilava.png",
              normalized = true,
              rect = { x=(56+8)/160, y=(16+56-48)/144,
                w=48/160, h=48/144 } }},
            circles = {{ x=0.5, y=0.4, radius=4/160,
              color={0.9,0.55,0.15,1} }},
          },
        },
        {
          id = "gold_silver_intro_preview", kind = "animation",
          schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
          preset = "ANIMATION", title = "GOLD / SILVER INTRO", opaque = true,
          animation = {
            id = "cinematic.gold_silver_intro", overlay = true,
            phase = 2, frame = 48, duration = 2335, progress = 48 / 2335,
            overlays = {{ x=0, y=0, w=1, h=1, color={0,0,0,1} }},
            tilemap = {
              path = "assets/generated/intro/water_tiles.png",
              tileWidth = 8, tileHeight = 8, mapWidth = 32,
              mapHeight = 32, sheetColumns = 16,
              logicalWidth = 160, logicalHeight = 144,
              scrollX = 88, scrollY = 0, tiles = introTiles,
            },
            backgroundSprites = {}, sprites = {},
          },
        },
      },
      gallery = {
        { id = "gen2.cinematics.egg_hatch", family = "cinematics",
          title = "V3 Egg Hatch", support = "supported", variant = "hatch",
          screen = "egg_hatch_preview", preset = "ANIMATION" },
        { id = "gen2.cinematics.evolution", family = "cinematics",
          title = "V3 Evolution", support = "supported", variant = "flash",
          screen = "evolution_preview", preset = "ANIMATION" },
        { id = "gen2.cinematics.evolution.reveal", family = "cinematics",
          title = "V3 Evolution Reveal", support = "supported",
          variant = "reveal", screen = "evolution_reveal_preview",
          preset = "ANIMATION" },
        { id = "gen2.cinematics.gold_silver_intro", family = "cinematics",
          title = "V3 Gold / Silver Intro", support = "supported",
          variant = "intro", screen = "gold_silver_intro_preview",
          preset = "ANIMATION" },
      },
      actions = {
        open_egg_hatch = function() end,
        open_evolution = function() end,
        open_gold_silver_intro = function() end,
      },
    }
  end

  function V3.extendedContract()
    return {
      id = "gen2_extended_menus",
      version = "0.1.0",
      games = { "gen2" },
      screens = {
        namingScreen(), storageScreen(), martScreen(), mailScreen(),
        mailComposeScreen(), clockScreen(), hallScreen(),
      },
      gallery = {
        { id = "gen2.naming.v3", family = "naming", title = "V3 Naming",
          support = "supported", variant = "pokemon", screen = "naming_menu_preview",
          preset = "XL" },
        { id = "gen2.storage.box.v3", family = "storage", title = "V3 Box",
          support = "supported", variant = "box", screen = "box_menu_preview",
          preset = "XL" },
        { id = "gen2.mart.v3", family = "services", title = "V3 Mart",
          support = "supported", variant = "buy", screen = "mart_menu_preview",
          preset = "L" },
        { id = "gen2.mail.v3", family = "mail", title = "V3 Mail",
          support = "supported", variant = "mailbox", screen = "mail_menu_preview",
          preset = "M" },
        { id = "gen2.mail.compose.v3", family = "mail",
          title = "V3 Mail Compose", support = "supported", variant = "compose",
          screen = "mail_compose_preview", preset = "XL" },
        { id = "gen2.clock.v3", family = "services", title = "V3 Clock",
          support = "supported", variant = "clock", screen = "clock_menu_preview",
          preset = "M" },
        { id = "gen2.hall_of_fame.v3", family = "services",
          title = "V3 Hall of Fame", support = "supported", variant = "viewer",
          screen = "hall_of_fame_preview", preset = "L" },
      },
      actions = {
        open_naming = namingScreen,
        open_storage = storageScreen,
        open_mart = martScreen,
        open_mail = mailScreen,
        open_mail_compose = mailComposeScreen,
        open_clock = clockScreen,
        open_hall_of_fame = hallScreen,
      },
    }
  end

  V3.officialCatalogContract = officialCatalogContract

  function V3.register(core)
    local host = core and core.host
    if not (host and type(host.register) == "function"
        and type(host.supports) == "function"
        and host:supports("contract_catalog", "0.1.0")) then
      return nil, "v3_unavailable", "V3 contract catalog is unavailable"
    end
    local ok, code, message = host:register("gen2_clean_ui", V3.contract())
    if not ok then return nil, code, message end
    ok, code, message = host:register("gen2_clean_ui",
      V3.foundationContract())
    if not ok then return nil, code, message end
    ok, code, message = host:register("gen2_clean_ui", V3.partyContract())
    if not ok then return nil, code, message end
    ok, code, message = host:register("gen2_clean_ui",
      V3.inventoryDeviceContract())
    if not ok then return nil, code, message end
    ok, code, message = host:register("gen2_clean_ui", V3.progressContract())
    if not ok then return nil, code, message end
    ok, code, message = host:register("gen2_clean_ui", V3.battleContract())
    if not ok then return nil, code, message end
    ok, code, message = host:register("gen2_clean_ui",
      V3.animationContract())
    if not ok then return nil, code, message end
    ok, code, message = host:register("gen2_clean_ui",
      V3.bootContract())
    if not ok then return nil, code, message end
    ok, code, message = host:register("gen2_clean_ui",
      V3.cinematicContract())
    if not ok then return nil, code, message end
    ok, code, message = host:register("gen2_clean_ui", V3.extendedContract())
    if not ok then return nil, code, message end
    ok, code, message = host:register("gen2_clean_ui",
      V3.officialCatalogContract())
    if not ok then return nil, code, message end
    return true
  end

  return V3
end
