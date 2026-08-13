local requireCore = ...
local State = requireCore("components.dropdown_state")
local Layout = requireCore("components.dropdown_layout")

local Dropdown = {}

function Dropdown.new()
  local self = { state = State.closed(), descriptor = nil, layout = nil }

  local function reveal(optionId)
    if not (optionId and self.layout) then return end
    local viewport = self.layout.rect
    local scroll = self.state.scrollOffset or 0
    for _, row in ipairs(self.layout.rows or {}) do
      if row.option.id == optionId then
        local top, bottom = row.rect.y - scroll, row.rect.y - scroll + row.rect.h
        if top < viewport.y then
          scroll = scroll - (viewport.y - top)
        elseif bottom > viewport.y + viewport.h then
          scroll = scroll + (bottom - (viewport.y + viewport.h))
        end
        self.state.scrollOffset = math.max(0,
          math.min(self.layout.maxScroll or 0, scroll))
        return
      end
    end
  end

  function self:open(descriptor, trigger, safeArea, metrics)
    local normalized = {}
    for key, value in pairs(descriptor or {}) do normalized[key] = value end
    normalized.options = {}
    local lastGroup
    for index, option in ipairs(descriptor.options or {}) do
      if option.group and option.group ~= lastGroup then
        lastGroup = option.group
        normalized.options[#normalized.options + 1] = {
          id = "__group." .. tostring(index), label = option.group,
          heading = true, disabled = true,
        }
      end
      normalized.options[#normalized.options + 1] = option
    end
    self.descriptor = normalized
    self.layout = Layout.measure(normalized, trigger, safeArea, metrics)
    local result = State.reduce(self.state,
      { type = "open", triggerId = normalized.id, placement = self.layout.side },
      normalized)
    self.state = result.value.state
    reveal(self.state.activeOptionId)
    return result
  end

  function self:dispatch(event)
    if event and (event.type == "scroll" or event.type == "drag_move")
        and self.layout then
      event.maxScroll = self.layout.maxScroll
    end
    local result = State.reduce(self.state, event, self.descriptor)
    if result.ok then
      self.state = result.value.state
      reveal(result.value.reveal)
    end
    return result
  end

  return self
end

return Dropdown
