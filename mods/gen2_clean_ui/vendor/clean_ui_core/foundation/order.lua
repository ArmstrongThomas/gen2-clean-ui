local requireCore = ...

local Order = {}

function Order.keys(input)
  local keys = {}
  for key in pairs(input or {}) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end

function Order.contributions(input)
  local out = {}
  for i, value in ipairs(input or {}) do out[i] = value end
  table.sort(out, function(a, b)
    local ap, bp = tonumber(a.priority) or 0, tonumber(b.priority) or 0
    if ap ~= bp then return ap < bp end
    for _, key in ipairs({ "ownerId", "contractId", "id" }) do
      local av, bv = tostring(a[key] or ""), tostring(b[key] or "")
      if av ~= bv then return av < bv end
    end
    return false
  end)
  return out
end

return Order

