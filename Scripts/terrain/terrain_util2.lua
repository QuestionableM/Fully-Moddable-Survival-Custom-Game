
----------------------------------------------------------------------------------------------------
-- Utility
----------------------------------------------------------------------------------------------------

CELL_SIZE = 64

function InsideCellBounds( cellX, cellY )
	if cellX < g_cellData.bounds.xMin or cellX > g_cellData.bounds.xMax then
		return false
	elseif cellY < g_cellData.bounds.yMin or cellY > g_cellData.bounds.yMax then
		return false
	end
	return true
end

----------------------------------------------------------------------------------------------------

function GetClosestCorner( x, y )
	return math.floor( x / CELL_SIZE + 0.5 ), math.floor( y / CELL_SIZE + 0.5 )
end

----------------------------------------------------------------------------------------------------

function GetCell( x, y )
	return math.floor( x / CELL_SIZE ), math.floor( y / CELL_SIZE )
end

----------------------------------------------------------------------------------------------------

function GetFraction( x, y )
	local cellX, cellY = GetCell( x, y )
	return x / CELL_SIZE - cellX, y / CELL_SIZE - cellY
end

----------------------------------------------------------------------------------------------------

function GetCellRotation( cellX, cellY )
	if InsideCellBounds( cellX, cellY ) then
		if g_cellData.rotation then
			if g_cellData.rotation[cellY] then
				return g_cellData.rotation[cellY][cellX]
			end
		end
	end
	return 0
end

----------------------------------------------------------------------------------------------------

function RotateLocal( cellX, cellY, x, y, cellSize )
	cellSize = cellSize or CELL_SIZE

	local rotation = GetCellRotation( cellX, cellY )

	local rx, ry
	if rotation == 1 then
		rx = cellSize - y
		ry = x
	elseif rotation == 2 then
		rx = cellSize - x
		ry = cellSize - y
	elseif rotation == 3 then
		rx = y
		ry = cellSize - x
	else
		rx = x
		ry = y
	end

	return rx, ry
end

----------------------------------------------------------------------------------------------------

function InverseRotateLocal( cellX, cellY, x, y, cellSize )
	cellSize = cellSize or CELL_SIZE

	local rotation = GetCellRotation( cellX, cellY )

	local rx, ry
	if rotation == 1 then
		rx = y
		ry = cellSize - x
	elseif rotation == 2 then
		rx = cellSize - x
		ry = cellSize - y
	elseif rotation == 3 then
		rx = cellSize - y
		ry = x
	else
		rx = x
		ry = y
	end

	return rx, ry
end

----------------------------------------------------------------------------------------------------

function GetRotationQuat( cellX, cellY )
	local rotation = GetCellRotation( cellX, cellY )
	if rotation == 1 then
		return sm.quat.new( 0, 0, 0.70710678118654752440084436210485, 0.70710678118654752440084436210485 )
	elseif rotation == 2 then
		return sm.quat.new( 0, 0, 1, 0 )
	elseif rotation == 3 then
		return sm.quat.new( 0, 0, -0.70710678118654752440084436210485, 0.70710678118654752440084436210485 )
	end

	return sm.quat.new( 0, 0, 0, 1 )
end

----------------------------------------------------------------------------------------------------

function SquareDistance( x0, y0, x1, y1 )
	return ( x0 - x1 )^2 + ( y0 - y1 )^2
end

----------------------------------------------------------------------------------------------------

function Distance( x0, y0, x1, y1 )
	return math.sqrt( dist2( x0, y0, x1, y1 ) )
end

----------------------------------------------------------------------------------------------------

function ValueExists( array, value )
	for _, v in ipairs( array ) do
		if v == value then
			return true
		end
	end
	return false
end

----------------------------------------------------------------------------------------------------

function CreateReflectionNode( z )
	return {
		pos = sm.vec3.new( 32, 32, z ),
		rot = sm.quat.new( 0.707107, 0, 0, 0.707107 ),
		scale = sm.vec3.new( 64, 64, 64 ),
		tags = { "REFLECTION" }
	}
end

----------------------------------------------------------------------------------------------------

-- Rotate local foreign connections
function RotateLocalWaypoint( cellX, cellY, node )
	local rotationStep = GetCellRotation( cellX, cellY )
	if rotationStep ~= 0 and ValueExists( node.tags, "WAYPOINT" ) then
		for _, other in ipairs( node.params.connections.otherIds ) do
			if ( type(other) == "table" ) and other.cell then
				local cx = other.cell[1]
				local cy = other.cell[2]
				if rotationStep == 1 then
					other.cell[1] = -cy
					other.cell[2] = cx
				elseif rotationStep == 2 then
					other.cell[1] = -cx
					other.cell[2] = -cy
				elseif rotationStep == 3 then
					other.cell[1] = cy
					other.cell[2] = -cx
				end
			end
		end
	end
end

function CalculateTileStorageKey( worldId, cellX, cellY )
	local rotation = g_cellData.rotation[cellY][cellX]
	local xOffset = g_cellData.xOffset[cellY][cellX]
	local yOffset = g_cellData.yOffset[cellY][cellX]

	local rx, ry
	if rotation == 1 then
		rx = -yOffset
		ry = xOffset
	elseif rotation == 2 then
		rx = -xOffset
		ry = -yOffset
	elseif rotation == 3 then
		rx = yOffset
		ry = -xOffset
	else
		rx = xOffset
		ry = yOffset
	end

	local tx = cellX - rx
	local ty = cellY - ry

	--local x = cellX * 64 + 32
	--local y = cellY * 64 + 32
	--local z = getElevationHeightAt( x, y ) + getCliffHeightAt( x, y )
	--local fromPosition = sm.vec3.new( x, y, z )
	--local toPosition = sm.vec3.new( tx * 64 + 32, ty * 64 + 32, z )
	--local color = sm.color.new( 0, 0, 1 )
	--sm.debugDraw.addArrow( "Kin"..cellX..","..cellY, fromPosition, toPosition, color )

	return "ts_"..worldId..":("..tx..","..ty..")"
end
