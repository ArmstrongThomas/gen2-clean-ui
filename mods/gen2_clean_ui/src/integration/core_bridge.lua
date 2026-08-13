return function(ctx)
  local CoreBridge = {}
  CoreBridge.__index = CoreBridge

  local VENDOR_ROOT = "vendor/clean_ui_core"
  local VENDOR_BOOTSTRAP = VENDOR_ROOT .. "/bootstrap.lua"

  local function log(mod, level, message, ...)
    local logger = mod and mod.log
    local method = logger and logger[level]
    if type(method) == "function" then method(logger, message, ...) end
  end

  local function pendingHost(services)
    local host = {
      apiVersion = 3,
      coreVersion = "unavailable",
      productId = "gen2_clean_ui",
      game = "gen2",
      capabilities = {},
    }
    function host.supports() return false end
    local function unavailable()
      return nil, "core_unavailable",
        "clean-ui-core is not available; source UI remains native"
    end
    host.register, host.unregister, host.openGallery =
      unavailable, unavailable, unavailable
    host.contracts = function() return services.provider.catalog.records end
    return host
  end

  function CoreBridge.new(mod, loaderContext, services)
    local self = setmetatable({ mod = mod, services = services,
      status = "vendor_pending", runtime = nil }, CoreBridge)
    self.host = pendingHost(services)

    local source, readError = mod:read(VENDOR_BOOTSTRAP)
    if not source then
      log(mod, "warn", "Clean UI core vendor unavailable; Gen2 UI remains native: %s",
        tostring(readError))
      return self
    end
    local chunk, compileError = load(source,
      "@" .. tostring(mod.path) .. "/" .. VENDOR_BOOTSTRAP)
    if not chunk then
      self.status = "core_error"
      log(mod, "error", "vendored core bootstrap did not compile: %s",
        tostring(compileError))
      return self
    end
    local okEntry, start = pcall(chunk)
    if not okEntry or type(start) ~= "function" then
      self.status = "core_error"
      log(mod, "error", "vendored core bootstrap is invalid: %s", tostring(start))
      return self
    end

    local adapter = services.provider
    adapter.gallery = services.gallery
    local runtime, bootError = start({
      root = VENDOR_ROOT,
      read = function(path) return mod:read(path) end,
      mod = mod,
      provider = adapter,
      settingsSchema = services.settings.schema,
    })
    if type(runtime) ~= "table" then
      self.status = "core_error"
      log(mod, "error", "vendored core startup failed: %s",
        tostring(type(bootError) == "table" and bootError.message or bootError))
      return self
    end
    local installed, code, message = runtime:install()
    if not installed then
      self.status = "core_error"
      log(mod, "error", "vendored core install failed: %s: %s",
        tostring(code), tostring(message))
      return self
    end
    self.runtime, self.host, self.status = runtime, runtime.host, "ready"
    return self
  end

  function CoreBridge:attachProvider()
    return self.status == "ready", self.status == "ready" and nil or "core_unavailable"
  end

  return CoreBridge
end
