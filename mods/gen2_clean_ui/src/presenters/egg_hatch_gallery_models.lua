return function(ctx)
  local Models = {}

  function Models.galleryFixtures()
    return {
      {
        screenId="Gen2EggHatchAnim", variant="hatch",
        model={
          schema="clean_ui.v3.presentation.v1", apiVersion=3,
          id="egg_hatch_preview", kind="animation", preset="ANIMATION",
          title="EGG HATCH", opaque=true,
          animation={id="cinematic.egg_hatch", overlay=true,
            frame=80, duration=482, progress=80/482,
            overlays={{x=0, y=0, w=1, h=1, color={1,1,1,1}}},
            sprites={
              {path="assets/generated/battle/front/egg.png",
                normalized=true,
                rect={x=(7*8+8)/160, y=(4*8+16)/144,
                  w=40/160, h=40/144},
                palette={{255,255,255}, {240,208,88},
                  {184,128,0}, {0,0,0}}},
              {path="assets/generated/menu/egg_hatch.png",
                normalized=true,
                rect={x=(11*8-12)/160, y=(9*8-20)/144,
                  w=8/160, h=8/144},
                crop={x=0, y=0, w=8, h=8}},
            },
          },
        },
      },
    }
  end

  return Models
end
