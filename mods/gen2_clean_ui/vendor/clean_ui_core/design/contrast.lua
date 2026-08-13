local requireCore = ...

local Contrast = {}

local function channel(value)
  value = value / 255
  if value <= 0.04045 then return value / 12.92 end
  return ((value + 0.055) / 1.055) ^ 2.4
end

function Contrast.rgb(hex)
  if type(hex) ~= "string" then return nil end
  local value = hex:gsub("#", "")
  if #value ~= 6 then return nil end
  local r, g, b = tonumber(value:sub(1, 2), 16),
    tonumber(value:sub(3, 4), 16), tonumber(value:sub(5, 6), 16)
  if not r or not g or not b then return nil end
  return { r / 255, g / 255, b / 255, 1 }
end

function Contrast.luminance(hex)
  local rgb = Contrast.rgb(hex)
  if not rgb then return nil end
  return 0.2126 * channel(rgb[1] * 255)
    + 0.7152 * channel(rgb[2] * 255)
    + 0.0722 * channel(rgb[3] * 255)
end

function Contrast.ratio(foreground, background)
  local a, b = Contrast.luminance(foreground), Contrast.luminance(background)
  if not a or not b then return nil end
  local light, dark = math.max(a, b), math.min(a, b)
  return (light + 0.05) / (dark + 0.05)
end

return Contrast

