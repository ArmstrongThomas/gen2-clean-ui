local requireCore = ...
local Copy = requireCore("foundation.copy")

local Bounds = {}
local assetDebug = false

function Bounds.setAssetDebug(enabled)
  assetDebug = enabled == true
end

function Bounds.collect(layout)
  return Copy.deep({
    envelope = layout and layout.outer,
    safeArea = layout and layout.safeArea,
    nodes = layout and layout.nodes or {},
    clips = layout and layout.clipRects or {},
    scroll = layout and layout.scrollRanges or {},
    pointers = layout and layout.hitRegions or {},
    overflow = layout and layout.overflow or {},
  })
end

local function rectangle(value)
  return type(value) == "table"
    and type(value.x) == "number" and type(value.y) == "number"
    and type(value.w) == "number" and type(value.h) == "number"
    and value.w > 0 and value.h > 0
end

local function assetKey(key)
  key = tostring(key):lower()
  return key:find("sprite", 1, true) ~= nil
    or key:find("image", 1, true) ~= nil
    or key:find("asset", 1, true) ~= nil
    or key:find("portrait", 1, true) ~= nil
    or key:find("art", 1, true) ~= nil
    or key:find("preview", 1, true) ~= nil
    or key:find("icon", 1, true) ~= nil
    or key:find("avatar", 1, true) ~= nil
    or key:find("card", 1, true) ~= nil
end

local function visit(G, value, key, mode, seen)
  if type(value) ~= "table" or seen[value] then return end
  seen[value] = true
  if rectangle(value) and (mode == "containers" or assetKey(key)) then
    G.rectangle("line", value.x, value.y, value.w, value.h)
  end
  for childKey, child in pairs(value) do
    visit(G, child, childKey, mode, seen)
  end
end

function Bounds.draw(G, layout, mode)
  if not G or type(G.rectangle) ~= "function" or not layout then return end
  local previous = G.getColor and { G.getColor() } or nil
  if mode == "containers" then
    G.setColor(1, 0.2, 0.9, 1)
  else
    G.setColor(0.1, 0.95, 1, 1)
  end
  visit(G, layout, "layout", mode, {})
  if previous and G.setColor then G.setColor(unpack(previous)) end
end

function Bounds.drawAsset(G, rect)
  if not assetDebug or not G or type(G.rectangle) ~= "function"
      or not rectangle(rect) then return end
  local previous = G.getColor and { G.getColor() } or nil
  G.setColor(0.1, 0.95, 1, 1)
  G.rectangle("line", rect.x, rect.y, rect.w, rect.h)
  if previous and G.setColor then G.setColor(unpack(previous)) end
end

return Bounds

