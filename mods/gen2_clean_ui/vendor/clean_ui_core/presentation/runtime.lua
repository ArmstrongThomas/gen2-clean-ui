local requireCore = ...
local Data = requireCore("foundation.data")
local Result = requireCore("foundation.result")
local Viewport = requireCore("geometry.viewport")
local FontCatalog = requireCore("text.font_catalog")
local Solver = requireCore("layout.solver")
local Transaction = requireCore("surfaces.transaction")
local PresentationModel = requireCore("presentation.model")
local MenuLayout = requireCore("presentation.menu_layout")
local MenuRender = requireCore("presentation.menu_render")
local DialogueLayout = requireCore("presentation.dialogue_layout")
local DialogueRender = requireCore("presentation.dialogue_render")
local BattleLayout = requireCore("presentation.battle_layout")
local BattleRender = requireCore("presentation.battle_render")
local AnimationLayout = requireCore("presentation.animation_layout")
local AnimationRender = requireCore("presentation.animation_render")
local DocumentLayout = requireCore("presentation.document_layout")
local DocumentRender = requireCore("presentation.document_render")
local Bounds = requireCore("diagnostics.bounds")

local Runtime = {}

-- Keep the V3 pointer pipeline available for future work, but do not expose
-- or activate it until the screen families have reliable pointer behavior.
local POINTER_TOUCH_ENABLED = false

-- The v0.1.86 visibility seam passes a live screen state while newer hosts
-- pass the game through the dedicated prepare seam. Resolve both forms so a
-- recreated child state cannot lose the prepared clean candidate.
local function gameFromState(state)
  if type(state) ~= "table" then return nil end
  local ok, game = pcall(function() return state.game end)
  return ok and type(game) == "table" and game or nil
end

local function gameFromMod(mod)
  if type(mod) ~= "table" then return nil end
  local ok, game = pcall(function() return mod.game end)
  return ok and type(game) == "table" and game or nil
end

local function inside(outer, rect)
  return type(rect) == "table"
    and rect.x >= outer.x and rect.y >= outer.y
    and rect.x + rect.w <= outer.x + outer.w
    and rect.y + rect.h <= outer.y + outer.h
end

local function overlaps(first, second)
  return type(first) == "table" and type(second) == "table"
    and first.x < second.x + second.w and second.x < first.x + first.w
    and first.y < second.y + second.h and second.y < first.y + first.h
end

local function battleFontMetrics(font)
  local height = tonumber(font and font.physicalPx) or 15
  return {
    getHeight = function() return height end,
    getWidth = function(_, value)
      return #tostring(value or "") * height * 0.55
    end,
  }
end

local function battleFits(envelope, model, font, density)
  local measured = BattleLayout.measure(envelope, model,
    battleFontMetrics(font), density)
  if not measured or not inside(measured.inner, measured.field)
      or not inside(measured.field, measured.hud)
      or not inside(measured.field, measured.arena)
      or not inside(measured.inner, measured.panel)
      or measured.overlaps.cardSprite then
    return false
  end
  if not inside(measured.field, measured.enemyCard)
      or not inside(measured.field, measured.playerCard)
      or not inside(measured.arena, measured.enemySprite)
      or not inside(measured.arena, measured.playerSprite) then
    return false
  end
  local minimumArena = math.max(24 * (envelope.scale or 1),
    measured.fontHeight + measured.gap)
  local minimumCard = measured.fontHeight + measured.gap * 2
  if measured.arena.h < minimumArena
      or measured.enemyCard.h < minimumCard
      or measured.playerCard.h < minimumCard then
    return false
  end
  if overlaps(measured.enemyCard, measured.playerCard)
      or overlaps(measured.enemySprite, measured.playerSprite) then
    return false
  end
  for _, region in ipairs(measured.hitRegions or {}) do
    if not inside(measured.panel, region.rect) then return false end
    if region.role == "battle_action"
        and region.rect.h < measured.fontHeight then
      return false
    end
  end
  return true
end

