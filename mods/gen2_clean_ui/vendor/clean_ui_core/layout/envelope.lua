local requireCore = ...
local Rect = requireCore("geometry.rect")
local Presets = requireCore("design.presets")
local Scale = requireCore("layout.scale")

local Envelope = {}

function Envelope.measure(presetId, viewport, safeArea, uiSize)
  local preset = Presets[presetId]
  if not preset then return nil, "unknown_preset", tostring(presetId) end
  safeArea = safeArea or viewport
  local scale, fitCap, targetScale = Scale.resolve(uiSize, safeArea, preset)
  if scale <= 0 then return nil, "viewport_too_small", "no safe drawing area" end
  local w, h = math.floor(preset.w * scale), math.floor(preset.h * scale)
  local outer = Rect.round(Rect.new(
    safeArea.x + (safeArea.w - w) / 2,
    safeArea.y + (safeArea.h - h) / 2,
    w, h))
  return {
    preset = presetId,
    logical = { w = preset.w, h = preset.h },
    viewport = Rect.copy(viewport),
    safeArea = Rect.copy(safeArea),
    outer = outer,
    scale = scale,
    fitCap = fitCap,
    targetScale = targetScale,
  }
end

return Envelope

