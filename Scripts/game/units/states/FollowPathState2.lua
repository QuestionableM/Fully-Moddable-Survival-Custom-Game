dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"

FollowPathState2 = class( nil )

-- State specific functions

function FollowPathState2.sv_onCreate( self, unit, debugPrefix )
	self.unit = unit
	self.debugPrefix = debugPrefix or ""
	self.followDirectionState = unit:createState( "followDirection" )
	self.movementType = "walk"
	self.tolerance = 1.0
	self.followDirectionState.movementType = self.movementType
	self.followDirectionState.maxDeviation = 15 * math.pi / 180
	self.followDirectionState.avoidance = true
	self.sharpTurnTimer = Timer()
	self.sharpTurnTimer:reset()
	self.sharpTurnTickTime = 20
end

function FollowPathState2.sv_onDestroy( self )
	self:sv_debugDrawCleanup()
end

function FollowPathState2.sv_setMovementType( self, movementType )
	self.movementType = movementType
end

function FollowPathState2.sv_setWaterAvoidance( self, waterAvoidance )
	self.followDirectionState.waterAvoidance = waterAvoidance
end

function FollowPathState2.sv_setCliffAvoidance( self, cliffAvoidance )
	self.followDirectionState.cliffAvoidance = cliffAvoidance
end

function FollowPathState2.sv_setWhiskerAvoidance( self, whiskerAvoidance )
	self.followDirectionState.avoidance = whiskerAvoidance
end

