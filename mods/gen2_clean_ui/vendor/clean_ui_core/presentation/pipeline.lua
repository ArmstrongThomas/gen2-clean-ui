local requireCore = ...
local Guard = requireCore("foundation.guard")
local Result = requireCore("foundation.result")

local Pipeline = {}

function Pipeline.new(config)
  local self = { provider = assert(config.provider), solver = assert(config.solver),
    sessions = assert(config.sessions), lastGood = {}, lease = nil }

  local function release(reason)
    if self.lease and self.provider.suppression
        and self.provider.suppression.release then
      pcall(self.provider.suppression.release, self.lease, reason)
    end
    self.lease = nil
  end

  function self:prepare(game, render)
    local stack = self.provider.visibleStack(game)
    if type(stack) ~= "table" or #stack == 0 then
      release("empty_stack")
      return Result.err("native_fallback", "no replaceable visible stack")
    end
    local prepared = {}
    for _, screen in ipairs(stack) do
      local id = self.provider.exactScreenId(screen)
      local record = id and self.provider.recordFor(id)
      if not record or record.status ~= "supported" then
        release("unsupported_screen")
        return Result.err("native_fallback", "unsupported exact screen: " .. tostring(id))
      end
      local valid = Guard.call("validator_failed", record.validate, screen)
      if not valid.ok or valid.value ~= true then
        release("invalid_screen")
        return Result.err("native_fallback", "screen contract did not validate")
      end
      local snapshot = Guard.call("snapshot_failed", record.snapshot, screen)
      if not snapshot.ok then release("snapshot_failed") return snapshot end
      local layout = self.solver.solve({
        preset = record.preset, viewport = self.provider.getViewport(game),
        safeArea = self.provider.getSafeArea(game), uiSize = config.uiSize,
        textSize = config.textSize, fontFamily = config.fontFamily,
        density = config.density, probe = record.probe,
      })
      if not layout.ok then release("layout_failed") return layout end
      local token = self.provider.sourceToken(screen)
      local locked = self.sessions:lock(token, layout.value.signature, layout.value)
      local frame = Guard.call("presenter_failed", render, record,
        snapshot.value, locked.value)
      if not frame.ok then release("presenter_failed") return frame end
      prepared[#prepared + 1] = { screen = screen, id = id, frame = frame.value,
        layout = locked.value }
    end
    local proof = self.provider.suppression.prove(stack, prepared)
    if not proof then release("proof_failed")
      return Result.err("native_fallback", "complete-stack proof failed") end
    release("renew")
    self.lease = self.provider.suppression.acquire(proof)
    self.lastGood = prepared
    return Result.ok(prepared)
  end

  function self:restore(reason) release(reason or "restore") end
  return self
end

return Pipeline

