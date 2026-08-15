local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"),
  "GEN2_CLEAN_UI_ROOT is required")
root = root:gsub("\\\\", "/")

local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)
local Battle = ctx.load("adapters.battle")
local Transition = ctx.load("adapters.battle_transition")

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

local Solver = loadCore("layout.solver")
local BattleLayout = loadCore("presentation.battle_layout")
local LiveStack = ctx.load("provider.live_stack")

local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, ("check %d failed: %s"):format(checks, message))
end

local palettes = {
  pokemon = {
    CYNDAQUIL = { normal={{220,120,80},{80,40,24}} },
    PIDGEY = { normal={{220,180,120},{100,60,30}} },
  },
  trainers = {
    PLAYER = {{240,180,120},{120,60,30}},
    BUG_CATCHER = {{220,160,100},{80,40,20}},
  },
}
local stableState = {
  screenId="Gen2BattleState", phase="menu", slideFrame=72,
  showPlayerHud=true, showEnemyHud=true,
  showPlayerTrainer=false, showEnemyTrainer=false,
  shownLevel=13, shownExp=24,
  save={pokedex={caught={PIDGEY=true}}},
  palettes=palettes,
  pokemon={
    CYNDAQUIL={spriteFront="assets/generated/battle/front/cyndaquil.png",
      spriteBack="assets/generated/battle/back/cyndaquil.png"},
    PIDGEY={spriteFront="assets/generated/battle/front/pidgey.png",
      spriteBack="assets/generated/battle/back/pidgey.png"},
  },
  battle={
    wild=true,
    player={species="CYNDAQUIL", nickname="CYNDAQUIL", level=12,
      gender="male", types={"FIRE","GROUND"}, hp=34, maxHp=34,
      moves={{id="TACKLE",name="TACKLE",type="NORMAL",pp=35,maxPp=35}}},
    enemy={species="PIDGEY", name="PIDGEY", level=4, gender="female",
      types={"NORMAL","FLYING"}, hp=18, maxHp=18, status="poison",
      volatile={confuseCount=2}},
  },
}

local bundle, code = Battle.extract(stableState)
check(type(bundle) == "table" and type(bundle.model) == "table",
  "stable battle state produces a detached model: " .. tostring(code))
check(bundle.model.kind == "battle" and bundle.model.preset == "BATTLE",
  "battle model uses the responsive battle preset")
check(bundle.model.schema == "clean_ui.v3.presentation.v1"
    and bundle.model.apiVersion == 3,
  "battle model uses the canonical V3 presentation schema")
check(bundle.model.player.sprite.path:find("cyndaquil", 1, true) ~= nil
    and bundle.model.enemy.sprite.path:find("pidgey", 1, true) ~= nil,
  "battle model carries both detached sprite paths")
check(bundle.model.player.gender == "male"
    and bundle.model.enemy.gender == "female"
    and bundle.model.enemy.caught == true,
  "battle model carries gender and wild dex-caught metadata")
check(bundle.model.player.genderIcon.path
    == "assets/generated/icons/gen2/gender.png"
    and bundle.model.player.genderIcon.crop.x == 0
    and bundle.model.enemy.genderIcon.crop.x == 16,
  "battle model uses the supplied cropped gender sprite sheet")
check(bundle.model.player.level == 13
    and math.abs(bundle.model.player.exp - (24 / 64)) < 0.0001,
  "battle model uses the native shown level and experience-bar progress")
  check(bundle.model.enemy.status == "poison"
    and bundle.model.enemy.confused == true,
  "battle model carries major and volatile status conditions")
check(#bundle.model.player.types == 2
    and bundle.model.player.types[1].label == "FIRE"
    and #bundle.model.enemy.types == 2,
  "battle model carries one or two species types for colored badges")
check(bundle.model.player.expText == "EXP 24/64",
  "battle model exposes the native experience progress fraction")

local trainerState = {}
for key, value in pairs(stableState) do trainerState[key] = value end
trainerState.battle = {}
for key, value in pairs(stableState.battle) do
  trainerState.battle[key] = value
end
trainerState.battle.wild = false
local trainerBundle = assert(Battle.extract(trainerState))
check(trainerBundle.model.enemy.caught == false,
  "trainer battles never show the wild catch marker")

