--This file is generated! Don't edit here.

----------------------------------------------------------------------------------------------------
-- Data
----------------------------------------------------------------------------------------------------

local g_field = {} --Flags lookup table

-------------------------------
-- Bits                      --
-- dir | SE | SW | NW | NE | --
-- bit |  3 |  2 |  1 |  0 | --
-------------------------------

local function toFieldIndex( se, sw, nw, ne )
	return bit.bor( bit.lshift( se, 3 ), bit.lshift( sw, 2 ), bit.lshift( nw, 1 ), bit.tobit( ne ) )
end

function initFieldTiles()
	for i=0, 15 do
		g_field[i] = { tiles = {}, rotation = 0 }
	end
	g_field[toFieldIndex( 0, 0, 0, 1 )] = { tiles = { AddTile( 4000101, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(0001)_01.tile", 4 ) }, rotation = 0 }
	g_field[toFieldIndex( 0, 0, 1, 0 )] = { tiles = { AddTile( 4000101, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(0001)_01.tile", 4 ) }, rotation = 1 }
	g_field[toFieldIndex( 0, 0, 1, 1 )] = { tiles = { AddTile( 4000301, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(0011)_01.tile", 4 ) }, rotation = 0 }
	g_field[toFieldIndex( 0, 1, 0, 0 )] = { tiles = { AddTile( 4000101, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(0001)_01.tile", 4 ) }, rotation = 2 }
	g_field[toFieldIndex( 0, 1, 0, 1 )] = { tiles = { AddTile( 4000501, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(0101)_01.tile", 4 ) }, rotation = 0 }
	g_field[toFieldIndex( 0, 1, 1, 0 )] = { tiles = { AddTile( 4000301, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(0011)_01.tile", 4 ) }, rotation = 1 }
	g_field[toFieldIndex( 0, 1, 1, 1 )] = { tiles = { AddTile( 4000701, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(0111)_01.tile", 4 ) }, rotation = 0 }
	g_field[toFieldIndex( 1, 0, 0, 0 )] = { tiles = { AddTile( 4000101, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(0001)_01.tile", 4 ) }, rotation = 3 }
	g_field[toFieldIndex( 1, 0, 0, 1 )] = { tiles = { AddTile( 4000301, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(0011)_01.tile", 4 ) }, rotation = 3 }
	g_field[toFieldIndex( 1, 0, 1, 0 )] = { tiles = { AddTile( 4000501, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(0101)_01.tile", 4 ) }, rotation = 3 }
	g_field[toFieldIndex( 1, 0, 1, 1 )] = { tiles = { AddTile( 4000701, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(0111)_01.tile", 4 ) }, rotation = 3 }
	g_field[toFieldIndex( 1, 1, 0, 0 )] = { tiles = { AddTile( 4000301, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(0011)_01.tile", 4 ) }, rotation = 2 }
	g_field[toFieldIndex( 1, 1, 0, 1 )] = { tiles = { AddTile( 4000701, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(0111)_01.tile", 4 ) }, rotation = 2 }
	g_field[toFieldIndex( 1, 1, 1, 0 )] = { tiles = { AddTile( 4000701, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(0111)_01.tile", 4 ) }, rotation = 1 }
	g_field[toFieldIndex( 1, 1, 1, 1 )] = { tiles = { AddTile( 4001501, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(1111)_01.tile", 4 ), AddTile( 4001502, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(1111)_02.tile", 4 ), AddTile( 4001503, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(1111)_03.tile", 4 ), AddTile( 4001504, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(1111)_04.tile", 4 ), AddTile( 4001505, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(1111)_05.tile", 4 ), AddTile( 4001506, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(1111)_06.tile", 4 ), AddTile( 4001507, "$SURVIVAL_DATA/Terrain/Tiles/field/Field(1111)_07.tile", 4 ) }, rotation = 0 }
end

----------------------------------------------------------------------------------------------------
-- Getters
----------------------------------------------------------------------------------------------------

function getFieldTileIdAndRotation( cornerFlags, variationNoise, rotationNoise )
	if cornerFlags > 0 then
		local item = g_field[cornerFlags]
		local tileCount = #item.tiles

		if tileCount == 0 then
			return ERROR_TILE_UUID, 0 --error tile
		end

		local rotation = cornerFlags == 15 and ( rotationNoise % 4 ) or item.rotation

		return item.tiles[variationNoise % tileCount + 1], rotation
	end

	return sm.uuid.getNil(), 0
end
