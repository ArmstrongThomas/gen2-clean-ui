local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"),
  "GEN2_CLEAN_UI_ROOT is required")
root = root:gsub("\\", "/")

local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)
local Data = ctx.load("adapters.data")
local Models = ctx.load("presenters.services_commerce_models")
local Presenters = ctx.load("presenters.services_commerce_presenters")
local GalleryModels = ctx.load("presenters.services_commerce_gallery_models")
local Catalog = ctx.load("contracts.catalog")
local StackPolicy = ctx.load("provider.stack_policy")

local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, ("check %d failed: %s"):format(checks, message))
end

local function detailValue(details, label)
  for _, detail in ipairs(details or {}) do
    if detail.label == label then return detail.value end
  end
  return nil
end

local function deepEqual(left, right, active)
  if type(left) ~= type(right) then return false end
  if type(left) ~= "table" then return left == right end
  if getmetatable(left) ~= nil or getmetatable(right) ~= nil then return false end
  active = active or {}
  active[left] = active[left] or {}
  if active[left][right] then return true end
  active[left][right] = true
  local count = 0
  for key, value in next, left do
    count = count + 1
    if not deepEqual(value, right[key], active) then return false end
  end
  local rightCount = 0
  for _ in next, right do rightCount = rightCount + 1 end
  return count == rightCount
end

local callbackCalls = 0
local function sourceCallback()
  callbackCalls = callbackCalls + 1
end

local function gameData()
  return {
    items={
      POTION={ name="POTION", price=300, pocket="ITEM",
        description="Restores 20 HP." },
      ANTIDOTE={ name="ANTIDOTE", price=100, pocket="ITEM",
        description="Cures poison." },
      BERRY={ name="BERRY", price=10, pocket="ITEM" },
    },
    moves={
      SCRATCH={ name="SCRATCH", type="NORMAL", power=40, accuracy=100,
        description="Scratches with sharp claws." },
      LEER={ name="LEER", type="NORMAL", power=0, accuracy=100,
        description="Lowers DEFENSE." },
    },
  }
end

local function saveData()
  return {
    player={ name="GOLD", money=45000, coins=2300 },
    inventory={ POTION=5, ANTIDOTE=2 },
    party={{ species="TOTODILE", nickname="TOTO", level=15,
      hp=42, maxHp=44, item="BERRY",
      moves={{ id="SCRATCH", pp=35, maxPp=35 },
        { id="LEER", pp=30, maxPp=30 }} }},
    dayCare={
      man={ introSeen=true, mon={ species="DITTO", level=20 } },
      lady={ introSeen=true, mon={ species="PIKACHU", level=18 } },
      hasEgg=true, compatible=false, stepsToEgg=0,
    },
  }
end

local function page(lines)
  return { pages={ lines }, page=1, onDone=sourceCallback }
end

local function confirmation(lines)
  return { pages={ lines }, page=1, choice=1,
    onYes=sourceCallback, onNo=sourceCallback }
end

local function packState()
  local data = gameData()
  local save = saveData()
  return {
    screenId="Gen2PackMenu", game={ data=data }, save=save,
    items=data.items, rows={{ id="POTION", name="POTION", count=5,
      showCount=true }}, index=1, scroll=0, pocketIndex=1,
    give=false, battle=false,
  }
end

local function martState(phase, martType)
  local data, save = gameData(), saveData()
  local state={
    screenId="Gen2MartMenu", game={ data=data }, save=save,
    isOpaque=false,
    items=data.items, marts={}, martType=martType or "STANDARD", martId=0,
    entries={{ id="POTION", name="POTION", price=300 },
      { id="ANTIDOTE", name="ANTIDOTE", price=100 }},
    index=1, scroll=0, phase=phase or "buy", onClose=sourceCallback,
  }
  if state.phase == "top" then
    state.topIndex=1
    state.topLines={ "Welcome! How may I", "help you?" }
  elseif state.phase == "intro" or state.phase == "outro" then
    state.message=page({ "Please come again!" })
  elseif state.phase == "buyQuantity" then
    state.qtyItem=state.entries[1]
    state.qty, state.qtyMax = 3, 99
  elseif state.phase == "sell" or state.phase == "sellQuantity" then
    state.pack=packState()
    if state.phase == "sellQuantity" then
      state.qtyItem=state.entries[1]
      state.qty, state.qtyMax = 2, 5
    end
  end
  return state
end

