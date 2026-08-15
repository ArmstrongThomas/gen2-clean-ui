return function()
  local Identity = {}

  local function failure(code, detail)
    return nil, code, detail
  end

  function Identity.defaultClassResolver(record, context)
    local mod = context and context.mod
    if record.kind == "shared" then
      local key = record.uiClass
      local officialClass = mod and mod.ui and key and mod.ui[key]
      if type(officialClass) ~= "table" then
        return nil, "class_unavailable", tostring(key)
      end
      return officialClass
    end
    return nil, "builtin_predicate_required", record.id
  end

  function Identity.validate(state, record, context, officialClass)
    if type(state) ~= "table" then return failure("state_type", "table") end
    local game = context and context.game
    if record.kind == "shared" then
      if rawget(state, "screenId") ~= nil then
        return failure("shared_screen_id", tostring(rawget(state, "screenId")))
      end
      if type(officialClass) ~= "table" then
        return failure("class_unavailable", record.uiClass)
      end
      if getmetatable(state) ~= officialClass then
        return failure("class_override", record.id)
      end
      if record.marker and state[record.marker] ~= true then
        return failure("marker_mismatch", record.marker)
      end
    else
      if rawget(state, "screenId") ~= record.id then
        return failure("screen_id_mismatch", tostring(rawget(state, "screenId")))
      end
      local screenOverrides = game and game.data and game.data.screens
      if type(screenOverrides) == "table" and screenOverrides[record.id] ~= nil then
        return failure("registry_override", record.id)
      end
      if type(officialClass) == "table" then
        if getmetatable(state) ~= officialClass then
          return failure("class_override", record.id)
        end
      elseif officialClass == true then
        -- The v0.1.86 host exposes the exact screen id and source screen
        -- registry, but does not expose the newer mod.ui.isBuiltinScreen
        -- predicate. Keep using that predicate when a newer host provides
        -- it, while allowing the older host's exact-id fallback to work.
        local mod = context and context.mod
        local predicate = mod and mod.ui and mod.ui.isBuiltinScreen
        if type(predicate) == "function" then
          local ok, exact = pcall(predicate, state, record.id)
          if not ok or exact ~= true then
            return failure("class_override", record.id)
          end
        end
      else
        return failure("builtin_predicate_unavailable", record.id)
      end
    end
    if rawget(state, "draw") ~= nil then
      return failure("custom_draw", record.id)
    end
    if (state.isOpaque == true) ~= (record.opaque == true) then
      return failure("opacity_mismatch", record.id)
    end
    return true
  end

  return Identity
end