function Runtime.new(core)
  local self = { core=core, mod=core.mod, provider=core.provider,
    candidate=nil, canvas=nil, canvasW=nil, canvasH=nil,
    menuWidths=setmetatable({}, { __mode = "k" }), frameId=0,
    frameSerial=0, lastGame=nil,
    debugContainers=false, debugAssets=false, debugKeys={} }
  self.fonts = FontCatalog.new(love and love.graphics,
    core.fontPaths or {
      plainPixel = core.config.plainPixelPath
        or "assets/fonts/plainpixel/PlainPixel-Regular.ttf",
    })
  local function fitsCandidate(envelope, model, policy, density, priorEntries)
    local _, font = self.fonts:resolve(policy)
    if not font then return false end
    if model.kind == "document" then
      return DocumentLayout.fits(envelope, model, font, density)
    elseif model.kind == "menu" or model.kind == "device"
        or model.kind == "map" then
      return MenuLayout.fits(envelope, model, font, density)
    elseif model.kind == "dialogue" or model.kind == "choice" then
      return DialogueLayout.fits(envelope, model, font, density, priorEntries)
    elseif model.kind == "animation" then
      return AnimationLayout.fits(envelope, model, font, density)
    elseif model.kind == "battle" then
      return battleFits(envelope, model, font, density)
    end
    return true
  end
  local sourceImage = core.mod and core.mod.ui and core.mod.ui.sourceImage
  local assetApi = core.mod and core.mod.assets
  local function generatedPng(path)
    return type(path) == "string"
      and path:sub(1, 17) == "assets/generated/"
      and not path:find("..", 1, true)
      and not path:find("\\", 1, true)
      and not path:find(":", 1, true)
      and path:lower():match("%.png$") ~= nil
  end
  local function resolveAssetPath(assetPath)
    if type(assetPath) == "string"
        and assetPath:sub(1, 14) == "clean_ui_core/" then
      return "vendor/clean_ui_core/" .. assetPath:sub(15)
    end
    return assetPath
  end
  MenuRender.setSourceImageLoader(function(path, assetPath)
    local resolvedAssetPath = resolveAssetPath(assetPath)
    if type(sourceImage) == "function" then
      local ok, image = pcall(sourceImage, path, resolvedAssetPath)
      if ok and image ~= nil then return image end
    end
    if type(resolvedAssetPath) == "string" and assetApi
        and type(assetApi.image) == "function" then
      local ok, image = pcall(assetApi.image, assetApi, resolvedAssetPath)
      if ok and image ~= nil then return image end
    end
    if type(resolvedAssetPath) == "string" and assetApi
        and type(assetApi.path) == "function"
        and love and love.graphics
        and type(love.graphics.newImage) == "function" then
      local ok, fullPath = pcall(assetApi.path, assetApi, resolvedAssetPath)
      if ok and type(fullPath) == "string" then
        local imageOk, image = pcall(love.graphics.newImage, fullPath)
        if imageOk and image ~= nil then return image end
      end
    end
    if type(resolvedAssetPath) == "string"
        and resolvedAssetPath:sub(1, 21) == "vendor/clean_ui_core/"
        and core.mod and type(core.mod.path) == "string"
        and love and love.graphics
        and type(love.graphics.newImage) == "function" then
      local fullPath = core.mod.path .. "/" .. resolvedAssetPath
      local imageOk, image = pcall(love.graphics.newImage, fullPath)
      if imageOk and image ~= nil then return image end
    end
    if generatedPng(path) and love and love.graphics
        and type(love.graphics.newImage) == "function" then
      return love.graphics.newImage(path)
    end
    return nil, "invalid_source_image"
  end)

  function self:enabled()
    return type(self.provider.visibleStack) == "function"
      and type(self.provider.prepareScreen) == "function"
  end

  function self:clear(reason)
    self.candidate = nil
    self.lastReason = reason
  end

  function self:invalidate(reason)
    self:clear(reason or "invalidated")
    self.canvas, self.canvasW, self.canvasH = nil, nil, nil
  end

  function self:canvasFor(w, h)
    if self.canvas and self.canvasW == w and self.canvasH == h then
      return self.canvas
    end
    local G = love and love.graphics
    if not (G and G.newCanvas) then return nil, "canvas_unavailable" end
    local ok, canvas = pcall(G.newCanvas, w, h, { dpiscale=1 })
    if not ok then ok, canvas = pcall(G.newCanvas, w, h) end
    if not ok or not canvas then return nil, tostring(canvas) end
    if canvas.setFilter then pcall(canvas.setFilter, canvas, "nearest", "nearest") end
    self.canvas, self.canvasW, self.canvasH = canvas, w, h
    return canvas
  end

  function self:option(key, fallback)
    local value = self.core:setting(key)
    return value == nil and fallback or value
  end

  local function copyRow(row)
    local output = {}
    for key, value in pairs(row or {}) do output[key] = value end
    return output
  end

  function self:galleryModel(source, contentLevel)
    local model = Data.snapshot(source)
    if not model then return source end
    local level = tostring(contentLevel or "NORMAL"):upper()
    if model.kind == "menu" or model.kind == "device"
        or model.kind == "map" then
      local rows = model.rows or {}
      if level == "EMPTY" then
        model.rows, model.selected, model.scroll = {}, nil, 0
      elseif level == "MINIMAL" and #rows > 1 then
        model.rows, model.selected, model.scroll = { rows[1] }, 1, 0
      elseif level == "DENSE" or level == "OVERFLOW" then
        local target = level == "DENSE" and math.max(#rows, 10)
          or math.max(#rows, 24)
        local expanded = {}
        for index = 1, target do
          local sourceRow = #rows > 0 and rows[((index - 1) % #rows) + 1]
            or { id="fixture", label="FIXTURE ROW" }
          local item = copyRow(sourceRow)
          item.id = tostring(item.id or "row") .. ".fixture." .. index
          item.label = tostring(item.label or "ROW") .. " " .. index
          expanded[index] = item
        end
        model.rows = expanded
        model.selected = math.min(model.selected or 1, #expanded)
      end
    elseif model.kind == "choice" then
      local options = model.options or {}
      if level == "EMPTY" then
        model.options, model.selected = {}, nil
      elseif level == "MINIMAL" and #options > 1 then
        model.options, model.selected = { options[1] }, 1
      elseif level == "DENSE" or level == "OVERFLOW" then
        local target = level == "DENSE" and math.max(#options, 6)
          or math.max(#options, 14)
        local expanded = {}
        for index = 1, target do
          local sourceOption = #options > 0
            and options[((index - 1) % #options) + 1]
            or { id="fixture", label="FIXTURE OPTION" }
          local option = copyRow(sourceOption)
          option.id = tostring(option.id or "option") .. ".fixture." .. index
          option.label = tostring(option.label or "OPTION") .. " " .. index
          expanded[index] = option
        end
        model.options = expanded
        model.selected = math.min(model.selected or 1, #expanded)
      end
    elseif model.kind == "dialogue" then
      local lines = model.lines or {}
      if level == "EMPTY" then
        model.lines = {}
      elseif level == "MINIMAL" and #lines > 1 then
        model.lines = { lines[1] }
      elseif level == "DENSE" or level == "OVERFLOW" then
        local target = level == "DENSE" and math.max(#lines, 5)
          or math.max(#lines, 12)
        local expanded = {}
        for index = 1, target do
          local sourceLine = #lines > 0 and lines[((index - 1) % #lines) + 1]
            or "FIXTURE DIALOGUE"
          expanded[index] = tostring(sourceLine) .. " " .. index
        end
        model.lines = expanded
      end
    end
    if model.kind == "document" and type(model.document) == "table" then
      local regions = model.document.regions or {}
      for _, region in ipairs(regions) do
        local components = region.components or {}
        if level == "EMPTY" then
          region.components = {}
        elseif level == "MINIMAL" and #components > 1 then
          region.components = { components[1] }
        elseif level == "DENSE" or level == "OVERFLOW" then
          local target = level == "DENSE" and math.max(#components, 4)
            or math.max(#components, 8)
          local expanded = {}
          for index = 1, target do
            local sourceComponent = #components > 0
              and components[((index - 1) % #components) + 1]
              or { type = "label", text = "FIXTURE COMPONENT" }
            expanded[index] = Data.snapshot(sourceComponent)
          end
          region.components = expanded
        end
      end
    end
    return model
  end

  function self:attachTextRuns(layout, policy)
    if type(layout) ~= "table" or type(policy) ~= "table" then
      return layout
    end
    -- Layout geometry remains anchored to the solved/base font.  Renderers
    -- call this closure for individual constrained strings so multiple font
    -- sizes can safely coexist in one frame.
    layout.textPolicy = policy
    layout.textRun = function(value, maximum, options)
      return self.fonts:fit(policy, value, maximum, options)
    end
    return layout
  end

  function self:measureModel(base, model, font, density, priorEntries)
    local layout
    if model.kind == "document" then
      layout = DocumentLayout.measure(base, model, font, density)
    elseif model.kind == "menu" or model.kind == "device"
        or model.kind == "map" then
      layout = MenuLayout.measure(base, model, font, density)
    elseif model.kind == "dialogue" or model.kind == "choice" then
      layout = DialogueLayout.measure(base, model, font, density, priorEntries)
    elseif model.kind == "battle" then
      layout = BattleLayout.measure(base, model, font, density)
    elseif model.kind == "animation" then
      layout = AnimationLayout.measure(base, model, font, density)
    else
      return nil, "unsupported_presentation"
    end
    return self:attachTextRuns(layout, base and base.font)
  end

  function self:drawModel(model, layout, font, theme)
    local result
    if model.kind == "document" then
      result = DocumentRender.draw(love.graphics, model, layout, font, theme)
    elseif model.kind == "menu" or model.kind == "device"
        or model.kind == "map" then
      result = MenuRender.draw(love.graphics, model, layout, font, theme)
    elseif model.kind == "dialogue" or model.kind == "choice" then
      result = DialogueRender.draw(love.graphics, model, layout, font, theme)
    elseif model.kind == "battle" then
      result = BattleRender.draw(love.graphics, model, layout, font, theme)
    elseif model.kind == "animation" then
      result = AnimationRender.draw(love.graphics, model, layout, font, theme)
    else
      return nil, "unsupported_presentation"
    end
    if result == true then
      if self.debugContainers then
        Bounds.draw(love.graphics, layout, "containers")
      end
      if self.debugAssets then
        Bounds.draw(love.graphics, layout, "assets")
      end
    end
    return result
  end

  function self:debugInput()
    local keyboard = love and love.keyboard
    if not keyboard or type(keyboard.isDown) ~= "function" then return end
    for key, field in pairs({ f7 = "debugContainers", f8 = "debugAssets" }) do
      local ok, down = pcall(keyboard.isDown, key)
      down = ok and down == true
      if down and not self.debugKeys[key] then
        self[field] = not self[field]
        self:invalidate("debug_toggle")
      end
      self.debugKeys[key] = down
    end
  end

  function self:measureMenu(base, model, font, density)
    return self:measureModel(base, model, font, density)
  end

  function self:solveModel(model, request, priorEntries)
    if type(request) ~= "table" then
      return Solver.solve(request)
    end
    if type(model) == "table" and (model.kind == "document"
        or model.kind == "menu"
        or model.kind == "device" or model.kind == "map"
        or model.kind == "dialogue" or model.kind == "choice"
        or model.kind == "animation" or model.kind == "battle") then
      request.probe = function(envelope, candidate, density)
        return fitsCandidate(envelope, model, candidate, density, priorEntries)
      end
    end
    local solved = Solver.solve(request)
    if solved.ok and solved.value and solved.value.font then
      local resolved, _, code, message = self.fonts:resolve(
        solved.value.font)
      if not resolved then
        return Result.err(code or "font_unavailable", message)
      end
      solved.value.font = resolved
    end
    return solved
  end

  function self:lockedMenuWidth(state, base, model, font, density, viewport, safe)
    local width = MenuLayout.contentWidth(base, model, font, density)
    if not width or type(state) ~= "table" then return nil end
    local context = table.concat({ viewport.w, viewport.h, safe.w, safe.h,
      base.scale, font:getHeight(), self:option("ui_size", "auto"),
      self:option("text_size", "auto"),
      base.font and base.font.family or self:option("font", "openttd_mono"),
      density or "auto", base.widthMode or "fixed" }, ":")
    local current = self.menuWidths[state]
    if not current or current.context ~= context then
      current = { context=context, width=width }
      self.menuWidths[state] = current
    end
    return current.width
  end

  function self:drawMenu(model, layout, font, theme)
    return self:drawModel(model, layout, font, theme)
  end

  function self:prepare(game, viewport)
    self:clear("prepare")
    self.frameId = self.frameId + 1
    local function failed(reason)
      self.lastReason = reason
      return nil, reason
    end
    local graphics = love and love.graphics
    local window = love and love.window
    local vp = Viewport.rect(viewport, graphics)
    local safe = Viewport.safeArea(vp, graphics, window)
    local stackOk, states = pcall(self.provider.visibleStack,
      self.provider, game, { viewport=vp, safeArea=safe })
    if not stackOk then return failed("stack_error:" .. tostring(states)) end
    if type(states) ~= "table" or #states == 0 then return failed("empty_stack") end
    local w, h = vp.w, vp.h
    local entries, hidden = {}, {}
    for _, state in ipairs(states) do
      local ok, prepared = pcall(self.provider.prepareScreen,
        self.provider, state, { game=game, viewport=vp, safeArea=safe })
      local presentation = ok and type(prepared) == "table"
        and prepared.presentation or nil
      local legacyPresentation = type(presentation) == "table"
        and (presentation.kind == "legacy_surface"
          or presentation.kind == "legacy_screen")
      if not ok or type(prepared) ~= "table"
          or (prepared.suppress ~= true and not legacyPresentation)
          or type(presentation) ~= "table"
          or presentation.complete ~= true then
        return failed(ok and (prepared and prepared.reason or "incomplete")
          or tostring(prepared))
      end
      local legacySurface = prepared.presentation.kind == "legacy_surface"
        and prepared.presentation.surface or nil
      local legacyScreen = prepared.presentation.kind == "legacy_screen"
      local model
      if legacySurface then
        if type(legacySurface.model) ~= "table"
            or type(legacySurface.context) ~= "table" then
          return failed("invalid_legacy_surface")
        end
        model = legacySurface.model
      else
        local sourceModel = prepared.presentation.model or prepared.presentation
        local dataError
        model, dataError = Data.snapshot(sourceModel)
        if not model then return failed("invalid_model:" .. tostring(dataError)) end
        local valid, code = PresentationModel.validate(model)
        if not valid then
          return failed(code or "unsupported_presentation")
        end
      end
      if prepared.suppress ~= true and not legacySurface and not legacyScreen then
        return failed("native_suppression_unproven")
      end
      if prepared.suppress ~= true and legacySurface
          and legacySurface.policy ~= "preserve" then
        return failed("invalid_legacy_surface_policy")
      end
      local solved, font, solveRequest
      if not legacySurface then
        solveRequest = { preset=model.preset, viewport=vp,
          safeArea=safe, uiSize=self:option("ui_size", "auto"),
          textSize=self:option("text_size", "auto"),
          fontFamily=self:option("font", "openttd_mono"),
          density=self:option("density", "auto") }
        if model.kind == "document" or model.kind == "menu"
            or model.kind == "map" or model.kind == "dialogue"
            or model.kind == "choice" or model.kind == "animation"
            or model.kind == "battle" then
          solveRequest.probe = function(envelope, candidate, density)
            return fitsCandidate(envelope, model, candidate, density, entries)
          end
        end
        solved = self:solveModel(model, solveRequest, entries)
        if not solved.ok then return failed(solved.error.code) end
        local fontCode, fontMessage
        font, fontCode, fontMessage = self.fonts:get(solved.value.font)
        if not font then
          return failed((fontCode or "font_unavailable") .. ":"
            .. tostring(fontMessage or ""))
        end
        if (model.kind == "menu" or model.kind == "device"
            or model.kind == "map")
            and solved.value.widthMode == "content" then
          local logicalWidth = self:lockedMenuWidth(state, solved.value, model,
            font, solveRequest.density, vp, safe)
          if logicalWidth then
            solveRequest.logicalWidth = logicalWidth
            solved = self:solveModel(model, solveRequest, entries)
            if not solved.ok then return failed(solved.error.code) end
            font, fontCode, fontMessage = self.fonts:get(solved.value.font)
            if not font then
              return failed((fontCode or "font_unavailable") .. ":"
                .. tostring(fontMessage or ""))
            end
          end
        end
      end
      local layout
      if not legacySurface then
        layout = self:measureModel(solved.value, model, font,
          self:option("density", "auto"), entries)
        if not layout then return failed("layout_unsupported") end
      end
      entries[#entries + 1] = { state=state, model=model, layout=layout,
        font=font, prepared=prepared, presentation=prepared.presentation,
        surface=legacySurface }
      hidden[state] = prepared.suppress == true
    end
    for _, entry in ipairs(entries) do
      if entry.surface and entry.surface.policy == "replace"
          and #entries ~= #states then
        return failed("legacy_surface_replace_stack")
      end
    end
    local canvas, canvasError = self:canvasFor(w, h)
    if not canvas then return failed(canvasError) end
    local theme = self.core:themeFor(self:option("theme", "clean"),
      self:option("dark_mode", false))
    local rendered = Transaction.run(love.graphics, canvas, function()
      for _, entry in ipairs(entries) do
        local drawOk, drawCode, drawMessage
        if entry.surface then
          if type(self.provider.renderSurface) ~= "function" then
            return { complete=false, code="surface_runtime_unavailable" }
          end
          drawOk, drawCode, drawMessage = self.provider:renderSurface(
            entry.state, entry.presentation, canvas, vp, safe, theme,
            self.frameId)
        else
          drawOk, drawCode, drawMessage = self:drawModel(entry.model,
            entry.layout, entry.font, theme)
        end
        if drawOk ~= true then
          return { complete=false, code=drawCode or "render_incomplete",
            message=drawMessage }
        end
      end
      return { complete=true }
    end, {}, {})
    if not rendered.ok then return failed(rendered.error.code) end
    if type(rendered.value) ~= "table"
        or rendered.value.complete ~= true then
      return failed(type(rendered.value) == "table" and rendered.value.code
        or "render_incomplete")
    end
    self.candidate = { game=game, viewport=vp, entries=entries,
      hidden=hidden, canvas=canvas, frameSerial=self.frameSerial }
    self.lastReason = "ready"
    return self.candidate
  end

  function self:install()
    if not self:enabled() then return Result.ok({}) end
    if not (self.mod and self.mod.hooks and self.mod.hooks.wrap) then
      return Result.err("hooks_unavailable", "presentation hooks are unavailable")
    end
    local subscriptions = {}
    subscriptions[#subscriptions + 1] = self.mod.hooks:wrap("input.step",
      function(nextFn, game, dt)
        self:debugInput()
        return nextFn(game, dt)
      end, 95000)
    if self.mod.events and self.mod.events.on then
      subscriptions[#subscriptions + 1] = self.mod.events:on(
        "mod.options_changed", function(event)
          if type(event) ~= "table" or event.mod == nil
              or event.mod == self.provider.productId then
            self:invalidate("options_changed")
          end
        end, 90000)
      subscriptions[#subscriptions + 1] = self.mod.events:on(
        "mods.loaded", function() self:invalidate("mods_loaded") end, 90000)
      subscriptions[#subscriptions + 1] = self.mod.events:on(
        "screen.pushed", function() self:invalidate("screen_pushed") end,
        90000)
      subscriptions[#subscriptions + 1] = self.mod.events:on(
        "screen.popped", function() self:invalidate("screen_popped") end,
        90000)
    end
    subscriptions[#subscriptions + 1] = self.mod.hooks:wrap("render.ui.prepare",
      function(nextFn, game, viewport)
        if type(game) == "table" then self.lastGame = game end
        self:clear("prepare_begin")
        local downstream = nextFn(game, viewport)
        self:prepare(game, viewport)
        return downstream
      end, 90000)
    subscriptions[#subscriptions + 1] = self.mod.hooks:wrap("screen.render_visible",
      function(nextFn, state)
        -- v0.1.86 has the visibility and HUD seams but predates the dedicated
        -- render.ui.prepare seam. Prepare once, before the first native state
        -- is queried, so suppression is still atomic and the native state
        -- never flashes underneath a V3 frame. Newer hosts prepare through
        -- render.ui.prepare first, making this path a no-op for that frame.
        local game = gameFromState(state) or self.lastGame
          or gameFromMod(self.mod)
        local candidate = self.candidate
        if game and (not candidate or candidate.game ~= game
            or candidate.frameSerial ~= self.frameSerial) then
          local graphics = love and love.graphics
          if graphics and type(graphics.getDimensions) == "function" then
            local width, height = graphics.getDimensions()
            pcall(self.prepare, self, game,
              { x=0, y=0, w=width, h=height,
                width=width, height=height })
          end
        end
        local visible = nextFn(state)
        if visible == false then return false end
        candidate = self.candidate
        if candidate and candidate.hidden[state] then return false end
        return visible
      end, 90000)
    subscriptions[#subscriptions + 1] = self.mod.hooks:wrap("render.hud",
      function(nextFn, game, viewport)
        if type(game) == "table" then self.lastGame = game end
        nextFn(game, viewport)
        local candidate = self.candidate
        if candidate and candidate.game == game and candidate.canvas then
          local graphics = love and love.graphics
          if not graphics then self:clear("graphics_unavailable"); return end
          local pushed = graphics.push and pcall(graphics.push, "all")
          local ok = pcall(function()
            graphics.setColor(1,1,1,1)
            graphics.draw(candidate.canvas, 0, 0)
          end)
          if pushed and graphics.pop then pcall(graphics.pop) end
          if not ok then self:clear("compose_failed") end
        end
        -- Keep the completed candidate available to input hooks until the
        -- next frame begins, but force the fallback prepare above to rebuild
        -- it once the host advances to that next frame.
        self.frameSerial = self.frameSerial + 1
      end, 90000)
    subscriptions[#subscriptions + 1] = self.mod.hooks:wrap("input.pointer",
      function(nextFn, game, event)
        local candidate = self.candidate
        if candidate and candidate.game == game
            and POINTER_TOUCH_ENABLED
            and type(self.provider.pointer) == "function" then
          for index = #candidate.entries, 1, -1 do
            local entry = candidate.entries[index]
            local ok, consumed = pcall(self.provider.pointer, self.provider,
              entry.state, entry.model, entry.layout, event, game)
            if ok and consumed then
              self:clear("pointer_action")
              return true
            elseif not ok then
              self:clear("pointer_error")
              return nextFn(game, event)
            end
          end
        end
        return nextFn(game, event)
      end, 90000)
    subscriptions[#subscriptions + 1] = self.mod.hooks:wrap("input.wheel",
      function(nextFn, game, event)
        local candidate = self.candidate
        if candidate and candidate.game == game
            and type(self.provider.wheel) == "function" then
          for index = #candidate.entries, 1, -1 do
            local entry = candidate.entries[index]
            local ok, consumed = pcall(self.provider.wheel, self.provider,
              entry.state, entry.model, entry.layout, event, game)
            if ok and consumed then
              self:clear("wheel_action")
              return true
            elseif not ok then
              self:clear("wheel_error")
              return nextFn(game, event)
            end
          end
        end
        return nextFn(game, event)
      end, 90000)
    return Result.ok(subscriptions)
  end

  return self
end

return Runtime
