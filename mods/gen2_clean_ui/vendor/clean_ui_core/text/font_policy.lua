local requireCore = ...

local FontPolicy = {}
local BASE_BY_FAMILY = {
  plain_pixel = 15,
  system = 15,
  openttd_mono = 10,
}

local LABEL_BY_FAMILY = {
  plain_pixel = "PLAIN PIXEL",
  system = "SYSTEM",
  openttd_mono = "OPENTTD MONO",
}

local DEFAULT_FAMILY = "openttd_mono"
local PUBLIC_MAX_STEP = 3
local INTERNAL_MAX_STEP = 4

local function normalizeFamily(family)
  family = tostring(family or DEFAULT_FAMILY)
  return BASE_BY_FAMILY[family] and family or DEFAULT_FAMILY
end

local function clampStep(value, maximum)
  value = math.floor(tonumber(value) or 1)
  return math.max(1, math.min(maximum or INTERNAL_MAX_STEP, value))
end

function FontPolicy.normalizeFamily(family)
  return normalizeFamily(family)
end

function FontPolicy.baseSize(family)
  return BASE_BY_FAMILY[normalizeFamily(family)]
end

function FontPolicy.label(family)
  return LABEL_BY_FAMILY[normalizeFamily(family)]
end

function FontPolicy.candidates(setting, panelScale, family)
  family = normalizeFamily(family)
  local maximum
  if setting == "auto" or setting == nil then
    -- Four times remains a valid internal size for authored display styles,
    -- but is intentionally not selected by the public AUTO setting.
    maximum = clampStep(math.floor((tonumber(panelScale) or 1) + 0.5),
      PUBLIC_MAX_STEP)
  else
    local value = tonumber(setting)
      or tonumber(tostring(setting):match("%d+")) or 1
    maximum = clampStep(value, INTERNAL_MAX_STEP)
  end
  local out = {}
  for step = maximum, 1, -1 do
    out[#out + 1] = {
      family = family,
      step = step,
      physicalPx = BASE_BY_FAMILY[family] * step,
    }
  end
  return out
end

function FontPolicy.systemEquivalent(step)
  step = clampStep(step, INTERNAL_MAX_STEP)
  return { family = "system", step = step,
    physicalPx = BASE_BY_FAMILY.system * step }
end

function FontPolicy.validSize(family, size)
  family = normalizeFamily(family)
  size = tonumber(size)
  if not size then return false end
  for step = 1, INTERNAL_MAX_STEP do
    if size == BASE_BY_FAMILY[family] * step then return true end
  end
  return false
end

function FontPolicy.validPlainPixelSize(size)
  return FontPolicy.validSize("plain_pixel", size)
end

return FontPolicy
