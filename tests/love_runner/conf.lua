function love.conf(t)
  t.identity = "gen2-clean-ui-tests"
  t.version = "11.5"
  t.console = true
  t.window = { width = 640, height = 360, visible = false }
  t.modules.audio = false
  t.modules.joystick = false
  t.modules.physics = false
  t.modules.sound = false
  t.modules.video = false
end
