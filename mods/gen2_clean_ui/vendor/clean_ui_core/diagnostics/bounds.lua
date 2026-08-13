local requireCore = ...
local Copy = requireCore("foundation.copy")

local Bounds = {}

function Bounds.collect(layout)
  return Copy.deep({
    envelope = layout and layout.outer,
    safeArea = layout and layout.safeArea,
    nodes = layout and layout.nodes or {},
    clips = layout and layout.clipRects or {},
    scroll = layout and layout.scrollRanges or {},
    pointers = layout and layout.hitRegions or {},
    overflow = layout and layout.overflow or {},
  })
end

return Bounds