local function scriptState(style, balance)
  local data, save = gameData(), saveData()
  local grid = style == "2d"
  local items = grid and { "A", "B", "C", "D" }
    or { "FRESH WATER", "SODA POP", "CANCEL" }
  return {
    screenId="Gen2ScriptMenu", game={ data=data }, save=save,
    header={ left=0, top=0, right=12, bottom=10,
      dataFlags=128, cursor=1 },
    style=style or "vertical", balance=balance,
    items=items, rows=grid and 2 or #items, cols=grid and 2 or 1,
    spacing=grid and 5 or 0, textX=2, textY=2,
    showCursor=true, row=1, col=1, wrap=false,
    pageJump=false, keyRepeat=false, repeatDelay=16, repeatRate=4,
    onChoose=sourceCallback,
  }
end

local function bankState(kind)
  return { screenId="Gen2BankOfMom", kind=kind or "deposit",
    saved=8200, held=45000, amount=1200, position=5, blink=0,
    onDone=sourceCallback }
end

local function contestState()
  return { screenId="Gen2ContestMenu", game={ data=gameData() },
    save=saveData(),
    stock={ species="SCYTHER", nickname="SCYTHER", level=14,
      hp=36, maxHp=40 },
    caught={ species="PINSIR", nickname="PINSIR", level=13,
      hp=42, maxHp=44 },
    choice=1, onClose=sourceCallback }
end

local function dayCareState(mode)
  local data, save = gameData(), saveData()
  local state={ screenId="Gen2DayCareMenu", game={ data=data },
    save=save, data=data, textData={}, TEXT={}, side="man",
    scriptVar=0, delay=0, onClose=sourceCallback }
  if mode == "confirm" then
    state.confirm=confirmation({ "Should I raise a POKEMON?" })
  elseif mode == "party_picker" then
    state.picking=true
  else
    state.message=page({ "Come back for it later." })
  end
  return state
end

local function heldState(mode)
  local data, save = gameData(), saveData()
  local state={ screenId="Gen2HeldItemMenu", game={ data=data },
    save=save, items=data.items, slot=1, index=1, busy=false,
    onClose=sourceCallback }
  if mode == "message" then
    state.message=page({ "Took BERRY from TOTO." })
  elseif mode == "confirm" then
    state.confirm=confirmation({ "Switch held items?" })
  end
  return state
end

local function elevatorState()
  return { screenId="Gen2ElevatorMenu",
    floors={{ floorId=4, destMap="FLOOR_1", destWarp=3 },
      { floorId=5, destMap="FLOOR_2", destWarp=3 },
      { floorId=6, destMap="FLOOR_3", destWarp=3 }},
    floorNames={ [5]="1F", [6]="2F", [7]="3F" },
    origin=1, index=1, scroll=0, onDone=sourceCallback }
end

local function moveState()
  local data, save = gameData(), saveData()
  return { screenId="Gen2MoveDeleter", game={ data=data },
    mon=save.party[1], moves=data.moves, list=save.party[1].moves,
    row=1, onChoose=sourceCallback, onCancel=sourceCallback }
end

local VALID = {
  Gen2MartMenu=martState("buy"),
  Gen2ScriptMenu=scriptState("vertical"),
  Gen2BankOfMom=bankState("deposit"),
  Gen2ContestMenu=contestState(),
  Gen2DayCareMenu=dayCareState("message"),
  Gen2HeldItemMenu=heldState("give_take"),
  Gen2ElevatorMenu=elevatorState(),
  Gen2MoveDeleter=moveState(),
}

-- Exact adapters produce detached data and never invoke source ownership.
for _, screenId in ipairs(Models.ids()) do
  local adapter = assert(Models.adapterFor(screenId), screenId .. " adapter")
  local bundle, code, detail = adapter.extract(VALID[screenId], {})
  check(type(bundle) == "table",
    ("%s exact adapter accepts host shape: %s %s"):format(
      screenId, tostring(code), tostring(detail)))
  check(bundle.model.screenId == screenId,
    screenId .. " preserves exact screen identity")
  check(bundle.model.schema == "clean_ui.presenter_model.v1",
    screenId .. " source schema")
  check(Data.isFunctionFree(bundle.model), screenId .. " model is data-only")
  check(Data.isFunctionFree(bundle.actions),
    screenId .. " deferred source-input map contains no callbacks")
  check(#bundle.model.actionDescriptors > 0,
    screenId .. " exposes source-owned input descriptors")
  local presentation, presentCode, presentDetail = Presenters.convert(screenId,
    bundle.model)
  check(type(presentation) == "table",
    ("%s production conversion succeeds: %s %s"):format(screenId,
      tostring(presentCode), tostring(presentDetail)))
  check(Data.isFunctionFree(presentation),
    screenId .. " production presentation is data-only")
  check(presentation.kind == "menu" and presentation.preset ~= nil,
    screenId .. " uses a stable production menu envelope")
