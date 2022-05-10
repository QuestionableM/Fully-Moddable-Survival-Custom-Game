dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/celldata.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/roads_and_cliffs.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/type_meadow.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/type_forest.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/type_field.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/type_burntForest.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/type_autumnForest.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/type_lake.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/type_desert.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/poi.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/start_area.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/terrain_util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/terrain_util2.lua" )

----------------------------------------------------------------------------------------------------

function writePoiDebug( cellX, cellY, cellDebug, size )
	for y0 = 0, size - 1 do
		for x0 = 0, size - 1 do
			local x = cellX + x0 - math.floor( size / 2 )
			local y = cellY + y0 - math.floor( size / 2 )
			if insideCornerBounds( x, y ) then
				g_cellData.cellDebug[y][x] = cellDebug
			end
		end
	end
end

----------------------------------------------------------------------------------------------------

function flattenPoiCliff( poi )
	local type = math.floor( poi.type / 100 )
	if type == 0 then type = TYPE_MEADOW end
	local pad = type ~= TYPE_MEADOW and 1 or 0
	-- Cliff level flatten
	for y0 = -pad, poi.size + pad do
		for x0 = -pad, poi.size + pad do
			local x = poi.x + x0 - math.floor( poi.size / 2 )
			local y = poi.y + y0 - math.floor( poi.size / 2 )
			if insideCornerBounds( x, y ) then
				g_cornerTemp.type[y][x] = type
				g_cellData.cliffLevel[y][x] = poi.cliffLevel
				g_cornerTemp.forceFlat[y][x] = true
			end
		end
	end
end

----------------------------------------------------------------------------------------------------

function setLakeAdjacentPoiHillynessToZero( poi )
	if not poi.flat then
		return
	end
	local halfSize = math.floor( poi.size / 2 )

	local lake = false

	for y0 = -1, poi.size + 1 do
		local corner = y0 == -1 or y0 == poi.size + 1
		for x0 = corner and 0 or -1, poi.size + ( corner and 0 or 1 ) do
			local x = poi.x + x0 - halfSize
			local y = poi.y + y0 - halfSize
			if insideCornerBounds( x, y ) then
				if g_cornerTemp.lakeAdjacent[y][x] then
					lake = true
				end
			end
		end
	end

	if lake then
		for y0 = -1, poi.size + 1 do
			local corner = y0 == -1 or y0 == poi.size + 1
			for x0 = corner and 0 or -1, poi.size + ( corner and 0 or 1 ) do
				local x = poi.x + x0 - halfSize
				local y = poi.y + y0 - halfSize
				if insideCornerBounds( x, y ) then
					g_cornerTemp.hillyness[y][x] = 0
				end
			end
		end
	end
end

----------------------------------------------------------------------------------------------------

function flattenPoiElevation( poi )
	if not poi.flat then
		return
	end
	local halfSize = math.floor( poi.size / 2 )

	-- Elevation flatten
	local avg = 0
	local count = 0
	local lake = false

	for y0 = -1, poi.size + 1 do
		local corner = y0 == -1 or y0 == poi.size + 1
		for x0 = corner and 0 or -1, poi.size + ( corner and 0 or 1 ) do
			local x = poi.x + x0 - halfSize
			local y = poi.y + y0 - halfSize
			if insideCornerBounds( x, y ) then
				avg = avg + g_cellData.elevation[y][x]
				count = count + 1
				lake = lake or g_cornerTemp.lakeAdjacent[y][x] or poi.type == POI_TEST
			end
		end
	end

	if lake then
		avg = 0
	else
		avg = round( 4 * avg / count ) / 4 -- Round to block grid
	end

	for y0 = -1, poi.size + 1 do
		local corner = y0 == -1 or y0 == poi.size + 1
		for x0 = corner and 0 or -1, poi.size + ( corner and 0 or 1 ) do
			local x = poi.x + x0 - halfSize
			local y = poi.y + y0 - halfSize
			if insideCornerBounds( x, y ) then
				g_cellData.elevation[y][x] = avg
			end
		end
	end

	for y0 = 0, poi.size  do
		for x0 = 0, poi.size do
			local x = poi.x + x0 - math.floor( poi.size / 2 )
			local y = poi.y + y0 - math.floor( poi.size / 2 )
			if insideCellBounds( x, y ) then
				g_cellData.flags[y][x] = bit.bor( g_cellData.flags[y][x], MASK_FLAT )
			end
		end
	end
