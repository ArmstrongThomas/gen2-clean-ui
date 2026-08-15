local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"),
  "GEN2_CLEAN_UI_ROOT is required")
root = root:gsub("\\", "/")

local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)
local Data = ctx.load("adapters.data")
local Catalog = ctx.load("contracts.catalog")
local Shared = ctx.load("contracts.shared")
local Provider = ctx.load("provider.init")
local SharedModels = ctx.load("presenters.shared_models")
local SharedPresenters = ctx.load("presenters.shared_presenters")
local SourceInput = ctx.load("provider.source_input")
local Gallery = ctx.load("gallery.catalog")

local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, ("check %d failed: %s"):format(checks, message))
end

local function glyphs(count)
  local output = {}
  for index = 1, count do output[index] = 0x80 + index end
  return output
end

local catalog, shared = Catalog.build(), Shared.build()
local classes = {}
local function classFor(record)
  local class = classes[record.id]
  if not class then
    class = { isOpaque=record.opaque }
    if record.marker then class[record.marker] = true end
    class.__index = class
    classes[record.id] = class
  end
  return class
end

local nativeDialogue = false
local tapCalls = {}
local mod = {
  options = { get=function(_, key)
    if key == "native_dialogue" then return nativeDialogue end
    return false
  end },
  input = { tap=function(_, game, button)
    tapCalls[#tapCalls + 1] = { game=game, button=button }
  end },
}
local provider = Provider.new({
  catalog=catalog, shared=shared, mod=mod,
  classResolver=function(record) return classFor(record) end,
})
check(SharedModels.register(provider) == true,
  "shared model adapters register")
check(SharedPresenters.register(provider) == true,
  "shared presenters register")

local game = { marker="source-game" }
local textClass = classFor(shared.byId["shared.TextBox"])
local text = setmetatable({
  game=game,
  pages={{ "POK\195\169MON", "READY" }},
  pageIndex=1, lineIndex=2,
  codes=glyphs(5), charIndex=3,
  shown={ glyphs(7), glyphs(3) },
  waiting=false, done=false, blink=0,
  boxTx=0, boxTy=12, boxTw=20, boxTh=6, maxCols=18,
}, textClass)

local inspectedText = provider:inspect(text, { game=game })
check(inspectedText.valid, "exact shared TextBox identity and shape validate")
local textBundle = provider:extractModel(text, { game=game }).presentation
check(textBundle.model.lines[1] == "POK\195\169MON"
  and textBundle.model.lines[2] == "REA",
  "TextBox reconstructs the two source-shown glyph prefixes")
check(textBundle.model.apiVersion == 3
  and textBundle.model.schema == "clean_ui.v3.presentation.v1",
  "TextBox emits the canonical V3 dialogue model")
local revealedState = setmetatable({
  game=game,
  pages={{ "FIRST REVEALED LINE", "SECOND REVEALED LINE", "THIRD" }},
  pageIndex=1, lineIndex=3,
  codes=glyphs(5), charIndex=2,
  shown={ glyphs(19), glyphs(2) },
  waiting=false, done=false, blink=0,
  boxTx=0, boxTy=12, boxTw=20, boxTh=6, maxCols=18,
}, textClass)
local revealedModel = provider:extractModel(revealedState, { game=game }).presentation.model
check(#revealedModel.lines == 3
  and revealedModel.lines[1] == "FIRST REVEALED LINE"
  and revealedModel.lines[3] == "TH",
  "TextBox exposes all revealed page lines while preserving the active prefix")
check(textBundle.model.inputReady == false and textBundle.model.controls == "",
  "typing TextBox does not advertise an input it cannot accept")
check(Data.isFunctionFree(textBundle.model),
  "TextBox model is detached and function-free")

local tokenCtx = Helper.new(root, { mod={ ui={ Font={ split=function(value)
  if value == "<PK><MN>" then
    return { { from=1, to=4 }, { from=5, to=8 } }
  end
  local spans = {}
  for index = 1, #value do spans[index] = { from=index, to=index } end
  return spans
end } } } })
local TokenTextBox = tokenCtx.load("adapters.shared_textbox")
local tokenState = {
  pages={{ "<PK><MN>" }}, pageIndex=1, lineIndex=1,
  charIndex=1, codes=glyphs(2), shown={ glyphs(1) },
  waiting=false, done=false,
}
check(TokenTextBox.extract(tokenState).model.lines[1] == "POK\195\169",
  "one shown <PK> source glyph expands only after its glyph boundary")
tokenState.charIndex, tokenState.shown = 2, { glyphs(2) }
check(TokenTextBox.extract(tokenState).model.lines[1] == "POK\195\169MON",
  "two shown <PK><MN> source glyphs expand to the complete label")

text.waiting, text.preWait = true, 2
local preWait = provider:extractModel(text, { game=game }).presentation.model
check(preWait.more and not preWait.inputReady,
  "TextBox protected pre-wait shows continuation without accepting input")
text.preWait = 0
local waiting = provider:extractModel(text, { game=game }).presentation.model
check(waiting.more and waiting.inputReady
  and waiting.controls == "A/B CONTINUE",
  "TextBox accepts input only after the source pre-wait drains")

local function shallow(source)
  local output = {}
  for key, value in pairs(source) do output[key] = value end
  return setmetatable(output, getmetatable(source))
end

local continuation = shallow(text)
continuation.pages = {{ "GOLD, I want you to have this", "for your errand." }}
continuation.pageIndex, continuation.lineIndex = 1, 1
continuation.shown = { glyphs(27) }
continuation.codes, continuation.charIndex = glyphs(27), 27
continuation.waiting, continuation.contAdvance, continuation.done = true, true, false
local continuationModel = provider:extractModel(continuation,
  { game=game }).presentation.model
check(#continuationModel.lines == 2
  and continuationModel.lines[1] == "GOLD, I want you to have this"
  and continuationModel.lines[2] == "for your errand.",
  "native continuation breaks remain one reflowable Clean UI message")
continuation.waiting, continuation.contAdvance, continuation.lineIndex = false, false, 2
continuation.shown = { glyphs(27), glyphs(1) }
continuation.codes, continuation.charIndex = glyphs(1), 1
local continuedModel = provider:extractModel(continuation,
  { game=game }).presentation.model
check(#continuedModel.lines == 2
  and continuedModel.lines[1] == "GOLD, I want you to have this"
  and continuedModel.lines[2] == "for your errand.",
  "a collapsed continuation remains one stable message while the source catches up")

local noShown = shallow(text)
noShown.shown = {}
check(provider:inspect(noShown, { game=game }).reason == "shape_range",
  "empty source shown buffer fails open")
local mismatchedGlyphs = shallow(text)
mismatchedGlyphs.shown = { glyphs(7), glyphs(2) }
check(provider:inspect(mismatchedGlyphs, { game=game }).reason == "shape_value",
  "charIndex and shown glyph drift fails open")
local customDraw = shallow(text)
customDraw.draw = function() end
check(provider:inspect(customDraw, { game=game }).reason == "custom_draw",
  "instance draw override remains native")
local foreignText = shallow(text)
setmetatable(foreignText, {})
check(provider:inspect(foreignText, { game=game }).reason == "unknown_screen",
  "foreign no-id table cannot impersonate TextBox")

local choiceClass = classFor(shared.byId["shared.ChoiceBox"])
local choice = setmetatable({
  game=game, onChoose=function() end, index=2, noSound=false,
  tx=14, ty=6, tw=6, th=5, anchor="bottom",
}, choiceClass)
local choicePrepared = provider:prepare(choice, { game=game })
check(choicePrepared.suppress
  and choicePrepared.presentation.model.selected == 2
  and choicePrepared.presentation.model.apiVersion == 3
  and choicePrepared.presentation.model.schema == "clean_ui.v3.presentation.v1",
  "ChoiceBox preserves its one-based NO selection")
check(choicePrepared.presentation.model.options[1].sourceIndex == 1
  and choicePrepared.presentation.model.options[2].sourceIndex == 2,
  "ChoiceBox exposes exact one-based source indices")
choice.pending, choice.holdFrames = false, 15
local pendingChoice = provider:prepare(choice, { game=game })
check(pendingChoice.suppress
  and pendingChoice.presentation.model.pending
  and not pendingChoice.presentation.model.inputReady,
  "NO answer remains visible and disabled during the source hold")
choice.pending, choice.holdFrames = nil, nil

local stackGame = { stack={ states={ text, choice } } }
check(#provider:visibleStack(stackGame, { game=game }) == 2,
  "complete TextBox plus ChoiceBox stack is eligible atomically")
nativeDialogue = true
check(#provider:visibleStack(stackGame, { game=game }) == 0,
  "Native Dialogue disables both shared seams")
nativeDialogue = false
stackGame.stack.states = { text, { screenId="Gen2FutureScreen" } }
check(#provider:visibleStack(stackGame, { game=game }) == 0,
  "unknown parent or child keeps the complete stack native")
stackGame.stack.states = {
  { screenId="Gen2BattleState" }, text, choice,
}
check(#provider:visibleStack(stackGame, { game=game }) == 0,
  "battle plus shared children is wholly native")
check(#provider:visibleStack({ stack={ states={ text } } },
  { game=game, battleActive=true }) == 0,
  "explicit battle context vetoes an otherwise valid shared screen")