local timingState = {}
for key, value in pairs(stableState) do timingState[key] = value end
timingState.slideFrame = 71
local timingModel = assert(Battle.extract(timingState))
check(timingModel.model.animation and timingModel.model.animation.kind == "intro"
    and timingModel.model.player.hudVisible == false,
  "clean battle owns the intro timing frame")

local trainerIntroState = {}
for key, value in pairs(stableState) do trainerIntroState[key] = value end
trainerIntroState.battle = {}
for key, value in pairs(stableState.battle) do
  trainerIntroState.battle[key] = value
end
trainerIntroState.battle.wild = false
trainerIntroState.battle.trainer = { classId="BUG_CATCHER" }
trainerIntroState.showPlayerTrainer = true
trainerIntroState.showEnemyTrainer = true
trainerIntroState.playerBackPath = "assets/generated/battle/player_back.png"
trainerIntroState.enemyTrainerPath =
  "assets/generated/battle/trainers/bug_catcher.png"
trainerIntroState.trainerSlide = 4
local trainerIntroBundle = assert(Battle.extract(trainerIntroState))
check(trainerIntroBundle.model.playerTrainer
    and trainerIntroBundle.model.playerTrainer.path:find("player_back", 1, true)
    and trainerIntroBundle.model.playerTrainer.palette[2][1] == 240
    and trainerIntroBundle.model.enemyTrainer
    and trainerIntroBundle.model.enemyTrainer.path:find("bug_catcher", 1, true),
  "battle intro carries detached player and opponent trainer art")
check(trainerIntroBundle.model.player.sprite ~= nil
    and trainerIntroBundle.model.enemy.sprite ~= nil,
  "battle intro retains battler data for the send-out hand-off")

local moveState = {}
for key, value in pairs(stableState) do moveState[key] = value end
moveState.phase, moveState.moveIndex = "moves", 2
moveState.battle = {
  player={species="CYNDAQUIL", nickname="CYNDAQUIL", level=12,
    hp=34, maxHp=34, moves={{id="TACKLE",name="TACKLE",
      type="NORMAL",pp=35,maxPp=35,
      description="Scratches with<NEXT>sharp claws."},
      {id="LEER",name="LEER",type="NORMAL",pp=30,maxPp=30}}},
  enemy=stableState.battle.enemy,
}
local moveBundle = assert(Battle.extract(moveState))
check(moveBundle.model.selectedAction == nil
    and moveBundle.model.selectedMove == 2,
  "move selection uses the move cursor instead of the battle cursor")
check(moveBundle.model.actions[1].pp == 35
    and moveBundle.model.actions[1].maxPp == 35
    and moveBundle.model.actions[1].type.label == "NORMAL"
    and moveBundle.model.actions[1].category == "PHYSICAL",
  "move selection carries PP, type, and Generation II category metadata")
check(moveBundle.model.actions[1].description == "Scratches with sharp claws.",
  "move descriptions replace native pagination markers with spaces")

local postActionMessageState = {}
for key, value in pairs(stableState) do postActionMessageState[key] = value end
postActionMessageState.phase = "resolving"
postActionMessageState.message = "The foe used<NEXT>an item!"
local postActionMessageBundle = assert(Battle.extract(postActionMessageState))
check(postActionMessageBundle.model.message == "The foe used an item!",
  "battle messages replace native pagination markers with spaces")

local animationState = {}
for key, value in pairs(stableState) do animationState[key] = value end
animationState.anim = { env={ animId="ANIM_THROW_POKE_BALL", battleTurn=0 },
  frames=4, stopped=false }
local animationBundle = assert(Battle.extract(animationState))
check(animationBundle.model.schema == "clean_ui.v3.presentation.v1"
    and animationBundle.model.apiVersion == 3
    and animationBundle.model.kind == "battle"
    and animationBundle.model.animation.kind == "pokeball"
    and animationBundle.model.animation.label == "POKE BALL",
  "clean battle owns the Poké Ball animation frame")

