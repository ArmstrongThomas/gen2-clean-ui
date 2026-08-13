local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"),
  "GEN2_CLEAN_UI_ROOT is required"):gsub("\\", "/")
local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)

local Data = ctx.load("adapters.data")
local Pokegear = ctx.load("adapters.pokegear")
local PokegearPresenter = ctx.load("presenters.pokegear")
local MapRadio = ctx.load("adapters.map_radio")
local MapRadioPresenter = ctx.load("presenters.map_radio")
local GalleryModels = ctx.load("presenters.pokegear_gallery_models")

local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, ("check %d failed: %s"):format(checks, message))
end

local function findFixture(fixtures, screenId, variant)
  for _, fixture in ipairs(fixtures) do
    if fixture.screenId == screenId and fixture.variant == variant then
      return fixture
    end
  end
end

local function freshState(screenId, variant)
  return assert(findFixture(GalleryModels.sourceFixtures(), screenId, variant),
    screenId .. "." .. variant .. " fixture").state
end

local function descriptor(model, id)
  for _, item in ipairs(model.actionDescriptors or {}) do
    if item.id == id then return item end
  end
end

local sourceFixtures = GalleryModels.sourceFixtures()
local galleryFixtures = GalleryModels.galleryFixtures()
check(#sourceFixtures == 10 and #galleryFixtures == 10
  and GalleryModels.count() == 10,
  "Gallery supplies nine Pokegear variants and one wall-radio variant")

local expected = {
  Gen2Pokegear={
    strip=true, clock=true, map=true, fly=true, radio=true, phone=true,
    phone_submenu=true, call=true, no_signal=true,
  },
  Gen2MapRadio={ station=true },
}
local seen = { Gen2Pokegear={}, Gen2MapRadio={} }
for index, source in ipairs(sourceFixtures) do
  check(Data.isFunctionFree(source.state),
    source.screenId .. "." .. source.variant .. " source state is data-only")
  check(expected[source.screenId][source.variant] == true,
    source.screenId .. "." .. source.variant .. " is an expected variant")
  check(not seen[source.screenId][source.variant],
    source.screenId .. "." .. source.variant .. " is unique")
  seen[source.screenId][source.variant] = true

  local adapter = source.screenId == "Gen2Pokegear" and Pokegear or MapRadio
  local presenter = source.screenId == "Gen2Pokegear"
    and PokegearPresenter or MapRadioPresenter
  local bundle, code, detail = adapter.extract(source.state, { synthetic=true })
  check(type(bundle) == "table" and type(bundle.model) == "table",
    source.screenId .. "." .. source.variant .. " extracts: "
      .. tostring(code) .. " " .. tostring(detail))
  check(bundle.model.view == source.variant
      or (source.screenId == "Gen2MapRadio" and bundle.model.view == "station"),
    source.screenId .. "." .. source.variant .. " keeps exact view identity")
  check(Data.isFunctionFree(bundle.model),
    source.screenId .. "." .. source.variant .. " model is function-free")
  local presentation, presentCode = presenter.convert(bundle.model)
  check(type(presentation) == "table",
    source.screenId .. "." .. source.variant .. " converts: "
      .. tostring(presentCode))
  check(Data.isFunctionFree(presentation),
    source.screenId .. "." .. source.variant .. " presentation is data-only")
  check(presentation.preset == "L",
    source.screenId .. "." .. source.variant .. " uses stable L envelope")
  check(galleryFixtures[index].screenId == source.screenId
      and galleryFixtures[index].variant == source.variant,
    "Gallery preserves source fixture order and identity")
  local galleryPresentation = assert(presenter.convert(
    galleryFixtures[index].model))
  check(Data.isFunctionFree(galleryPresentation),
    source.screenId .. "." .. source.variant
      .. " Gallery routes through production converter")
end
for screenId, variants in pairs(expected) do
  for variant in pairs(variants) do
    check(seen[screenId][variant] == true,
      screenId .. "." .. variant .. " has a Gallery source fixture")
  end
