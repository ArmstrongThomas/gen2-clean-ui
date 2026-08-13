local requireCore = ...
local Order = requireCore("foundation.order")

local StartMenu = {}

local function insertionIndex(items)
  for i, item in ipairs(items) do
    local id = tostring(item.id or ""):lower()
    local label = tostring(item.label or item.text or ""):upper()
    if id == "mods" or label == "MODS" then return i end
  end
  for i, item in ipairs(items) do
    local id = tostring(item.id or ""):lower()
    local label = tostring(item.label or item.text or ""):upper()
    if id == "save" or label == "SAVE" then return i end
  end
  return #items + 1
end

function StartMenu.compose(sourceItems, catalog, pins, handlers)
  handlers = handlers or {}
  local items = {}
  -- Source rows may carry callbacks and host objects. Keep those references
  -- intact: this hook changes presentation order, never source ownership.
  for index, item in ipairs(sourceItems or {}) do items[index] = item end
  local catalogRows = catalog:list()
  local pinned = {}
  for _, entry in ipairs(catalogRows) do
    if pins:contains(entry.key) and entry.action then
      local key = entry.key
      pinned[#pinned + 1] = {
        id = "clean_ui.pin." .. entry.key,
        label = entry.label,
        pinned = true,
        cleanUiKey = entry.key,
        desc = { "Pinned mod", "shortcut" },
        action = function(game)
          if handlers.activate then return handlers.activate(key, game) end
          return entry.action(game)
        end,
        onSelect = function(game)
          if handlers.activate then return handlers.activate(key, game) end
          return entry.action(game)
        end,
      }
    end
  end
  local block = Order.contributions(pinned)
  block[#block + 1] = {
    id = "clean_ui.mod_menus", label = "MOD MENUS", cleanUiInternal = true,
    desc = { "Third-party", "menu actions" },
    cleanUiCatalog = catalogRows, action = handlers.openModMenus,
    onSelect = handlers.openModMenus,
  }
  local at = insertionIndex(items)
  for i = #block, 1, -1 do table.insert(items, at, block[i]) end
  return items
end

return StartMenu