local frameState = {}
for key, value in pairs(stableState) do frameState[key] = value end
frameState.anims = {
  gfx = {
    tackle = { image="assets/generated/battle/effects/tackle.png", width=64 },
  },
}
frameState.anim = {
  env={ animId="ANIM_TACKLE", battleTurn=1 }, frames=5, stopped=false,
  side="player",
  loaded={{ gfx="tackle", tile=0, tiles=1, battler=false }},
  objects={ oam={{ x=24, y=40, tile=0, attr=0,
    palette="PAL_BATTLE_OB_PLAYER" }} },
  bg={ hidden={ player=false, enemy=false },
    picSize={ player=0, enemy=0 }, slide={ player=0, enemy=0 } },
}
local frameBundle = assert(Battle.extract(frameState))
local frameAnimation = frameBundle.model.animation
check(frameAnimation.kind == "move" and frameAnimation.side == "player"
    and frameAnimation.frameData ~= nil
    and type(frameAnimation.frameData.objects) == "table"
    and #frameAnimation.frameData.objects == 1,
  "battle move animation exposes a detached data-only OAM frame")
check(frameAnimation.frameData.sheets[1].path
    == "assets/generated/battle/effects/tackle.png"
    and frameAnimation.frameData.sheets[1].wide == 8
    and frameAnimation.frameData.objects[1].tile == 0,
  "battle move animation preserves source sheet geometry without callbacks")

local itemAnimationState = {}
for key, value in pairs(stableState) do itemAnimationState[key] = value end
itemAnimationState.anim = { env={ animId="RECOVER", battleTurn=0 },
  frames=3, stopped=false }
local itemAnimationBundle = assert(Battle.extract(itemAnimationState))
check(itemAnimationBundle.model.animation.kind == "item",
  "clean battle owns item recovery animation frames")

local ballAnimationState = {}
for key, value in pairs(stableState) do ballAnimationState[key] = value end
ballAnimationState.anim = { env={ animId="ANIM_THROW_PARK_BALL", battleTurn=0 },
  frames=3, stopped=false }
local ballAnimationBundle = assert(Battle.extract(ballAnimationState))
check(ballAnimationBundle.model.animation.kind == "pokeball",
  "clean battle owns contest/Park Ball throw animation frames")

local forgetState = {}
for key, value in pairs(moveState) do forgetState[key] = value end
forgetState.phase, forgetState.forgetChoice = "ask-forget", 2
local forgetBundle = assert(Battle.extract(forgetState))
check(forgetBundle.model.selectedAction == 2
    and forgetBundle.model.actions[1].id == "yes"
    and forgetBundle.model.actions[2].id == "no",
  "move-learning confirmation keeps the native yes/no choice mapping")

local benchForgetState = {}
for key, value in pairs(moveState) do benchForgetState[key] = value end
benchForgetState.phase, benchForgetState.forgetIndex = "choose-forget", 2
benchForgetState.moveIndex = 1
benchForgetState.pendingLearn = { index=2, moveName="BITE" }
benchForgetState.battle = {
  player=moveState.battle.player,
  enemy=moveState.battle.enemy,
  party={
    [2]={moves={{id="GROWL", name="GROWL", type="NORMAL", pp=40,
      maxPp=40}, {id="TAIL_WHIP", name="TAIL WHIP", type="NORMAL",
      pp=30, maxPp=30}}},
  },
}
local benchForgetBundle = assert(Battle.extract(benchForgetState))
check(benchForgetBundle.model.selectedMove == 2
    and #benchForgetBundle.model.actions == 2
    and benchForgetBundle.model.actions[2].id == "TAIL_WHIP",
  "move learning reads the pending benched participant and forget cursor")

local nextMonState = {}
for key, value in pairs(stableState) do nextMonState[key] = value end
nextMonState.phase, nextMonState.nextMonIndex = "ask-next-mon", 2
local nextMonBundle = assert(Battle.extract(nextMonState))
check(nextMonBundle.model.selectedAction == 2
    and nextMonBundle.model.actions[1].id == "yes"
    and nextMonBundle.model.actions[2].id == "no",
  "battle next-Pokemon confirmation keeps the clean yes/no mapping")

