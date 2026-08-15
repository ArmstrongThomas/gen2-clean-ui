return function()
  local SourceInput = {}

  local function contains(rect, x, y)
    return type(rect) == "table" and type(x) == "number" and type(y) == "number"
      and x >= rect.x and y >= rect.y
      and x < rect.x + rect.w and y < rect.y + rect.h
  end

  local function hit(layout, event)
    if type(event) ~= "table" then return nil end
    for index = #(layout and layout.hitRegions or {}), 1, -1 do
      local region = layout.hitRegions[index]
      if contains(region.rect, event.x, event.y) then return region end
    end
  end

  local function ensureVisible(state)
    local list = rawget(state, "list")
    if type(list) == "table" and type(list.ensureVisible) == "function" then
      list:ensureVisible()
    elseif type(state.ensureVisible) == "function" then
      state:ensureVisible()
    end
  end

  local function select(state, screenId, region)
    if screenId == "Gen2BattleState" and region.role == "battle_advance" then
      return true
    end
    if screenId == "Gen2BattleState" and region.role == "battle_action" then
      local index = tonumber(region.sourceIndex) or region.index
      local phase = rawget(state, "phase")
      if phase == "menu" then
        state.menuIndex = index
      elseif phase == "moves" then
        state.moveIndex = index
      elseif phase == "choose-forget" then
        state.forgetIndex = index
      elseif phase == "ask-nickname" then
        state.nicknameIndex = index
      elseif phase == "ask-shift" then
        state.shiftIndex = index
      elseif phase == "ask-forget" or phase == "stop-learning" then
        state.forgetChoice = index
      elseif phase == "ask-next-mon" then
        state.nextMonIndex = index
      end
      return true
    end
    if screenId == nil and region.role == "choice_option"
        and rawget(state, "index") ~= nil then
      local sourceIndex = tonumber(region.sourceIndex) or region.index
      if sourceIndex ~= 1 and sourceIndex ~= 2 then return false end
      state.index = sourceIndex
      return true
    end
    if screenId == nil and region.role == "dialogue_advance" then
      return true
    end
    if region.role == "modal_option" and screenId == "Gen2StartMenu" then
      state.confirmChoice = region.index
      return true
    end
    if screenId == "Gen2Pokegear" and region.role == "map_marker" then
      state.mapCursor = tonumber(region.sourceIndex) or region.index
      return true
    end
    if region.role ~= "menu_row" then return false end
    local sourceIndex = tonumber(region.sourceIndex) or region.index
    if screenId == "Gen2OptionsMenu" then
      state.index = sourceIndex
    else
      local list = rawget(state, "list")
      if type(list) ~= "table" then return false end
      list.index = sourceIndex
    end
    ensureVisible(state)
    return true
  end

  local function tap(provider, game, button)
    local input = provider.mod and provider.mod.input
    if not (input and type(input.tap) == "function") then return false end
    local ok = pcall(input.tap, input, game, button)
    return ok
  end

  local function isSharedPresentation(model)
    return type(model) == "table"
      and (model.kind == "dialogue" or model.kind == "choice")
  end

  local function sourceAcceptsSharedInput(state, model)
    if type(model) ~= "table" then return false end
    if model.kind == "choice" then
      return rawget(state, "pending") == nil
    end
    if model.kind ~= "dialogue" then return false end
    local holdFrames = tonumber(rawget(state, "holdFrames")) or 0
    if holdFrames > 0 then return false end
    if rawget(state, "waiting") == true then
      return (tonumber(rawget(state, "preWait")) or 0) <= 0
    end
    return rawget(state, "done") == true
      and rawget(state, "choice") == nil
      and rawget(state, "auto") == nil
      and rawget(state, "stay") == nil
  end

  function SourceInput.pointer(provider, state, model, layout, event, game)
    if type(state) ~= "table" or type(event) ~= "table" then return false end
    local pointerId = tostring(event.source or "pointer") .. ":"
      .. tostring(event.id or event.button or "primary")
    local region = hit(layout, event)
    if event.phase == "pressed" then
      local existing = provider.pointerPress[pointerId]
      if existing and existing.pressEvent == event then
        -- The presentation runtime offers the same press to lower stack
        -- entries when this shared overlay deliberately leaves it
        -- unconsumed until release. Never let the parent steal that press.
        return false
      elseif existing then
        -- A release can be lost on focus/hook teardown. A fresh event with
        -- the same pointer id safely retires that stale gesture.
        provider.pointerPress[pointerId] = nil
      end
      local shared = isSharedPresentation(model)
      local actionable = region ~= nil
        and (not shared or sourceAcceptsSharedInput(state, model))
        and select(state, rawget(state, "screenId"), region)
      if not actionable and not shared then return false end
      provider.pointerPress[pointerId] = {
        state = state,
        role = actionable and region.role or "shared_blocked",
        index = actionable and region.index or nil,
        sourceIndex = actionable and region.sourceIndex or nil,
        pressEvent = event,
      }
      -- The core invalidates a prepared frame after a consumed pointer
      -- action. Shared overlays commit on release, so consuming the press
      -- would make a fast press+release in one event poll lose its release.
      -- Selection is still source-owned; only the final A edge is deferred.
      return not shared
    end
    if event.phase == "cancelled" then
      provider.pointerPress[pointerId] = nil
      return false
    end
    if event.phase ~= "released" then return false end
    local pressed = provider.pointerPress[pointerId]
    provider.pointerPress[pointerId] = nil
    if pressed and pressed.role == "shared_blocked" then
      return pressed.state == state
    end
    local shared = isSharedPresentation(model)
    if not pressed or pressed.state ~= state or not region
        or pressed.role ~= region.role or pressed.index ~= region.index
        or pressed.sourceIndex ~= region.sourceIndex then
      return shared and pressed ~= nil
    end
    if shared and not sourceAcceptsSharedInput(state, model) then return true end
    if not select(state, rawget(state, "screenId"), region) then
      return shared
    end
    return tap(provider, game, "a")
  end

  function SourceInput.wheel(provider, state, model, _, event, game)
    local delta = type(event) == "table" and tonumber(event.y) or 0
    if not delta or delta == 0 then return false end
    if type(model) == "table" and model.kind == "dialogue" then
      return true
    end
    if type(model) == "table" and model.kind == "choice"
        and not sourceAcceptsSharedInput(state, model) then
      return true
    end
    if rawget(state, "screenId") == nil and rawget(state, "index") ~= nil then
      return tap(provider, game, delta > 0 and "up" or "down")
    end
    if rawget(state, "screenId") == "Gen2StartMenu"
        and rawget(state, "phase") == "confirm" then
      return tap(provider, game, delta > 0 and "up" or "down")
    end
    return tap(provider, game, delta > 0 and "up" or "down")
  end

  return SourceInput
end
