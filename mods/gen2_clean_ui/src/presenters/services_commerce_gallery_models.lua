return function(ctx)
  local Data = ctx.load("adapters.data")
  local GalleryModels = {}

  local ORDER = {
    "Gen2MartMenu", "Gen2ScriptMenu", "Gen2BankOfMom",
    "Gen2ContestMenu", "Gen2DayCareMenu", "Gen2HeldItemMenu",
    "Gen2ElevatorMenu", "Gen2MoveDeleter",
  }
  local VARIANTS = {
    Gen2MartMenu={ "standard", "herb", "bargain", "pharmacy", "sell" },
    Gen2ScriptMenu={ "vertical", "grid", "money", "coins", "prizes" },
    Gen2BankOfMom={ "deposit", "withdraw" },
    Gen2ContestMenu={ "compare" },
    Gen2DayCareMenu={ "message", "confirm", "party_picker" },
    Gen2HeldItemMenu={ "give_take", "message", "confirm" },
    Gen2ElevatorMenu={ "floors" },
    Gen2MoveDeleter={ "moves" },
  }
  local definitions = {}

  local function clone(value)
    return Data.copy(value, { maxDepth=16, maxEntries=4096 })
  end

  local function add(screenId, variant, model)
    assert(type(model) == "table" and model.screenId == screenId,
      screenId .. "." .. variant .. " source model")
    assert(Data.isFunctionFree(model),
      screenId .. "." .. variant .. " must be function-free")
    definitions[#definitions + 1] = {
      screenId=screenId, variant=variant, model=model,
    }
  end

  local function row(id, label, index, right)
    return { id=id, label=label, sourceIndex=index, right=right,
      selected=index == 1 }
  end

  local function message(lines)
    return { page=1, pageCount=1, lines=clone(lines), pages={ clone(lines) } }
  end

  local function confirm(lines, selected)
    selected = selected or 1
    return {
      page=1, pageCount=1, lines=clone(lines), pages={ clone(lines) },
      selectedChoice=selected,
      choices={
        { id="yes", sourceIndex=1, label="YES", selected=selected == 1 },
        { id="no", sourceIndex=2, label="NO", selected=selected == 2 },
      },
    }
  end

  local function item(id, name, price, soldOut)
    return { id=id, name=name, price=price, soldOut=soldOut == true,
      description="A dependable item sold by this shop." }
  end

  local function nestedPack()
    local rows = {
      row("POTION", "POTION", 1, "x5"),
      row("ANTIDOTE", "ANTIDOTE", 2, "x2"),
      row("cancel", "CANCEL", 3, ""),
    }
    return {
      schema="clean_ui.presenter_model.v1", screenId="Gen2PackMenu",
      family="inventory", preset="L", title="PACK", mode="pockets",
      chooser=false, battleOwned=false,
      pockets={{ id="ITEM", label="ITEMS", sourceIndex=1,
        itemCount=2, selected=true }},
      pocket={ id="ITEM", label="ITEMS", sourceIndex=1,
        itemCount=2, selected=true },
      navigation={ selectedIndex=1, selectedId="POTION", scroll=0,
        itemCount=2, rowCount=3 },
      rows=rows,
      selectedItem={ id="POTION", name="POTION", count=5,
        description="Restores 20 HP." },
      message={}, controls={}, actionDescriptors={},
    }
  end

  local function martModel(variant)
    local martType = variant == "herb" and "BITTER"
      or variant == "bargain" and "BARGAIN"
      or variant == "pharmacy" and "PHARMACY" or "STANDARD"
    local title = martType == "BITTER" and "HERB SHOP"
      or martType == "BARGAIN" and "BARGAIN SHOP"
      or martType == "PHARMACY" and "PHARMACY" or "POKE MART"
    local entries = {
      item("POTION", "POTION", 300),
      item("ANTIDOTE", "ANTIDOTE", 100, variant == "bargain"),
    }
    local model = {
      schema="clean_ui.presenter_model.v1", screenId="Gen2MartMenu",
      family="commerce", preset="L", title=title,
      martType=martType, martId=1, phase="buy", mode="buy",
      money=12500, entries=entries, selectedItem=clone(entries[1]),
      rows={ row("POTION", "POTION", 1, "Y300"),
        row("ANTIDOTE", "ANTIDOTE", 2, "Y100"),
        row("cancel", "CANCEL", 3, "") },
      navigation={ selectedIndex=1, scroll=0, itemCount=3 },
      actionDescriptors={},
    }
    if variant == "standard" then
      model.phase, model.mode = "top", "top"
      model.rows={ row("buy", "BUY", 1), row("sell", "SELL", 2),
        row("quit", "QUIT", 3) }
      model.navigation={ selectedIndex=1, scroll=0, itemCount=3 }
      model.topLines={ "Welcome! How may I", "help you?" }
      model.selectedItem=nil
    elseif variant == "pharmacy" then
      model.phase, model.mode = "buyQuantity", "quantity"
      model.quantity={ item=clone(entries[1]), value=3, maximum=99, total=900 }
    elseif variant == "sell" then
      model.phase, model.mode = "sell", "sell"
      model.rows={}
      model.selectedItem=nil
      model.navigation={ selectedIndex=1, scroll=0, itemCount=0 }
      model.nestedPack=nestedPack()
    end
    return model
  end

  for _, variant in ipairs(VARIANTS.Gen2MartMenu) do
    add("Gen2MartMenu", variant, martModel(variant))
  end

  local function scriptModel(variant)
    local grid = variant == "grid"
    local labels = grid and { "A", "B", "C", "D" }
      or variant == "prizes" and { "ABRA 100", "EKANS 700", "DRATINI 2100" }
      or { "FRESH WATER", "SODA POP", "LEMONADE", "CANCEL" }
    local rows = {}
    for index, label in ipairs(labels) do rows[index] = row("choice_" .. index,
      label, index) end
    local balance = variant == "money" and "money"
      or variant == "coins" and "coins"
      or variant == "prizes" and "coins" or nil
    return {
      schema="clean_ui.presenter_model.v1", screenId="Gen2ScriptMenu",
      family="services", preset="M", title="SCRIPT MENU",
      style=grid and "2d" or "vertical", variant=variant,
      rows=rows,
      navigation={ selectedIndex=1, row=1, col=1,
        rows=grid and 2 or #rows, cols=grid and 2 or 1,
        wrap=false, pageJump=false, keyRepeat=false,
        repeatDelay=16, repeatRate=4 },
      geometry={ header={ left=0, top=0, right=12, bottom=10,
        dataFlags=128, cursor=1 }, textX=2, textY=2,
        spacing=grid and 5 or 0, showCursor=true },
      balance=balance and { kind=balance, money=45000, coins=2300 } or nil,
      actionDescriptors={},
    }
  end
  for _, variant in ipairs(VARIANTS.Gen2ScriptMenu) do
    add("Gen2ScriptMenu", variant, scriptModel(variant))
  end

  local function bankModel(kind)
    local amount = kind == "withdraw" and 2500 or 1200
    local digits = ("%06d"):format(amount)
    local places = { 100000, 10000, 1000, 100, 10, 1 }
    local rows = {}
    for index, place in ipairs(places) do
      rows[index]={ id="digit_" .. (index - 1), sourceIndex=index,
        label=("%06d PLACE"):format(place), right=digits:sub(index, index),
        selected=index == 6 }
    end
    return {
      schema="clean_ui.presenter_model.v1", screenId="Gen2BankOfMom",
      family="services", preset="XS",
      title=kind == "withdraw" and "WITHDRAW" or "DEPOSIT",
      kind=kind, saved=8200, held=45000, amount=amount,
      position=5, blink=0, rows=rows,
      navigation={ selectedIndex=6, digitCount=6 }, actionDescriptors={},
    }
  end
  add("Gen2BankOfMom", "deposit", bankModel("deposit"))
  add("Gen2BankOfMom", "withdraw", bankModel("withdraw"))

  local stock={ species="SCYTHER", name="SCYTHER", level=14, hp=36, maxHp=40 }
  local caught={ species="PINSIR", name="PINSIR", level=13, hp=42, maxHp=44 }
  add("Gen2ContestMenu", "compare", {
    schema="clean_ui.presenter_model.v1", screenId="Gen2ContestMenu",
    family="services", preset="L", title="BUG CONTEST", mode="compare",
    stock=stock, caught=caught,
    rows={ row("yes", "SWITCH", 1), row("no", "KEEP STOCK", 2) },
    navigation={ selectedIndex=1 },
    prompt="Switch the newly caught POKEMON?", battleRouteNative=true,
    actionDescriptors={},
  })

  local dayCareData={ hasEgg=true, compatible=false, stepsToEgg=0,
    man={ introSeen=true, mon={ species="DITTO", name="DITTO", level=20 } },
    lady={ introSeen=true, mon={ species="PIKACHU", name="PIKACHU", level=18 } } }
  add("Gen2DayCareMenu", "message", {
    schema="clean_ui.presenter_model.v1", screenId="Gen2DayCareMenu",
    family="services", preset="L", title="DAY-CARE MAN", side="man",
    mode="message", scriptVar=0, delay=0,
    message=message({ "Come back for it later." }),
    dayCare=clone(dayCareData), actionDescriptors={},
  })
  add("Gen2DayCareMenu", "confirm", {
    schema="clean_ui.presenter_model.v1", screenId="Gen2DayCareMenu",
    family="services", preset="L", title="DAY-CARE LADY", side="lady",
    mode="confirm", scriptVar=0, delay=0,
    confirm=confirm({ "Should I raise a POKEMON?" }),
    dayCare=clone(dayCareData), actionDescriptors={},
  })
  add("Gen2DayCareMenu", "party_picker", {
    schema="clean_ui.presenter_model.v1", screenId="Gen2DayCareMenu",
    family="services", preset="L", title="DAY-CARE PARTY PICKER",
    side="man", mode="party_picker_native", scriptVar=0, delay=0,
    nativeOnly=true,
    nativeReason="Nested Gen2PartyMenu remains native until the complete stack is proven.",
    dayCare=clone(dayCareData), actionDescriptors={},
  })

  local heldPokemon={ species="TOTODILE", name="TOTODILE", level=15,
    hp=42, maxHp=44, heldName="BERRY" }
  local function heldModel(variant)
    local model={
      schema="clean_ui.presenter_model.v1", screenId="Gen2HeldItemMenu",
      family="services", preset="L", title="HELD ITEM", slot=1,
      mode=variant, pokemon=clone(heldPokemon),
      rows={ row("give", "GIVE", 1), row("take", "TAKE", 2) },
      navigation={ selectedIndex=1 }, actionDescriptors={},
    }
    if variant == "message" then
      model.message=message({ "Took BERRY from TOTODILE." })
    elseif variant == "confirm" then
      model.confirm=confirm({ "Switch held items?" })
    end
    return model
  end
  for _, variant in ipairs(VARIANTS.Gen2HeldItemMenu) do
    add("Gen2HeldItemMenu", variant, heldModel(variant))
  end

  add("Gen2ElevatorMenu", "floors", {
    schema="clean_ui.presenter_model.v1", screenId="Gen2ElevatorMenu",
    family="services", preset="S", title="ELEVATOR",
    rows={
      { id="floor_1", sourceIndex=1, label="1F", right="CURRENT",
        selected=true, destination={ map="GOLDENROD_DEPT_STORE_1F",
          warp=3, floorId=4 } },
      { id="floor_2", sourceIndex=2, label="2F", right="",
        destination={ map="GOLDENROD_DEPT_STORE_2F", warp=3, floorId=5 } },
      { id="floor_3", sourceIndex=3, label="3F", right="",
        destination={ map="GOLDENROD_DEPT_STORE_3F", warp=3, floorId=6 } },
    },
    navigation={ selectedIndex=1, scroll=0, origin=1 }, currentFloor="1F",
    actionDescriptors={},
  })

  local moveRows={
    { id="SCRATCH", sourceIndex=1, label="SCRATCH", right="PP 35/35",
      pp=35, maxPp=35, type="NORMAL", power=40, accuracy=100,
      description="Scratches with sharp claws.", selected=true },
    { id="LEER", sourceIndex=2, label="LEER", right="PP 30/30",
      pp=30, maxPp=30, type="NORMAL", power=0, accuracy=100,
      description="Lowers the foe's DEFENSE." },
  }
  add("Gen2MoveDeleter", "moves", {
    schema="clean_ui.presenter_model.v1", screenId="Gen2MoveDeleter",
    family="services", preset="L", title="CHOOSE A MOVE",
    rows=moveRows, navigation={ selectedIndex=1 },
    pokemon={ species="TOTODILE", name="TOTODILE", level=15 },
    selectedMove=clone(moveRows[1]), actionDescriptors={},
  })

  function GalleryModels.galleryFixtures()
    local output = {}
    for index, definition in ipairs(definitions) do
      output[index] = {
        screenId=definition.screenId, variant=definition.variant,
        model=clone(definition.model),
      }
    end
    return output
  end

  function GalleryModels.variantsFor(screenId)
    return clone(VARIANTS[screenId] or {})
  end

  function GalleryModels.ids()
    return clone(ORDER)
  end

  function GalleryModels.count()
    return #definitions
  end

  return GalleryModels
end
