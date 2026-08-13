return function(ctx)
  local Record = ctx.load("contracts.record")

  local function native(id, module, family, opaque, reason)
    return Record.native({
      id = id,
      module = module,
      milestone = "native_by_design",
      family = family,
      opaque = opaque,
      nativeReason = reason,
      gallery = { "native_status" },
    })
  end

  local function deferred(id, module, opaque, reason)
    return Record.deferred({
      id = id,
      module = module,
      milestone = "post_1.0_battle_design",
      family = "battle",
      opaque = opaque,
      nativeReason = reason,
      gallery = { "deferred_status" },
    })
  end

  return {
    deferred("Gen2BattleState", "src.ui.gen2.BattleState", true,
      "Gold battle and every battle-owned child remain native through 1.0"),
    deferred("Gen2BattleTransition", "src.ui.gen2.BattleTransition", false,
      "timed battle transition and world capture are deferred with battle"),
    native("Gen2CardFlip", "src.ui.gen2.CardFlip", "minigames", true,
      "spatial animated minigame"),
    native("Gen2CopyrightSplash", "src.ui.gen2.CopyrightSplash", "cinematics", true,
      "timed boot splash"),
    native("Gen2Credits", "src.ui.gen2.Credits", "cinematics", true,
      "timed credits cinematic"),
    native("Gen2EggHatchAnim", "src.ui.gen2.EggHatchAnim", "cinematics", true,
      "animation-heavy hatch sequence"),
    native("Gen2EvolutionAnim", "src.ui.gen2.EvolutionAnim", "cinematics", true,
      "animation, cancellation, move learning, and mutation are coupled"),
    native("Gen2GameFreakPresents", "src.ui.gen2.GameFreakPresents", "cinematics", true,
      "timed boot cinematic"),
    native("Gen2GoldSilverIntro", "src.ui.gen2.GoldSilverIntro", "cinematics", true,
      "animation-owned intro cinematic"),
    native("Gen2MagnetTrainRide", "src.ui.gen2.MagnetTrainRide", "cinematics", true,
      "timed travel and world animation"),
    native("Gen2OakSpeech", "src.ui.gen2.OakSpeech", "cinematics", true,
      "Oak artwork and parent sequence remain source-owned"),
    native("Gen2SlotMachine", "src.ui.gen2.SlotMachine", "minigames", true,
      "coordinate-driven animated minigame"),
    native("Gen2TitleState", "src.ui.gen2.TitleState", "cinematics", true,
      "title artwork and timing remain native"),
    native("Gen2TradeAnim", "src.ui.gen2.TradeAnim", "cinematics", true,
      "animation-heavy trade sequence"),
    native("Gen2UnownPuzzle", "src.ui.gen2.UnownPuzzle", "minigames", true,
      "direct-manipulation spatial puzzle"),
  }
end

