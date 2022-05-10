dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/processing.lua" )

----------------------------------------------------------------------------------------------------

function generateOverworldCelldata( xMin, xMax, yMin, yMax, seed, data, padding )

	math.randomseed( seed )

	print( "Initializing cell data" )
	initializeCellData( xMin, xMax, yMin, yMax, seed ) --Zero everything

	-- Temp corner data during generate
	g_cornerTemp = {
		type = {},
		gradC = {},
		gradN = {},
		forceFlat = {},
		poiDst = {},
		lakeAdjacent = {},
		hillyness = {},
		island = {}
	}
	for y = yMin, yMax + 1 do
		g_cornerTemp.type[y] = {}
		g_cornerTemp.gradC[y] = {}
		g_cornerTemp.gradN[y] = {}
		g_cornerTemp.forceFlat[y] = {}
		g_cornerTemp.poiDst[y] = {}
		g_cornerTemp.lakeAdjacent[y] = {}
		g_cornerTemp.hillyness[y] = {}
		g_cornerTemp.island[y] = {}

		for x = xMin, xMax + 1 do
			g_cornerTemp.type[y][x] = TYPE_LAKE
			g_cornerTemp.gradC[y][x] = 0
			g_cornerTemp.gradN[y][x] = 0
			g_cornerTemp.forceFlat[y][x] = false
			g_cornerTemp.poiDst[y][x] = 0
			g_cornerTemp.lakeAdjacent[y][x] = true
			g_cornerTemp.hillyness[y][x] = 1
			g_cornerTemp.island[y][x] = 0
		end
	end

	-- Temp cell data during generate
	g_cellTemp = {
		road = {}
	}
	for cellY = yMin, yMax do
		g_cellTemp.road[cellY] = {}

		for cellX = xMin, xMax do
			g_cellTemp.road[cellY][cellX] = false
		end
	end

	padding = padding + 8
	local xSize = xMax + 1 - xMin
	local ySize = yMax + 1 - yMin
	local xHalfSize = xSize / 2
	local yHalfSize = ySize / 2
	local xCenter = xMin + xHalfSize
	local yCenter = yMin + yHalfSize
	print( "Size", xSize, ySize )
	print( "Center", xCenter, yCenter )

	local pois = {}

	------------------------------------------------------------------------------------------------

	-- Terrain types from noise
	for y = yMin + 1, yMax - 1 do
		for x = xMin + 1, xMax - 1 do
			local gradC = 1 - math.min( math.max( math.abs( x - xCenter ) / ( xHalfSize - padding ), math.abs( y - yCenter ) / ( yHalfSize - padding ) ), 1 )
			assert( gradC >= 0 and gradC <= 1 )
			local gradN = sm.util.clamp( ( y - yMin - padding ) / ( ySize - 2 * padding ), 0, 1 )
			assert( gradN >= 0 and gradN <= 1 )
			g_cornerTemp.gradC[y][x] = gradC
			g_cornerTemp.gradN[y][x] = gradN

			local island = sm.util.clamp( sm.noise.perlinNoise2d( x / 6, y / 6, seed + 6437 ) * 2 + 0.5, 0, 1 ) + sm.util.clamp( gradC * 2 - 1, -1, 1 )
			g_cornerTemp.island[y][x] = island

			if island > 0 then -- Land
				g_cornerTemp.type[y][x] = TYPE_MEADOW
			end
		end
	end

	------------------------------------------------------------------------------------------------

	-- Crash site
	pois[#pois + 1] = { x = -36, y = -40, type = POI_CRASHSITE_AREA, size = 20, road = false, flat = false, cliffLevel = 0, cellDebug = nil, edges = {} }
	local crashSite = pois[#pois]
	pois[#pois + 1] = { x = -35, y = -30, type = POI_ROAD, rotation = 1, size = 1, road = false, flat = false, terrainType = TYPE_FOREST, cliffLevel = 0, cellDebug = nil, edges = {} }
	local crashSiteExit = pois[#pois]

	-- Unique
	pois[#pois + 1] = { x = -27, y = -26, type = POI_MECHANICSTATION_MEDIUM, size = 2, road = false, flat = true, terrainType = TYPE_FOREST, cellDebug = nil, edges = {} }
	local mechanicStation = pois[#pois]
	pois[#pois + 1] = { x = -17, y = -23, type = POI_PACKINGSTATIONVEG_MEDIUM, size = 2, road = false, flat = true, cellDebug = nil, edges = {} }
	local packingStation1 = pois[#pois]
	pois[#pois + 1] = { x = 0, y = -21, type = POI_PACKINGSTATIONFRUIT_MEDIUM, size = 2, road = false, flat = true, cellDebug = nil, edges = {} }
	local packingStation2 = pois[#pois]
	pois[#pois + 1] = { x = -16, y = -16, type = POI_HIDEOUT_XL, rotation = 0, size = 8, road = false, flat = true, cliffLevel = 0, cellDebug = nil, edges = {} }
	local hideout = pois[#pois]

	pois[#pois + 1] = { x = 24, y = 32, type = POI_RUINCITY_XL, size = 8, road = true, flat = true, cellDebug = nil, edges = {} }
	pois[#pois + 1] = { x = 40, y = 0, type = POI_SILODISTRICT_XL, rotation = 1, size = 8, road = true, flat = true, cellDebug = nil, edges = {} }

	pois[#pois + 1] = { x = -48, y = 40, type = POI_CRASHEDSHIP_LARGE, size = 4, road = false, flat = true, cellDebug = nil, edges = {} }
	pois[#pois + 1] = { x = -56, y = 0, type = POI_CAMP_LARGE, rotation = 0, size = 4, road = true, flat = true, cellDebug = nil, edges = {} }

	pois[#pois + 1] = { x = 24, y = 0, type = POI_CAPSULESCRAPYARD_MEDIUM, size = 2, road = false, flat = true, cellDebug = nil, terrainType = TYPE_MEADOW, edges = {} }
	pois[#pois + 1] = { x = 24, y = -20, type = POI_LABYRINTH_MEDIUM, size = 2, road = false, flat = true, cellDebug = nil, terrainType = TYPE_FIELD, edges = {} }

	pois[#pois + 1] = { x = 0, y = 10, type = POI_MECHANICSTATION_MEDIUM, size = 2, road = true, flat = true, cellDebug = nil, edges = {} }
	pois[#pois + 1] = { x = -12, y = 20, type = POI_PACKINGSTATIONVEG_MEDIUM, size = 2, road = true, flat = true, cellDebug = nil, edges = {} }
	pois[#pois + 1] = { x = 12, y = 20, type = POI_PACKINGSTATIONFRUIT_MEDIUM, size = 2, road = true, flat = true, cellDebug = nil, edges = {} }

	------------------------------------------------------------------------------------------------













































































	for _,poi in ipairs( pois ) do
		assert( poi.x + math.floor( poi.size / 2 ) > xMin, "out of bounds"..poi.type.." x="..poi.x.."y="..poi.y )
		assert( poi.x - math.floor( poi.size / 2 ) < xMax, "out of bounds"..poi.type.." x="..poi.x.."y="..poi.y )
		assert( poi.y + math.floor( poi.size / 2 ) > yMin, "out of bounds"..poi.type.." x="..poi.x.."y="..poi.y )
		assert( poi.y - math.floor( poi.size / 2 ) < yMax, "out of bounds"..poi.type.." x="..poi.x.."y="..poi.y )
	end

	------------------------------------------------------------------------------------------------

	-- Large Random
	local largePoiSpots = {}
	for i = 1,4 do
		for j = 1,4 do
			if not ( i == 1 and j == 2 ) then
				largePoiSpots[#largePoiSpots + 1] = {
					x = j * 24 - 60,
					y = i * 20 - 50
				}
				--print( largePoiSpots[#largePoiSpots].x, largePoiSpots[#largePoiSpots].y )
			end
		end
	end
	print( "Large poi spots:", #largePoiSpots )

	--shuffle( largePoiSpots, 3, #largePoiSpots ) -- Keep the 2 first in order
	shuffle( largePoiSpots )
	local count = 0
	for _,spot in ipairs( largePoiSpots ) do
		local type, debug
		if count < 3 then
			type, debug = POI_WAREHOUSE2_LARGE, DEBUG_PINK
		elseif count < 6 then
			type, debug = POI_WAREHOUSE3_LARGE, DEBUG_B
		elseif count < 9 then
			type, debug = POI_WAREHOUSE4_LARGE, DEBUG_PURPLE
		elseif count < 12 then
			type, debug = POI_BURNTFOREST_FARMBOTSCRAPYARD_LARGE, DEBUG_G
		else
			break
		end

		local poi = {
			x = spot.x,-- + sm.noise.intNoise2d( spot.x, spot.y, seed + 3831 ) % 9 - 4,
			y = spot.y,-- + sm.noise.intNoise2d( spot.x, spot.y, seed + 4041 ) % 9 - 4,
			type = type,
			size = 4,
			road = type ~= POI_BURNTFOREST_FARMBOTSCRAPYARD_LARGE,
			flat = true,
			terrainType = type == POI_BURNTFOREST_FARMBOTSCRAPYARD_LARGE and TYPE_BURNTFOREST or nil,
			cellDebug = debug,
			edges = {}
		}
		if not collides( poi.x, poi.y, poi.size, pois ) then
			pois[#pois + 1] = poi
			count = count + 1
		end
	end
	print( "Large pois:", count )


	-- Connect a road to all unique and large pois tagged with road
	local roadDestinations = {}
	for _,poi in ipairs( pois ) do
		if poi.road then
			roadDestinations[#roadDestinations + 1] = poi
		end
	end

	-- Keept away from roadDestinations but allow roads
	crashSiteExit.road = true
	mechanicStation.road = true
	packingStation1.road = true
	packingStation2.road = true

	------------------------------------------------------------------------------------------------

	--[[
	local surround = function( points, size, fn )
		local _seed = sm.noise.intNoise2d( points[1].x, points[1].y, seed + 5993 )
		for y = yMin + padding, yMax - padding do
			for x = xMin + padding, xMax - padding do
				local dd = math.huge
				local index
				for i,pt in ipairs( points ) do
					local _dd = dist2( x, y, pt.x, pt.y )
					if _dd < dd then
						dd = _dd
						index = i
					end
				end

				local grad = math.max( 1 - math.sqrt( dd ) / size, 0.0 )
				local noise = sm.noise.perlinNoise2d( x / 6, y / 6, _seed )

				if sm.util.clamp( noise * 2 + 0.5, 0, 1 ) + sm.util.clamp( grad * 2 - 1, -1, 1 ) > 0 then
					fn( x, y, index )
				end
			end
		end
	end

	-- Add burnt forest around scrapyards
	local scrapyards = {}
	for _,poi in ipairs( pois ) do
		if poi.type == POI_BURNTFOREST_FARMBOTSCRAPYARD_LARGE then
			scrapyards[#scrapyards + 1] = { x = poi.x, y = poi.y }
		end
	end
	surround( scrapyards, 7, function( x, y )
		if g_cornerTemp.type[y][x] == TYPE_MEADOW then
			g_cornerTemp.type[y][x] = TYPE_BURNTFOREST
		end
	end )

	-- Add bunk burial lake and island
	surround( { [1] = { x = 24,  y = 0 } }, 10, function( x, y )
		if g_cornerTemp.type[y][x] == TYPE_MEADOW then
			g_cornerTemp.type[y][x] = TYPE_LAKE
		end
	end )
	surround( { [1] = { x = 24,  y = 0 } }, 4, function( x, y )
		if g_cornerTemp.type[y][x] == TYPE_LAKE then
			g_cornerTemp.type[y][x] = TYPE_MEADOW
		end
	end )


	-- Add labyrinth field
	surround( { [1] = { x = 50, y = -50 } }, 5, function( x, y )
		g_cornerTemp.type[y][x] = TYPE_FIELD
	end )
	]]

	------------------------------------------------------------------------------------------------

	local RandomTypes = {
		TYPE_MEADOW,
		TYPE_FOREST, TYPE_FOREST,
		TYPE_DESERT,
		TYPE_FIELD,
		TYPE_BURNTFOREST,
		TYPE_AUTUMNFOREST,
		TYPE_LAKE, TYPE_LAKE
	}

	-- Medium poi spots
	local poiSpots = {}
	for i = 1,19 do
		for j = 1,25 do
			local noise = sm.noise.intNoise2d( j, i, seed + 557 ) % 4
			poiSpots[#poiSpots + 1] = {
				x = j * 5 - 63 + noise % 2,
				y = i * 5 - 50 + ( j % 2 ) * 2 + math.floor( noise / 2 )
			}
		end
	end
	print( "Small/medium poi spots:", #poiSpots )

	local mustHavePois = {
		{ type = POI_CHEMLAKE_MEDIUM, size = 2, road = false },
		{ type = POI_CHEMLAKE_MEDIUM, size = 2, road = false },
		{ type = POI_CHEMLAKE_MEDIUM, size = 2, road = false },
		{ type = POI_CHEMLAKE_MEDIUM, size = 2, road = false },
		{ type = POI_CHEMLAKE_MEDIUM, size = 2, road = false },
	}
	local count = 0
	local mustHaveCount = 0
	shuffle( poiSpots )
	for _,spot in ipairs( poiSpots ) do
		local terrainType = g_cornerTemp.type[spot.y][spot.x]
		local poi = {
			x = spot.x,
			y = spot.y,
			flat = true,
			terrainType = terrainType,
			edges = {}
		}

		if mustHaveCount < #mustHavePois and g_cornerTemp.gradC[spot.y][spot.x] > 0.15 then -- Add some must haves
			local mustHave = mustHavePois[mustHaveCount + 1]
			poi.type = mustHave.type
			poi.size = mustHave.size
			poi.road = mustHave.road
			poi.terrainType = math.floor( mustHave.type / 100 )
			if not collides( poi.x, poi.y, poi.size + 2, pois ) then
				pois[#pois + 1] = poi
				count = count + 1
				mustHaveCount = mustHaveCount + 1
			end
		else
			poi.type = POI_RANDOM_PLACEHOLDER
			poi.size = 2
			poi.road = terrainType ~= TYPE_LAKE
			if poi.terrainType == TYPE_MEADOW then
				poi.terrainType = RandomTypes[math.random( #RandomTypes )]
			end
			if not collides( poi.x, poi.y, poi.size + 2, pois ) then
				pois[#pois + 1] = poi
				count = count + 1
			end
		end
	end
	print( "Small/medium pois:", count )

	for _,poi in ipairs( pois ) do
		assert( poi.x + math.floor( poi.size / 2 ) > xMin, "out of bounds"..poi.type.." x="..poi.x.."y="..poi.y )
		assert( poi.x - math.floor( poi.size / 2 ) < xMax, "out of bounds"..poi.type.." x="..poi.x.."y="..poi.y )
		assert( poi.y + math.floor( poi.size / 2 ) > yMin, "out of bounds"..poi.type.." x="..poi.x.."y="..poi.y )
		assert( poi.y - math.floor( poi.size / 2 ) < yMax, "out of bounds"..poi.type.." x="..poi.x.."y="..poi.y )
	end

	------------------------------------------------------------------------------------------------

	-- Get terrain type from closest poi
	forEveryCorner( function( x, y )
		if g_cornerTemp.type[y][x] == TYPE_MEADOW then
			local dst, poi = closestPoi( pois, x, y )
			local type = poi.terrainType or TYPE_MEADOW
			assert( type )
			g_cornerTemp.type[y][x] = type
		end
	end )

	------------------------------------------------------------------------------------------------

	local poiRandomCliff = function( x, y )
		if g_cornerTemp.type[y][x] ~= TYPE_LAKE then
			local grad = g_cornerTemp.gradC[y][x]
			local noise = sm.noise.perlinNoise2d( x / 6, y / 6, seed + 8397 )
			local val = sm.util.clamp( noise * 2 + 0.5, 0, 1 ) + sm.util.clamp( grad * 2.5 - 2.0, -1, 1 )
			if val > 0.85 then
				return 4
			elseif val > 0.5 then
				return 3
			elseif val > 0.25 then
				return 2
			elseif val > 0 then
				return 1
			end
		end
		return 0
	end
	--local poiRandomCliff = function( x, y ) return 0 end --HACK: No cliffs

	local poisWithCliffLevel = {}
	for _,poi in ipairs( pois ) do
		if poi.cliffLevel then
			poisWithCliffLevel[#poisWithCliffLevel + 1] = poi
		end
	end

	-- Set poi cliff height
	for i,poi in ipairs( pois ) do
		if not poi.cliffLevel then
			if i < 100 then
				poi.cliffLevel = poiRandomCliff( poi.x, poi.y ) -- Some random cliff levels
			else
				local closestDst, closestPoi = closestPoi( poisWithCliffLevel, poi.x, poi.y ) -- Copy closest cliff level
				poi.cliffLevel = closestPoi.cliffLevel
			end
			poisWithCliffLevel[#poisWithCliffLevel + 1] = poi
		end
	end

	-- Set 0 cliff level to closest poi for every point along border
	-- West and east
	for y = yMin + padding, yMax + 1 - padding do
		for _,x in ipairs( { xMin + padding, xMax + 1 - padding } ) do
			local closestDst, closestPoi = closestPoi( pois, x, y )
			closestPoi.cliffLevel = 0
		end
	end
	-- South and north
	for _,y in ipairs( { yMin + padding, yMax + 1 - padding } ) do
		for x = xMin + padding, xMax + 1 - padding do
			local closestDst, closestPoi = closestPoi( pois, x, y )
			closestPoi.cliffLevel = 0
		end
	end

	------------------------------------------------------------------------------------------------

	-- Compute graph of possible roads
	local roadPois = {}

	for _,poi in ipairs( pois ) do
		if poi.road then
			roadPois[#roadPois + 1] = poi
		end
	end

	local DistanceCostMultipliers = {
		[TYPE_MEADOW] = 1,
		[TYPE_FOREST] = 2,
		[TYPE_FIELD] = 2,
		[TYPE_BURNTFOREST] = 10,
		[TYPE_AUTUMNFOREST] = 5,
		[TYPE_LAKE] = 5,
		[TYPE_DESERT] = 2,
	}

	for i = 1, #roadPois - 1 do
		for j = i + 1, #roadPois do
			if isNeighbor( roadPois, i, j ) then
				local a = roadPois[i]
				local b = roadPois[j]

				--local distance = math.sqrt( ( a.x - b.x )^2 + ( a.y - b.y )^2 )
				local distance = math.abs( a.x - b.x ) + math.abs( a.y - b.y ) -- Manhattan distance
				local cliffDiff = math.abs( a.cliffLevel - b.cliffLevel )
				local distanceMultiplier = math.max( DistanceCostMultipliers[g_cornerTemp.type[a.y][a.x]], DistanceCostMultipliers[g_cornerTemp.type[b.y][b.x]] )

				local cost = distance * distanceMultiplier + cliffDiff * 5

				cost = cost + 10 -- Additional unroaded cost

				a.edges[#a.edges + 1] = { neighbor = b, cost = cost }
				b.edges[#b.edges + 1] = { neighbor = a, cost = cost }
			end
		end
	end


	-- Create some roads with a start and a finish
	shuffle( roadDestinations )

	local searches = {}
	searches[#searches + 1] = { crashSiteExit, mechanicStation }
	searches[#searches + 1] = { mechanicStation, packingStation1 }
	searches[#searches + 1] = { packingStation1, packingStation2 }

	local from = packingStation2
	for _,to in ipairs( roadDestinations ) do
		if from then
			searches[#searches + 1] = { from, to }
		end
		from = to
	end

	local edges = {}
	for _,search in ipairs( searches ) do
		for _,poi in ipairs( pois ) do
			poi.totalCost = math.huge -- Init to huge cost
		end

		local start = search[1]
		local destination = search[2]
		destination.totalCost = 0 -- Destination has 0 cost

		local queue = { [1] = destination }-- Start from destination

		-- Calculate the smallest total cost to destination from all nodes
		while #queue > 0 do
			local node = queue[#queue]
			queue[#queue] = nil
			for _,edge in ipairs( node.edges ) do
				local totalCost = node.totalCost + edge.cost
				if totalCost < edge.neighbor.totalCost then
					edge.neighbor.totalCost = totalCost
					queue[#queue + 1] = edge.neighbor
				end
			end
		end

		-- Traverse down the total costs
		local node = start
		while node ~= destination do
			local bestEdge
			local index

			for i,edge in ipairs( node.edges ) do
				if bestEdge == nil or edge.neighbor.totalCost < bestEdge.neighbor.totalCost then
					bestEdge = edge
					index = i
				end
			end

			if bestEdge == nil then
				sm.log.error( "No path found!" )
				break
			end

			local a = node
			local b = bestEdge.neighbor
			edges[#edges + 1] = { a = a,  b = b }

			-- Reduce edge cost of beaten paths
			local distance = math.abs( a.x - b.x ) + math.abs( a.y - b.y ) -- Manhattan distance
			distance = distance + math.abs( a.cliffLevel - b.cliffLevel ) * 5

			bestEdge.cost = distance
			for _,edge in ipairs( b.edges ) do
				if edge.neighbor == a then
					edge.cost = distance
				end
			end

			node = b
		end
	end

	------------------------------------------------------------------------------------------------

	--Add the roads and convert placeholder pois
	local convertToRoadPoi = function( poi, other )
		local dx = poi.x - other.x
		local dy = poi.y - other.y

		-- Rotation based on road direction

		if poi.type == POI_RANDOM_PLACEHOLDER then
			poi.type = POI_ROAD
			local rot = math.abs( dy ) > math.abs( dx ) and 1 or 0
			poi.rotation = rot + ( sm.noise.intNoise2d( poi.x, poi.y, g_cellData.seed + 211 ) % 2 ) * 2
			poi.size = 1
			poi.flat = false
			poi.cellDebug = nil
		end

		if poi.rotation == nil and ( poi.type == POI_MECHANICSTATION_MEDIUM or poi.type == POI_PACKINGSTATIONVEG_MEDIUM or poi.type == POI_PACKINGSTATIONFRUIT_MEDIUM ) then
			if math.abs( dy ) > math.abs( dx ) then
				poi.rotation = dx > 0 and 3 or 1
			else
				poi.rotation = dy > 0 and 0 or 2
			end
		end

		if poi.rotation == nil and ( poi.type == POI_WAREHOUSE2_LARGE or poi.type == POI_WAREHOUSE3_LARGE or poi.type == POI_WAREHOUSE4_LARGE ) then
			local rot = math.abs( dy ) > math.abs( dx ) and 0 or 1
			poi.rotation = rot + ( sm.noise.intNoise2d( poi.x, poi.y, g_cellData.seed + 211 ) % 2 ) * 2
		end

		-- Road connections

		if poi.type == POI_ROAD then
			g_cellTemp.road[poi.y][poi.x] = true
			if poi.rotation % 2 == 0 then -- W -> E
				g_cellTemp.road[poi.y][poi.x - 1] = true
				g_cellTemp.road[poi.y][poi.x + 1] = true
				if dx > 0 then
					return -1, 0
				else
					return 1, 0
				end
			else -- S -> N
				g_cellTemp.road[poi.y - 1][poi.x] = true
				g_cellTemp.road[poi.y + 1][poi.x] = true
				if dy > 0 then
					return 0, -1
				else
					return 0, 1
				end
			end
		end

		if poi.type == POI_MECHANICSTATION_MEDIUM or poi.type == POI_PACKINGSTATIONVEG_MEDIUM or poi.type == POI_PACKINGSTATIONFRUIT_MEDIUM then
			if poi.rotation == 0 then
				g_cellTemp.road[poi.y - 1][poi.x] = true
				g_cellTemp.road[poi.y - 1][poi.x + 1] = true
				g_cellTemp.road[poi.y - 1][poi.x - 1] = true
				g_cellTemp.road[poi.y - 1][poi.x - 2] = true
				if dx > 0 then
					return -3, -1
				else
					return 2, -1
				end
			elseif poi.rotation == 1 then
				g_cellTemp.road[poi.y][poi.x] = true
				g_cellTemp.road[poi.y + 1][poi.x] = true
				g_cellTemp.road[poi.y - 1][poi.x] = true
				g_cellTemp.road[poi.y - 2][poi.x] = true
				if dy > 0 then
					return 0, -3
				else
					return 0, 2
				end
			elseif poi.rotation == 2 then
				g_cellTemp.road[poi.y][poi.x] = true
				g_cellTemp.road[poi.y][poi.x + 1] = true
				g_cellTemp.road[poi.y][poi.x - 1] = true
				g_cellTemp.road[poi.y][poi.x - 2] = true
				if dx > 0 then
					return -3, 0
				else
					return 2, 0
				end
			else
				g_cellTemp.road[poi.y][poi.x -1] = true
				g_cellTemp.road[poi.y + 1][poi.x -1] = true
				g_cellTemp.road[poi.y - 1][poi.x -1] = true
				g_cellTemp.road[poi.y - 2][poi.x -1] = true
				if dy > 0 then
					return -1, -3
				else
					return -1, 2
				end
			end
		end

		if poi.type == POI_WAREHOUSE2_LARGE or poi.type == POI_WAREHOUSE3_LARGE or poi.type == POI_WAREHOUSE4_LARGE then
			if poi.rotation % 2 == 0 then
				g_cellTemp.road[poi.y + 1][poi.x] = true
				g_cellTemp.road[poi.y + 2][poi.x] = true
				g_cellTemp.road[poi.y - 2][poi.x - 1] = true
				g_cellTemp.road[poi.y - 3][poi.x - 1] = true
			else
				g_cellTemp.road[poi.y - 1][poi.x + 1] = true
				g_cellTemp.road[poi.y - 1][poi.x + 2] = true
				g_cellTemp.road[poi.y][poi.x - 2] = true
				g_cellTemp.road[poi.y][poi.x - 3] = true
			end
			if poi.rotation % 2 == 0 then -- SSW -> NNE
				if dy > 0 then
					return -1, -4
				else
					return 0, 3
				end
			else -- WSW -> ENE
				if dx > 0 then
					return -4, 0
				else
					return 3, -1
				end
			end
		end

		if poi.type == POI_RUINCITY_XL or poi.type == POI_SILODISTRICT_XL then
			-- E
			g_cellTemp.road[poi.y - 1][poi.x + 3] = true
			g_cellTemp.road[poi.y - 1][poi.x + 4] = true
			-- N
			g_cellTemp.road[poi.y + 3][poi.x] = true
			g_cellTemp.road[poi.y + 4][poi.x] = true
			-- W
			g_cellTemp.road[poi.y][poi.x - 4] = true
			g_cellTemp.road[poi.y][poi.x - 5] = true
			-- S
			g_cellTemp.road[poi.y - 4][poi.x - 1] = true
			g_cellTemp.road[poi.y - 5][poi.x - 1] = true

			if dx > 0 and dx > math.abs( dy ) then 		-- From W
				return -5, 0
			elseif dx < 0 and dx < -math.abs( dy ) then	-- From E
				return 4, -1
			elseif dy > 0 then							-- From S
				return -1, -5
			else										-- From N
				return 0, 4
			end
		end

		if poi.type == POI_CAMP_LARGE then
			g_cellTemp.road[poi.y + 1][poi.x + 1] = true
			g_cellTemp.road[poi.y + 1][poi.x + 2] = true
			g_cellTemp.road[poi.y + 2][poi.x + 1] = true
			return 2, 1
		end

		return 0, 0
	end

	for _,edge in ipairs( edges ) do
		local aox, aoy = convertToRoadPoi( edge.a, edge.b )
		local box, boy = convertToRoadPoi( edge.b, edge.a )

		local roadCells = {}
		if edge.a.x + aox < edge.b.x + box then
			drawLine( roadCells, edge.a.x + aox, edge.a.y + aoy, edge.b.x + box, edge.b.y + boy )
		else
			drawLine( roadCells, edge.b.x + box, edge.b.y + boy, edge.a.x + aox, edge.a.y + aoy )
		end

		for _,road in ipairs( roadCells ) do
			if insideCellBounds( road.x, road.y ) then
				g_cellTemp.road[road.y][road.x] = true
				--g_cellData.cellDebug[road.y][road.x] = DEBUG_BLACK
			end
		end
	end

	print( hideout.y, ",", hideout.y)

	-- Clear hideout of roads
	for y0 = -4, 3 do
		for x0 = -4, 3 do
			local x = hideout.x + x0
			local y = hideout.y + y0
			g_cellTemp.road[y][x] = false
		end
	end

	------------------------------------------------------------------------------------------------


	-- Process placeholder pois not converted to road pois

	local function allOfTypeNoRoad( poi, type )
		local halfSize = math.floor( poi.size / 2 )
		for y0 = 0, poi.size do
			for x0 = 0, poi.size do
				local x = poi.x + x0 - halfSize
				local y = poi.y + y0 - halfSize
				if g_cornerTemp.type[y][x] ~= type or g_cellTemp.road[y][x] then
					return false
				end
			end
		end
		return true
	end

	for _,poi in ipairs( pois ) do
		if poi.type == POI_RANDOM_PLACEHOLDER then
			assert( poi.size == 2 )
			local terrainType = g_cornerTemp.type[poi.y][poi.x]
			local noise = sm.noise.intNoise2d( poi.x, poi.y, seed + 3208 )

			if terrainType == TYPE_MEADOW then

				noise = noise % 5
				if noise == 1 then
					poi.type = POI_CHEMLAKE_MEDIUM
					poi.size = 2
					poi.flat = true
				elseif noise == 2 then
					poi.type = POI_RUIN_MEDIUM
					poi.size = 2
					poi.flat = false
				elseif noise == 3 then
					poi.type = POI_BUILDAREA_MEDIUM
					poi.size = 2
					poi.flat = false
				elseif noise == 4 then
					poi.type = POI_CAMP
					poi.size = 1
					poi.flat = false
				else
					poi.type = POI_RUIN
					poi.size = 1
					poi.flat = false
				end

			elseif terrainType == TYPE_FOREST then

				noise = noise % 2
				if noise == 1 then
					poi.type = POI_FOREST_RUIN_MEDIUM
					poi.size = 2
					poi.flat = false
				else
					poi.type = POI_FOREST_CAMP
					poi.size = 1
					poi.flat = false
				end

			elseif terrainType == TYPE_FIELD then

				noise = noise % 2
				if noise == 1 then
					poi.type = POI_FARMINGPATCH
					poi.size = 1
					poi.flat = false
				else
					poi.type = POI_FIELD_RUIN
					poi.size = 1
					poi.flat = false
				end

			elseif terrainType == TYPE_BURNTFOREST then

				noise = noise % 2
				if noise == 1 then
					poi.type = POI_BURNTFOREST_CAMP
					poi.size = 1
					poi.flat = false
				else
					poi.type = POI_BURNTFOREST_RUIN
					poi.size = 1
					poi.flat = false
				end

			elseif terrainType == TYPE_AUTUMNFOREST then

				noise = noise % 2
				if noise == 1 then
					poi.type = POI_AUTUMNFOREST_CAMP
					poi.size = 1
					poi.flat = false
				else
					poi.type = POI_AUTUMNFOREST_RUIN
					poi.size = 1
					poi.flat = false
				end

			elseif terrainType == TYPE_LAKE then

				poi.size = 4
				if allOfTypeNoRoad( poi, TYPE_LAKE ) then
					poi.type = POI_LAKE_UNDERWATER_MEDIUM
					poi.size = 2
					poi.flat = true
					poi.cellDebug = nil
				else
					poi.type = nil -- Remove
				end

			else

				poi.type = nil
			end
			--poi.type = nil -- HACK REMOVE ALL

			if poi.type ~= nil and poi.cellDebug == nil then
				poi.cellDebug = nil
			end
		end
	end

	removeFromArray( pois, function( poi )
		return poi.type == nil
	end )

	------------------------------------------------------------------------------------------------

	-- Inherit cliff level from closest poi
	local maxPoiDst = 0
	forEveryCorner( function( x, y )
		local dst, poi = closestPoi( pois, x, y )
		assert( poi.cliffLevel )
		g_cellData.cliffLevel[y][x] = poi.cliffLevel -- Could add some random cliff level here
		g_cornerTemp.poiDst[y][x] = dst
		maxPoiDst = maxPoiDst < dst and dst or maxPoiDst
	end )
	print( "Max poi distance:", maxPoiDst )

	------------------------------------------------------------------------------------------------

	-- Add all pois
	for _,poi in ipairs( pois ) do
		assert( poi.type ~= POI_RANDOM_PLACEHOLDER )
		if poi.type ~= nil and poi.type ~= POI_CRASHSITE_AREA then
			--poi.rotation = 0
			flattenPoiCliff( poi )
			writePoi( poi )
		end
	end

	-- Crash site and nearby pois
	writeStartArea( pois )

	------------------------------------------------------------------------------------------------

	-- Processing: All corner types must be adjacent to meadow
	addBorderingMeadows()

	-- Max 3 cliff level difference on a cell, 1 on roads
	enforceCliffRoadLimitations()

	-- Evaluate road and cliff cells
	evaluateRoadsAndCliffs()

	------------------------------------------------------------------------------------------------

	local function getCornerType( cornerX, cornerY )
		if insideCornerBounds( cornerX, cornerY ) then
			return g_cornerTemp.type[cornerY][cornerX]
		end
		return 0
	end

	------------------------------------------------------------------------------------------------

	-- Calculate lake adjacency
	forEveryCorner( function( x, y )
		if getCornerType( x - 1, y - 1 ) == TYPE_LAKE then
		elseif getCornerType( x, y - 1 ) == TYPE_LAKE then
		elseif getCornerType( x + 1, y - 1 ) == TYPE_LAKE then
		elseif getCornerType( x - 1, y ) == TYPE_LAKE then
		elseif getCornerType( x, y ) == TYPE_LAKE then
		elseif getCornerType( x + 1, y ) == TYPE_LAKE then
		elseif getCornerType( x - 1, y + 1 ) == TYPE_LAKE then
		elseif getCornerType( x, y + 1 ) == TYPE_LAKE then
		elseif getCornerType( x + 1, y + 1 ) == TYPE_LAKE then
		else
			g_cornerTemp.lakeAdjacent[y][x] = false
		end
	end )

	for _,poi in ipairs( pois ) do
		if poi.type ~= nil and poi.type ~= POI_CRASHSITE_AREA then
			setLakeAdjacentPoiHillynessToZero( poi )
		end
	end

	-- Cells close to lakes get less effect from elevation noise
	for y = yMin, yMax + 1 do
		-- Sweep west to east
		for x = xMin + 1, xMax + 1 do
			if g_cornerTemp.lakeAdjacent[y][x] then
				g_cornerTemp.hillyness[y][x] = 0
			else
				g_cornerTemp.hillyness[y][x] = math.min( g_cornerTemp.hillyness[y][x - 1] + 0.2, g_cornerTemp.hillyness[y][x] )
			end
		end
		-- Sweep east to west
		for x = xMax, xMin + 1, -1 do
			if g_cornerTemp.lakeAdjacent[y][x] then
				g_cornerTemp.hillyness[y][x] = 0
			else
				g_cornerTemp.hillyness[y][x] = math.min( g_cornerTemp.hillyness[y][x + 1] + 0.2, g_cornerTemp.hillyness[y][x] )
			end
		end
	end
	for x = xMin, xMax + 1 do
		-- Sweep south to north
		for y = yMin + 1, yMax + 1 do
			if g_cornerTemp.lakeAdjacent[y][x] then
				g_cornerTemp.hillyness[y][x] = 0
			else
				g_cornerTemp.hillyness[y][x] = math.min( g_cornerTemp.hillyness[y - 1][x] + 0.2, g_cornerTemp.hillyness[y][x] )
			end
		end
		-- Sweep north to south
		for y = yMax, yMin + 1, -1 do
			if g_cornerTemp.lakeAdjacent[y][x] then
				g_cornerTemp.hillyness[y][x] = 0
			else
				g_cornerTemp.hillyness[y][x] = math.min( g_cornerTemp.hillyness[y + 1][x] + 0.2, g_cornerTemp.hillyness[y][x] )
			end
		end
	end

	forEveryCorner( function( x, y )
		if g_cornerTemp.lakeAdjacent[y][x] then
			g_cellData.elevation[y][x] = 0
		else
			local elevation = 0.1 + clamp( ( g_cornerTemp.gradC[y][x] * 3 - 1 ) * 0.1, 0, 1 )
			elevation = elevation + sm.noise.perlinNoise2d( x / 16, y / 16, seed + 7907 ) * clamp( ( g_cornerTemp.gradC[y][x] * 3 - 1 ), 0, 1 )
			elevation = elevation + sm.noise.perlinNoise2d( x / 8, y / 8, seed + 5527 ) * 0.5
			elevation = elevation + sm.noise.perlinNoise2d( x / 4, y / 4, seed + 8733 ) * 0.25
			elevation = elevation + sm.noise.perlinNoise2d( x / 2, y / 2, seed + 5442 ) * 0.125
			g_cellData.elevation[y][x] = g_cornerTemp.hillyness[y][x] * elevation * 250
		end
	end )

	------------------------------------------------------------------------------------------------

	writePoiDebug( crashSite.x, crashSite.y, crashSite.cellDebug, crashSite.size )

	-- Flatten poi elevation
	for _,poi in ipairs( pois ) do
		if poi.type ~= nil and poi.type ~= POI_CRASHSITE_AREA then
			flattenPoiElevation( poi )
			writePoiDebug( poi.x, poi.y, poi.cellDebug, poi.size )
		end
	end

	------------------------------------------------------------------------------------------------

	-- Scan for additional small poi spots
	forEveryCell( function( x, y )
		--g_cellData.cellDebug[y][x] = DEBUG_R
		local type = getCornerType( x, y )
		if g_cellData.flags[y][x] == 0 and getCornerType( x + 1, y ) == type and getCornerType( x, y + 1 ) == type and getCornerType( x + 1, y + 1 ) == type then

			-- Find poi box distance
			local minBoxDst = math.huge
			for _,poi in pairs( pois ) do
				local halfSize = math.floor( poi.size / 2 )
				local xDst, yDst
				if x > poi.x then
					xDst = x - poi.x - math.max( 0, halfSize - 1 )
				else
					xDst = poi.x - x - halfSize
				end
				if y > poi.y then
					yDst = y - poi.y - math.max( 0, halfSize - 1 )
				else
					yDst = poi.y - y - halfSize
				end

				minBoxDst = math.min( math.max( xDst, yDst ), minBoxDst )
			end

			if minBoxDst > 1 then
				--g_cellData.cellDebug[y][x] = DEBUG_G
			end
		end
	end )

	for i = 0,32 do
		for j = 0,42 do
			local k = 0
			while k < 2 do
				local y = i * 3 - 48 + k
				local l = 0
				while l < 2 do
					local x = j * 3 - 64 + ( i % 3 ) + l

					local terrainType = getCornerType( x, y )
					if g_cellData.flags[y][x] == 0 and getCornerType( x + 1, y ) == terrainType
						and getCornerType( x, y + 1 ) == terrainType and getCornerType( x + 1, y + 1 ) == terrainType then

						-- Find poi box distance
						local minBoxDst = math.huge
						for _,poi in pairs( pois ) do
							local halfSize = math.floor( poi.size / 2 )
							local xDst, yDst
							if x > poi.x then
								xDst = x - poi.x - math.max( 0, halfSize - 1 )
							else
								xDst = poi.x - x - halfSize
							end
							if y > poi.y then
								yDst = y - poi.y - math.max( 0, halfSize - 1 )
							else
								yDst = poi.y - y - halfSize
							end

							minBoxDst = math.min( math.max( xDst, yDst ), minBoxDst )
						end

						if minBoxDst > 1 then

							local poi = {
								x = x,
								y = y,
								type = nil,
								size = 1,
								road = false,
								flat = false,
								terrainType = terrainType,
								edges = {}
							}

							if terrainType == TYPE_MEADOW then
								poi.type = POI_RANDOM

							elseif terrainType == TYPE_FOREST then
								poi.type = POI_FOREST_RANDOM

							elseif terrainType == TYPE_DESERT then
								poi.type = POI_DESERT_RANDOM

							elseif terrainType == TYPE_FIELD then
								poi.type = POI_FIELD_RANDOM

							elseif terrainType == TYPE_BURNTFOREST then
								poi.type = POI_BURNTFOREST_RANDOM

							elseif terrainType == TYPE_AUTUMNFOREST then
								poi.type = POI_AUTUMNFOREST_RANDOM

							elseif terrainType == TYPE_LAKE then
								poi.type = POI_LAKE_RANDOM
							end

							if poi.type then
								writePoi( poi )
							end

							g_cellData.cellDebug[y][x] = DEBUG_B
							l = 2
							k = 2
						end
					end
					l = l + 1
				end
				k = k + 1
			end
		end
	end

	------------------------------------------------------------------------------------------------

	-- Evaluate standard terrain cells
	evaluateType( TYPE_MEADOW, getMeadowTileIdAndRotation )
	evaluateType( TYPE_FOREST, getForestTileIdAndRotation )
	evaluateType( TYPE_DESERT, getDesertTileIdAndRotation )
	evaluateType( TYPE_FIELD, getFieldTileIdAndRotation )
	evaluateType( TYPE_BURNTFOREST, getBurntForestTileIdAndRotation )
	evaluateType( TYPE_AUTUMNFOREST, getAutumnForestTileIdAndRotation )
	evaluateType( TYPE_LAKE, getLakeTileIdAndRotation )

	------------------------------------------------------------------------------------------------

	-- Statistics
	local typeCount = {}
	local totalCellCount = ( xMax - xMin + 1 ) * ( yMax - yMin + 1 )

	forEveryCell( function( cellX, cellY )
		local type = g_cornerTemp.type[cellY][cellX]
		if typeCount[type] then
			typeCount[type] = typeCount[type] + 1
		else
			typeCount[type] = 1
		end
	end )

	local toPercent = function( val )
		if val then
			return math.floor( 10000 * val / totalCellCount ) / 100
		end
		return 0
	end

	print( "Distribution of terrain type on cell corners: " )
	print( "MEADOW: "..toPercent( typeCount[TYPE_MEADOW] ).."%" )
	print( "FOREST: "..toPercent( typeCount[TYPE_FOREST] ).."%" )
	print( "DESERT: "..toPercent( typeCount[TYPE_DESERT] ).."%" )
	print( "FIELD: "..toPercent( typeCount[TYPE_FIELD] ).."%" )
	print( "BURNTFOREST: "..toPercent( typeCount[TYPE_BURNTFOREST] ).."%" )
	print( "AUTUMNFOREST: "..toPercent( typeCount[TYPE_AUTUMNFOREST] ).."%" )
	print( "LAKE: "..toPercent( typeCount[TYPE_LAKE] ).."%" )

	------------------------------------------------------------------------------------------------

	local tileUseCounts = {}

	for _, poi in ipairs( pois ) do
		local uid = GetCellTileUid( poi.x, poi.y )
		if not uid:isNil() then
			local tile = GetPath( uid )
			if tile ~= nil then			
				tileUseCounts[tile] = ( tileUseCounts[tile] or 0 ) + 1
			end
		end
	end

	local sortedTiles = {}

	for tile, _ in pairs( tileUseCounts ) do
		sortedTiles[#sortedTiles + 1] = tile
	end

	table.sort( sortedTiles )

	for _,tile in ipairs( sortedTiles ) do
		print( tileUseCounts[tile], tile )
	end

	------------------------------------------------------------------------------------------------

	-- Clear temps
	g_cornerTemp = nil
	g_cellTemp = nil
end
