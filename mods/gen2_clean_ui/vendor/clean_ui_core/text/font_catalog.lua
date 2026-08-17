local requireCore = ...
local FontPolicy = requireCore("text.font_policy")

local FontCatalog = {}
local PATH_KEYS = {
  plain_pixel = "plainPixel",
  system = "system",
  openttd_mono = "openttdMono",
}

function FontCatalog.new(graphics, paths)
  local cache = {}
  local familyAvailability = {}
  local familyResolution = {}
  paths = paths or {}
  local self = {}

  function self:get(policy)
    policy = policy or {}
    local family = FontPolicy.normalizeFamily(policy.family)
    local size = assert(policy.physicalPx, "physicalPx is required")
    if not FontPolicy.validSize(family, size) then
      return nil, "invalid_font_size", "font size is not an allowed 1x-4x step"
    end
    local key = family .. ":" .. size
    if cache[key] then return cache[key] end
    if not graphics or not graphics.newFont then
      return nil, "font_unavailable", "graphics.newFont is unavailable"
    end
    local path = paths[PATH_KEYS[family]]
    if family ~= "system" and not path then
      return nil, "font_asset_missing", "font asset path is not configured"
    end
    local ok, font
    if path then
      ok, font = pcall(graphics.newFont, path, size, "mono", 1)
    else
      ok, font = pcall(graphics.newFont, size)
    end
    if not ok then return nil, "font_create_failed", tostring(font) end
    if font and font.setFilter then pcall(font.setFilter, font, "nearest", "nearest") end
    cache[key] = font
    return font
  end

  local function policyFor(family, step)
    family = FontPolicy.normalizeFamily(family)
    step = math.max(1, math.min(4, math.floor(tonumber(step) or 1)))
    return {
      family = family,
      step = step,
      physicalPx = FontPolicy.baseSize(family) * step,
    }
  end

  local function familyAvailable(family)
    family = FontPolicy.normalizeFamily(family)
    if familyAvailability[family] ~= nil then
      return familyAvailability[family]
    end
    local basePolicy = policyFor(family, 1)
    local font = self:get(basePolicy)
    familyAvailability[family] = font ~= nil
    return familyAvailability[family]
  end

  -- A persisted font choice must not turn a supported screen into a native
  -- fallback merely because the host has not mounted that optional face yet.
  -- Keep the requested family when it is available; otherwise use the
  -- bundled OpenTTD Mono face, then the always-available system face. The
  -- step is preserved while the physical pixel size is recalculated for the
  -- fallback family, so layout and rendering use the same policy.
  function self:resolve(policy)
    if type(policy) ~= "table" then
      return nil, nil, "invalid_font_policy", "font policy is required"
    end
    local requested = FontPolicy.normalizeFamily(policy.family)
    local step = math.max(1, math.min(4, math.floor(
      tonumber(policy.step) or 1)))
    local resolved = familyResolution[requested]
    if resolved == false then
      return nil, nil, "font_unavailable", requested
    end
    if resolved == nil then
      if familyAvailable(requested) then
        resolved = requested
      else
        for _, fallback in ipairs({ "openttd_mono", "system" }) do
          if fallback ~= requested and familyAvailable(fallback) then
            resolved = fallback
            break
          end
        end
      end
      familyResolution[requested] = resolved or false
    end
    if not resolved then
      return nil, nil, "font_unavailable", requested
    end
    local candidate = policyFor(resolved, step)
    local font, code, message = self:get(candidate)
    if not font then
      return nil, nil, code or "font_unavailable", message
    end
    return candidate, font
  end

  local function widthOf(font, value)
    if not font or type(font.getWidth) ~= "function" then return math.huge end
    local ok, width = pcall(font.getWidth, font, tostring(value or ""))
    return ok and tonumber(width) or math.huge
  end

  -- Text is allowed to use a smaller cached face without changing the
  -- screen's authored/base policy.  This is deliberately a per-run helper:
  -- a long footer, name, or translated label must not make every other label
  -- on the screen shrink with it.
  function self:fit(policy, value, maximum, options)
    if type(policy) ~= "table" then return nil, "invalid_font_policy" end
    local text = tostring(value or "")
    local limit = tonumber(maximum)
    if not limit or limit < 0 then limit = math.huge end
    options = type(options) == "table" and options or {}
    local requestedStep = tonumber(options.step)
    if not requestedStep then
      requestedStep = (tonumber(policy.step) or 1)
        + (tonumber(options.stepDelta) or 0)
    end
    requestedStep = math.max(1, math.min(4, math.floor(requestedStep)))
    local resolvedBase, baseFont = self:resolve({
      family=policy.family, step=requestedStep,
    })
    if not resolvedBase or not baseFont then
      return nil, "font_unavailable"
    end
    local selected = nil
    for step = resolvedBase.step, 1, -1 do
      local candidate = policyFor(resolvedBase.family, step)
      local font = self:get(candidate)
      if font then
        local width = widthOf(font, text)
        selected = { policy=candidate, font=font, width=width,
          fits=width <= limit }
        if selected.fits then return selected end
      end
    end
    -- The renderer owns the final ellipsis/truncation policy.  Returning the
    -- smallest face with fits=false keeps that last-resort behavior explicit
    -- without silently handing the screen back to the native UI.
    return selected
  end

  return self
end

return FontCatalog
