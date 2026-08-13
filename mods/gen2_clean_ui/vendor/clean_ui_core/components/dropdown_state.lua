local requireCore = ...
local Result = requireCore("foundation.result")

local DropdownState = {}

function DropdownState.closed()
  return {
    phase = "closed", componentId = nil, triggerId = nil,
    activeOptionId = nil, committedValue = nil, scrollOffset = 0,
    pointerId = nil, dragOriginY = nil, dragOriginScroll = nil,
    placement = nil,
  }
end

local function selectable(options)
  local out = {}
  for _, option in ipairs(options or {}) do
    if not option.heading and not option.disabled then out[#out + 1] = option end
  end
  return out
end

local function activeFor(descriptor)
  local choices = selectable(descriptor.options)
  for _, option in ipairs(choices) do
    if option.value == descriptor.value then return option.id end
  end
  return choices[1] and choices[1].id or nil
end

local function copyState(state)
  local out = {}
  for key, value in pairs(state or {}) do out[key] = value end
  return out
end

function DropdownState.reduce(state, event, descriptor)
  state = state or DropdownState.closed()
  descriptor = descriptor or {}
  if event.type == "open" and state.phase == "closed" then
    local nextState = DropdownState.closed()
    nextState.phase = "open"
    nextState.componentId = descriptor.id
    nextState.triggerId = event.triggerId or descriptor.id
    nextState.committedValue = descriptor.value
    nextState.activeOptionId = activeFor(descriptor)
    nextState.placement = event.placement
    return Result.ok({ state = nextState })
  end
  if event.type == "dismiss" or event.type == "cancel" then
    return Result.ok({ state = DropdownState.closed(), restoreFocus = state.triggerId })
  end
  if state.phase == "closed" then return Result.ok({ state = state }) end

  -- Reducers are pure: callers may retain the old state for cancellation,
  -- diagnostics, or deterministic replay.
  state = copyState(state)

  local choices = selectable(descriptor.options)
  if event.type == "move" and #choices > 0 then
    local index = 1
    for i, option in ipairs(choices) do
      if option.id == state.activeOptionId then index = i break end
    end
    local delta = event.delta and (event.delta < 0 and -1 or 1) or 1
    index = ((index - 1 + delta) % #choices) + 1
    state.activeOptionId = choices[index].id
    return Result.ok({ state = state, reveal = state.activeOptionId })
  end
  if event.type == "scroll" then
    local maximum = tonumber(event.maxScroll) or math.huge
    state.scrollOffset = math.min(maximum,
      math.max(0, (state.scrollOffset or 0) + (event.delta or 0)))
    return Result.ok({ state = state })
  end
  if event.type == "activate" then
    local selected
    for _, option in ipairs(choices) do
      if option.id == (event.optionId or state.activeOptionId) then selected = option break end
    end
    if not selected then return Result.ok({ state = state }) end
    return Result.ok({
      state = DropdownState.closed(),
      restoreFocus = state.triggerId,
      action = descriptor.action,
      payload = { componentId = descriptor.id, value = selected.value,
        optionId = selected.id },
    })
  end
  if event.type == "drag_start" then
    state.phase, state.pointerId = "dragging", event.pointerId
    state.dragOriginY, state.dragOriginScroll = event.y, state.scrollOffset
  elseif event.type == "drag_move" and state.phase == "dragging"
      and event.pointerId == state.pointerId then
    state.scrollOffset = math.min(tonumber(event.maxScroll) or math.huge,
      math.max(0, state.dragOriginScroll + state.dragOriginY - event.y))
  elseif event.type == "drag_end" and state.phase == "dragging"
      and event.pointerId == state.pointerId then
    state.phase, state.pointerId = "open", nil
  end
  return Result.ok({ state = state })
end

return DropdownState