local sharedGallery = Gallery.build(catalog, shared,
  SharedModels.galleryFixtures())
local expectedGallery = {
  ["gen2.shared.text_box.dialogue"]="dialogue",
  ["gen2.shared.text_box.overflow"]="dialogue",
  ["gen2.shared.choice_box.yes_no"]="choice",
}
local galleryReady = 0
for _, fixture in ipairs(sharedGallery.fixtures) do
  local kind = expectedGallery[fixture.id]
  if kind then
    galleryReady = galleryReady + 1
    check(fixture.modelReady and not fixture.statusOnly,
      "shared Gallery fixture is production-model backed: " .. fixture.id)
    check(fixture.model.kind == kind,
      "shared Gallery fixture uses its production presenter: " .. fixture.id)
  end
end
check(galleryReady == 3, "all shared Gallery fixture IDs are stable and ready")

local inputProvider = { pointerPress={}, mod=mod }
local choiceState = { index=1 }
local choiceModel = { kind="choice" }
local choiceLayout = { hitRegions={
  { role="choice_option", index=1, sourceIndex=1,
    rect={ x=10, y=10, w=100, h=30 } },
  { role="choice_option", index=2, sourceIndex=2,
    rect={ x=10, y=40, w=100, h=30 } },
}, outer={ x=0, y=0, w=120, h=80 } }
local press = { phase="pressed", source="mouse", id="mouse", button=1,
  x=20, y=50 }
