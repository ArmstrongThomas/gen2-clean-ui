return function(ctx)
  local Models = {}

  local function screen(id, title, path, variant)
    return {
      screenId = id, variant = variant,
      model = {
        schema = "clean_ui.v3.presentation.v1", apiVersion = 3,
        id = variant .. "_preview", kind = "animation",
        preset = "ANIMATION", title = title, opaque = true,
        animation = {
          id = "boot." .. variant, overlay = true, frame = 0,
          duration = variant == "title" and 60 or 100, progress = 0,
          overlays = variant == "title" and {
            { x=0, y=0, w=1, h=88/144,
              color={123/255,165/255,1,1} },
            { x=0, y=88/144, w=1, h=56/144,
              color={1,1,1,1} },
          } or {{ x=0, y=0, w=1, h=1, color={1,1,1,1} }},
          sprites = {{ path = path, rect = { x=0, y=0, w=1, h=1 } }},
        },
      },
    }
  end

  function Models.galleryFixtures()
    return {
      screen("Gen2CopyrightSplash", "COPYRIGHT", 
        "assets/generated/title/copyright_splash.png", "splash"),
      {
        screenId="Gen2GameFreakPresents", variant="gamefreak",
        model={
          schema="clean_ui.v3.presentation.v1", apiVersion=3,
          id="gamefreak_preview", kind="animation", preset="ANIMATION",
          title="GAME FREAK PRESENTS", opaque=true,
          animation={id="boot.gamefreak", overlay=true, frame=96,
            duration=128, progress=0.75,
            overlays={{x=0, y=0, w=1, h=1, color={0,0,0,1}}},
            sprites={
              {path="assets/generated/splash/logo.png",
                rect={x=0.4, y=0.38, w=0.15, h=40/144},
                crop={x=0, y=0, w=24, h=40}},
            },
          },
        },
      },
      screen("Gen2TitleState", "GOLD TITLE",
        "assets/generated/title/title_screen.png", "title"),
    }
  end

  return Models
end
