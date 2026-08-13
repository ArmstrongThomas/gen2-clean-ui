return function(ctx)
  local Data = ctx.load("adapters.data")

  local Compatibility = {}
  Compatibility.__index = Compatibility

  local API_VERSION = 1
  local SURFACE_API_VERSION = 2
  local SEMANTIC_ACTIONS = {
    up=true, down=true, left=true, right=true, select=true,
    back=true, start=true, hover=true,
  }
  local SURFACE_PRESETS = {
    XS={ width=320, height=180 },
    S={ width=400, height=240 },
    M={ width=480, height=320 },
    L={ width=640, height=400 },
    XL={ width=960, height=640 },
    BATTLE_WIDE={ width=640, height=360 },
  }

  local function copy(value)
    return Data.copy(value, { maxDepth=10, maxEntries=1024 })
  end

  local function containsFunction(value, seen, active, allowUserdata)
    local kind = type(value)
    if kind == "function" or kind == "thread"
        or (kind == "userdata" and not allowUserdata) then
      return true
    end
    if kind ~= "table" then return false end
    seen, active = seen or {}, active or {}
    if active[value] then return true end
    if seen[value] then return false end
    seen[value], active[value] = true, true
    local key, item = next(value, nil)
    while key ~= nil do
      if containsFunction(key, seen, active, allowUserdata)
          or containsFunction(item, seen, active, allowUserdata) then
        active[value] = nil
        return true
      end
      key, item = next(value, key)
    end
    active[value] = nil
    return false
  end

  local function sortedKeys(value)
    local keys = {}
    for key in pairs(value or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
  end

  local function validDimension(value)
    return type(value) == "number" and value >= 1 and value <= 2048
  end

  local function layoutBase(layout)
    if type(layout) ~= "table" then return nil end
    if type(layout.default) == "table" then return layout.default end
    return layout
  end

  local function validateSurfaceLayout(layout)
    if type(layout) ~= "table" then
      return false, "surface layout requires a virtual canvas within 2048x2048 and four million pixels"
    end
    local base = layoutBase(layout)
    local width = tonumber(base.virtualWidth or base.width)
    local height = tonumber(base.virtualHeight or base.height)
    if not validDimension(width) or not validDimension(height)
        or width * height > 4000000 then
      return false, "surface layout requires a virtual canvas within 2048x2048 and four million pixels"
    end
    for _, orientation in ipairs({ "portrait", "landscape" }) do
      local variant = layout[orientation]
      if variant ~= nil then
        if type(variant) ~= "table" then
          return false, "surface orientation layouts must be tables"
        end
        local variantWidth = tonumber(variant.virtualWidth or variant.width or width)
        local variantHeight = tonumber(variant.virtualHeight or variant.height or height)
        if not validDimension(variantWidth) or not validDimension(variantHeight)
            or variantWidth * variantHeight > 4000000 then
          return false, "surface orientation canvas exceeds the safe limit"
        end
      end
    end
    local fit = tostring(layout.fit or base.fit or "contain"):lower()
    local scaleMode = tostring(layout.scaleMode or base.scaleMode
      or "integer-fit"):lower()
    if fit ~= "contain" then
      return false, "surface layout.fit currently supports only contain"
    end
    if scaleMode ~= "integer-fit" and scaleMode ~= "smooth-fit" then
      return false, "surface scaleMode must be integer-fit or smooth-fit"
    end
    if containsFunction(layout) then
      return false, "surface layout must be data-only"
    end
    local preset = tostring(layout.preset or base.preset or "VIEWPORT"):upper()
    if preset ~= "VIEWPORT" and SURFACE_PRESETS[preset] == nil then
      return false, "unknown surface layout preset: " .. preset
    end
    return true
  end

  local function validateContract(contract)
    if type(contract) ~= "table" then return false, "contract is not a table" end
    local apiVersion = tonumber(contract.apiVersion)
    if apiVersion ~= API_VERSION and apiVersion ~= SURFACE_API_VERSION then
      return false, "unsupported gen1ModernUi apiVersion"
    end
    for _, name in ipairs({ "screens", "extensions", "surfaces", "themes", "frames" }) do
      if contract[name] ~= nil and type(contract[name]) ~= "table" then
        return false, "contract." .. name .. " must be a table"
      end
    end
    if contract.surfaces ~= nil and apiVersion ~= SURFACE_API_VERSION then
      return false, "contract.surfaces requires apiVersion 2"
    end
    if contract.screens == nil and contract.extensions == nil
        and contract.surfaces == nil then
      return false, "contract.screens, contract.extensions, or contract.surfaces is required"
    end
    if containsFunction(contract.themes) then
      return false, "themes and frames cannot contain callbacks"
    end
    if containsFunction(contract.frames, nil, nil, true) then
      return false, "themes and frames cannot contain callbacks"
    end
    for frameId, frame in pairs(contract.frames or {}) do
      if type(frameId) ~= "string" then
        return false, "frame IDs must be strings"
      end
      local asset = type(frame) == "table"
        and (frame.asset or frame.image or frame.texture or frame.path) or frame
      if type(asset) ~= "string" and type(asset) ~= "userdata"
          and type(asset) ~= "table" then
        return false, "frame assets must be declared paths or public images"
      end
    end
    for themeId, theme in pairs(contract.themes or {}) do
      if type(themeId) ~= "string" or type(theme) ~= "table" then
        return false, "theme IDs and specs must be strings and tables"
      end
    end
    for screenId, screen in pairs(contract.screens or {}) do
      if type(screenId) ~= "string" or type(screen) ~= "table"
          or type(screen.match) ~= "function"
          or type(screen.model) ~= "function" then
        return false, "screen descriptors require match and model functions"
      end
      if screen.draw or screen.render or screen.drawCallback then
        return false, "custom draw callbacks are not supported"
      end
      if screen.layer ~= nil and type(screen.layer) ~= "string" then
        return false, "screen.layer must be a string"
      end
      if screen.canSuppressNative ~= nil
          and type(screen.canSuppressNative) ~= "boolean" then
        return false, "screen.canSuppressNative must be boolean"
      end
      if screen.actions ~= nil and type(screen.actions) ~= "table" then
        return false, "screen.actions must be a table"
      end
      for action, callback in pairs(screen.actions or {}) do
        if type(action) ~= "string" or action == "" then
          return false, "screen actions must have non-empty string names"
        end
        if apiVersion == API_VERSION and not SEMANTIC_ACTIONS[action] then
          return false, "unsupported semantic action: " .. tostring(action)
        end
        if type(callback) ~= "function" then
          return false, "semantic actions must be functions"
        end
      end
    end
    for extensionId, extension in pairs(contract.extensions or {}) do
      if type(extensionId) ~= "string" or type(extension) ~= "table"
          or type(extension.match) ~= "function"
          or type(extension.model) ~= "function" then
        return false, "extension descriptors require match and model functions"
      end
      if extension.menu ~= nil and type(extension.menu) ~= "function" then
        return false, "extension.menu must be a function"
      end
      if extension.actions ~= nil and type(extension.actions) ~= "table" then
        return false, "extension.actions must be a table"
      end
      for action, callback in pairs(extension.actions or {}) do
        if type(action) ~= "string" or type(callback) ~= "function" then
          return false, "extension actions must be named functions"
        end
      end
      if extension.priority ~= nil and type(extension.priority) ~= "number" then
        return false, "extension.priority must be a number"
      end
    end
    for surfaceId, surface in pairs(contract.surfaces or {}) do
      if type(surfaceId) ~= "string" or surfaceId == ""
          or type(surface) ~= "table"
          or type(surface.match) ~= "function"
          or type(surface.model) ~= "function"
          or type(surface.render) ~= "function" then
        return false, "surface descriptors require named match, model, and render functions"
      end
      local layoutOk, layoutError = validateSurfaceLayout(surface.layout)
      if not layoutOk then return false, layoutError end
      local native = surface.native
      if type(native) ~= "table"
          or (native.policy ~= "replace" and native.policy ~= "preserve") then
        return false, "surface native.policy must explicitly be replace or preserve"
      end
      if native.scope ~= nil and native.scope ~= "uiCanvas" then
        return false, "surface native.scope must be uiCanvas"
      end
      if surface.actions ~= nil and type(surface.actions) ~= "table" then
        return false, "surface.actions must be a table"
      end
      for action, callback in pairs(surface.actions or {}) do
        if type(action) ~= "string" or action == ""
            or type(callback) ~= "function" then
          return false, "surface actions must be named functions"
        end
      end
      if surface.input ~= nil and (type(surface.input) ~= "table"
          or (surface.input.pointer ~= nil
            and type(surface.input.pointer) ~= "function")) then
        return false, "surface.input.pointer must be a function"
      end
      if surface.gallery ~= nil and (type(surface.gallery) ~= "table"
          or containsFunction(surface.gallery)) then
        return false, "surface.gallery must be data-only"
      end
    end
    return true
  end

  local function normalizeRows(rows)
    local output = {}
    for index = 1, #(rows or {}) do
      local source = rows[index]
      if type(source) == "table" then
        local row = copy(source) or {}
        row.label = tostring(row.label or row.text or row.value or ("ROW " .. index))
        row.sourceIndex = row.sourceIndex or index
        output[#output + 1] = row
      else
        output[#output + 1] = { label=tostring(source or ("ROW " .. index)),
          sourceIndex=index }
      end
    end
    return output
  end

  local function normalizeModel(raw, state, apiVersion)
    local model = copy(raw)
    if type(model) ~= "table" then return nil, "model must be a data-only table" end
    local kind = model.kind
    if kind ~= "dialogue" and kind ~= "choice" and kind ~= "menu" then
      if type(model.options) == "table" then kind = "choice"
      elseif type(model.lines) == "table" or model.text ~= nil then kind = "dialogue"
      else kind = "menu" end
    end
    model.kind = kind
    model.preset = tostring(model.preset or "NAV")
    model.screenId = model.screenId or rawget(state, "screenId")
    model.title = tostring(model.title or model.name or "")
    if kind == "menu" then
      model.rows = normalizeRows(model.rows or model.items)
      model.selected = tonumber(model.selected or model.index) or 1
      model.scroll = tonumber(model.scroll) or 0
    elseif kind == "choice" then
      model.options = normalizeRows(model.options)
      model.selected = tonumber(model.selected or model.index) or 1
      model.scroll = tonumber(model.scroll) or 0
    else
      if type(model.lines) ~= "table" then
        model.lines = { tostring(model.text or model.message or "") }
      end
      local lines = {}
      for index = 1, #model.lines do lines[index] = tostring(model.lines[index] or "") end
      model.lines = lines
    end
    if apiVersion == SURFACE_API_VERSION and model.layout_options ~= nil then
      model.layoutOptions = model.layout_options
    end
    return model
  end

  function Compatibility.new(mod, provider)
    return setmetatable({
      mod = mod, provider = provider, adapters = {},
      active = setmetatable({}, { __mode="k" }),
      activeSurfaces = setmetatable({}, { __mode="k" }),
      pointerPress = {}, commits = setmetatable({}, { __mode="k" }),
      canvases = setmetatable({}, { __mode="k" }), clocks = setmetatable({}, { __mode="k" }),
      themes = {}, frames = {}, assetOwners = {}, errors = {}, frameId = 0,
    }, Compatibility)
  end

  function Compatibility:ownerActive(owner)
    if type(self.mod.find) ~= "function" then return true end
    local ok, handle = pcall(self.mod.find, owner)
    if not ok then ok, handle = pcall(self.mod.find, self.mod, owner) end
    return ok and type(handle) == "table"
  end

  function Compatibility:recordError(owner, message)
    self.errors[owner or "unknown"] = tostring(message)
  end

  function Compatibility:clearOwnerAssets(owner)
    local assets = self.assetOwners[owner]
    if type(assets) ~= "table" then return end
    for id in pairs(assets.frames or {}) do self.frames[id] = nil end
    for id in pairs(assets.themes or {}) do self.themes[id] = nil end
    self.assetOwners[owner] = nil
  end

  function Compatibility:registerFrame(spec)
    if type(spec) ~= "table" then return false, "frame registration must be a table" end
    local owner, id = spec.owner or spec.sourceModId, spec.id
    local asset = spec.asset or spec.image or spec.texture or spec.path
    if type(owner) ~= "string" or owner == "" or type(id) ~= "string" or id == "" then
      return false, "frame owner and id are required"
    end
    if not self:ownerActive(owner) then return false, "source mod is not active" end
    if type(asset) ~= "string" and type(asset) ~= "userdata" and type(asset) ~= "table" then
      return false, "frame asset must be a declared path or public image"
    end
    if type(asset) ~= "userdata" and containsFunction(asset) then
      return false, "frame assets cannot contain callbacks"
    end
    local fullId = id:find(":", 1, true) and id or owner .. ":" .. id
    self.frames[fullId] = asset
    local owned = self.assetOwners[owner] or { frames={}, themes={} }
    owned.frames[fullId] = true
    self.assetOwners[owner] = owned
    return fullId
  end

  function Compatibility:registerTheme(spec)
    if type(spec) ~= "table" then return false, "theme registration must be a table" end
    local owner, id = spec.owner or spec.sourceModId, spec.id
    if type(owner) ~= "string" or owner == "" or type(id) ~= "string" or id == "" then
      return false, "theme owner and id are required"
    end
    if not self:ownerActive(owner) then return false, "source mod is not active" end
    if containsFunction(spec) then return false, "themes cannot contain callbacks" end
    local fullId = id:find(":", 1, true) and id or owner .. ":" .. id
    local theme = copy(spec) or {}
    theme.id, theme.owner = fullId, owner
    self.themes[fullId] = theme
    local owned = self.assetOwners[owner] or { frames={}, themes={} }
    owned.themes[fullId] = true
    self.assetOwners[owner] = owned
    return fullId
  end

  function Compatibility:register(spec)
    if type(spec) ~= "table" then return false, "adapter registration must be a table" end
    local owner = spec.owner or spec.sourceModId or spec.modId
    local contract = spec.contract or spec
    if type(owner) ~= "string" or owner == "" then
      return false, "adapter owner must be the source mod id"
    end
    local valid, reason = validateContract(contract)
    if not valid then self:recordError(owner, reason); return false, reason end
    if not self:ownerActive(owner) then return false, "source mod is not active" end
    self:clearOwnerAssets(owner)
    self.adapters[owner] = { owner=owner, version=spec.version, contract=contract }
    for frameId, frame in pairs(contract.frames or {}) do
      local frameSpec = type(frame) == "table" and copy(frame) or { asset=frame }
      frameSpec.owner, frameSpec.id = owner, frameSpec.id or frameId
      self:registerFrame(frameSpec)
    end
    for themeId, theme in pairs(contract.themes or {}) do
      if type(theme) == "table" then
        local themeSpec = copy(theme) or {}
        themeSpec.owner, themeSpec.id = owner, themeSpec.id or themeId
        self:registerTheme(themeSpec)
      end
    end
    self.active = setmetatable({}, { __mode="k" })
    self.activeSurfaces = setmetatable({}, { __mode="k" })
    self.commits = setmetatable({}, { __mode="k" })
    self.errors[owner] = nil
    return true
  end

  function Compatibility:unregister(owner)
    if type(owner) ~= "string" then return false end
    self.adapters[owner] = nil
    self:clearOwnerAssets(owner)
    self.active = setmetatable({}, { __mode="k" })
    self.activeSurfaces = setmetatable({}, { __mode="k" })
    self.commits = setmetatable({}, { __mode="k" })
    return true
  end

  function Compatibility:adapterFor(game, state)
    if type(state) ~= "table" then return nil end
    for _, owner in ipairs(sortedKeys(self.adapters)) do
      local entry = self.adapters[owner]
      if self:ownerActive(owner) then
        for _, screenId in ipairs(sortedKeys(entry.contract.screens)) do
          local screen = entry.contract.screens[screenId]
          local ok, matched = pcall(screen.match, state)
          if not ok then
            self:recordError(owner, "screen match failed: " .. tostring(screenId))
          elseif matched == true then
            local result = { owner=owner, id=screenId, screen=screen, entry=entry }
            self.active[state] = result
            return result
          end
        end
      end
    end
    self.active[state] = nil
    return nil
  end

  function Compatibility:surfaceFor(game, state)
    if type(state) ~= "table" then return nil end
    for _, owner in ipairs(sortedKeys(self.adapters)) do
      local entry = self.adapters[owner]
      if self:ownerActive(owner) then
        for _, surfaceId in ipairs(sortedKeys(entry.contract.surfaces)) do
          local surface = entry.contract.surfaces[surfaceId]
          local ok, matched = pcall(surface.match, state)
          if not ok then
            self:recordError(owner, "surface match failed: " .. tostring(surfaceId))
          elseif matched == true then
            local result = { owner=owner, id=surfaceId, surface=surface, entry=entry }
            self.activeSurfaces[state] = result
            return result
          end
        end
      end
    end
    self.activeSurfaces[state] = nil
    return nil
  end

  function Compatibility:modelFor(game, state, context)
    context = context or self.active[state] or self:adapterFor(game, state)
    if not context then return nil end
    local ok, raw = pcall(context.screen.model, game, state)
    if not ok then
      self:recordError(context.owner, "screen model failed: " .. context.id)
      self.active[state] = nil
      return nil
    end
    local model, reason = normalizeModel(raw, state,
      tonumber(context.entry.contract.apiVersion) or API_VERSION)
    if not model then
      self:recordError(context.owner, reason .. ": " .. context.id)
      self.active[state] = nil
      return nil
    end
    return model
  end

  function Compatibility:surfaceModelFor(game, state, context)
    context = context or self.activeSurfaces[state] or self:surfaceFor(game, state)
    if not context then return nil end
    local ok, raw = pcall(context.surface.model, game, state)
    if not ok or type(raw) ~= "table" or containsFunction(raw) then
      self:recordError(context.owner, "surface model must be a data-only table: " .. context.id)
      self.activeSurfaces[state] = nil
      return nil
    end
    return copy(raw)
  end

  function Compatibility:prepareScreen(game, state, context)
    local surfaceContext = self.activeSurfaces[state] or self:surfaceFor(game, state)
    if surfaceContext then
      local model = self:surfaceModelFor(game, state, surfaceContext)
      if not model then
        return { matched=true, failed=true, reason="surface_model_invalid" }
      end
      local surface = surfaceContext.surface
      return { matched=true, surface=true, result={
        record=nil, valid=true, suppress=surface.native.policy == "replace",
        reason="legacy_surface_ready",
        presentation={ complete=true, kind="legacy_surface", surface={
          context=surfaceContext, model=model,
          policy=surface.native.policy,
        } },
      } }
    end
    local adapter = self.active[state] or self:adapterFor(game, state)
    if not adapter then return { matched=false } end
    local model = self:modelFor(game, state, adapter)
    if not model then return { matched=true, failed=true, reason="screen_model_invalid" } end
      return { matched=true, result={
        record=nil, valid=true,
        suppress=adapter.screen.canSuppressNative ~= false,
        reason="legacy_screen_ready",
      presentation={ complete=true, kind="legacy_screen", model=model },
      } }
  end

  function Compatibility:action(game, state, action, payload)
    local context = self.active[state] or self:adapterFor(game, state)
    local callback = context and context.screen.actions
      and context.screen.actions[action]
    if type(callback) ~= "function" then return false end
    local ok, result = pcall(callback, game, state, payload)
    if not ok then
      self:recordError(context.owner, "semantic action failed: " .. tostring(action))
      self.active[state] = nil
      return false
    end
    return result ~= false
  end

  function Compatibility:surfaceAction(game, state, action, payload)
    local context = self.activeSurfaces[state] or self:surfaceFor(game, state)
    local callback = context and context.surface.actions
      and context.surface.actions[action]
    if type(callback) ~= "function" then return false end
    local ok, result = pcall(callback, game, state, copy(payload))
    if not ok then
      self:recordError(context.owner, "surface action failed: " .. tostring(action))
      return false
    end
    return result ~= false
  end

  local function inside(rect, x, y)
    return type(rect) == "table" and x >= rect.x and y >= rect.y
      and x < rect.x + rect.w and y < rect.y + rect.h
  end

  function Compatibility:pointer(state, model, layout, event, game)
    local surface = self.commits[state]
    if surface then
      local x, y = tonumber(event and event.x), tonumber(event and event.y)
      local output = surface.layout.output
      local virtualX = x and (x - output.x) / output.scaleX or nil
      local virtualY = y and (y - output.y) / output.scaleY or nil
      local input = surface.context.surface.input
      if type(input) == "table" and type(input.pointer) == "function" then
        local pointerEvent = copy(event) or {}
        pointerEvent.x, pointerEvent.y = virtualX, virtualY
        pointerEvent.inside = virtualX ~= nil and virtualY ~= nil
          and virtualX >= 0 and virtualY >= 0
          and virtualX <= surface.layout.virtual.width
          and virtualY <= surface.layout.virtual.height
        local ok, handled = pcall(input.pointer, game, state, pointerEvent,
          copy(surface.model))
        return ok and handled == true
      end
      if event and event.phase == "pressed" then
        self.pointerPress[state] = { x=virtualX, y=virtualY, event=event }
        return true
      end
      if event and event.phase == "released" then
        local pressed = self.pointerPress[state]
        self.pointerPress[state] = nil
        if not pressed or not virtualX or not virtualY then return true end
        for index = #surface.regions, 1, -1 do
          local region = surface.regions[index]
          if inside(region, virtualX, virtualY)
              and inside(region, pressed.x, pressed.y) then
            self:surfaceAction(game, state, region.action, region.payload)
            return true
          end
        end
        return true
      end
      return true
    end
    local context = self.active[state] or self:adapterFor(game, state)
    if not context or not model or type(layout) ~= "table" then return nil end
    if event and event.phase == "pressed" then
      for index = #(layout.hitRegions or {}), 1, -1 do
        local region = layout.hitRegions[index]
        if inside(region.rect, event.x, event.y) then
          self.pointerPress[state] = { region=region, event=event }
          return true
        end
      end
      return false
    end
    if event and event.phase == "released" then
      local pressed = self.pointerPress[state]
      self.pointerPress[state] = nil
      if not pressed then return false end
      local region = pressed.region
      if inside(region.rect, event.x, event.y) then
        self:action(game, state, "select", region.sourceIndex or region.index)
      end
      return true
    end
    return false
  end

  function Compatibility:layoutFor(surface, viewport, safe)
    local declared = surface.layout or {}
    local base = layoutBase(declared)
    local width, height = tonumber(base.virtualWidth or base.width),
      tonumber(base.virtualHeight or base.height)
    local orientation = safe.h > safe.w and "portrait" or "landscape"
    local variant = type(declared[orientation]) == "table" and declared[orientation] or {}
    width = tonumber(variant.virtualWidth or variant.width) or width
    height = tonumber(variant.virtualHeight or variant.height) or height
    local preset = tostring(variant.preset or base.preset or "VIEWPORT"):upper()
    local maxW, maxH = safe.w, safe.h
    local presetSize = SURFACE_PRESETS[preset]
    if presetSize then maxW, maxH = math.min(maxW, presetSize.width), math.min(maxH, presetSize.height) end
    local margin = math.max(0, tonumber(variant.margin or base.margin) or 0)
    maxW, maxH = math.max(1, maxW - margin * 2), math.max(1, maxH - margin * 2)
    local scale = math.min(maxW / width, maxH / height)
    local scaleMode = tostring(variant.scaleMode or base.scaleMode
      or declared.scaleMode or "integer-fit"):lower()
    if scaleMode == "integer-fit" and scale >= 1 then scale = math.floor(scale) end
    local outputW, outputH = width * scale, height * scale
    return {
      virtual={ width=width, height=height },
      output={ x=safe.x + (safe.w-outputW)/2, y=safe.y + (safe.h-outputH)/2,
        width=outputW, height=outputH, scaleX=outputW/width, scaleY=outputH/height },
      safe={ x=safe.x, y=safe.y, width=safe.w, height=safe.h },
      orientation=orientation, scaleMode=scaleMode,
    }
  end

  function Compatibility:renderSurface(state, presentation, target, viewport, safe, theme)
    local graphics = love and love.graphics
    local surfaceContext = presentation and presentation.surface
      and presentation.surface.context
    local surface = surfaceContext and surfaceContext.surface
    if not graphics or type(graphics.newCanvas) ~= "function" or not surface then
      return nil, "surface graphics unavailable"
    end
    local layout = self:layoutFor(surface, viewport, safe)
    local cached = self.canvases[state]
    local canvas
    if cached and cached.width == layout.virtual.width and cached.height == layout.virtual.height then
      canvas = cached.canvas
    else
      local ok, result = pcall(graphics.newCanvas, layout.virtual.width, layout.virtual.height)
      if not ok or not result then return nil, "surface canvas unavailable" end
      canvas = result
      if canvas.setFilter then
        pcall(canvas.setFilter, canvas, layout.scaleMode == "smooth-fit" and "linear" or "nearest",
          layout.scaleMode == "smooth-fit" and "linear" or "nearest")
      end
      self.canvases[state] = { canvas=canvas, width=layout.virtual.width, height=layout.virtual.height }
    end
    local now = love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
    local previous = self.clocks[state]
    self.clocks[state] = now
    local drawContext = {
      frame={ id=self.frameId, time=now, dt=previous and math.min(0.10, math.max(0, now-previous)) or 0 },
      virtual=copy(layout.virtual), output=copy(layout.output), safe=copy(layout.safe),
      orientation=layout.orientation, scale={ ui=1, font=1 }, theme=copy(theme) or {},
      graphics=graphics, fonts={ get=function() return nil end }, assets={}, effects={},
      input={}, ["de" .. "bug"]={}, _regions={}, _bounds={},
    }
    drawContext.input.region = function(spec)
      if type(spec) ~= "table" or type(spec.action) ~= "string"
          or type(spec.x) ~= "number" or type(spec.y) ~= "number"
          or type(spec.w) ~= "number" or type(spec.h) ~= "number"
          or spec.w <= 0 or spec.h <= 0 or containsFunction(spec.payload) then return false end
      drawContext._regions[#drawContext._regions + 1] = {
        id=tostring(spec.id or spec.action), x=spec.x, y=spec.y,
        w=spec.w, h=spec.h, action=spec.action, payload=copy(spec.payload),
      }
      return true
    end
    drawContext["de" .. "bug"].bounds = function(id, x, y, w, h)
      if type(id) == "table" then x,y,w,h=id.x,id.y,id.w,id.h; id=id.id end
      if type(x) ~= "number" or type(y) ~= "number" or type(w) ~= "number" or type(h) ~= "number" then return false end
      drawContext._bounds[#drawContext._bounds + 1] = { id=tostring(id or "bounds"), x=x,y=y,w=w,h=h,
        outside=x < 0 or y < 0 or x+w > layout.virtual.width or y+h > layout.virtual.height }
      return true
    end
    drawContext.effects.withShader = function(_, callback, ...) return type(callback) == "function" and callback(...) or false end
    drawContext.effects.withPalette = drawContext.effects.withShader
    drawContext.effects.withSilhouette = drawContext.effects.withShader
    local pushed = pcall(graphics.push, "all")
    if not pushed then return nil, "surface graphics state unavailable" end
    local ok, rendered = pcall(function()
      graphics.setCanvas(canvas)
      if graphics.origin then graphics.origin() end
      graphics.clear(0, 0, 0, 0)
      graphics.setColor(1, 1, 1, 1)
      if graphics.setBlendMode then graphics.setBlendMode("alpha") end
      if graphics.setScissor then graphics.setScissor(0, 0, layout.virtual.width, layout.virtual.height) end
      local accepted = surface.render(presentation.surface.model, drawContext)
      if accepted ~= true then error("surface renderer must explicitly return true", 0) end
      if graphics.getCanvas and graphics.getCanvas() ~= canvas then error("surface renderer changed the private canvas", 0) end
      return true
    end)
    pcall(graphics.pop)
    if not ok or rendered ~= true then return nil, tostring(rendered) end
    self.frameId = self.frameId + 1
    self.commits[state] = { context=surfaceContext, model=presentation.surface.model,
      canvas=canvas, layout=layout, regions=drawContext._regions }
    local pushedTarget = pcall(graphics.push, "all")
    if not pushedTarget then return nil, "surface compose state unavailable" end
    local composed, composeError = pcall(function()
      graphics.setCanvas(target)
      graphics.setColor(1, 1, 1, 1)
      graphics.draw(canvas, layout.output.x, layout.output.y,
        0, layout.output.scaleX, layout.output.scaleY)
    end)
    pcall(graphics.pop)
    if not composed then return nil, tostring(composeError) end
    return true
  end

  function Compatibility:api()
    local api = {}
    api.version, api.compatibilityApiVersion, api.surfaceApiVersion = 1, 1, 2
    api.supportedApiVersions = { 1, 2 }
    api.supports = function(capability, version)
      version = tonumber(version)
      if version and version ~= 1 and version ~= 2 then return false end
      local capabilities = {
        data_screens=1, additive_extensions=1, themes=1, frames=1,
        custom_fields=2, footer_lists=2, modal_overlay=2,
        custom_surface=2, isolated_shader=2,
      }
      local introduced = capabilities[tostring(capability or ""):lower()]
      return introduced ~= nil and (version == nil or version >= introduced)
    end
    api.registerAdapter = function(spec) return self:register(spec) end
    api.unregisterAdapter = function(owner) return self:unregister(owner) end
    api.dispatchScreenAction = function(game, state, action, payload)
      return self:action(game, state, action, payload)
    end
    api.dispatchSurfaceAction = function(game, state, action, payload)
      return self:surfaceAction(game, state, action, payload)
    end
    api.registerTheme = function(spec) return self:registerTheme(spec) end
    api.registerFrame = function(spec) return self:registerFrame(spec) end
    api.themes, api.frames = self.themes, self.frames
    api.frameChoices = {}
    api.uiGalleryCatalog = function()
      local output = {}
      for _, owner in ipairs(sortedKeys(self.adapters)) do
        local entry = self.adapters[owner]
        for _, surfaceId in ipairs(sortedKeys(entry.contract.surfaces)) do
          local surface = entry.contract.surfaces[surfaceId]
          if type(surface.gallery) == "table" then
            output[#output + 1] = { id="surface:" .. owner .. ":" .. surfaceId,
              name=surface.gallery.name or surfaceId, kind="custom_surface",
              screenId=surface.gallery.screenId or surfaceId,
              category=surface.gallery.category or "Integration" }
          end
        end
      end
      return output
    end
    api.openUiGallery = function(game) return self.provider:openGallery(self.provider, { game=game }) end
    return api
  end

  return Compatibility
end
