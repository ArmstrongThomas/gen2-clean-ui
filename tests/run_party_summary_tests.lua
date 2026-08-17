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
local vendorRoot = root .. "/mods/gen2_clean_ui/vendor/clean_ui_core"
local coreCache = {}
local function loadCore(name)
  if coreCache[name] ~= nil then return coreCache[name] end
  local path = vendorRoot .. "/" .. name:gsub("%.", "/") .. ".lua"
  local chunk, loadError = loadfile(path)
  assert(chunk, loadError)
  local exported = chunk(loadCore)
  coreCache[name] = exported
  return exported
end
local MenuLayout = loadCore("presentation.menu_layout")
local MenuRender = loadCore("presentation.menu_render")

local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, ("check %d failed: %s"):format(checks, message))
end

check(MenuRender.textStyles.title.stepDelta == 1
  and MenuRender.textStyles.display.stepDelta == 2
  and MenuRender.textStyleOptions("caption").stepDelta == -1,
  "Party/Summary uses the shared per-run typography roles")

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

-- Party list snapshots preserve the visible Pokemon rows; native CANCEL is a
-- source boundary handled by B rather than a Clean-visible row.
local partyState = basePartyState(1)
local partyBundle = assert(Party.extract(partyState))
local partyModel = partyBundle.model
check(partyState.calls.count == 0,
  "Party extraction invokes no source callback")
check(Data.isFunctionFree(partyModel),
  "Party model is a plain function-free snapshot")
check(partyModel.preset == "L" and partyModel.family == "party",
  "Party uses the fixed L envelope")
check(#partyModel.rows == 2 and partyModel.rows[2].kind == "pokemon",
  "Party exposes only visible Pokemon rows")
check(partyModel.rows[1].sourceIndex == 1
  and partyModel.rows[2].sourceIndex == 2
  and descriptor(partyModel, "party.cancel") == nil,
  "Party rows preserve source indices without a hidden CANCEL action")
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
check(partyModel.party[1].icon.crop.x == 0
  and partyModel.party[1].icon.crop.y == 0
  and partyModel.party[1].icon.crop.w == 16
  and partyModel.party[1].icon.crop.h == 16,
  "Party icon snapshots pin the first frame of the animated icon sheet")
check(partyModel.party[1].icon.animation.frames == 2
  and partyModel.party[1].icon.animation.frameDuration == 16,
  "Party icon snapshots preserve the official two-frame timing contract")
check(partyModel.party[1].genderIcon.path
  == "assets/generated/icons/gen2/gender10px.png"
  and partyModel.party[1].genderIcon.assetPath
    == "overrides/icons/gen2/gender10px.png"
  and partyModel.party[1].genderIcon.crop.x == 0
  and partyModel.party[1].genderIcon.crop.w == 10
  and partyModel.party[1].genderIcon.variants["16"].crop.x == 0
  and partyModel.party[1].genderIcon.variants["16"].crop.w == 16,
  "Male party members use both authored gender-sheet variants")
local femalePartyState = basePartyState(1)
femalePartyState.party[1].gender = "female"
local femalePartyModel = assert(Party.extract(femalePartyState)).model
check(femalePartyModel.party[1].genderIcon.crop.x == 10
  and femalePartyModel.party[1].genderIcon.variants["16"].crop.x == 16,
  "Female party members use the authored female gender-sheet crop")
local genderlessPartyState = basePartyState(1)
genderlessPartyState.party[1].gender = "genderless"
local genderlessPartyModel = assert(Party.extract(genderlessPartyState)).model
check(genderlessPartyModel.party[1].genderIcon.gender == "none"
  and genderlessPartyModel.party[1].genderIcon.crop.x == 20
  and genderlessPartyModel.party[1].genderIcon.variants["16"].crop.x == 32,
  "Genderless party members use the authored purple-circle slot")
local ratioFixture = {
  pokemon={
    NIDORAN_F={ genderRatio=254 },
    NIDORAN_M={ genderRatio=0 },
    DITTO={ genderRatio=255 },
  },
}
check(Party.genderFor(ratioFixture,
    { species="NIDORAN_F", gender="male" }) == "female"
  and Party.genderFor(ratioFixture,
    { species="NIDORAN_M", gender="female" }) == "male"
  and Party.genderFor(ratioFixture,
    { species="DITTO", gender="unknown" }) == "none",
  "Species gender-ratio endpoints override contradictory runtime gender")
check(Party.genderIconFor("unknown").gender == "none",
  "The host unknown gender sentinel selects the authored genderless icon")