check(SourceInput.pointer(inputProvider, choiceState, choiceModel,
  choiceLayout, press, game) == false,
  "shared choice press defers consumption until release")
check(choiceState.index == 2 and #tapCalls == 0,
  "choice press selects exact source row without invoking its callback")

local underlyingText = { waiting=true, preWait=0, done=false }
local textModel = { kind="dialogue" }
local textLayout = { hitRegions={{ role="dialogue_advance", index=1,
  rect={ x=0, y=0, w=200, h=100 } }} }
check(SourceInput.pointer(inputProvider, underlyingText, textModel,
  textLayout, press, game) == false,
  "same press cannot fall through a shared choice to its TextBox parent")
check(inputProvider.pointerPress["mouse:mouse"].state == choiceState,
  "top shared overlay retains pointer ownership")

local release = { phase="released", source="mouse", id="mouse", button=1,
  x=20, y=50 }
check(SourceInput.pointer(inputProvider, choiceState, choiceModel,
  choiceLayout, release, game) == true,
  "same-poll shared release is consumed")
check(#tapCalls == 1 and tapCalls[1].button == "a",
  "release queues one source-owned A edge")

choiceState.index, choiceState.pending = 1, false
local pendingPress = { phase="pressed", source="mouse", id="mouse",
  button=1, x=20, y=50 }
SourceInput.pointer(inputProvider, choiceState, choiceModel,
  choiceLayout, pendingPress, game)
check(choiceState.index == 1,
  "pointer cannot move the source cursor during answer hold")
SourceInput.pointer(inputProvider, choiceState, choiceModel, choiceLayout,
  { phase="released", source="mouse", id="mouse", button=1, x=20, y=50 },
  game)
check(#tapCalls == 1,
  "pointer cannot queue a second answer during source hold")
choiceState.pending = nil

underlyingText.preWait = 3
local waitPress = { phase="pressed", source="touch", id="finger",
  x=20, y=20 }
SourceInput.pointer(inputProvider, underlyingText, textModel,
  textLayout, waitPress, game)
SourceInput.pointer(inputProvider, underlyingText, textModel, textLayout,
  { phase="released", source="touch", id="finger", x=20, y=20 }, game)
check(#tapCalls == 1,
  "protected TextBox pre-wait swallows pointer input like native")
underlyingText.preWait = 0
local readyPress = { phase="pressed", source="touch", id="finger",
  x=20, y=20 }
SourceInput.pointer(inputProvider, underlyingText, textModel,
  textLayout, readyPress, game)
SourceInput.pointer(inputProvider, underlyingText, textModel, textLayout,
  { phase="released", source="touch", id="finger", x=20, y=20 }, game)
check(#tapCalls == 2 and tapCalls[2].button == "a",
  "ready TextBox queues one source-owned continuation edge")

choiceState.index = 1
local invalidLayout = { hitRegions={{ role="choice_option", index=1,
  sourceIndex=0, rect={ x=0, y=0, w=100, h=100 } }} }
local invalidPress = { phase="pressed", source="mouse", id="mouse",
  button=1, x=10, y=10 }
SourceInput.pointer(inputProvider, choiceState, choiceModel,
  invalidLayout, invalidPress, game)
SourceInput.pointer(inputProvider, choiceState, choiceModel, invalidLayout,
  { phase="released", source="mouse", id="mouse", button=1, x=10, y=10 },
  game)
check(choiceState.index == 1 and #tapCalls == 2,
  "invalid zero-based choice geometry cannot mutate or confirm source state")

check(SourceInput.wheel(inputProvider, choiceState, choiceModel, choiceLayout,
  { y=-1 }, game) == true and tapCalls[#tapCalls].button == "down",
  "choice wheel navigation stays source-input owned")
choiceState.pending = true
local beforePendingWheel = #tapCalls
check(SourceInput.wheel(inputProvider, choiceState, choiceModel, choiceLayout,
  { y=1 }, game) == true and #tapCalls == beforePendingWheel,
  "choice hold consumes wheel input without leaking a direction")
check(SourceInput.wheel(inputProvider, underlyingText, textModel, textLayout,
  { y=1 }, game) == true and #tapCalls == beforePendingWheel,
  "TextBox consumes wheel input without inventing dialogue semantics")

print(("Gen2 shared UI tests: %d checks passed"):format(checks))
