function love.conf(t)
  t.identity = "gen2-clean-ui-tests"
  t.version = "11.5"
  t.console = true
  -- Product contract/presenter tests do not render in hosted CI. Disable the
  -- window there so the runner never waits on an OpenGL context, while local
  -- runs retain the full hidden-window smoke coverage.
  if os.getenv("GEN2_CLEAN_UI_HEADLESS") == "1" then
    t.window = false
  else
    t.window = { width = 640, height = 360, visible = false }
  end
  t.modules.audio = false
  t.modules.joystick = false
  t.modules.physics = false
  t.modules.sound = false
  t.modules.video = false
end