function FollowPathState2.sv_setPath( self, path )
	self.path = path
	--print( "FollowPathState2 follows path with", #self.path, "nodes" )

	if self.path and #self.path > 1 then
		-- Used for spline calculation
		self.distances = {}
		self.distances[1] = 0
		for i = 2,#self.path do
			self.distances[i] = self.distances[i - 1] + ( self.path[i] - self.path[i - 1] ):length()
		end
		
		local closest = closestPointInLines( self.path, self.unit.character.worldPosition )
		self.segmentLength = closest.len
		self.timeInSegment = 0 --TODO: Take distance to first node into account
		
		self.targetPosition = self.unit.character.worldPosition
		self:sv_updateProgress()
		--self:sv_debugDrawPath()
		
		self.followDirectionState.desiredDirection = self.unit:getCurrentMovementDirection()
		
		return true
	end
	return false
end

-- AiState common interface

function FollowPathState2.start( self )
	if not self.path or #self.path < 2 then
		print( "FollowPathState2 ("..self.debugPrefix..") for unit", self.unit.id, "does not have enough nodes to start" )
		return
	end

	local closest = closestPointInLines( self.path, self.unit.character.worldPosition )

	self.segmentLength = closest.len
	self.timeInSegment = 0 --TODO: Take distance to first node into account
	
	self.targetPosition = self.unit.character.worldPosition
	self:sv_updateProgress()
	--self:sv_debugDrawPath()

	self.followDirectionState.desiredDirection = self.unit:getCurrentMovementDirection()
	self.followDirectionState:start()

	self.started = true
	--print( "FollowPathState2 started" )
end

function FollowPathState2.stop( self )
	--print( "FollowPathState2 stopped" )
	self.started = false

	self.followDirectionState:stop()

	self:sv_debugDrawCleanup()
	self.targetPosition = nil
	self.segmentLength = nil
	self.timeInSegment = nil
	self.checkSharpTurn = nil
	self.done = nil
end

function FollowPathState2.onFixedUpdate( self, timeStep )
	if not self.started then return end
	
	if ( self.targetPosition - self.unit.character.worldPosition ):length2() > 0.25 then
		
		local fromToTarget = self.targetPosition - self.unit.character.worldPosition
		local flatFromToTarget = sm.vec3.new( fromToTarget.x, fromToTarget.y, 0.0 )
		local desiredDirection = self.unit:getCurrentMovementDirection()
		if flatFromToTarget:length2() >= FLT_EPSILON * FLT_EPSILON then
			desiredDirection = flatFromToTarget:normalize()
		end

		self.followDirectionState.desiredDirection = desiredDirection
		
		if self.unit:getCurrentMovementDirection():dot( self.followDirectionState.desiredDirection ) < 0.86602540378 then --cos(30deg)
			self.sharpTurnTimer:tick()
			
			if self.sharpTurnTimer.count > self.sharpTurnTickTime then
				self.followDirectionState.movementType = "stand"
				self.followDirectionState.avoidance = false
			elseif self.sharpTurnTimer.count > self.sharpTurnTickTime * 0.5 then
				self.followDirectionState.movementType = "walk"
	
				if self.path and #self.path >= 2 and self.distanceToPath < 4.0 then
					self.followDirectionState.avoidance = false
				else
					self.followDirectionState.avoidance = true
				end
			end

		else

			self.sharpTurnTimer:reset()
			self.followDirectionState.movementType = self.movementType
			
			if self.path and #self.path >= 2 and self.distanceToPath < 4.0 then
				self.followDirectionState.avoidance = false
			else
				self.followDirectionState.avoidance = true
			end
		end
	else
		self.followDirectionState.movementType = "stand"
		self.followDirectionState.avoidance = false
	end
	
	self.followDirectionState:onFixedUpdate( timeStep )
end

function FollowPathState2.onUnitUpdate( self, dt )
	if not self.started then return end

	-- Update progess
	local movementSpeed = self.unit.character:getCurrentMovementSpeed()
	self:sv_updateProgress()
	
	self.timeInSegment = self.timeInSegment + dt
	local expected = self.segmentLength / movementSpeed
	local max = expected * 2.0 + 1 --TWEAKABLE
	--print( "time in segment:", self.timeInSegment, "expected:", expected, "max:", max )

	if self.timeInSegment > max then
		--print( "Too slow! - Time in segment:", self.timeInSegment, "expected:", expected, "max:", max )
		--self.done = "failed"
	end
end

function FollowPathState2.isDone( self )
	return self.done ~= nil, self.done
end

function FollowPathState2.getMovementDirection( self )
	return self.followDirectionState:getMovementDirection()
end

function FollowPathState2.getFacingDirection( self )
	return self.followDirectionState:getFacingDirection()
end

function FollowPathState2.getMovementType( self )
	return self.followDirectionState:getMovementType()
end

-- Private

function FollowPathState2.sv_updateProgress( self )
	local totalLength, lines = lengthOfLines( self.path )
	if totalLength == 0 then
		return
	end
	
	if #self.path > 2 then
		local res = closestPointInLinesSkipFirst( self.path, self.unit.character.worldPosition )
		local distToIndex2 = self.path[2] - self.unit.character.worldPosition
		local distToIndex2Flat = sm.vec3.new( distToIndex2.x, distToIndex2.y, 0.0 ):length()

		if res.i == 2 and ( res.t > 0.0 or distToIndex2Flat < 1.5 ) then
			self.targetPosition = self.path[3]

			local pt, t, len = closestPointOnLineSegment( self.path[2], self.path[3], self.unit.character.worldPosition )
			local fromToSegment = pt - self.unit.character.worldPosition
			local flatFromToSegment = sm.vec3.new( fromToSegment.x, fromToSegment.y, 0.0 )

			self.distanceToPath = flatFromToSegment:length()
		else
			self.targetPosition = self.path[2]
			self.distanceToPath = distToIndex2Flat
		end
	elseif #self.path == 2 then
		self.targetPosition = self.path[2]

		local distToIndex2 = self.path[2] - self.unit.character.worldPosition
		local distToIndex2Flat = sm.vec3.new( distToIndex2.x, distToIndex2.y, 0.0 ):length()

		self.distanceToPath = distToIndex2Flat

	elseif #self.path == 1 then
		self.targetPosition = self.path[#self.path]
		self.distanceToPath = 1000.0
	else
		self.distanceToPath = 1000.0
	end

	if #self.path ~= 0 then
		local fromToDestination = self.path[#self.path] - self.unit.character.worldPosition
		local flatFromToDestination = sm.vec3.new( fromToDestination.x, fromToDestination.y, 0.0 )

		if flatFromToDestination:length2() < 1.0 then
			self.done = "arrived"
		else
			self.done = nil
		end
	else
		self.done = "failed"
	end
end

function FollowPathState2.sv_debugDrawPath( self )
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

function FollowPathState2.sv_debugDrawCleanup( self )
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

function FollowPathState2.sv_debugText( self, text )
	sm.event.sendToCharacter( self.unit.character, "sv_e_unitDebugText", text )
end