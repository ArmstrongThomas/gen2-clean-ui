local requireCore = ...

local State = {}

local PRESETS = {
  mod_menus = "NAV", settings = "NAV", compatibility = "NAV",
  gallery = "L", gallery_preview = "L",
}

function State.new(view, payload)
  local self = {
    view = view or "mod_menus", payload = payload, history = {},
    index = 1, scroll = 0, hover = nil, pressed = nil,
    notice = nil, modal = nil, layout = nil,
    layoutWidth = nil, layoutWidthContext = nil,
    galleryFamily = 1,
    preview = { content = "NORMAL", ui_size = "auto",
      text_size = "auto", font = "openttd_mono" },
  }

  function self:preset(nextView)
    if nextView == "v3_screen" then
      local model = self.payload and self.payload.model
      return type(model) == "table" and model.preset or "M"
    end
    return PRESETS[nextView or self.view] or "NAV"
  end

  function self:show(nextView, nextPayload, remember)
    if remember ~= false then
      self.history[#self.history + 1] = {
        view = self.view, payload = self.payload,
        index = self.index, scroll = self.scroll,
      }
    end
    self.view, self.payload = nextView, nextPayload
    self.index, self.scroll, self.hover, self.pressed = 1, 0, nil, nil
    self.modal, self.layoutWidth, self.layoutWidthContext = nil, nil, nil
  end

  function self:back()
    local previous = table.remove(self.history)
    if not previous then return false end
    self.view, self.payload = previous.view, previous.payload
    self.index, self.scroll = previous.index, previous.scroll
    self.hover, self.pressed, self.modal = nil, nil, nil
    self.layoutWidth, self.layoutWidthContext = nil, nil
    return true
  end

  function self:move(delta, count)
    if count <= 0 then self.index = 1 return end
    self.index = ((self.index - 1 + delta) % count) + 1
  end

  function self:moveSelectable(delta, rows)
    local count = #(rows or {})
    if count <= 0 then self.index = 1 return end
    local direction = delta < 0 and -1 or 1
    local candidate = self.index
    for _ = 1, count do
      candidate = ((candidate - 1 + direction) % count) + 1
      if not (rows[candidate] and rows[candidate].disabled) then
        self.index = candidate
        return
      end
    end
  end

  function self:ensureVisible(visible, count)
    visible = math.max(1, visible or 1)
    count = math.max(0, count or 0)
    self.index = math.max(1, math.min(self.index, math.max(1, count)))
    if self.index <= self.scroll then self.scroll = self.index - 1 end
    if self.index > self.scroll + visible then
      self.scroll = self.index - visible
    end
    self.scroll = math.max(0, math.min(self.scroll,
      math.max(0, count - visible)))
  end

  return self
end

return State
