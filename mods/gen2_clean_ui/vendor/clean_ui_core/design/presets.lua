local requireCore = ...

return {
  XS = { w = 320, h = 200 },
  S = { w = 400, h = 300 },
  -- NAV keeps the tall menu silhouette, but its width is content-driven
  -- between the compact minimum and the historical maximum. The shell
  -- locks the chosen width for the lifetime of the open view.
  NAV = { w = 440, minW = 320, h = 560, widthMode = "content" },
  -- Ordinary list menus may narrow to their measured content, but retain the
  -- full 420-pixel logical height for scrolling room and stable composition.
  M = { w = 600, minW = 320, h = 420, widthMode = "content" },
  L = { w = 760, h = 540 },
  XL = { w = 960, h = 640 },
  BATTLE_WIDE = { w = 640, h = 360 },
  -- Battle keeps the desktop composition's information density, but has a
  -- deliberately stacked portrait envelope for phones and narrow safe areas.
  BATTLE = { w = 640, h = 360, portrait = { w = 360, h = 640 } },
}
