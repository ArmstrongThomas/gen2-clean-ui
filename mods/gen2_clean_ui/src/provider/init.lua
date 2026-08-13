return function(ctx)
  local Identity = ctx.load("provider.identity")
  local Diagnostics = ctx.load("provider.diagnostics")
  local StackPolicy = ctx.load("provider.stack_policy")
  local LiveStack = ctx.load("provider.live_stack")
  local SourceInput = ctx.load("provider.source_input")

  local Provider = {}
  Provider.__index = Provider

  local function result(record, valid, suppress, reason, detail, presentation)
    return {
      record = record,
      valid = valid == true,
      suppress = suppress == true,
      reason = reason,
      detail = detail,
      presentation = presentation,
    }
  end

  function Provider.new(options)
    assert(options and options.catalog and options.catalog.byId,
      "Gen2 provider requires a contract catalog")
    return setmetatable({
      productId = "gen2_clean_ui",
      game = "gen2",
      catalog = options.catalog,
      shared = options.shared,
      mod = options.mod,
      classResolver = options.classResolver or Identity.defaultClassResolver,
      classResolverInjected = options.classResolver ~= nil,
      classCache = {},
      modelAdapters = {},
      presenters = {},
      pointerPress = {},
      gallery = options.gallery,
      compatibility = options.compatibility,
      diagnostics = Diagnostics.new(128),
    }, Provider)
  end

  function Provider:officialClass(record, context)
    if record.kind ~= "shared" and not self.classResolverInjected then
      return true
    end
    local cached = self.classCache[record.id]
    if cached ~= nil then return cached ~= false and cached or nil end
    local resolveContext = {}
    for key, value in pairs(context or {}) do resolveContext[key] = value end
    resolveContext.mod = self.mod
    local officialClass, code, detail = self.classResolver(record, resolveContext)
    if type(officialClass) ~= "table" then
      self.classCache[record.id] = false
      return nil, code or "class_unavailable", detail
    end
    self.classCache[record.id] = officialClass
    return officialClass
  end

  function Provider:recordForState(state, context)
    if type(state) ~= "table" then return nil end
    local id = rawget(state, "screenId")
    if id ~= nil then return self.catalog.byId[id] end
    for _, record in ipairs(self.shared and self.shared.records or {}) do
      local officialClass = self:officialClass(record, context)
      if officialClass and getmetatable(state) == officialClass then
        return record
      end
    end
    return nil
  end

  function Provider:recordFailure(record, code, detail)
    self.diagnostics:record(record and record.id or "unknown", code, detail)
    return result(record, false, false, code, detail)
  end

  function Provider:validateShape(state, record, context)
    local validators = { record.validateBase, record.validateMode }
    for _, validator in ipairs(validators) do
      local ok, valid, code, detail = pcall(validator, state, context)
      if not ok then
        return self:recordFailure(record, "validator_error", tostring(valid))
      end
      if not valid then
        return self:recordFailure(record, code or "shape_invalid", detail)
      end
    end
    return result(record, true, false, "validated_native")
  end

  function Provider:inspect(state, context)
    if type(state) ~= "table" then
      return self:recordFailure(nil, "state_type", "table")
    end
    context = context or {}
    context.mod = self.mod
    local id = rawget(state, "screenId")
    local record = self:recordForState(state, context)
    if not record then return self:recordFailure(nil, "unknown_screen", tostring(id)) end

    local officialClass, classCode, classDetail = self:officialClass(record, context)
    if not officialClass then
      return self:recordFailure(record, classCode or "class_unavailable", classDetail)
    end
    local ok, code, detail = Identity.validate(state, record, context, officialClass)
    if not ok then return self:recordFailure(record, code, detail) end

    if record.support == "native" then
      return self:recordFailure(record, "native_by_design", record.nativeReason)
    end
    if record.support == "deferred" then
      return self:recordFailure(record, "deferred", record.nativeReason)
    end

    local shape = self:validateShape(state, record, context)
    if not shape.valid then return shape end
    if not self.presenters[record.id] then
      if self.modelAdapters[record.id] then
        return result(record, true, false, "model_ready_native",
          record.implementation)
      end
      return result(record, true, false, "presenter_unavailable",
        record.implementation)
    end
    return result(record, true, false, "presentation_not_prepared")
  end

  function Provider:registerPresenter(screenId, presenter)
    local record = self.catalog.byId[screenId]
      or (self.shared and self.shared.byId[screenId])
    if not record then return nil, "unknown_screen", screenId end
    if record.support ~= "supported" then
      return nil, "unsupported_contract", record.support
    end
    if type(presenter) ~= "table" or type(presenter.prepare) ~= "function" then
      return nil, "invalid_presenter", "prepare function required"
    end
    self.presenters[screenId] = presenter
    return true
  end

  function Provider:registerModelAdapter(screenId, adapter)
    local record = self.catalog.byId[screenId]
      or (self.shared and self.shared.byId[screenId])
    if not record then return nil, "unknown_screen", screenId end
    if record.support ~= "supported" then
      return nil, "unsupported_contract", record.support
    end
    if type(adapter) ~= "table" or type(adapter.extract) ~= "function" then
      return nil, "invalid_model_adapter", "extract function required"
    end
    self.modelAdapters[screenId] = adapter
    return true
  end

  -- Produces detached presentation data and deferred source action bindings.
  -- This method never marks a screen suppressible; drawing/suppression is a
  -- separate integration layer and remains native until that layer is ready.
  function Provider:extractModel(state, context)
    local inspected = self:inspect(state, context)
    if not inspected.valid then return inspected end
    local record = inspected.record
    local adapter = record and self.modelAdapters[record.id]
    if not adapter then
      return result(record, true, false, "model_adapter_unavailable")
    end

    local ok, bundle, code, detail = pcall(adapter.extract, state, context)
    if not ok then
      return self:recordFailure(record, "model_adapter_error", tostring(bundle))
    end
    if type(bundle) ~= "table" or type(bundle.model) ~= "table" then
      return self:recordFailure(record, code or "model_adapter_incomplete", detail)
    end
    if bundle.model.screenId ~= record.id then
      return self:recordFailure(record, "model_adapter_mismatch",
        tostring(bundle.model.screenId))
    end
    return result(record, true, false, "model_ready_native", nil, bundle)
  end

  Provider.modelFor = Provider.extractModel

  function Provider:prepare(state, context)
    if self.compatibility and type(self.compatibility.prepareScreen) == "function" then
      local legacy = self.compatibility:prepareScreen(
        context and context.game, state, context)
      if legacy and legacy.matched then
        if legacy.failed then
          return self:recordFailure(nil, legacy.reason or "legacy_ui_invalid")
        end
        return legacy.result
      end
    end
    local inspected = self:inspect(state, context)
    if not inspected.valid then return inspected end
    local presenter = inspected.record and self.presenters[inspected.record.id]
    if not presenter then return inspected end

    local ok, presentation = pcall(presenter.prepare, presenter, state, context)
    if not ok then
      return self:recordFailure(inspected.record, "presenter_error", tostring(presentation))
    end
    if type(presentation) ~= "table" or presentation.complete ~= true
        or type(presentation.model) ~= "table" then
      return self:recordFailure(inspected.record, "presenter_incomplete")
    end
    return result(inspected.record, true, true, "ready", nil, presentation)
  end

  Provider.prepareScreen = Provider.prepare

  function Provider:visibleStack(game, context)
    return LiveStack.visible(self, game, context)
  end

  function Provider:pointer(state, model, layout, event, game)
    if self.compatibility and type(self.compatibility.pointer) == "function" then
      local handled = self.compatibility:pointer(state, model, layout, event, game)
      if handled ~= nil then return handled end
    end
    return SourceInput.pointer(self, state, model, layout, event, game)
  end

  function Provider:wheel(state, model, layout, event, game)
    if self.compatibility and type(self.compatibility.wheel) == "function" then
      local handled = self.compatibility:wheel(state, model, layout, event, game)
      if handled ~= nil then return handled end
    end
    return SourceInput.wheel(self, state, model, layout, event, game)
  end

  function Provider:renderSurface(state, presentation, target, viewport, safe, theme)
    if self.compatibility and type(self.compatibility.renderSurface) == "function" then
      return self.compatibility:renderSurface(state, presentation, target,
        viewport, safe, theme)
    end
    return nil, "surface_runtime_unavailable"
  end

  function Provider:openGallery(_, filter)
    if type(self.gallery) ~= "table" then return { game = "gen2", fixtures = {} } end
    if type(filter) ~= "table" or filter.family == nil then return self.gallery end
    local fixtures = {}
    for _, fixture in ipairs(self.gallery.fixtures or {}) do
      if fixture.family == filter.family then fixtures[#fixtures + 1] = fixture end
    end
    return { game = "gen2", fixtures = fixtures, count = #fixtures,
      sourceContract = self.gallery.sourceContract }
  end

  function Provider:assessStack(states, context)
    return StackPolicy.assess(states, context, function(state, currentContext)
      return self:prepare(state, currentContext)
    end)
  end

  return Provider
end
