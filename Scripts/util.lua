--util.lua
dofile( "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_constants.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

function printf( s, ... )
	return print( s:format( ... ) )
end

function clamp( value, min, max )
	if value < min then return min elseif value > max then return max else return value end
end

function round( value )
	return math.floor( value + 0.5 )
end

function max( a, b )
	return a > b and a or b
end

function min( a, b )
	return a < b and a or b
end

function sign( value )
	return value >= DBL_EPSILON and 1 or ( value <= -DBL_EPSILON and -1 or 0 )
end

function finite( value )
	return  value > -math.huge and value < math.huge
end

function RadToDeg( rad )
	return rad * 57.295779513082320876798154814105
end

function DegToRad( deg )
	return deg * 0.01745329251994329576923690768489
end

function orthogonal( vec )
	assert( type( vec ) == "Vec3" )
	local x = math.abs( vec.x )
	local y = math.abs( vec.y )
	local z = math.abs( vec.z )

	local other = sm.vec3.new( 0, 0, 1 )
	if x < y and x < z then
		sm.vec3.new( 1, 0, 0 )
	elseif y < x and y < z then
		sm.vec3.new( 0, 1, 0 )
	end
	return vec:cross( other )
end

function lerp( a, b, p )
	return clamp( a + (b - a) * p, min(a, b), max(a, b) )
end

function easeIn( a, b, dt, speed )
	local p = 1 - math.pow( clamp( speed, 0.0, 1.0 ), dt * 60 )
	return lerp( a, b, p )
end

function unclampedLerp( a, b, p )
	return a + (b - a) * p
end

function isAnyOf(is, off)
	for _, v in pairs(off) do
		if is == v then
			return true
		end
	end
	return false
end

function valueExists( array, value )
	for _, v in ipairs( array ) do
		if v == value then
			return true
		end
	end
	return false
end

function concat( a, b )
	for _, v in ipairs( b ) do
		a[#a+1] = v;
	end
end

function append( a, b )
	for k, v in pairs( b ) do
		a[k] = v;
	end
end

--http://lua-users.org/wiki/SwitchStatement
function switch( table )
	table.case = function ( self, caseVariable )
		local caseFunction = self[caseVariable] or self.default
		if caseFunction then
			if type( caseFunction ) == "function" then
				caseFunction( caseVariable, self )
			else
				error( "case " .. tostring( caseVariable ).." not a function" )
			end
		end
	end
	return table
end


function addToArrayIfNotExists( array, value )
	local n = #array
	local exists = false
	for i = 1, n do
		if array[i] == value then
			return
		end
	end
	array[n + 1] = value
end


function removeFromArray( array, fnShouldRemove )
	local n = #array;
	local j = 1
	for i = 1, n do
		if fnShouldRemove( array[i] ) then
			array[i] = nil;
		else
			if i ~= j then
				array[j] = array[i];
				array[i] = nil;
			end
			j = j + 1;
		end
	end
	return array;
end

function CellKey( x, y )
	return ( y + 1024 ) * 2048 + x + 1024
end

function isHarvest( shapeUuid )

	local harvests = sm.json.open("$SURVIVAL_DATA/Objects/Database/ShapeSets/harvests.json")
	for i, harvest in ipairs(harvests.partList) do
		local harvestUuid = sm.uuid.new( harvest.uuid )
		if harvestUuid == shapeUuid then
			return true
		end
	end

	return false
end


function isPipe( shapeUuid )

	local pipeList = {}
	pipeList[#pipeList+1] = sm.uuid.new( "9dd5ee9c-aa5c-4bec-8fc2-a67999697085") --PipeStraight
	pipeList[#pipeList+1] = sm.uuid.new( "7f658dcd-e31d-4890-b4a7-4cd5e1378eaf") --PipeBend
	pipeList[#pipeList+1] = sm.uuid.new( "339dc807-099c-449f-bc4b-ecad92e9908d") --PneumaticPump
	pipeList[#pipeList+1] = sm.uuid.new( "28f536f2-f812-4bd4-821f-483a76f55de3") --PipeMerger

	for i, pipeUuid in ipairs(pipeList) do
		if shapeUuid == pipeUuid then
			return true
		end
	end

	return false

end

function getCell( x, y )
	return math.floor( x / 64 ), math.floor( y / 64 )
end

-- Allows to iterate a table of form [key, value, key, value, key, value]
function kvpairs(t)
	local i = 1
	local n = #t
	return function ()
		if i < n then
			local a = t[i]
			local b = t[i + 1]
			i = i + 2
			return a, b
		end
	end
end

function reverse_ipairs( a )
	function iter( a, i )
		i = i - 1
		local v = a[i]
		if v then
			return i, v
		end
	end
	return iter, a, #a + 1
end

function shuffle( array, first, last )
	first = first or 1
	last = last or #array
	for i = last, 1 + first, -1 do
		local j = math.random( first, i )
		array[i], array[j] = array[j], array[i]
	end
	return array
end

function reverse( array )
	local i, j = 1, #array
	while i < j do
		array[i], array[j] = array[j], array[i]
		i = i + 1
		j = j - 1
	end
end

function shallowcopy( orig )
	local orig_type = type( orig )
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in pairs( orig ) do
			copy[orig_key] = orig_value
		end
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

function closestPointOnLineSegment( line0, line1, point )
	local vec = line1 - line0
	local len = vec:length()
	local dist = ( vec / len ):dot( point - line0 )
	local t = sm.util.clamp( dist / len, 0, 1 )
	return line0 + vec * t, t, len
end

function closestPointInLines( linePoints, point )
	local closest
	if #linePoints > 1 then
		local closestDistance2 = math.huge
		for i = 1, #linePoints - 1 do
			local pt, t, len = closestPointOnLineSegment( linePoints[i], linePoints[i + 1], point )
			local distance2 = ( pt - point ):length2()
			if distance2 < closestDistance2 then
				closest = { i = i, pt = pt, t = t, len = len }
				closestDistance2 = distance2
			end
		end
	elseif #linePoints == 1 then
		closest = { i = 1, pt = linePoints[1], t = 0, len = 1 }
	end
	return closest
end

function closestPointInLinesSkipFirst( linePoints, point )
	local closest
	if #linePoints > 1 then
		local closestDistance2 = math.huge
		for i = 2, #linePoints - 1 do
			local pt, t, len = closestPointOnLineSegment( linePoints[i], linePoints[i + 1], point )
			local distance2 = ( pt - point ):length2()
			if distance2 < closestDistance2 then
				closest = { i = i, pt = pt, t = t, len = len }
				closestDistance2 = distance2
			end
		end
	elseif #linePoints == 1 then
		closest = { i = 1, pt = linePoints[1], t = 0, len = 1 }
	end
	return closest
end


function lengthOfLines( linePoints )
	local lines = {}
	local totalLength = 0
	if #linePoints > 1 then
		for i = 1, #linePoints - 1 do
			lines[i] = {}
			lines[i].p0 = linePoints[i]
			lines[i].p1 = linePoints[i+1]
			lines[i].length = ( lines[i].p1 - lines[i].p0 ):length()
			totalLength = totalLength + lines[i].length
		end
	end
	return totalLength, lines
end

function closestFractionInLines( linePoints, point )
	if #linePoints > 1 then
		local closest = closestPointInLines( linePoints, point )
		return ( ( closest.i - 1 ) + closest.t ) / #linePoints
	elseif #linePoints == 1 then
		return 1.0
	end
end

function pointInLines( linePoints, fraction )
	local totalLength, lines = lengthOfLines( linePoints )

	if totalLength == 0 then
		return linePoints[1]
	end

	local point
	for i = 1, #lines do
		lines[i].minFraction = 0.0
		lines[i].maxFraction = lines[i].length / totalLength
		if lines[i-1] then
			lines[i].minFraction = lines[i].minFraction + lines[i-1].maxFraction
			lines[i].maxFraction = lines[i].maxFraction + lines[i-1].maxFraction
		end
		if i == #lines then
			lines[i].maxFraction = 1.0
		end

		if fraction >= lines[i].minFraction and fraction <= lines[i].maxFraction then
			local f = ( fraction - lines[i].minFraction ) / ( lines[i].maxFraction - lines[i].minFraction )
			point = sm.vec3.lerp( lines[i].p0, lines[i].p1, f )
			break
		end
	end

	return point
end

-- p = progress from first point (1) to last point (#points)
function spline( points, p, distances )
	assert( #points > 1, "Must have at least 2 points" )
	local i0 = math.floor( p )
	if i0 < 1 then
		i0 = 1
		p = 1
	elseif i0 >= #points then
		i0 = #points - 1
		p = #points
	end

	local u
	local ui
	if distances then
		local invDistance = 1 / distances[#distances]
		u = ( ( p - i0 ) * ( distances[i0 + 1] - distances[i0] ) + distances[i0] ) * invDistance
		ui = function( o )
			local i = i0 + o
			if i < 1 then i = 1 end
			if i > #distances then i = #distances end
			return distances[i] * invDistance
		end
	else
		u = p
		ui = function( o ) return i0 + o end
	end

	local pt1_0 = points[math.max( i0 - 1, 1 )]
	local pt2_0 = points[i0]
	local pt3_0 = points[i0 + 1]
	local pt4_0 = points[math.min( i0 + 2, #points )]

	local t = ( u - ui(-2 ) ) / ( ui( 1 ) - ui(-2 ) )
	local pt1_1 = sm.vec3.lerp( pt1_0, pt2_0, finite( t ) and t or 0.0 )
	t = ( u - ui(-1 ) ) / ( ui( 2 ) - ui(-1 ) )
	local pt2_1 = sm.vec3.lerp( pt2_0, pt3_0, finite( t ) and t or 0.0 )
	t = ( u - ui( 0 ) ) / ( ui( 3 ) - ui( 0 ) )
	local pt3_1 = sm.vec3.lerp( pt3_0, pt4_0, finite( t ) and t or 0.0 )

	t = ( u - ui(-1 ) ) / ( ui( 1 ) - ui(-1 ) )
	local pt1_2 = sm.vec3.lerp( pt1_1, pt2_1, finite( t ) and t or 0.0 )
	t = ( u - ui( 0 ) ) / ( ui( 2 ) - ui( 0 ) )
	local pt2_2 = sm.vec3.lerp( pt2_1, pt3_1, finite( t ) and t or 0.0 )

	t = ( u - ui( 0 ) ) / ( ui( 1 ) - ui( 0 ) )
	local pt1_3 = sm.vec3.lerp( pt1_2, pt2_2, finite( t ) and t or 0.0 )

	return pt1_3, pt1_2, pt2_2, pt1_1, pt2_1, pt3_1
end

function getClosestShape( body, position )
	local closestShape = nil
	local closestDistance = math.huge
	local shapes = body:getShapes()
	for _, shape in ipairs( shapes ) do
		local distance = ( shape.worldPosition - position ):length()
		if closestShape then
			if distance < closestDistance then
				closestShape = shape
				closestDistance = distance
			end
		else
			closestShape = shape
			closestDistance = distance
		end
	end

	return closestShape
end

function EstimateBezierLength( points, samples )
	samples = samples and samples or 32
	samples = math.min( samples, 64 )
	if #points == 0 or samples < 2 then
		return 0
	end

	local step = 1.0 / ( samples - 1 )
	local latestPosition = points[1]
	local length = 0.0
	for i = 2, samples do
		local position = BezierPosition( points, step * i )
		length = length + ( latestPosition - position ):length()
		latestPosition = position
	end

	return length
end

local function bezierPositionRecursive( points, p, startIndex, endIndex )
	if startIndex == endIndex then
		return points[startIndex]
	end

	local p1 = bezierPositionRecursive( points, p, startIndex, endIndex - 1 )
	local p2 = bezierPositionRecursive( points, p, startIndex + 1, endIndex )
	return sm.vec3.lerp( p1, p2, p )
end

function BezierPosition( points, p )
	if #points == 0 then
		return sm.vec3.zero()
	elseif #points == 1 then
		return points[#points]
	end
	
	local p1 = bezierPositionRecursive( points, p, 1, #points - 1 )
	local p2 = bezierPositionRecursive( points, p, 2, #points )

	return sm.vec3.lerp( p1, p2, p )
end

local function bezierRotationRecursive( rotations, p, startIndex, endIndex )
	if startIndex == endIndex then
		return rotations[startIndex]
	end

	local q1 = bezierRotationRecursive( rotations, p, startIndex, endIndex - 1 )
	local q2 = bezierRotationRecursive( rotations, p, startIndex + 1, endIndex )
	return sm.quat.slerp( q1, q2, p )
end

function BezierRotation( rotations, p )
	if #rotations == 0 then
		return sm.quat.identity()
	elseif #rotations == 1 then
		return rotations[#rotations]
	end

	local q1 = bezierRotationRecursive( rotations, p, 1, #rotations - 1 )
	local q2 = bezierRotationRecursive( rotations, p, 2, #rotations )
	return sm.quat.slerp( q1, q2, p )
end

function lerpDirection( fromDirection, toDirection, p )
	local cameraHeading = math.atan2( -fromDirection.x, fromDirection.y )
	local cameraPitch = math.asin( fromDirection.z )

	local cameraDesiredHeading = math.atan2( -toDirection.x, toDirection.y )
	local cameraDesiredPitch = math.asin( toDirection.z )

	local shortestAngle = ( ( ( cameraDesiredHeading - cameraHeading ) % ( 2 * math.pi ) + 3 * math.pi ) % ( 2 * math.pi ) ) - math.pi
	cameraDesiredHeading = cameraHeading + shortestAngle

	cameraHeading = sm.util.lerp( cameraHeading, cameraDesiredHeading, p )
	cameraPitch = sm.util.lerp( cameraPitch, cameraDesiredPitch, p )

	local newCameraDirection = sm.vec3.new( 0, 1, 0 )
	newCameraDirection = newCameraDirection:rotateX( cameraPitch )
	newCameraDirection = newCameraDirection:rotateZ( cameraHeading )

	return newCameraDirection
end

function magicDirectionInterpolation( currentDirection, desiredDirection, dt, speed )
	-- Smooth heading and pitch movement
	local speed = speed or ( 1.0 / 6.0 )
	local blend = 1 - math.pow( 1 - speed, dt * 60 )
	return lerpDirection( currentDirection, desiredDirection, blend )
end

function magicPositionInterpolation( currentPosition, desiredPosition, dt, speed )
	local speed = speed or ( 1.0 / 6.0 )
	local blend = 1 - math.pow( 1 - speed, dt * 60 )
	return sm.vec3.lerp( currentPosition, desiredPosition, blend )
end

function magicInterpolation( currentValue, desiredValue, dt, speed )
	local speed = speed or ( 1.0 / 6.0 )
	local blend = 1 - math.pow( 1 - speed, dt * 60 )
	return sm.util.lerp( currentValue, desiredValue, blend )
end

function TriangleCurve( p )
	local res = math.max( math.min( p, 1.0 ), 0.0 )
	return 1.0 - math.abs( res * 2 - 1.0 )
end

function isDangerousCollisionShape( shapeUuid )
	return isAnyOf( shapeUuid, { obj_powertools_drill, obj_powertools_sawblade } )
end

function isSafeCollisionShape( shapeUuid )
	return isAnyOf( shapeUuid, { obj_scrap_smallwheel, obj_vehicle_smallwheel, obj_vehicle_bigwheel, obj_spaceship_cranewheel } )
end

function isTrapProjectile( projectileUuid )
	local TrapProjectiles = { projectile_tape, projectile_explosivetape }
	return isAnyOf( projectileUuid, TrapProjectiles )
end








function isIgnoreCollisionShape( shapeUuid )
	return isAnyOf( shapeUuid, {
		obj_harvest_metal,

		obj_robotparts_tapebothead01,
		obj_robotparts_tapebottorso01,
		obj_robotparts_tapebotleftarm01,
		obj_robotparts_tapebotshooter,

		obj_robotparts_haybothead,
		obj_robotparts_haybotbody,
		obj_robotparts_haybotfork,

		obj_robotpart_totebotbody,
		obj_robotpart_totebotleg,

		obj_robotparts_farmbotpart_head,
		obj_robotparts_farmbotpart_cannonarm,
		obj_robotparts_farmbotpart_drill,
		obj_robotparts_farmbotpart_scytharm
	} )
end

function getTimeOfDayString()
	local timeOfDay = sm.game.getTimeOfDay()
	local hour = ( timeOfDay * 24 ) % 24
	local minute = ( hour % 1 ) * 60
	local hour1 = math.floor( hour / 10 )
	local hour2 = math.floor( hour - hour1 * 10 )
	local minute1 = math.floor( minute / 10 )
	local minute2 = math.floor( minute - minute1 * 10 )

	return hour1..hour2..":"..minute1..minute2
end

function formatCountdown( seconds )
	local time = seconds / DAYCYCLE_TIME
	local days = math.floor(( time * 24 ) / 24)
	local hour = ( time * 24 ) % 24
	local minute = ( hour % 1 ) * 60
	local hour1 = math.floor( hour / 10 )
	local hour2 = math.floor( hour - hour1 * 10 )
	local minute1 = math.floor( minute / 10 )
	local minute2 = math.floor( minute - minute1 * 10 )

	return days.."d "..hour1..hour2.."h "..minute1..minute2.."m"
end

function getDayCycleFraction()

	local time = sm.game.getTimeOfDay()

	local index = 1
	while index < #DAYCYCLE_SOUND_TIMES and time >= DAYCYCLE_SOUND_TIMES[index + 1] do
		index = index + 1
	end
	assert( index <= #DAYCYCLE_SOUND_TIMES )

	local night = 0.0
	if index < #DAYCYCLE_SOUND_TIMES then
		local p = ( time - DAYCYCLE_SOUND_TIMES[index] ) / ( DAYCYCLE_SOUND_TIMES[index + 1] - DAYCYCLE_SOUND_TIMES[index] )
		night = sm.util.lerp( DAYCYCLE_SOUND_VALUES[index], DAYCYCLE_SOUND_VALUES[index + 1], p )
	else
		night = DAYCYCLE_SOUND_VALUES[index]
	end

	return 1.0 - night
end

function getTicksUntilDayCycleFraction( dayCycleFraction )
	local time = sm.game.getTimeOfDay()
	local timeDiff = ( time > dayCycleFraction ) and ( dayCycleFraction - time ) + 1.0 or ( dayCycleFraction - time )
	return math.floor( timeDiff * DAYCYCLE_TIME * 40 + 0.5 )
end

-- Brute force testing of a function for randomizing integer ranges
function testRandomFunction( fn )
	local a = {}
	local sum = 0
	for i = 1,1000000 do
		local n = fn()
		a[n] = a[n] and a[n] + 1 or 1
		sum = sum + n
	end

	for n,v in pairs( a ) do
		print( n, "=", (v / 10000).."%" )
	end
	print( "avg =", sum / 1000000 )
end

function randomStackAmount( min, mean, max )
	return clamp( round( sm.noise.randomNormalDistribution( mean, ( max - min + 1 ) * 0.25 ) ), min, max )
end

function randomStackAmount2()
	return randomStackAmount( 1, 1, 2 )
end

function randomStackAmountAvg2()
	return randomStackAmount( 1, 2, 3 )
end

function randomStackAmountAvg3()
	return randomStackAmount( 2, 3, 4 )
end

function randomStackAmount5()
	return randomStackAmount( 2, 3.5, 5 )
end

function randomStackAmountAvg5()
	return randomStackAmount( 3, 5, 7 )
end

function randomStackAmount10()
	return randomStackAmount( 5, 7.5, 10 )
end

function randomStackAmountAvg10()
	return randomStackAmount( 5, 10, 15 )
end

function randomStackAmount20()
	return randomStackAmount( 10, 15, 20 )
end

function GetOwnerPosition( tool )
	local playerPosition = sm.vec3.new( 0, 0, 0 )
	local player = tool:getOwner()
	if player and player.character and sm.exists( player.character ) then
		playerPosition = player.character.worldPosition
	end
	return playerPosition
end

function CharacterCollision( self, other, vCollisionPosition, vPointVelocitySelf, vPointVelocityOther, vCollisionNormal, maxhp, velDiffThreshold )
	assert( type( self ) == "Character" )
	
	if type( other ) == "Character" then
		return 0, 0, sm.vec3.zero(), sm.vec3.zero()
	end

	if type( other ) == "Shape" and not sm.exists( other ) then
		return 0, 0, sm.vec3.zero(), sm.vec3.zero()
	end

	if type( other ) == "Shape" and sm.exists( other ) then
		if isIgnoreCollisionShape( other:getShapeUuid() ) then
			return 0, 0, sm.vec3.zero(), sm.vec3.zero()
		end
	end

	--print( "------ COLLISION", type( other ), "------" )

	local vVelImpact = ( vPointVelocitySelf - vPointVelocityOther )
	local fVelImpact = vVelImpact:length()
	local vDirImpact = vVelImpact / fVelImpact
	local fCosImpactAngle = vDirImpact:dot( -vCollisionNormal )

	local vTumbleVelocity = sm.vec3.zero()
	local vImpactReaction = sm.vec3.zero()

	local fallDamage = 0
	local collisionDamage = 0
	local specialCollisionDamage = 0
	local fallTumbleTicks = 0
	local collisionTumbleTicks = 0
	local specialCollision = false

	-- Fall damage
	local fFallMinVelocity = 18
	local fFallMaxVelocity = 36
	local fFallImpact = math.min( -vVelImpact.z, -vPointVelocitySelf.z ) * fCosImpactAngle
	local fFallDamageFraction = clamp( ( fFallImpact - fFallMinVelocity ) / ( fFallMaxVelocity - fFallMinVelocity ), 0.0, 1.0 )
	if fFallDamageFraction > 0.5 then
		fallTumbleTicks = MEDIUM_TUMBLE_TICK_TIME
	end
	if self:isOnGround() then
		-- No fall damage if character is already touching the ground
		fFallDamageFraction = 0
		fallTumbleTicks = 0
	end
	fallDamage = fFallDamageFraction * ( maxhp or 100 )


	local isSafeShape = false
	if type( other ) == "Shape" then

		-- Special damage
		if isDangerousCollisionShape( other:getShapeUuid() ) then
			if other.body.angularVelocity:length() > SPINNER_ANGULAR_THRESHOLD then
				specialCollisionDamage = 10
				specialCollision = true
			end
		end

		isSafeShape = isSafeCollisionShape( other:getShapeUuid() )
	end


	-- Collision damage
	if not isSafeShape then
		local massSelf = self.mass
		local massOther = 0
		if type( other ) == "Shape" and other.body:isDynamic() then
			massOther = other.body.mass
		end

		if fCosImpactAngle > 0.5 then -- At least 30 degree impact angle
			local fVel0Self = vPointVelocitySelf:dot( vDirImpact )
			local fVel0Other = vPointVelocityOther:dot( vDirImpact )

			local fVel1Self
			local fVel1Other
			
			local fRestitution = 0.3
			local fFriction = 0.3

			if massOther > 0 then
				fVel1Self = ( fRestitution * massOther * ( fVel0Other - fVel0Self ) + massSelf * fVel0Self + massOther * fVel0Other ) / ( massSelf + massOther )
				fVel1Other = ( fRestitution * massSelf * ( fVel0Self - fVel0Other ) + massSelf * fVel0Self + massOther * fVel0Other ) / ( massSelf + massOther )
			else
				-- Simplified with massSelf as 0, massOther as 1
				fVel1Self = fRestitution * ( fVel0Other - fVel0Self ) + fVel0Other
				fVel1Other = fVel0Other
			end

			-- Damage is based on the change in velocity from collision
			local fVelDiffSelf = ( fVel1Self - fVel0Self )
			local fVelDiffOther = ( fVel1Other - fVel0Other )
			
			if fVelDiffSelf <= -( velDiffThreshold or 12 ) then
				collisionDamage = round( 0.1885715 * ( -fVelDiffSelf )^1.464069 )
				if fVelDiffSelf <= -80 then
					collisionTumbleTicks = LARGE_TUMBLE_TICK_TIME
				elseif fVelDiffSelf <= -48 then
					collisionTumbleTicks = MEDIUM_TUMBLE_TICK_TIME
				else
					collisionTumbleTicks = SMALL_TUMBLE_TICK_TIME
				end

				-- Tumble body created with zero velocity
				if vDirImpact:dot( vCollisionNormal ) > -0.99802673 then -- 4 degrees
					local vTangent = vDirImpact:cross( vCollisionNormal )
					vTangent = ( vTangent:cross( vCollisionNormal ) ):normalize()
					vTumbleVelocity = ( vCollisionNormal * vDirImpact:dot( vCollisionNormal ) - vTangent * vDirImpact:dot( vTangent ) * fFriction ) * fVel1Self
					--sm.debugDraw.addArrow( "vTangent", vCollisionPosition, vCollisionPosition + vTangent, BLUE )
				else
					vTumbleVelocity = vDirImpact * fVel1Self
					--sm.debugDraw.removeArrow( "vTangent" )
				end

				-- Value to slow down whatever hit the character
				vImpactReaction = vDirImpact * fVelDiffOther

				--sm.debugDraw.addArrow( "vCollisionNormal", vCollisionPosition, vCollisionPosition + vCollisionNormal, GREEN )
				--sm.debugDraw.addArrow( "vDirImpact", vCollisionPosition, vCollisionPosition + vDirImpact, RED )
				
				--sm.debugDraw.addArrow( "vVelImpact", vCollisionPosition - vVelImpact, vCollisionPosition, WHITE )
				--sm.debugDraw.addArrow( "vTumbleVelocity", vCollisionPosition, vCollisionPosition + vTumbleVelocity, CYAN )
				--sm.debugDraw.addArrow( "vImpactReaction", vCollisionPosition, vCollisionPosition + vImpactReaction, MAGENTA )
			end
		end
	end

	local damage = fallDamage > 0 and fallDamage or math.max( collisionDamage, specialCollisionDamage )
	local tumbleTicks = specialCollision and 0 or math.max( fallTumbleTicks, collisionTumbleTicks )

	return damage, tumbleTicks, vTumbleVelocity, vImpactReaction
end

function ApplyCharacterImpulse( targetCharacter, direction, power )
	local impulseDirection = direction:safeNormalize( sm.vec3.zero() )
	if impulseDirection:length2() >= FLT_EPSILON * FLT_EPSILON then
		local massImpulse = power / ( 5000.0 / 10.0 )
		local massImpulseSqrt = power / ( 5000.0 / 12.0 )
		local impulse = math.min( targetCharacter.mass * massImpulse + math.sqrt( targetCharacter.mass ) * massImpulseSqrt, power )
		impulse = math.min( impulse, MAX_CHARACTER_KNOCKBACK_VELOCITY * targetCharacter.mass )

		if targetCharacter:isTumbling() then
			targetCharacter:applyTumblingImpulse( impulseDirection * impulse )
		else
			sm.physics.applyImpulse( targetCharacter, impulseDirection * impulse )
		end
	end
end

function ApplyKnockback( targetCharacter, direction, power )

	local impulseDirection = sm.vec3.new( direction.x, direction.y, 0 ):safeNormalize( sm.vec3.zero() )
	if impulseDirection:length2() >= FLT_EPSILON * FLT_EPSILON then
		local rightVector =  impulseDirection:cross( sm.vec3.new( 0, 0, 1 ) )
		impulseDirection = impulseDirection:rotate( 0.523598776, rightVector ) -- 30 degrees
	end

	ApplyCharacterImpulse( targetCharacter, impulseDirection, power )
end

function GetClosestPlayer( worldPosition, maxDistance, world )
	local closestPlayer = nil
	local closestDd = maxDistance and ( maxDistance * maxDistance ) or math.huge
	local players = sm.player.getAllPlayers()
	for _, player in ipairs( players ) do
		if player.character and player.character:getWorld() == world then
			local dd = ( player.character.worldPosition - worldPosition ):length2()
			if dd <= closestDd then
				closestPlayer = player
				closestDd = dd
			end
		end
	end
	return closestPlayer
end

local ToolItems = {
	[tostring( tool_connect )] = obj_tool_connect,
	[tostring( tool_paint )] = obj_tool_paint,
	[tostring( tool_weld )] = obj_tool_weld,
	[tostring( tool_spudgun )] = obj_tool_spudgun,
	[tostring( tool_shotgun )] = obj_tool_frier,
	[tostring( tool_gatling )] = obj_tool_spudling
}
function GetToolProxyItem( toolUuid )
	return ToolItems[tostring( toolUuid )]
end

function FindFirstInteractable( uuid )
	local bodies = sm.body.getAllBodies()
	for _, body in ipairs( bodies ) do
		for _, shape in ipairs( body:getShapes() ) do
			if tostring( shape:getShapeUuid() ) == uuid then
				return shape:getInteractable()
			end
		end
	end	
end

function FindFirstInteractableWithinCell( uuid, x, y )
	local bodies = sm.body.getAllBodies()
	for _, body in ipairs( bodies ) do
		for _, shape in ipairs( body:getShapes() ) do
			if tostring( shape:getShapeUuid() ) == uuid then
				local ix, iy = getCell( shape:getWorldPosition().x, shape:getWorldPosition().y )
				if ix == x and iy == y then
					return shape:getInteractable()
				end
			end
		end
	end	
end

function FindInteractablesWithinCell( uuid, x, y )
	local tbl = {}
	local bodies = sm.body.getAllBodies()
	for _, body in ipairs( bodies ) do
		for _, shape in ipairs( body:getShapes() ) do
			if tostring( shape:getShapeUuid() ) == uuid then
				local ix, iy = getCell( shape:getWorldPosition().x, shape:getWorldPosition().y )
				if ix == x and iy == y then
					table.insert( tbl, shape:getInteractable() )
				end
			end
		end
	end
	return tbl	
end

function ConstructionRayCast( constructionFilters )

	local valid, result = sm.localPlayer.getRaycast( 7.5 )
	if valid then
		for _, filter in ipairs( constructionFilters ) do
			if result.type == filter then

				local groundPointOffset = -( sm.construction.constants.subdivideRatio_2 - 0.04 + sm.construction.constants.shapeSpacing + 0.005 )
				local pointLocal = result.pointLocal + result.normalLocal * groundPointOffset

				-- Compute grid pos
				local size = sm.vec3.new( 3, 3, 1 )
				local size_2 = sm.vec3.new( 1, 1, 0 )
				local a = pointLocal * sm.construction.constants.subdivisions
				local gridPos = sm.vec3.new( math.floor( a.x ), math.floor( a.y ), a.z ) - size_2

				-- Compute world pos
				local worldPos = gridPos * sm.construction.constants.subdivideRatio + ( size * sm.construction.constants.subdivideRatio ) * 0.5

				return valid, worldPos, result.normalWorld
			end
		end
	end
	return false, nil, nil
end

local function getWorld( userdataObject )
	if userdataObject and isAnyOf( type( userdataObject ), { "Character", "Body", "Harvestable", "Player", "Unit", "Shape", "Interactable", "Joint", "World" } ) then
		if sm.exists( userdataObject ) then
			if type( userdataObject ) == "Character" or type( userdataObject ) == "Body" or type( userdataObject ) == "Harvestable" then
				return userdataObject:getWorld()
			elseif type( userdataObject ) == "Player" or type( userdataObject ) == "Unit" then
				if userdataObject.character then
					return userdataObject.character:getWorld()
				end
			elseif type( userdataObject ) == "Shape" or type( userdataObject ) == "Interactable" then
				if userdataObject.body then
					return userdataObject.body:getWorld()
				end
			elseif type( userdataObject ) == "Joint" then
				local hostShape = userdataObject:getShapeA()
				if hostShape and hostShape.body then
					return hostShape.body:getWorld()
				end
			elseif type( userdataObject ) == "World" then
				return userdataObject
			end
			return nil
		else
			return nil
		end
	end
	sm.log.warning( "Tried to get world for an unsupported type: "..type( userdataObject ) )
	return nil
end

function InSameWorld( userdataObjectA, userdataObjectB )
	local worldA = getWorld( userdataObjectA )
	local worldB = getWorld( userdataObjectB )

	local result = ( worldA ~= nil and worldB ~= nil and worldA == worldB )
	return result
end

function FindAttackableShape( worldPosition, radius, attackLevel )
	local nearbyShapes = sm.shape.shapesInSphere( worldPosition, radius )
	local destructableNearbyShapes = {}
	for _, shape in ipairs( nearbyShapes )do
		local shapeQualityLevel = sm.item.getQualityLevel( shape.shapeUuid )
		if shape.destructable and attackLevel >= shapeQualityLevel and shapeQualityLevel > 0 then
			destructableNearbyShapes[#destructableNearbyShapes+1] = shape
		end
	end
	if #destructableNearbyShapes > 0 then
		local targetShape = destructableNearbyShapes[math.random( 1, #destructableNearbyShapes )]
		local targetPosition = targetShape.worldPosition
		if sm.item.isBlock( targetShape.shapeUuid ) then
			local targetLocalPosition = targetShape:getClosestBlockLocalPosition( worldPosition )
			targetPosition = targetShape.body:transformPoint( ( targetLocalPosition + sm.vec3.new( 0.5, 0.5, 0.5 ) ) * 0.25 )
		end
		return targetShape, targetPosition
	end
	return nil, nil
end

function BinarySearchInterval( array, targetValue )
	local lowerBound = 1
	local upperBound = #array
	if targetValue < array[lowerBound] then
		return lowerBound -- Clamp to lower index
	elseif targetValue > array[upperBound] then
		return upperBound -- Clamp to upper index
	end
	
	while lowerBound <= upperBound do
		local middleIndex = math.floor( ( lowerBound + upperBound ) * 0.5 )
		if array[middleIndex] < targetValue then
			lowerBound = middleIndex + 1
		elseif array[middleIndex] > targetValue then
			upperBound = middleIndex - 1
		else
			return middleIndex -- Found exact value
		end
	end
	return upperBound -- No exact value, return the interval index
end

function RotateAxis( vector, xAxis, zAxis, inverse )
	local yAxis = zAxis:cross( xAxis )
	if inverse then
		-- Transpose rotation matrix
		return sm.vec3.new(
			vector.x * xAxis.x + vector.y * xAxis.y + vector.z * xAxis.z,
			vector.x * yAxis.x + vector.y * yAxis.y + vector.z * yAxis.z,
			vector.x * zAxis.x + vector.y * zAxis.y + vector.z * zAxis.z
		)
	end
	return sm.vec3.new(
		vector.x * xAxis.x + vector.y * yAxis.x + vector.z * zAxis.x,
		vector.x * xAxis.y + vector.y * yAxis.y + vector.z * zAxis.y,
		vector.x * xAxis.z + vector.y * yAxis.z + vector.z * zAxis.z
	)
end

function RotateSticky( minSticky, maxSticky, xAxis, zAxis, inverse )
	local minFlags = RotateAxis( minSticky, xAxis, zAxis, inverse )
	local maxFlags = RotateAxis( maxSticky, xAxis, zAxis, inverse )

	local NX = ( minFlags.x > 0 or maxFlags.x < 0 ) and 1 or 0
	local NY = ( minFlags.y > 0 or maxFlags.y < 0 ) and 1 or 0
	local NZ = ( minFlags.z > 0 or maxFlags.z < 0 ) and 1 or 0
	local PX = ( maxFlags.x > 0 or minFlags.x < 0 ) and 1 or 0
	local PY = ( maxFlags.y > 0 or minFlags.y < 0 ) and 1 or 0
	local PZ = ( maxFlags.z > 0 or minFlags.z < 0 ) and 1 or 0

	local rotatedMinSticky = sm.vec3.new( NX, NY, NZ )
	local rotatedMaxSticky = sm.vec3.new( PX, PY, PZ )
	return rotatedMinSticky, rotatedMaxSticky
end

local EasyDifficultySettings =
{
	playerTakeDamageMultiplier = 0.5
}
local NormalDifficultySettings =
{
	playerTakeDamageMultiplier = 1.0
}
function GetDifficultySettings()
	local difficulties = { EasyDifficultySettings, NormalDifficultySettings }
	local difficultyIndex = sm.game.getDifficulty()
	if difficultyIndex < 0 then
		difficultyIndex = 2 -- Default to Normal difficulty
	else
		difficultyIndex = difficultyIndex + 1 -- Lua index
	end
	return difficulties[difficultyIndex]
end

function SpawnDebris( character, bone, debrisEffect, offsetPos, offsetRot )
	local bonePos = character:getTpBonePos( bone )
	local boneRot = character:getTpBoneRot( bone )

	local position = offsetPos and bonePos + boneRot * offsetPos or bonePos
	local rotation = offsetRot and boneRot * offsetRot or boneRot

	local relPos = position - character.worldPosition

	local velocity = relPos:safeNormalize( sm.vec3.new( 0, 0, 1 ) ) * ( math.random() + 1 ) * 2 + sm.vec3.new( 0, 0, math.random() + 2 ) + character.velocity
	local color = character:getColor()

	sm.effect.playEffect( debrisEffect, position, velocity, rotation, nil, { Color = color, startVelocity = velocity } )
end