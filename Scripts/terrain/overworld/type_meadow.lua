
----------------------------------------------------------------------------------------------------
-- Data
----------------------------------------------------------------------------------------------------

local g_meadowTiles = {}

function initMeadowTiles()
	g_meadowTiles = {
		AddTile( 1000001, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_01.tile", 1 ),
		AddTile( 1000002, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_02.tile", 1 ),
		AddTile( 1000003, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_03.tile", 1 ),
		AddTile( 1000004, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_04.tile", 1 ),
		AddTile( 1000005, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_05.tile", 1 ),
		AddTile( 1000006, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_06.tile", 1 ),
		AddTile( 1000007, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_07.tile", 1 ),
		AddTile( 1000008, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_08.tile", 1 ),
		AddTile( 1000009, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_09.tile", 1 ),
		AddTile( 1000010, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_10.tile", 1 ),
		AddTile( 1000011, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_11.tile", 1 ),
		AddTile( 1000012, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_12.tile", 1 ),
		AddTile( 1000013, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_13.tile", 1 ),
		AddTile( 1000014, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_14.tile", 1 ),
		AddTile( 1000015, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_15.tile", 1 ),
		AddTile( 1000016, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_16.tile", 1 ),
		AddTile( 1000017, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_17.tile", 1 ),
		AddTile( 1000018, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_18.tile", 1 ),
		AddTile( 1000019, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_19.tile", 1 ),
		AddTile( 1000020, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_20.tile", 1 ),
		AddTile( 1000021, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_21.tile", 1 ),
		AddTile( 1000022, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_22.tile", 1 ),
		AddTile( 1000023, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_23.tile", 1 ),
		AddTile( 1000024, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_24.tile", 1 ),
		AddTile( 1000025, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_25.tile", 1 ),
		AddTile( 1000026, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_26.tile", 1 ),
		AddTile( 1000027, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_27.tile", 1 ),
		AddTile( 1000028, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_28.tile", 1 ),
		AddTile( 1000029, "$SURVIVAL_DATA/Terrain/Tiles/meadow/Meadow_64(1111)_29.tile", 1 )
	}
end

----------------------------------------------------------------------------------------------------
-- Getters
----------------------------------------------------------------------------------------------------

function getMeadowTileIdAndRotation( cornerFlags, variationNoise, rotationNoise )
	if cornerFlags == 15 then
		local tileCount = #g_meadowTiles

		if tileCount == 0 then
			return ERROR_TILE_UUID, 0
		end

		return g_meadowTiles[variationNoise % tileCount + 1], rotationNoise % 4
	end

	return sm.uuid.getNil(), 0
end
