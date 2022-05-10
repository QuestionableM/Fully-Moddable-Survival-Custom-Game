----------------------------------------------------------------------------------------------------
-- Data
----------------------------------------------------------------------------------------------------

local f_poiTiles = {}

----------------------------------------------------------------------------------------------------

function getPoiTileId( poiType, index )
	return f_poiTiles[poiType][index]
end

function getRandomPoiTileId( poiType, noise )
	local tileCount = 0
	if f_poiTiles[poiType] then
		tileCount = #f_poiTiles[poiType]
	end

	if tileCount == 0 then
		return ERROR_TILE_UUID, 0 --error tile
	end

	return f_poiTiles[poiType][noise % tileCount + 1]
end

----------------------------------------------------------------------------------------------------

local function addPoiTile( poiType, index, path, terrainType )
	if f_poiTiles[poiType] == nil then
		f_poiTiles[poiType] = {}
	end
	assert( index == #f_poiTiles[poiType] + 1 )
	f_poiTiles[poiType][#f_poiTiles[poiType] + 1] = AddTile( nil, path, terrainType, poiType )
end

local function addPoiTileLegacy( poiType, index, path, terrainType )
	if f_poiTiles[poiType] == nil then
		f_poiTiles[poiType] = {}
	end
	assert( index == #f_poiTiles[poiType] + 1 or poiType == POI_ROAD or poiType == POI_PACKINGSTATIONFRUIT_MEDIUM )

	local legacyId = poiType * 100 + index
	f_poiTiles[poiType][#f_poiTiles[poiType] + 1] = AddTile( legacyId, path, terrainType, poiType )
end

----------------------------------------------------------------------------------------------------

function initPoiTiles()
	-- Add new variations at the end if lists for old world compability.

	-- Starting area
	addPoiTileLegacy( POI_CRASHSITE_AREA, 1, "$SURVIVAL_DATA/Terrain/Tiles/start_area/SurvivalStartArea_CrashedShip_01.tile" )
	addPoiTileLegacy( POI_CRASHSITE_AREA, 2, "$SURVIVAL_DATA/Terrain/Tiles/start_area/SurvivalStartArea_CrashedTower_01.tile" )
	addPoiTileLegacy( POI_CRASHSITE_AREA, 3, "$SURVIVAL_DATA/Terrain/Tiles/start_area/SurvivalStartArea_BigRuin_01.tile" )
	addPoiTileLegacy( POI_CRASHSITE_AREA, 4, "$SURVIVAL_DATA/Terrain/Tiles/start_area/SurvivalStartArea_CrashedTowerCliff_01.tile" )
	addPoiTileLegacy( POI_CRASHSITE_AREA, 5, "$SURVIVAL_DATA/Terrain/Tiles/start_area/SurvivalStartArea_SmallRuin_A_01.tile" )
	addPoiTileLegacy( POI_CRASHSITE_AREA, 6, "$SURVIVAL_DATA/Terrain/Tiles/start_area/SurvivalStartArea_SmallRuin_B_01.tile" )
	addPoiTileLegacy( POI_CRASHSITE_AREA, 7, "$SURVIVAL_DATA/Terrain/Tiles/start_area/SurvivalStartArea_SmallRuin_C_01.tile" )
	addPoiTileLegacy( POI_CRASHSITE_AREA, 8, "$SURVIVAL_DATA/Terrain/Tiles/start_area/SurvivalStartArea_SmallRuin_D_01.tile" )

	-- Unique (MEADOW)
	addPoiTileLegacy( POI_HIDEOUT_XL, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Hideout_512_01.tile" )

	addPoiTileLegacy( POI_SILODISTRICT_XL, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/SiloDistrict_512_01.tile" )

	addPoiTileLegacy( POI_RUINCITY_XL, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/RuinCity_512_01.tile" )

	addPoiTileLegacy( POI_CRASHEDSHIP_LARGE, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/CrashedShip_256_01.tile" )

	addPoiTileLegacy( POI_CAMP_LARGE, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_WaterFront_256_01.tile" )

	addPoiTileLegacy( POI_CAPSULESCRAPYARD_MEDIUM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/SleepCapsuleBurial_128_01.tile" )

	addPoiTileLegacy( POI_LABYRINTH_MEDIUM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/HayBaleLabyrinth_128_01.tile" )

	-- Special (MEADOW)
	addPoiTileLegacy( POI_MECHANICSTATION_MEDIUM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/MechanicStation_128_01.tile" )

	addPoiTileLegacy( POI_PACKINGSTATIONVEG_MEDIUM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/PackingStation_Vegetable_128_01.tile" )

	addPoiTileLegacy( POI_PACKINGSTATIONFRUIT_MEDIUM, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/PackingStation_Fruit_128_01.tile" ) -- Issue: index starts at 2


	-- Large Random
	addPoiTileLegacy( POI_WAREHOUSE2_LARGE, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Warehouse_Exterior_2Floors_256_01.tile" )
	addPoiTileLegacy( POI_WAREHOUSE2_LARGE, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/Warehouse_Exterior_2Floors_256_02.tile" )
	addPoiTileLegacy( POI_WAREHOUSE2_LARGE, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/Warehouse_Exterior_2Floors_256_03.tile" )
	addPoiTileLegacy( POI_WAREHOUSE2_LARGE, 4, "$SURVIVAL_DATA/Terrain/Tiles/poi/Warehouse_Exterior_2Floors_256_04.tile" )

	addPoiTileLegacy( POI_WAREHOUSE3_LARGE, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Warehouse_Exterior_3Floors_256_01.tile" )

	addPoiTileLegacy( POI_WAREHOUSE4_LARGE, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Warehouse_Exterior_4Floors_256_01.tile" )

	addPoiTileLegacy( POI_BURNTFOREST_FARMBOTSCRAPYARD_LARGE, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/FarmbotGraveyard_256_01.tile" )
	addPoiTileLegacy( POI_BURNTFOREST_FARMBOTSCRAPYARD_LARGE, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/FarmbotGraveyard_256_02.tile" )

	-- Small Random
	-- Road
	addPoiTileLegacy( POI_ROAD, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Kiosk_64_01.tile" )
	addPoiTileLegacy( POI_ROAD, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Kiosk_64_01.tile" ) -- Added twice (to f_poiTiles[POI_ROAD]) for increased chance
	addPoiTileLegacy( POI_ROAD, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/Kiosk_64_02.tile" )
	addPoiTileLegacy( POI_ROAD, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/Kiosk_64_02.tile" ) -- Added twice (to f_poiTiles[POI_ROAD]) for increased chance
	addPoiTileLegacy( POI_ROAD, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/Kiosk_64_03.tile" )
	addPoiTileLegacy( POI_ROAD, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/Kiosk_64_03.tile" ) -- Added twice (to f_poiTiles[POI_ROAD]) for increased chance
	addPoiTileLegacy( POI_ROAD, 4, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Road_64_01.tile" )
	addPoiTileLegacy( POI_ROAD, 5, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Road_64_02.tile" )
	addPoiTileLegacy( POI_ROAD, 6, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Road_64_03.tile" )
	addPoiTileLegacy( POI_ROAD, 7, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Road_64_04.tile" )

	-- Meadow
	addPoiTileLegacy( POI_CAMP, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_Meadow_64_01.tile" )

	addPoiTileLegacy( POI_RUIN, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Meadow_64_01.tile" )
	addPoiTileLegacy( POI_RUIN, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Meadow_64_02.tile" )
	addPoiTileLegacy( POI_RUIN, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Meadow_64_03.tile" )
	addPoiTileLegacy( POI_RUIN, 4, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Meadow_64_04.tile" )

	addPoiTileLegacy( POI_RANDOM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Meadow_64_01.tile" )
	addPoiTileLegacy( POI_RANDOM, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Meadow_64_02.tile" )
	addPoiTileLegacy( POI_RANDOM, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Meadow_64_03.tile" )
	addPoiTileLegacy( POI_RANDOM, 4, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Meadow_64_04.tile" )
	addPoiTileLegacy( POI_RANDOM, 5, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Meadow_64_01.tile" )
	addPoiTileLegacy( POI_RANDOM, 6, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Meadow_64_02.tile" )
	addPoiTileLegacy( POI_RANDOM, 7, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Meadow_64_03.tile" )
	addPoiTileLegacy( POI_RANDOM, 8, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Meadow_64_04.tile" )
	addPoiTileLegacy( POI_RANDOM, 9, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Meadow_64_05.tile" )

	-- Replaces field with meadow
	addPoiTileLegacy( POI_FARMINGPATCH, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/FarmingPatch_64_01.tile" )
	addPoiTileLegacy( POI_FARMINGPATCH, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/FarmingPatch_64_02.tile" )
	addPoiTileLegacy( POI_FARMINGPATCH, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/FarmingPatch_64_03.tile" )

	-- Forest
	addPoiTileLegacy( POI_FOREST_CAMP, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_Forest_64_01.tile" )
	addPoiTileLegacy( POI_FOREST_CAMP, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_Forest_64_02.tile" )
	addPoiTileLegacy( POI_FOREST_CAMP, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_Forest_64_03.tile" )
	addPoiTileLegacy( POI_FOREST_CAMP, 4, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_Forest_64_04.tile" )
	addPoiTileLegacy( POI_FOREST_CAMP, 5, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_Forest_64_05.tile" )
	addPoiTileLegacy( POI_FOREST_CAMP, 6, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_Forest_64_06.tile" )
	addPoiTileLegacy( POI_FOREST_CAMP, 7, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_Forest_64_07.tile" )

	addPoiTileLegacy( POI_FOREST_RUIN, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Forest_64_01.tile" )
	addPoiTileLegacy( POI_FOREST_RUIN, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Forest_64_02.tile" )
	addPoiTileLegacy( POI_FOREST_RUIN, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Forest_64_03.tile" )

	addPoiTileLegacy( POI_FOREST_RANDOM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Forest_64_01.tile" )
	addPoiTileLegacy( POI_FOREST_RANDOM, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Forest_64_02.tile" )
	addPoiTileLegacy( POI_FOREST_RANDOM, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Forest_64_03.tile" )
	addPoiTileLegacy( POI_FOREST_RANDOM, 4, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Forest_64_01.tile" )
	addPoiTileLegacy( POI_FOREST_RANDOM, 5, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Forest_64_02.tile" )
	addPoiTileLegacy( POI_FOREST_RANDOM, 6, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Forest_64_03.tile" )
	addPoiTileLegacy( POI_FOREST_RANDOM, 7, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Forest_64_04.tile" )

	-- Desert
	addPoiTileLegacy( POI_DESERT_RANDOM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Desert_64_01.tile" )
	addPoiTileLegacy( POI_DESERT_RANDOM, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Desert_64_02.tile" )

	-- Field
	addPoiTileLegacy( POI_FIELD_RUIN, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Field_64_01.tile" )

	addPoiTileLegacy( POI_FIELD_RANDOM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Field_64_01.tile" )
	addPoiTileLegacy( POI_FIELD_RANDOM, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Field_64_02.tile" )
	addPoiTileLegacy( POI_FIELD_RANDOM, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Field_64_03.tile" )

	-- Burnt forest
	addPoiTileLegacy( POI_BURNTFOREST_CAMP, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_BurntForest_64_01.tile" )

	addPoiTileLegacy( POI_BURNTFOREST_RUIN, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_BurntForest_64_01.tile" )

	addPoiTile( POI_BURNTFOREST_RANDOM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_BurntForest_64_01.tile" ) -- Issue: Was POI_BURNTFOREST_CAMP in POI_BURNTFOREST_RANDOM list. Note: Upgrade should be fine since ( POI_BURNTFOREST_CAMP, 1 ) also exists.
	addPoiTileLegacy( POI_BURNTFOREST_RANDOM, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_BurntForest_64_01.tile" )

	-- Autumn forest
	addPoiTileLegacy( POI_AUTUMNFOREST_CAMP, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_AutumnForest_64_01.tile" )
	addPoiTileLegacy( POI_AUTUMNFOREST_CAMP, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_AutumnForest_64_02.tile" )
	addPoiTileLegacy( POI_AUTUMNFOREST_CAMP, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_AutumnForest_64_03.tile" )

	addPoiTileLegacy( POI_AUTUMNFOREST_RUIN, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_AutumnForest_64_01.tile" )

	addPoiTileLegacy( POI_AUTUMNFOREST_RANDOM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_AutumnForest_64_01.tile" )
	addPoiTileLegacy( POI_AUTUMNFOREST_RANDOM, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_AutumnForest_64_01.tile" )
	addPoiTileLegacy( POI_AUTUMNFOREST_RANDOM, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_AutumnForest_64_02.tile" )
	addPoiTileLegacy( POI_AUTUMNFOREST_RANDOM, 4, "$SURVIVAL_DATA/Terrain/Tiles/poi/CampingSpot_AutumnForest_64_03.tile" )

	-- Lake
	addPoiTileLegacy( POI_LAKE_RANDOM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_64_01.tile" )
	addPoiTileLegacy( POI_LAKE_RANDOM, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_64_02.tile" )
	addPoiTileLegacy( POI_LAKE_RANDOM, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_64_03.tile" )
	addPoiTileLegacy( POI_LAKE_RANDOM, 4, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_64_01.tile" )
	addPoiTileLegacy( POI_LAKE_RANDOM, 5, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_64_01.tile" )
	addPoiTileLegacy( POI_LAKE_RANDOM, 6, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_64_01.tile" )
	addPoiTileLegacy( POI_LAKE_RANDOM, 7, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_64_01.tile" )
	addPoiTileLegacy( POI_LAKE_RANDOM, 8, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_64_01.tile" )
	addPoiTileLegacy( POI_LAKE_RANDOM, 9, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_64_01.tile" )

	-- Medium Random
	addPoiTileLegacy( POI_CHEMLAKE_MEDIUM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/ChemicalLake_128_01.tile" )
	addPoiTileLegacy( POI_CHEMLAKE_MEDIUM, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/ChemicalLake_128_02.tile" )
	addPoiTileLegacy( POI_CHEMLAKE_MEDIUM, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/ChemicalLake_128_03.tile" )

	addPoiTileLegacy( POI_RUIN_MEDIUM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Meadow_128_01.tile" )
	addPoiTileLegacy( POI_RUIN_MEDIUM, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Meadow_128_02.tile" )
	addPoiTileLegacy( POI_RUIN_MEDIUM, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Meadow_128_03.tile" )
	addPoiTileLegacy( POI_RUIN_MEDIUM, 4, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Meadow_128_04.tile" )

	addPoiTileLegacy( POI_BUILDAREA_MEDIUM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Meadow_128_01.tile" )

	addPoiTileLegacy( POI_FOREST_RUIN_MEDIUM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Ruin_Forest_128_01.tile" )
	addPoiTileLegacy( POI_FOREST_RUIN_MEDIUM, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Forest_128_01.tile" )

	addPoiTileLegacy( POI_LAKE_UNDERWATER_MEDIUM, 1, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_128_01.tile" )
	addPoiTileLegacy( POI_LAKE_UNDERWATER_MEDIUM, 2, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_128_02.tile" )
	addPoiTileLegacy( POI_LAKE_UNDERWATER_MEDIUM, 3, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Island_128_01.tile" )
	addPoiTileLegacy( POI_LAKE_UNDERWATER_MEDIUM, 4, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_128_02.tile" )
	addPoiTileLegacy( POI_LAKE_UNDERWATER_MEDIUM, 5, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_128_01.tile" )
	addPoiTileLegacy( POI_LAKE_UNDERWATER_MEDIUM, 6, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_128_01.tile" )
	addPoiTileLegacy( POI_LAKE_UNDERWATER_MEDIUM, 7, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_128_01.tile" )
	addPoiTileLegacy( POI_LAKE_UNDERWATER_MEDIUM, 8, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_128_01.tile" )
	addPoiTileLegacy( POI_LAKE_UNDERWATER_MEDIUM, 9, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_128_01.tile" )
	addPoiTileLegacy( POI_LAKE_UNDERWATER_MEDIUM, 10, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_128_01.tile" )
	addPoiTileLegacy( POI_LAKE_UNDERWATER_MEDIUM, 11, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_128_01.tile" )
	addPoiTileLegacy( POI_LAKE_UNDERWATER_MEDIUM, 12, "$SURVIVAL_DATA/Terrain/Tiles/poi/Random_Lake_128_01.tile" )













-- Odd upgrade paths (for player worlds hacked with -dev flag)
	AddLegacyUpgrade( POI_TEST * 100 + 1, sm.uuid.new( "68794ad2-e70f-4f68-8dc1-4b396a927d07" ) ) --Ruin_Meadow_64_01.tile
	AddLegacyUpgrade( POI_TEST * 100 + 2, sm.uuid.new( "a3b7e066-2530-404e-9c4b-d311f569748c" ) ) --Ruin_Meadow_128_01.tile
	AddLegacyUpgrade( POI_TEST * 100 + 3, sm.uuid.new( "68794ad2-e70f-4f68-8dc1-4b396a927d07" ) ) --Ruin_Meadow_64_01.tile
	AddLegacyUpgrade( POI_TEST * 100 + 4, sm.uuid.new( "68794ad2-e70f-4f68-8dc1-4b396a927d07" ) ) --Ruin_Meadow_64_01.tile
	AddLegacyUpgrade( POI_TEST * 100 + 5, sm.uuid.new( "68794ad2-e70f-4f68-8dc1-4b396a927d07" ) ) --Ruin_Meadow_64_01.tile

end
