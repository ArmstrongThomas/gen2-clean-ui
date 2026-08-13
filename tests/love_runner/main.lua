local function fail(message)
  io.stderr:write(tostring(message), "\n")
  love.event.quit(1)
end

function love.load()
  io.stdout:setvbuf("no")
  local root = os.getenv("GEN2_CLEAN_UI_ROOT")
  if not root then return fail("GEN2_CLEAN_UI_ROOT is required") end
  local target = os.getenv("GEN2_CLEAN_UI_TEST") or "tests/run_all.lua"
  if target:find("..", 1, true) or target:find(":", 1, true)
      or target:sub(1, 1) == "/" or target:sub(1, 1) == "\\" then
    return fail("GEN2_CLEAN_UI_TEST must be a repository-relative path")
  end
  local chunk, loadError = loadfile(root .. "/" .. target)
  if not chunk then return fail(loadError) end
  local ok, runtimeError = xpcall(chunk, debug.traceback)
  if not ok then return fail(runtimeError) end
  love.event.quit(0)
end
