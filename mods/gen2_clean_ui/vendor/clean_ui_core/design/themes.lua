local requireCore = ...
local Contrast = requireCore("design.contrast")
local Copy = requireCore("foundation.copy")
local Order = requireCore("foundation.order")

local Themes = {}

local BUILT_INS = {
  clean = {
    id = "clean", label = "Clean", frame = "clean_cut",
    colors = {
      paper = "#F4F1E5", raised = "#E5E4DA", ink = "#20242A",
      muted = "#66727A", selection = "#BCCAC4", focus = "#356AC3",
      gen1Accent = "#356AC3", gen2Accent = "#B3882D",
    },
  },
  dark = {
    id = "dark", label = "Dark", frame = "clean_cut",
    colors = {
      paper = "#171A1F", raised = "#252A31", ink = "#F4F1E8",
      muted = "#B7C0C8", selection = "#35414A", focus = "#78A9FF",
      gen1Accent = "#78A9FF", gen2Accent = "#E1B95C",
    },
  },
  high_contrast = {
    id = "high_contrast", label = "High Contrast", frame = "clean_cut",
    colors = {
      paper = "#000000", raised = "#000000", ink = "#FFFFFF",
      muted = "#FFFFFF", selection = "#222222", focus = "#FFD83D",
      gen1Accent = "#FFD83D", gen2Accent = "#FFD83D",
    },
  },
}

local function validate(theme)
  if type(theme) ~= "table" or type(theme.id) ~= "string"
      or type(theme.colors) ~= "table" then
    return nil, "invalid_theme", "theme id and colors are required"
  end
  for _, key in ipairs({ "paper", "raised", "ink", "muted", "selection", "focus" }) do
    if not Contrast.rgb(theme.colors[key]) then
      return nil, "invalid_theme", "invalid color: " .. key
    end
  end
  if (Contrast.ratio(theme.colors.ink, theme.colors.paper) or 0) < 4.5 then
    return nil, "insufficient_contrast", "ink/paper contrast must be at least 4.5:1"
  end
  return true
end

function Themes.new()
  local self = { records = Copy.deep(BUILT_INS), revision = 1 }

  function self:get(id)
    local found = self.records[id] or self.records.clean
    return Copy.deep(found)
  end

  function self:register(theme)
    local ok, code, message = validate(theme)
    if not ok then return nil, code, message end
    self.records[theme.id] = Copy.deep(theme)
    self.revision = self.revision + 1
    return true
  end

  function self:list()
    local out = {}
    for _, id in ipairs(Order.keys(self.records)) do
      out[#out + 1] = Copy.deep(self.records[id])
    end
    return out
  end

  return self
end

return Themes