local tutorialState = {}
for key, value in pairs(stableState) do tutorialState[key] = value end
tutorialState.tutorial = true
tutorialState.battle = {}
for key, value in pairs(stableState.battle) do tutorialState.battle[key] = value end
tutorialState.battle.player = nil
local tutorialBundle = assert(Battle.extract(tutorialState))
check(tutorialBundle.model.enemy ~= nil
    and tutorialBundle.model.player ~= nil
    and tutorialBundle.model.player.hudVisible == false
    and tutorialBundle.model.player.sprite == nil,
  "catch tutorial keeps the enemy battle page clean without a player battler")

local messageState = {}
for key, value in pairs(stableState) do messageState[key] = value end
messageState.phase, messageState.message = "resolving", "CYNDAQUIL gained EXP!"
local messageBundle = assert(Battle.extract(messageState))
check(messageBundle.model.message == "CYNDAQUIL gained EXP!",
  "stable level-up and experience messages remain visible in the battle presenter")

for _, phase in ipairs({"intro", "menu", "moves", "locked-in", "resolving",
    "shift-intro", "ask-shift", "ask-next-mon",
    "cant-escape-then-switch", "refuse-shift", "forced-switch",
    "refuse-switch", "refuse-move", "learn-intro", "ask-forget",
    "stop-learning", "choose-forget", "stats-box", "submenu", "evolving"}) do
  local phaseState = {}
  for key, value in pairs(stableState) do phaseState[key] = value end
  phaseState.phase = phase
  if phase == "moves" then
    phaseState.moveIndex = 1
  elseif phase == "ask-shift" then
    phaseState.shiftIndex = 1
  elseif phase == "ask-next-mon" then
    phaseState.nextMonIndex = 1
  elseif phase == "ask-forget" or phase == "stop-learning" then
    phaseState.forgetChoice = 1
  elseif phase == "choose-forget" then
    phaseState.forgetIndex = 1
    phaseState.pendingLearn = { index=1, moveName="BITE" }
    phaseState.battle = {}
    for key, value in pairs(stableState.battle) do
      phaseState.battle[key] = value
    end
    phaseState.battle.party = { [1]=stableState.battle.player }
  elseif phase == "stats-box" then
    phaseState.statsBoxMon = { species="CYNDAQUIL", level=13,
      stats={attack=24, defense=20, speed=26, specialAttack=18,
        specialDefense=18} }
  end
  local phaseBundle = assert(Battle.extract(phaseState))
  check(phaseBundle.model.phase == phase,
    "clean battle owns the " .. phase .. " phase")
  if phase == "stats-box" then
    check(phaseBundle.model.statsBox.stats.specialAttack == 18
        and phaseBundle.model.statsBox.stats.specialDefense == 18,
      "level-up stats preserve both Generation II special stats")
  end
end

local finishedState = {}
for key, value in pairs(stableState) do finishedState[key] = value end
finishedState.phase = "resolving"
finishedState.battle = {}
for key, value in pairs(stableState.battle) do
  finishedState.battle[key] = value
end
finishedState.battle.over = true
local finishedBundle, finishedCode = Battle.extract(finishedState)
check(finishedBundle and finishedBundle.model.phase == "resolving"
    and finishedCode == nil,
  "finishing-hit resolution remains clean while victory and EXP screens drain")

finishedState.phase = "done"
local doneBundle, doneCode = Battle.extract(finishedState)
check(doneBundle == nil and doneCode == "battle_finished",
  "only the completed battle phase releases the clean battle presenter")

local transitionState = {
  screenId="Gen2BattleTransition", phase="outro", style="spin",
  frame=4, step=2, trainer=true, black={ [0]=true, [21]=true },
}
local transitionBundle, transitionCode = Transition.extract(transitionState)
check(transitionBundle and transitionCode == nil
    and transitionBundle.model.kind == "animation"
    and transitionBundle.model.animation.id == "battle.transition"
    and transitionBundle.model.animation.overlay == true
    and #transitionBundle.model.animation.overlays == 2,
  "battle transitions emit canonical transparent V3 overlay frames")

