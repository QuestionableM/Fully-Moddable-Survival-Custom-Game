dofile "tile_database.lua"

--------------------------------------------------------------------------------
-- Cell type constants
--------------------------------------------------------------------------------

TYPE_MEADOW = 1
TYPE_FOREST = 2
TYPE_DESERT = 3
TYPE_FIELD = 4
TYPE_BURNTFOREST = 5
TYPE_AUTUMNFOREST = 6
-- 7
TYPE_LAKE = 8

DEBUG_R = 243
DEBUG_G = 244
DEBUG_B = 245
DEBUG_C = 246
DEBUG_M = 247
DEBUG_Y = 248
DEBUG_BLACK = 249
DEBUG_ORANGE = 250
DEBUG_PINK = 251
DEBUG_LIME = 252
DEBUG_SPRING = 253
DEBUG_PURPLE = 254
DEBUG_LAKE = 255

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

CELL_SIZE = 64

MASK_CLIFF = 0x00ff
MASK_ROADS = 0x0f00
MASK_ROADCLIFF = 0x0fff
MASK_TERRAINTYPE = 0xf000
MASK_FLAT = 0x10000

FLAG_ROAD_E = 0x0100
FLAG_ROAD_N = 0x0200
FLAG_ROAD_W = 0x0400
FLAG_ROAD_S = 0x0800

MASK_ROADS_SN = bit.bor( FLAG_ROAD_S, FLAG_ROAD_N )
MASK_ROADS_WE = bit.bor( FLAG_ROAD_W, FLAG_ROAD_E )

SHIFT_TERRAINTYPE = 12

ERROR_TILE_UUID = sm.uuid.new( "723268d4-8d59-4500-a433-7d900b61c29c" )

--------------------------------------------------------------------------------


--------------------------------------------------------------------------------

-- No type = MEADOW
-- No size = SMALL

-- Unique (MEADOW)
POI_CRASHSITE_AREA = 101 --predefined area
POI_HIDEOUT_XL = 102
POI_SILODISTRICT_XL = 103
POI_RUINCITY_XL = 104 --roads
POI_CRASHEDSHIP_LARGE = 105
POI_CAMP_LARGE = 106
POI_CAPSULESCRAPYARD_MEDIUM = 107
POI_LABYRINTH_MEDIUM = 108

-- Special (MEADOW)
POI_MECHANICSTATION_MEDIUM = 109 -- roads
POI_PACKINGSTATIONVEG_MEDIUM = 110 -- roads
POI_PACKINGSTATIONFRUIT_MEDIUM = 111 -- roads

-- Large Random
POI_WAREHOUSE2_LARGE = 112 -- 2 floors, roads
POI_WAREHOUSE3_LARGE = 113 -- 3 floors, roads
POI_WAREHOUSE4_LARGE = 114 -- 4 floors, roads
POI_BURNTFOREST_FARMBOTSCRAPYARD_LARGE = 501 -- burnt forest center


-- Small Random
POI_ROAD = 115 -- meadow with roads

POI_CAMP = 116
POI_RUIN = 117
POI_RANDOM = 118

POI_FOREST_CAMP = 201
POI_FOREST_RUIN = 202
POI_FOREST_RANDOM = 203

POI_DESERT_RANDOM = 301

POI_FARMINGPATCH = 119 -- meadow adjacent to field
POI_FIELD_RUIN = 401
POI_FIELD_RANDOM = 402

POI_BURNTFOREST_CAMP = 502
POI_BURNTFOREST_RUIN = 503
POI_BURNTFOREST_RANDOM = 504

POI_AUTUMNFOREST_CAMP = 601
POI_AUTUMNFOREST_RUIN = 602
POI_AUTUMNFOREST_RANDOM = 603

POI_LAKE_RANDOM = 801

-- Medium Random
POI_RUIN_MEDIUM = 120
POI_CHEMLAKE_MEDIUM = 121
POI_BUILDAREA_MEDIUM = 122

POI_FOREST_RUIN_MEDIUM = 204

POI_LAKE_UNDERWATER_MEDIUM = 802

-- Excavation
POI_EXCAVATION = 123

POI_RANDOM_PLACEHOLDER = 1
POI_TEST = 99

--------------------------------------------------------------------------------
-- Cell data
--------------------------------------------------------------------------------

-- Version history:
-- 2:	Changes integer 'tileId' to 'uid' from tile uuid
--		Renamed 'tileOffsetX' -> 'xOffset'
--		Renamed 'tileOffsetY' -> 'yOffset'
--		Added 'version'

g_cellData = {
	version = 2,
	bounds = { xMin=0, xMax=0, yMin=0, yMax=0 },
	seed = 0,
	-- Per corner
	elevation = {},
	cliffLevel = {},
	cornerDebug = {},
	-- Per Cell
	uid = {},
	xOffset = {},
	yOffset = {},
	rotation = {},
	flags = {},
	cellDebug = {}
}

