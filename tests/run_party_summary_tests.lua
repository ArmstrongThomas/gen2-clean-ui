local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"),
  "GEN2_CLEAN_UI_ROOT is required")
root = root:gsub("\\", "/")

local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)
local Data = ctx.load("adapters.data")
local Party = ctx.load("adapters.party")
local Summary = ctx.load("adapters.summary")
local PartyModels = ctx.load("presenters.party_models")
local PartyPresenters = ctx.load("presenters.party_presenters")

local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, ("check %d failed: %s"):format(checks, message))
end

local function descriptor(model, id)
  for _, entry in ipairs(model.actionDescriptors or {}) do
    if entry.id == id then return entry end
  end
end

local function makeData()
  return {
    pokemon = {
      growthRates = {
        GROWTH_MEDIUM_SLOW = {
          numerator=6, denominator=5, squared=-15, linear=100, constant=140,
        },
      },
      TOTODILE = {
        id="TOTODILE", name="TOTODILE", dex=158,
        growthRate="GROWTH_MEDIUM_SLOW", types={ "WATER", "WATER" },
        spriteFront="assets/generated/battle/front/totodile.png",
      },
      CYNDAQUIL = {
        id="CYNDAQUIL", name="CYNDAQUIL", dex=155,
        growthRate="GROWTH_MEDIUM_SLOW", types={ "FIRE", "FIRE" },
        spriteFront="assets/generated/battle/front/cyndaquil.png",
      },
      TOGEPI = {
        id="TOGEPI", name="TOGEPI", dex=175,
        growthRate="GROWTH_MEDIUM_SLOW", types={ "NORMAL", "NORMAL" },
        spriteFront="assets/generated/battle/front/togepi.png",
      },
    },
    moves = {
      SCRATCH = { id="SCRATCH", name="SCRATCH", type="NORMAL", power=40,
        description="Scratches with sharp claws." },
      LEER = { id="LEER", name="LEER", type="NORMAL", power=0,
        description="Lowers the foe's<NEXT>DEFENSE." },
      WATER_GUN = { id="WATER_GUN", name="WATER GUN", type="WATER", power=40,
        description="Squirts water to<NEXT>attack." },
    },
    items = {
      BERRY = { id="BERRY", name="BERRY" },
      FLOWER_MAIL = { id="FLOWER_MAIL", name="FLOWER MAIL" },
    },
    palettes = {
      pokemon = {
        TOTODILE = {
          normal={ { 80, 160, 220 }, { 20, 70, 150 } },
          shiny={ { 80, 220, 180 }, { 20, 130, 100 } },
        },
        CYNDAQUIL = {
          normal={ { 240, 150, 70 }, { 170, 55, 30 } },
          shiny={ { 220, 190, 90 }, { 120, 85, 25 } },
        },
        TOGEPI = {
          normal={ { 245, 225, 180 }, { 200, 100, 90 } },
          shiny={ { 245, 230, 150 }, { 180, 120, 80 } },
        },
        EGG = {
          normal={ { 240, 225, 185 }, { 185, 150, 100 } },
          shiny={ { 245, 235, 150 }, { 175, 145, 80 } },
        },
      },
      partyMenu = {
        { { 255, 255, 255 }, { 245, 95, 55 },
          { 120, 35, 25 }, { 0, 0, 0 } },
      },
    },
    icons = {
      species = {
        TOTODILE="ICON_MONSTER", CYNDAQUIL="ICON_FOX",
        TOGEPI="ICON_MONSTER",
      },
      icons = {
        ICON_MONSTER = { image="assets/generated/icons/gen2/monster.png",
          frames=2, width=16, height=32 },
        ICON_FOX = { image="assets/generated/icons/gen2/fox.png",
          frames=2, width=16, height=32 },
        ICON_EGG = { image="assets/generated/icons/gen2/egg.png",
          frames=2, width=16, height=32 },
      },
      heldItem = { image="assets/generated/icons/gen2/held.png",
        width=8, height=8, mailRow=0, itemRow=1 },
    },
    menuGfx = {
      eggHatch = { egg="assets/generated/menu/egg.png" },
    },
  }
