return function(mod)
  assert(type(mod) == "table", "Gen2 Clean UI requires the API 2 mod facade")
  assert(type(mod.path) == "string", "Gen2 Clean UI requires mod.path")

  local cache = {}
  local loading = {}
  local context = { mod = mod }

  local function loadFile(relative)
    local source, readError = mod:read(relative)
    if not source then return nil, readError or ("unable to read " .. relative) end
    local path = tostring(mod.path) .. "/" .. relative
    local chunk, loadError = load(source, "@" .. path)
    if not chunk then
      return nil, loadError or ("unable to load " .. path)
    end
    local ok, value = pcall(chunk)
    if not ok then return nil, value end
    return value
  end

  local function loadModule(name)
    if cache[name] ~= nil then return cache[name] end
    if loading[name] then error("circular Clean UI module: " .. name, 0) end
    loading[name] = true
    local relative = "src/" .. name:gsub("%.", "/") .. ".lua"
    local exported, loadError = loadFile(relative)
    if exported == nil then
      loading[name] = nil
      error(("unable to load %s: %s"):format(name, tostring(loadError)), 0)
    end
    if type(exported) == "function" then exported = exported(context) end
    cache[name] = exported
    loading[name] = nil
    return exported
  end

  function context.load(name) return loadModule(name) end
  function context.loadFile(relative) return loadFile(relative) end
  function context.fileExists(relative)
    local source = mod:read(relative)
    return type(source) == "string"
  end

  return loadModule("product").start()
end