--------------------------------------------------------------------------------
-- Initializes all cells for terrain bounds
--------------------------------------------------------------------------------

function initializeCellData( xMin, xMax, yMin, yMax, seed )
	g_cellData.bounds.xMin = xMin
	g_cellData.bounds.xMax = xMax
	g_cellData.bounds.yMin = yMin
	g_cellData.bounds.yMax = yMax
	g_cellData.seed = seed
	
	-- Corners
	for cornerY = yMin, yMax + 1 do
		g_cellData.elevation[cornerY] = {}
		g_cellData.cliffLevel[cornerY] = {}
		g_cellData.cornerDebug[cornerY] = {}

		for cornerX = xMin, xMax + 1 do
			g_cellData.elevation[cornerY][cornerX] = 0
			g_cellData.cliffLevel[cornerY][cornerX] = 0
			g_cellData.cornerDebug[cornerY][cornerX] = 0
		end
	end

	-- Cells
	for cellY = yMin, yMax do
		g_cellData.uid[cellY] = {}
		g_cellData.xOffset[cellY] = {}
		g_cellData.yOffset[cellY] = {}
		g_cellData.rotation[cellY] = {}
		g_cellData.flags[cellY] = {}
		g_cellData.cellDebug[cellY] = {}

		for cellX = xMin, xMax do
			g_cellData.uid[cellY][cellX] = sm.uuid.getNil()
			g_cellData.xOffset[cellY][cellX] = 0
			g_cellData.yOffset[cellY][cellX] = 0
			g_cellData.rotation[cellY][cellX] = 0
			g_cellData.flags[cellY][cellX] = 0
			g_cellData.cellDebug[cellY][cellX] = 0
		end
	end
end

--------------------------------------------------------------------------------
-- Corner data convenience functions
--------------------------------------------------------------------------------

function getCornerElevationLevel( cornerX, cornerY )
	if insideCornerBounds( cornerX, cornerY ) then
		return g_cellData.elevation[cornerY][cornerX]
	end
	return 0
end

--------------------------------------------------------------------------------

function getCornerCliffLevel( cornerX, cornerY )
	if insideCornerBounds( cornerX, cornerY ) then
		return g_cellData.cliffLevel[cornerY][cornerX]
	end
	return 0
end

--------------------------------------------------------------------------------

function getCornerData( cornerX, cornerY, data, default )
	if insideCornerBounds( cornerX, cornerY ) then
		return data[cornerY][cornerX]
	end
	return default
end

--------------------------------------------------------------------------------
-- Cell data convenience functions
--------------------------------------------------------------------------------

function GetCellTileUid( cellX, cellY )
	if insideCellBounds( cellX, cellY ) then
		return 	g_cellData.uid[cellY][cellX]
	end
	return sm.uuid.getNil()
end

--------------------------------------------------------------------------------

function getRoadCliffFlags( cellX, cellY )
	if insideCellBounds( cellX, cellY ) then
		return bit.band( g_cellData.flags[cellY][cellX], MASK_ROADCLIFF )
	end
	return 0
end

--------------------------------------------------------------------------------

function isFlat( cellX, cellY )
	if insideCellBounds( cellX, cellY ) then
		return bit.band( g_cellData.flags[cellY][cellX], MASK_FLAT ) ~= 0
	end
	return false
end

--------------------------------------------------------------------------------

function getCellType( cellX, cellY )
	if insideCellBounds( cellX, cellY ) then
		return bit.rshift( bit.band( g_cellData.flags[cellY][cellX], MASK_TERRAINTYPE ), SHIFT_TERRAINTYPE )
	end
	return 0
end

--------------------------------------------------------------------------------

function isLake( cellX, cellY )
	if insideCellBounds( cellX, cellY ) then
		return bit.rshift( bit.band( g_cellData.flags[cellY][cellX], MASK_TERRAINTYPE ), SHIFT_TERRAINTYPE ) == TYPE_LAKE
	end
	return false
end

--------------------------------------------------------------------------------

function getCellData( cellX, cellY, data, default )
	if insideCellBounds( cellX, cellY ) then
		return data[cellY][cellX]
	end
	return default
end

--------------------------------------------------------------------------------
-- Util
--------------------------------------------------------------------------------

function forEveryCorner( doThis )
	for cornerY = g_cellData.bounds.yMin, g_cellData.bounds.yMax + 1 do
		for cornerX = g_cellData.bounds.xMin, g_cellData.bounds.xMax + 1 do
			doThis( cornerX, cornerY )
		end
	end
end

--------------------------------------------------------------------------------

function forEveryCell( doThis )
	for cellY = g_cellData.bounds.yMin, g_cellData.bounds.yMax do
		for cellX = g_cellData.bounds.xMin, g_cellData.bounds.xMax do
			doThis( cellX, cellY )
		end
	end
end

--------------------------------------------------------------------------------
