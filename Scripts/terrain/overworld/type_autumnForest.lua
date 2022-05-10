--This file is generated! Don't edit here.

----------------------------------------------------------------------------------------------------
-- Data
----------------------------------------------------------------------------------------------------

local g_autumnForest = {} --Flags lookup table

-------------------------------
-- Bits                      --
-- dir | SE | SW | NW | NE | --
-- bit |  3 |  2 |  1 |  0 | --
-------------------------------

local function toAutumnForestIndex( se, sw, nw, ne )
	return bit.bor( bit.lshift( se, 3 ), bit.lshift( sw, 2 ), bit.lshift( nw, 1 ), bit.tobit( ne ) )
end

function initAutumnForestTiles()
	for i=0, 15 do
		g_autumnForest[i] = { tiles = {}, rotation = 0 }
	end
	g_autumnForest[toAutumnForestIndex( 0, 0, 0, 1 )] = { tiles = { AddTile( 6000101, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_01.tile", 6 ), AddTile( 6000102, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_02.tile", 6 ), AddTile( 6000103, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_03.tile", 6 ), AddTile( 6000104, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_04.tile", 6 ), AddTile( 6000105, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_05.tile", 6 ) }, rotation = 0 }
	g_autumnForest[toAutumnForestIndex( 0, 0, 1, 0 )] = { tiles = { AddTile( 6000101, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_01.tile", 6 ), AddTile( 6000102, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_02.tile", 6 ), AddTile( 6000103, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_03.tile", 6 ), AddTile( 6000104, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_04.tile", 6 ), AddTile( 6000105, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_05.tile", 6 ) }, rotation = 1 }
	g_autumnForest[toAutumnForestIndex( 0, 0, 1, 1 )] = { tiles = { AddTile( 6000301, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_01.tile", 6 ), AddTile( 6000302, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_02.tile", 6 ), AddTile( 6000303, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_03.tile", 6 ), AddTile( 6000304, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_04.tile", 6 ), AddTile( 6000305, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_05.tile", 6 ) }, rotation = 0 }
	g_autumnForest[toAutumnForestIndex( 0, 1, 0, 0 )] = { tiles = { AddTile( 6000101, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_01.tile", 6 ), AddTile( 6000102, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_02.tile", 6 ), AddTile( 6000103, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_03.tile", 6 ), AddTile( 6000104, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_04.tile", 6 ), AddTile( 6000105, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_05.tile", 6 ) }, rotation = 2 }
	g_autumnForest[toAutumnForestIndex( 0, 1, 0, 1 )] = { tiles = { AddTile( 6000501, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0101)_01.tile", 6 ) }, rotation = 0 }
	g_autumnForest[toAutumnForestIndex( 0, 1, 1, 0 )] = { tiles = { AddTile( 6000301, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_01.tile", 6 ), AddTile( 6000302, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_02.tile", 6 ), AddTile( 6000303, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_03.tile", 6 ), AddTile( 6000304, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_04.tile", 6 ), AddTile( 6000305, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_05.tile", 6 ) }, rotation = 1 }
	g_autumnForest[toAutumnForestIndex( 0, 1, 1, 1 )] = { tiles = { AddTile( 6000701, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0111)_01.tile", 6 ) }, rotation = 0 }
	g_autumnForest[toAutumnForestIndex( 1, 0, 0, 0 )] = { tiles = { AddTile( 6000101, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_01.tile", 6 ), AddTile( 6000102, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_02.tile", 6 ), AddTile( 6000103, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_03.tile", 6 ), AddTile( 6000104, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_04.tile", 6 ), AddTile( 6000105, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0001)_05.tile", 6 ) }, rotation = 3 }
	g_autumnForest[toAutumnForestIndex( 1, 0, 0, 1 )] = { tiles = { AddTile( 6000301, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_01.tile", 6 ), AddTile( 6000302, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_02.tile", 6 ), AddTile( 6000303, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_03.tile", 6 ), AddTile( 6000304, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_04.tile", 6 ), AddTile( 6000305, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_05.tile", 6 ) }, rotation = 3 }
	g_autumnForest[toAutumnForestIndex( 1, 0, 1, 0 )] = { tiles = { AddTile( 6000501, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0101)_01.tile", 6 ) }, rotation = 3 }
	g_autumnForest[toAutumnForestIndex( 1, 0, 1, 1 )] = { tiles = { AddTile( 6000701, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0111)_01.tile", 6 ) }, rotation = 3 }
	g_autumnForest[toAutumnForestIndex( 1, 1, 0, 0 )] = { tiles = { AddTile( 6000301, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_01.tile", 6 ), AddTile( 6000302, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_02.tile", 6 ), AddTile( 6000303, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_03.tile", 6 ), AddTile( 6000304, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_04.tile", 6 ), AddTile( 6000305, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0011)_05.tile", 6 ) }, rotation = 2 }
	g_autumnForest[toAutumnForestIndex( 1, 1, 0, 1 )] = { tiles = { AddTile( 6000701, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0111)_01.tile", 6 ) }, rotation = 2 }
	g_autumnForest[toAutumnForestIndex( 1, 1, 1, 0 )] = { tiles = { AddTile( 6000701, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(0111)_01.tile", 6 ) }, rotation = 1 }
	g_autumnForest[toAutumnForestIndex( 1, 1, 1, 1 )] = { tiles = { AddTile( 6001501, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(1111)_01.tile", 6 ), AddTile( 6001502, "$SURVIVAL_DATA/Terrain/Tiles/autumn_forest/AutumnForest(1111)_02.tile", 6 ) }, rotation = 0 }
end

----------------------------------------------------------------------------------------------------
-- Getters
----------------------------------------------------------------------------------------------------

function getAutumnForestTileIdAndRotation( cornerFlags, variationNoise, rotationNoise )
	if cornerFlags > 0 then
		local item = g_autumnForest[cornerFlags]
		local tileCount = #item.tiles

		if tileCount == 0 then
			return ERROR_TILE_UUID, 0 --error tile
		end

		local rotation = cornerFlags == 15 and ( rotationNoise % 4 ) or item.rotation

		return item.tiles[variationNoise % tileCount + 1], rotation
	end

	return sm.uuid.getNil(), 0
end