local ordinaryRatioState = basePartyState(1)
ordinaryRatioState.pokemon.TOTODILE.genderRatio = 127
ordinaryRatioState.party[1].gender = "female"
local ordinaryRatioModel = assert(Party.extract(ordinaryRatioState)).model
check(ordinaryRatioModel.party[1].gender == "female",
  "Ordinary species preserve the host DV-derived gender value")
check(partyModel.selectedPokemon.item.name == "BERRY",
  "Party selected details preserve the held item")

local conditionState = basePartyState(2)
conditionState.party[2].status = "paralysis"
local conditionModel = assert(Party.extract(conditionState)).model
local conditionView = assert(PartyPresenters.convert(
  "Gen2PartyMenu", conditionModel))
check(conditionView.partyLayout == "list"
  and conditionView.partyCountText == "2 / 6"
  and conditionView.controlScheme.id == "gen2_party_clean_v1",
  "Party presenter selects the fixed Clean list layout and declarative controls")
check(conditionView.rows[1].status == nil
  and conditionView.rows[2].status == "PAR"
  and conditionView.rows[2].gender == "male"
  and conditionView.rows[2].genderIcon.crop.x == 0
  and #conditionView.rows[2].types == 1,
  "Healthy party rows omit a status badge while abnormal rows expose a three-character code")

local function layoutForFontHeight(model, height)
  local font = {
    getHeight=function() return height end,
    getWidth=function(_, value)
      return #tostring(value or "") * math.max(1, math.floor(height * 0.5))
    end,
  }
  return assert(MenuLayout.measure({
    outer={ x=0, y=0, w=800, h=600 }, scale=1,
    font={ step=1 },
  }, model, font, "comfortable"))
end
local tenPixelLayout = layoutForFontHeight(conditionView, 10)
local twentyPixelLayout = layoutForFontHeight(conditionView, 20)
check(tenPixelLayout.partyList.columns.genderIconSize == 10
  and twentyPixelLayout.partyList.columns.genderIconSize == 20,
  "gender icon geometry follows the selected font pixel height")
check(tenPixelLayout.partyList.columns.genderIconSize
    < tenPixelLayout.partyList.columns.pokemonIconSize,
  "gender art is not allowed to overpower the party icon slot at 1x")
local function iconForFontHeight(height)
  return MenuRender.resolveGenderIcon(partyModel.party[1].genderIcon, {
    getHeight=function() return height end,
  })
end
local tenIcon, tenSource = iconForFontHeight(10)
local twentyIcon, twentySource = iconForFontHeight(20)
local sixteenIcon, sixteenSource = iconForFontHeight(16)
local thirtyTwoIcon, thirtyTwoSource = iconForFontHeight(32)
local fifteenIcon, fifteenSource = iconForFontHeight(15)
check(tenSource == 10 and tenIcon.path:find("gender10px", 1, true) ~= nil
  and tenIcon.crop.w == 10
  and twentySource == 10 and twentyIcon.crop.w == 10
  and sixteenSource == 16 and sixteenIcon.crop.w == 16
  and thirtyTwoSource == 16 and thirtyTwoIcon.crop.w == 16,
  "Gender art selects the matching source sheet for clean font multiples")
check(fifteenSource == 10 and fifteenIcon.crop.w == 10,
  "Gender art falls back to the largest clean source that fits an in-between size")

local dualTypeState, dualTypeData = basePartyState(1)
dualTypeData.pokemon.TOTODILE.types = { "WATER", "ICE" }
local dualTypeModel = assert(Party.extract(dualTypeState)).model
local dualTypeView = assert(PartyPresenters.convert(
  "Gen2PartyMenu", dualTypeModel))
check(#dualTypeView.rows[1].types == 2
  and dualTypeView.rows[1].types[1].label == "WATER"
  and dualTypeView.rows[1].types[2].label == "ICE",
  "Party presentation preserves distinct dual types without duplicating single types")

partyState.party[1].nickname = "MUTATED"
partyState.palettes.pokemon.TOTODILE.normal[1][1] = 1
check(partyModel.party[1].name == "TOTO"
  and partyModel.artwork.palette[2][1] == 80,
  "Party snapshot is detached from later source mutation")

local sourceEndState = basePartyState(3)
local sourceEndBundle = assert(Party.extract(sourceEndState))
check(sourceEndBundle.model.navigation.selectedIndex == 2
  and sourceEndBundle.model.navigation.sourceSelectedIndex == 3
  and sourceEndState.index == 2
  and sourceEndBundle.model.selection.kind == "pokemon"
  and sourceEndBundle.model.selectedPokemon ~= nil,
  "Native trailing CANCEL index clamps the live cursor to the last visible Pokemon")
local sourceEndView = assert(PartyPresenters.convert(
  "Gen2PartyMenu", sourceEndBundle.model))
check(sourceEndView.preset == "L" and sourceEndView.selected == 2
  and sourceEndView.details.title == "CYNDA",
  "Party presenter keeps the clamped selection on a visible row")

