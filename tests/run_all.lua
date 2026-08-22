local root = assert(os.getenv("GEN2_CLEAN_UI_ROOT"), "GEN2_CLEAN_UI_ROOT is required")
root = root:gsub("\\", "/")

local syntaxFiles = {
  "mods/gen2_clean_ui/main.lua",
  "mods/gen2_clean_ui/options.lua",
  "mods/gen2_clean_ui/src/bootstrap.lua",
  "mods/gen2_clean_ui/src/product.lua",
  "mods/gen2_clean_ui/src/settings.lua",
  "mods/gen2_clean_ui/src/integration/core_bridge.lua",
  "mods/gen2_clean_ui/src/adapters/data.lua",
  "mods/gen2_clean_ui/src/adapters/actions.lua",
  "mods/gen2_clean_ui/src/adapters/main_menu.lua",
  "mods/gen2_clean_ui/src/adapters/start_menu.lua",
  "mods/gen2_clean_ui/src/adapters/options_menu.lua",
  "mods/gen2_clean_ui/src/adapters/shared_textbox.lua",
  "mods/gen2_clean_ui/src/adapters/shared_choicebox.lua",
  "mods/gen2_clean_ui/src/presenters/foundation_models.lua",
  "mods/gen2_clean_ui/src/presenters/foundation_presenters.lua",
  "mods/gen2_clean_ui/src/presenters/shared_models.lua",
  "mods/gen2_clean_ui/src/presenters/shared_presenters.lua",
  "mods/gen2_clean_ui/src/contracts/validators.lua",
  "mods/gen2_clean_ui/src/contracts/record.lua",
  "mods/gen2_clean_ui/src/contracts/catalog.lua",
  "mods/gen2_clean_ui/src/contracts/shared.lua",
  "mods/gen2_clean_ui/src/contracts/families/foundation.lua",
  "mods/gen2_clean_ui/src/contracts/families/gameplay.lua",
  "mods/gen2_clean_ui/src/contracts/families/services.lua",
  "mods/gen2_clean_ui/src/contracts/families/native.lua",
  "mods/gen2_clean_ui/src/provider/identity.lua",
  "mods/gen2_clean_ui/src/provider/diagnostics.lua",
  "mods/gen2_clean_ui/src/provider/stack_policy.lua",
  "mods/gen2_clean_ui/src/provider/live_stack.lua",
  "mods/gen2_clean_ui/src/provider/source_input.lua",
  "mods/gen2_clean_ui/src/provider/init.lua",
  "mods/gen2_clean_ui/src/gallery/catalog.lua",
}

local function collectLua(directory, prefix)
  local isWindows = package.config:sub(1, 1) == "\\"
  local command
  if isWindows then
    command = 'dir /b /s "' .. directory:gsub("/", "\\") .. '\\*.lua"'
  else
    command = 'find "' .. directory:gsub('"', '\\"')
      .. '" -type f -name "*.lua" -print'
  end
  local pipe = assert(io.popen(command))
  for path in pipe:lines() do
    local normalized = path:gsub("\\", "/")
    syntaxFiles[#syntaxFiles + 1] = normalized:sub(#root + 2)
  end
  pipe:close()
end
collectLua(root .. "/mods/gen2_clean_ui/vendor/clean_ui_core")
collectLua(root .. "/mods/gen2_clean_ui/src")

for _, relative in ipairs(syntaxFiles) do
  local chunk, parseError = loadfile(root .. "/" .. relative)
  assert(chunk, relative .. ": " .. tostring(parseError))
end
print(("Lua syntax: %d files passed"):format(#syntaxFiles))

assert(loadfile(root .. "/tests/run_contract_tests.lua"))()
assert(loadfile(root .. "/tests/run_foundation_model_tests.lua"))()
assert(loadfile(root .. "/tests/run_load_report_tests.lua"))()
assert(loadfile(root .. "/tests/run_shared_ui_tests.lua"))()
assert(loadfile(root .. "/tests/run_product_smoke.lua"))()
assert(loadfile(root .. "/tests/run_v0186_sprite_fallback_tests.lua"))()
assert(loadfile(root .. "/tests/run_modern_compat_tests.lua"))()
assert(loadfile(root .. "/tests/run_party_summary_tests.lua"))()
assert(loadfile(root .. "/tests/run_pack_dex_trainer_save_tests.lua"))()
assert(loadfile(root .. "/tests/run_naming_storage_tests.lua"))()
assert(loadfile(root .. "/tests/run_pokegear_tests.lua"))()
assert(loadfile(root .. "/tests/run_services_commerce_tests.lua"))()
assert(loadfile(root .. "/tests/run_mail_specialty_tests.lua"))()
assert(loadfile(root .. "/tests/run_integrated_03_gallery_tests.lua"))()
assert(loadfile(root .. "/tests/run_production_gallery_fixture_tests.lua"))()
assert(loadfile(root .. "/tests/run_responsive_nav_tests.lua"))()
