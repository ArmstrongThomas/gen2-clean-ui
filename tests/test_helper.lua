local Helper = {}

function Helper.new(root, options)
  options = options or {}
  local cache = {}
  local context = { mod=options.mod }
  root = root:gsub("\\", "/")

  local function loadModule(name)
    if cache[name] ~= nil then return cache[name] end
    local path = root .. "/mods/gen2_clean_ui/src/"
      .. name:gsub("%.", "/") .. ".lua"
    local chunk, loadError = loadfile(path)
    assert(chunk, loadError)
    local exported = chunk()
    if type(exported) == "function" then exported = exported(context) end
    cache[name] = exported
    return exported
  end

  context.load = loadModule
  return context
end

return Helper
