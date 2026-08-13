local requireCore = ...

local Color = {}

function Color.rgba(value, alpha)
  if type(value) == "table" then
    return value[1] or 0, value[2] or 0, value[3] or 0,
      alpha or value[4] or 1
  end
  local hex = type(value) == "string" and value:match("^#(%x%x%x%x%x%x)$")
  if not hex then return 0, 0, 0, alpha or 1 end
  return tonumber(hex:sub(1, 2), 16) / 255,
    tonumber(hex:sub(3, 4), 16) / 255,
    tonumber(hex:sub(5, 6), 16) / 255, alpha or 1
end

function Color.set(graphics, value, alpha)
  graphics.setColor(Color.rgba(value, alpha))
end

return Color
