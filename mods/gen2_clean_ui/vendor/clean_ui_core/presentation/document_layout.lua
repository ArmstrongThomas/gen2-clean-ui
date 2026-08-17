local requireCore = ...
local Rect = requireCore("geometry.rect")

local DocumentLayout = {}

local function inset(rect, amount)
  return Rect.inset(rect, { x = amount })
end

local function heightFor(font, scale, lines)
  return math.max(font:getHeight() * lines + math.floor(12 * scale),
    math.floor(42 * scale))
end

function DocumentLayout.measure(base, model, font, _density)
  local scale = base.scale or 1
  local pad = math.max(8, math.floor(14 * scale))
  local frame = math.max(2, math.floor(2 * scale + 0.5))
  local inner = inset(base.outer, frame + pad)
  local header = Rect.new(inner.x, inner.y, inner.w,
    heightFor(font, scale, 1))
  local footer = Rect.new(inner.x, inner.y + inner.h
    - heightFor(font, scale, 1), inner.w, heightFor(font, scale, 1))
  local body = Rect.new(inner.x, header.y + header.h, inner.w,
    math.max(1, footer.y - header.y - header.h))
  local regions = model.document.regions or {}
  local regionLayouts = {}
  local headerRegions, footerRegions, contentRegions = {}, {}, {}
  for _, region in ipairs(regions) do
    if region.role == "header" then
      headerRegions[#headerRegions + 1] = region
    elseif region.role == "footer" then
      footerRegions[#footerRegions + 1] = region
    else
      contentRegions[#contentRegions + 1] = region
    end
  end
  local top = body.y
  for _, region in ipairs(headerRegions) do
    local height = heightFor(font, scale, 2)
    regionLayouts[#regionLayouts + 1] = {
      source = region, rect = Rect.new(body.x, top, body.w, height),
    }
    top = top + height + pad
  end
  local available = math.max(1, body.y + body.h - top)
  local columns = #contentRegions > 1 and 2 or 1
  local cellWidth = (body.w - pad * (columns - 1)) / columns
  local cellHeight = math.max(1, available / math.max(1,
    math.ceil(#contentRegions / columns)))
  for index, region in ipairs(contentRegions) do
    local column = (index - 1) % columns
    local row = math.floor((index - 1) / columns)
    regionLayouts[#regionLayouts + 1] = {
      source = region,
      rect = Rect.new(body.x + column * (cellWidth + pad),
        top + row * (cellHeight + pad), cellWidth, cellHeight),
    }
  end
  local footerTop = footer.y
  for _, region in ipairs(footerRegions) do
    regionLayouts[#regionLayouts + 1] = {
      source = region, rect = Rect.new(footer.x, footerTop, footer.w, footer.h),
    }
  end
  base.inner, base.header, base.body, base.footer = inner, header, body, footer
  base.document = regionLayouts
  base.hitRegions = {}
  return base
end

function DocumentLayout.fits(base, model, font, density)
  return type(DocumentLayout.measure(base, model, font, density)) == "table"
end

return DocumentLayout
