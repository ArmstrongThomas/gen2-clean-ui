local requireCore = ...
local Version = requireCore("version")
local Presets = requireCore("design.presets")
local Contract = requireCore("v3.contract")
local Content = requireCore("shell.content")
local PresentationModel = requireCore("presentation.model")
local Themes = requireCore("design.themes")
local Session = requireCore("layout.session")
local Solver = requireCore("layout.solver")
local Dropdown = requireCore("components.dropdown")
local Transaction = requireCore("surfaces.transaction")
local Registry = requireCore("v3.registry")
local Host = requireCore("v3.host")
local Settings = requireCore("integration.settings")
local Catalog = requireCore("integration.catalog")
local Pins = requireCore("integration.pins")
local StartMenu = requireCore("integration.start_menu")
local ModMenus = requireCore("integration.mod_menus")
local Shell = requireCore("shell.runtime")
local Gallery = requireCore("gallery.catalog")
local Bounds = requireCore("diagnostics.bounds")
local PresentationRuntime = requireCore("presentation.runtime")
local Pipeline = requireCore("presentation.pipeline")

local Core = {}
local CAPABILITIES = {
  data_screens = "0.1.0", additive_extensions = "0.1.0",
  dropdown = "0.1.0", modal_overlay = "0.1.0", custom_fields = "0.1.0",
  footer_lists = "0.1.0", custom_surface = "0.1.0",
  isolated_shader = "0.1.0", themes = "0.1.0", frames = "0.1.0",
  gallery = "0.1.0", start_menu_pinning = "0.1.0",
  contract_catalog = "0.1.0",
  presentation_models = "0.1.0",
}

local function modAssetPath(mod, relative)
  local assets = mod and mod.assets
  if assets and type(assets.path) == "function" then
    local ok, path = pcall(assets.path, assets, relative)
    if ok and type(path) == "string" and path ~= "" then return path end
  end
  return relative
end

