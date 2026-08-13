-- Entry point only. Product code lives under src/ and vendored shared code
-- lives under vendor/clean_ui_core once a core snapshot is pinned.
return function(mod)
  assert(type(mod) == "table" and type(mod.read) == "function",
    "gen2_clean_ui requires the API 2 mod facade")
  local path = "src/bootstrap.lua"
  local source, readError = mod:read(path)
  if not source then error(readError or ("unable to read " .. path), 0) end
  local chunk, loadError = load(source, "@" .. tostring(mod.path) .. "/" .. path)
  if not chunk then error(loadError or ("unable to compile " .. path), 0) end
  local bootstrap = chunk()
  if type(bootstrap) ~= "function" then
    error("Gen2 Clean UI bootstrap must return a function", 0)
  end
  return bootstrap(mod)
end