local partyWrapState = basePartyState(2)
partyWrapState.index = 2
assert(Party.extract(partyWrapState))
partyWrapState.index = 3
local partyDownWrap = assert(Party.extract(partyWrapState))
check(partyDownWrap.model.navigation.selectedIndex == 1
  and partyWrapState.index == 1,
  "Party Down from the last Pokemon wraps to the first visible row")
partyWrapState.index = 3
local partyUpWrap = assert(Party.extract(partyWrapState))
check(partyUpWrap.model.navigation.selectedIndex == 2
  and partyWrapState.index == 2,
  "Party Up from the first Pokemon wraps to the last visible row")

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
  and #actionBundle.model.submenu.items == 2
  and actionBundle.model.submenu.items[1].kind == "summary"
  and actionBundle.model.submenu.items[1].label == "DETAILS"
  and actionBundle.model.submenu.items[2].kind == "held_item"
  and actionBundle.model.submenu.items[2].sourceIndex == 3
  and actionBundle.model.submenu.items[2].id ~= "CANCEL"
  and descriptor(actionBundle.model, "submenu.choose.2") == nil
  and descriptor(actionBundle.model, "submenu.choose.4") == nil,
  "Action submenu hides MOVE and CANCEL while preserving source indices")
check(actionBundle.model.heldItemState.active
  and actionBundle.model.heldItemState.held.name == "BERRY",
  "Held-item action exposes the currently held item")
check(descriptor(actionBundle.model, "submenu.choose.3").dispatch
    == "source_input",
  "Held-item action is deferred to native source input")
local actionView = assert(PartyPresenters.convert(
  "Gen2PartyMenu", actionBundle.model))
check(actionView.modal and actionView.modal.selected == 2
  and #actionView.modal.options == 2
  and actionView.modal.compact
  and actionView.modal.options[1].label == "DETAILS"
  and actionView.modal.options[2].kind == "held_item",
  "Party presenter emits a compact action submenu without MOVE or CANCEL")
local actionLayout = layoutForFontHeight(actionView, 20)
check(actionLayout.modal and actionLayout.modal.options[1].rect.h
    < actionLayout.partyList.rowHeight
  and #actionLayout.modal.options == 2
  and actionLayout.modal.rect.w < actionLayout.inner.w * 0.7,
  "Action modal uses compact rows and content-sized geometry")

local cancelActionState = basePartyState(1)
cancelActionState.submenu = {
  items={
    { id="STATS", label="STATS" },
    { id="MOVE", label="MOVE" },
    { id="ITEM", label="ITEM" },
    { id="CANCEL", label="CANCEL" },
  },
  index=4, mon=cancelActionState.party[1], slot=1,
}
local cancelActionBundle = assert(Party.extract(cancelActionState))
check(cancelActionState.submenu.index == 3
  and cancelActionBundle.model.submenu.sourceSelectedIndex == 4
  and cancelActionBundle.model.submenu.selectedIndex == 2
  and cancelActionBundle.model.submenu.items[2].id == "ITEM",
  "Hidden action boundary remaps the live host cursor to the visible final action")

local actionWrapState = basePartyState(1)
actionWrapState.submenu = {
  items={
    { id="STATS", label="STATS" },
    { id="MOVE", label="MOVE" },
    { id="ITEM", label="ITEM" },
    { id="CANCEL", label="CANCEL" },
  },
  index=3, mon=actionWrapState.party[1], slot=1,
}
assert(Party.extract(actionWrapState))
actionWrapState.submenu.index = 4
local actionDownWrap = assert(Party.extract(actionWrapState))
check(actionDownWrap.model.submenu.selectedIndex == 1
  and actionWrapState.submenu.index == 1,
  "Action-menu Down from the last visible action wraps to the first action")
actionWrapState.submenu.index = 4
local actionUpWrap = assert(Party.extract(actionWrapState))
check(actionUpWrap.model.submenu.selectedIndex == 2
  and actionWrapState.submenu.index == 3,
  "Action-menu Up from the first action wraps to the last visible action")
  check(actionView.details.sprite.path:find("totodile", 1, true) ~= nil
    and #actionView.details.sprite.palette == 4
    and #actionView.details.typeBadges == 1
    and actionView.details.typeBadges[1].label == "WATER"
    and actionView.details.bars[1].fraction == (20 / 24),
  "Party presenter emits colored type badges and an HP bar without userdata")

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
  and statusModel.status.experience.toNext >= 0
  and statusModel.status.experience.nextLevel == 6
  and statusModel.status.experience.progressSpan > 0
  and statusModel.status.experience.fraction >= 0
  and statusModel.status.experience.fraction <= 1,
  "Status page preserves HP and level-to-level experience progress")