end

local function mon(species, level, fields)
  fields = fields or {}
  local value = {
    species=species, nickname=species, name=species, level=level,
    hp=20, maxHp=24,
    stats={ hp=24, attack=13, defense=14, specialAttack=11,
      specialDefense=12, speed=10 },
    experience=125, status=nil, pokerus=0,
    gender="male", shiny=false, item=nil,
    otName="GOLD", otId=12345,
    moves={
      { id="SCRATCH", pp=31, maxPp=35 },
      { id="LEER", pp=27, maxPp=30 },
    },
  }
  for key, item in pairs(fields) do value[key] = item end
  return value
end

local function egg(cycles)
  return mon("TOGEPI", 5, {
    nickname="EGG", isEgg=true, hp=0, maxHp=20,
    stats={ hp=20, attack=1, defense=1, specialAttack=1,
      specialDefense=1, speed=1 },
    experience=0, moves={}, eggSteps=cycles or 20,
    gender=nil, item=nil,
  })
end

local function basePartyState(selected)
  local data = makeData()
  local party = {
    mon("TOTODILE", 5, { nickname="TOTO", item="BERRY" }),
    mon("CYNDAQUIL", 6, { nickname="CYNDA", hp=18, maxHp=25,
      stats={ hp=25, attack=15, defense=12, specialAttack=14,
        specialDefense=13, speed=16 } }),
  }
  local calls = { count=0 }
  return {
    screenId="Gen2PartyMenu", party=party, index=selected or 1,
    prompt="Choose a POKEMON.", wantsSubmenu=true,
    wantsBattleSubmenu=false, switchFrom=nil, submenu=nil,
    pokemon=data.pokemon, moves=data.moves, items=data.items,
    icons=data.icons, palettes=data.palettes, menuGfx=data.menuGfx,
    onChoose=function() calls.count = calls.count + 1 end,
    onCancel=function() calls.count = calls.count + 1 end,
    calls=calls,
  }, data
end

local function baseSummaryState(page)
  local state, data = basePartyState(1)
  state.screenId = "Gen2SummaryMenu"
  state.page = page or 1
  state.mon = state.party[1]
  state.moveScreen = false
  state.moveDetail = false
  state.moveIndex = 1
  state.swapFrom = nil
  state.save = { player={ name="GOLD", id=12345 }, party=state.party }
  state.onClose = function() state.calls.count = state.calls.count + 1 end
  return state, data
end

-- Party list snapshots preserve exact source rows and make CANCEL meaningful.
local partyState = basePartyState(1)
local partyBundle = assert(Party.extract(partyState))
local partyModel = partyBundle.model
check(partyState.calls.count == 0,
  "Party extraction invokes no source callback")
check(Data.isFunctionFree(partyModel),
  "Party model is a plain function-free snapshot")
check(partyModel.preset == "L" and partyModel.family == "party",
  "Party uses the fixed L envelope")
check(#partyModel.rows == 3 and partyModel.rows[3].kind == "back"
  and partyModel.rows[3].label == "CANCEL",
  "Party exposes CANCEL as a real final row")
check(partyModel.rows[1].sourceIndex == 1
  and partyModel.rows[3].sourceIndex == 3,
  "Party rows preserve exact source indices")
check(descriptor(partyModel, "party.choose.1").dispatch == "source_input"
  and descriptor(partyModel, "party.choose.1").sourceIndex == 1,
  "Party selection remains source-input owned")
check(partyModel.artwork.path:find("totodile", 1, true) ~= nil
  and partyModel.artwork.paletteMode == "gen2_2bpp"
  and #partyModel.artwork.palette == 4,
  "Party selected Pokemon has a complete full-color descriptor")
check(partyModel.party[1].icon.path:find("monster", 1, true) ~= nil
  and #partyModel.party[1].icon.palette == 4,
  "Party row icon carries its source image and OBJ palette")
check(partyModel.selectedPokemon.item.name == "BERRY",
  "Party selected details preserve the held item")

partyState.party[1].nickname = "MUTATED"
partyState.palettes.pokemon.TOTODILE.normal[1][1] = 1
check(partyModel.party[1].name == "TOTO"
  and partyModel.artwork.palette[2][1] == 80,
  "Party snapshot is detached from later source mutation")

