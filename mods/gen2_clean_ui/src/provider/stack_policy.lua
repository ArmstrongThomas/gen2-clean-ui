return function()
  local StackPolicy = {}

  local BATTLE_IDS = { Gen2BattleTransition = true }

  function StackPolicy.containsBattle(states, context)
    if context and context.battleActive then return true end
    for index, state in ipairs(states or {}) do
      local id = type(state) == "table" and rawget(state, "screenId") or nil
      if BATTLE_IDS[id] or (id == "Gen2BattleState"
          and index < #(states or {})) then
        return true
      end
    end
    return false
  end

  function StackPolicy.assess(states, context, inspect)
    if type(states) ~= "table" then return nil, "stack_unavailable" end

    local proved = {}
    for index, state in ipairs(states) do
      if context and context.isNonUi and context.isNonUi(state) then
        proved[index] = { nativeBackdrop = true }
      else
        local result = inspect(state, context)
        if not result or not result.suppress then
          return nil, (result and result.reason) or "unknown_stack_state",
            result and result.detail
        end
        proved[index] = result
      end
    end
    return proved
  end

  return StackPolicy
end