end

----------------------------------------------------------------------------------------------------

function isNeighbor( pois, a, b )
	local x0 = pois[a].x
	local y0 = pois[a].y
	local x1 = pois[b].x
	local y1 = pois[b].y
	
	--In between point
	local cx = ( x0 + x1 ) / 2
	local cy = ( y0 + y1 ) / 2
	
	local dd = dist2( x0, y0, cx, cy )
	
	for i = 1, #pois do
		if i ~= a and i ~= b and dist2( pois[i].x, pois[i].y, cx, cy ) < dd then
			return false
		end
	end
	return true
end

----------------------------------------------------------------------------------------------------

function closestPoi( pois, cellX, cellY )
	local minDist2 = math.huge
	local poi
	for _,p in pairs( pois ) do
		local dd = dist2( p.x, p.y, cellX, cellY )
		if dd < minDist2 then
			minDist2 = dd
			poi = p
		end
	end
	return math.sqrt( minDist2 ), poi
end

----------------------------------------------------------------------------------------------------

function collides( xPos, yPos, size, pois )
	local x = xPos - math.floor( size / 2 )
	local y = yPos - math.floor( size / 2 )
	for _,p in ipairs( pois ) do
		local xDist = math.abs( xPos - p.x )
		local yDist = math.abs( yPos - p.y )
		local minDist = ( size + p.size ) / 2 + 1 --The bigger the difference between poi cliff levels, the bigger this number needs to be.
		if xDist < minDist and yDist < minDist then
			return true
		end
	end
	return false
end

----------------------------------------------------------------------------------------------------

function writeTile( tileId, xPos, yPos, size, rotation, terrainType )
	assert( type( tileId ) == "Uuid" )
	for y = 0, size - 1 do
		for x = 0, size - 1 do
			local cellX = x + xPos
			local cellY = y + yPos
			g_cellData.uid[cellY][cellX] = tileId
			g_cellData.rotation[cellY][cellX] = rotation
			if terrainType then
				g_cellData.flags[cellY][cellX] = bit.bor( g_cellData.flags[cellY][cellX], bit.band( bit.lshift( terrainType, SHIFT_TERRAINTYPE ), MASK_TERRAINTYPE ) )
			end

			if rotation == 1 then
				g_cellData.xOffset[cellY][cellX] = y
				g_cellData.yOffset[cellY][cellX] = ( size - 1 ) - x
			elseif rotation == 2 then
				g_cellData.xOffset[cellY][cellX] = ( size - 1 ) - x
				g_cellData.yOffset[cellY][cellX] = ( size - 1 ) - y
			elseif rotation == 3 then
				g_cellData.xOffset[cellY][cellX] = ( size - 1 ) - y
				g_cellData.yOffset[cellY][cellX] = x
			else
				g_cellData.xOffset[cellY][cellX] = x
				g_cellData.yOffset[cellY][cellX] = y
			end
		end
	end
end

----------------------------------------------------------------------------------------------------

function writePoi( poi )
	local variationNoise = poi.index and poi.index - 1 or sm.noise.intNoise2d( poi.x, poi.y, g_cellData.seed + 2854 )
	local tileId = getRandomPoiTileId( poi.type, variationNoise )
	local rotation = poi.rotation or ( sm.noise.intNoise2d( poi.x, poi.y, g_cellData.seed + 9439 ) % 4 )

	assert( tileId ~= -1, "Error: Unkown poi type!" )

	local x = poi.x - math.floor( poi.size / 2 )
	local y = poi.y - math.floor( poi.size / 2 )
	if insideCellBounds( x, y ) and insideCellBounds( x + poi.size - 1, y + poi.size - 1 ) then
		local terrainType = math.floor( poi.type / 100 )
		writeTile( tileId, x, y, poi.size, rotation, terrainType )
	else
		sm.log.warning( "Poi out of bounds! ("..poi.x..","..poi.y.."):"..poi.size )
	end
