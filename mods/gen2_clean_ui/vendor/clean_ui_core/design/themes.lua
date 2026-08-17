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
  light_high_contrast = {
    id = "light_high_contrast", label = "Light High Contrast",
    frame = "clean_cut",
    colors = {
      paper = "#FFFFFF", raised = "#FFFFFF", ink = "#000000",
      muted = "#000000", selection = "#E6E6E6", focus = "#0047AB",
      gen1Accent = "#0047AB", gen2Accent = "#8B5E00",
    },
  },
  red = {
    id = "red", label = "Red", frame = "clean_cut",
    colors = {
      paper = "#F8E9EA", raised = "#EAC7CB", ink = "#4A141B",
      muted = "#7D4A52", selection = "#F0A9B1", focus = "#C52A3A",
      gen1Accent = "#C52A3A", gen2Accent = "#A86A2A",
    },
  },
  red_dark = {
    id = "red_dark", label = "Dark Red", frame = "clean_cut",
    colors = {
      paper = "#241317", raised = "#3A1D23", ink = "#F9E7EA",
      muted = "#D3AAB3", selection = "#5D2933", focus = "#FF6B78",
      gen1Accent = "#FF6B78", gen2Accent = "#D7A25A",
    },
  },
  gold = {
    id = "gold", label = "Gold", frame = "clean_cut",
    colors = {
      paper = "#F7F0D2", raised = "#E7D79C", ink = "#3E2F12",
      muted = "#7A6428", selection = "#D8B84A", focus = "#A67310",
      gen1Accent = "#A67310", gen2Accent = "#A67310",
    },
  },
  gold_dark = {
    id = "gold_dark", label = "Dark Gold", frame = "clean_cut",
    colors = {
      paper = "#211C0B", raised = "#382F13", ink = "#FFF5D0",
      muted = "#D8C788", selection = "#594917", focus = "#EFC34C",
      gen1Accent = "#EFC34C", gen2Accent = "#EFC34C",
    },
  },
  blue = {
    id = "blue", label = "Blue", frame = "clean_cut",
    colors = {
      paper = "#E9F2FA", raised = "#C9DDED", ink = "#122B45",
      muted = "#46647F", selection = "#A7CFF1", focus = "#2A66B7",
      gen1Accent = "#2A66B7", gen2Accent = "#4E83B5",
    },
  },
  blue_dark = {
    id = "blue_dark", label = "Dark Blue", frame = "clean_cut",
    colors = {
      paper = "#101B29", raised = "#1D3045", ink = "#E8F3FF",
      muted = "#A8C4DD", selection = "#284B6D", focus = "#69B1FF",
      gen1Accent = "#69B1FF", gen2Accent = "#8FC7E8",
    },
  },
  yellow = {
    id = "yellow", label = "Yellow", frame = "clean_cut",
    colors = {
      paper = "#FFF8D6", raised = "#F2DF75", ink = "#3A3005",
      muted = "#74631A", selection = "#E8CB3F", focus = "#9E7A00",
      gen1Accent = "#9E7A00", gen2Accent = "#A67310",
    },
  },
  yellow_dark = {
    id = "yellow_dark", label = "Dark Yellow", frame = "clean_cut",
    colors = {
      paper = "#211E08", raised = "#393411", ink = "#FFF7C7",
      muted = "#D8CB84", selection = "#5A5117", focus = "#F0D64F",
      gen1Accent = "#F0D64F", gen2Accent = "#E2B84F",
    },
  },
  silver = {
    id = "silver", label = "Silver", frame = "clean_cut",
    colors = {
      paper = "#EEF1F3", raised = "#D4D9DE", ink = "#242A30",
      muted = "#58636E", selection = "#B8C4CE", focus = "#687A8C",
      gen1Accent = "#687A8C", gen2Accent = "#9A7B35",
    },
  },
  silver_dark = {
    id = "silver_dark", label = "Dark Silver", frame = "clean_cut",
    colors = {
      paper = "#1B2025", raised = "#303942", ink = "#EEF2F5",
      muted = "#B8C3CC", selection = "#475462", focus = "#A9C5D9",
      gen1Accent = "#A9C5D9", gen2Accent = "#D7B866",
    },
  },
  crystal = {
    id = "crystal", label = "Crystal", frame = "clean_cut",
    colors = {
      paper = "#EAF5F6", raised = "#CDE7EB", ink = "#202C3A",
      muted = "#4F6874", selection = "#B7DDE5", focus = "#6A4FB3",
      gen1Accent = "#5B91C8", gen2Accent = "#B452B9",
    },
  },
  crystal_dark = {
    id = "crystal_dark", label = "Dark Crystal", frame = "clean_cut",
    colors = {
      paper = "#17172A", raised = "#282845", ink = "#EEF1FF",
      muted = "#B9B9D6", selection = "#3D3565", focus = "#B9A7FF",
      gen1Accent = "#86C6FF", gen2Accent = "#E58BEE",
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

  function self:resolve(id, darkMode)
    id = type(id) == "string" and id or "clean"
    darkMode = darkMode == true
    if id == "clean" then
      return self:get(darkMode and "dark" or "clean")
    elseif id == "dark" then
      return self:get("dark")
    elseif id == "high_contrast" or id == "light_high_contrast" then
      return self:get(darkMode and "high_contrast" or "light_high_contrast")
    elseif id:sub(-5) == "_dark" then
      return self:get(darkMode and id or id:sub(1, -6))
    elseif darkMode and self.records[id .. "_dark"] then
      return self:get(id .. "_dark")
    end
    return self:get(id)
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
