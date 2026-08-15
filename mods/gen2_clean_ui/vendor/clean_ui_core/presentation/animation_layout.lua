local requireCore = ...
local Rect = requireCore("geometry.rect")

local AnimationLayout = {}

local function inset(rect, amount)
  return Rect.inset(rect, { x=amount, y=amount })
end

function AnimationLayout.measure(base, model, font, density)
  local scale = base.scale or 1
  local compact = density == "compact"
  local animation = model.animation or {}
  if animation.overlay == true then
    -- Overlay animations deliberately cover the whole viewport while leaving
    -- the source-owned underlay visible.  This is the V3 seam for timed
    -- source-owned Gen II wipe; it must not invent a
    -- centered paper panel over the world that the transition is decorating.
    local stage = base.viewport or base.outer
    local empty = Rect.new(stage.x, stage.y, 0, 0)
    base.inner, base.field, base.stage = stage, stage, stage
    base.panel, base.caption, base.progress = stage, empty, empty
    base.hitRegions = {}
    base.scale, base.fontHeight = scale, math.max(1, font:getHeight())
    base.gap, base.overlay = 0, true
    base.animationId = animation.id
    return base
  end
  local frame = math.max(2, math.floor(2 * scale + 0.5))
  local pad = math.max(8, math.floor((compact and 10 or 14) * scale))
  local gap = math.max(6, math.floor(8 * scale + 0.5))
  local fontHeight = math.max(1, font:getHeight())
  local inner = inset(base.outer, frame + pad)
  local captionHeight = math.max(fontHeight + pad,
    math.floor(34 * scale + 0.5))
  local progressHeight = math.max(4, math.floor(7 * scale + 0.5))
  local stageHeight = math.max(1, inner.h - captionHeight - gap)
  local stage = Rect.new(inner.x, inner.y, inner.w, stageHeight)
  local caption = Rect.new(inner.x, stage.y + stage.h + gap,
    inner.w, math.max(1, inner.h - stage.h - gap))
  local progress = Rect.new(caption.x + pad,
    caption.y + caption.h - pad - progressHeight,
    math.max(1, caption.w - pad * 2), progressHeight)

  base.inner, base.field, base.stage = inner, stage, stage
  base.panel, base.caption, base.progress = caption, caption, progress
  base.hitRegions = {}
  base.scale, base.fontHeight, base.gap = scale, fontHeight, gap
  base.animationId = model.animation.id
  return base
end

return AnimationLayout