end

----------------------------------------------------------------------------------------------------

function addBorderingMeadows()
	forEveryCell( function( cellX, cellY )
		if g_cornerTemp.type[cellY][cellX] ~= TYPE_MEADOW and g_cornerTemp.type[cellY][cellX + 1] ~= TYPE_MEADOW then
			if g_cornerTemp.type[cellY][cellX] ~= g_cornerTemp.type[cellY][cellX + 1] then
				g_cornerTemp.type[cellY][cellX + 1] = TYPE_MEADOW
			end
		end
		if g_cornerTemp.type[cellY][cellX] ~= TYPE_MEADOW and g_cornerTemp.type[cellY + 1][cellX] ~= TYPE_MEADOW then
			if g_cornerTemp.type[cellY][cellX] ~= g_cornerTemp.type[cellY + 1][cellX] then
				g_cornerTemp.type[cellY + 1][cellX] = TYPE_MEADOW
			end
		end
		if g_cornerTemp.type[cellY][cellX] ~= TYPE_MEADOW and g_cornerTemp.type[cellY + 1][cellX + 1] ~= TYPE_MEADOW then
			if g_cornerTemp.type[cellY][cellX] ~= g_cornerTemp.type[cellY + 1][cellX + 1] then
				g_cornerTemp.type[cellY + 1][cellX + 1] = TYPE_MEADOW
			end
		end
		if g_cornerTemp.type[cellY + 1][cellX] ~= TYPE_MEADOW and g_cornerTemp.type[cellY][cellX + 1] ~= TYPE_MEADOW then
			if g_cornerTemp.type[cellY + 1][cellX] ~= g_cornerTemp.type[cellY][cellX + 1] then
				g_cornerTemp.type[cellY][cellX + 1] = TYPE_MEADOW
			end
		end
	end )
end

----------------------------------------------------------------------------------------------------

function getRoad( cellX, cellY )
	return getCellData( cellX, cellY, g_cellTemp.road, false )
end

----------------------------------------------------------------------------------------------------

