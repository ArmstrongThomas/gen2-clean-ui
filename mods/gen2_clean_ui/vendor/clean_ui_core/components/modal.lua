local requireCore = ...
local Result = requireCore("foundation.result")
local Data = requireCore("foundation.data")

local Modal = {}

local function stableId(value)
  return type(value) == "string" and value:match("^[%a_][%w_.%-]*$") ~= nil
end

local function firstSelectable(options)
  for index, option in ipairs(options or {}) do
    if not option.disabled then return index end
  end
  return nil
end

function Modal.validate(descriptor)
  if type(descriptor) ~= "table" or descriptor.type ~= "modal_overlay" then
    return Result.err("invalid_modal", "type must be modal_overlay")
  end
  local snapshot, err = Data.snapshot(descriptor)
  if not snapshot then return Result.err("invalid_modal", err) end
  snapshot.dim_background = snapshot.dim_background ~= false
  snapshot.dim_opacity = math.max(0, math.min(1,
    tonumber(snapshot.dim_opacity) or 0.4))
  snapshot.cancelable = snapshot.cancelable ~= false
  snapshot.options = snapshot.options or {}
  if type(snapshot.options) ~= "table" then
    return Result.err("invalid_modal", "options must be an array")
  end
  for index, option in ipairs(snapshot.options) do
    if type(option) ~= "table" or not stableId(option.id)
        or type(option.label) ~= "string" then
      return Result.err("invalid_modal", "option " .. tostring(index)
        .. " requires a stable id and label")
    end
    if option.action ~= nil and not stableId(option.action) then
      return Result.err("invalid_modal", "option " .. option.id
        .. " has an invalid action id")
    end
  end
  snapshot.selected = firstSelectable(snapshot.options)
  return Result.ok(snapshot)
end

function Modal.move(modal, delta)
  local options = modal and modal.descriptor and modal.descriptor.options or {}
  if #options == 0 then return nil end
  local index = tonumber(modal.index) or firstSelectable(options)
  if not index then return nil end
  for _ = 1, #options do
    index = ((index - 1 + delta) % #options) + 1
    if not options[index].disabled then
      modal.index = index
      return index
    end
  end
  return nil
end

function Modal.ensureVisible(modal)
  local layout = modal and modal.layout
  if not layout then return end
  local visible = math.max(1, layout.visibleRows or 1)
  local count = #(modal.descriptor.options or {})
  local index = math.max(1, math.min(modal.index or 1, math.max(1, count)))
  modal.index = index
  if index <= (modal.scroll or 0) then modal.scroll = index - 1 end
  if index > (modal.scroll or 0) + visible then modal.scroll = index - visible end
  modal.scroll = math.max(0, math.min(modal.scroll or 0,
    math.max(0, count - visible)))
end

return Modal