function Core.new(config)
  assert(type(config.provider) == "table", "product provider is required")
  assert(config.provider.game == "gen1" or config.provider.game == "gen2",
    "provider game must be gen1 or gen2")
  local configuredPaths = config.fontPaths or {}
  local fontPaths = {
    -- Plain Pixel remains host-provided. The other bundled faces are resolved
    -- through the public mod.assets:path facade so they work from both a
    -- development folder and a mounted release archive.
    plainPixel = configuredPaths.plainPixel or config.plainPixelPath
      or "assets/fonts/plainpixel/PlainPixel-Regular.ttf",
    system = configuredPaths.system,
    openttdMono = configuredPaths.openttdMono or config.openttdMonoPath
      or modAssetPath(config.mod,
        "assets/fonts/openttd_mono/OpenTTD-Mono.ttf"),
  }
  local self = {
    config = config, mod = config.mod, provider = config.provider,
    fontPaths = fontPaths,
    version = Version, presets = Presets, themes = Themes.new(),
    sessions = Session.new(), dropdown = Dropdown.new(),
    transaction = Transaction, registry = Registry.new(config.provider.game),
    catalog = Catalog.new(), gallery = Gallery.new(config.provider.game),
    settingsSchema = config.settingsSchema or Settings.schema,
    installed = false, subscriptions = {},
  }
  self.pins = Pins.new(config.mod and config.mod.save)
  self.modMenus = ModMenus.new(self.catalog, self.pins)
  self.pipeline = Pipeline.new({ provider = config.provider, solver = Solver,
    sessions = self.sessions, uiSize = "auto", textSize = "auto",
    fontFamily = "openttd_mono", density = "auto" })
  self.host = Host.new({ registry = self.registry,
    productId = config.provider.productId, game = config.provider.game,
    capabilities = CAPABILITIES,
    openGallery = function(filter) return self:openGallery(filter) end })
  self.shell = Shell.new(self)
  self.presentation = PresentationRuntime.new(self)

  function self:install()
    if self.installed then return true end
    local defined = Settings.define(self.mod, self.settingsSchema)
    if not defined.ok then return defined:unpack() end
    if self.mod and self.mod.exports then self.mod.exports.cleanUiHost = self.host end
    if self.provider.registerContracts then
      local ok, err = pcall(self.provider.registerContracts, self)
      if not ok then
        if self.mod and self.mod.exports then self.mod.exports.cleanUiHost = nil end
        return nil, "provider_contract_failed", tostring(err)
      end
    end
    if self.provider.install then
      local ok, value = pcall(self.provider.install, self)
      if not ok then
        if self.mod and self.mod.exports then self.mod.exports.cleanUiHost = nil end
        return nil, "provider_install_failed", tostring(value)
      end
      if type(value) == "table" then self.subscriptions = value end
    end
    local shellInstalled = self.shell:install()
    if not shellInstalled.ok then
      if self.mod and self.mod.exports then self.mod.exports.cleanUiHost = nil end
      return shellInstalled:unpack()
    end
    for _, unsubscribe in ipairs(shellInstalled.value or {}) do
      self.subscriptions[#self.subscriptions + 1] = unsubscribe
    end
    local presentationInstalled = self.presentation:install()
    if not presentationInstalled.ok then
      if self.mod and self.mod.exports then self.mod.exports.cleanUiHost = nil end
      return presentationInstalled:unpack()
    end
    for _, unsubscribe in ipairs(presentationInstalled.value or {}) do
      self.subscriptions[#self.subscriptions + 1] = unsubscribe
    end
    self:installStartMenuHook()
    self.installed = true
    return true
  end

  function self:uninstall()
    self.pipeline:restore("uninstall")
    if self.presentation then self.presentation:clear("uninstall") end
    for _, unsubscribe in ipairs(self.subscriptions) do pcall(unsubscribe) end
    self.subscriptions = {}
    self.sessions:clear()
    if self.mod and self.mod.exports and self.mod.exports.cleanUiHost == self.host then
      self.mod.exports.cleanUiHost = nil
    end
    self.installed = false
    return true
  end

  function self:galleryPayload(filter)
    if self.provider.openGallery then
      return self.provider.openGallery(self.provider, filter)
    end
    return self.gallery:list(type(filter) == "table" and filter or nil)
  end

  function self:openShell(view, game, payload)
    game = game or (self.mod and self.mod.game)
    if self.shell and game then return self.shell:open(game, view, payload) end
    return nil, "shell_unavailable", "Clean UI shell is unavailable"
  end

  function self:openGallery(filter)
    local payload = self:galleryPayload(filter)
    local game = type(filter) == "table" and filter.game or nil
    if self.shell and (game or (self.mod and self.mod.game)) then
      return self:openShell("gallery", game, payload)
    end
    return payload
  end

  function self:resetDefaults()
    return Settings.reset(self.mod, self.settingsSchema):unpack()
  end

  function self:setting(key, fallback)
    return Settings.get(self.mod, key, self.settingsSchema, fallback)
  end

  function self:setSetting(key, value)
    return Settings.set(self.mod, key, value, self.settingsSchema)
  end

  function self:themeFor(themeId, darkMode)
    if darkMode == nil then darkMode = self:setting("dark_mode", false) end
    return self.themes:resolve(themeId or self:setting("theme", "clean"),
      darkMode)
  end

  function self:composeStartMenu(items, game)
    return StartMenu.compose(items, self.catalog, self.pins, {
      activate = function(key, selectedGame)
        return self:activateModMenu(key, { game = selectedGame or game })
      end,
      openModMenus = function(selectedGame)
        return self:openShell("mod_menus", selectedGame or game)
      end,
    })
  end

  function self:modMenuRows() return self.modMenus:rows() end
  function self:activateModMenu(key, context)
    return self.modMenus:activate(key, context):unpack()
  end
  function self:togglePin(key)
    return self.modMenus:togglePin(key):unpack()
  end

  -- These methods form the small embedding bridge used by Clean UI Studio.
  -- They deliberately run the same contract/model/layout/render pipeline as a
  -- product host, so the editor cannot drift into a second V3 implementation.
  function self:validateV3(contract)
    local result = Contract.validate(self.provider.productId, contract,
      self.provider.game)
    if result.ok then return {} end
    local error = result.error or {}
    return { { severity = "error", code = error.code or "invalid_contract",
      path = "contract", message = error.message or "Contract is invalid." } }
  end

  local function v3Model(screen)
    local model = Content.v3Model(screen)
    if not model then return nil, "invalid_model", "screen is not a V3 presentation" end
    local valid, code, message = PresentationModel.validate(model)
    if not valid then return nil, code, message end
    return model
  end

  local function v3Font(presentation, policy, supplied)
    if supplied then return supplied end
    local font = presentation.fonts and presentation.fonts:get(policy)
    if font then return font end
    if love and love.graphics and love.graphics.newFont then
      return love.graphics.newFont(policy.physicalPx or 15)
    end
  end

  function self:measureV3(screen, width, height, options)
    options = options or {}
    local model, modelCode, modelMessage = v3Model(screen)
    if not model then return nil, modelCode, modelMessage end
    local viewport = options.viewport or { x = 0, y = 0, w = width, h = height }
    local safeArea = options.safeArea or viewport
    local solved = self.presentation:solveModel(model, {
      preset = model.preset, viewport = viewport, safeArea = safeArea,
      uiSize = options.uiSize or "auto", textSize = options.textSize or "auto",
      fontFamily = options.fontFamily or "openttd_mono",
      density = options.density or "auto",
    })
    if not solved.ok then
      local error = solved.error or {}
      return nil, error.code, error.message
    end
    local font = v3Font(self.presentation, solved.value.font, options.font)
    if not font then return nil, "font_unavailable", "V3 preview font is unavailable" end
    local layout, code, message = self.presentation:measureModel(solved.value,
      model, font, options.density or "auto")
    if not layout then return nil, code, message end
    layout.v3Model, layout.v3Font = model, font
    return layout
  end

  function self:drawV3(g, screen, layout, options)
    options = options or {}
    local model, modelCode, modelMessage = v3Model(screen)
    if not model then return nil, modelCode, modelMessage end
    model = layout and layout.v3Model or model
    local font = options.font or (layout and layout.v3Font)
    if not font then
      local solved = self.presentation:solveModel(model, {
        preset = model.preset, viewport = options.viewport or { x = 0, y = 0,
          w = layout and layout.outer.w or 640, h = layout and layout.outer.h or 360 },
        safeArea = options.safeArea or options.viewport,
        uiSize = options.uiSize or "auto", textSize = options.textSize or "auto",
        fontFamily = options.fontFamily or "openttd_mono",
        density = options.density or "auto",
      })
      if solved.ok then font = v3Font(self.presentation, solved.value.font) end
    end
    if not font then return nil, "font_unavailable", "V3 preview font is unavailable" end
    local requestedDark = options.darkMode
    if requestedDark == nil then requestedDark = options.dark_mode end
    local theme = self:themeFor(options.theme or self:setting("theme", "clean"),
      requestedDark)
    return self.presentation:drawModel(model, layout, font, theme)
  end

  function self:renderV3(screen, width, height, options)
    return self:measureV3(screen, width, height, options)
  end

  function self:refreshMenuCatalog(sourceItems, game, baseSignatures)
    self.catalog:removeWhere(function(record) return record.fromHook == true end)
    self.catalog:removeOwner(self.provider.productId)
    local builtins = {
      { id = "clean_ui_settings", label = "CLEAN UI SETTINGS",
        action = function(context)
          return self:openShell("settings", context and context.game or game)
        end },
      { id = "ui_gallery", label = "UI GALLERY",
        action = function(context)
          return self:openGallery({ game = context and context.game or game })
        end },
    }
    for _, entry in ipairs(builtins) do
      local added = self.catalog:add(self.provider.productId, entry)
      if added.ok and self.catalog.records[added.value] then
        self.catalog.records[added.value].builtin = true
      end
    end
    local remaining = {}
    for signature, count in pairs(baseSignatures or {}) do remaining[signature] = count end
    local hookItems, labels = {}, {}
    local function signature(item)
      return table.concat({ tostring(item.id or ""), tostring(item.value or ""),
        tostring(item.label or item.text or "") }, "\0")
    end
    for index, item in ipairs(sourceItems or {}) do
      local sig = signature(item)
      if (remaining[sig] or 0) > 0 then
        remaining[sig] = remaining[sig] - 1
      elseif not item.cleanUiInternal and (type(item.onSelect) == "function"
          or type(item.action) == "function") then
        hookItems[#hookItems + 1] = { item = item, index = index }
        local label = item.label or item.text
        if type(label) == "string" then labels[label] = (labels[label] or 0) + 1 end
      end
    end
    for _, candidate in ipairs(hookItems) do
      local item, index = candidate.item, candidate.index
      local callback = item.onSelect or item.action
      local label = item.label or item.text
      if type(label) == "string" then
        local added = self.catalog:add(tostring(item.ownerId or "legacy_hook"), {
          id = item.id, label = label,
          compatibilityKey = item.id == nil and labels[label] == 1,
          action = function(context)
            return callback(context and context.game or game)
          end,
          priority = item.priority or index,
        })
        if added.ok and self.catalog.records[added.value] then
          self.catalog.records[added.value].fromHook = true
        end
      end
    end
    for _, extension in ipairs(self.registry:menuExtensions()) do
      if type(extension.actionCallback) == "function" then
        self.catalog:add(extension.ownerId, {
          id = extension.id, label = extension.label,
          action = extension.actionCallback, priority = extension.priority,
          actions = extension.actionTable,
        })
      end
    end
    local rows = self.catalog:list()
    if self.provider.addProductMenuEntries then
      local ok, value = pcall(self.provider.addProductMenuEntries, self, rows)
      if ok and type(value) == "table" then rows = value end
    end
    return rows
  end

  function self:installStartMenuHook()
    if not (self.mod and self.mod.hooks and self.mod.hooks.wrap) then
      return nil, "hooks_unavailable"
    end
    local unsubscribe = self.mod.hooks:wrap("ui.start_menu.items",
      function(nextFn, game, items)
        local baseSignatures = {}
        for _, item in ipairs(type(items) == "table" and items or {}) do
          local signature = table.concat({ tostring(item.id or ""),
            tostring(item.value or ""), tostring(item.label or item.text or "") }, "\0")
          baseSignatures[signature] = (baseSignatures[signature] or 0) + 1
        end
        local source = nextFn(game, items)
        if type(source) ~= "table" then return source end
        self:refreshMenuCatalog(source, game, baseSignatures)
        return self:composeStartMenu(source, game)
      end, 100000)
    self.subscriptions[#self.subscriptions + 1] = unsubscribe
    return true
  end

  function self:bounds(layout) return Bounds.collect(layout) end
  return self
end

return Core
