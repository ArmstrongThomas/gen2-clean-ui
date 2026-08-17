local requireCore = ...
local Rect = requireCore("geometry.rect")

local DialogueLayout = {}

local function textWidth(font, text)
  if type(font.getWidth) == "function" then return font:getWidth(text) end
  return #tostring(text or "") * math.max(1, font:getHeight() * 0.55)
end

local function normalizedLines(model)
  local source = model.lines or {}
  if model.reflow ~= true then return source end
  local parts = {}
  for _, value in ipairs(source) do
    local text = tostring(value or ""):gsub("%s+", " ")
      :gsub("^%s+", ""):gsub("%s+$", "")
    if text ~= "" then
      local previous = parts[#parts]
      if previous and previous:sub(-1) == "-"
          and text:match("^[%a%d]") then
        -- Source dialogue sometimes uses a visible hyphen only because the
        -- ROM line ended in the middle of a word. Once the source lines are
        -- reflowed into the wider Clean UI envelope, that marker is no longer
        -- part of the prose and should not survive as a dangling dash.
        parts[#parts] = previous:sub(1, -2) .. text
      else
        parts[#parts + 1] = text
      end
    end
  end
  return { table.concat(parts, " ") }
end

local function nextCodepointEnd(text, position)
  local byte = text:byte(position)
  if not byte then return position end
  local width = byte >= 240 and 4
    or byte >= 224 and 3
    or byte >= 192 and 2 or 1
  return math.min(#text, position + width - 1)
end

local function hardWrapWord(font, word, width)
  if word == "" or textWidth(font, word) <= width then return { word } end
  local output, current, position = {}, "", 1
  while position <= #word do
    local finish = nextCodepointEnd(word, position)
    local piece = word:sub(position, finish)
    local candidate = current .. piece
    if current ~= "" and textWidth(font, candidate) > width then
      output[#output + 1] = current
      current = piece
    else
      current = candidate
    end
    if textWidth(font, current) > width then
      -- A single glyph can be wider than the available body. Keep it intact;
      -- inserting a hyphen would change the source dialogue and make the
      -- overflow look like a second, authored line break.
      output[#output + 1] = current
      current = ""
    end
    position = finish + 1
  end
  if current ~= "" then output[#output + 1] = current end
  return #output > 0 and output or { word }
end

local function wrapLine(font, value, width)
  local text = tostring(value or "")
  if text == "" or textWidth(font, text) <= width then return { text } end
  local output, current = {}, ""
  for word in text:gmatch("%S+") do
    local candidate = current == "" and word or (current .. " " .. word)
    if current == "" then
      local chunks = hardWrapWord(font, word, width)
      for index = 1, #chunks - 1 do output[#output + 1] = chunks[index] end
      current = chunks[#chunks]
    elseif textWidth(font, candidate) <= width then
      current = candidate
    else
      output[#output + 1] = current
      local chunks = hardWrapWord(font, word, width)
      for index = 1, #chunks - 1 do output[#output + 1] = chunks[index] end
      current = chunks[#chunks]
    end
  end
  if current ~= "" then output[#output + 1] = current end
  return #output > 0 and output or { text }
end

local function wrappedLines(model, font, width)
  if model.reflow ~= true then return normalizedLines(model) end
  local output = {}
  for _, line in ipairs(normalizedLines(model)) do
    for _, wrapped in ipairs(wrapLine(font, line, width)) do
      output[#output + 1] = wrapped
    end
  end
  return output
end

local function anchoredOuter(base, anchor, priorEntries)
  local outer = Rect.copy(base.outer)
  local safe = base.safeArea or base.viewport
  local gap = math.max(8, math.floor(12 * (base.scale or 1)))
  if anchor == "bottom" then
    outer.y = safe.y + safe.h - outer.h - gap
  elseif anchor == "top" then
    outer.y = safe.y + gap
  elseif anchor == "above_dialogue" then
    local dialogue
    for index = #(priorEntries or {}), 1, -1 do
      local candidate = priorEntries[index]
      if candidate.model and candidate.model.kind == "dialogue" then
        dialogue = candidate.layout and candidate.layout.outer
        break
      end
    end
    if dialogue then
      outer.x = dialogue.x + dialogue.w - outer.w
      outer.y = dialogue.y - outer.h - gap
      if outer.y < safe.y + gap then
        -- Two fixed XS envelopes cannot be fully stacked in a short 360p
        -- viewport. Keep the choice at the safe top edge instead of placing
        -- it directly on top of the dialogue and hiding the question.
        outer.y = safe.y + gap
      end
    end
  end
  outer.x = math.max(safe.x + gap,
    math.min(outer.x, safe.x + safe.w - outer.w - gap))
  outer.y = math.max(safe.y + gap,
    math.min(outer.y, safe.y + safe.h - outer.h - gap))
  return outer
end

local function inset(rect, amount)
  return Rect.inset(rect, { x=amount, y=amount })
end

function DialogueLayout.measure(base, model, font, density, priorEntries)
  local scale = base.scale or 1
  local compact = density == "compact"
  local pad = math.max(8, math.floor((compact and 10 or 14) * scale))
  local frame = math.max(2, math.floor(2 * scale + 0.5))
  local outer = anchoredOuter(base, model.anchor, priorEntries)
  local inner = inset(outer, frame + pad)
  local lineGap = math.max(4, math.floor(6 * scale))
  local footerHeight = math.max(font:getHeight() + pad,
    math.floor((compact and 34 or 42) * scale))
  local body = Rect.new(inner.x, inner.y, inner.w,
    math.max(0, inner.h - footerHeight))
  local footer = Rect.new(inner.x, body.y + body.h, inner.w, footerHeight)
  local hitRegions = {}
  local optionRows = {}

  if model.kind == "choice" then
    local options = model.options or {}
    local rowHeight = math.max(font:getHeight() + pad,
      math.floor((compact and 38 or 46) * scale))
    local total = #options * rowHeight
    local y = body.y + math.max(0, math.floor((body.h - total) / 2))
    for index, option in ipairs(options) do
      local rect = Rect.new(body.x, y + (index - 1) * rowHeight,
        body.w, rowHeight)
      optionRows[index] = { index=index, option=option, rect=rect }
      if option.disabled ~= true then
        hitRegions[#hitRegions + 1] = {
          id=tostring(option.id or index), index=index,
          sourceIndex=option.sourceIndex or index,
          rect=Rect.copy(rect), role="choice_option",
        }
      end
    end
  else
    hitRegions[1] = {
      id="advance", index=1, rect=Rect.copy(outer),
      role="dialogue_advance",
    }
  end

  local displayLines = wrappedLines(model, font, body.w)
  local lineHeight = font:getHeight() + lineGap
  local lineCapacity = math.max(1,
    math.floor((body.h + lineGap) / math.max(1, lineHeight)))
  local textOverflow = #displayLines > lineCapacity
  if textOverflow then
    local clipped = {}
    local first = math.max(1, #displayLines - lineCapacity + 1)
    for index = first, #displayLines do
      clipped[#clipped + 1] = displayLines[index]
    end
    displayLines = clipped
  end

  base.outer, base.inner, base.body, base.footer = outer, inner, body, footer
  base.lineGap, base.hitRegions, base.optionRows = lineGap, hitRegions, optionRows
  base.displayLines, base.textOverflow = displayLines, textOverflow
  return base
end

-- Horizontal text is resolved per run by the renderer.  Only layout-owned
-- overflow remains a frame-level reason to try another base size.
function DialogueLayout.fits(base, model, font, density, priorEntries)
  local measured = DialogueLayout.measure(base, model, font, density,
    priorEntries)
  if measured.textOverflow then return false end
  return true
end

return DialogueLayout
