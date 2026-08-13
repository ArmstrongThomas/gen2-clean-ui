return function(config)
  if type(config) ~= "table" then
    return nil, { code = "invalid_bootstrap", message = "config is required" }
  end
  if type(config.root) ~= "string" or config.root == "" then
    return nil, { code = "invalid_bootstrap", message = "root is required" }
  end
  if type(config.read) ~= "function" then
    return nil, { code = "invalid_bootstrap", message = "read callback is required" }
  end

  local compile = loadstring or load
  if type(compile) ~= "function" then
    return nil, { code = "compile_unavailable", message = "Lua compiler is unavailable" }
  end

  local function read(relative)
    local source, err = config.read(config.root .. "/" .. relative)
    if type(source) ~= "string" then
      return nil, tostring(err or ("unable to read " .. relative))
    end
    return source
  end

  local manifestSource, manifestError = read("module_manifest.lua")
  if not manifestSource then
    return nil, { code = "module_manifest_missing", message = manifestError }
  end
  local manifestChunk, compileError = compile(manifestSource,
    "@" .. config.root .. "/module_manifest.lua")
  if not manifestChunk then
    return nil, { code = "module_manifest_invalid", message = tostring(compileError) }
  end
  local okManifest, manifest = pcall(manifestChunk)
  if not okManifest or type(manifest) ~= "table"
      or type(manifest.modules) ~= "table" then
    return nil, { code = "module_manifest_invalid", message = tostring(manifest) }
  end

  local cache, loading, stack = {}, {}, {}
  local requireCore

  local function dependencyAllowed(parent, child)
    if not parent then return child == "core" end
    local dependencies = manifest.modules[parent] or {}
    for _, name in ipairs(dependencies) do
      if name == child then return true end
    end
    return false
  end

  requireCore = function(name)
    if type(name) ~= "string" or name == ""
        or name:match("[^a-z0-9_.]")
        or name:match("^[.]") or name:match("[.]$")
        or name:match("[.][.]") then
      error("core_invalid_module: " .. tostring(name), 2)
    end
    if manifest.modules[name] == nil then
      error("core_unknown_module: " .. name, 2)
    end
    local parent = stack[#stack]
    if not dependencyAllowed(parent, name) then
      error("core_undeclared_dependency: " .. tostring(parent)
        .. " -> " .. name, 2)
    end
    if cache[name] ~= nil then return cache[name] end
    if loading[name] then
      error("core_dependency_cycle: " .. table.concat(stack, " -> ")
        .. " -> " .. name, 2)
    end

    local relative = name:gsub("[.]", "/") .. ".lua"
    local source, err = read(relative)
    if not source then error("core_module_read: " .. name .. ": " .. err, 2) end
    local chunk, chunkError = compile(source, "@" .. config.root .. "/" .. relative)
    if not chunk then
      error("core_module_compile: " .. name .. ": " .. tostring(chunkError), 2)
    end

    loading[name] = true
    stack[#stack + 1] = name
    local ok, value = xpcall(function() return chunk(requireCore) end,
      function(message) return tostring(message) end)
    stack[#stack] = nil
    loading[name] = nil
    if not ok then error("core_module_error: " .. name .. ": " .. value, 2) end
    if value == nil then error("core_module_nil: " .. name, 2) end
    cache[name] = value
    return value
  end

  local ok, coreOrError = xpcall(function()
    return requireCore("core").new(config, requireCore)
  end, function(message) return tostring(message) end)
  if not ok then
    return nil, { code = "core_boot_failed", message = coreOrError }
  end
  return coreOrError
end