local cancelState = basePartyState(3)
local cancelBundle = assert(Party.extract(cancelState))
check(cancelBundle.model.selection.kind == "back"
  and cancelBundle.model.selectedPokemon == nil
  and cancelBundle.model.selection.description ~= nil,
  "Selecting CANCEL yields an explicit back selection instead of an empty UI")
local cancelView = assert(PartyPresenters.convert(
  "Gen2PartyMenu", cancelBundle.model))
check(cancelView.preset == "L" and cancelView.selected == 3
  and cancelView.details[1].label == "BACK",
  "Party presenter keeps CANCEL selected with meaningful details")

-- The native action submenu remains a modal snapshot; ITEM is not executed.
local actionState = basePartyState(1)
local injectedCalls = 0
actionState.submenu = {
  items={
    { id="STATS", label="STATS" },
    { id="MOVE", label="MOVE" },
    { id="ITEM", label="ITEM", onSelect=function()
      injectedCalls = injectedCalls + 1
    end },
    { id="CANCEL", label="CANCEL" },
  },
  index=3, mon=actionState.party[1], slot=1,
}
local actionBundle = assert(Party.extract(actionState))
check(injectedCalls == 0 and actionState.calls.count == 0,
  "Party submenu extraction invokes no callback")
check(actionBundle.model.mode == "actions"
  and actionBundle.model.submenu.items[3].kind == "held_item"
  and actionBundle.model.submenu.items[3].sourceIndex == 3,
  "Held-item submenu state and exact index are represented")
check(actionBundle.model.heldItemState.active
  and actionBundle.model.heldItemState.held.name == "BERRY",
  "Held-item action exposes the currently held item")
check(descriptor(actionBundle.model, "submenu.choose.3").dispatch
    == "source_input",
  "Held-item action is deferred to native source input")
local actionView = assert(PartyPresenters.convert(
  "Gen2PartyMenu", actionBundle.model))
check(actionView.modal and actionView.modal.selected == 3
  and actionView.modal.options[3].kind == "held_item",
  "Party presenter preserves the native action submenu")
check(actionView.details.sprite.path:find("totodile", 1, true) ~= nil
  and #actionView.details.sprite.palette == 4
  and actionView.details.custom_fields.columns == 2,
  "Party presenter emits rich source-image details without userdata")

local switchState = basePartyState(2)
switchState.switchFrom = 1
local switchModel = assert(Party.extract(switchState)).model
check(switchModel.mode == "switch" and #switchModel.rows == 2
  and switchModel.rows[1].switchOrigin,
  "Switch mode marks its origin and omits the unavailable CANCEL row")

local eggPartyState = basePartyState(1)
eggPartyState.party = { egg(4) }
eggPartyState.index = 1
local eggParty = assert(Party.extract(eggPartyState)).model
check(eggParty.party[1].kind == nil and eggParty.party[1].isEgg
  and eggParty.party[1].name == "EGG",
  "Party egg snapshot does not expose the hidden species as its label")
check(eggParty.artwork.species == "EGG"
  and eggParty.artwork.path:find("egg.png", 1, true) ~= nil,
  "Party egg uses the dedicated full-color egg artwork descriptor")

-- Summary snapshots name the three pages by purpose and keep art on all pages.
local statusState = baseSummaryState(1)
local statusBundle = assert(Summary.extract(statusState))
local statusModel = statusBundle.model
check(statusState.calls.count == 0,
  "Summary extraction invokes no close callback")
check(Data.isFunctionFree(statusModel),
  "Summary model is a plain function-free snapshot")
check(statusModel.preset == "L" and statusModel.purpose == "status"
  and statusModel.pageTabs[1].id == "status"
  and statusModel.pageTabs[2].id == "moves"
  and statusModel.pageTabs[3].id == "stats",
  "Summary uses purpose names status, moves, and stats")
check(statusModel.artwork.path:find("totodile", 1, true) ~= nil
  and #statusModel.artwork.palette == 4,
  "Status page carries full-color Pokemon artwork")
