local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"),
  "GEN2_CLEAN_UI_ROOT is required")
root = root:gsub("\\", "/")

local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)
local Data = ctx.load("adapters.data")
local Models = ctx.load("presenters.mail_specialty_models")
local Presenters = ctx.load("presenters.mail_specialty_presenters")
local Gallery = ctx.load("presenters.mail_specialty_gallery_models")

local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, ("check %d failed: %s"):format(checks, message))
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

local function descriptor(model, id)
  for _, item in ipairs(model.actionDescriptors or {}) do
    if item.id == id then return item end
  end
end

local function fixture(screenId, variant)
  for _, item in ipairs(Gallery.galleryFixtures()) do
    if item.screenId == screenId and item.variant == variant then return item end
  end
  error("missing fixture " .. screenId .. "." .. variant)
end

local expectedIds = {
  Gen2MailCompose=true, Gen2MailMenu=true, Gen2MailRead=true,
  Gen2MailboxMenu=true, Gen2DecorationMenu=true, Gen2TradeMenu=true,
  Gen2NamePick=true, Gen2InitClock=true, Gen2Diploma=true,
  Gen2PhotoStudio=true, Gen2UnownPrinter=true, Gen2HallOfFame=true,
}

-- Registration remains isolated and additive; integration files do not need
-- to be modified for these modules to prove their complete API surface.
local registeredModels, registeredPresenters = {}, {}
local fakeProvider = {}
function fakeProvider:registerModelAdapter(screenId, adapter)
  check(expectedIds[screenId] == true and type(adapter.extract) == "function",
    "model registration is exact for " .. tostring(screenId))
  registeredModels[screenId] = adapter
  return true
end
function fakeProvider:registerPresenter(screenId, presenter)
  check(expectedIds[screenId] == true and type(presenter.prepare) == "function",
    "presenter registration is exact for " .. tostring(screenId))
  registeredPresenters[screenId] = presenter
  return true