local stackProvider = {
  presenters={Gen2BattleState=true, Gen2BattleTransition=true,
    Gen2PackMenu=true, Gen2PartyMenu=true},
  mod={options={get=function() return false end}},
  recordForState=function(_, state)
    if state and state.screenId == "Gen2BattleState" then
      return {id="Gen2BattleState", support="supported", toggle="battle",
        opaque=true}
    end
    if state and (state.screenId == "Gen2PackMenu"
        or state.screenId == "Gen2PartyMenu") then
      return {id=state.screenId, support="supported", toggle="pokemon",
        opaque=true}
    end
    if state and state.screenId == "Gen2BattleTransition" then
      return {id=state.screenId, support="supported", toggle="battle",
        opaque=false}
    end
    return nil
  end,
}
local battleStackState = {screenId="Gen2BattleState"}
check(#LiveStack.visible(stackProvider,
    {stack={states={battleStackState}}}, {}) == 1,
  "stable battle stack exposes the clean battle presenter")
local overworldBackdrop = {}
local startWithBackdrop = {screenId="Gen2StartMenu"}
stackProvider.presenters.Gen2StartMenu = true
stackProvider.recordForState = function(_, state)
  if state == startWithBackdrop then
    return {id="Gen2StartMenu", support="supported", toggle="menus",
      opaque=false}
  end
  if state and state.screenId == "Gen2BattleState" then
    return {id="Gen2BattleState", support="supported", toggle="battle",
      opaque=true}
  end
  if state and (state.screenId == "Gen2PackMenu"
      or state.screenId == "Gen2PartyMenu") then
    return {id=state.screenId, support="supported", toggle="pokemon",
      opaque=true}
  end
  if state and state.screenId == "Gen2BattleTransition" then
    return {id=state.screenId, support="supported", toggle="battle",
      opaque=false}
  end
  return nil
end
local backdropVisible = LiveStack.visible(stackProvider,
  {stack={states={overworldBackdrop, startWithBackdrop}}}, {})
check(#backdropVisible == 1 and backdropVisible[1] == startWithBackdrop,
  "source-owned overworld backdrop does not block a clean start menu")
for _, childId in ipairs({"Gen2PackMenu", "Gen2PartyMenu"}) do
  local visible = LiveStack.visible(stackProvider,
    {stack={states={battleStackState, {screenId=childId}}}}, {})
  check(#visible == 1 and visible[1].screenId == childId,
    "battle-owned " .. childId .. " routes through the clean child presenter")
end

local transitionVisible = LiveStack.visible(stackProvider,
  {stack={states={ {screenId="Gen2MainMenu"},
    {screenId="Gen2BattleTransition"} }}}, {})
check(#transitionVisible == 1
    and transitionVisible[1].screenId == "Gen2BattleTransition",
  "transparent battle transition routes through the clean V3 overlay")