end
check(callbackCalls == 0,
  "adapter extraction and conversion never invoke source callbacks")

-- Representative source mutation cannot alter the detached snapshot.
local detached = assert(Models.extract("Gen2MartMenu", VALID.Gen2MartMenu)).model
check(detached.entries[1].ownedCount == 5,
  "Mart snapshots the owned inventory count for buy entries")
VALID.Gen2MartMenu.entries[1].name = "MUTATED"
VALID.Gen2MartMenu.save.player.money = 1
check(detached.entries[1].name == "POTION" and detached.money == 45000,
  "Mart source model is detached from live inventory and money")
VALID.Gen2MartMenu = martState("buy")

-- Every audited Mart phase/type, including the embedded SELL Pack, converts.
local martCases = {
  martState("top", "STANDARD"), martState("intro", "BITTER"),
  martState("buy", "BARGAIN"), martState("buyQuantity", "PHARMACY"),
  martState("sell", "STANDARD"), martState("sellQuantity", "STANDARD"),
}
for index, state in ipairs(martCases) do
  local bundle, code, detail = Models.extract("Gen2MartMenu", state)
  check(type(bundle) == "table",
    ("Mart phase %d extracts: %s %s"):format(index, tostring(code),
      tostring(detail)))
  local presentation = assert(Presenters.convert("Gen2MartMenu", bundle.model))
  check(type(presentation.rows) == "table" and presentation.opaque == true,
    "Mart phase " .. index .. " has complete production geometry")
  if state.phase == "buy" then
    check(presentation.rows[1].right == "OWN 5  Y300",
      "Mart BUY row shows owned count and price")
    check(detailValue(presentation.details, "OWNED") == "x5",
      "Mart BUY details show owned count")
  elseif state.phase == "buyQuantity" then
    check(detailValue(presentation.details, "OWNED") == "x5",
      "Mart BUY quantity details show owned count")
  elseif state.phase == "sell" or state.phase == "sellQuantity" then
    check(detailValue(presentation.details, "OWNED") == "x5",
      "Mart SELL details show owned count")
    check(detailValue(presentation.details, "SELL VALUE") == "Y150",
      "Mart SELL details show half-price value")
  end
end
local sellBundle = assert(Models.extract("Gen2MartMenu", martState("sell")))
check(sellBundle.model.nestedPack.screenId == "Gen2PackMenu",
  "Mart SELL snapshots the embedded Pack through its audited adapter")

-- Script menus cover both axes and all balance forms without guessing calls.
for _, state in ipairs({ scriptState("vertical"), scriptState("2d"),
    scriptState("vertical", "money"), scriptState("vertical", "coins"),
    scriptState("2d", "moneycoins") }) do
  local bundle = assert(Models.extract("Gen2ScriptMenu", state))
  check(Data.isFunctionFree(bundle.model), "ScriptMenu variant remains data-only")
end

-- Explicit fail-open conditions: these return nil, so the provider cannot
-- mark the native screen suppressible.
for screenId, state in pairs(VALID) do
  local wrong = {}
  for key, value in pairs(state) do wrong[key] = value end
  wrong.screenId = "Gen2Not" .. screenId
  local bundle, code = Models.extract(screenId, wrong)
  check(bundle == nil and code == "screen_mismatch",
    screenId .. " rejects non-exact identity")
end

local malformedMart = martState("sell")
malformedMart.pack.rows = nil
local noMart, martCode = Models.extract("Gen2MartMenu", malformedMart)
check(noMart == nil and (martCode == "rows_type"
    or martCode == "nested_child_invalid"),
  "malformed embedded Mart Pack remains native")
local battlePack = martState("sell")
battlePack.pack.battle = true
local noBattlePack, battlePackCode = Models.extract("Gen2MartMenu", battlePack)
check(noBattlePack == nil and battlePackCode == "battle_owned",
  "battle-owned embedded Mart Pack remains native")

local picker, pickerCode = Models.extract("Gen2DayCareMenu",
  dayCareState("party_picker"))
check(picker == nil and pickerCode == "nested_party_picker",
  "Day Care Party picker refuses partial parent suppression")
local busyHeld = heldState("give_take")
busyHeld.busy = true
local busy, busyCode = Models.extract("Gen2HeldItemMenu", busyHeld)
check(busy == nil and busyCode == "nested_child_active",
  "Held Item Pack/Mail child refuses partial parent suppression")
local contestBattle, contestBattleCode = Models.extract("Gen2ContestMenu",
  contestState(), { battleActive=true })
check(contestBattle == nil and contestBattleCode == "battle_owned",
  "Contest comparison remains native over Gold battle")
local moveBattle, moveBattleCode = Models.extract("Gen2MoveDeleter",
  moveState(), { states={{ screenId="Gen2BattleState" }} })
