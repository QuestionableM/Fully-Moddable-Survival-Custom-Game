--This file is generated! Don't edit here.

----------------------------------------------------------------------------------------------------
-- Data
----------------------------------------------------------------------------------------------------

local g_burntForest = {} --Flags lookup table

-------------------------------
-- Bits                      --
-- dir | SE | SW | NW | NE | --
-- bit |  3 |  2 |  1 |  0 | --
-------------------------------

local function toBurntForestIndex( se, sw, nw, ne )
	return bit.bor( bit.lshift( se, 3 ), bit.lshift( sw, 2 ), bit.lshift( nw, 1 ), bit.tobit( ne ) )
end

function initBurntForestTiles()
	for i=0, 15 do
		g_burntForest[i] = { tiles = {}, rotation = 0 }
	end
	g_burntForest[toBurntForestIndex( 0, 0, 0, 1 )] = { tiles = { AddTile( 5000101, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0001)_01.tile", 5 ), AddTile( 5000102, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0001)_02.tile", 5 ), AddTile( 5000103, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0001)_03.tile", 5 ) }, rotation = 0 }
	g_burntForest[toBurntForestIndex( 0, 0, 1, 0 )] = { tiles = { AddTile( 5000101, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0001)_01.tile", 5 ), AddTile( 5000102, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0001)_02.tile", 5 ), AddTile( 5000103, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0001)_03.tile", 5 ) }, rotation = 1 }
	g_burntForest[toBurntForestIndex( 0, 0, 1, 1 )] = { tiles = { AddTile( 5000301, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0011)_01.tile", 5 ), AddTile( 5000302, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0011)_02.tile", 5 ), AddTile( 5000303, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0011)_03.tile", 5 ) }, rotation = 0 }
	g_burntForest[toBurntForestIndex( 0, 1, 0, 0 )] = { tiles = { AddTile( 5000101, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0001)_01.tile", 5 ), AddTile( 5000102, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0001)_02.tile", 5 ), AddTile( 5000103, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0001)_03.tile", 5 ) }, rotation = 2 }
	g_burntForest[toBurntForestIndex( 0, 1, 0, 1 )] = { tiles = { AddTile( 5000501, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0101)_01.tile", 5 ) }, rotation = 0 }
	g_burntForest[toBurntForestIndex( 0, 1, 1, 0 )] = { tiles = { AddTile( 5000301, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0011)_01.tile", 5 ), AddTile( 5000302, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0011)_02.tile", 5 ), AddTile( 5000303, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0011)_03.tile", 5 ) }, rotation = 1 }
	g_burntForest[toBurntForestIndex( 0, 1, 1, 1 )] = { tiles = { AddTile( 5000701, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0111)_01.tile", 5 ), AddTile( 5000702, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0111)_02.tile", 5 ), AddTile( 5000703, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0111)_03.tile", 5 ) }, rotation = 0 }
	g_burntForest[toBurntForestIndex( 1, 0, 0, 0 )] = { tiles = { AddTile( 5000101, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0001)_01.tile", 5 ), AddTile( 5000102, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0001)_02.tile", 5 ), AddTile( 5000103, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0001)_03.tile", 5 ) }, rotation = 3 }
	g_burntForest[toBurntForestIndex( 1, 0, 0, 1 )] = { tiles = { AddTile( 5000301, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0011)_01.tile", 5 ), AddTile( 5000302, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0011)_02.tile", 5 ), AddTile( 5000303, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0011)_03.tile", 5 ) }, rotation = 3 }
	g_burntForest[toBurntForestIndex( 1, 0, 1, 0 )] = { tiles = { AddTile( 5000501, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0101)_01.tile", 5 ) }, rotation = 3 }
	g_burntForest[toBurntForestIndex( 1, 0, 1, 1 )] = { tiles = { AddTile( 5000701, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0111)_01.tile", 5 ), AddTile( 5000702, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0111)_02.tile", 5 ), AddTile( 5000703, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0111)_03.tile", 5 ) }, rotation = 3 }
	g_burntForest[toBurntForestIndex( 1, 1, 0, 0 )] = { tiles = { AddTile( 5000301, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0011)_01.tile", 5 ), AddTile( 5000302, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0011)_02.tile", 5 ), AddTile( 5000303, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0011)_03.tile", 5 ) }, rotation = 2 }
	g_burntForest[toBurntForestIndex( 1, 1, 0, 1 )] = { tiles = { AddTile( 5000701, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0111)_01.tile", 5 ), AddTile( 5000702, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0111)_02.tile", 5 ), AddTile( 5000703, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0111)_03.tile", 5 ) }, rotation = 2 }
	g_burntForest[toBurntForestIndex( 1, 1, 1, 0 )] = { tiles = { AddTile( 5000701, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0111)_01.tile", 5 ), AddTile( 5000702, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0111)_02.tile", 5 ), AddTile( 5000703, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(0111)_03.tile", 5 ) }, rotation = 1 }
	g_burntForest[toBurntForestIndex( 1, 1, 1, 1 )] = { tiles = { AddTile( 5001501, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(1111)_01.tile", 5 ), AddTile( 5001502, "$SURVIVAL_DATA/Terrain/Tiles/burnt_forest/BurntForest(1111)_02.tile", 5 ) }, rotation = 0 }
end

----------------------------------------------------------------------------------------------------
-- Getters
----------------------------------------------------------------------------------------------------

function getBurntForestTileIdAndRotation( cornerFlags, variationNoise, rotationNoise )
	if cornerFlags > 0 then
		local item = g_burntForest[cornerFlags]
		local tileCount = #item.tiles

		if tileCount == 0 then
			return ERROR_TILE_UUID, 0 --error tile
		end

		local rotation = cornerFlags == 15 and ( rotationNoise % 4 ) or item.rotation

		return item.tiles[variationNoise % tileCount + 1], rotation
	end

	return sm.uuid.getNil(), 0
end
