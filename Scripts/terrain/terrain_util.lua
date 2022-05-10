
----------------------------------------------------------------------------------------------------
-- Utility
----------------------------------------------------------------------------------------------------

function insideCornerBounds( cornerX, cornerY )
	if cornerX < g_cellData.bounds.xMin or cornerX > g_cellData.bounds.xMax then
		return false
	elseif cornerY < g_cellData.bounds.yMin or cornerY > g_cellData.bounds.yMax then
		return false
	end
	return true
end

----------------------------------------------------------------------------------------------------

function insideCellBounds( cellX, cellY )
	if cellX < g_cellData.bounds.xMin or cellX > g_cellData.bounds.xMax then
		return false
	elseif cellY < g_cellData.bounds.yMin or cellY > g_cellData.bounds.yMax then
		return false
	end
	return true
end

----------------------------------------------------------------------------------------------------

function getClosestCorner( x, y )
	return math.floor( x / CELL_SIZE + 0.5 ), math.floor( y / CELL_SIZE + 0.5 )
end

----------------------------------------------------------------------------------------------------

function getCell( x, y )
	return math.floor( x / CELL_SIZE ), math.floor( y / CELL_SIZE )
end

----------------------------------------------------------------------------------------------------

function drawLine( points, x0, y0, x1, y1 )
	local xDir = x1 - x0 >= 0 and 1 or -1
	local yDir = y1 - y0 >= 0 and 1 or -1
	local xDiff = math.abs( x1 - x0 )
	local yDiff = math.abs( y1 - y0 )

	local x = 0
	local y = 0
	while x < xDiff or y < yDiff do
		local point = { x = x0 + x * xDir, y = y0 + y * yDir }
		table.insert( points, point )

		if x / xDiff < y / yDiff then
			x = x + 1
		elseif x / xDiff > y / yDiff then
			y = y + 1
		elseif xDiff > yDiff then
			x = x + 1
		else
			y = y + 1
		end
	end
	table.insert( points, { x = x1, y = y1 } )
end

----------------------------------------------------------------------------------------------------

function dist2( x0, y0, x1, y1 )
	return ( x0 - x1 )^2 + ( y0 - y1 )^2
end

----------------------------------------------------------------------------------------------------

function distance( x0, y0, x1, y1 )
	return math.sqrt( dist2( x0, y0, x1, y1 ) )
end

----------------------------------------------------------------------------------------------------
