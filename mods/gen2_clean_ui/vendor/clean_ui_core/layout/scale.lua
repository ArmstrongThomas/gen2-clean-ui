local requireCore = ...
local Tokens = requireCore("design.tokens")

local Scale = {}

function Scale.resolve(setting, safeArea, preset)
  local fit = math.min(safeArea.w / preset.w, safeArea.h / preset.h)
  local auto = math.sqrt(math.max(1,
    math.min(safeArea.w, safeArea.h) / Tokens.autoScale.referenceShortEdge))
  auto = math.max(Tokens.autoScale.min, math.min(Tokens.autoScale.max, auto))
  local normalized = type(setting) == "string" and setting:lower() or "auto"
  local multiplier = Tokens.uiSizeMultiplier[normalized] or 1
  local target = normalized == "auto" and auto or auto * multiplier
  return math.max(0, math.min(fit, target)), fit, target
end

return Scale

