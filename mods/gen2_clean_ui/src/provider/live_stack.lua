return function(ctx)
  local StackPolicy = ctx.load("provider.stack_policy")
  local LiveStack = {}

  local function statesFor(game)
    local stack = type(game) == "table" and rawget(game, "stack")
    local states = type(stack) == "table" and rawget(stack, "states")
    return type(states) == "table" and states or nil
  end

  local function enabled(provider, record)
    local options = provider.mod and provider.mod.options
    if options and type(options.get) == "function" then
      local ok, native = pcall(options.get, options,
        "native_" .. tostring(record.toggle or "menus"))
      if not ok or native == true then return false end
    end
    return true
  end

  function LiveStack.visible(provider, game, context)
    local states = statesFor(game)
    if not states or #states == 0 then return {} end
    -- An opaque battle owns the full frame. Lower layers may be the overworld
    -- or the transition that handed control to it, but a battle-owned child
    -- menu above the battle must keep the entire native stack visible.
    local battleIndex
    for index, state in ipairs(states) do
      if type(state) == "table" and rawget(state, "screenId")
          == "Gen2BattleState" then
        battleIndex = index
      end
    end
    if battleIndex then
      if battleIndex ~= #states then return {} end
      local battle = states[battleIndex]
      local record = provider:recordForState(battle, context)
      if not record or record.support ~= "supported"
          or not provider.presenters[record.id]
          or not enabled(provider, record) then
        return {}
      end
      return { battle }
    end
    if StackPolicy.containsBattle(states, context) then return {} end

    -- Hiding only the top opaque state would make StateStack:visibleBase()
    -- reveal its parent. Prove and replace every retained UI state instead;
    -- one unknown, native, overridden, or disabled layer keeps the whole
    -- stack native for this frame.
    local visible = {}
    for index = 1, #states do
      local state = states[index]
      if type(state) ~= "table" or rawget(state, "cleanUiShell") == true then
        return {}
      end
      local record = provider:recordForState(state, context)
      if not record or record.support ~= "supported"
          or not provider.presenters[record.id]
          or not enabled(provider, record) then
        return {}
      end
      visible[#visible + 1] = state
    end
    return visible
  end

  return LiveStack
end
