return function(ctx)
  local V = ctx.load("contracts.validators")
  local Record = {}
  local SUPPORT = { supported = true, native = true, deferred = true }

  function Record.new(spec)
    assert(type(spec) == "table", "contract record must be a table")
    assert(type(spec.id) == "string" and spec.id:match("^Gen2"),
      "contract record needs an exact Gen2 id")
    assert(type(spec.module) == "string", spec.id .. " needs an official module")
    assert(SUPPORT[spec.support], spec.id .. " has invalid support metadata")
    assert(type(spec.opaque) == "boolean", spec.id .. " needs opacity metadata")
    assert(type(spec.family) == "string", spec.id .. " needs a family")
    assert(type(spec.milestone) == "string", spec.id .. " needs a milestone")

    spec.generation = 2
    spec.implementation = spec.implementation
      or (spec.support == "supported" and "pending_presenter" or "native")
    spec.gallery = spec.gallery or { "status" }
    spec.validateBase = spec.validateBase or V.unimplemented
    spec.validateMode = spec.validateMode or function() return true end
    return spec
  end

  function Record.native(spec)
    spec.support = "native"
    spec.preset = nil
    spec.validateBase = V.native(spec.nativeReason or "native by design")
    return Record.new(spec)
  end

  function Record.deferred(spec)
    spec.support = "deferred"
    spec.preset = nil
    spec.validateBase = V.deferred(spec.nativeReason or "deferred")
    return Record.new(spec)
  end

  return Record
end

