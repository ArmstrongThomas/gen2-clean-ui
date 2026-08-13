local requireCore = ...
local Data = requireCore("foundation.data")
local Result = requireCore("foundation.result")
local Viewport = requireCore("geometry.viewport")
local FontCatalog = requireCore("text.font_catalog")
local Solver = requireCore("layout.solver")
local Transaction = requireCore("surfaces.transaction")
local MenuLayout = requireCore("presentation.menu_layout")
local MenuRender = requireCore("presentation.menu_render")
local DialogueLayout = requireCore("presentation.dialogue_layout")
local DialogueRender = requireCore("presentation.dialogue_render")

local Runtime = {}

function Runtime.new(core)
  local self = { core=core, mod=core.mod, provider=core.provider,
    candidate=nil, canvas=nil, canvasW=nil, canvasH=nil }
  self.fonts = FontCatalog.new(love and love.graphics, {
    plainPixel=core.config.plainPixelPath
      or "assets/fonts/plainpixel/PlainPixel-Regular.ttf",
  })
  local sourceImage = core.mod and core.mod.ui and core.mod.ui.sourceImage
  if type(sourceImage) == "function" then
    MenuRender.setSourceImageLoader(function(path)
      return sourceImage(path)
    end)
  end

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
    local value = self.mod and self.mod.options and self.mod.options:get(key)
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
    if model.kind == "menu" then
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
    return model
  end

  function self:measureModel(base, model, font, density, priorEntries)
    if model.kind == "menu" then
      return MenuLayout.measure(base, model, font, density)
    elseif model.kind == "dialogue" or model.kind == "choice" then
      return DialogueLayout.measure(base, model, font, density, priorEntries)
    end
    return nil, "unsupported_presentation"
  end

  function self:drawModel(model, layout, font, theme)
    if model.kind == "menu" then
      return MenuRender.draw(love.graphics, model, layout, font, theme)
    elseif model.kind == "dialogue" or model.kind == "choice" then
      return DialogueRender.draw(love.graphics, model, layout, font, theme)
    end
    return nil, "unsupported_presentation"
  end

  function self:measureMenu(base, model, font, density)
    return self:measureModel(base, model, font, density)
  end

  function self:drawMenu(model, layout, font, theme)
    return self:drawModel(model, layout, font, theme)
  end

  function self:prepare(game, viewport)
    self:clear("prepare")
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
      if not ok or type(prepared) ~= "table" or prepared.suppress ~= true
          or type(prepared.presentation) ~= "table"
          or prepared.presentation.complete ~= true then
        return failed(ok and (prepared and prepared.reason or "incomplete")
          or tostring(prepared))
      end
      local sourceModel = prepared.presentation.model or prepared.presentation
      local model, dataError = Data.snapshot(sourceModel)
      if not model then return failed("invalid_model:" .. tostring(dataError)) end
      local supported = model.kind == "menu"
        or model.kind == "dialogue" or model.kind == "choice"
      if not supported or type(model.preset) ~= "string"
          or (model.kind == "menu" and type(model.rows) ~= "table")
          or (model.kind == "dialogue" and type(model.lines) ~= "table")
          or (model.kind == "choice" and type(model.options) ~= "table") then
        return failed("unsupported_presentation")
      end
      local solved = Solver.solve({ preset=model.preset, viewport=vp,
        safeArea=safe, uiSize=self:option("ui_size", "auto"),
        textSize=self:option("text_size", "auto"),
        fontFamily=self:option("font", "plain_pixel"),
        density=self:option("density", "auto") })
      if not solved.ok then return failed(solved.error.code) end
      local font, fontCode, fontMessage = self.fonts:get(solved.value.font)
      if not font then
        return failed((fontCode or "font_unavailable") .. ":"
          .. tostring(fontMessage or ""))
      end
      local layout = self:measureModel(solved.value, model, font,
        self:option("density", "auto"), entries)
      if not layout then return failed("layout_unsupported") end
      entries[#entries + 1] = { state=state, model=model, layout=layout,
        font=font, prepared=prepared }
      hidden[state] = true
    end
    local canvas, canvasError = self:canvasFor(w, h)
    if not canvas then return failed(canvasError) end
    local theme = self.core.themes:get(self:option("theme", "clean"))
    local rendered = Transaction.run(love.graphics, canvas, function()
      for _, entry in ipairs(entries) do
        local drawOk, drawCode, drawMessage = self:drawModel(entry.model,
          entry.layout, entry.font, theme)
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
      hidden=hidden, canvas=canvas }
    self.lastReason = "ready"
    return self.candidate
  end

  function self:install()
    if not self:enabled() then return Result.ok({}) end
    if not (self.mod and self.mod.hooks and self.mod.hooks.wrap) then
      return Result.err("hooks_unavailable", "presentation hooks are unavailable")
    end
    local subscriptions = {}
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
    end
    subscriptions[#subscriptions + 1] = self.mod.hooks:wrap("render.ui.prepare",
      function(nextFn, game, viewport)
        self:clear("prepare_begin")
        local downstream = nextFn(game, viewport)
        self:prepare(game, viewport)
        return downstream
      end, 90000)
    subscriptions[#subscriptions + 1] = self.mod.hooks:wrap("screen.render_visible",
      function(nextFn, state)
        local visible = nextFn(state)
        if visible == false then return false end
        local candidate = self.candidate
        if candidate and candidate.hidden[state] then return false end
        return visible
      end, 90000)
    subscriptions[#subscriptions + 1] = self.mod.hooks:wrap("render.hud",
      function(nextFn, game, viewport)
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
      end, 90000)
    subscriptions[#subscriptions + 1] = self.mod.hooks:wrap("input.pointer",
      function(nextFn, game, event)
        local candidate = self.candidate
        if candidate and candidate.game == game
            and self:option("pointer_touch", true) ~= false
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