check(moveBattle == nil and moveBattleCode == "battle_owned",
  "Move picker remains native over Gold battle")

local badScript = scriptState("2d")
badScript.row, badScript.col = 2, 2
badScript.items[4] = nil
local noScript, scriptCode = Models.extract("Gen2ScriptMenu", badScript)
check(noScript == nil and (scriptCode == "shape_range"
    or scriptCode == "shape_array"),
  "Script grid refuses selection outside complete source items")
local badBank = bankState("deposit")
badBank.amount = 1000000
check(Models.extract("Gen2BankOfMom", badBank) == nil,
  "Bank refuses amount outside six-digit source contract")
local badElevator = elevatorState()
badElevator.floors[2].destMap = nil
check(Models.extract("Gen2ElevatorMenu", badElevator) == nil,
  "Elevator refuses an incomplete destination row")
local badMove = moveState()
badMove.list[1].id = nil
check(Models.extract("Gen2MoveDeleter", badMove) == nil,
  "Move Deleter refuses an incomplete move row")

-- Presenter.prepare carries failures through rather than claiming completion.
local dayCarePresenter = assert(Presenters.presenterFor("Gen2DayCareMenu"))
local preparedPicker, prepareCode = dayCarePresenter:prepare(
  dayCareState("party_picker"), {})
check(preparedPicker == nil and prepareCode == "nested_party_picker",
  "production presenter leaves nested Party picker native")
local contestPresenter = assert(Presenters.presenterFor("Gen2ContestMenu"))
local preparedContest, preparedContestCode = contestPresenter:prepare(
  contestState(), { battleActive=true })
check(preparedContest == nil and preparedContestCode == "battle_owned",
  "production presenter leaves battle-owned Contest native")

local assessed, assessedCode = StackPolicy.assess({
  { screenId="Gen2BattleState" }, contestState(),
}, {}, function() return { suppress=true } end)
check(type(assessed) == "table" and #assessed == 2
    and assessedCode == nil,
  "complete-stack policy accepts a fully supported battle child stack")

-- Model and presenter registration remain separate and exact for integration.
local registeredModels, registeredPresenters = {}, {}
local provider = {
  registerModelAdapter=function(_, id, adapter)
    registeredModels[id] = adapter
    return true
  end,
  registerPresenter=function(_, id, presenter)
    registeredPresenters[id] = presenter
    return true
  end,
}
check(Models.register(provider) == true, "service model registration succeeds")
check(Presenters.register(provider) == true,
  "service presenter registration succeeds")
for _, screenId in ipairs(Models.ids()) do
  check(type(registeredModels[screenId]) == "table"
      and type(registeredPresenters[screenId]) == "table",
    screenId .. " registers by exact ID")
end

-- Dedicated Gallery source models exactly match the declared variants and
-- are converted by this same production converter table.
local catalog = Catalog.build()
local fixtures = GalleryModels.galleryFixtures()
check(GalleryModels.count() == 23 and #fixtures == 23,
  "services/commerce Gallery exports all 23 declared variants")
check(Data.isFunctionFree(fixtures),
  "complete services/commerce Gallery source collection is function-free")
local seen = {}
for _, screenId in ipairs(GalleryModels.ids()) do
  local expected = assert(catalog.byId[screenId]).gallery
  check(deepEqual(GalleryModels.variantsFor(screenId), expected),
    screenId .. " Gallery variants exactly match its contract")
end
for _, fixture in ipairs(fixtures) do
  local key = fixture.screenId .. "\0" .. fixture.variant
  check(not seen[key], "Gallery fixture identity is unique " .. key)
  seen[key] = true
  check(fixture.model.screenId == fixture.screenId
      and fixture.model.schema == "clean_ui.presenter_model.v1",
    "Gallery fixture is an exact production source model " .. key)
  check(rawget(fixture, "state") == nil and rawget(fixture, "actions") == nil,
    "Gallery fixture constructs no live source screen " .. key)
  local converted, code, detail = Presenters.convert(fixture.screenId,
    fixture.model)
  check(type(converted) == "table",
    ("Gallery fixture uses production converter %s: %s %s"):format(
      key, tostring(code), tostring(detail)))
  check(Data.isFunctionFree(converted),
    "Gallery production output remains function-free " .. key)
  if fixture.screenId == "Gen2DayCareMenu"
      and fixture.variant == "party_picker" then
    check(converted.nativeStatus == true,
      "Party picker Gallery fixture documents native stack ownership")
  end
end

check(callbackCalls == 0,
  "all tests completed without executing any source-owned callback")
print(("Gen2 services/commerce: %d checks passed"):format(checks))
