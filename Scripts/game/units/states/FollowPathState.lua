dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"

FollowPathState = class( nil )

-- State specific functions

function FollowPathState.sv_onCreate( self, unit, debugPrefix )
	self.unit = unit
	self.debugPrefix = debugPrefix or ""
	self.followDirectionState = unit:createState( "followDirection" )
	self.movementType = "walk"
	self.tolerance = 1.0
	self.followDirectionState.movementType = self.movementType
	self.followDirectionState.maxDeviation = 15 * math.pi / 180
	self.followDirectionState.avoidance = true
end

function FollowPathState.sv_onDestroy( self )
	self:sv_debugDrawCleanup()
end

function FollowPathState.sv_setMovementType( self, movementType )
	self.movementType = movementType
end

function FollowPathState.sv_setPath( self, path )
	self.path = path
	--print( "FollowPathState follows path with", #self.path, "nodes" )

	if self.path and #self.path > 1 then
		-- Used for spline calculation
		self.distances = {}
		self.distances[1] = 0
		for i = 2,#self.path do
			self.distances[i] = self.distances[i - 1] + ( self.path[i] - self.path[i - 1] ):length()
		end
		return true
	end
	return false
end

-- AiState common interface

function FollowPathState.start( self )
	if not self.path or #self.path < 2 then
		print( "FollowPathState ("..self.debugPrefix..") for unit", self.unit.id, "does not have enough nodes to start" )
		return
	end

	local closest = closestPointInLines( self.path, self.unit.character.worldPosition )

	self.targetPosition = closest.pt
	self.segmentLength = closest.len
	self.timeInSegment = 0 --TODO: Take distance to first node into account
	self.progress = closest.i + closest.t
	self.checkSharpTurn = true
	self:sv_updateProgress( self.unit.character:getCurrentMovementSpeed() * 0.125 )
	--self:sv_debugDrawPath()

	self.followDirectionState.desiredDirection = self.unit:getCurrentMovementDirection()
	self.followDirectionState:start()

	self.started = true
	--print( "FollowPathState started" )
end

function FollowPathState.stop( self )
	--print( "FollowPathState stopped" )
	self.started = false

	self.followDirectionState:stop()

	self:sv_debugDrawCleanup()
	self.targetPosition = nil
	self.segmentLength = nil
	self.timeInSegment = nil
	self.progress = nil
	self.checkSharpTurn = nil
	self.done = nil
end

function FollowPathState.onFixedUpdate( self, timeStep )
	if not self.started then return end

	if ( self.targetPosition - self.unit.character.worldPosition ):length2() >= FLT_EPSILON * FLT_EPSILON then
		local fromToTarget = self.targetPosition - self.unit.character.worldPosition
		local flatFromToTarget = sm.vec3.new( fromToTarget.x, fromToTarget.y, 0.0 )
		local desiredDirection = self.unit:getCurrentMovementDirection()
		if flatFromToTarget:length2() >= FLT_EPSILON * FLT_EPSILON then
			desiredDirection = flatFromToTarget:normalize()
		end
		self.followDirectionState.desiredDirection = desiredDirection
		
		if self.checkSharpTurn then
			--print( "New path segment started" )
			if self.unit:getCurrentMovementDirection():dot( self.followDirectionState.desiredDirection ) < 0.86602540378 then --cos(30deg)
				--print( "--Narrow turn!" )
				self.followDirectionState.movementType = "stand"
				self.followDirectionState.avoidance = false
			end
			self.checkSharpTurn = false
		else
			if self.unit:getCurrentMovementDirection():dot( self.followDirectionState.desiredDirection ) >= 0.86602540378 then --cos(30deg)
				self.followDirectionState.movementType = self.movementType
				self.followDirectionState.avoidance = true
			end
		end
	else
		self.followDirectionState.movementType = "stand"
		self.followDirectionState.avoidance = false
	end
	
	sm.debugDraw.addArrow( self.debugPrefix.."fps_"..self.unit.id.."_dir", self.unit.character.worldPosition, self.targetPosition, sm.color.new( "ff0080" ) )
	sm.debugDraw.addSphere( self.debugPrefix.."fps_"..self.unit.id.."_pos", self.targetPosition, 0.5, sm.color.new( "ff0080" ) )


	-- Spline
	sm.debugDraw.removeSphere( self.debugPrefix.."fps_"..self.unit.id.."_p1_1" )
	sm.debugDraw.removeSphere( self.debugPrefix.."fps_"..self.unit.id.."_p2_1" )
	sm.debugDraw.removeSphere( self.debugPrefix.."fps_"..self.unit.id.."_p3_1" )
	sm.debugDraw.removeArrow( self.debugPrefix.."fps_"..self.unit.id.."_p1_1-p2_1" )
	sm.debugDraw.removeArrow( self.debugPrefix.."fps_"..self.unit.id.."_p2_1-p3_1" )

	sm.debugDraw.removeSphere( self.debugPrefix.."fps_"..self.unit.id.."_p1_2" )
	sm.debugDraw.removeSphere( self.debugPrefix.."fps_"..self.unit.id.."_p2_2" )
	sm.debugDraw.removeArrow( self.debugPrefix.."fps_"..self.unit.id.."_p1_2-p2_2" )

	sm.debugDraw.removeSphere( self.debugPrefix.."fps_"..self.unit.id.."_p1_3" )

	local pt1_3, pt1_2, pt2_2, pt1_1, pt2_1, pt3_1  = spline( self.path, self.progress, self.distances )

	sm.debugDraw.addSphere( self.debugPrefix.."fps_"..self.unit.id.."_p1_1", pt1_1, 0.1, sm.color.new( "ff0000" ) )
	sm.debugDraw.addSphere( self.debugPrefix.."fps_"..self.unit.id.."_p2_1", pt2_1, 0.1, sm.color.new( "00ff00" ) )
	sm.debugDraw.addSphere( self.debugPrefix.."fps_"..self.unit.id.."_p3_1", pt3_1, 0.1, sm.color.new( "0000ff" ) )
	sm.debugDraw.addArrow( self.debugPrefix.."fps_"..self.unit.id.."_p1_1-p2_1", pt1_1, pt2_1, sm.color.new( "ffff00" ) )
	sm.debugDraw.addArrow( self.debugPrefix.."fps_"..self.unit.id.."_p2_1-p3_1", pt2_1, pt3_1, sm.color.new( "00ffff" ) )

	sm.debugDraw.addSphere( self.debugPrefix.."fps_"..self.unit.id.."_p1_2", pt1_2, 0.1, sm.color.new( "ffff00" ) )
	sm.debugDraw.addSphere( self.debugPrefix.."fps_"..self.unit.id.."_p2_2", pt2_2, 0.1, sm.color.new( "00ffff" ) )
	sm.debugDraw.addArrow( self.debugPrefix.."fps_"..self.unit.id.."_p1_2-p2_2", pt1_2, pt2_2, sm.color.new( "ffffff" ) )

	sm.debugDraw.addSphere( self.debugPrefix.."fps_"..self.unit.id.."_p1_3", pt1_3, 0.2, sm.color.new( "ffffff" ) )


	self.followDirectionState:onFixedUpdate( timeStep )
end

function FollowPathState.onUnitUpdate( self, dt )
	if not self.started then return end

	-- Update progess
	local movementSpeed = self.unit.character:getCurrentMovementSpeed()
	self:sv_updateProgress( 2 * movementSpeed * dt )
	
	self.timeInSegment = self.timeInSegment + dt
	local expected = self.segmentLength / movementSpeed
	local max = expected * 2.0 + 1 --TWEAKABLE
	--print( "time in segment:", self.timeInSegment, "expected:", expected, "max:", max )

	if self.timeInSegment > max then
		--print( "Too slow! - Time in segment:", self.timeInSegment, "expected:", expected, "max:", max )
		--self.done = "failed"
	end
end

function FollowPathState.isDone( self )
	return self.done ~= nil, self.done
end

function FollowPathState.getMovementDirection( self )
	return self.followDirectionState:getMovementDirection()
end

function FollowPathState.getFacingDirection( self )
	return self.followDirectionState:getFacingDirection()
end

function FollowPathState.getMovementType( self )
	return self.followDirectionState:getMovementType()
end

-- Private

function FollowPathState.sv_updateProgress( self, stepLength )
	local closest = closestPointInLines( self.path, self.unit.character.worldPosition )
	if ( closest.pt - self.unit.character.worldPosition ):length2() <= self.tolerance * self.tolerance and closest.i + closest.t > self.progress then
		self:sv_debugText( "Found a shortcut!" )
		-- Force a step update
		self.targetPosition = closest.pt
		self.segmentLength = closest.len
		self.timeInSegment = 0
		self.progress = closest.i + closest.t
	end
	
	local fromToTarget = self.targetPosition - self.unit.character.worldPosition
	local flatFromToTarget = sm.vec3.new( fromToTarget.x, fromToTarget.y, 0.0 )
	if flatFromToTarget:length2() <= self.tolerance * self.tolerance then
		local step = stepLength / self.segmentLength

		if math.floor( self.progress + step ) ~= math.floor( self.progress ) then -- Next segment
			local i0 = math.floor( self.progress + step )
			local rest = ( self.progress + step - i0 ) * self.segmentLength

			if i0 < #self.path then
				local i1 = i0 + 1
				self.segmentLength = ( self.path[i1] - self.path[i0] ):length()
				self.timeInSegment = rest / self.unit.character:getCurrentMovementSpeed()
				self.progress = i0 + rest / self.segmentLength
				self.checkSharpTurn = true
				--self:sv_debugText( "started new segement: "..i1 )
				local offset = sm.vec3.new( 0, 0, 0.1 )
				sm.debugDraw.addArrow( self.debugPrefix.."fps_"..self.unit.id.."_seg", self.path[i0] + offset, self.path[i1] + offset, sm.color.new( "0080ff" ) )

			else -- Arrived
				self.segmentLength = 1
				self.timeInSegment = 0
				self.progress = i0
				self.done = "arrived"
			end
		else -- Standard progress
			self.progress = self.progress + step
		end

		-- Target position from progress
		local i0 = math.floor( self.progress )
		if i0 >= #self.path then
			self.targetPosition = self.path[#self.path]
		else
			local t = self.progress - i0
			self.targetPosition = sm.vec3.lerp( self.path[i0], self.path[i0 + 1], t )
		end
	end
end

function FollowPathState.sv_debugDrawPath( self )
	local offset = sm.vec3.new( 0, 0, 0.05 )
	local prevNode
	for i, node in ipairs( self.path ) do
		if prevNode then
			sm.debugDraw.addArrow( self.debugPrefix.."fps_"..self.unit.id.."_n"..( i - 1 ), prevNode + offset, node + offset, sm.color.new( "8000ff" ) )
		end
		prevNode = node
	end
	
	for p = 1, #self.path - 0.1, 0.1 do
		local pt0 = spline( self.path, p, self.distances )
		local pt1 = spline( self.path, p + 0.1, self.distances )
		sm.debugDraw.addArrow( self.debugPrefix.."fps_"..self.unit.id.."_p"..p, pt0, pt1, sm.color.new( "00ff80" ) )
	end
end

function FollowPathState.sv_debugDrawCleanup( self )
	sm.debugDraw.removeArrow( self.debugPrefix.."fps_"..self.unit.id.."_dir" )
	sm.debugDraw.removeSphere( self.debugPrefix.."fps_"..self.unit.id.."_pos" )
	sm.debugDraw.removeArrow( self.debugPrefix.."fps_"..self.unit.id.."_seg" )

	-- Path
	if self.path and #self.path > 1 then
		for i = 1, #self.path - 1 do
			sm.debugDraw.removeArrow( self.debugPrefix.."fps_"..self.unit.id.."_n"..i )
		end
	end
	
	if self.path then
		for p = 1, #self.path - 0.1, 0.1 do
			sm.debugDraw.removeArrow( self.debugPrefix.."fps_"..self.unit.id.."_p"..p )
		end
	end

	-- Spline
	sm.debugDraw.removeSphere( self.debugPrefix.."fps_"..self.unit.id.."_p1_1" )
	sm.debugDraw.removeSphere( self.debugPrefix.."fps_"..self.unit.id.."_p2_1" )
	sm.debugDraw.removeSphere( self.debugPrefix.."fps_"..self.unit.id.."_p3_1" )
	sm.debugDraw.removeArrow( self.debugPrefix.."fps_"..self.unit.id.."_p1_1-p2_1" )
	sm.debugDraw.removeArrow( self.debugPrefix.."fps_"..self.unit.id.."_p2_1-p3_1" )

	sm.debugDraw.removeSphere( self.debugPrefix.."fps_"..self.unit.id.."_p1_2" )
	sm.debugDraw.removeSphere( self.debugPrefix.."fps_"..self.unit.id.."_p2_2" )
	sm.debugDraw.removeArrow( self.debugPrefix.."fps_"..self.unit.id.."_p1_2-p2_2" )

	sm.debugDraw.removeSphere( self.debugPrefix.."fps_"..self.unit.id.."_p1_3" )
end

function FollowPathState.sv_debugText( self, text )
	sm.event.sendToCharacter( self.unit.character, "sv_e_unitDebugText", text )
end