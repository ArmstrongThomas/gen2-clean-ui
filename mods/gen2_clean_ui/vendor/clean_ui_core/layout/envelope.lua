local requireCore = ...
local Rect = requireCore("geometry.rect")
local Presets = requireCore("design.presets")
local Scale = requireCore("layout.scale")

local Envelope = {}

function Envelope.measure(presetId, viewport, safeArea, uiSize)
  local preset = Presets[presetId]
  if not preset then return nil, "unknown_preset", tostring(presetId) end
  safeArea = safeArea or viewport
  local orientation = "landscape"
  local resolvedPreset = preset
  if safeArea.h > safeArea.w and type(preset.portrait) == "table" then
    orientation = "portrait"
    resolvedPreset = {}
    for key, value in pairs(preset) do
      if key ~= "portrait" then resolvedPreset[key] = value end
    end
    for key, value in pairs(preset.portrait) do
      resolvedPreset[key] = value
    end
  end
  local scale, fitCap, targetScale = Scale.resolve(uiSize, safeArea,
    resolvedPreset)
  if scale <= 0 then return nil, "viewport_too_small", "no safe drawing area" end
  local w, h = math.floor(resolvedPreset.w * scale),
    math.floor(resolvedPreset.h * scale)
  local outer = Rect.round(Rect.new(
    safeArea.x + (safeArea.w - w) / 2,
    safeArea.y + (safeArea.h - h) / 2,
    w, h))
  return {
    preset = presetId,
    logical = { w = resolvedPreset.w, h = resolvedPreset.h },
    minW = resolvedPreset.minW,
    widthMode = resolvedPreset.widthMode,
    viewport = Rect.copy(viewport),
    safeArea = Rect.copy(safeArea),
    outer = outer,
    scale = scale,
    fitCap = fitCap,
    targetScale = targetScale,
    orientation = orientation,
  }
end

function Envelope.withLogicalWidth(envelope, logicalWidth)
  if type(envelope) ~= "table" or type(envelope.logical) ~= "table"
      or type(logicalWidth) ~= "number" then
    return envelope
  end
  local fullWidth = tonumber(envelope.logical.w) or 0
  local width = math.max(1, math.min(fullWidth, logicalWidth))
  if width >= fullWidth then return envelope end
  local physicalWidth = math.max(1, math.floor(width * envelope.scale + 0.5))
  local outer = Rect.round(Rect.new(
    envelope.safeArea.x + (envelope.safeArea.w - physicalWidth) / 2,
    envelope.outer.y, physicalWidth, envelope.outer.h))
  local narrowed = {}
  for key, value in pairs(envelope) do narrowed[key] = value end
  narrowed.logical = { w = width, h = envelope.logical.h }
  narrowed.outer = outer
  return narrowed
end

return Envelope
