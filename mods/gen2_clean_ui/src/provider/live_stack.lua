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

  local function eligible(provider, state, context)
    if type(state) ~= "table" or rawget(state, "cleanUiShell") == true then
      return nil
    end
    local record = provider:recordForState(state, context)
    if not record or record.support ~= "supported"
        or not provider.presenters[record.id]
        or not enabled(provider, record) then
      return nil
    end
    return record
  end

  local function opaque(record, state)
    -- The contract is the source of truth for replacement geometry. Keep the
    -- state fallback for older host builds whose constructors do not expose a
    -- screenId-specific record in every hand-off frame.
    return record and record.opaque == true
      or (type(state) == "table" and rawget(state, "isOpaque") == true)
  end

  function LiveStack.visible(provider, game, context)
    local states = statesFor(game)
    if not states or #states == 0 then return {} end
    -- Battle and battle-owned child stacks are deliberately outside the
    -- active Clean UI product. Leave the complete source-owned stack visible
    -- while the future battle rewrite is deferred.
    if StackPolicy.containsBattle(states, context) then return {} end

    -- Only native/unknown states ABOVE a clean state are unsafe. Native
    -- parents and the source-owned overworld below an opaque clean screen
    -- will never be drawn by StateStack:visibleBase(), and transparent clean
    -- overlays are allowed to sit over those source-owned backdrops. The old
    -- all-or-nothing scan rejected an otherwise valid child whenever a
    -- native parent remained on the stack, which made most production UIs
    -- fall back even though their own V3 presenter was ready.
    local visible = {}
    local index = #states
    local top = states[index]
    local topRecord = eligible(provider, top, context)
    if not topRecord then return {} end
    while index >= 1 do
      local state = states[index]
      local record = eligible(provider, state, context)
      if not record then
        -- Leave the lower source-owned/native portion to the host. It is
        -- safe because every clean state collected above is transparent; an
        -- opaque clean state would already have stopped this walk.
        break
      end
      table.insert(visible, 1, state)
      if opaque(record, state) then break end
      index = index - 1
    end
    return visible
  end

  return LiveStack
end
