local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"),
  "GEN2_CLEAN_UI_ROOT is required")
root = root:gsub("\\\\", "/")

local Helper = assert(loadfile(root .. "/tests/test_helper.lua"))()
local ctx = Helper.new(root)
local Battle = ctx.load("adapters.battle")

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
      gender="male", hp=34, maxHp=34, moves={{id="TACKLE",name="TACKLE"}}},
    enemy={species="PIDGEY", name="PIDGEY", level=4, gender="female",
      hp=18, maxHp=18, status="poison",
      volatile={confuseCount=2}},
  },
}

local bundle, code = Battle.extract(stableState)
check(type(bundle) == "table" and type(bundle.model) == "table",
  "stable battle state produces a detached model: " .. tostring(code))
check(bundle.model.kind == "battle" and bundle.model.preset == "BATTLE",
  "battle model uses the responsive battle preset")
check(bundle.model.player.sprite.path:find("cyndaquil", 1, true) ~= nil
    and bundle.model.enemy.sprite.path:find("pidgey", 1, true) ~= nil,
  "battle model carries both detached sprite paths")
check(bundle.model.player.gender == "male"
    and bundle.model.enemy.gender == "female"
    and bundle.model.enemy.caught == true,
  "battle model carries gender and wild dex-caught metadata")
check(bundle.model.player.level == 13
    and math.abs(bundle.model.player.exp - (24 / 64)) < 0.0001,
  "battle model uses the native shown level and experience-bar progress")
check(bundle.model.enemy.status == "poison"
    and bundle.model.enemy.confused == true,
  "battle model carries major and volatile status conditions")

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
local timingModel, timingCode = Battle.extract(timingState)
check(timingModel == nil and timingCode == "native_timing_frame",
  "battle stays native during the intro timing frame")

local moveState = {}
for key, value in pairs(stableState) do moveState[key] = value end
moveState.phase, moveState.moveIndex = "moves", 2
moveState.battle = {
  player={species="CYNDAQUIL", nickname="CYNDAQUIL", level=12,
    hp=34, maxHp=34, moves={{id="TACKLE",name="TACKLE"},
      {id="LEER",name="LEER"}}},
  enemy=stableState.battle.enemy,
}
local moveBundle = assert(Battle.extract(moveState))
check(moveBundle.model.selectedAction == nil
    and moveBundle.model.selectedMove == 2,
  "move selection uses the move cursor instead of the battle cursor")

local forgetState = {}
for key, value in pairs(moveState) do forgetState[key] = value end
forgetState.phase, forgetState.forgetChoice = "ask-forget", 2
local forgetBundle = assert(Battle.extract(forgetState))
check(forgetBundle.model.selectedAction == 2
    and forgetBundle.model.actions[1].id == "yes"
    and forgetBundle.model.actions[2].id == "no",
  "move-learning confirmation keeps the native yes/no choice mapping")

local messageState = {}
for key, value in pairs(stableState) do messageState[key] = value end
messageState.phase, messageState.message = "resolving", "CYNDAQUIL gained EXP!"
local messageBundle = assert(Battle.extract(messageState))
check(messageBundle.model.message == "CYNDAQUIL gained EXP!",
  "stable level-up and experience messages remain visible in the battle presenter")

for _, phase in ipairs({"submenu", "evolving", "stats-box", "forced-switch"}) do
  local phaseState = {}
  for key, value in pairs(stableState) do phaseState[key] = value end
  phaseState.phase = phase
  local phaseBundle, phaseCode = Battle.extract(phaseState)
  check(phaseBundle == nil and phaseCode == "native_phase",
    "battle returns the native frame for " .. phase)
end

local finishedState = {}
for key, value in pairs(stableState) do finishedState[key] = value end
finishedState.phase = "ask-nickname"
finishedState.battle = {}
for key, value in pairs(stableState.battle) do
  finishedState.battle[key] = value
end
finishedState.battle.over = true
local finishedBundle, finishedCode = Battle.extract(finishedState)
check(finishedBundle == nil and finishedCode == "battle_finished",
  "post-catch nickname flow remains native after the battle closes")

local stackProvider = {
  presenters={Gen2BattleState=true},
  mod={options={get=function() return false end}},
  recordForState=function(_, state)
    if state and state.screenId == "Gen2BattleState" then
      return {id="Gen2BattleState", support="supported", toggle="battle"}
    end
    return nil
  end,
}
local battleStackState = {screenId="Gen2BattleState"}
check(#LiveStack.visible(stackProvider,
    {stack={states={battleStackState}}}, {}) == 1,
  "stable battle stack exposes the clean battle presenter")
for _, childId in ipairs({"Gen2PackMenu", "Gen2PartyMenu"}) do
  local visible = LiveStack.visible(stackProvider,
    {stack={states={battleStackState, {screenId=childId}}}}, {})
  check(#visible == 0,
    "battle-owned " .. childId .. " keeps the complete native child stack")
end

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
