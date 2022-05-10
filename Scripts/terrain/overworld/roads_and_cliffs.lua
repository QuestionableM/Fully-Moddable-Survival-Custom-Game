dofile "celldata.lua"

----------------------------------------------------------------------------------------------------
-- Data
----------------------------------------------------------------------------------------------------

local g_roadsAndCliffs = {} --Flags lookup table

--------------------------------------------------------
-- Cliff road bits                                    --
--      | ROADS             | CLIFFS                  --
-- dir  |  S |  W |  N |  E |  SE |  SW |  NW |  NE | --
-- bit  | 11 | 10 |  9 |  8 | 7 6 | 5 4 | 3 2 | 1 0 | --
--------------------------------------------------------

----------------------------------------------------------------------------------------------------
-- Utility
----------------------------------------------------------------------------------------------------

function calculateCliffBits( levelSE, levelSW, levelNW, levelNE )
	local minLevel = math.min( math.min( levelSE, levelSW ), math.min( levelNW, levelNE ) )

	local cliffSE = sm.util.clamp( levelSE - minLevel, 0, 3 )
	local cliffSW = sm.util.clamp( levelSW - minLevel, 0, 3 )
	local cliffNW = sm.util.clamp( levelNW - minLevel, 0, 3 )
	local cliffNE = sm.util.clamp( levelNE - minLevel, 0, 3 )
	--[[
	if cliffSE ~= levelSE - minLevel then
		print( "Clamped a cliff height! (SE)" )
	end
	if cliffSW ~= levelSW - minLevel then
		print( "Clamped a cliff height! (SW)" )
	end
	if cliffNW ~= levelNW - minLevel then
		print( "Clamped a cliff height! (EW)" )
	end
	if cliffNE ~= levelNE - minLevel then
		print( "Clamped a cliff height! (NE)" )
	end
	]]
	local flags = bit.tobit( 0 )
	flags = bit.bor( flags, bit.tobit( bit.lshift( sm.util.clamp( cliffSE, 0, 3 ), 6 ) ) )
	flags = bit.bor( flags, bit.tobit( bit.lshift( sm.util.clamp( cliffSW, 0, 3 ), 4 ) ) )
	flags = bit.bor( flags, bit.tobit( bit.lshift( sm.util.clamp( cliffNW, 0, 3 ), 2 ) ) )
	flags = bit.bor( flags, bit.tobit( bit.lshift( sm.util.clamp( cliffNE, 0, 3 ), 0 ) ) )
	return flags
end

function calculateRoadBits( roadS, roadW, roadN, roadE )
	local flags = bit.tobit( 0 )
	flags = flags + ( roadE and FLAG_ROAD_E or 0 )
	flags = flags + ( roadN and FLAG_ROAD_N or 0 )
	flags = flags + ( roadW and FLAG_ROAD_W or 0 )
	flags = flags + ( roadS and FLAG_ROAD_S or 0 )
	return flags
end

----------------------------------------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------------------------------------

function toCliffIndex( se, sw, nw, ne )
	return bit.bor( bit.lshift( se, 6 ), bit.lshift( sw, 4 ), bit.lshift( nw, 2 ), bit.tobit( ne ) )
end

function toRoadIndex( s, w, n, e )
	return bit.bor( bit.lshift( s, 11 ), bit.lshift( w, 10 ), bit.lshift( n, 9 ), bit.lshift( e, 8 ) )
end