check(statusModel.status.hp == 20 and statusModel.status.maxHp == 24
  and statusModel.status.experience.toNext >= 0,
  "Status page preserves HP and calculated experience fields")
check(statusModel.heldItem.name == "BERRY"
  and statusModel.stats.trainer.id == 12345,
  "Summary preserves held item and trainer fields")
local statusView = assert(PartyPresenters.convert(
  "Gen2SummaryMenu", statusModel))
check(statusView.details.sprite.path == statusModel.artwork.path
  and #statusView.details.sprite.palette == 4
  and statusView.details.custom_fields.columns == 2,
  "Status page rich details retains the full-color front sprite")

local movesState = baseSummaryState(2)
local movesModel = assert(Summary.extract(movesState)).model
local movesView = assert(PartyPresenters.convert(
  "Gen2SummaryMenu", movesModel))
check(movesModel.purpose == "moves" and movesModel.artwork.path ~= nil
  and movesView.preset == "L" and movesView.purpose == "moves",
  "Moves page keeps the same L envelope and Pokemon artwork")
check(movesView.details.sprite.path == movesModel.artwork.path
  and #movesView.details.sprite.palette == 4,
  "Moves page rich details retains the full-color front sprite")
check(movesView.rows[1].label == "SCRATCH"
  and movesView.rows[1].sourceIndex == 1
  and movesView.rows[3].disabled,
  "Moves presenter preserves source slots and meaningful empty slots")

local statsState = baseSummaryState(3)
local statsModel = assert(Summary.extract(statsState)).model
local statsView = assert(PartyPresenters.convert(
  "Gen2SummaryMenu", statsModel))
check(statsModel.purpose == "stats" and statsModel.artwork.path ~= nil
  and statsView.rows[1].label == "ATTACK"
  and statsView.rows[5].label == "SPEED",
  "Stats page preserves all five Gen2 stats and Pokemon artwork")
check(statsView.details.sprite.path == statsModel.artwork.path
  and #statsView.details.sprite.palette == 4,
  "Stats page rich details retains the full-color front sprite")

-- Move detail captures reorder state without swapping or calling source code.
local reorderState = baseSummaryState(2)
local firstMove = reorderState.mon.moves[1]
local secondMove = reorderState.mon.moves[2]
reorderState.moveDetail = true
reorderState.moveIndex = 2
reorderState.swapFrom = 1
local reorderBundle = assert(Summary.extract(reorderState))
local reorder = reorderBundle.model
check(reorderState.mon.moves[1] == firstMove
  and reorderState.mon.moves[2] == secondMove
  and reorderState.calls.count == 0,
  "Move reorder extraction neither swaps moves nor invokes callbacks")
check(reorder.mode == "move_reorder" and reorder.purpose == "moves"
  and reorder.moveDetail.reorderActive
  and reorder.moveDetail.swapFrom == 1
  and reorder.moveDetail.selectedIndex == 2,
  "Move reorder source state is preserved exactly")
check(reorder.moves[1].sourceIndex == 1
  and reorder.moves[2].sourceIndex == 2
  and descriptor(reorder, "summary.move.2").sourceIndex == 2
  and descriptor(reorder, "summary.move.2").dispatch == "source_input",
  "Move actions retain exact slots and source-owned dispatch")
local reorderView = assert(PartyPresenters.convert(
  "Gen2SummaryMenu", reorder))
check(reorderView.selected == 2
  and reorderView.description:find("PLACE", 1, true) ~= nil,
  "Move presenter shows the selected drop target and reorder instruction")
check(reorderView.details.sprite.path == reorder.artwork.path
  and reorderView.details.footer_lists[1].title == "LEER INFO",
  "Move detail keeps the sprite and bottom-anchors its description")

local standaloneState = baseSummaryState(2)
standaloneState.moveScreen = true
standaloneState.moveDetail = true
local standalone = assert(Summary.extract(standaloneState)).model
check(standalone.moveDetail.standalone
  and descriptor(standalone, "summary.move.back").input == "b",
  "Standalone MOVE screen remains source-owned and distinguishable")

