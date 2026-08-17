local requireCore = ...
local Result = requireCore("foundation.result")
local unpackValues = unpack or table.unpack

local Transaction = {}

local GETTERS = {
  canvas = "getCanvas", shader = "getShader", color = "getColor",
  font = "getFont", lineWidth = "getLineWidth", lineStyle = "getLineStyle",
  lineJoin = "getLineJoin", pointSize = "getPointSize",
}

local function capture(graphics)
  local state = {}
  for key, method in pairs(GETTERS) do
    if graphics[method] then state[key] = { graphics[method]() } end
  end
  if graphics.getBlendMode then state.blendMode = { graphics.getBlendMode() } end
  if graphics.getScissor then state.scissor = { graphics.getScissor() } end
  if graphics.getColorMask then state.colorMask = { graphics.getColorMask() } end
  if graphics.getStencilTest then state.stencilTest = { graphics.getStencilTest() } end
  if graphics.getTransform then state.transform = graphics.getTransform() end
  return state
end

local function call(graphics, method, values)
  if values and graphics[method] then
    return pcall(graphics[method], unpackValues(values))
  end
end

local function restore(graphics, state)
  call(graphics, "setCanvas", state.canvas)
  call(graphics, "setShader", state.shader)
  call(graphics, "setColor", state.color)
  call(graphics, "setBlendMode", state.blendMode)
  if state.scissor then call(graphics, "setScissor", state.scissor)
  elseif graphics.setScissor then pcall(graphics.setScissor) end
  call(graphics, "setFont", state.font)
  call(graphics, "setLineWidth", state.lineWidth)
  call(graphics, "setLineStyle", state.lineStyle)
  call(graphics, "setLineJoin", state.lineJoin)
  call(graphics, "setPointSize", state.pointSize)
  call(graphics, "setColorMask", state.colorMask)
  if state.stencilTest and graphics.setStencilTest then
    call(graphics, "setStencilTest", state.stencilTest)
  elseif graphics.setStencilTest then
    pcall(graphics.setStencilTest)
  end
  if state.transform and graphics.replaceTransform then
    pcall(graphics.replaceTransform, state.transform)
  end
end

function Transaction.run(graphics, canvas, callback, context, snapshot)
  if type(graphics) ~= "table" or type(callback) ~= "function" then
    return Result.err("invalid_surface", "graphics and callback are required")
  end
  local state = capture(graphics)
  local initialDepth
  if graphics.getStackDepth then
    local depthOk, depth = pcall(graphics.getStackDepth)
    if depthOk and type(depth) == "number" then initialDepth = depth end
  end
  local isolated = false
  if graphics.push and graphics.pop then
    isolated = pcall(graphics.push, "all")
  end
  local ok, value = xpcall(function()
    if graphics.setCanvas then graphics.setCanvas(canvas) end
    if graphics.clear then graphics.clear(0, 0, 0, 0) end
    if graphics.origin then graphics.origin() end
    return callback(context, snapshot)
  end, function(message) return tostring(message) end)
  if graphics.pop and isolated then
    if initialDepth ~= nil and graphics.getStackDepth then
      local depthOk, depth = pcall(graphics.getStackDepth)
      while depthOk and type(depth) == "number" and depth > initialDepth do
        if not pcall(graphics.pop) then break end
        depthOk, depth = pcall(graphics.getStackDepth)
      end
      -- A callback that underflows the caller's stack has violated the surface
      -- contract. Rebuild the depth defensively, then restore every observable
      -- graphics property captured above. Normal callbacks never enter here.
      while depthOk and type(depth) == "number" and depth < initialDepth
          and graphics.push do
        if not pcall(graphics.push, "all") then break end
        depthOk, depth = pcall(graphics.getStackDepth)
      end
    else
      pcall(graphics.pop)
    end
  end
  restore(graphics, state)
  if not ok then return Result.err("surface_callback_failed", value) end
  return Result.ok(value)
end

return Transaction
