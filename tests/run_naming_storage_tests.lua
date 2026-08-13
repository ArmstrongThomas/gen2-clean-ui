local function run()
  local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"),
    "GEN2_CLEAN_UI_ROOT is required")
  root = root:gsub("\\", "/")

  local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
  local ctx = Helper.new(root)
  local Data = ctx.load("adapters.data")
  local Naming = ctx.load("adapters.naming_screen")
  local CenterPc = ctx.load("adapters.storage_center_pc")
  local Pc = ctx.load("adapters.storage_pc")
  local Box = ctx.load("adapters.storage_box")
  local ItemPc = ctx.load("adapters.storage_item_pc")
  local Models = ctx.load("presenters.naming_storage_models")
  local Presenters = ctx.load("presenters.naming_storage_presenters")
  local Catalog = ctx.load("contracts.catalog")
  local Shared = ctx.load("contracts.shared")
  local Provider = ctx.load("provider.init")

  local checks = 0
  local function check(condition, message)
    checks = checks + 1
    assert(condition, ("check %d failed: %s"):format(checks, message))
  end
  local function functionFree(bundle, label)
    check(type(bundle) == "table" and type(bundle.model) == "table",
      label .. " returns a model bundle")
    check(Data.isFunctionFree(bundle.model), label .. " model is function-free")
    return bundle.model
  end
  local function descriptor(model, id)
    for _, item in ipairs(model.actionDescriptors or {}) do
      if item.id == id then return item end
    end
  end

  local calls = 0
  local function forbidden() calls = calls + 1 end
  local palette = {
    { 255, 255, 255 }, { 160, 200, 248 },
    { 48, 96, 192 }, { 8, 16, 32 },
  }

  -- Naming preserves the cart's exact boards and source-owned button rules.
  local namingState = {
    screenId="Gen2NamingScreen", kind={ prompt="YOUR NAME?",
      ignored=forbidden }, isBox=false, maxLength=7,
    prompt="YOUR NAME?", lower=false, text="GO", col=0, row=0,
    tiles={}, iconPath="assets/generated/sprites/chris.png",
    iconColors=palette, iconMetadata={ frame=1, ignored=forbidden },
    iconImage={ ignored=forbidden },
  }
  local namingBundle = assert(Naming.extract(namingState))
  local naming = functionFree(namingBundle, "Naming")
  check(calls == 0, "Naming extraction invokes no caller function")
  check(naming.context == "player" and not naming.isBox,
    "Naming context derives from the exact source prompt")
  check(naming.cursor.zeroBased and naming.cursor.col == 0
    and naming.cursor.row == 0 and naming.cursor.value == "A",
    "Naming cursor remains zero-based")
  check(naming.keyboard.columns == 9 and naming.keyboard.letterRows == 4,
    "Name keyboard is exactly nine by four plus controls")
  check(naming.keyboard.rows[3][9] == " "
    and naming.keyboard.rows[4][7] == " ",
    "Stock upper-board blank cells remain real spaces")
  check(naming.keyboard.stockLayouts.lower[4][8] == "<PK>"
    and naming.keyboard.stockLayouts.lower[4][9] == "<MN>",
    "Stock lower-board token cells are exact")
  check(naming.keyboard.bottom[1].colStart == 0
    and naming.keyboard.bottom[2].colStart == 3
    and naming.keyboard.bottom[3].colStart == 6,
    "Bottom targets retain their three-column hit spans")
  check(naming.keyboard.bottom[3].cursorTileX == 14
    and naming.keyboard.bottom[3].labelTileX == 15,
    "END target retains exact tile coordinates")
  check(naming.sprite.path == namingState.iconPath
    and naming.sprite.palette[2][2] == 200
    and naming.sprite.metadata.frame == 1
    and naming.sprite.nativeImageAvailable,
    "Caller-provided sprite and palette metadata are preserved as data")
  check(naming.sprite.metadata.ignored == nil
    and naming.kindMetadata.ignored == nil,
    "Naming model strips caller functions")
  check(descriptor(naming, "entry.delete").input == "b"
    and descriptor(naming, "entry.delete").kind == "delete",
    "B is modeled only as delete")
  check(descriptor(naming, "entry.focus_end").input == "start"
    and descriptor(naming, "entry.focus_end").kind == "focus_end",
    "Start is modeled as focus END, not submit")
  check(descriptor(naming, "menu.back") == nil,
    "Naming exposes no false cancel/back action")

  namingState.lower, namingState.row, namingState.col = true, 3, 0
  local lower = functionFree(assert(Naming.extract(namingState)),
    "Lower naming")
  check(lower.keyboard.rows[4][1] == "\xc3\x97"
    and lower.cursor.value == "\xc3\x97"
    and lower.keyboard.bottom[1].label == "UPPER",
    "Lower name board and case target are exact")

  local boxNamingState = {
    screenId="Gen2NamingScreen", kind={ isBox=true }, isBox=true,
    maxLength=8, prompt="BOX NAME?", lower=true, text="BOX",
    col=8, row=4, tiles={},
  }
  local boxNaming = functionFree(assert(Naming.extract(boxNamingState)),
    "Box naming")
  check(boxNaming.context == "box"
    and boxNaming.keyboard.topTile == 6
    and boxNaming.keyboard.letterRows == 5,
    "Box naming uses its shorter header and fifth letter row")
  check(boxNaming.keyboard.rows[4][1] == "\xc3\xa9"
    and boxNaming.keyboard.rows[4][2] == "'d"
    and boxNaming.keyboard.rows[5][9] == "9",
    "Box lower-case contractions and number row are exact")
  boxNamingState.row, boxNamingState.col = 5, 4
  local deleteTarget = assert(Naming.extract(boxNamingState)).model
  check(deleteTarget.cursor.bottomRow
    and deleteTarget.cursor.target == "delete"
    and deleteTarget.cursor.targetIndex == 2,
    "Bottom-row middle span resolves to DEL")
  boxNamingState.col = 6
  check(assert(Naming.extract(boxNamingState)).model.cursor.target == "end",
    "Bottom-row final span resolves to END")
  check(select(2, Naming.extract({
    isBox=false, maxLength=7, lower=false, text="", col=9, row=0,
  })) == "cursor_invalid", "Out-of-range naming cursor fails open")
  namingState.lower, namingState.row, namingState.col = false, 0, 0
  local namingPresentation = assert(Presenters.convert(
    "Gen2NamingScreen", assert(Naming.extract(namingState)).model))
  check(namingPresentation.kind == "menu"
    and namingPresentation.preset == "XL"
    and namingPresentation.naming.cursor.zeroBased,
    "Naming presenter is renderable and retains exact semantic geometry")
  check(Data.isFunctionFree(namingPresentation),
    "Naming presentation remains function-free")

  local save = {
    player={ name="GOLD" }, currentBox=2,
    party={{ species="TOTODILE", name="TOTODILE", nickname="TOTO",
      level=12, hp=31, maxHp=36, gender="male", moves={"SCRATCH"} }},
    boxes={
      [1]={{ species="PIDGEY", name="PIDGEY", level=5, hp=18, maxHp=18 }},
      [2]={
        { species="MAREEP", name="MAREEP", level=8, hp=25, maxHp=25 },
        { species="WOOPER", name="WOOPER", level=7, hp=23, maxHp=23 },
      },
    },
    boxNames={ [2]="WOODS" },
    pcItems={ POTION=4 },
  }
  local pokemon = {
    TOTODILE={ spriteFront="assets/generated/battle/front/totodile.png" },
    PIDGEY={ spriteFront="assets/generated/battle/front/pidgey.png" },
    MAREEP={ spriteFront="assets/generated/battle/front/mareep.png" },
    WOOPER={ spriteFront="assets/generated/battle/front/wooper.png" },
  }
  local palettes = { pokemon={} }
  for species in pairs(pokemon) do
    palettes.pokemon[species] = {
      normal={ { 160, 200, 248 }, { 48, 96, 192 } },
      shiny={ { 248, 216, 120 }, { 176, 104, 40 } },
    }
  end

  -- Pokemon Center whose-PC root, messages, and confirmations.
  local centerState = {
    screenId="Gen2CenterPcMenu", save=save, items={}, data={},
    entries={
      { id="bills", label="BILL'S PC" },
      { id="players", label="GOLD'S PC" },
      { id="turnoff", label="TURN OFF" },
    },
    index=2,
  }
  local center = functionFree(assert(CenterPc.extract(centerState)),
    "Center PC root")
  check(center.mode == "root" and center.navigation.selectedIndex == 2
    and center.entries[2].id == "players",
    "Center PC root selection and IDs are exact")
  centerState.message={
    pages={{ "{PLAYER} turned on", "the PC." },
      { "Storage System", "opened." }}, page=2, onDone=forbidden,
  }
  local centerMessage = functionFree(assert(CenterPc.extract(centerState)),
    "Center PC message")
  check(centerMessage.mode == "message"
    and centerMessage.message.page == 2
    and centerMessage.message.pageCount == 2
    and centerMessage.message.lines[1] == "Storage System",
    "Center PC preserves paged message state")
  centerState.message=nil
  centerState.confirm={
    prompt={ "Want to get your", "<PK><MN>DEX rated?" },
    choice=2, onYes=forbidden, onNo=forbidden,
  }
  local centerConfirm = functionFree(assert(CenterPc.extract(centerState)),
    "Center PC confirm")
  check(centerConfirm.mode == "confirm"
    and centerConfirm.confirm.selectedChoice == 2,
    "Center PC preserves NO-selected confirmation")
  check(calls == 0, "Center PC extraction invokes no callbacks")
  local centerPresentation = assert(Presenters.convert(
    "Gen2CenterPcMenu", centerConfirm))
  check(centerPresentation.modal.selected == 2
    and centerPresentation.modal.options[2].label == "NO",
    "Center PC presenter preserves confirmation")

  -- Bill's PC root, box picker, and refusal/message state.
  local pcState = {
    screenId="Gen2PcMenu", save=save, house=false,
    entries={
      { id="withdraw", label="WITHDRAW <PK><MN>" },
      { id="changebox", label="CHANGE BOX" },
      { id="seeya", label="SEE YA!", onSelect=forbidden },
    },
    index=2, messageCloses=false, changedDecorations=false,
  }
  local pcRoot = functionFree(assert(Pc.extract(pcState)), "PC root")
  check(pcRoot.mode == "root" and pcRoot.entries[2].id == "changebox",
    "PC root rows remain source ordered")
  pcState.picking, pcState.pickIndex = true, 2
  local picker = functionFree(assert(Pc.extract(pcState)), "PC box picker")
  check(picker.mode == "box_picker" and #picker.picker.boxes == 14,
    "PC picker exposes all fourteen boxes")
  check(picker.picker.boxes[2].label == "WOODS"
    and picker.picker.boxes[2].right == "2/20"
    and picker.picker.boxes[2].selected,
    "PC picker preserves custom name, count, capacity, and cursor")
  check(save.boxes[14] == nil,
    "PC picker reads absent boxes without mutating the save")
  pcState.picking=false
  pcState.message="Please remove the\nMAIL."
  pcState.messagePages={
    "There is a POKEMON\nholding MAIL.",
    "Please remove the\nMAIL.",
  }
  pcState.messagePage=2
  local pcMessage = functionFree(assert(Pc.extract(pcState)), "PC message")
  check(pcMessage.mode == "message"
    and pcMessage.message.page == 2
    and pcMessage.message.pageCount == 2
    and not pcMessage.message.closes,
    "PC refusal preserves page and return-to-menu behavior")
  check(calls == 0, "PC extraction invokes no injected row action")
  local pickerPresentation = assert(Presenters.convert(
    "Gen2PcMenu", picker))
  check(pickerPresentation.kind == "menu"
    and pickerPresentation.rows[2].right == "2/20",
    "PC picker presenter retains storage counts")

  -- Box storage browse/deposit/move/submenu/insert/message modes.
  local boxState = {
    screenId="Gen2BoxMenu", save=save, mode="withdraw", boxIndex=2,
    index=1, scroll=0, pokemon=pokemon, palettes=palettes,
    menuGfx={}, icons={},
  }
  local boxBrowse = functionFree(assert(Box.extract(boxState)),
    "Box browse")
  check(boxBrowse.view == "browse" and boxBrowse.title == "WOODS"
    and #boxBrowse.rows == 3 and boxBrowse.rows[3].id == "cancel",
    "Box browse includes source list and meaningful CANCEL")
  check(boxBrowse.selectedMon.spritePath
      == "assets/generated/battle/front/mareep.png"
    and boxBrowse.selectedMon.artwork.palette[2][2] == 200
    and boxBrowse.destination.count == 2
    and boxBrowse.destination.capacity == 20,
    "Box browse includes detached selected-mon and capacity data")
  check(descriptor(boxBrowse, "list.release").input == "select"
    and descriptor(boxBrowse, "list.nickname").input == "start",
    "Withdraw-only release and nickname inputs remain source owned")

  boxState.mode, boxState.index = "deposit", 1
  local deposit = functionFree(assert(Box.extract(boxState)), "Box deposit")
  check(deposit.title == "PARTY <PK><MN>"
    and deposit.rows[1].label == "TOTO"
    and descriptor(deposit, "list.previous_box") == nil,
    "Deposit reads party and cannot switch boxes")

  boxState.mode, boxState.boxIndex, boxState.index = "move", 0, 1
  local moveParty = functionFree(assert(Box.extract(boxState)),
    "Box move party")
  check(moveParty.destination.isParty
    and moveParty.destination.capacity == 6
    and moveParty.rows[1].label == "TOTO",
    "Move box zero exactly represents the party")

  boxState.mode, boxState.boxIndex = "move", 2
  boxState.phase, boxState.submenuIndex = "submenu", 2
  local moveSubmenu = functionFree(assert(Box.extract(boxState)),
    "Box move submenu")
  check(moveSubmenu.view == "submenu"
    and #moveSubmenu.submenu.rows == 3
    and moveSubmenu.submenu.rows[2].label == "STATS",
    "Move submenu is exactly MOVE/STATS/CANCEL")

  boxState.mode, boxState.phase, boxState.submenuIndex =
    "withdraw", "submenu", 1
  local withdrawSubmenu = assert(Box.extract(boxState)).model
  check(#withdrawSubmenu.submenu.rows == 4
    and withdrawSubmenu.submenu.rows[1].label == "WITHDRAW"
    and withdrawSubmenu.submenu.rows[3].label == "RELEASE",
    "Withdraw submenu includes WITHDRAW/STATS/RELEASE/CANCEL")

  boxState.mode, boxState.phase, boxState.boxIndex, boxState.index =
    "move", "insert", 1, 1
  boxState.moveFrom={ box=2, slot=2, ignored=forbidden }
  boxState.backup={ box=2, index=2, scroll=0, ignored=forbidden }
  local insert = functionFree(assert(Box.extract(boxState)), "Box insert")
  check(insert.view == "insert" and insert.insert.source.boxIndex == 2
    and insert.insert.source.slot == 2
    and insert.insert.positionCount == 1,
    "Insert mode preserves source, destination, and insertion positions")
  check(insert.rows[#insert.rows].id ~= "cancel"
    and insert.selectedMon.species == "WOOPER",
    "Insert mode has no false CANCEL row and keeps the moving mon visible")
  boxState.message="There's no room!"
  local boxMessage = functionFree(assert(Box.extract(boxState)),
    "Box message")
  check(boxMessage.view == "message"
    and boxMessage.underlyingPhase == "insert"
    and boxMessage.message.lines[1] == "There's no room!",
    "Box message preserves its underlying insert phase")
  check(calls == 0, "Box extraction invokes no source action")
  local insertPresentation = assert(Presenters.convert(
    "Gen2BoxMenu", insert))
  check(insertPresentation.kind == "menu"
    and insertPresentation.storage.insert.source.boxIndex == 2,
    "Box presenter retains insert semantics")

  -- Item PC root/list/deposit/message/quantity/confirm overlays.
  local itemRows = {
    { id="POTION", name="POTION", count=4, index=1 },
    { id="BERRY", name="BERRY", count=2, index=2 },
  }
  local itemState = {
    screenId="Gen2ItemPcMenu", save=save,
    items={
      POTION={ description="Restores HP.<NEXT>Useful medicine." },
      BERRY={ description="A self-use item." },
    },
    entries={
      { id="withdraw", label="WITHDRAW ITEM" },
      { id="deposit", label="DEPOSIT ITEM" },
      { id="toss", label="TOSS ITEM" },
      { id="logoff", label="LOG OFF" },
    },
    index=1, phase="menu", rows=itemRows, listIndex=1,
    scroll=0, house=false,
  }
  local itemRoot = functionFree(assert(ItemPc.extract(itemState)),
    "Item PC root")
  check(itemRoot.view == "menu" and itemRoot.entries[1].id == "withdraw",
    "Item PC root remains source ordered")

  itemState.phase="withdraw"
  local withdraw = functionFree(assert(ItemPc.extract(itemState)),
    "Item PC withdraw")
  check(withdraw.view == "withdraw" and #withdraw.rows == 3
    and withdraw.rows[3].id == "cancel"
    and withdraw.description[2] == "Useful medicine.",
    "Withdraw preserves quantities, CANCEL, and split description")

  itemState.phase="toss"
  local toss = functionFree(assert(ItemPc.extract(itemState)), "Item PC toss")
  check(toss.view == "toss" and toss.rows[1].right == "x4",
    "Toss list preserves item quantities")

  itemState.phase="deposit"
  itemState.pack={
    pocketIndex=2, index=1, scroll=0,
    rows={{ id="POKE_BALL", name="POKE BALL", count=7,
      showCount=true, ignored=forbidden }},
  }
  local itemDeposit = functionFree(assert(ItemPc.extract(itemState)),
    "Item PC deposit")
  check(itemDeposit.view == "deposit"
    and itemDeposit.deposit.packPresent
    and itemDeposit.deposit.pocket.pocket.id == "BALL"
    and itemDeposit.deposit.rows[1].right == "x7",
    "Deposit preserves nested Pack pocket, list, and selection")

  itemState.qtyState={
    qty=3, max=7, prompt={ "How many do you", "want to deposit?" },
    onAccept=forbidden,
  }
  local quantity = functionFree(assert(ItemPc.extract(itemState)),
    "Item PC quantity")
  check(quantity.view == "quantity" and quantity.quantity.value == 3
    and quantity.quantity.maximum == 7,
    "Quantity overlay preserves value and bounds")
  check(descriptor(quantity, "quantity.increment_ten").input == "right"
    and descriptor(quantity, "quantity.decrement_ten").input == "left",
    "Quantity x10 adjustment remains source owned")

  itemState.qtyState=nil
  itemState.confirm={
    prompt={ "Throw away 3", "POTION(S)?" }, choice=2,
    onYes=forbidden, onNo=forbidden,
  }
  local itemConfirm = functionFree(assert(ItemPc.extract(itemState)),
    "Item PC confirm")
  check(itemConfirm.view == "confirm"
    and itemConfirm.confirm.selectedChoice == 2,
    "Item PC confirmation preserves default NO")

  itemState.confirm=nil
  itemState.message={
    pages={{ "{PLAYER} turned on", "the PC." },
      { "There's no room", "to store items." }},
    page=2, onDone=forbidden,
  }
  local itemMessage = functionFree(assert(ItemPc.extract(itemState)),
    "Item PC message")
  check(itemMessage.view == "message"
    and itemMessage.message.page == 2
    and itemMessage.message.lines[1] == "There's no room",
    "Item PC preserves current message page")
  check(calls == 0, "Item PC extraction invokes no source callback")
  local quantityPresentation = assert(Presenters.convert(
    "Gen2ItemPcMenu", quantity))
  check(quantityPresentation.kind == "menu"
    and quantityPresentation.details[#quantityPresentation.details].value
      == "3/7",
    "Item PC presenter exposes quantity through compatible flat details")

  -- Focused modules register against production contracts without touching
  -- product.lua; every presenter returns a complete, currently renderable menu.
  local catalog, shared = Catalog.build(), Shared.build()
  local classes = {}
  local function classFor(record)
    classes[record.id] = classes[record.id]
      or { isOpaque=record.opaque }
    classes[record.id].__index = classes[record.id]
    return classes[record.id]
  end
  local provider = Provider.new({
    catalog=catalog, shared=shared,
    classResolver=function(record) return classFor(record) end,
  })
  check(Models.register(provider) == true,
    "Focused model adapters register against production contracts")
  check(Presenters.register(provider) == true,
    "Focused presenters register against production contracts")

  local validStates = {
    namingState,
    centerState,
    pcState,
    {
      screenId="Gen2BoxMenu", save=save, mode="withdraw", boxIndex=2,
      index=1, scroll=0, pokemon=pokemon, palettes=palettes,
      menuGfx={}, icons={},
    },
    {
      screenId="Gen2ItemPcMenu", save=save, items=itemState.items,
      entries=itemState.entries, index=1, phase="menu", rows={},
      listIndex=1, scroll=0, house=false,
    },
  }
  centerState.message, centerState.confirm = nil, nil
  pcState.picking, pcState.message, pcState.messagePages, pcState.messagePage =
    nil, nil, nil, nil
  for _, state in ipairs(validStates) do
    setmetatable(state, classFor(catalog.byId[state.screenId]))
    local prepared = provider:prepare(state, {})
    check(prepared.valid and prepared.suppress
      and prepared.presentation.complete,
      state.screenId .. " prepares a complete replacement")
    check(prepared.presentation.model.kind == "menu"
      and Data.isFunctionFree(prepared.presentation.model),
      state.screenId .. " prepares a function-free supported presentation")
  end
  check(calls == 0, "Registration and presentation invoke no source callback")

  print(("Gen2 naming/storage tests: %d checks passed"):format(checks))
end

local ok, failure = xpcall(run, debug.traceback)
if love and love.event then
  function love.load()
    if not ok then
      io.stderr:write(tostring(failure), "\n")
      love.event.quit(1)
      return
    end
    love.event.quit(0)
  end
elseif not ok then
  error(failure, 0)
end