local eggState = baseSummaryState(1)
eggState.party = { egg(4) }
eggState.mon = eggState.party[1]
eggState.index = 1
eggState.save.party = eggState.party
local eggSummary = assert(Summary.extract(eggState)).model
check(eggSummary.mode == "egg" and eggSummary.purpose == "egg"
  and eggSummary.pokemon.species == nil
  and eggSummary.artwork.species == "EGG",
  "Egg summary does not leak its hidden species and uses EGG artwork")
check(eggSummary.egg.lines[1]:find("making sounds", 1, true) ~= nil,
  "Egg summary preserves the source hatch-stage message")
local eggView = assert(PartyPresenters.convert(
  "Gen2SummaryMenu", eggSummary))
check(eggView.details.sprite.path == eggSummary.artwork.path
  and #eggView.details.sprite.palette == 4
  and eggView.details.footer_lists[1].title == "HATCHING",
  "Egg summary emits rich sprite and bottom-anchored flavor details")

-- Snapshots stay detached after move definitions and live records change.
statusState.mon.nickname = "CHANGED"
statusState.moves.SCRATCH.name = "CHANGED MOVE"
check(statusModel.pokemon.name == "TOTO"
  and statusModel.moves[1].name == "SCRATCH",
  "Summary snapshot is detached from live Pokemon and move data")

-- Incomplete or ambiguous states fail instead of producing a suppressible UI.
local battleState = basePartyState(1)
battleState.wantsBattleSubmenu = true
local _, battleCode = Party.extract(battleState)
check(battleCode == "battle_owned", "Battle-owned Party remains native")

local missingSprite = baseSummaryState(1)
missingSprite.pokemon.TOTODILE.spriteFront = nil
local _, spriteCode = Summary.extract(missingSprite)
check(spriteCode == "sprite_incomplete",
  "Missing front art fails open instead of showing a blank sprite")

local unsafeSprite = baseSummaryState(1)
unsafeSprite.pokemon.TOTODILE.spriteFront = "../outside.png"
local _, unsafeSpriteCode = Summary.extract(unsafeSprite)
check(unsafeSpriteCode == "sprite_incomplete",
  "Non-generated source-image paths fail before presentation")

local missingPalette = baseSummaryState(1)
missingPalette.palettes.pokemon.TOTODILE = nil
local _, paletteCode = Summary.extract(missingPalette)
check(paletteCode == "palette_incomplete",
  "Missing color data fails open instead of rendering grayscale")

local mismatched = baseSummaryState(1)
mismatched.mon = mon("TOTODILE", 5)
local _, mismatchCode = Summary.extract(mismatched)
check(mismatchCode == "source_mismatch",
  "Detached selected-mon objects fail instead of guessing an index")

local emptyDetail = baseSummaryState(2)
emptyDetail.mon.moves = {}
emptyDetail.moveDetail = true
emptyDetail.moveIndex = 1
local _, emptyCode = Summary.extract(emptyDetail)
check(emptyCode == "move_detail_empty",
  "Move detail with no source moves fails open")

local badMove = baseSummaryState(2)
badMove.moves.SCRATCH.description = nil
local _, badMoveCode = Summary.extract(badMove)
check(badMoveCode == "move_incomplete",
  "Incomplete move definitions fail rather than inventing details")

-- Focused registration helpers expose only these two exact screen adapters.
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
check(PartyModels.register(provider) == true
  and registeredModels.Gen2PartyMenu == Party
  and registeredModels.Gen2SummaryMenu == Summary,
  "Focused model adapters register by exact screen ID")
check(PartyPresenters.register(provider) == true
  and type(registeredPresenters.Gen2PartyMenu.prepare) == "function"
  and type(registeredPresenters.Gen2SummaryMenu.prepare) == "function",
  "Focused presenters register by exact screen ID")
local prepared = assert(registeredPresenters.Gen2SummaryMenu:prepare(
  baseSummaryState(1)))
check(prepared.complete and prepared.model.preset == "L"
  and Data.isFunctionFree(prepared.model),
  "Registered Summary presenter produces a complete data-only L model")

print(("Gen2 Party/Summary tests: %d checks passed"):format(checks))
