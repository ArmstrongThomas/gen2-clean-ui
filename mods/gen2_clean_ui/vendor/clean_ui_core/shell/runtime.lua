local requireCore = ...
local Result = requireCore("foundation.result")
local Data = requireCore("foundation.data")
local Viewport = requireCore("geometry.viewport")
local Modal = requireCore("components.modal")
local FontCatalog = requireCore("text.font_catalog")
local State = requireCore("shell.state")
local Content = requireCore("shell.content")
local Layout = requireCore("shell.layout")
local Render = requireCore("shell.render")

local Shell = {}

-- Pointer/touch hit testing remains implemented for a future input pass, but
-- the current Clean UI deliberately leaves it disabled. The released host
-- exposes the hook, while several screens still have incomplete or poor
-- pointer behavior.
local POINTER_TOUCH_ENABLED = false

local function slug(value)
  local text = tostring(value):lower():gsub("[^a-z0-9]+", "_")
  text = text:gsub("^_+", ""):gsub("_+$", "")
  return text ~= "" and text or "choice"
end

function Shell.new(core)
  local self = {
    core = core, mod = core.mod, content = Content, settingsRevision = 0,
    screenId = core.provider.game == "gen1"
      and "Gen1CleanUiShell" or "Gen2CleanUiShell",
  }
  self.fonts = FontCatalog.new(love and love.graphics, {
    plainPixel = "assets/fonts/plainpixel/PlainPixel-Regular.ttf",
  })

  function self:active(game)
    local stack = game and game.stack
    local top = stack and stack.top and stack:top()
    return top and top.cleanUiShell == self and top or nil
  end

  function self:createState(game, view, payload)
    local screen = {
      game = game, cleanUiShell = self, isOpaque = true,
      model = State.new(view, payload), screenId = self.screenId,
    }
    function screen:update(dt) self.cleanUiShell:update(self, dt) end
    function screen:draw() end
    function screen:exit()
      if self.cleanUiShell.core.dropdown.state.phase ~= "closed" then
        self.cleanUiShell.core.dropdown:dispatch({ type = "cancel" })
      end
    end
    return screen
  end

  function self:install()
    local screens = self.mod and self.mod.content and self.mod.content.screens
    if not (screens and screens.register and self.mod.ui and self.mod.ui.push
        and self.mod.hooks and self.mod.hooks.wrap) then
      return Result.err("shell_api_unavailable",
        "Clean UI shell requires screen, UI, and hook APIs")
    end
    screens:register(self.screenId, {
      new = function(game, view, payload)
        return self:createState(game, view, payload)
      end,
    })
    local subscriptions = {}
    subscriptions[#subscriptions + 1] = self.mod.hooks:wrap("render.hud",
      function(nextFn, game, viewport)
        nextFn(game, viewport)
        local screen = self:active(game)
        if not screen then return end
        local G = love and love.graphics
        if not (G and G.push and G.pop) then return end
        local pushed = pcall(G.push, "all")
        local ok, message = xpcall(function()
          self:draw(screen, viewport)
        end, function(errorValue) return tostring(errorValue) end)
        if pushed then pcall(G.pop) end
        if not ok then
          self:close(screen)
          local logger = self.mod and self.mod.log
          if logger and type(logger.error) == "function" then
            pcall(logger.error, logger,
              "Clean UI shell draw failed; restored the source UI: %s", message)
          end
        end
      end, 100000)
    subscriptions[#subscriptions + 1] = self.mod.hooks:wrap("input.pointer",
      function(nextFn, game, event)
        local screen = self:active(game)
        if screen and POINTER_TOUCH_ENABLED
            and self:pointer(screen, event) then return true end
        return nextFn(game, event)
      end, 100000)
    subscriptions[#subscriptions + 1] = self.mod.hooks:wrap("input.wheel",
      function(nextFn, game, event)
        local screen = self:active(game)
        if screen and self:wheel(screen, event) then return true end
        return nextFn(game, event)
      end, 100000)
    return Result.ok(subscriptions)
  end

  function self:open(game, view, payload)
    if not game then return nil, "game_unavailable", "live game is unavailable" end
    local current = self:active(game)
    if current and current.model:preset() == current.model:preset(view) then
      current.model:show(view, payload, true)
      return current
    end
    return self.mod.ui.push(game, self.screenId, view, payload)
  end

  function self:close(screen)
    local stack = screen.game and screen.game.stack
    if stack and stack.top and stack.pop and stack:top() == screen then
      stack:pop()
      return true
    end
    return false
  end

  function self:rows(screen)
    return Content.rows(self, screen.model)
  end

  function self:previewModel(state)
    if not (state and state.view == "gallery_preview") then return nil end
    local fixture = state.payload and state.payload.fixture
    local model = fixture and fixture.model
    local supported = type(model) == "table" and (model.kind == "menu"
      or model.kind == "device" or model.kind == "map"
      or model.kind == "dialogue" or model.kind == "choice")
    return supported and model or nil
  end

  function self:setting(state, key)
    if state and state.view == "gallery_preview" and state.preview
        and state.preview[key] ~= nil then
      return state.preview[key]
    end
    return self.core:setting(key)
  end

  function self:previewSetting(state, key)
    if state and state.preview and state.preview[key] ~= nil then
      return state.preview[key]
    end
    return self.core:setting(key)
  end

  function self:fontPolicy(viewport, safeArea, state)
    local solved = self.core.pipeline.solver.solve({
      preset = state:preset(), viewport = viewport, safeArea = safeArea,
      uiSize = self:setting(state, "ui_size") or "auto",
      textSize = self:setting(state, "text_size") or "auto",
      fontFamily = self:setting(state, "font") or "plain_pixel",
      density = self:setting(state, "density") or "auto",
      settingsRevision = self.settingsRevision,
    })
    return solved.ok and solved.value.font or { family="system", physicalPx=15 }
  end

  function self:draw(screen, viewport)
    viewport = Viewport.rect(viewport, love and love.graphics)
    local safeArea = Viewport.safeArea(viewport, love and love.graphics,
      love and love.window)
    local policy = self:fontPolicy(viewport, safeArea, screen.model)
    local font = self.fonts:get(policy)
    if not font then font = love.graphics.newFont(policy.physicalPx or 15) end
    if screen.model.view == "v3_screen" then
      local model = screen.model.payload and screen.model.payload.model
      if type(model) ~= "table" then return end
      local solved = self.core.pipeline.solver.solve({
        preset=model.preset or "M", viewport=viewport, safeArea=safeArea,
        uiSize=self:setting(screen.model, "ui_size") or "auto",
        textSize=self:setting(screen.model, "text_size") or "auto",
        fontFamily=self:setting(screen.model, "font") or "plain_pixel",
        density=self:setting(screen.model, "density") or "auto",
        settingsRevision=self.settingsRevision,
      })
      if not solved.ok then return end
      local v3Font = self.fonts:get(solved.value.font)
      if not v3Font then return end
      local layout = self.core.presentation:measureModel(solved.value, model,
        v3Font, self:setting(screen.model, "density") or "auto")
      if not layout then return end
      screen.model.layout, screen.rows = layout, model.rows or {}
      local theme = self.core.themes:get(self.core:setting("theme") or "clean")
      self.core.presentation:drawModel(model, layout, v3Font, theme)
      return
    end
    local preview = self:previewModel(screen.model)
    if preview then
      local solved = self.core.pipeline.solver.solve({
        preset = preview.preset or "L", viewport = viewport, safeArea = safeArea,
        uiSize = self:previewSetting(screen.model, "ui_size") or "auto",
        textSize = self:previewSetting(screen.model, "text_size") or "auto",
        fontFamily = self:previewSetting(screen.model, "font") or "plain_pixel",
        density = self:previewSetting(screen.model, "density") or "auto",
        settingsRevision = self.settingsRevision,
      })
      if not solved.ok then return end
      local previewFont = self.fonts:get(solved.value.font)
      if not previewFont then return end
      local previewModel = self.core.presentation:galleryModel(preview,
        screen.model.preview and screen.model.preview.content)
      local previewLayout = self.core.presentation:measureModel(solved.value,
        previewModel, previewFont,
        self:previewSetting(screen.model, "density") or "auto")
      if not previewLayout then return end
      screen.model.layout = previewLayout
      screen.rows = previewModel.rows or previewModel.options or {}
      local theme = self.core.themes:get(self.mod.options:get("theme") or "clean")
      self.core.presentation:drawModel(previewModel, previewLayout,
        previewFont, theme)
      return
    end
    local rows = self:rows(screen)
    local layout = Layout.measure(self, screen.model, viewport, safeArea, rows, font)
    if not layout then return end
    screen.model.layout, screen.rows = layout, rows
    if screen.model.modal then
      screen.model.modal.layout = Layout.measureModal(layout,
        screen.model.modal.descriptor, font)
      Modal.ensureVisible(screen.model.modal)
    end
    local theme = self.core.themes:get(self.mod.options:get("theme") or "clean")
    Render.draw(self, screen.model, layout, rows, font, theme)
  end

  function self:openDropdown(screen, row)
    local layout = screen.model.layout
    if not layout then return end
    local trigger
    for _, measured in ipairs(layout.rows) do
      if measured.index == screen.model.index then trigger = measured.rect break end
    end
    if not trigger then return end
    local options = {}
    for index, choice in ipairs(row.choices or {}) do
      options[#options + 1] = {
        id = slug(choice.id or choice[2]) .. "." .. index,
        label = tostring(choice[1]), value = choice[2],
        disabled = choice.disabled == true, group = choice.group,
        icon = choice.icon, description = choice.description,
      }
    end
    self.core.dropdown:open({ type="dropdown", id=row.id,
      label=row.label, value=row.value, options=options,
      action=row.action or "change_setting" }, trigger, layout.safeArea, {
        rowHeight = layout.rowHeight,
        headingHeight = math.max(24, math.floor(layout.rowHeight * 0.7)),
        descriptionHeight = math.max((layout.fontHeight or 15) + 4,
          math.floor(layout.rowHeight * 0.55)),
        iconWidth = math.max(layout.rowHeight,
          math.floor(44 * layout.scale)),
        minWidth = math.min(layout.safeArea.w,
          math.max(trigger.w, math.floor(240 * layout.scale))),
      })
  end

  function self:commitDropdown(result, screen)
    local payload = result and result.value and result.value.payload
    if not payload then return end
    if screen and screen.model.view == "v3_screen"
        and result.value.action then
      return self:invokeV3Action(screen, result.value.action, payload)
    end
    local ok, code, message = self.core:setSetting(payload.componentId, payload.value)
    if ok then
      self.settingsRevision = self.settingsRevision + 1
    else
      return nil, code, message
    end
    return true
  end

  function self:openV3Screen(screen, descriptor, actions)
    local model = Content.v3Model(descriptor)
    if not model then return nil, "invalid_screen", "V3 action did not return a screen" end
    screen.model:show("v3_screen", { model=model, actions=actions or {} }, true)
    return true
  end

  function self:invokeV3Action(screen, actionId, payload)
    local actions = screen.model.payload and screen.model.payload.actions or {}
    local action = actions and actions[actionId]
    if type(action) ~= "function" then
      return nil, "unknown_action", tostring(actionId)
    end
    local ok, value = xpcall(function()
      return action({ game=screen.game, productId=self.core.provider.productId,
        contractId=screen.model.payload.contractId }, payload or {})
    end, function(message) return tostring(message) end)
    if not ok then
      screen.model.notice = "ACTION FAILED: " .. value
      return nil, "action_failed", value
    end
    if value ~= nil then
      local snapshot, snapshotError = Data.snapshot(value)
      if not snapshot then
        screen.model.notice = "ACTION FAILED: " .. tostring(snapshotError)
        return nil, "invalid_action_result", snapshotError
      end
      value = snapshot
    end
    if type(value) == "table" and value.type == "modal_overlay" then
      return self:openModal(screen, value, actions)
    elseif type(value) == "table" and value.type == "close" then
      self:close(screen)
      return true
    elseif Content.isV3Screen(value) then
      return self:openV3Screen(screen, value, actions)
    end
    return true
  end

  function self:openModal(screen, descriptor, actions)
    local validated = Modal.validate(descriptor)
    if not validated.ok then return validated:unpack() end
    screen.model.modal = {
      descriptor = validated.value,
      index = validated.value.selected,
      scroll = 0,
      actions = actions or {},
      triggerIndex = screen.model.index,
    }
    return true
  end

  function self:closeModal(screen)
    local modal = screen.model.modal
    if not modal then return false end
    screen.model.modal = nil
    if modal.triggerIndex then screen.model.index = modal.triggerIndex end
    return true
  end

  function self:activateModal(screen, optionId)
    local modal = screen.model.modal
    if not modal then return end
    local options = modal.descriptor.options or {}
    local option
    if optionId then
      for index, candidate in ipairs(options) do
        if candidate.id == optionId then modal.index, option = index, candidate break end
      end
    else
      option = options[modal.index or 0]
    end
    if not option or option.disabled then return end
    local action = option.action and modal.actions[option.action] or nil
    if not action then self:closeModal(screen); return true end
    local ok, value = xpcall(function()
      return action({ game=screen.game, productId=self.core.provider.productId,
        modalId=modal.descriptor.id }, {
          componentId=modal.descriptor.id, optionId=option.id,
          value=option.value,
        })
    end, function(message) return tostring(message) end)
    if not ok then
      self:closeModal(screen)
      screen.model.notice = "ACTION FAILED: " .. value
      return nil, "modal_action_failed", value
    end
    if type(value) == "table" and value.type == "modal_overlay" then
      return self:openModal(screen, value, modal.actions)
    end
    self:closeModal(screen)
    if type(value) == "table" and value.type == "close" then
      self:close(screen)
    end
    return value
  end

  local CONTENT_LEVELS = { "EMPTY", "MINIMAL", "NORMAL", "DENSE", "OVERFLOW" }
  local UI_SIZES = { "auto", "small", "medium", "large" }
  local TEXT_SIZES = { "auto", "1", "2", "3", "4" }
  local function cycle(values, current, delta)
    local found = 1
    for index, value in ipairs(values) do if value == current then found = index break end end
    return values[((found - 1 + delta) % #values) + 1]
  end

  function self:cycleGalleryFamily(screen, delta)
    local families = Content.families(screen.model.payload)
    if #families == 0 then return end
    screen.model.galleryFamily = ((screen.model.galleryFamily - 1 + delta)
      % #families) + 1
    screen.model.index, screen.model.scroll = 1, 0
  end

  function self:cyclePreviewFixture(screen, delta)
    local payload = screen.model.payload or {}
    local all = Content.fixtures(payload.catalog)
    if #all == 0 then return end
    local current = payload.fixture
    local found = 1
    for index, fixture in ipairs(all) do if fixture == current
        or (fixture.id and current and fixture.id == current.id) then found = index break end end
    payload.fixture = all[((found - 1 + delta) % #all) + 1]
  end

  function self:activate(screen)
    local rows = self:rows(screen)
    local row = rows[screen.model.index]
    if not row or row.disabled then return end
    if row.kind == "toggle" then
      local ok, code, message = self.core:setSetting(row.id, not row.value)
      screen.model.notice = ok and "SETTING UPDATED"
        or (tostring(code) .. ": " .. tostring(message))
      if ok then self.settingsRevision = self.settingsRevision + 1 end
    elseif row.kind == "choice" then
      self:openDropdown(screen, row)
    elseif row.kind == "open" and row.id == "__compatibility" then
      screen.model:show("compatibility", nil, true)
    elseif row.kind == "reset" then
      local ok, code, message = self.core:resetDefaults()
      screen.model.notice = ok and "DEFAULTS RESTORED"
        or (tostring(code) .. ": " .. tostring(message))
      if ok then self.settingsRevision = self.settingsRevision + 1 end
    elseif row.kind == "mod_action" then
      local value, code, message = self.core:activateModMenu(row.id,
        { game = screen.game, componentId = row.id })
      if code then screen.model.notice = tostring(code) .. ": " .. tostring(message) end
      if type(value) == "table" and value.type == "modal_overlay" then
        local record = self.core.catalog.records[row.id]
        local opened, modalCode, modalMessage = self:openModal(screen, value,
          record and record.actions)
        if not opened then
          screen.model.notice = tostring(modalCode) .. ": " .. tostring(modalMessage)
        end
      elseif Content.isV3Screen(value) then
        local record = self.core.catalog.records[row.id]
        local opened, openCode, openMessage = self:openV3Screen(screen, value,
          record and record.actions)
        if not opened then
          screen.model.notice = tostring(openCode) .. ": "
            .. tostring(openMessage)
        end
      end
    elseif screen.model.view == "v3_screen"
        and (row.kind == "v3_action" or row.kind == "v3_item") then
      local payload = { componentId=row.v3ComponentId or row.id,
        itemId=row.v3ItemId, value=row.v3Value }
      local ok, code, message = self:invokeV3Action(screen, row.action, payload)
      if not ok then screen.model.notice = tostring(code) .. ": " .. tostring(message) end
    elseif screen.model.view == "v3_screen" and row.kind == "v3_dropdown" then
      self:openDropdown(screen, row)
    elseif row.kind == "gallery" then
      screen.model:show("gallery_preview", {
        fixture = row.source, catalog = screen.model.payload,
      }, true)
    end
  end

  function self:update(screen)
    local input = screen.game and screen.game.input
    if not input then return end
    local dropdown = self.core.dropdown
    if dropdown.state.phase ~= "closed" then
      local result
      if input:wasPressed("up") then
        result = dropdown:dispatch({ type="move", delta=-1 })
      elseif input:wasPressed("down") then
        result = dropdown:dispatch({ type="move", delta=1 })
      elseif input:wasPressed("a") then
        result = dropdown:dispatch({ type="activate" })
      elseif input:wasPressed("b") then
        dropdown:dispatch({ type="cancel" })
      end
      if result and result.ok and result.value.action then
          local ok, code, message = self:commitDropdown(result, screen)
        if not ok then screen.model.notice = tostring(code) .. ": " .. tostring(message) end
      end
      return
    end
    local modal = screen.model.modal
    if modal then
      if input:wasPressed("up") then Modal.move(modal, -1)
      elseif input:wasPressed("down") then Modal.move(modal, 1)
      elseif input:wasPressed("a") then self:activateModal(screen)
      elseif input:wasPressed("b") and modal.descriptor.cancelable then
        self:closeModal(screen)
      end
      Modal.ensureVisible(modal)
      return
    end
    local rows = self:rows(screen)
    if screen.model.view == "gallery" and input:wasPressed("left") then
      self:cycleGalleryFamily(screen, -1)
    elseif screen.model.view == "gallery" and input:wasPressed("right") then
      self:cycleGalleryFamily(screen, 1)
    elseif screen.model.view == "gallery_preview" and input:wasPressed("left") then
      self:cyclePreviewFixture(screen, -1)
    elseif screen.model.view == "gallery_preview" and input:wasPressed("right") then
      self:cyclePreviewFixture(screen, 1)
    elseif screen.model.view == "gallery_preview" and input:wasPressed("up") then
      screen.model.preview.content = cycle(CONTENT_LEVELS,
        screen.model.preview.content, 1)
    elseif screen.model.view == "gallery_preview" and input:wasPressed("down") then
      screen.model.preview.content = cycle(CONTENT_LEVELS,
        screen.model.preview.content, -1)
    elseif screen.model.view == "gallery_preview" and input:wasPressed("a") then
      screen.model.preview.ui_size = cycle(UI_SIZES,
        screen.model.preview.ui_size, 1)
    elseif screen.model.view == "gallery_preview" and input:wasPressed("select") then
      screen.model.preview.text_size = cycle(TEXT_SIZES,
        screen.model.preview.text_size, 1)
    elseif screen.model.view == "gallery_preview" and input:wasPressed("start") then
      screen.model.preview.font = screen.model.preview.font == "system"
        and "plain_pixel" or "system"
    elseif input:wasPressed("up") then
      if screen.model.view == "v3_screen" then
        screen.model:moveSelectable(-1, rows)
      else
        screen.model:move(-1, #rows)
      end
    elseif input:wasPressed("down") then
      if screen.model.view == "v3_screen" then
        screen.model:moveSelectable(1, rows)
      else
        screen.model:move(1, #rows)
      end
    elseif input:wasPressed("a") then
      self:activate(screen)
    elseif input:wasPressed("select") and screen.model.view == "mod_menus" then
      local row = rows[screen.model.index]
      if row then
        local ok, code, message = self.core:togglePin(row.id)
        screen.model.notice = ok and (row.pinned and "PIN REMOVED" or "PIN ADDED")
          or (tostring(code) .. ": " .. tostring(message))
      end
    elseif input:wasPressed("b") then
      if not screen.model:back() then self:close(screen) end
    end
  end

  function self:dropdownRowAt(x, y)
    local dropdown = self.core.dropdown
    local layout = dropdown.layout
    if not layout then return nil end
    if x < layout.rect.x or x >= layout.rect.x + layout.rect.w
        or y < layout.rect.y or y >= layout.rect.y + layout.rect.h then return nil end
    local scroll = dropdown.state.scrollOffset or 0
    for _, measured in ipairs(layout.rows) do
      local rect = measured.rect
      if x >= rect.x and x < rect.x + rect.w
          and y >= rect.y - scroll and y < rect.y - scroll + rect.h then
        return measured.option
      end
    end
    return nil
  end

  function self:pointer(screen, event)
    local model, dropdown = screen.model, self.core.dropdown
    if not event or not model.layout then return false end
    if model.modal then
      local modal = model.modal
      local layout = modal.layout
      if not layout then return true end
      local hit
      local pixelScroll = (modal.scroll or 0) * layout.rowHeight
      for _, measured in ipairs(layout.rows or {}) do
        local rect = { x=measured.rect.x,
          y=measured.rect.y - pixelScroll,
          w=measured.rect.w, h=measured.rect.h }
        if event.x >= rect.x and event.x < rect.x + rect.w
            and event.y >= rect.y and event.y < rect.y + rect.h then
          hit = measured
          break
        end
      end
      if event.phase == "pressed" then
        if hit and not hit.option.disabled then
          modal.index = hit.index
          model.pressed = { kind="modal", id=hit.option.id }
        elseif modal.descriptor.cancelable and not (event.x >= layout.rect.x
            and event.x < layout.rect.x + layout.rect.w
            and event.y >= layout.rect.y and event.y < layout.rect.y + layout.rect.h) then
          self:closeModal(screen)
        end
        return true
      elseif event.phase == "released" then
        if model.pressed and model.pressed.kind == "modal" and hit
            and model.pressed.id == hit.option.id then
          self:activateModal(screen, hit.option.id)
        end
        model.pressed = nil
        return true
      elseif event.phase == "cancelled" then
        model.pressed = nil
        return true
      end
      return true
    end
    if dropdown.state.phase ~= "closed" then
      local rect = dropdown.layout and dropdown.layout.rect
      local inside = rect and event.x >= rect.x and event.x < rect.x + rect.w
        and event.y >= rect.y and event.y < rect.y + rect.h
      if event.phase == "pressed" then
        if not inside then dropdown:dispatch({ type="cancel" }); return true end
        local option = self:dropdownRowAt(event.x, event.y)
        if option and not option.disabled and not option.heading then
          dropdown.state.activeOptionId = option.id
        end
        model.pressed = { kind="dropdown",
          id=option and not option.disabled and not option.heading and option.id or nil,
          pointerId=event.id, source=event.source, x=event.x, y=event.y,
          dragging=false }
        return true
      elseif event.phase == "moved" and model.pressed
          and model.pressed.kind == "dropdown"
          and model.pressed.pointerId == event.id then
        local pressed = model.pressed
        local threshold = math.max(6,
          math.floor((screen.model.layout.scale or 1) * 8))
        if not pressed.dragging
            and math.abs(event.y - pressed.y) >= threshold then
          pressed.dragging = true
          dropdown:dispatch({ type="drag_start", pointerId=event.id,
            y=pressed.y })
        end
        if pressed.dragging then
          dropdown:dispatch({ type="drag_move", pointerId=event.id,
            y=event.y })
        end
        return true
      elseif event.phase == "released" then
        local option = self:dropdownRowAt(event.x, event.y)
        if model.pressed and model.pressed.dragging then
          dropdown:dispatch({ type="drag_end", pointerId=event.id,
            y=event.y })
        elseif model.pressed and option and model.pressed.id == option.id then
          local result = dropdown:dispatch({ type="activate", optionId=option.id })
          if result.ok and result.value.action then
            local ok, code, message = self:commitDropdown(result, screen)
            if not ok then model.notice = tostring(code) .. ": " .. tostring(message) end
          end
        end
        model.pressed = nil
        return true
      elseif event.phase == "cancelled" then
        if model.pressed and model.pressed.dragging then
          dropdown:dispatch({ type="drag_end", pointerId=event.id,
            y=event.y })
        end
        model.pressed = nil
        return true
      end
      return inside
    end
    local hit
    for _, measured in ipairs(model.layout.rows) do
      local rect = measured.rect
      if event.x >= rect.x and event.x < rect.x + rect.w
          and event.y >= rect.y and event.y < rect.y + rect.h then
        hit = measured
        break
      end
    end
    if event.phase == "moved" then
      model.hover = hit and hit.index or nil
      return hit ~= nil
    elseif event.phase == "pressed" and hit then
      if hit.row and hit.row.disabled then return true end
      model.index = hit.index
      local pin = model.view == "mod_menus"
        and event.x >= hit.rect.x + hit.rect.w - model.layout.pinWidth
      model.pressed = { index=hit.index, pin=pin }
      return true
    elseif event.phase == "released" and model.pressed then
      local pressed = model.pressed
      model.pressed = nil
      if hit and hit.index == pressed.index then
        model.index = hit.index
        if pressed.pin then
          local row = self:rows(screen)[hit.index]
          local ok, code, message = self.core:togglePin(row.id)
          model.notice = ok and (row.pinned and "PIN REMOVED" or "PIN ADDED")
            or (tostring(code) .. ": " .. tostring(message))
        else
          self:activate(screen)
        end
      end
      return true
    elseif event.phase == "cancelled" then
      model.pressed = nil
    end
    return false
  end

  function self:wheel(screen, event)
    local wheelY = tonumber(event and event.y) or 0
    if wheelY == 0 then return false end
    if screen.model.modal then
      local modal = screen.model.modal
      if modal.layout and modal.layout.maxScroll > 0 then
        modal.scroll = math.max(0, math.min(modal.layout.maxScroll,
          (modal.scroll or 0) - wheelY))
      else
        Modal.move(modal, wheelY > 0 and -1 or 1)
      end
      Modal.ensureVisible(modal)
      return true
    end
    local dropdown = self.core.dropdown
    if dropdown.state.phase ~= "closed" then
      dropdown:dispatch({ type="scroll",
        delta = -wheelY * math.max(24,
          dropdown.layout and dropdown.layout.rect.h / 5 or 32) })
      return true
    end
    local rows = self:rows(screen)
    if #rows == 0 or not screen.model.layout then return false end
    local direction = wheelY > 0 and -1 or 1
    screen.model:move(direction, #rows)
    screen.model:ensureVisible(screen.model.layout.visibleRows, #rows)
    return true
  end

  return self
end

return Shell
