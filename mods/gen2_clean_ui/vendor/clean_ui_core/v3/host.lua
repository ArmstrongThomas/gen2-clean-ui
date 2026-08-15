local requireCore = ...
local Semver = requireCore("foundation.semver")
local Version = requireCore("version")

local Host = {}

function Host.new(config)
  local registry = assert(config.registry)
  local capabilities = config.capabilities or {}
  local facade = {
    apiVersion = Version.apiVersion,
    coreVersion = Version.coreVersion,
    productId = config.productId,
    game = config.game,
    capabilities = capabilities,
  }

  facade.supports = function(first, second, third)
    local capability, minimumVersion = first, second
    if first == facade then capability, minimumVersion = second, third end
    local available = capabilities[capability]
    if not available then return false end
    if minimumVersion == nil then return true end
    local version = type(available) == "string" and available or Version.coreVersion
    return Semver.atLeast(version, minimumVersion)
  end
  facade.register = function(first, second, third)
    local ownerId, contract = first, second
    if first == facade then ownerId, contract = second, third end
    return registry:register(ownerId, contract):unpack()
  end
  facade.unregister = function(first, second, third)
    local ownerId, contractId = first, second
    if first == facade then ownerId, contractId = second, third end
    return registry:unregister(ownerId, contractId):unpack()
  end
  facade.openGallery = function(first, second)
    local filter = first == facade and second or first
    if config.openGallery then return config.openGallery(filter) end
    return nil, "gallery_unavailable", "Gallery is unavailable"
  end
  facade.listContracts = function(first, second)
    local filter = first == facade and second or first
    if filter ~= nil and type(filter) ~= "table" then
      return nil, "invalid_filter", "contract catalog filter must be a table"
    end
    return registry:descriptors(filter)
  end
  return facade
end

return Host