local moveMeasured = BattleLayout.measure({
  outer={x=0,y=0,w=900,h=600}, scale=1, orientation="landscape",
}, {
  kind="battle", phase="moves", moveList=true,
  actions={{label="TACKLE"},{label="LEER"},{label="BITE"},{label="ROAR"}},
}, { getHeight=function() return 15 end,
  getWidth=function(_, value) return #tostring(value or "") * 8 end },
  "comfortable")
check(moveMeasured.moveList and moveMeasured.menuColumns == 1
    and moveMeasured.moveInfoRegion ~= nil
    and moveMeasured.menu[1].rect.x == moveMeasured.menu[2].rect.x,
  "move selection uses a vertical list with a dedicated detail region")
check(moveMeasured.menu[1].rect.x > moveMeasured.moveInfoRegion.x
    and moveMeasured.menu[1].rect.x + moveMeasured.menu[1].rect.w
      <= moveMeasured.panel.x + moveMeasured.panel.w,
  "move list occupies the right column beside move details")

local function rectKey(rect)
  return table.concat({ rect.x, rect.y, rect.w, rect.h }, ":")
end

local function stableBattleModel(phase)
  local model = { kind="battle", preset="BATTLE", phase=phase,
    actions={
      { id="fight", label="FIGHT", sourceIndex=1 },
      { id="pokemon", label="POKEMON", sourceIndex=2 },
      { id="pack", label="PACK", sourceIndex=3 },
      { id="run", label="RUN", sourceIndex=4 },
    } }
  if phase == "moves" then
    model.moveList = true
    model.actions = {
      { id="scratch", label="SCRATCH", sourceIndex=1 },
      { id="leer", label="LEER", sourceIndex=2 },
      { id="rage", label="RAGE", sourceIndex=3 },
      { id="bite", label="BITE", sourceIndex=4 },
    }
  elseif phase == "resolving" then
    model.actions = {}
    model.message = "A battle message"
  end
  return model
end

local stableEnvelope = {
  outer={x=0,y=0,w=1200,h=800}, scale=1, orientation="landscape",
}
local stableFont = { getHeight=function() return 15 end,
  getWidth=function(_, value) return #tostring(value or "") * 8 end }
local stableMenu = BattleLayout.measure(stableEnvelope,
  stableBattleModel("menu"), stableFont, "comfortable")
local stableMoves = BattleLayout.measure(stableEnvelope,
  stableBattleModel("moves"), stableFont, "comfortable")
local stableMessage = BattleLayout.measure(stableEnvelope,
  stableBattleModel("resolving"), stableFont, "comfortable")
for _, name in ipairs({ "field", "hud", "arena", "panel", "enemyCard",
    "enemySprite", "playerSprite", "playerCard" }) do
  check(rectKey(stableMenu[name]) == rectKey(stableMoves[name])
      and rectKey(stableMenu[name]) == rectKey(stableMessage[name]),
    "battle " .. name .. " stays fixed while menu and move phases open")
end
check(stableMenu.hudStable and stableMoves.hudStable
    and stableMessage.hudStable
    and stableMenu.stablePanelHeight == stableMoves.stablePanelHeight
    and stableMenu.stablePanelHeight == stableMessage.stablePanelHeight,
  "battle phases share one reserved HUD/panel geometry")

local portraitMenu = BattleLayout.measure({
  outer={x=0,y=0,w=360,h=640}, scale=1, orientation="portrait",
}, { kind="battle", phase="menu", actions={
  {label="FIGHT"},{label="POKEMON"},{label="PACK"},{label="RUN"},
} }, { getHeight=function() return 15 end,
  getWidth=function(_, value) return #tostring(value or "") * 8 end },
  "comfortable")
check(portraitMenu.menuColumns == 2
    and portraitMenu.menu[1].rect.x ~= portraitMenu.menu[2].rect.x,
  "portrait battle command menu keeps the native 2x2 grid")

local viewports = {
  { 320, 180 }, { 360, 640 }, { 390, 844 }, { 640, 360 },
  { 768, 1024 }, { 1024, 768 }, { 1280, 720 }, { 1600, 1000 },
  { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
  { 3840, 2160 }, { 5120, 2880 },
}
local uiSizes = { "auto", "small", "medium", "large" }
local textSizes = { "auto", "1", "2", "3", "4" }
local fonts = { "plain_pixel", "system" }
local densities = { "auto", "comfortable", "compact" }

local function inside(outer, rect)
  return rect.x >= outer.x and rect.y >= outer.y
    and rect.x + rect.w <= outer.x + outer.w
    and rect.y + rect.h <= outer.y + outer.h
end

local function overlaps(first, second)
  return first.x < second.x + second.w and second.x < first.x + first.w
    and first.y < second.y + second.h and second.y < first.y + first.h
end

local battleModel = { kind="battle", preset="BATTLE", actions={
  { id="fight", label="FIGHT", sourceIndex=1 },
  { id="pokemon", label="POKEMON", sourceIndex=2 },
  { id="pack", label="PACK", sourceIndex=3 },
  { id="run", label="RUN", sourceIndex=4 },
} }

local function fakeFont(layout)
  local height = layout.font.physicalPx
  local step = height / 15
  return {
    getHeight=function() return height end,
    getWidth=function(_, value) return #tostring(value or "") * 8 * step end,
  }
end

for _, dimensions in ipairs(viewports) do
  local width, height = dimensions[1], dimensions[2]
  local viewport = { x=0, y=0, w=width, h=height }
  local inset = math.max(0, math.floor(math.min(width, height) * 0.03))
  local safeArea = { x=inset, y=inset,
    w=math.max(1, width - inset * 2), h=math.max(1, height - inset * 2) }
  for _, uiSize in ipairs(uiSizes) do
    for _, textSize in ipairs(textSizes) do
      for _, font in ipairs(fonts) do
        for _, density in ipairs(densities) do
          local solved = Solver.solve({ preset="BATTLE", viewport=viewport,
            safeArea=safeArea, uiSize=uiSize, textSize=textSize,
            fontFamily=font, density=density,
            probe=function(envelope, candidateFont, candidateDensity)
              local candidateFontMetrics = {
                getHeight=function() return candidateFont.physicalPx end,
                getWidth=function(_, value)
                  return #tostring(value or "") * candidateFont.physicalPx * 0.55
                end,
              }
              local candidate = BattleLayout.measure(envelope, battleModel,
                candidateFontMetrics, candidateDensity)
              if not inside(candidate.inner, candidate.field)
                  or not inside(candidate.inner, candidate.panel) then
                return false
              end
              local minimumArena = math.max(24 * (envelope.scale or 1),
                candidate.fontHeight + candidate.gap)
              local minimumCard = candidate.fontHeight
                + candidate.gap * 2
              if candidate.arena.h < minimumArena
                  or candidate.enemyCard.h < minimumCard
                  or candidate.playerCard.h < minimumCard
                  or candidate.overlaps.cardSprite then
                return false
              end
              for _, region in ipairs(candidate.hitRegions) do
                if not inside(candidate.panel, region.rect) then return false end
                if region.role == "battle_action"
                    and region.rect.h < candidate.fontHeight then
                  return false
                end
              end
              return true
            end })
          check(solved.ok, ("battle matrix solves at %sx%s"):format(width, height))
          if solved.ok then
            local base = solved.value
            local measured = BattleLayout.measure(base, battleModel,
              fakeFont(base), density)
            local portrait = height > width
            check(measured.orientation == (portrait and "portrait" or "landscape"),
              "battle matrix keeps the viewport orientation")
            check(base.outer.x >= safeArea.x and base.outer.y >= safeArea.y
              and base.outer.x + base.outer.w <= safeArea.x + safeArea.w
              and base.outer.y + base.outer.h <= safeArea.y + safeArea.h,
              "battle envelope stays inside the safe area")
            check(measured.enemySprite.w > 0 and measured.enemySprite.h > 0
              and measured.playerSprite.w > 0 and measured.playerSprite.h > 0,
              "battle matrix reserves both sprite stages")
            check(inside(measured.field, measured.enemyCard)
                and inside(measured.field, measured.playerCard)
                and inside(measured.arena, measured.enemySprite)
                and inside(measured.arena, measured.playerSprite),
              "battle HUD and sprite stages stay in their parent regions")
            check((portrait and measured.enemyCard.y < measured.playerCard.y)
                or ((not portrait) and measured.enemyCard.x
                  < measured.playerCard.x),
              "battle side mapping keeps enemy before player")
            check(measured.enemyCard.x < measured.enemySprite.x
                and measured.playerSprite.x < measured.playerCard.x,
              "battle diagonal keeps enemy card left of its sprite and player sprite left of its card")
            check(measured.enemyCard.y < measured.playerCard.y
                and measured.enemySprite.y < measured.playerSprite.y,
              "battle diagonal keeps enemy row above player row")
            check(not overlaps(measured.enemyCard, measured.playerCard)
                and not overlaps(measured.enemySprite, measured.playerSprite)
                and not measured.overlaps.cardSprite,
              "battle HUD cards and sprites never overlap")
            check(measured.arena.h >= math.max(24 * (base.scale or 1),
                measured.fontHeight + measured.gap),
              "battle matrix preserves a usable arena at every font step")
            for _, region in ipairs(measured.hitRegions) do
              check(region.rect.x >= measured.panel.x
                and region.rect.y >= measured.panel.y
                and region.rect.x + region.rect.w
                  <= measured.panel.x + measured.panel.w
                and region.rect.y + region.rect.h
                  <= measured.panel.y + measured.panel.h,
                ("battle action target stays inside its panel at %sx%s %s/%s/%s/%s"):format(
                  width, height, uiSize, textSize, font, density)
                  .. (" rect=%s+%s panel=%s+%s"):format(
                    tostring(region.rect.y), tostring(region.rect.h),
                    tostring(measured.panel.y), tostring(measured.panel.h)))
            end
          end
        end
      end
    end
  end
end

print(("Gen2 responsive battle matrix: %d checks passed"):format(checks))
