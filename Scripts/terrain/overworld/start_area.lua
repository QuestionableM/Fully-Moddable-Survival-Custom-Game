
----------------------------------------------------------------------------------------------------

function writeStartArea( pois )
	local xPos = -46
	local yPos = -46

	local function _addPoi( tileX, tileY, size )
		local x = tileX + math.floor( size / 2 )
		local y = tileY + math.floor( size / 2 )
		pois[#pois + 1] = { x = x, y = y, size = size, flat = true }
	end

	-- Crash site
	writeTile( getPoiTileId( POI_CRASHSITE_AREA, 1 ), xPos + 8, yPos + 4, 4, 0 )
	_addPoi( xPos + 8, yPos + 4, 4 )

	-- Crash site tower
	writeTile( getPoiTileId( POI_CRASHSITE_AREA, 2 ), xPos + 10, yPos + 7, 2, 0 )
	_addPoi( xPos + 10, yPos + 7, 2 )

	-- Crash site big ruin
	writeTile( getPoiTileId( POI_CRASHSITE_AREA, 3 ), xPos + 8, yPos + 9, 2, 0 )
	_addPoi( xPos + 8, yPos + 9, 2 )

	-- Crash site tower cliff
	writeTile( getPoiTileId( POI_CRASHSITE_AREA, 4 ), xPos + 10, yPos + 8, 1, 2 )

	-- Small ruin A
	writeTile( getPoiTileId( POI_CRASHSITE_AREA, 5 ), xPos + 14, yPos + 5, 1, 0 )
	_addPoi( xPos + 14, yPos + 5, 1 )

	-- Small ruin B
	writeTile( getPoiTileId( POI_CRASHSITE_AREA, 6 ), xPos + 5, yPos + 5, 1, 0 )
	_addPoi( xPos + 5, yPos + 5, 1 )

	-- Small ruin C
	writeTile( getPoiTileId( POI_CRASHSITE_AREA, 7 ), xPos + 9, yPos + 2, 1, 0 )
	_addPoi( xPos + 9, yPos + 2, 1 )

	-- Small ruin D
	writeTile( getPoiTileId( POI_CRASHSITE_AREA, 8 ), xPos + 6, yPos + 8, 1, 0 )
	_addPoi( xPos + 6, yPos + 8, 1 )


	local M = TYPE_MEADOW
	local F = TYPE_FOREST
	local L = TYPE_LAKE
	local X = true
	local O = false
	
	-- Corner data
	local type = {
		{ L, L, L, L, L, L, L, M, M, M, M, M, M, M, M, M, L, L, L, L, L },
		{ L, L, L, L, L, L, L, M, M, M, M, M, M, M, M, M, M, L, L, L, L },
		{ L, L, L, L, L, L, L, M, M, M, M, M, M, M, M, M, M, L, L, L, L },
		{ L, L, L, L, L, M, M, M, M, M, M, M, M, M, M, M, M, M, M, L, L },
		{ L, L, L, L, M, M, M, M, M, M, M, M, M, M, M, M, M, M, M, M, L },
		{ L, L, M, M, L, M, M, F, M, M, M, M, F, M, M, M, M, M, M, M, L },
		{ L, L, L, L, L, L, M, M, M, M, M, F, F, F, M, M, M, M, M, M, L },
		{ L, L, L, L, L, L, M, M, M, M, F, F, F, F, F, M, M, L, L, L, L },
		{ L, L, L, L, L, M, M, M, M, M, F, F, F, F, F, M, M, L, L, M, L },
		{ L, L, L, M, M, M, F, F, M, F, F, F, F, F, M, M, M, L, L, M, L },
		{ L, L, L, M, M, F, F, F, F, F, F, F, F, F, M, M, M, L, L, L, L },
		{ L, L, L, L, M, M, F, F, F, F, F, F, M, M, M, M, L, L, L, L, L },
		{ L, L, L, L, L, M, M, M, M, M, M, M, M, M, M, L, L, L, L, L, L },
		{ L, L, L, L, L, L, L, L, M, M, M, M, M, M, M, L, L, L, L, L, L },
		{ L, L, L, L, M, M, L, L, L, M, M, M, M, L, L, L, L, L, L, L, L },
		{ L, L, L, L, L, M, L, L, L, L, L, L, L, L, L, L, L, L, L, L, L },
		{ L, L, L, L, L, L, L, L, L, L, L, L, L, L, L, L, L, L, L, L, L }
	}
	local cliff = {
		{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 1, 1, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 3, 3, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 3, 3, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 1, 2, 3, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 1, 3, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 1, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 1, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
	}

	-- Cell data
	local static = {
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, X, X, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, X, X, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, X, O, O, O, X, X, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, X, X, X, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, X, X, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, X, O, O, X, X, X, O, O, O, X, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, X, X, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, X, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O }
	}
	local road = {
		{ O, O, O, O, O, O, O, O, O, O, O, X, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, X, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, X, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, X, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, X, X, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, X, X, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O },
		{ O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O, O }
	}

	-- Corners
	for y = 0, 16 do
		for x = 0, 20 do
			local cornerX = xPos + x
			local cornerY = yPos + y
			g_cornerTemp.type[cornerY][cornerX] = type[17 - y][1 + x]
			g_cellData.cliffLevel[cornerY][cornerX] = cliff[17 - y][1 + x]
		end
	end

	-- Cells
	for y = 0, 15 do
		for x = 0, 19 do
			local cellX = xPos + x
			local cellY = yPos + y
			g_cellTemp.road[cellY][cellX] = road[16 - y][1 + x]
			if static[16 - y][1 + x] then
				g_cornerTemp.hillyness[cellY][cellX] = 0
				g_cornerTemp.hillyness[cellY][cellX + 1] = 0
				g_cornerTemp.hillyness[cellY + 1][cellX] = 0
				g_cornerTemp.hillyness[cellY + 1][cellX + 1] = 0
			else
				g_cellData.uid[cellY][cellX] = sm.uuid.getNil()
				g_cellData.rotation[cellY][cellX] = 0
				g_cellData.xOffset[cellY][cellX] = 0
				g_cellData.yOffset[cellY][cellX] = 0
			end
		end
	end
	
	-- Exit
	g_cellTemp.road[yPos + 16][xPos + 11] = true
end

----------------------------------------------------------------------------------------------------