function enforceCliffRoadLimitations()
	function maxCliffClamp( x, y, lower )
		local corrections = 0
		local violations = 0
		local offsets = {
			{ x = -1, y = -1 },
			{ x =  0, y = -1 },
			{ x =  1, y = -1 },
			{ x =  1, y =  0 },
			{ x =  1, y =  1 },
			{ x =  0, y =  1 },
			{ x = -1, y =  1 },
			{ x = -1, y =  0 }
		}
	
		if lower then
			local m = math.huge
			
			for _,o in ipairs( offsets ) do
				m = math.min( m, getCornerCliffLevel( x + o.x, y + o.y ) )
			end
			
			if m < g_cellData.cliffLevel[y][x] - 3 then
				if not g_cornerTemp.forceFlat[y][x] then
					g_cellData.cliffLevel[y][x] = m + 3
					corrections = corrections + 1
				else
					violations = violations + 1
				end
			end
		else
			local m = -math.huge
			
			for _,o in ipairs( offsets ) do
				m = math.max( m, getCornerCliffLevel( x + o.x, y + o.y ) )
			end
			
			if m > g_cellData.cliffLevel[y][x] + 3 then
				if not g_cornerTemp.forceFlat[y][x] then
					g_cellData.cliffLevel[y][x] = m - 3
					corrections = corrections + 1
				else
					violations = violations + 1
				end
			end
		end
		if violations > 0 then
			--print( "Violation at cell: ("..x..","..y..")".." - /tp",x*8,y*8,64)
		end
		return corrections, violations
	end
	
	function roadCliffClamp( x, y, lower )
		local corrections = 0
		local violations = 0
		if getRoad( x, y ) then
			local c00 = getCornerCliffLevel( x, y )
			local c10 = getCornerCliffLevel( x + 1, y )
			local c11 = getCornerCliffLevel( x + 1, y + 1 )
			local c01 = getCornerCliffLevel( x, y + 1 )
			
			local neighborRoadCount = 0
			neighborRoadCount = neighborRoadCount + ( getRoad( x + 1, y ) and 1 or 0 )
			neighborRoadCount = neighborRoadCount + ( getRoad( x, y + 1 ) and 1 or 0 )
			neighborRoadCount = neighborRoadCount + ( getRoad( x - 1, y ) and 1 or 0 )
			neighborRoadCount = neighborRoadCount + ( getRoad( x, y - 1 ) and 1 or 0 )
			
			local maxDiff = neighborRoadCount < 3 and 1 or 0
			
			if lower then
				local m = math.min( math.min( c00, c10 ), math.min( c11, c01 ) ) + maxDiff
				
				if c00 > m then
					if not g_cornerTemp.forceFlat[y][x] then
						g_cellData.cliffLevel[y][x] = m
						corrections = corrections + 1
					else
						violations = violations + 1
					end
				end
				if c10 > m then
					if not g_cornerTemp.forceFlat[y][x + 1] then
						g_cellData.cliffLevel[y][x + 1] = m
						corrections = corrections + 1
					else
						violations = violations + 1
					end
				end
				if c11 > m then
					if not g_cornerTemp.forceFlat[y + 1][x + 1] then
						g_cellData.cliffLevel[y + 1][x + 1] = m
						corrections = corrections + 1
					else
						violations = violations + 1
					end
				end
				if c01 > m then
					if not g_cornerTemp.forceFlat[y + 1][x] then
						g_cellData.cliffLevel[y + 1][x] = m
						corrections = corrections + 1
					else
						violations = violations + 1
					end
				end
			else
				local m = math.max( math.max( c00, c10 ), math.max( c11, c01 ) ) - maxDiff
				
				if c00 < m then
					if not g_cornerTemp.forceFlat[y][x] then
						g_cellData.cliffLevel[y][x] = m
						corrections = corrections + 1
					else
						violations = violations + 1
					end
				end
				if c10 < m then
					if not g_cornerTemp.forceFlat[y][x + 1] then
						g_cellData.cliffLevel[y][x + 1] = m
						corrections = corrections + 1
					else
						violations = violations + 1
					end
				end
				if c11 < m then
					if not g_cornerTemp.forceFlat[y + 1][x + 1] then
						g_cellData.cliffLevel[y + 1][x + 1] = m
						corrections = corrections + 1
					else
						violations = violations + 1
					end
				end
				if c01 < m then
					if not g_cornerTemp.forceFlat[y + 1][x] then
						g_cellData.cliffLevel[y + 1][x] = m
						corrections = corrections + 1
					else
						violations = violations + 1
					end
				end
			end
		end
		if violations > 0 then
			--print( "Violation at cell: ("..x..","..y..")".." - /tp",x*8,y*8,64)
		end
		return corrections, violations
	end
	
	local pass = 1
	local hasViolations = true
	while pass <= 5 and hasViolations do
		hasViolations = false
		print( "Cliff road limitaion pass", pass )
		local corrections, violations
		local lower = pass % 2 == 1

		--Sweep from SW to NE
		corrections = 0
		violations = 0
		for y = g_cellData.bounds.yMin, g_cellData.bounds.yMax do
			for x = g_cellData.bounds.xMin, g_cellData.bounds.xMax do
				local c, v = maxCliffClamp( x, y, lower )
				corrections = corrections + c
				violations = violations + v
				hasViolations = hasViolations or v > 0
			end
		end
		print( "Cliff SW to NE:", corrections, "corrections,", violations, "violations" )
		
		--Sweep from NE to SW
		corrections = 0
		violations = 0
		for y = g_cellData.bounds.yMax, g_cellData.bounds.yMin, -1 do
			for x = g_cellData.bounds.xMax, g_cellData.bounds.xMin, -1 do
				local c, v = maxCliffClamp( x, y, lower )
				corrections = corrections + c
				violations = violations + v
				hasViolations = hasViolations or v > 0
			end
		end
		print( "Cliff NE to SW:", corrections, "corrections,", violations, "violations" )
		
		--Sweep from SW to NE
		corrections = 0
		violations = 0
		for y = g_cellData.bounds.yMin, g_cellData.bounds.yMax do
			for x = g_cellData.bounds.xMin, g_cellData.bounds.xMax do
				local c, v = roadCliffClamp( x, y, lower )
				corrections = corrections + c
				violations = violations + v
				hasViolations = hasViolations or v > 0
			end
		end
		print( "Road SW to NE:", corrections, "corrections,", violations, "violations" )
		
		--Sweep from NE to SW
		corrections = 0
		violations = 0
		for y = g_cellData.bounds.yMax, g_cellData.bounds.yMin, -1 do
			for x = g_cellData.bounds.xMax, g_cellData.bounds.xMin, -1 do
				local c, v = roadCliffClamp( x, y, lower )
				corrections = corrections + c
				violations = violations + v
				hasViolations = hasViolations or v > 0
			end
		end
		print( "Road NE to SW:", corrections, "corrections,", violations, "violations" )
		pass = pass + 1
	end
