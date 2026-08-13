local requireCore = ...
local Copy = requireCore("foundation.copy")
local Data = requireCore("foundation.data")
local Id = requireCore("foundation.id")
local Result = requireCore("foundation.result")

local Contract = {}
local function includesGame(games, game)
  for _, value in ipairs(games or {}) do if value == game then return true end end
  return false
end

local function validateDataSections(contract)
  for _, name in ipairs({ "screens", "extensions", "themes", "frames", "gallery" }) do
    if contract[name] ~= nil then
      local ok, err = Data.validate(contract[name])
      if not ok then return nil, name .. ": " .. err end
    end
  end
  return true
end

function Contract.validate(ownerId, contract, game)
  local _, code, message = Id.require(ownerId, "ownerId")
  if code then return Result.err(code, message) end
  if type(contract) ~= "table" then
    return Result.err("invalid_contract", "contract must be a table")
  end
  local id, idCode, idMessage = Id.require(contract.id, "contract.id")
  if not id then return Result.err(idCode, idMessage) end
  if type(contract.version) ~= "string" or contract.version == "" then
    return Result.err("invalid_contract", "contract.version is required")
  end
  if not includesGame(contract.games, game) then
    return Result.err("wrong_game", "contract does not include " .. tostring(game))
  end
  if contract.actions ~= nil and type(contract.actions) ~= "table" then
    return Result.err("invalid_contract", "actions must be a table")
  end
  for actionId, callback in pairs(contract.actions or {}) do
    if not Id.valid(actionId) or type(callback) ~= "function" then
      return Result.err("invalid_action", "actions require stable IDs and functions")
    end
  end
  for _, surface in ipairs(contract.surfaces or {}) do
    if type(surface) ~= "table" or (surface.update ~= nil
        and type(surface.update) ~= "function") or type(surface.draw) ~= "function" then
      return Result.err("invalid_surface", "surface draw must be a function")
    end
    if surface.mode == "replace" and (type(surface.screen_id) ~= "string"
        or type(surface.validate) ~= "function") then
      return Result.err("unsafe_replace_surface",
        "replace surfaces require exact screen_id and validate")
    end
  end
  for index, extension in ipairs(contract.extensions or {}) do
    if type(extension) ~= "table" or not Id.valid(extension.id)
        or type(extension.type) ~= "string"
        or type(extension.target) ~= "string" then
      return Result.err("invalid_extension",
        "extension " .. tostring(index) .. " requires id, type, and target")
    end
    if (extension.type == "start.action" or extension.type == "menu.action")
        and (not Id.valid(extension.action)
          or type((contract.actions or {})[extension.action]) ~= "function") then
      return Result.err("unknown_action",
        "extension " .. extension.id .. " references an unknown action")
    end
  end
  local dataOk, dataError = validateDataSections(contract)
  if not dataOk then return Result.err("invalid_snapshot", dataError) end
  local staged = Copy.deep(contract)
  staged.actions = contract.actions or {}
  staged.surfaces = contract.surfaces or {}
  staged.ownerId = ownerId
  staged.contractId = id
  return Result.ok(staged)
end

return Contract
