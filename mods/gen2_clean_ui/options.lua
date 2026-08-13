return {
  {
    key = "theme",
    type = "choice",
    label = "THEME",
    default = "clean",
    choices = {
      { "CLEAN", "clean" },
      { "DARK", "dark" },
      { "HIGH CONTRAST", "high_contrast" },
    },
  },
  {
    key = "ui_size",
    type = "choice",
    label = "UI SIZE",
    default = "auto",
    choices = {
      { "AUTO", "auto" },
      { "SMALL", "small" },
      { "MEDIUM", "medium" },
      { "LARGE", "large" },
    },
  },
  {
    key = "text_size",
    type = "choice",
    label = "TEXT SIZE",
    default = "auto",
    choices = {
      { "AUTO", "auto" },
      { "1X", 1 },
      { "2X", 2 },
      { "3X", 3 },
      { "4X", 4 },
    },
  },
  {
    key = "font",
    type = "choice",
    label = "FONT",
    default = "plain_pixel",
    choices = {
      { "PLAIN PIXEL", "plain_pixel" },
      { "SYSTEM", "system" },
    },
  },
  {
    key = "density",
    type = "choice",
    label = "DENSITY",
    default = "auto",
    choices = {
      { "AUTO", "auto" },
      { "COMFORTABLE", "comfortable" },
      { "COMPACT", "compact" },
    },
  },
  {
    key = "pointer_touch",
    type = "toggle",
    label = "POINTER & TOUCH",
    default = true,
  },
  {
    key = "native_dialogue",
    type = "toggle",
    label = "NATIVE DIALOGUE",
    default = false,
  },
  {
    key = "native_menus",
    type = "toggle",
    label = "NATIVE MENUS",
    default = false,
  },
  {
    key = "native_pokemon",
    type = "toggle",
    label = "NATIVE POKEMON UI",
    default = false,
  },
  {
    key = "native_storage",
    type = "toggle",
    label = "NATIVE STORAGE",
    default = false,
  },
  {
    key = "native_services",
    type = "toggle",
    label = "NATIVE SERVICES",
    default = false,
  },
  {
    key = "native_manager",
    type = "toggle",
    label = "NATIVE MANAGER",
    default = false,
  },
}

