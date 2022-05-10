dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/units/states/FollowPathState2.lua" )
dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"

PathingState = class( nil )

-- State specific functions

function PathingState.sv_onCreate( self, unit )
	self.unit = unit
	self.tolerance = 1.0
	self.followPathState = FollowPathState2()
	self.followPathState:sv_onCreate( unit, "a:" )
	self.followPathState.debugName = "followPathState"
	
	self.followDirectionState = self.unit:createState( "followDirection" )
	self.followDirectionState.debugName = "followDirectionState"
	
	self.idleState = self.unit:createState( "idle" )
	self.idleState.debugName = "idleState"
	
	self.pathingConditions = nil
	self.destination = nil
	
	self.progressTimeout = 5.0 -- seconds without progress
	self.ticksWithoutProgress = 0
	self.lastProgressPosition = self.unit.character.worldPosition

	self.currentState = self.idleState
end

function PathingState.sv_onDestroy( self )
	self:sv_debugDrawCleanup()
	self.followPathState:sv_onDestroy()
end

function PathingState.sv_setMovementType( self, movementType )
	self.followPathState:sv_setMovementType( movementType )
	self.followDirectionState.movementType = movementType
end

function PathingState.sv_setWaterAvoidance( self, waterAvoidance )
	self.followPathState:sv_setWaterAvoidance( waterAvoidance )
	self.followDirectionState.waterAvoidance = waterAvoidance
end

function PathingState.sv_setCliffAvoidance( self, cliffAvoidance )
	self.followPathState:sv_setCliffAvoidance( cliffAvoidance )
	self.followDirectionState.cliffAvoidance = cliffAvoidance
end

function PathingState.sv_setWhiskerAvoidance( self, whiskerAvoidance )
	self.followPathState:sv_setWhiskerAvoidance( whiskerAvoidance )
	self.followDirectionState.avoidance = whiskerAvoidance
end

function PathingState.sv_setTimeout( self, progressTimeout )
	self.progressTimeout = progressTimeout
end

function PathingState.sv_setTolerance( self, tolerance )
	self.tolerance = tolerance
	self.followPathState.tolerance = tolerance
end

function PathingState.sv_setConditions( self, conditions )
	self.pathingConditions = conditions
end

function PathingState.sv_setDestination( self, toPosition )
	self.destination = toPosition
	self.newDestination = true
end

-- AiState common interface

function PathingState.start( self )
	self:sv_debugText( "PathingState started" )
	
	self.done = nil
	self.breachPosition = nil
	self.breachDirection = nil
	
	self.lastProgressPosition = self.unit.character.worldPosition
	self.ticksWithoutProgress = 0

	self.currentState = self.followDirectionState
	self.currentState:start()
	
	self.started = true
end

function PathingState.stop( self )
	self.started = false

	self.currentState:stop()
	self.currentState = self.idleState

	self:sv_debugDrawCleanup()
	
	self:sv_debugText( "PathingState stopped" )
end

