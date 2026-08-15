return function(ctx)
  local Adapter = ctx.load("adapters.battle")
  local Presenter = {}

  local DETACHED_FRAME_KINDS = {
    move=true, pokeball=true, item=true, ["send-out"]=true,
  }

  function Presenter.prepare(_, state, context)
    local bundle, code, detail = Adapter.extract(state, context)
    if not bundle then
      -- Preserve explicit adapter boundaries (notably `battle_finished`) so
      -- the presentation runtime can release battle ownership deliberately
      -- instead of reducing every extraction failure to an opaque presenter
      -- error.
      return { complete=false, reason=code or "battle_extract_failed",
        detail=detail }
    end
    -- The battle presenter owns only a detached scene frame.  A transient
    -- battler snapshot is safe only when the presentation runtime can latch
    -- the previous complete clean frame; it must never fall through to the
    -- native battle canvas as an animation or state-transition substitute.
    if bundle.model.transient == true then
      return { complete=false,
        reason=bundle.model.transientReason or "battle_snapshot_incomplete" }
    end
    local animation = bundle.model.animation
    if animation and DETACHED_FRAME_KINDS[animation.kind] then
      local frameData = animation.frameData
      local overrides = type(frameData) == "table"
        and frameData.pictureOverrides or nil
      if type(overrides) == "table"
          and (overrides.player ~= nil or overrides.enemy ~= nil) then
        return { complete=false,
          reason="battle_picture_override_unavailable" }
      end
      if type(frameData) ~= "table" or frameData.sourceAvailable ~= true then
        return { complete=false, reason="battle_animation_frame_unavailable" }
      end
    end
    return { complete=true, model=bundle.model, sourceModel=bundle.model }
  end

  function Presenter.register(provider)
    if type(provider) ~= "table" then return nil, "invalid_provider" end
    local ok, code, detail = provider:registerModelAdapter(
      "Gen2BattleState", Adapter)
    if not ok then return nil, code, detail end
    return provider:registerPresenter("Gen2BattleState", Presenter)
  end

  return Presenter
end