check(statusModel.pokemon.name == "TOTO"
  and statusModel.pokemon.nickname == "TOTO"
  and statusModel.pokemon.speciesName == "TOTODILE",
  "Summary identity exposes nickname and species separately")
local speciesOnlyState = baseSummaryState(1)
speciesOnlyState.mon.nickname = nil
speciesOnlyState.mon.name = "TOTODILE"
local speciesOnly = assert(Summary.extract(speciesOnlyState)).model
check(speciesOnly.pokemon.name == "TOTODILE"
  and speciesOnly.pokemon.nickname == nil
  and speciesOnly.pokemon.speciesName == "TOTODILE",
  "Summary identity keeps species-only records to one visible name")
check(statusModel.heldItem.name == "BERRY"
  and statusModel.stats.trainer.id == 12345,
  "Summary preserves held item and trainer fields")
check(statusModel.pokemon.genderIcon.path
  == "assets/generated/icons/gen2/gender10px.png"
  and statusModel.pokemon.genderIcon.assetPath
    == "overrides/icons/gen2/gender10px.png"
  and statusModel.pokemon.genderIcon.crop.x == 0,
  "Summary identity uses the same authored gender-sheet descriptor")
local statusView = assert(PartyPresenters.convert(
  "Gen2SummaryMenu", statusModel))
check(statusView.details.sprite.path == statusModel.artwork.path
  and #statusView.details.sprite.palette == 4
  and statusView.details.custom_fields.columns == 2
  and #statusView.details.custom_fields.data == 8,
  "Status page details fills the journal grid with exposed fields")
check(statusView.partyLayout == "summary"
  and statusView.pageTabs[1].id == "journal"
  and statusView.pageTabs[2].id == "moves"
  and statusView.pageTabs[3].id == "details"
  and statusView.pageTabs[1].selected
  and statusView.controlScheme.id == "gen2_summary_clean_v1"
  and statusView.controlLegend[1].label == "LEFT/RIGHT PAGE"
  and statusView.controlLegend[3].label == "B BACK",
  "Summary presenter follows the host Journal/Moves/Details tab order and Clean control contract")
local statusLayout = layoutForFontHeight(statusView, 20)
check(statusLayout.summary and statusLayout.summary.content
  and statusLayout.summary.content.h > 0
  and statusLayout.summary.portrait.h == statusLayout.summary.info.h,
  "Journal geometry keeps the identity rail and dense content region aligned")

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
local movesLayout = layoutForFontHeight(movesView, 20)
check(movesLayout.summary and #movesLayout.summary.moveRows == 4
  and movesLayout.summary.moveList.h > 0
  and movesLayout.summary.moveInfo.h > 0
  and movesLayout.summary.moveInfo.y > movesLayout.summary.moveList.y,
  "Moves geometry keeps all four slots and a separate detail rail")
check(movesView.pageTabs[2].selected and not movesView.pageTabs[1].selected
  and movesView.summary.moves[1].description[1]:find("<NEXT>", 1, true) == nil,
  "Moves page selects MOVES and keeps continuation markers out of descriptions")
check(movesView.controlLegend[1].label == "SELECT VIEW MOVES"
  and movesView.controlLegend[2].label == "UP/DOWN POKEMON",
  "Moves preview exposes the host-supported move-detail transition")
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
  and #statsView.details.sprite.palette == 4
  and #statsView.details.custom_fields.data == 10,
  "Details page fills both columns with exposed identity and stat fields")
check(statsView.pageTabs[3].selected
  and statsView.pageTabs[3].label == "DETAILS",
  "Stats source page is presented as the Clean Details tab")

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
  and reorderView.description:find("PLACE", 1, true) ~= nil
  and reorderView.controlLegend[1].label == "A PLACE MOVE"
  and reorderView.controlLegend[2].label == "UP/DOWN MOVE",
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
local battleModel, battleCode = Party.extract(battleState)
check(battleModel ~= nil and battleModel.model.mode == "party",
  "Battle-owned Party now produces a clean child model: "
    .. tostring(battleCode))

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
  and prepared.model.schema == "clean_ui.v3.presentation.v1"
  and prepared.model.apiVersion == 3
  and Data.isFunctionFree(prepared.model),
  "Registered Summary presenter produces a complete canonical V3 model")

local partyPrepared = assert(registeredPresenters.Gen2PartyMenu:prepare(
  basePartyState(1)))
check(partyPrepared.model.schema == "clean_ui.v3.presentation.v1"
  and partyPrepared.model.apiVersion == 3,
  "Registered Party presenter emits the canonical V3 model")

print(("Gen2 Party/Summary tests: %d checks passed"):format(checks))
