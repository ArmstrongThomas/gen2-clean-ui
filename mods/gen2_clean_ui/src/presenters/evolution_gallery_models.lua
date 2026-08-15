return function()
  local Models = {}

  function Models.galleryFixtures()
    return {
      {
        screenId="Gen2EvolutionAnim", variant="flash",
        model={
          schema="clean_ui.v3.presentation.v1", apiVersion=3,
          id="evolution_preview", kind="animation", preset="ANIMATION",
          title="EVOLUTION", opaque=true,
          animation={id="cinematic.evolution", overlay=true,
            phase="flash", frame=80, duration=144, progress=80/144,
            blackout=true, showNew=true,
            overlays={{x=0, y=0, w=1, h=1, color={1,1,1,1}}},
            sprites={
              {path="assets/generated/battle/front/cyndaquil.png",
                normalized=true,
                rect={x=(56+8)/160, y=(16+56-48)/144,
                  w=48/160, h=48/144},
                palette={{255,255,255}, {58,58,58}, {16,25,25}, {0,0,0}}},
            },
            circles={}, labels={},
          },
        },
      },
      {
        screenId="Gen2EvolutionAnim", variant="reveal",
        model={
          schema="clean_ui.v3.presentation.v1", apiVersion=3,
          id="evolution_reveal_preview", kind="animation", preset="ANIMATION",
          title="EVOLUTION", opaque=true,
          animation={id="cinematic.evolution", overlay=true,
            phase="reveal", frame=26, duration=64, progress=26/64,
            blackout=false, showNew=true,
            overlays={{x=0, y=0, w=1, h=1, color={1,1,1,1}}},
            sprites={
              {path="assets/generated/battle/front/quilava.png",
                normalized=true,
                rect={x=(56+8)/160, y=(16+56-48)/144,
                  w=48/160, h=48/144}},
            },
            circles={{x=0.5, y=0.4, radius=4/160,
              color={0.9,0.55,0.15,1}}}, labels={},
          },
        },
      },
    }
  end

  return Models
end