end

local stripSource = { state=freshState("Gen2Pokegear", "strip") }
local hostileCalls = 0
stripSource.state.onClose = function()
  hostileCalls = hostileCalls + 1
  error("source callback executed during extraction")
end
stripSource.state.onCall = stripSource.state.onClose
local strip = assert(Pokegear.extract(stripSource.state))
check(hostileCalls == 0, "Pokegear extraction never invokes source callbacks")
check(strip.model.view == "strip" and #strip.model.cards == 4
  and strip.model.activeCard.id == "clock",
  "strip snapshots all unlocked cards and exact active card")
check(descriptor(strip.model, "pokegear.strip.open").dispatch == "source_input",
  "strip activation is delegated back to screen.update")

local clock = assert(Pokegear.extract(freshState("Gen2Pokegear", "clock")))
check(clock.model.clock.day == "MONDAY"
  and clock.model.clock.hour == 10 and clock.model.clock.minute == 37,
  "clock snapshots exact day and time without calling host clock methods")
local clockView = assert(PokegearPresenter.convert(clock.model))
check(clockView.details[1].value == "MONDAY"
  and clockView.details[2].value == "10:37 AM",
  "clock presenter exposes measured clean details")

local mapSource = { state=freshState("Gen2Pokegear", "map") }
local mapBundle = assert(Pokegear.extract(mapSource.state))
check(mapBundle.model.map.region == "johto"
  and mapBundle.model.map.current.name == "ROUTE 30"
  and mapBundle.model.map.player.name == "NEW BARK TOWN",
  "map separates movable cursor from player landmark")
local mapView = assert(PokegearPresenter.convert(mapBundle.model))
check(mapView.map.cursorIndex == 4 and mapView.selected ~= nil,
  "map presenter preserves exact cursor geometry data")

local flyBundle = assert(Pokegear.extract(freshState("Gen2Pokegear", "fly")))
check(flyBundle.model.map.flyIndex == 2
  and flyBundle.model.map.flyRows[2].spawn == "SPAWN_CHERRYGROVE",
  "fly snapshot keeps exact selected source destination")
check(assert(PokegearPresenter.convert(flyBundle.model)).selected == 2,
  "fly presenter preserves source selection")

local radioBundle = assert(Pokegear.extract(freshState("Gen2Pokegear", "radio")))
check(radioBundle.model.radio.current.frequency == "04.5"
  and radioBundle.model.radio.current.station == "OAKS_POKEMON_TALK"
  and radioBundle.model.radio.top:find("OAK", 1, true),
  "radio snapshots tuned frequency, station, and live broadcast lines")
check(#assert(PokegearPresenter.convert(radioBundle.model)).rows == 8,
  "radio presenter exposes the complete native dial")

local phoneBundle = assert(Pokegear.extract(freshState("Gen2Pokegear", "phone")))
check(#phoneBundle.model.phone.rows == 10
  and phoneBundle.model.phone.rows[1].label == "MOM"
  and phoneBundle.model.phone.rows[3].label == "JOEY"
  and phoneBundle.model.phone.rows[3].className == "YOUNGSTER",
  "phone list keeps all ten native slots and resolves exact contact names")
check(phoneBundle.model.phone.rows[1].deletable == false
  and phoneBundle.model.phone.rows[3].deletable == true,
  "phone contact metadata preserves permanent-number deletion rules")

local submenuBundle = assert(Pokegear.extract(
  freshState("Gen2Pokegear", "phone_submenu")))
local submenuView = assert(PokegearPresenter.convert(submenuBundle.model))
check(submenuBundle.model.phone.submenu.selectedIndex == 2
  and submenuView.modal.options[2].label == "DELETE",
  "phone submenu keeps exact native action and cursor")

local callBundle = assert(Pokegear.extract(freshState("Gen2Pokegear", "call")))
local callView = assert(PokegearPresenter.convert(callBundle.model))
check(callBundle.model.phone.call.contact == 15
  and callView.modal.title == "JOEY"
  and callView.description:find("RATTATA", 1, true),
  "connected call snapshots source-owned call presentation only")

