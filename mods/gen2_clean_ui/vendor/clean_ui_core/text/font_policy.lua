local requireCore = ...

local FontPolicy = {}
local BASE = 15

local function clampStep(value)
  value = math.floor(tonumber(value) or 1)
  return math.max(1, math.min(4, value))
end

function FontPolicy.candidates(setting, panelScale)
  local maximum
  if setting == "auto" or setting == nil then
    maximum = clampStep(math.floor((tonumber(panelScale) or 1) + 0.5))
  else
    maximum = clampStep(tonumber(setting) or tonumber(tostring(setting):match("%d+")))
  end
  local out = {}
  for step = maximum, 1, -1 do
    out[#out + 1] = { family = "plain_pixel", step = step, physicalPx = BASE * step }
  end
  return out
end

function FontPolicy.systemEquivalent(step)
  step = clampStep(step)
  return { family = "system", step = step, physicalPx = BASE * step }
end

function FontPolicy.validPlainPixelSize(size)
  return size == 15 or size == 30 or size == 45 or size == 60
end

return FontPolicy

