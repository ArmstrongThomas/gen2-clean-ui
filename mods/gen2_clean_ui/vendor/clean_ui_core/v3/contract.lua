local requireCore = ...
local Copy = requireCore("foundation.copy")
local Data = requireCore("foundation.data")
local Id = requireCore("foundation.id")
local Panel = requireCore("v3.panel")
local PresentationModel = requireCore("presentation.model")
local Result = requireCore("foundation.result")

local Contract = {}
local PRESENTATION_KINDS = PresentationModel.KINDS

local function validateScreens(screens)
  if screens ~= nil and type(screens) ~= "table" then
    return nil, "invalid_screen", "screens must be a table"
  end
  for index, screen in ipairs(screens or {}) do
    if type(screen) ~= "table" then
      return nil, "invalid_screen", "screens[" .. tostring(index)
        .. "] must be a table"
    end
    if screen.type == "panel" then
      local valid, panelMessage = Panel.validate(screen)
      if not valid then
        return nil, "invalid_screen", "screens[" .. tostring(index)
          .. "] " .. tostring(panelMessage)
      end
    elseif PRESENTATION_KINDS[screen.kind] then
      local valid, _, message = PresentationModel.validate(screen)
      if not valid then
        return nil, "invalid_screen", "screens[" .. tostring(index)
          .. "] " .. tostring(message)
      end
    else
      return nil, "invalid_screen", "screens[" .. tostring(index)
        .. "] must be a panel or supported direct presentation model"
    end
  end
  return true
end

local function validateGames(games)
  if games == nil then return true end
  if type(games) ~= "table" then return nil, "games must be an array" end
  for index, value in ipairs(games) do
    if type(value) ~= "string" or value == "" then
      return nil, "games[" .. tostring(index) .. "] must be a non-empty string"
    end
  end
  return true
end

local function includesGame(games, game)
  for _, value in ipairs(games or {}) do if value == game then return true end end
  return false
end

local function appliesToGame(contract, game)
  if contract.all_generations == true then return true end
  return includesGame(contract.games, game)
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

local function validateScreenActions(value, path, actions)
  if type(value) ~= "table" then return true end
  if value.action ~= nil then
    if type(value.action) ~= "string" or not Id.valid(value.action)
        or type(actions[value.action]) ~= "function" then
      return nil, "unknown_action",
        path .. ".action references an unregistered named action"
    end
  end
  local keys = {}
  for key in pairs(value) do
    if key ~= "action" then keys[#keys + 1] = key end
  end
  table.sort(keys, function(left, right) return tostring(left) < tostring(right) end)
  for _, key in ipairs(keys) do
    local ok, code, message = validateScreenActions(value[key],
      path .. "." .. tostring(key), actions)
    if not ok then return nil, code, message end
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
  if contract.all_generations ~= nil
      and type(contract.all_generations) ~= "boolean" then
    return Result.err("invalid_contract",
      "all_generations must be a boolean when provided")
  end
  local gamesOk, gamesMessage = validateGames(contract.games)
  if not gamesOk then return Result.err("invalid_contract", gamesMessage) end
  if contract.all_generations ~= true and contract.games == nil then
    return Result.err("invalid_contract",
      "games is required unless all_generations is true")
  end
  if contract.all_generations ~= true and not includesGame(contract.games, game) then
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
  local screensOk, screensCode, screensMessage = validateScreens(contract.screens)
  if not screensOk then return Result.err(screensCode, screensMessage) end
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
  local actionsOk, actionsCode, actionsMessage = validateScreenActions(
    contract.screens or {}, "screens", contract.actions or {})
  if not actionsOk then return Result.err(actionsCode, actionsMessage) end
  local staged = Copy.deep(contract)
  staged.actions = contract.actions or {}
  staged.surfaces = contract.surfaces or {}
  staged.ownerId = ownerId
  staged.contractId = id
  return Result.ok(staged)
end

-- Return the editor-safe part of a validated contract. Runtime callbacks are
-- intentionally omitted: a standalone editor may inspect the declarative
-- screen, extension, surface, theme, frame, and Gallery metadata without
-- receiving source-owned closures or private execution context.
function Contract.public(record)
  local out = {
    ownerId=record.ownerId, contractId=record.contractId,
    id=record.id, version=record.version,
    games=Copy.deep(record.games or {}),
    all_generations=record.all_generations == true,
    priority=record.priority,
    screens=Copy.deep(record.screens or {}),
    extensions=Copy.deep(record.extensions or {}),
    themes=Copy.deep(record.themes or {}),
    frames=Copy.deep(record.frames or {}),
    gallery=Copy.deep(record.gallery or {}),
    actionIds={}, surfaces={},
  }
  for actionId in pairs(record.actions or {}) do
    out.actionIds[#out.actionIds + 1] = actionId
  end
  table.sort(out.actionIds)
  for _, surface in ipairs(record.surfaces or {}) do
    local descriptor = {}
    for key, value in pairs(surface) do
      if type(value) ~= "function" then descriptor[key] = Copy.deep(value) end
    end
    descriptor.has_update = type(surface.update) == "function"
    descriptor.has_draw = type(surface.draw) == "function"
    descriptor.has_validate = type(surface.validate) == "function"
    out.surfaces[#out.surfaces + 1] = descriptor
  end
  return out
end

return Contract