function PathingState.sv_updatePath( self )
	local path = sm.pathfinder.getPath( self.unit.character, self.destination, false, self.pathingConditions )
	self.mainPath = {}
	self.mainPath[1] = self.unit.character.worldPosition
	for _, link in ipairs( path ) do
		local pathPosition = link.toNode:getPosition() + sm.vec3.new( 0, 0, self.unit.character:getHeight() * 0.5 )
		if ( pathPosition - self.mainPath[#self.mainPath] ):length() > 0 then
			self.mainPath[#self.mainPath+1] = pathPosition
		end
	end
	if ( self.destination - self.mainPath[#self.mainPath] ):length() > 0 then
		self.mainPath[#self.mainPath+1] = self.destination
	end
	
	-- Tweak path by finding shortcuts when entering and leaving the node network
	if #self.mainPath > 2 then
		
		-- Attempt to shortcut the first step
		local firstShortcut
		if ( self.mainPath[2] - self.mainPath[3] ):length() > 0 then
			local closest = closestPointInLines( { self.mainPath[2], self.mainPath[3] }, self.unit.character.worldPosition )
			if sm.ai.directPathAvailable( self.unit, closest.pt, ( closest.pt - self.unit.character.worldPosition ):length() ) then
				firstShortcut = closest.pt
			end
		end
		
		-- Check for shortcut on the final step
		local finalShortcut
		if ( self.mainPath[#self.mainPath-2] - self.mainPath[#self.mainPath-1] ):length() > 0 then
			local closest = closestPointInLines( { self.mainPath[#self.mainPath-2], self.mainPath[#self.mainPath-1] }, self.destination )
			finalShortcut = closest.pt
		end
		
		local allowShortcut = true
		if firstShortcut and finalShortcut then
			if ( finalShortcut - firstShortcut ):length() == 0 then
				allowShortcut = false
			end
		end
		if allowShortcut then
			if firstShortcut and ( firstShortcut - self.mainPath[3] ):length() > 0 and ( firstShortcut - self.mainPath[1] ):length() > 0 then
				self.mainPath[2] = firstShortcut
			end
			if finalShortcut and ( finalShortcut - self.mainPath[#self.mainPath-2] ):length() > 0 and ( finalShortcut - self.mainPath[#self.mainPath] ):length() > 0 then
				self.mainPath[#self.mainPath-1] = finalShortcut
			end
		end
	end
	
	self.followPathState:sv_setPath( self.mainPath )
end

function PathingState.onFixedUpdate( self, timeStep )
	if not self.started then return end
	if self.currentState then
		self.currentState:onFixedUpdate( timeStep )
	end
	
	local prevState = self.currentState
	
	if self.newDestination then
		self:sv_updatePath()
		self.done = nil
		self.newDestination = nil
	end
	
	local movementSpeed = self.unit.character:getCurrentMovementSpeed()
	local updateInterval = 0.3 -- tweakable, % of timeout
	local progressUpdateDistance = movementSpeed * ( self.progressTimeout * updateInterval )
	local distanceTraveled = ( self.lastProgressPosition - self.unit.character.worldPosition ):length()
	if distanceTraveled >= progressUpdateDistance then
		self.lastProgressPosition = self.unit.character.worldPosition
		self.ticksWithoutProgress = 0
	else
		self.ticksWithoutProgress = self.ticksWithoutProgress + 1
	end
	if ( self.ticksWithoutProgress / 40 ) >= self.progressTimeout then
		self.currentState = self.idleState
		self.done = "failed"
	end

	local fromTo = self.destination - self.unit.character.worldPosition
	local distanceLeft = fromTo:length()
	if distanceLeft <= self.tolerance then
		self.currentState = self.idleState
		self.done = "arrived"
	end
	
	local hasDirectPath = sm.ai.directPathAvailable( self.unit, self.destination, math.min( distanceLeft, 16.0 ) )
	if self.currentState == self.idleState then
		if not self.done then
			self.currentState = self.followDirectionState
		end
	end
	
	if self.currentState == self.followDirectionState then
		local flatFromTo = sm.vec3.new( fromTo.x, fromTo.y, 0.0 )
		if flatFromTo:length() >= FLT_EPSILON then
			self.followDirectionState.desiredDirection = flatFromTo:normalize()
		else
			self.followDirectionState.desiredDirection = self.unit.character.direction
		end
		
		if not hasDirectPath then
			if #self.mainPath >= 2 then
				self.currentState = self.followPathState
			--else
			--	self.currentState = self.idleState
			--	self.done = "failed"
			--	-- can replace with ticker for bot states that report when stuck and continue walking into the wall
			end
		end
		
	elseif self.currentState == self.followPathState then
		local done, result = self.followPathState:isDone()
		if done then
			self.done = result
		else
			if hasDirectPath then
				self.currentState = self.followDirectionState
			end
		end
		
	end
	
	if prevState ~= self.currentState then
		prevState:stop()
		self.currentState:start()
	end
end

function PathingState.onUnitUpdate( self, dt )
	if not self.started then return end
	if self.currentState then
		self.currentState:onUnitUpdate( dt )
		if self.done == nil and self.currentState == self.followPathState then
			self.newDestination = true
		end
	end
end

function PathingState.isDone( self )
	if self.done then
		return true, self.done
	end
	return false
end

function PathingState.getMovementDirection( self )
	return self.currentState:getMovementDirection()
end

function PathingState.getFacingDirection( self )
	return self.currentState:getFacingDirection()
end

function PathingState.getMovementType( self )
	return self.currentState:getMovementType()
end

-- Private

function PathingState.sv_debugDrawCleanup( self )
	sm.debugDraw.removeSphere( "u_"..self.unit.id.."_closestLinePos" )
	
	self:sv_clearBacktrackDebugDraw()
end

function PathingState.sv_clearBacktrackDebugDraw( self )
	if self.backtrack and #self.backtrack > 1 then
		for i = 1, #self.backtrack - 1 do
			sm.debugDraw.removeArrow( "u_"..self.unit.id.."_backtrack"..i )
		end
	end
end

function PathingState.sv_debugText( self, text )
	sm.event.sendToCharacter( self.unit.character, "sv_e_unitDebugText", text )
end
