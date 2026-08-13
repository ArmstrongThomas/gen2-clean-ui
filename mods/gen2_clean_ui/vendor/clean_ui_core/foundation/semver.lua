local requireCore = ...

local Semver = {}

local function parse(value)
  if type(value) ~= "string" then return nil end
  local a, b, c = value:match("^[vV]?(%d+)[.](%d+)[.](%d+)")
  if not a then return nil end
  return { tonumber(a), tonumber(b), tonumber(c) }
end

function Semver.compare(a, b)
  local av, bv = parse(a), parse(b)
  if not av or not bv then return nil end
  for i = 1, 3 do
    if av[i] < bv[i] then return -1 end
    if av[i] > bv[i] then return 1 end
  end
  return 0
end

function Semver.atLeast(value, minimum)
  local comparison = Semver.compare(value, minimum)
  return comparison ~= nil and comparison >= 0
end

return Semver

