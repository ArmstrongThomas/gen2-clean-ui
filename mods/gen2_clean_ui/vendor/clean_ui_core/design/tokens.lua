local requireCore = ...

return {
  plainPixelBase = 15,
  plainPixelSteps = { 1, 2, 3, 4 },
  frameLogicalWidth = 2,
  cutLogicalSize = 7,
  minPointerTarget = 44,
  spacing = {
    comfortable = { xxs = 4, xs = 8, s = 12, m = 16, l = 24, xl = 32 },
    compact = { xxs = 3, xs = 6, s = 9, m = 12, l = 18, xl = 24 },
  },
  uiSizeMultiplier = {
    small = 0.84,
    medium = 1.0,
    large = 1.18,
  },
  autoScale = {
    referenceShortEdge = 720,
    min = 0.45,
    max = 3.25,
  },
}