local noSignalBundle = assert(Pokegear.extract(
  freshState("Gen2Pokegear", "no_signal")))
local noSignalView = assert(PokegearPresenter.convert(noSignalBundle.model))
check(noSignalBundle.model.phone.service == false
  and noSignalBundle.model.phone.call.kind == "nosignal"
  and noSignalView.modal.title == "NO SIGNAL",
  "no-signal branch remains distinct and reports unavailable service")

local wallBundle = assert(MapRadio.extract(freshState("Gen2MapRadio", "station")))
local wallView = assert(MapRadioPresenter.convert(wallBundle.model))
check(wallBundle.model.station.id == "LUCKY_CHANNEL"
  and wallBundle.model.broadcast.lines[1]:find("lucky", 1, true)
  and wallView.opaque == false,
  "wall radio keeps its exact non-opaque station seam")
check(descriptor(wallBundle.model, "map_radio.close_b").dispatch
    == "source_input",
  "wall-radio close remains owned by source update")

-- Models are detached snapshots, not references into live source tables.
local detachedSource = freshState("Gen2Pokegear", "phone")
local detached = assert(Pokegear.extract(detachedSource))
detachedSource.save.phone.list[1] = 0
detachedSource.game.data.gen2PhoneContacts.PHONE_MOM.number = 99
check(detached.model.phone.rows[1].contactId == 1
  and detached.model.phone.rows[1].label == "MOM",
  "phone model is detached from mutable save and registry data")

-- Direct adapter calls fail native under malformed/custom/battle contracts,
-- in addition to the provider's exact-class and complete-stack checks.
check(Pokegear.extract(nil) == nil, "Pokegear rejects non-table roots")
local wrongId = freshState("Gen2Pokegear", "clock")
wrongId.screenId = "Gen2OptionsMenu"
local _, wrongCode = Pokegear.extract(wrongId)
check(wrongCode == "screen_id_mismatch", "Pokegear requires exact screen id")

local custom = freshState("Gen2Pokegear", "clock")
custom.draw = function() end
local _, customCode = Pokegear.extract(custom)
check(customCode == "custom_draw", "custom draw override stays native")
local customWide = freshState("Gen2Pokegear", "clock")
customWide.drawWidescreen = function() end
local _, customWideCode = Pokegear.extract(customWide)
check(customWideCode == "custom_draw",
  "custom widescreen override stays native")

local contextBattle = freshState("Gen2Pokegear", "clock")
local _, contextBattleCode = Pokegear.extract(contextBattle,
  { battleActive=true })
check(contextBattleCode == "battle_owned",
  "explicit battle context leaves Pokegear native")
local stackBattle = freshState("Gen2Pokegear", "clock")
stackBattle.game.stack.states = { { screenId="Gen2BattleState" } }
local _, stackBattleCode = Pokegear.extract(stackBattle)
check(stackBattleCode == "battle_owned",
  "battle parent in live stack leaves Pokegear native")

local duplicateCards = freshState("Gen2Pokegear", "clock")
duplicateCards.cards[2].id = "clock"
local _, duplicateCode = Pokegear.extract(duplicateCards)
check(duplicateCode == "cards_shape", "duplicate cards fail native")
local reorderedCards = freshState("Gen2Pokegear", "clock")
reorderedCards.cards[1], reorderedCards.cards[2]
  = reorderedCards.cards[2], reorderedCards.cards[1]
local _, reorderedCode = Pokegear.extract(reorderedCards)
check(reorderedCode == "cards_shape", "reordered source cards fail native")
local badStation = freshState("Gen2Pokegear", "clock")
badStation.station = 9
local _, badStationCode = Pokegear.extract(badStation)
check(badStationCode == "station_range",
  "malformed inactive radio cursor still fails native")
