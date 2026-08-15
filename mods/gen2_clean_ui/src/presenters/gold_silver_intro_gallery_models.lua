return function(ctx)
  local models = {}

  local function blankTiles()
    local tiles = {}
    for index = 1, 32 * 32 do tiles[index] = 0 end
    return tiles
  end

  function models.galleryFixtures()
    local tiles = blankTiles()
    return {{
      screenId="Gen2GoldSilverIntro", variant="intro", synthetic=true,
      source={screenId="Gen2GoldSilverIntro", scene=2, frames=48,
        done=false, act="water", scx=88, scy=0, counter1=64, counter2=4,
        bgp=228, obp0=228, lyActive=false,
        lyOverrides=(function()
          local values = {}
          for index = 1, 144 do values[index] = 0 end
          return values
        end)(), bgmap=tiles, anims={oam={}}},
      modelReady=true,
      model={schema="clean_ui.v3.presentation.v1", apiVersion=3,
        id="gold_silver_intro", kind="animation", preset="ANIMATION",
        title="GOLD / SILVER INTRO", opaque=true,
        animation={id="cinematic.gold_silver_intro", overlay=true,
          phase=2, frame=48, duration=2335, progress=48/2335,
          overlays={{x=0,y=0,w=1,h=1,color={0,0,0,1}}},
          tilemap={path="assets/generated/intro/water_tiles.png",
            tileWidth=8, tileHeight=8, mapWidth=32, mapHeight=32,
            sheetColumns=16, logicalWidth=160, logicalHeight=144,
            scrollX=88, scrollY=0, tiles=tiles},
          backgroundSprites={}, sprites={}},
    }}}
  end

  return models
end
