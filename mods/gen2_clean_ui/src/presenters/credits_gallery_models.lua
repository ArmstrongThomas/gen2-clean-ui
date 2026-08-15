return function(ctx)
  local Models = {}

  function Models.galleryFixtures()
    return {
      {
        screenId="Gen2Credits", variant="credits",
        model={
          schema="clean_ui.v3.presentation.v1", apiVersion=3,
          id="credits_preview", kind="animation", preset="ANIMATION",
          title="CREDITS", opaque=true,
          animation={id="credits.roll", overlay=true, frame=72,
            duration=13, progress=0.5,
            overlays={
              {x=0, y=0, w=1, h=1, color={1, 1, 1, 1}},
              {x=0, y=0, w=1, h=32/144, color={0.94, 0.87, 0.84, 1}},
              {x=0, y=14*8/144, w=1, h=32/144,
                color={0.94, 0.87, 0.84, 1}},
              {x=0, y=4*8/144, w=1, h=8/144,
                color={0.48, 0.38, 0.32, 1}},
              {x=0, y=13*8/144, w=1, h=8/144,
                color={0.48, 0.38, 0.32, 1}},
            },
            sprites={
              {path="assets/generated/credits/bellossom.png",
                rect={x=0, y=0, w=0.2, h=32/144},
                crop={x=0, y=0, w=32, h=32}},
              {path="assets/generated/credits/theend.png",
                rect={x=6*8/160, y=8*8/144, w=64/160, h=16/144}},
            },
            labels={{text="PORT STAFF", x=0.5, y=6*8/144,
              align="center", maxWidth=0.8, color={0.22,0.22,0.22,1}},
              {text="THE END", x=0.5, y=8*8/144,
                align="center", maxWidth=0.4, color={0.22,0.22,0.22,1}}},
          },
        },
      },
    }
  end

  return Models
end