end

----------------------------------------------------------------------------------------------------

function cliffString( bits )
	local se = bit.band( bit.rshift( bits, 6 ), 0x3 )
	local sw = bit.band( bit.rshift( bits, 4 ), 0x3 )
	local nw = bit.band( bit.rshift( bits, 2 ), 0x3 )
	local ne = bit.band( bits, 0x3 )
	return se..sw..nw..ne
end

----------------------------------------------------------------------------------------------------

function evaluateRoadsAndCliffs()
	-- Calculate flags
	for cellY = g_cellData.bounds.yMin, g_cellData.bounds.yMax do
		for cellX = g_cellData.bounds.xMin, g_cellData.bounds.xMax do
			local cliffLevelSE = getCornerCliffLevel( cellX + 1, cellY )
			local cliffLevelSW = getCornerCliffLevel( cellX, cellY )
			local cliffLevelNW = getCornerCliffLevel( cellX, cellY + 1 )
			local cliffLevelNE = getCornerCliffLevel( cellX + 1, cellY + 1 )
			local cliffBits = calculateCliffBits( cliffLevelSE, cliffLevelSW, cliffLevelNW, cliffLevelNE )
			
			local roadBits = bit.tobit( 0 )
			if( getRoad( cellX, cellY ) ) then
				local roadE = getRoad( cellX + 1, cellY )
				local roadN = getRoad( cellX, cellY + 1 )
				local roadW = getRoad( cellX - 1, cellY )
				local roadS = getRoad( cellX, cellY - 1 )
				roadBits = calculateRoadBits( roadS, roadW, roadN, roadE )
			end
			
			g_cellData.flags[cellY][cellX] = bit.bor( g_cellData.flags[cellY][cellX], bit.bor( roadBits, cliffBits ) )
		end
	end

	-- Statistics init
	local totalCliffTilesUsed = 0
	local cliffUsage = {}
	for i = 0, 255 do
		cliffUsage[i] = -1
	end
	for i = 0, 255 do
		local tileId1, rotation1 = getCliffRoadTileIdAndRotation( i, 0 )
		if not tileId1:isNil() then
			local bits = bit.bor( i, bit.lshift( i, 8 ) )
			bits = bit.rshift( bits, 2 * rotation1 )
			bits = bit.band( bits, 0xff )
			cliffUsage[bits] = 0
		end
	end
	
	for cellY = g_cellData.bounds.yMin, g_cellData.bounds.yMax do
		for cellX = g_cellData.bounds.xMin, g_cellData.bounds.xMax do
			-- Evaluate flags
			local flags = getRoadCliffFlags( cellX, cellY )
			local tileId, rotation = getCliffRoadTileIdAndRotation( flags, sm.noise.intNoise2d( cellX, cellY, g_cellData.seed + 2854 ) )
			if not tileId:isNil() and g_cellData.uid[cellY][cellX]:isNil() then
				g_cellData.uid[cellY][cellX] = tileId
				g_cellData.rotation[cellY][cellX] = rotation
				g_cellData.xOffset[cellY][cellX] = 0
				g_cellData.yOffset[cellY][cellX] = 0
			end
			
			-- Cliff usage statistics calculation
			local cliffIndex = bit.band( flags, 0xff )
			local tileId1, rotation1 = getCliffRoadTileIdAndRotation( cliffIndex, 0 )
			if not tileId1:isNil() then
				local bits = bit.bor( cliffIndex, bit.lshift( cliffIndex, 8 ) )
				bits = bit.rshift( bits, 2 * rotation1 )
				bits = bit.band( bits, 0xff )
				
				cliffIndex = bits;
				
				cliffUsage[cliffIndex] = cliffUsage[cliffIndex] + 1
				totalCliffTilesUsed = totalCliffTilesUsed + 1
			end
		end
	end
	
	-- Cliffs and roads as TYPE_MEADOW
	forEveryCell( function( cellX, cellY )
		if getRoadCliffFlags( cellX, cellY ) ~= 0 then
			g_cornerTemp.type[cellY][cellX] = TYPE_MEADOW
			g_cornerTemp.type[cellY][cellX + 1] = TYPE_MEADOW
			g_cornerTemp.type[cellY + 1][cellX] = TYPE_MEADOW
			g_cornerTemp.type[cellY + 1][cellX + 1] = TYPE_MEADOW
		end
	end )

	for i = 0, 255 do
		if cliffUsage[i] > 0 then
			local percentage = math.floor( 100000 * cliffUsage[i] / totalCliffTilesUsed ) / 1000
			local spaces = ""
			local n = 10000
			while n > cliffUsage[i] do
				spaces = spaces.." "
				n = n / 10
			end
			print( "Cliff("..cliffString( i ).."): "..spaces..cliffUsage[i].. " ("..percentage.."%)" )
		elseif cliffUsage[i] == 0 then
			print( "Cliff("..cliffString( i ).."):	 0 (0.00%)" )
		end
	end
	print( "Cliff tiles used: "..totalCliffTilesUsed )

