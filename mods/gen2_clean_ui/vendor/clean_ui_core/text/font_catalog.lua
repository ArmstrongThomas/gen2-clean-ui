local requireCore = ...
local FontPolicy = requireCore("text.font_policy")

local FontCatalog = {}

function FontCatalog.new(graphics, paths)
  local cache = {}
  paths = paths or {}
  local self = {}

  function self:get(policy)
    local family = policy.family or "plain_pixel"
    local size = assert(policy.physicalPx, "physicalPx is required")
    if family == "plain_pixel" and not FontPolicy.validPlainPixelSize(size) then
      return nil, "invalid_plain_pixel_size", "Plain Pixel must use 15px multiples"
    end
    local key = family .. ":" .. size
    if cache[key] then return cache[key] end
    if not graphics or not graphics.newFont then
      return nil, "font_unavailable", "graphics.newFont is unavailable"
    end
    local path = family == "plain_pixel" and paths.plainPixel or paths.system
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

  return self
end

return FontCatalog