end
check(Models.register(fakeProvider) == true, "all model adapters register")
check(Presenters.register(fakeProvider) == true, "all presenters register")
check(#Models.ids() == 12, "the mail/specialty group has twelve exact IDs")
for screenId in pairs(expectedIds) do
  check(registeredModels[screenId] ~= nil, screenId .. " model registered")
  check(registeredPresenters[screenId] ~= nil, screenId .. " presenter registered")
end

-- Every dedicated Gallery fixture starts from a host-shaped source state,
-- goes through the real adapter, then through the real production converter.
local fixtures = Gallery.galleryFixtures()
check(Gallery.count() == 26 and #fixtures == 26,
  "all twenty-six declared mail/specialty variants are present")
check(Data.isFunctionFree(fixtures), "the Gallery fixture set is data-only")
local keys, ready, native = {}, 0, 0
for _, item in ipairs(fixtures) do
  local key = item.screenId .. "\0" .. item.variant
  check(expectedIds[item.screenId] == true, key .. " uses an exact target ID")
  check(not keys[key], key .. " is unique")
  keys[key] = true
  check(Data.isFunctionFree(item.sourceState), key .. " source state is data-only")
  check(item.sourceState.screenId == item.screenId,
    key .. " source state carries its exact host screen ID")
  local bundle, code, detail = Models.extract(item.screenId, item.sourceState)
  if item.expectedNative then
    native = native + 1
    check(bundle == nil and code == item.nativeCode,
      key .. " remains native for the recorded reason")
    check(item.statusOnly and not item.modelReady and item.model == nil
        and item.presentation == nil,
      key .. " is a native Gallery status fixture")
    local prepared, prepareCode = registeredPresenters[item.screenId]:prepare(
      item.sourceState, {})
    check(prepared == nil and prepareCode == item.nativeCode,
      key .. " production presenter also fails open")
  else
    ready = ready + 1
    check(type(bundle) == "table" and Models.isFunctionFree(bundle, item.screenId),
      key .. " extracts through the production adapter: "
        .. tostring(code) .. " " .. tostring(detail))
    check(deepEqual(bundle.model, item.sourceModel),
      key .. " stores the exact adapter result")
    check(deepEqual(bundle.model, item.model),
      key .. " follows the product Gallery source-model convention")
    local converted, convertCode, convertDetail = Presenters.convert(
      item.screenId, bundle.model)
    check(type(converted) == "table",
      key .. " converts: " .. tostring(convertCode) .. " "
        .. tostring(convertDetail))
    check(deepEqual(converted, item.presentation),
      key .. " stores the exact production presenter result")
    check(converted.kind == "menu" and converted.preset == bundle.model.preset,
      key .. " is a production menu in its stable envelope")
    check(Data.isFunctionFree(converted), key .. " presentation is data-only")
    local prepared, prepareCode, prepareDetail =
      registeredPresenters[item.screenId]:prepare(item.sourceState, {})
    check(type(prepared) == "table" and prepared.complete == true,
      key .. " production prepare succeeds: " .. tostring(prepareCode)
        .. " " .. tostring(prepareDetail))
    check(deepEqual(prepared.model, item.presentation),
      key .. " production prepare uses the same converter")
  end
end
check(ready == 24 and native == 2,
  "twenty-four variants render and two unsafe child scopes remain native")
check(fixture("Gen2TradeMenu", "party_picker").nativeCode == "native_child",
  "the incomplete trade Party picker stays native")
check(fixture("Gen2HallOfFame", "induction_native").nativeCode == "native_scope",
  "Hall induction stays native")

-- Mail Compose is the exact zero-based ten-by-six source grid. B deletes;
-- there is no fabricated cancel action.
local Compose = Models.adapterFor("Gen2MailCompose")
local composeState = fixture("Gen2MailCompose", "compose").sourceState
local compose = assert(Compose.extract(composeState)).model
check(compose.cursor.zeroBased and compose.cursor.row == 0
    and compose.cursor.col == 0 and compose.cursor.value == "A",
  "Mail Compose accepts the host's zero-based origin")
check(compose.keyboard.columns == 10 and compose.keyboard.letterRows == 5,
  "Mail Compose preserves its ten-by-five board plus control strip")
check(descriptor(compose, "entry.delete").input == "b"
    and descriptor(compose, "menu.back") == nil,
  "Mail Compose maps B to delete and exposes no false cancel")
composeState.text = string.rep("\xc3\xa9", 17)
local unicodeCompose = assert(Compose.extract(composeState)).model
check(#unicodeCompose.entry.lines[1] == 32
    and unicodeCompose.entry.lines[2] == "\xc3\xa9",
  "Mail Compose splits multibyte text on character boundaries")
composeState.row, composeState.col = 5, 9
local endTarget = assert(Compose.extract(composeState)).model
check(endTarget.cursor.bottomRow and endTarget.cursor.target == "end",
  "the bottom strip maps columns six through nine to END")

-- Source callbacks are never invoked or copied into snapshots.
local callbackCalls = 0
local function forbidden() callbackCalls = callbackCalls + 1 end
local mailState = fixture("Gen2MailMenu", "actions").sourceState
mailState.message = { pages={{ "SAFE" }}, page=1, onDone=forbidden }
local mailMessage = assert(Models.extract("Gen2MailMenu", mailState)).model
check(callbackCalls == 0 and Data.isFunctionFree(mailMessage),
  "mail extraction neither invokes nor copies a callback")
local readingState = fixture("Gen2MailMenu", "actions").sourceState
readingState.reading = true
check(select(2, Models.extract("Gen2MailMenu", readingState))
    == "native_child",
  "held Mail menu fails open when its read child cannot be proven")
local heldRead = assert(Models.extract("Gen2MailMenu", readingState, {
  game={ stack={ states={ { screenId="Gen2MailMenu" },
    { screenId="Gen2MailRead" } } } },
})).model
check(heldRead.mode == "child_read" and heldRead.child.active,
  "held Mail menu accepts a proven MailRead child")

-- Mailbox proves the exact child before allowing a composed stack. The same
-- source flag with a Party child or no child fails open.
local mailboxState = fixture("Gen2MailboxMenu", "list").sourceState
mailboxState.picking = true
local parent = { screenId="Gen2MailboxMenu" }
local mailReadChild = { screenId="Gen2MailRead" }
local mailboxRead = assert(Models.extract("Gen2MailboxMenu", mailboxState, {
  game={ stack={ states={ parent, mailReadChild } } },
})).model
check(mailboxRead.mode == "child_read"
    and mailboxRead.child.screenId == "Gen2MailRead",
  "Mailbox accepts only a proven MailRead child stack")
local _, childCode = Models.extract("Gen2MailboxMenu", mailboxState, {
  game={ stack={ states={ parent, { screenId="Gen2PartyMenu" } } } },
})
check(childCode == "native_child",
  "Mailbox Party picker keeps the complete stack native")
check(select(2, Models.extract("Gen2MailboxMenu", mailboxState))
    == "native_child",
  "Mailbox fails open when the active child cannot be proven")

-- NPC trade ids are the host's zero-based constants. Party and animation
-- children are never commandeered.
local tradeOffer = fixture("Gen2TradeMenu", "offer").sourceState
local trade = assert(Models.extract("Gen2TradeMenu", tradeOffer)).model
check(trade.tradeId == 0 and trade.offer.gender == "EITHER",
  "NPC trade preserves zero-based id and normalized gender")
tradeOffer.picking = true
check(select(2, Models.extract("Gen2TradeMenu", tradeOffer)) == "native_child",
  "NPC trade Party child remains native")
tradeOffer.picking, tradeOffer.animating = false, true
check(select(2, Models.extract("Gen2TradeMenu", tradeOffer)) == "native_child",
  "Gen2TradeAnim remains native")

-- Generated source paths and palettes are strict, detached, and fail open.
local photoState = fixture("Gen2PhotoStudio", "photo").sourceState
local photo = assert(Models.extract("Gen2PhotoStudio", photoState)).model
check(photo.artwork.path:sub(1, 17) == "assets/generated/"
    and #photo.artwork.palette == 4,
  "Photo Studio uses a safe generated path and four-color palette")
local detached = photo.artwork.palette[2][1]
photoState.palettes.pokemon.TOTODILE.normal[1][1] = 1
check(photo.artwork.palette[2][1] == detached,
  "Photo Studio palette is detached from host state")
local unsafePhoto = fixture("Gen2PhotoStudio", "photo").sourceState
unsafePhoto.pokemon.TOTODILE.spriteFront = "C:\\outside\\totodile.png"
check(select(2, Models.extract("Gen2PhotoStudio", unsafePhoto))
    == "sprite_incomplete",
  "Photo Studio rejects an unsafe Pokemon path")
local paletteLessPhoto = fixture("Gen2PhotoStudio", "photo").sourceState
paletteLessPhoto.palettes.pokemon.TOTODILE = nil
check(select(2, Models.extract("Gen2PhotoStudio", paletteLessPhoto))
    == "palette_incomplete",
  "Photo Studio fails open without its Pokemon palette")

local printerState = fixture("Gen2UnownPrinter", "forms").sourceState
local printer = assert(Models.extract("Gen2UnownPrinter", printerState)).model
check(printer.letter == "D" and printer.artwork.form == "D"
    and printer.artwork.path:sub(1, 17) == "assets/generated/",
  "Unown Printer resolves the selected full-color form safely")
printerState.index = 26
local vacant = assert(Models.extract("Gen2UnownPrinter", printerState)).model
check(vacant.vacant and vacant.artwork == nil,
  "Unown Printer's twenty-seventh slot is intentionally VACANT")
local paletteLessPrinter = fixture("Gen2UnownPrinter", "forms").sourceState
paletteLessPrinter.palettes.pokemon.UNOWN = nil
check(select(2, Models.extract("Gen2UnownPrinter", paletteLessPrinter))
    == "palette_incomplete",
  "Unown Printer fails open without the selected form palette")

local hallState = fixture("Gen2HallOfFame", "viewer").sourceState
local hall = assert(Models.extract("Gen2HallOfFame", hallState)).model
check(hall.mode == "viewer" and hall.artwork.path:sub(1, 17)
    == "assets/generated/" and #hall.artwork.palette == 4,
  "Hall viewer resolves safe color Pokemon art")
hallState.mode, hallState.phase = "induct", "display"
check(select(2, Models.extract("Gen2HallOfFame", hallState)) == "native_scope",
  "Hall induction remains native in every phase")
hallState.mode, hallState.phase = "view", "frontpic"
check(select(2, Models.extract("Gen2HallOfFame", hallState)) == "native_scope",
  "non-viewer Hall animation phases remain native")
local paletteLessHall = fixture("Gen2HallOfFame", "viewer").sourceState
paletteLessHall.palettes.pokemon.TOTODILE = nil
check(select(2, Models.extract("Gen2HallOfFame", paletteLessHall))
    == "palette_incomplete",
  "Hall viewer fails open without its Pokemon palette")

local nameState = fixture("Gen2NamePick", "presets").sourceState
local namePick = assert(Models.extract("Gen2NamePick", nameState)).model
check(namePick.sprite.path == "assets/generated/intro/cal.png"
    and #namePick.sprite.palette == 4,
  "NamePick carries the known generated CAL path and detached palette")
nameState.picColors = nil
check(select(2, Models.extract("Gen2NamePick", nameState))
    == "sprite_palette_missing",
  "NamePick fails open without its detached palette")

-- Clock mode/phase pairs are exact, including Oak's boundary at 10:00.
local responseState = fixture("Gen2InitClock", "clock").sourceState
responseState.phase, responseState.hour = "response", 10
local response = assert(Models.extract("Gen2InitClock", responseState)).model
check(response.question.lines[2] == "I overslept!",
  "10 o'clock uses Oak's overslept response")
responseState.hour = 11
response = assert(Models.extract("Gen2InitClock", responseState)).model
check(response.question.lines[2] == "Yikes! I overslept!",
  "11 o'clock uses Oak's yikes response")
responseState.mode, responseState.phase = "day", "hour"
check(select(2, Models.extract("Gen2InitClock", responseState))
    == "phase_invalid",
  "clock-only phases fail open in day mode")

print(("Gen2 mail/specialty adapters and presenters: %d checks passed")
  :format(checks))