local badPhoneNavigation = freshState("Gen2Pokegear", "clock")
badPhoneNavigation.phoneScroll = 7
local _, badPhoneNavigationCode = Pokegear.extract(badPhoneNavigation)
check(badPhoneNavigationCode == "phone_navigation_shape",
  "malformed inactive phone cursor still fails native")
local futureMode = freshState("Gen2Pokegear", "clock")
futureMode.mode = "future"
local _, modeCode = Pokegear.extract(futureMode)
check(modeCode == "mode_shape", "unknown Pokegear mode fails native")
local badFly = freshState("Gen2Pokegear", "fly")
badFly.fly = "not-a-list"
local _, flyCode = Pokegear.extract(badFly)
check(flyCode == "fly_shape", "malformed fly data fails native")
local badFlyCards = freshState("Gen2Pokegear", "fly")
badFlyCards.cards[1].id = "clock"
local _, badFlyCardsCode = Pokegear.extract(badFlyCards)
check(badFlyCardsCode == "fly_cards_shape",
  "fly screen with a non-map card fails native")
local badRadio = freshState("Gen2Pokegear", "radio")
badRadio.radio.top = false
local _, radioCode = Pokegear.extract(badRadio)
check(radioCode == "radio_shape", "malformed broadcast state fails native")
local unknownContact = freshState("Gen2Pokegear", "phone")
unknownContact.save.phone.list[1] = 99
local _, contactCode = Pokegear.extract(unknownContact)
check(contactCode == "contact_unavailable",
  "unknown phone registry row fails native")

local wallCustom = freshState("Gen2MapRadio", "station")
wallCustom.draw = function() end
local _, wallCustomCode = MapRadio.extract(wallCustom)
check(wallCustomCode == "custom_draw",
  "custom wall-radio draw override stays native")
local wallBattle = freshState("Gen2MapRadio", "station")
local _, wallBattleCode = MapRadio.extract(wallBattle, { battleActive=true })
check(wallBattleCode == "battle_owned",
  "wall radio over battle remains wholly native")
local wallMalformed = freshState("Gen2MapRadio", "station")
wallMalformed.radio.bottom = 12
local _, wallMalformedCode = MapRadio.extract(wallMalformed)
check(wallMalformedCode == "map_radio_shape",
  "malformed wall-radio state fails native")
local wallGearMalformed = freshState("Gen2MapRadio", "station")
wallGearMalformed.gear.station = 0
local _, wallGearMalformedCode = MapRadio.extract(wallGearMalformed)
check(wallGearMalformedCode == "gear_shape",
  "malformed nested wall-radio gear fails native")

check(PokegearPresenter.convert({ screenId="Gen2Pokegear", view="future" })
    == nil,
  "unknown Pokegear presenter view fails open")
check(MapRadioPresenter.convert({ screenId="Gen2MapRadio", view="future" })
    == nil,
  "unknown wall-radio presenter view fails open")

local registeredAdapters, registeredPresenters = {}, {}
local fakeProvider = {
  registerModelAdapter=function(_, id, adapter)
    registeredAdapters[id] = adapter
    return true
  end,
  registerPresenter=function(_, id, presenter)
    registeredPresenters[id] = presenter
    return true
  end,
}
check(PokegearPresenter.register(fakeProvider) == true
  and MapRadioPresenter.register(fakeProvider) == true,
  "Pokegear group production presenters register cleanly")
for _, id in ipairs({ "Gen2Pokegear", "Gen2MapRadio" }) do
  check(type(registeredAdapters[id]) == "table"
      and type(registeredPresenters[id]) == "table",
    id .. " registers both adapter and presenter")
end

-- CallerBox intentionally has no product module here. The current host's
-- public exact-class identity seam exposes only TextBox and ChoiceBox; without
-- an exact public class predicate, replacing anonymous CallerBox would be
-- spoofable and therefore cannot safely suppress native drawing.

check(hostileCalls == 0,
  "all Pokegear group extraction and conversion remains behavior-free")
print(("Gen2 Pokegear/MapRadio tests: %d checks passed"):format(checks))