end

----------------------------------------------------------------------------------------------------

function evaluateType( type, fn )
	forEveryCell( function( x, y )
		local typeSE = bit.tobit( g_cornerTemp.type[y][x + 1] == type and 8 or 0 )
		local typeSW = bit.tobit( g_cornerTemp.type[y][x] == type and 4 or 0 )
		local typeNW = bit.tobit( g_cornerTemp.type[y + 1][x] == type and 2 or 0 )
		local typeNE = bit.tobit( g_cornerTemp.type[y + 1][x + 1] == type and 1 or 0 )
		local typeBits = bit.bor( typeSE, typeSW, typeNW, typeNE )
		local tileId, rotation = fn( typeBits, sm.noise.intNoise2d( x, y, g_cellData.seed + 2854 ), sm.noise.intNoise2d( x, y, g_cellData.seed + 9439 ) )
		if not tileId:isNil() and g_cellData.uid[y][x]:isNil() then
			g_cellData.uid[y][x] = tileId
			g_cellData.rotation[y][x] = rotation
			g_cellData.xOffset[y][x] = 0
			g_cellData.yOffset[y][x] = 0
			g_cellData.flags[y][x] = bit.bor( g_cellData.flags[y][x], bit.band( bit.lshift( type, SHIFT_TERRAINTYPE ), MASK_TERRAINTYPE ) )
		end
	end )
end

----------------------------------------------------------------------------------------------------