function initRoadAndCliffTiles()
	for i=0, 4095 do
		g_roadsAndCliffs[i] = { tiles = {}, rotation = 0 }
	end

	--This is generated
	g_roadsAndCliffs[toCliffIndex( 0, 0, 0, 1 )] = { tiles = { AddTile( 1000101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_01.tile" ), AddTile( 1000102, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_02.tile" ), AddTile( 1000103, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_03.tile" ), AddTile( 1000104, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_04.tile" ), AddTile( 1000105, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_05.tile" ), AddTile( 1000106, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_06.tile" ), AddTile( 1000107, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_07.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 0, 0, 2 )] = { tiles = { AddTile( 1000201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0002)_01.tile" ), AddTile( 1000202, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0002)_02.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 0, 0, 3 )] = { tiles = { AddTile( 1000301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0003)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 0, 1, 0 )] = { tiles = { AddTile( 1000101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_01.tile" ), AddTile( 1000102, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_02.tile" ), AddTile( 1000103, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_03.tile" ), AddTile( 1000104, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_04.tile" ), AddTile( 1000105, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_05.tile" ), AddTile( 1000106, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_06.tile" ), AddTile( 1000107, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_07.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 0, 0, 1, 1 )] = { tiles = { AddTile( 1000501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_01.tile" ), AddTile( 1000502, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_02.tile" ), AddTile( 1000503, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_03.tile" ), AddTile( 1000504, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_04.tile" ), AddTile( 1000505, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_05.tile" ), AddTile( 1000506, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_06.tile" ), AddTile( 1000507, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_07.tile" ), AddTile( 1000508, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_08.tile" ), AddTile( 1000509, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_09.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 0, 1, 2 )] = { tiles = { AddTile( 1000601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0012)_01.tile" ), AddTile( 1000602, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0012)_02.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 0, 1, 3 )] = { tiles = { AddTile( 1000701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0013)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 0, 2, 0 )] = { tiles = { AddTile( 1000201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0002)_01.tile" ), AddTile( 1000202, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0002)_02.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 0, 0, 2, 1 )] = { tiles = { AddTile( 1000901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0021)_01.tile" ), AddTile( 1000902, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0021)_02.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 0, 2, 2 )] = { tiles = { AddTile( 1001001, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0022)_01.tile" ), AddTile( 1001002, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0022)_02.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 0, 2, 3 )] = { tiles = { AddTile( 1001101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0023)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 0, 3, 0 )] = { tiles = { AddTile( 1000301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0003)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 0, 0, 3, 1 )] = { tiles = { AddTile( 1001301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0031)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 0, 3, 2 )] = { tiles = { AddTile( 1001401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0032)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 0, 3, 3 )] = { tiles = { AddTile( 1001501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0033)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 0, 0 )] = { tiles = { AddTile( 1000101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_01.tile" ), AddTile( 1000102, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_02.tile" ), AddTile( 1000103, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_03.tile" ), AddTile( 1000104, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_04.tile" ), AddTile( 1000105, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_05.tile" ), AddTile( 1000106, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_06.tile" ), AddTile( 1000107, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_07.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 0, 1 )] = { tiles = { AddTile( 1001701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0101)_01.tile" ), AddTile( 1001702, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0101)_02.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 0, 2 )] = { tiles = { AddTile( 1001801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0102)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 0, 3 )] = { tiles = { AddTile( 1001901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0103)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 1, 0 )] = { tiles = { AddTile( 1000501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_01.tile" ), AddTile( 1000502, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_02.tile" ), AddTile( 1000503, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_03.tile" ), AddTile( 1000504, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_04.tile" ), AddTile( 1000505, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_05.tile" ), AddTile( 1000506, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_06.tile" ), AddTile( 1000507, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_07.tile" ), AddTile( 1000508, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_08.tile" ), AddTile( 1000509, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_09.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 1, 1 )] = { tiles = { AddTile( 1002101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0111)_01.tile" ), AddTile( 1002102, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0111)_02.tile" ), AddTile( 1002103, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0111)_03.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 1, 2 )] = { tiles = { AddTile( 1002201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0112)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 1, 3 )] = { tiles = { AddTile( 1002301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0113)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 2, 0 )] = { tiles = { AddTile( 1000601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0012)_01.tile" ), AddTile( 1000602, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0012)_02.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 2, 1 )] = { tiles = { AddTile( 1002501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0121)_01.tile" ), AddTile( 1002502, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0121)_02.tile" ), AddTile( 1002503, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0121)_03.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 2, 2 )] = { tiles = { AddTile( 1002601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0122)_01.tile" ), AddTile( 1002602, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0122)_02.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 2, 3 )] = { tiles = { AddTile( 1002701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0123)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 3, 0 )] = { tiles = { AddTile( 1000701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0013)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 3, 1 )] = { tiles = { AddTile( 1002901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0131)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 3, 2 )] = { tiles = { AddTile( 1003001, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0132)_01.tile" ), AddTile( 1003002, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0132)_02.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 1, 3, 3 )] = { tiles = { AddTile( 1003101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0133)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 0, 0 )] = { tiles = { AddTile( 1000201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0002)_01.tile" ), AddTile( 1000202, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0002)_02.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 0, 1 )] = { tiles = { AddTile( 1001801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0102)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 0, 2 )] = { tiles = { AddTile( 1003401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0202)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 0, 3 )] = { tiles = { AddTile( 1003501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0203)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 1, 0 )] = { tiles = { AddTile( 1000901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0021)_01.tile" ), AddTile( 1000902, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0021)_02.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 1, 1 )] = { tiles = { AddTile( 1003701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0211)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 1, 2 )] = { tiles = { AddTile( 1003801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0212)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 1, 3 )] = { tiles = { AddTile( 1003901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0213)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 2, 0 )] = { tiles = { AddTile( 1001001, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0022)_01.tile" ), AddTile( 1001002, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0022)_02.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 2, 1 )] = { tiles = { AddTile( 1004101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0221)_01.tile" ), AddTile( 1004102, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0221)_02.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 2, 2 )] = { tiles = { AddTile( 1004201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0222)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 2, 3 )] = { tiles = { AddTile( 1004301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0223)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 3, 0 )] = { tiles = { AddTile( 1001101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0023)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 3, 1 )] = { tiles = { AddTile( 1004501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0231)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 3, 2 )] = { tiles = { AddTile( 1004601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0232)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 2, 3, 3 )] = { tiles = { AddTile( 1004701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0233)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 0, 0 )] = { tiles = { AddTile( 1000301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0003)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 0, 1 )] = { tiles = { AddTile( 1001901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0103)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 0, 2 )] = { tiles = { AddTile( 1003501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0203)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 0, 3 )] = { tiles = { AddTile( 1005101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0303)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 1, 0 )] = { tiles = { AddTile( 1001301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0031)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 1, 1 )] = { tiles = { AddTile( 1005301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0311)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 1, 2 )] = { tiles = { AddTile( 1005401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0312)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 1, 3 )] = { tiles = { AddTile( 1005501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0313)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 2, 0 )] = { tiles = { AddTile( 1001401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0032)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 2, 1 )] = { tiles = { AddTile( 1005701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0321)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 2, 2 )] = { tiles = { AddTile( 1005801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0322)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 2, 3 )] = { tiles = { AddTile( 1005901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0323)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 3, 0 )] = { tiles = { AddTile( 1001501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0033)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 3, 1 )] = { tiles = { AddTile( 1006101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0331)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 3, 2 )] = { tiles = { AddTile( 1006201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0332)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 0, 3, 3, 3 )] = { tiles = { AddTile( 1006301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0333)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 0, 0 )] = { tiles = { AddTile( 1000101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_01.tile" ), AddTile( 1000102, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_02.tile" ), AddTile( 1000103, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_03.tile" ), AddTile( 1000104, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_04.tile" ), AddTile( 1000105, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_05.tile" ), AddTile( 1000106, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_06.tile" ), AddTile( 1000107, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0001)_07.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 0, 1 )] = { tiles = { AddTile( 1000501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_01.tile" ), AddTile( 1000502, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_02.tile" ), AddTile( 1000503, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_03.tile" ), AddTile( 1000504, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_04.tile" ), AddTile( 1000505, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_05.tile" ), AddTile( 1000506, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_06.tile" ), AddTile( 1000507, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_07.tile" ), AddTile( 1000508, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_08.tile" ), AddTile( 1000509, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_09.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 0, 2 )] = { tiles = { AddTile( 1000901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0021)_01.tile" ), AddTile( 1000902, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0021)_02.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 0, 3 )] = { tiles = { AddTile( 1001301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0031)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 1, 0 )] = { tiles = { AddTile( 1001701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0101)_01.tile" ), AddTile( 1001702, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0101)_02.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 1, 1 )] = { tiles = { AddTile( 1002101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0111)_01.tile" ), AddTile( 1002102, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0111)_02.tile" ), AddTile( 1002103, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0111)_03.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 1, 2 )] = { tiles = { AddTile( 1002501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0121)_01.tile" ), AddTile( 1002502, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0121)_02.tile" ), AddTile( 1002503, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0121)_03.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 1, 3 )] = { tiles = { AddTile( 1002901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0131)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 2, 0 )] = { tiles = { AddTile( 1001801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0102)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 2, 1 )] = { tiles = { AddTile( 1003701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0211)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 2, 2 )] = { tiles = { AddTile( 1004101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0221)_01.tile" ), AddTile( 1004102, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0221)_02.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 2, 3 )] = { tiles = { AddTile( 1004501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0231)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 3, 0 )] = { tiles = { AddTile( 1001901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0103)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 3, 1 )] = { tiles = { AddTile( 1005301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0311)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 3, 2 )] = { tiles = { AddTile( 1005701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0321)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 1, 0, 3, 3 )] = { tiles = { AddTile( 1006101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0331)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 1, 1, 0, 0 )] = { tiles = { AddTile( 1000501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_01.tile" ), AddTile( 1000502, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_02.tile" ), AddTile( 1000503, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_03.tile" ), AddTile( 1000504, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_04.tile" ), AddTile( 1000505, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_05.tile" ), AddTile( 1000506, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_06.tile" ), AddTile( 1000507, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_07.tile" ), AddTile( 1000508, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_08.tile" ), AddTile( 1000509, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0011)_09.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 1, 1, 0, 1 )] = { tiles = { AddTile( 1002101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0111)_01.tile" ), AddTile( 1002102, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0111)_02.tile" ), AddTile( 1002103, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0111)_03.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 1, 1, 0, 2 )] = { tiles = { AddTile( 1003701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0211)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 1, 1, 0, 3 )] = { tiles = { AddTile( 1005301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0311)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 1, 1, 1, 0 )] = { tiles = { AddTile( 1002101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0111)_01.tile" ), AddTile( 1002102, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0111)_02.tile" ), AddTile( 1002103, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0111)_03.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 1, 1, 2, 0 )] = { tiles = { AddTile( 1002201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0112)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 1, 1, 3, 0 )] = { tiles = { AddTile( 1002301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0113)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 1, 2, 0, 0 )] = { tiles = { AddTile( 1000601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0012)_01.tile" ), AddTile( 1000602, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0012)_02.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 1, 2, 0, 1 )] = { tiles = { AddTile( 1002201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0112)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 1, 2, 0, 2 )] = { tiles = { AddTile( 1003801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0212)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 1, 2, 0, 3 )] = { tiles = { AddTile( 1005401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0312)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 1, 2, 1, 0 )] = { tiles = { AddTile( 1002501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0121)_01.tile" ), AddTile( 1002502, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0121)_02.tile" ), AddTile( 1002503, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0121)_03.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 1, 2, 2, 0 )] = { tiles = { AddTile( 1002601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0122)_01.tile" ), AddTile( 1002602, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0122)_02.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 1, 2, 3, 0 )] = { tiles = { AddTile( 1002701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0123)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 1, 3, 0, 0 )] = { tiles = { AddTile( 1000701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0013)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 1, 3, 0, 1 )] = { tiles = { AddTile( 1002301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0113)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 1, 3, 0, 2 )] = { tiles = { AddTile( 1003901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0213)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 1, 3, 0, 3 )] = { tiles = { AddTile( 1005501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0313)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 1, 3, 1, 0 )] = { tiles = { AddTile( 1002901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0131)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 1, 3, 2, 0 )] = { tiles = { AddTile( 1003001, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0132)_01.tile" ), AddTile( 1003002, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0132)_02.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 1, 3, 3, 0 )] = { tiles = { AddTile( 1003101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0133)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 0, 0 )] = { tiles = { AddTile( 1000201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0002)_01.tile" ), AddTile( 1000202, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0002)_02.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 0, 1 )] = { tiles = { AddTile( 1000601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0012)_01.tile" ), AddTile( 1000602, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0012)_02.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 0, 2 )] = { tiles = { AddTile( 1001001, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0022)_01.tile" ), AddTile( 1001002, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0022)_02.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 0, 3 )] = { tiles = { AddTile( 1001401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0032)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 1, 0 )] = { tiles = { AddTile( 1001801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0102)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 1, 1 )] = { tiles = { AddTile( 1002201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0112)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 1, 2 )] = { tiles = { AddTile( 1002601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0122)_01.tile" ), AddTile( 1002602, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0122)_02.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 1, 3 )] = { tiles = { AddTile( 1003001, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0132)_01.tile" ), AddTile( 1003002, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0132)_02.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 2, 0 )] = { tiles = { AddTile( 1003401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0202)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 2, 1 )] = { tiles = { AddTile( 1003801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0212)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 2, 2 )] = { tiles = { AddTile( 1004201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0222)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 2, 3 )] = { tiles = { AddTile( 1004601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0232)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 3, 0 )] = { tiles = { AddTile( 1003501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0203)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 3, 1 )] = { tiles = { AddTile( 1005401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0312)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 3, 2 )] = { tiles = { AddTile( 1005801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0322)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 2, 0, 3, 3 )] = { tiles = { AddTile( 1006201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0332)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 2, 1, 0, 0 )] = { tiles = { AddTile( 1000901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0021)_01.tile" ), AddTile( 1000902, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0021)_02.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 2, 1, 0, 1 )] = { tiles = { AddTile( 1002501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0121)_01.tile" ), AddTile( 1002502, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0121)_02.tile" ), AddTile( 1002503, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0121)_03.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 2, 1, 0, 2 )] = { tiles = { AddTile( 1004101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0221)_01.tile" ), AddTile( 1004102, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0221)_02.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 2, 1, 0, 3 )] = { tiles = { AddTile( 1005701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0321)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 2, 1, 1, 0 )] = { tiles = { AddTile( 1003701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0211)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 2, 1, 2, 0 )] = { tiles = { AddTile( 1003801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0212)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 2, 1, 3, 0 )] = { tiles = { AddTile( 1003901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0213)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 2, 2, 0, 0 )] = { tiles = { AddTile( 1001001, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0022)_01.tile" ), AddTile( 1001002, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0022)_02.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 2, 2, 0, 1 )] = { tiles = { AddTile( 1002601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0122)_01.tile" ), AddTile( 1002602, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0122)_02.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 2, 2, 0, 2 )] = { tiles = { AddTile( 1004201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0222)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 2, 2, 0, 3 )] = { tiles = { AddTile( 1005801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0322)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 2, 2, 1, 0 )] = { tiles = { AddTile( 1004101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0221)_01.tile" ), AddTile( 1004102, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0221)_02.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 2, 2, 2, 0 )] = { tiles = { AddTile( 1004201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0222)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 2, 2, 3, 0 )] = { tiles = { AddTile( 1004301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0223)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 2, 3, 0, 0 )] = { tiles = { AddTile( 1001101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0023)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 2, 3, 0, 1 )] = { tiles = { AddTile( 1002701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0123)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 2, 3, 0, 2 )] = { tiles = { AddTile( 1004301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0223)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 2, 3, 0, 3 )] = { tiles = { AddTile( 1005901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0323)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 2, 3, 1, 0 )] = { tiles = { AddTile( 1004501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0231)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 2, 3, 2, 0 )] = { tiles = { AddTile( 1004601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0232)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 2, 3, 3, 0 )] = { tiles = { AddTile( 1004701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0233)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 0, 0 )] = { tiles = { AddTile( 1000301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0003)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 0, 1 )] = { tiles = { AddTile( 1000701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0013)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 0, 2 )] = { tiles = { AddTile( 1001101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0023)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 0, 3 )] = { tiles = { AddTile( 1001501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0033)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 1, 0 )] = { tiles = { AddTile( 1001901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0103)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 1, 1 )] = { tiles = { AddTile( 1002301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0113)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 1, 2 )] = { tiles = { AddTile( 1002701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0123)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 1, 3 )] = { tiles = { AddTile( 1003101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0133)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 2, 0 )] = { tiles = { AddTile( 1003501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0203)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 2, 1 )] = { tiles = { AddTile( 1003901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0213)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 2, 2 )] = { tiles = { AddTile( 1004301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0223)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 2, 3 )] = { tiles = { AddTile( 1004701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0233)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 3, 0 )] = { tiles = { AddTile( 1005101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0303)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 3, 1 )] = { tiles = { AddTile( 1005501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0313)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 3, 2 )] = { tiles = { AddTile( 1005901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0323)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 0, 3, 3 )] = { tiles = { AddTile( 1006301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0333)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[toCliffIndex( 3, 1, 0, 0 )] = { tiles = { AddTile( 1001301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0031)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 3, 1, 0, 1 )] = { tiles = { AddTile( 1002901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0131)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 3, 1, 0, 2 )] = { tiles = { AddTile( 1004501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0231)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 3, 1, 0, 3 )] = { tiles = { AddTile( 1006101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0331)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 3, 1, 1, 0 )] = { tiles = { AddTile( 1005301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0311)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 3, 1, 2, 0 )] = { tiles = { AddTile( 1005401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0312)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 3, 1, 3, 0 )] = { tiles = { AddTile( 1005501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0313)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 3, 2, 0, 0 )] = { tiles = { AddTile( 1001401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0032)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 3, 2, 0, 1 )] = { tiles = { AddTile( 1003001, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0132)_01.tile" ), AddTile( 1003002, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0132)_02.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 3, 2, 0, 2 )] = { tiles = { AddTile( 1004601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0232)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 3, 2, 0, 3 )] = { tiles = { AddTile( 1006201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0332)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 3, 2, 1, 0 )] = { tiles = { AddTile( 1005701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0321)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 3, 2, 2, 0 )] = { tiles = { AddTile( 1005801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0322)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 3, 2, 3, 0 )] = { tiles = { AddTile( 1005901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0323)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 3, 3, 0, 0 )] = { tiles = { AddTile( 1001501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0033)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 3, 3, 0, 1 )] = { tiles = { AddTile( 1003101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0133)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 3, 3, 0, 2 )] = { tiles = { AddTile( 1004701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0233)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 3, 3, 0, 3 )] = { tiles = { AddTile( 1006301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0333)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[toCliffIndex( 3, 3, 1, 0 )] = { tiles = { AddTile( 1006101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0331)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 3, 3, 2, 0 )] = { tiles = { AddTile( 1006201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0332)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[toCliffIndex( 3, 3, 3, 0 )] = { tiles = { AddTile( 1006301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Cliff(0333)_01.tile" ) }, rotation = 1 }

	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 0, 1 ), toCliffIndex( 0, 0, 0, 0 ) )] = { tiles = { AddTile( 1025601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0001)_Cliff(0000)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 0 ), toCliffIndex( 0, 0, 0, 0 ) )] = { tiles = { AddTile( 1025601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0001)_Cliff(0000)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 1 ), toCliffIndex( 0, 0, 0, 0 ) )] = { tiles = { AddTile( 1076801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_01.tile" ), AddTile( 1076802, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_02.tile" ), AddTile( 1076803, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_03.tile" ), AddTile( 1076804, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_04.tile" ), AddTile( 1076805, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_05.tile" ), AddTile( 1076806, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_06.tile" ), AddTile( 1076807, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_07.tile" ), AddTile( 1076808, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_08.tile" ), AddTile( 1076809, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_09.tile" ), AddTile( 1076810, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_10.tile" ), AddTile( 1076811, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_11.tile" ), AddTile( 1076812, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_12.tile" ), AddTile( 1076813, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_13.tile" ), AddTile( 1076814, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_14.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 1 ), toCliffIndex( 0, 0, 0, 1 ) )] = { tiles = { AddTile( 1076901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0001)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 1 ), toCliffIndex( 0, 0, 1, 0 ) )] = { tiles = { AddTile( 1077201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0010)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 1 ), toCliffIndex( 0, 0, 1, 1 ) )] = { tiles = { AddTile( 1077301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0011)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 1 ), toCliffIndex( 0, 1, 0, 0 ) )] = { tiles = { AddTile( 1078401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0100)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 1 ), toCliffIndex( 0, 1, 0, 1 ) )] = { tiles = { AddTile( 1078501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0101)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 1 ), toCliffIndex( 0, 1, 1, 0 ) )] = { tiles = { AddTile( 1078801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0110)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 1 ), toCliffIndex( 0, 1, 1, 1 ) )] = { tiles = { AddTile( 1078901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0111)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 1 ), toCliffIndex( 1, 0, 0, 0 ) )] = { tiles = { AddTile( 1083201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1000)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 1 ), toCliffIndex( 1, 0, 0, 1 ) )] = { tiles = { AddTile( 1083301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1001)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 1 ), toCliffIndex( 1, 0, 1, 0 ) )] = { tiles = { AddTile( 1083601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1010)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 1 ), toCliffIndex( 1, 0, 1, 1 ) )] = { tiles = { AddTile( 1083701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1011)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 1 ), toCliffIndex( 1, 1, 0, 0 ) )] = { tiles = { AddTile( 1084801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1100)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 1 ), toCliffIndex( 1, 1, 0, 1 ) )] = { tiles = { AddTile( 1084901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1101)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 0, 1, 1 ), toCliffIndex( 1, 1, 1, 0 ) )] = { tiles = { AddTile( 1085201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1110)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 0 ), toCliffIndex( 0, 0, 0, 0 ) )] = { tiles = { AddTile( 1025601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0001)_Cliff(0000)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 1 ), toCliffIndex( 0, 0, 0, 0 ) )] = { tiles = { AddTile( 1128001, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_01.tile" ), AddTile( 1128002, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_02.tile" ), AddTile( 1128003, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_03.tile" ), AddTile( 1128004, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_04.tile" ), AddTile( 1128005, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_05.tile" ), AddTile( 1128006, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_06.tile" ), AddTile( 1128007, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_07.tile" ), AddTile( 1128008, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_08.tile" ), AddTile( 1128009, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_09.tile" ), AddTile( 1128010, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_10.tile" ), AddTile( 1128011, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_11.tile" ), AddTile( 1128012, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_12.tile" ), AddTile( 1128013, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_13.tile" ), AddTile( 1128014, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_14.tile" ), AddTile( 1128015, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_15.tile" ), AddTile( 1128016, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_16.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 1 ), toCliffIndex( 0, 0, 0, 1 ) )] = { tiles = { AddTile( 1128101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0001)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 1 ), toCliffIndex( 0, 0, 1, 0 ) )] = { tiles = { AddTile( 1128401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0010)_01.tile" ), AddTile( 1128402, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0010)_02.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 1 ), toCliffIndex( 0, 0, 1, 1 ) )] = { tiles = { AddTile( 1128501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0011)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 1 ), toCliffIndex( 0, 1, 0, 0 ) )] = { tiles = { AddTile( 1128101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0001)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 1 ), toCliffIndex( 0, 1, 0, 1 ) )] = { tiles = { AddTile( 1129701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0101)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 1 ), toCliffIndex( 0, 1, 1, 0 ) )] = { tiles = { AddTile( 1130001, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0110)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 1 ), toCliffIndex( 0, 1, 1, 1 ) )] = { tiles = { AddTile( 1130101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0111)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 1 ), toCliffIndex( 1, 0, 0, 0 ) )] = { tiles = { AddTile( 1128401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0010)_01.tile" ), AddTile( 1128402, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0010)_02.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 1 ), toCliffIndex( 1, 0, 0, 1 ) )] = { tiles = { AddTile( 1130001, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0110)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 1 ), toCliffIndex( 1, 0, 1, 0 ) )] = { tiles = { AddTile( 1134801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(1010)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 1 ), toCliffIndex( 1, 0, 1, 1 ) )] = { tiles = { AddTile( 1134901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(1011)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 1 ), toCliffIndex( 1, 1, 0, 0 ) )] = { tiles = { AddTile( 1128501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0011)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 1 ), toCliffIndex( 1, 1, 0, 1 ) )] = { tiles = { AddTile( 1130101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0111)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 0, 1 ), toCliffIndex( 1, 1, 1, 0 ) )] = { tiles = { AddTile( 1134901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(1011)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 0 ), toCliffIndex( 0, 0, 0, 0 ) )] = { tiles = { AddTile( 1076801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_01.tile" ), AddTile( 1076802, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_02.tile" ), AddTile( 1076803, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_03.tile" ), AddTile( 1076804, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_04.tile" ), AddTile( 1076805, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_05.tile" ), AddTile( 1076806, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_06.tile" ), AddTile( 1076807, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_07.tile" ), AddTile( 1076808, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_08.tile" ), AddTile( 1076809, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_09.tile" ), AddTile( 1076810, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_10.tile" ), AddTile( 1076811, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_11.tile" ), AddTile( 1076812, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_12.tile" ), AddTile( 1076813, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_13.tile" ), AddTile( 1076814, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_14.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 0 ), toCliffIndex( 0, 0, 0, 1 ) )] = { tiles = { AddTile( 1083201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1000)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 0 ), toCliffIndex( 0, 0, 1, 0 ) )] = { tiles = { AddTile( 1076901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0001)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 0 ), toCliffIndex( 0, 0, 1, 1 ) )] = { tiles = { AddTile( 1083301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1001)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 0 ), toCliffIndex( 0, 1, 0, 0 ) )] = { tiles = { AddTile( 1077201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0010)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 0 ), toCliffIndex( 0, 1, 0, 1 ) )] = { tiles = { AddTile( 1083601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1010)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 0 ), toCliffIndex( 0, 1, 1, 0 ) )] = { tiles = { AddTile( 1077301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0011)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 0 ), toCliffIndex( 0, 1, 1, 1 ) )] = { tiles = { AddTile( 1083701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1011)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 0 ), toCliffIndex( 1, 0, 0, 0 ) )] = { tiles = { AddTile( 1078401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0100)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 0 ), toCliffIndex( 1, 0, 0, 1 ) )] = { tiles = { AddTile( 1084801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1100)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 0 ), toCliffIndex( 1, 0, 1, 0 ) )] = { tiles = { AddTile( 1078501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0101)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 0 ), toCliffIndex( 1, 0, 1, 1 ) )] = { tiles = { AddTile( 1084901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1101)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 0 ), toCliffIndex( 1, 1, 0, 0 ) )] = { tiles = { AddTile( 1078801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0110)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 0 ), toCliffIndex( 1, 1, 0, 1 ) )] = { tiles = { AddTile( 1085201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1110)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 0 ), toCliffIndex( 1, 1, 1, 0 ) )] = { tiles = { AddTile( 1078901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0111)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 0, 1, 1, 1 ), toCliffIndex( 0, 0, 0, 0 ) )] = { tiles = { AddTile( 1179201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0111)_Cliff(0000)_01.tile" ) }, rotation = 0 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 0 ), toCliffIndex( 0, 0, 0, 0 ) )] = { tiles = { AddTile( 1025601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0001)_Cliff(0000)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 1 ), toCliffIndex( 0, 0, 0, 0 ) )] = { tiles = { AddTile( 1076801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_01.tile" ), AddTile( 1076802, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_02.tile" ), AddTile( 1076803, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_03.tile" ), AddTile( 1076804, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_04.tile" ), AddTile( 1076805, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_05.tile" ), AddTile( 1076806, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_06.tile" ), AddTile( 1076807, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_07.tile" ), AddTile( 1076808, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_08.tile" ), AddTile( 1076809, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_09.tile" ), AddTile( 1076810, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_10.tile" ), AddTile( 1076811, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_11.tile" ), AddTile( 1076812, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_12.tile" ), AddTile( 1076813, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_13.tile" ), AddTile( 1076814, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_14.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 1 ), toCliffIndex( 0, 0, 0, 1 ) )] = { tiles = { AddTile( 1077201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0010)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 1 ), toCliffIndex( 0, 0, 1, 0 ) )] = { tiles = { AddTile( 1078401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0100)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 1 ), toCliffIndex( 0, 0, 1, 1 ) )] = { tiles = { AddTile( 1078801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0110)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 1 ), toCliffIndex( 0, 1, 0, 0 ) )] = { tiles = { AddTile( 1083201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1000)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 1 ), toCliffIndex( 0, 1, 0, 1 ) )] = { tiles = { AddTile( 1083601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1010)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 1 ), toCliffIndex( 0, 1, 1, 0 ) )] = { tiles = { AddTile( 1084801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1100)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 1 ), toCliffIndex( 0, 1, 1, 1 ) )] = { tiles = { AddTile( 1085201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1110)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 1 ), toCliffIndex( 1, 0, 0, 0 ) )] = { tiles = { AddTile( 1076901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0001)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 1 ), toCliffIndex( 1, 0, 0, 1 ) )] = { tiles = { AddTile( 1077301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0011)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 1 ), toCliffIndex( 1, 0, 1, 0 ) )] = { tiles = { AddTile( 1078501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0101)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 1 ), toCliffIndex( 1, 0, 1, 1 ) )] = { tiles = { AddTile( 1078901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0111)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 1 ), toCliffIndex( 1, 1, 0, 0 ) )] = { tiles = { AddTile( 1083301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1001)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 1 ), toCliffIndex( 1, 1, 0, 1 ) )] = { tiles = { AddTile( 1083701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1011)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 0, 1 ), toCliffIndex( 1, 1, 1, 0 ) )] = { tiles = { AddTile( 1084901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1101)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 0 ), toCliffIndex( 0, 0, 0, 0 ) )] = { tiles = { AddTile( 1128001, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_01.tile" ), AddTile( 1128002, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_02.tile" ), AddTile( 1128003, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_03.tile" ), AddTile( 1128004, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_04.tile" ), AddTile( 1128005, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_05.tile" ), AddTile( 1128006, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_06.tile" ), AddTile( 1128007, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_07.tile" ), AddTile( 1128008, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_08.tile" ), AddTile( 1128009, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_09.tile" ), AddTile( 1128010, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_10.tile" ), AddTile( 1128011, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_11.tile" ), AddTile( 1128012, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_12.tile" ), AddTile( 1128013, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_13.tile" ), AddTile( 1128014, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_14.tile" ), AddTile( 1128015, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_15.tile" ), AddTile( 1128016, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0000)_16.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 0 ), toCliffIndex( 0, 0, 0, 1 ) )] = { tiles = { AddTile( 1128401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0010)_01.tile" ), AddTile( 1128402, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0010)_02.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 0 ), toCliffIndex( 0, 0, 1, 0 ) )] = { tiles = { AddTile( 1128101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0001)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 0 ), toCliffIndex( 0, 0, 1, 1 ) )] = { tiles = { AddTile( 1130001, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0110)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 0 ), toCliffIndex( 0, 1, 0, 0 ) )] = { tiles = { AddTile( 1128401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0010)_01.tile" ), AddTile( 1128402, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0010)_02.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 0 ), toCliffIndex( 0, 1, 0, 1 ) )] = { tiles = { AddTile( 1134801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(1010)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 0 ), toCliffIndex( 0, 1, 1, 0 ) )] = { tiles = { AddTile( 1128501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0011)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 0 ), toCliffIndex( 0, 1, 1, 1 ) )] = { tiles = { AddTile( 1134901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(1011)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 0 ), toCliffIndex( 1, 0, 0, 0 ) )] = { tiles = { AddTile( 1128101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0001)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 0 ), toCliffIndex( 1, 0, 0, 1 ) )] = { tiles = { AddTile( 1128501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0011)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 0 ), toCliffIndex( 1, 0, 1, 0 ) )] = { tiles = { AddTile( 1129701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0101)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 0 ), toCliffIndex( 1, 0, 1, 1 ) )] = { tiles = { AddTile( 1130101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0111)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 0 ), toCliffIndex( 1, 1, 0, 0 ) )] = { tiles = { AddTile( 1130001, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0110)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 0 ), toCliffIndex( 1, 1, 0, 1 ) )] = { tiles = { AddTile( 1134901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(1011)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 0 ), toCliffIndex( 1, 1, 1, 0 ) )] = { tiles = { AddTile( 1130101, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0101)_Cliff(0111)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 0, 1, 1 ), toCliffIndex( 0, 0, 0, 0 ) )] = { tiles = { AddTile( 1179201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0111)_Cliff(0000)_01.tile" ) }, rotation = 3 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 0 ), toCliffIndex( 0, 0, 0, 0 ) )] = { tiles = { AddTile( 1076801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_01.tile" ), AddTile( 1076802, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_02.tile" ), AddTile( 1076803, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_03.tile" ), AddTile( 1076804, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_04.tile" ), AddTile( 1076805, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_05.tile" ), AddTile( 1076806, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_06.tile" ), AddTile( 1076807, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_07.tile" ), AddTile( 1076808, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_08.tile" ), AddTile( 1076809, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_09.tile" ), AddTile( 1076810, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_10.tile" ), AddTile( 1076811, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_11.tile" ), AddTile( 1076812, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_12.tile" ), AddTile( 1076813, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_13.tile" ), AddTile( 1076814, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0000)_14.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 0 ), toCliffIndex( 0, 0, 0, 1 ) )] = { tiles = { AddTile( 1078401, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0100)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 0 ), toCliffIndex( 0, 0, 1, 0 ) )] = { tiles = { AddTile( 1083201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1000)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 0 ), toCliffIndex( 0, 0, 1, 1 ) )] = { tiles = { AddTile( 1084801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1100)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 0 ), toCliffIndex( 0, 1, 0, 0 ) )] = { tiles = { AddTile( 1076901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0001)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 0 ), toCliffIndex( 0, 1, 0, 1 ) )] = { tiles = { AddTile( 1078501, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0101)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 0 ), toCliffIndex( 0, 1, 1, 0 ) )] = { tiles = { AddTile( 1083301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1001)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 0 ), toCliffIndex( 0, 1, 1, 1 ) )] = { tiles = { AddTile( 1084901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1101)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 0 ), toCliffIndex( 1, 0, 0, 0 ) )] = { tiles = { AddTile( 1077201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0010)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 0 ), toCliffIndex( 1, 0, 0, 1 ) )] = { tiles = { AddTile( 1078801, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0110)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 0 ), toCliffIndex( 1, 0, 1, 0 ) )] = { tiles = { AddTile( 1083601, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1010)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 0 ), toCliffIndex( 1, 0, 1, 1 ) )] = { tiles = { AddTile( 1085201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1110)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 0 ), toCliffIndex( 1, 1, 0, 0 ) )] = { tiles = { AddTile( 1077301, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0011)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 0 ), toCliffIndex( 1, 1, 0, 1 ) )] = { tiles = { AddTile( 1078901, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(0111)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 0 ), toCliffIndex( 1, 1, 1, 0 ) )] = { tiles = { AddTile( 1083701, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0011)_Cliff(1011)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 0, 1 ), toCliffIndex( 0, 0, 0, 0 ) )] = { tiles = { AddTile( 1179201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0111)_Cliff(0000)_01.tile" ) }, rotation = 2 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 1, 0 ), toCliffIndex( 0, 0, 0, 0 ) )] = { tiles = { AddTile( 1179201, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(0111)_Cliff(0000)_01.tile" ) }, rotation = 1 }
	g_roadsAndCliffs[bit.bor( toRoadIndex( 1, 1, 1, 1 ), toCliffIndex( 0, 0, 0, 0 ) )] = { tiles = { AddTile( 1384001, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(1111)_Cliff(0000)_01.tile" ), AddTile( 1384002, "$SURVIVAL_DATA/Terrain/Tiles/roads_and_cliffs/Road(1111)_Cliff(0000)_02.tile" ) }, rotation = 0 }

end

----------------------------------------------------------------------------------------------------
-- Getters
----------------------------------------------------------------------------------------------------

function getCliffRoadTileIdAndRotation( roadCliffFlags, variationNoise )
	if roadCliffFlags > 0 then
		local item = g_roadsAndCliffs[roadCliffFlags]
		local tileCount = #item.tiles

		if tileCount == 0 then --No tile found, remove road and get cliff only
			item = g_roadsAndCliffs[bit.band( roadCliffFlags, MASK_CLIFF )]
			tileCount = #item.tiles

			if tileCount == 0 then
				return ERROR_TILE_UUID, 0
			end
		end

		return item.tiles[variationNoise % tileCount + 1], item.rotation
	end

	return sm.uuid.getNil(), 0
end
