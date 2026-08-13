return function()
  local V = {}

  function V.fail(code, detail)
    return nil, code, detail
  end

  function V.isFinite(value)
    return type(value) == "number"
      and value == value
      and value ~= math.huge
      and value ~= -math.huge
  end

  function V.isInteger(value)
    return V.isFinite(value) and value == math.floor(value)
  end

  function V.type(value, expected, field)
    if type(value) ~= expected then
      return V.fail("shape_type", (field or "value") .. ":" .. expected)
    end
    return true
  end

  function V.optionalType(value, expected, field)
    if value == nil then return true end
    return V.type(value, expected, field)
  end

  function V.fields(value, fields)
    if type(value) ~= "table" then return V.fail("shape_type", "state:table") end
    for field, expected in pairs(fields) do
      local actual = value[field]
      if type(expected) == "table" then
        local matched = false
        for _, candidate in ipairs(expected) do
          if candidate == "nil" and actual == nil then matched = true end
          if candidate ~= "nil" and type(actual) == candidate then matched = true end
        end
        if not matched then return V.fail("shape_type", field) end
      elseif type(actual) ~= expected then
        return V.fail("shape_type", field .. ":" .. expected)
      end
    end
    return true
  end

  function V.array(value, field, minimum, itemValidator)
    if type(value) ~= "table" then return V.fail("shape_type", field .. ":array") end
    local count = #value
    if count < (minimum or 0) then return V.fail("shape_range", field) end
    for index = 1, count do
      if rawget(value, index) == nil then return V.fail("shape_array", field) end
    end
    for key in pairs(value) do
      if type(key) == "number" and (not V.isInteger(key) or key < 1 or key > count) then
        return V.fail("shape_array", field)
      end
    end
    if itemValidator then
      for index, item in ipairs(value) do
        local ok, code, detail = itemValidator(item, index)
        if not ok then
          return nil, code or "shape_item", detail or (field .. "[" .. index .. "]")
        end
      end
    end
    return true
  end

  function V.integer(value, field, minimum, maximum)
    if not V.isInteger(value) then return V.fail("shape_type", field .. ":integer") end
    if minimum ~= nil and value < minimum then return V.fail("shape_range", field) end
    if maximum ~= nil and value > maximum then return V.fail("shape_range", field) end
    return true
  end

  function V.number(value, field, minimum, maximum)
    if not V.isFinite(value) then return V.fail("shape_type", field .. ":number") end
    if minimum ~= nil and value < minimum then return V.fail("shape_range", field) end
    if maximum ~= nil and value > maximum then return V.fail("shape_range", field) end
    return true
  end

  function V.enum(value, field, allowed, allowNil)
    if value == nil and allowNil then return true end
    for _, candidate in ipairs(allowed) do
      if value == candidate then return true end
    end
    return V.fail("unknown_mode", field .. "=" .. tostring(value))
  end

  function V.index(value, field, count, extra)
    return V.integer(value, field, 1, math.max(1, count + (extra or 0)))
  end

  function V.zeroIndex(value, field, count)
    return V.integer(value, field, 0, math.max(0, count - 1))
  end

  function V.nonNegative(value, field)
    return V.integer(value, field, 0)
  end

  function V.lines(value, field)
    return V.array(value, field or "lines", 1, function(line)
      return V.type(line, "string", field or "line")
    end)
  end

  function V.pages(value, field)
    return V.array(value, field or "pages", 1, function(page)
      return V.lines(page, field or "page")
    end)
  end

  function V.chromeList(value, field)
    field = field or "list"
    local ok, code, detail = V.fields(value, {
      items = "table",
      index = "number",
      scroll = "number",
    })
    if not ok then return nil, code, detail end
    ok, code, detail = V.array(value.items, field .. ".items", 1)
    if not ok then return nil, code, detail end
    ok, code, detail = V.index(value.index, field .. ".index", #value.items)
    if not ok then return nil, code, detail end
    return V.nonNegative(value.scroll, field .. ".scroll")
  end

  function V.pagedMessage(value, field)
    field = field or "message"
    local ok, code, detail = V.fields(value, { pages = "table", page = "number" })
    if not ok then return nil, code, detail end
    ok, code, detail = V.pages(value.pages, field .. ".pages")
    if not ok then return nil, code, detail end
    return V.index(value.page, field .. ".page", #value.pages)
  end

  function V.pagedConfirm(value, field)
    field = field or "confirm"
    local ok, code, detail = V.pagedMessage(value, field)
    if not ok then return nil, code, detail end
    return V.integer(value.choice, field .. ".choice", 1, 2)
  end

  function V.mon(value, field)
    field = field or "mon"
    if type(value) ~= "table" then return V.fail("shape_type", field .. ":table") end
    if value.species ~= nil and type(value.species) ~= "string" then
      return V.fail("shape_type", field .. ".species:string")
    end
    if value.level ~= nil then
      local ok, code, detail = V.integer(value.level, field .. ".level", 1, 100)
      if not ok then return nil, code, detail end
    end
    return true
  end

  function V.optional(value, field, validator)
    if value == nil then return true end
    return validator(value, field)
  end

  function V.compose(...)
    local validators = { ... }
    return function(value, context)
      for _, validator in ipairs(validators) do
        local ok, code, detail = validator(value, context)
        if not ok then return nil, code, detail end
      end
      return true
    end
  end

  function V.unimplemented()
    return V.fail("validator_unimplemented", "contract has no audited validator")
  end

  function V.native(reason)
    return function()
      return V.fail("native_by_design", reason)
    end
  end

  function V.deferred(reason)
    return function()
      return V.fail("deferred", reason)
    end
  end

  return V
end
