dofile( "$SURVIVAL_DATA/Scripts/terrain/random_generation.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )


-- Version history:
-- 2:	Changes int tile id to tile uuid
--		Added 'version'

----------------------------------------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------------------------------------

function Init( world, generatorIndex )
	g_world = world
	g_generatorIndex = generatorIndex

	-- initialize temp data
	g_assets = {}
	g_harvestables = {}
	g_kinematics = {}
	g_decals = {}
	g_nodes = {}
	g_creations = {}
	g_nodeCount = 0
	g_zoneIndex = 1
	
	g_cellData = {}
	g_cellData.version = 2
	g_cellData.creations = nil
	g_cellData.tiles = nil
	print( "Initializing warehouse terrain" )
end

----------------------------------------------------------------------------------------------------

function Create( xMin, xMax, yMin, yMax, seed, data )
	print( "Creating warehouse terrain" )
	g_cellData.creations = data.creations

	if data.tiles then
		g_cellData.tiles = {}
		for _, tile in ipairs( data.tiles ) do
			local uid = sm.terrainTile.getTileUuid( tile )
			g_cellData.tiles[tostring( uid )] = tile
		end
	end

	g_cellData.seed = os.time()
	math.randomseed( g_cellData.seed )
	print( g_cellData )
	sm.terrainData.save( g_cellData )

	CreateWorldTileStorageKey()
end

----------------------------------------------------------------------------------------------------

function Load()
	print( "Loading warehouse terrain")
	if sm.terrainData.exists() then
		g_cellData = sm.terrainData.load()
		print( g_cellData )
		if UpgradeCellData( g_cellData ) then
			sm.terrainData.save( g_cellData )
		end
		print( g_cellData )
		math.randomseed( g_cellData.seed )

		CreateWorldTileStorageKey()

		return true
	end
	print( "No terrain data found" )
	return false
end

function UpgradeCellData( cellData )
	sm.log.info( "UpgradeCellData - version: "..tostring( cellData.version or 1 ) )
	local upgraded = false
	-- 1 to 2
	if ( cellData.version or 1 ) < 2 then
		local tiles = shallowcopy( cellData.tiles )
		cellData.tiles = {}
		for _, tile in ipairs( tiles ) do
			local uid = sm.terrainTile.getTileUuid( tile )
			if not sm.uuid.isNil( uid ) then
				cellData.tiles[tostring( uid )] = tile
			else
				sm.log.error( "Tile '"..tile.."' not found" )
			end
		end
		cellData.version = 2
		upgraded = true
	end
	if upgraded then sm.log.info( "	- Upgraded to version "..tostring( cellData.version ) ) else sm.log.info( "	- No upgrade needed" ) end
	return upgraded
end

function CreateWorldTileStorageKey()
	if g_generatorIndex == 0 and sm.isHost then
		local worldId = g_world.id
		local cellTileStorageKeys = { indoor = true, worldKey = worldId }
		sm.terrainGeneration.setGameStorageNoSave( "tsk_"..worldId, cellTileStorageKeys )
	end
end

----------------------------------------------------------------------------------------------------
-- Generator API Getters
----------------------------------------------------------------------------------------------------

function GetHeightAt( x, y, lod )
	return 0
end

function GetColorAt( x, y, lod )
	return 0, 0, 0
end

function GetMaterialAt( x, y, lod )
	return 0, 0, 0, 0, 0, 0, 0, 0
end

function GetClutterIdxAt( x, y )
	return -1
end

function GetEffectMaterialAt( x, y )
	return "Dirt"
end

----------------------------------------------------------------------------------------------------

function GetAssetsForCell( cellX, cellY, lod )
	-- prepare cell writes assets to g_assets and they get returned in first lod (0)
	local assets = g_assets;
	g_assets = {}

	if cellX == 0 and cellY == 0 then
		if g_cellData.tiles then
			for sUid, _ in pairs( g_cellData.tiles ) do
				local tileAssets = sm.terrainTile.getAssetsForCell( sm.uuid.new( sUid ), 0, 0, lod )
				for _,asset in pairs( tileAssets ) do
					assets[#assets + 1] = asset
				end
			end
		end
	end
		
	if assets and #assets > 0 then
		return assets
	end
	return {}

end

function GetDecalsForCell( cellX, cellY )
	-- prepare cell writes decals to g_decals and they get returned in first lod (0)
	local decals = g_decals;
	g_decals = {}

	if cellX == 0 and cellY == 0 then
		if g_cellData.tiles then
			for sUid, _ in pairs( g_cellData.tiles ) do
				local tileDecals = sm.terrainTile.getDecalsForCell( sm.uuid.new( sUid ), 0, 0 )
				for _,decal in pairs( tileDecals ) do
					decals[#decals + 1] = decal
				end
			end
		end
	end
		
	if decals and #decals > 0 then
		return decals 
	end
	return {}
end

function GetHarvestablesForCell( cellX, cellY, lod )
	-- prepare cell writes harvestables to g_harvestables and they get returned in first lod (0)
	local harvestables = g_harvestables;
	g_harvestables = {}
	
	if cellX == 0 and cellY == 0 then
		if g_cellData.tiles then
			for sUid, _ in pairs( g_cellData.tiles ) do
				local tileHarvestables = sm.terrainTile.getHarvestablesForCell( sm.uuid.new( sUid ), 0, 0, lod )
				for _,harvestable in pairs( tileHarvestables ) do
					harvestables[#harvestables + 1] = harvestable
				end
			end
		end
	end

	if harvestables and #harvestables > 0 then
		return harvestables
	end
	return {}
end

function GetKinematicsForCell( cellX, cellY, lod )
	-- prepare cell writes kinematics to g_kinematic and they get returned in first lod (0)
	local kinematics = g_kinematics;
	g_kinematics = {}
	
	if cellX == 0 and cellY == 0 then
		if g_cellData.tiles then
			for sUid, _ in pairs( g_cellData.tiles ) do
				local tileKinematics = sm.terrainTile.getKinematicsForCell( sm.uuid.new( sUid ), 0, 0, lod )
				for _,kinematic in pairs( tileKinematics ) do
					kinematics[#kinematics + 1] = kinematic
				end
			end
		end
	end

	for _, kinematic in pairs( kinematics ) do
		if kinematic.params == nil then
			kinematic.params = {}
		end
	end

	if kinematics and #kinematics > 0 then
		return kinematics
	end
	return {}
end

----------------------------------------------------------------------------------------------------

blueprintTable = {}

blueprintTable["Kit_Warehouse_Hallway_Ceiling_Bend"] =					{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Hallway_Ceiling_Bend_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Hallway_Ceiling_Bend_01.blueprint" }

blueprintTable["Kit_Warehouse_Hallway_Floor"] =							{{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Hallway_Floor_01.blueprint", 89 },
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Hallway_Floor_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Hallway_Floor_03.blueprint" }

blueprintTable["Kit_Warehouse_Hallway_Wall"] =							{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Hallway_Wall_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Hallway_Wall_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Hallway_Wall_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Hallway_Wall_04.blueprint" }

blueprintTable["Kit_Warehouse_Hallway_Wall_InnCorner"] =				{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Hallway_Wall_InnCorner_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Hallway_Wall_InnCorner_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBasement_PipeBig_InnCorner"] =		{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBasement_PipeBig_InnCorner_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBasement_PipeBig_InnCorner_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBasement_PipeBig_Straight"] =		{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBasement_PipeBig_Straight_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBasement_PipeBig_Straight_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBlend_Floor"] =						{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBlend_Floor_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBlend_Floor_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBlend_Floor_03.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBlend_Floor_8x8"] =					{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBlend_Floor_8x8_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBlend_Floor_8x8_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Ceiling"] =				{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Ceiling_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Ceiling_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Ceiling_03.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Ceiling_End"] =			{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Ceiling_End_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Ceiling_End_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Floor_Edge"] =			{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Floor_Edge_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Floor_Edge_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Floor_InnCorner"] =		{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Floor_InnCorner_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Floor_InnCorner_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_LightStrip"] =			{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_LightStrip_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_LightStrip_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_LightStrip_Bend"] =		{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_LightStrip_Bend_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_LightStrip_Bend_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_LightStrip_End"] =		{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_LightStrip_End_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_LightStrip_End_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Pillar"] =				{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Pillar_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Pillar_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Pillar_03.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Scaffolding_1x1"] =		{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Scaffolding_1x1_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Scaffolding_1x1_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Scaffolding_1x5"] =		{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Scaffolding_1x5_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Scaffolding_1x5_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Wall"] =					{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_04.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_05.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Wall_DoorL"] =			{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_DoorL_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_DoorL_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Wall_DoorR"] =			{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_DoorR_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_DoorR_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Wall_EndL"] =				{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_EndL_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_EndL_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Wall_EndR"] =				{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_EndR_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_EndR_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Wall_InnCorner"] =		{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_InnCorner_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_InnCorner_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_InnCorner_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_InnCorner_04.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_InnCorner_05.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Wall_InnCorner_DoorL"] =	{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_InnCorner_DoorL_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_InnCorner_DoorL_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Wall_InnCorner_DoorR"] =	{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_InnCorner_DoorR_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_InnCorner_DoorR_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeBuildsite_Wall_OutCorner"] =		{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_OutCorner_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeBuildsite_Wall_OutCorner_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeClutter_Bricks"] =					{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_Bricks_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_Bricks_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_Bricks_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_Bricks_04.blueprint" }

blueprintTable["Kit_Warehouse_OfficeClutter_Bucket_Paint"] =			{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_Bucket_Paint_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_Bucket_Paint_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_Bucket_Paint_03.blueprint" }

blueprintTable["Kit_Warehouse_OfficeClutter_CarpetRack"] =				{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_CarpetRack_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_CarpetRack_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeClutter_Cubicle"] =					{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_Cubicle_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_Cubicle_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_Cubicle_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_Cubicle_04.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_Cubicle_05.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_Cubicle_06.blueprint" }

blueprintTable["Kit_Warehouse_OfficeClutter_RebarRubble"] =				{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_RebarRubble_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_RebarRubble_02.blueprint" }

blueprintTable["Kit_Warehouse_OfficeClutter_SupplyShelf"] =				{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_SupplyShelf_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_OfficeClutter_SupplyShelf_02.blueprint" }

blueprintTable["Kit_Warehouse_Storage_Wall"] =							{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Storage_Wall_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Storage_Wall_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Storage_Wall_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Storage_Wall_04.blueprint" }

blueprintTable["Kit_Warehouse_Storage_Wall_InnCorner"] =				{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Storage_Wall_InnCorner_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Storage_Wall_InnCorner_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Storage_Wall_InnCorner_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Storage_Wall_InnCorner_04.blueprint" }

blueprintTable["Kit_Warehouse_StorageShelf_ConcreteTall"] =				{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_StorageShelf_ConcreteTall_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_StorageShelf_ConcreteTall_02.blueprint" }

blueprintTable["Kit_Warehouse_Toilets_Stall"] =							{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Toilets_Stall_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Toilets_Stall_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Toilets_Stall_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Toilets_Stall_04.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Toilets_Stall_05.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Toilets_Stall_06.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Toilets_Stall_07.blueprint" }

blueprintTable["Kit_Warehouse_Utility_Generator_Ceiling"] =				{{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Utility_Generator_Ceiling_01.blueprint", 3 },
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_Utility_Generator_Ceiling_02.blueprint" }

blueprintTable["Kit_Warehouse_UtilityCrawlspace_Divider_Fan"] =			{	"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_UtilityCrawlspace_Divider_Fan_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_UtilityCrawlspace_Divider_Fan_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Kit_Warehouse_UtilityCrawlspace_Divider_Fan_03.blueprint" }

blueprintTable["Warehouse_Clutter_BoxStack_5x6"] =						{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_5x6_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_5x6_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_5x6_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_5x6_04.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_5x6_05.blueprint" }

blueprintTable["Warehouse_Clutter_BoxStack_7x8"] =						{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_7x8_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_7x8_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_7x8_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_7x8_04.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_7x8_05.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_7x8_06.blueprint" }

blueprintTable["Warehouse_Clutter_BoxStack_9x12"] =						{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_9x12_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_9x12_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_9x12_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_9x12_04.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxStack_9x12_05.blueprint" }

blueprintTable["Warehouse_Clutter_BoxWood"] =							{{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxWood_01.blueprint", 10 },
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxWood_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxWood_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_BoxWood_04.blueprint" }

blueprintTable["Warehouse_Clutter_FruitCrate"] =						{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_FruitCrate_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_FruitCrate_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_FruitCrate_03.blueprint" }

blueprintTable["Warehouse_Clutter_FruitSpill"] =						{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_FruitSpill_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_FruitSpill_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_FruitSpill_03.blueprint" }

blueprintTable["Warehouse_Clutter_Pallet_1x1"] =						{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x1_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x1_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x1_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x1_04.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x1_05.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x1_06.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x1_07.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x1_08.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x1_09.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x1_10.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x1_11.blueprint" }

blueprintTable["Warehouse_Clutter_Pallet_1x2"] =						{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x2_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x2_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x2_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x2_04.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x2_05.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1x2_06.blueprint" }

blueprintTable["Warehouse_Clutter_Pallet_1xOverhang"] =					{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1xOverhang_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1xOverhang_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1xOverhang_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1xOverhang_04.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1xOverhang_05.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1xOverhang_06.blueprint" }

blueprintTable["Warehouse_Clutter_Pallet_1xTower"] =					{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1xTower_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1xTower_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_1xTower_03.blueprint" }

blueprintTable["Warehouse_Clutter_Pallet_2x3"] =						{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_2x3_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_2x3_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Pallet_2x3_03.blueprint" }

blueprintTable["Warehouse_Clutter_Poster"] =							{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Poster_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Poster_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Poster_03.blueprint" }

blueprintTable["Warehouse_Clutter_Poster_Light"] =						{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Poster_Light_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Poster_Light_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Poster_Light_03.blueprint" }

blueprintTable["Warehouse_Clutter_PottedPlant"] =						{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_PottedPlant_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_PottedPlant_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_PottedPlant_03.blueprint" }

blueprintTable["Warehouse_Clutter_PottedPlant_Small"] =					{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_PottedPlant_Small_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_PottedPlant_Small_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_PottedPlant_Small_03.blueprint" }

blueprintTable["Warehouse_Clutter_Shelf_x2"] =							{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x2_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x2_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x2_03.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x2_04.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x2_05.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x2_06.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x2_07.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x2_08.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x2_09.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x2_10.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x2_11.blueprint" }

blueprintTable["Warehouse_Clutter_Shelf_x3"] =							{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x3_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x3_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x3_03.blueprint" }

blueprintTable["Warehouse_Clutter_Shelf_x4"] =							{	"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x4_01.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x4_02.blueprint",
																			"$SURVIVAL_DATA/LocalBlueprints/Warehouse_Clutter_Shelf_x4_03.blueprint" }

----------------------------------------------------------------------------------------------------

prefabTable = {}

prefabTable["Kit_Warehouse_StorageClutter_ShelfTall_Bot"] =				{	"$SURVIVAL_DATA/LocalPrefabs/Kit_Warehouse_StorageClutter_ShelfTall_Bot_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Kit_Warehouse_StorageClutter_ShelfTall_Bot_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Kit_Warehouse_StorageClutter_ShelfTall_Bot_03.prefab" }

prefabTable["Kit_Warehouse_StorageClutter_ShelfTall_Mid"] =				{	"$SURVIVAL_DATA/LocalPrefabs/Kit_Warehouse_StorageClutter_ShelfTall_Mid_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Kit_Warehouse_StorageClutter_ShelfTall_Mid_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Kit_Warehouse_StorageClutter_ShelfTall_Mid_03.prefab" }

prefabTable["Kit_Warehouse_StorageClutter_ShelfTall_Top"] =				{	"$SURVIVAL_DATA/LocalPrefabs/Kit_Warehouse_StorageClutter_ShelfTall_Top_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Kit_Warehouse_StorageClutter_ShelfTall_Top_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Kit_Warehouse_StorageClutter_ShelfTall_Top_03.prefab" }

prefabTable["Warehouse_Ductway_Straight"] =								{	"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Ductway_Straight_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Ductway_Straight_02.prefab" }

prefabTable["Warehouse_FillerRoom_Hint"] =								{	"$SURVIVAL_DATA/LocalPrefabs/Warehouse_FillerRoom_Hint_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_FillerRoom_Hint_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_FillerRoom_Hint_03.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_FillerRoom_Hint_04.prefab" }

prefabTable["Warehouse_Hallway_Short_DoorL"] =							{	"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Hallway_Short_DoorL_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Hallway_Short_DoorL_02.prefab" }

prefabTable["Warehouse_Hallway_Straight"] =								{	"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Hallway_Straight_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Hallway_Straight_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Hallway_Straight_03.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Hallway_Straight_04.prefab" }

prefabTable["Warehouse_Hallway_Straight_DoorL"] =						{	"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Hallway_Straight_DoorL_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Hallway_Straight_DoorL_02.prefab" }

prefabTable["Warehouse_Room_Packaging_4x3x2"] =							{	"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Packaging_4x3x2_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Packaging_4x3x2_02.prefab" }

prefabTable["Warehouse_Room_Packaging_4x4x2"] =							{	"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Packaging_4x4x2_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Packaging_4x4x2_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Packaging_4x4x2_03.prefab" }

prefabTable["Warehouse_Room_Packaging_4x5x2"] =							{	"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Packaging_4x5x2_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Packaging_4x5x2_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Packaging_4x5x2_03.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Packaging_4x5x2_04.prefab" }

prefabTable["Warehouse_Room_Packaging_4x6x2"] =							{	"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Packaging_4x6x2_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Packaging_4x6x2_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Packaging_4x6x2_03.prefab" }

prefabTable["Warehouse_Room_Storage_2x3x2"] =							{	"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Storage_2x3x2_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Storage_2x3x2_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Storage_2x3x2_03.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Storage_2x3x2_04.prefab" }

prefabTable["Warehouse_Room_Storage_3x5x2"] =							{	"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Storage_3x5x2_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Storage_3x5x2_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Storage_3x5x2_03.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Storage_3x5x2_04.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Storage_3x5x2_05.prefab" }

prefabTable["Warehouse_Room_Toilets_2x2x1"] =							{	"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Toilets_2x2x1_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Toilets_2x2x1_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Toilets_2x2x1_03.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Toilets_2x2x1_04.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Toilets_2x2x1_05.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Toilets_2x2x1_06.prefab" }

prefabTable["Warehouse_Room_Utility_1x2x1_Door_Ww"] =					{	"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Utility_1x2x1_Door_Ww_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Utility_1x2x1_Door_Ww_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Utility_1x2x1_Door_Ww_03.prefab" }

prefabTable["Warehouse_Room_Utility_3x4x2"] =							{	"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Utility_3x4x2_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Utility_3x4x2_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/Warehouse_Room_Utility_3x4x2_03.prefab" }

prefabTable["WarehouseOffice_Hallway_End_DoorM"] =						{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Hallway_End_DoorM_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Hallway_End_DoorM_02.prefab" }

prefabTable["WarehouseOffice_Hallway_End_DoorR"] =						{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Hallway_End_DoorR_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Hallway_End_DoorR_02.prefab" }

prefabTable["WarehouseOffice_Hallway_Long_Bend_HoleL"] =				{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Hallway_Long_Bend_HoleL_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Hallway_Long_Bend_HoleL_02.prefab" }

prefabTable["WarehouseOffice_HallwayStair_Down"] =						{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_HallwayStair_Down_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_HallwayStair_Down_02.prefab" }

prefabTable["WarehouseOffice_HallwayStair_Upp"] =						{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_HallwayStair_Upp_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_HallwayStair_Upp_02.prefab" }

prefabTable["WarehouseOffice_HallwayStair_UppDown"] =					{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_HallwayStair_UppDown_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_HallwayStair_UppDown_02.prefab" }

prefabTable["WarehouseOffice_Room_Buildsite_2x2x1"] =					{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Buildsite_2x2x1_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Buildsite_2x2x1_02.prefab" }

prefabTable["WarehouseOffice_Room_Buildsite_3x3x1"] =					{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Buildsite_3x3x1_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Buildsite_3x3x1_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Buildsite_3x3x1_03.prefab" }

prefabTable["WarehouseOffice_Room_Buildsite_3x4x1"] =					{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Buildsite_3x4x1_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Buildsite_3x4x1_02.prefab" }

prefabTable["WarehouseOffice_Room_Buildsite_3x5x1"] =					{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Buildsite_3x5x1_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Buildsite_3x5x1_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Buildsite_3x5x1_03.prefab" }

prefabTable["WarehouseOffice_Room_Buildsite_4x4x1"] =					{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Buildsite_4x4x1_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Buildsite_4x4x1_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Buildsite_4x4x1_03.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Buildsite_4x4x1_04.prefab" }

prefabTable["WarehouseOffice_Room_Lounge_2x2x1"] =						{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Lounge_2x2x1_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Lounge_2x2x1_02.prefab" }

prefabTable["WarehouseOffice_Room_Workplace_2x1x1"] =					{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_2x1x1_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_2x1x1_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_2x1x1_03.prefab" }

prefabTable["WarehouseOffice_Room_Workplace_2x3x1"] =					{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_2x3x1_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_2x3x1_02.prefab" }

prefabTable["WarehouseOffice_Room_Workplace_3x3x1"] =					{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_3x3x1_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_3x3x1_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_3x3x1_03.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_3x3x1_04.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_3x3x1_05.prefab" }

prefabTable["WarehouseOffice_Room_Workplace_3x4x1"] =					{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_3x4x1_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_3x4x1_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_3x4x1_03.prefab" }

prefabTable["WarehouseOffice_Room_Workplace_4x4x1"] =					{	"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_4x4x1_01.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_4x4x1_02.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_4x4x1_03.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_4x4x1_04.prefab",
																			"$SURVIVAL_DATA/LocalPrefabs/WarehouseOffice_Room_Workplace_4x4x1_05.prefab" }

----------------------------------------------------------------------------------------------------

colorTable = {}

--	PaintToolColors
--	0xeeeeeeff	0xf5f071ff	0xcbf66fff	0x68ff88ff	0x7eededff	0x4c6fe3ff	0xae79f0ff	0xee7bf0ff	0xf06767ff	0xeeaf5cff
--	0x7f7f7fff	0xe2db13ff	0xa0ea00ff	0x19e753ff	0x2ce6e6ff	0x0a3ee2ff	0x7514edff	0xcf11d2ff	0xd02525ff	0xdf7f00ff
--	0x4a4a4aff	0x817c00ff	0x577d07ff	0x0e8031ff	0x118787ff	0x0f2e91ff	0x500aa6ff	0x720a74ff	0x7c0000ff	0x673b00ff
--	0x222222ff	0x323000ff	0x005037ff	0x064023ff	0x0a4444ff	0x0a1d5aff	0x35086cff	0x520653ff	0x560202ff	0x472800ff

colorTable["YELLOW"] = {
	[0xdf7f00ff] = sm.color.new(0xe2db13ff)
}

colorTable["GREEN"] = {
	[0xdf7f00ff] = sm.color.new(0x0e8031ff)
}

colorTable["BLUE"] = {
	[0xdf7f00ff] = sm.color.new(0x4c6fe3ff)
}

colorTable["RED"] = {
	[0xdf7f00ff] = sm.color.new(0xd02525ff)
}

----------------------------------------------------------------------------------------------------

local function loadPrefab( prefab, loadFlags, prefabIndex, prefabName )

	RandomizePrefab( prefab, prefabTable )

	print( "Loading prefab: ", prefab.name, " tagged: ", prefab.tags )

	local creations, prefabs, nodes, assets, decals, harvestables, kinematics = sm.terrainTile.getContentFromPrefab( prefab.name, loadFlags )

	for _,creation in ipairs( creations ) do

		RandomizeCreation( creation, blueprintTable )
		creation.debugName = prefabName

		creation.rot = prefab.rot * creation.rot
		creation.pos = prefab.pos + (prefab.rot * creation.pos)
		creation.tags = prefab.tags
		
		for _, tag in ipairs( creation.tags ) do
			for key, value in pairs( colorTable ) do
				if tag == key then
					creation.changeColor = value
				end
			end
		end

		local isElevator = valueExists( creation.tags, "ENTRANCE" )
			or valueExists( creation.tags, "UP" )
			or valueExists( creation.tags, "DOWN" )
			or valueExists( creation.tags, "EXIT" )

		creation.mergeCreation = not isElevator
		creation.restricted = true
		creation.destructable = not isElevator

		creation.zoneIndex = prefabIndex

		g_creations[#g_creations + 1] = creation
	end


	for _,subPrefab in ipairs( prefabs ) do

		subPrefab.rot = prefab.rot * subPrefab.rot
		subPrefab.pos = prefab.pos + (prefab.rot * subPrefab.pos)
		for _,tag in ipairs(prefab.tags) do
			subPrefab.tags[#subPrefab.tags + 1] = tag
		end
		
		loadPrefab( subPrefab, loadFlags, prefabIndex, prefabName )
	end

	local nodeCount = g_nodeCount
	
	for _,node in ipairs( nodes ) do

		node.rot = prefab.rot * node.rot
		node.pos = prefab.pos + (prefab.rot * node.pos)

		if node.params and node.params.connections then
			node.params.connections.id = node.params.connections.id + g_nodeCount;

			for index, value in ipairs(node.params.connections.otherIds) do
				if (type(value) == "table") then
					value.id = value.id + g_nodeCount
				else
					node.params.connections.otherIds[index] = node.params.connections.otherIds[index] + g_nodeCount
				end
			end


			nodeCount = math.max( node.params.connections.id, nodeCount )
		end
		
		g_nodes[#g_nodes + 1] = node
	end

	for _,asset in ipairs( assets ) do

		asset.rot = prefab.rot * asset.rot
		asset.pos = prefab.pos + (prefab.rot * asset.pos)
		
		g_assets[#g_assets + 1] = asset
	end

	for _,decal in ipairs( decals ) do
		decal.rot = prefab.rot * decal.rot
		decal.pos = prefab.pos + (prefab.rot * decal.pos)
		
		g_decals[#g_decals + 1] = decal
	end

	for _,harvestable in ipairs( harvestables ) do
		harvestable.rot = prefab.rot * harvestable.rot
		harvestable.pos = prefab.pos + (prefab.rot * harvestable.pos)
		
		g_harvestables[#g_harvestables + 1] = harvestable
	end

	for _,kinematic in ipairs( kinematics ) do
		kinematic.rot = prefab.rot * kinematic.rot
		kinematic.pos = prefab.pos + (prefab.rot * kinematic.pos)
		
		g_kinematics[#g_kinematics + 1] = kinematic
	end

	g_nodeCount = nodeCount + 1
end

function PrepareCell( cellX, cellY, loadFlags )
	g_assets = {}
	g_harvestables = {}
	g_kinematics = {}
	g_decals = {}
	g_nodeCount = 0
	g_nodes = {}
	g_creations = {}
	g_zoneIndex = 1
	
	if cellX == 0 and cellY == 0 then
		if g_cellData.tiles then
			for sUid, _ in pairs( g_cellData.tiles ) do
				local prefabs = sm.terrainTile.getPrefabsForCell( sm.uuid.new( sUid ), cellX, cellY )
				for _, prefab in ipairs( prefabs ) do
					if valueExists( prefab.tags, "NO_ZONE" ) then
						loadPrefab( prefab, loadFlags, 0 )
					else
						loadPrefab( prefab, loadFlags, g_zoneIndex, prefab.name )
						g_zoneIndex = g_zoneIndex + 1
					end
				end
			end
		end
	end
end

function GetCreationsForCell( cellX, cellY )
	if cellX == 0 and cellY == 0 then
		-- Load creations from tile
		if g_cellData.tiles then
			for sUid, _ in pairs( g_cellData.tiles ) do
				local tileCreations = sm.terrainTile.getCreationsForCell( sm.uuid.new( sUid ), cellX, cellY )
				for _, creation in ipairs( tileCreations ) do
					
					RandomizeCreation( creation, blueprintTable )
					
					creation.mergeCreation = true
					creation.restricted = true
					creation.destructable = true

					if string.find( creation.pathOrJson, "Filler" ) or string.find( creation.pathOrJson, "Bedrock" )  then
						creation.debugName = creation.pathOrJson
						creation.zoneIndex = g_zoneIndex
						g_zoneIndex = g_zoneIndex + 1
					end
					
					g_creations[#g_creations + 1] = creation
				end
			end
		end

		-- Load creations from data.creations
		if g_cellData.creations then
			for _,creation in ipairs( g_cellData.creations ) do
				g_creations[#g_creations + 1] = { pathOrJson = creation, pos = sm.vec3.zero(), rot = sm.quat.identity(), bodyTransforms = true }
			end
		end
		
		return g_creations
	end
	return {}
end

function GetNodesForCell( cellX, cellY )
	if cellX == 0 and cellY == 0 then
		
		if g_cellData.tiles then
			for sUid, _ in pairs( g_cellData.tiles ) do
				-- Load nodes from cell
				local nodes = sm.terrainTile.getNodesForCell( sm.uuid.new( sUid ), cellX, cellY )
				
				local nodeCount = g_nodeCount
				
				for _, node in ipairs( nodes ) do

					if node.params and node.params.connections then
						node.params.connections.id = node.params.connections.id + g_nodeCount;
						for index, value in ipairs(node.params.connections.otherIds) do
							if (type(value) == "table") then
								value.id = value.id + g_nodeCount
							else
								node.params.connections.otherIds[index] = node.params.connections.otherIds[index] + g_nodeCount
							end
						end

						nodeCount = math.max( node.params.connections.id, nodeCount )
					end
					
					g_nodes[#g_nodes + 1] = node
				end

				g_nodeCount = nodeCount + 1
			end
		end

		local positions = {}
		local nodes = {}
		for _, node in ipairs( g_nodes ) do
			if valueExists( node.tags, "WAYPOINT" ) then
				positions[node.params.connections.id] = node.pos
				nodes[node.params.connections.id] = node
			end
		end

		local function find(tab,el)
			for index, value in pairs(tab) do
				if value == el then
					return index
				end
			end
			return nil
		end

		local function findFromMapOrArray( table, element )
			for index, value in pairs( table ) do
				if type( value ) == "table" then
					if value.id == element then
						return index
					end
				else
					if value == element then
						return index
					end
				end
			end
			return nil
		end

		-- Connect with nodes in proximity (n^2)
		for idA, posA in pairs( positions ) do
			for idB, posB in pairs( positions ) do
				if posA ~= nil and posB ~= nil then
					local len = (posA - posB):length2()
					if len < 1.0 and idA ~= idB then

						nodes[idA].pos = posA + (posB - posA)*0.5
						nodes[idA].scale.x = math.min(nodes[idA].scale.x, nodes[idB].scale.x)
						nodes[idA].scale.y = math.min(nodes[idA].scale.y, nodes[idB].scale.y)
						nodes[idA].scale.z = math.min(nodes[idA].scale.z, nodes[idB].scale.z)

						for _, value in ipairs( nodes[idB].params.connections.otherIds ) do
							if (type(value) == "table") then
								local id = findFromMapOrArray( nodes[value.id].params.connections.otherIds, idB )
								if id then
									table.remove( nodes[value.id].params.connections.otherIds, id )
								end
								table.insert( nodes[value.id].params.connections.otherIds, idA )

								table.insert( nodes[idA].params.connections.otherIds, value.id )
							else
								local id = findFromMapOrArray( nodes[value].params.connections.otherIds, idB )
								if id then
									table.remove( nodes[value].params.connections.otherIds, id )
								end
								table.insert( nodes[value].params.connections.otherIds, idA )

								table.insert( nodes[idA].params.connections.otherIds, value )
							end
						end

						local id = find( g_nodes, nodes[idB] )
						if id then
							table.remove( g_nodes, id )
						end

						positions[idB] = nil
					end
				end
			end
		end
		
		return g_nodes
	end
	return {}
end

----------------------------------------------------------------------------------------------------
-- Tile Reader Path Getter
----------------------------------------------------------------------------------------------------

function GetTilePath( uid )
	if g_cellData.tiles then
		return g_cellData.tiles[tostring( uid )]
	end
	return ""
end
