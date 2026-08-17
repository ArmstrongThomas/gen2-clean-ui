local requireCore = ...
local Result = requireCore("foundation.result")
local Tokens = requireCore("design.tokens")
local Envelope = requireCore("layout.envelope")
local FontPolicy = requireCore("text.font_policy")

local Solver = {}

local function signature(request, envelope, font)
  return table.concat({ request.preset, envelope.outer.x, envelope.outer.y,
    envelope.outer.w, envelope.outer.h, request.themeRevision or 0,
    request.settingsRevision or 0, font.family, font.step,
    request.density or "auto" }, ":")
end

function Solver.solve(request)
  if type(request) ~= "table" or type(request.viewport) ~= "table" then
    return Result.err("invalid_layout_request", "viewport is required")
  end
  local envelope, code, message = Envelope.measure(request.preset,
    request.viewport, request.safeArea, request.uiSize)
  if not envelope then return Result.err(code, message) end
  if request.logicalWidth then
    envelope = Envelope.withLogicalWidth(envelope, request.logicalWidth)
  end
  local family = FontPolicy.normalizeFamily(request.fontFamily)
  local candidates = FontPolicy.candidates(request.textSize, envelope.scale,
    family)
  for _, font in ipairs(candidates) do
    local complete, decisions = true, {}
    if request.probe then
      local ok, outcome = pcall(request.probe, envelope, font, request.density)
      complete = ok and outcome ~= false
      decisions[#decisions + 1] = ok and "probe" or tostring(outcome)
    end
    if complete then
      local inset = math.max(1, math.floor(Tokens.frameLogicalWidth * envelope.scale))
      local layout = {
        revision = request.revision or 1,
        preset = request.preset,
        logical = { w = envelope.logical.w, h = envelope.logical.h },
        minW = envelope.minW,
        widthMode = envelope.widthMode,
        orientation = envelope.orientation,
        viewport = envelope.viewport,
        safeArea = envelope.safeArea,
        outer = envelope.outer,
        frameInset = { left = inset, top = inset, right = inset, bottom = inset },
        scale = envelope.scale,
        aspect = envelope.aspect,
        font = font,
        density = request.density or "comfortable",
        nodes = {}, clipRects = {}, scrollRanges = {}, hitRegions = {},
        overflow = { resolved = decisions, unresolvedRequired = {} },
        diagnostics = { decisions = decisions, warnings = {} },
      }
      layout.signature = signature(request, envelope, font)
      return Result.ok(layout)
    end
  end
  return Result.err("required_overflow", "no whole font step fits the envelope")
end

return Solver
