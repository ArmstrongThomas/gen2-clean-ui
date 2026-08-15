return function(ctx)
  local Catalog = {}

  local OFFICIAL_ORDER = {
    "Gen2BankOfMom",
    "Gen2BattleState",
    "Gen2BattleTransition",
    "Gen2BoxMenu",
    "Gen2CardFlip",
    "Gen2CenterPcMenu",
    "Gen2ContestMenu",
    "Gen2CopyrightSplash",
    "Gen2Credits",
    "Gen2DayCareMenu",
    "Gen2DecorationMenu",
    "Gen2Diploma",
    "Gen2EggHatchAnim",
    "Gen2ElevatorMenu",
    "Gen2EvolutionAnim",
    "Gen2GameFreakPresents",
    "Gen2GoldSilverIntro",
    "Gen2HallOfFame",
    "Gen2HeldItemMenu",
    "Gen2InitClock",
    "Gen2ItemPcMenu",
    "Gen2MagnetTrainRide",
    "Gen2MailCompose",
    "Gen2MailMenu",
    "Gen2MailRead",
    "Gen2MailboxMenu",
    "Gen2MapRadio",
    "Gen2MainMenu",
    "Gen2MartMenu",
    "Gen2MoveDeleter",
    "Gen2NamePick",
    "Gen2NamingScreen",
    "Gen2OakSpeech",
    "Gen2OptionsMenu",
    "Gen2PackMenu",
    "Gen2PartyMenu",
    "Gen2PcMenu",
    "Gen2PhotoStudio",
    "Gen2PokedexMenu",
    "Gen2Pokegear",
    "Gen2SaveMenu",
    "Gen2ScriptMenu",
    "Gen2SlotMachine",
    "Gen2StartMenu",
    "Gen2SummaryMenu",
    "Gen2TitleState",
    "Gen2TradeAnim",
    "Gen2TradeMenu",
    "Gen2TrainerCard",
    "Gen2UnownPrinter",
    "Gen2UnownPuzzle",
  }

  local FAMILY_MODULES = {
    "contracts.families.foundation",
    "contracts.families.gameplay",
    "contracts.families.services",
    "contracts.families.native",
  }

  local function copy(values)
    local result = {}
    for index, value in ipairs(values) do result[index] = value end
    return result
  end

  function Catalog.expectedOfficialIds()
    return copy(OFFICIAL_ORDER)
  end

  function Catalog.build()
    local unordered = {}
    for _, moduleName in ipairs(FAMILY_MODULES) do
      for _, record in ipairs(ctx.load(moduleName)) do
        assert(unordered[record.id] == nil, "duplicate Gen2 contract: " .. record.id)
        unordered[record.id] = record
      end
    end

    local records = {}
    local byId = {}
    for index, id in ipairs(OFFICIAL_ORDER) do
      local record = assert(unordered[id], "missing Gen2 contract: " .. id)
      unordered[id] = nil
      record.officialIndex = index
      records[index] = record
      byId[id] = record
    end
    for id in pairs(unordered) do
      error("unregistered Gen2 contract: " .. id, 0)
    end
    assert(#records == 51, "v0.1.87 Gen2 contract count drifted")

    return {
      version = "gen2-v0.1.87",
      hostTag = "v0.1.87",
      -- This drop follows the released host floor rather than pinning a
      -- mutable source checkout commit. The launcher release is the public
      -- compatibility authority for this drop-in mod.
      hostCommit = nil,
      records = records,
      byId = byId,
      officialIds = copy(OFFICIAL_ORDER),
      count = #records,
    }
  end

  return Catalog
end
