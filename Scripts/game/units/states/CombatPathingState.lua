dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/util/Stack.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/units/states/FollowPathState.lua" )

CombatPathingState = class( nil )

-- State specific functions

function CombatPathingState.sv_onCreate( self, unit )
	self.unit = unit
	self.tolerance = 1.0
	self.followPathState = FollowPathState()
	self.followPathState:sv_onCreate( unit, "a:" )
	self.pathStack = Stack()
	self.pathStack:init()
end

function CombatPathingState.sv_onDestroy( self )
	self:sv_debugDrawCleanup()
	self.followPathState:sv_onDestroy()
end

function CombatPathingState.sv_setMovementType( self, movementType )
	self.followPathState:sv_setMovementType( movementType )
end

function CombatPathingState.sv_setTolerance( self, tolerance )
	self.tolerance = tolerance
	self.followPathState.tolerance = tolerance
end

function CombatPathingState.sv_findPath( self, toPosition, conditions )
	local path = sm.pathfinder.getPath( self.unit.character, toPosition, false, conditions )
	print( path )

	self.mainPath = {}
	self.mainPath[1] = self.unit.character.worldPosition
	for _, link in ipairs( path ) do
		self.mainPath[#self.mainPath + 1] = link.toNode:getPosition() + sm.vec3.new( 0, 0, self.unit.character:getHeight() * 0.5 )
	end
	self.mainPath[#self.mainPath + 1] = toPosition

	-- HACK FOR TESTING
	--local dir = ( toPosition - self.unit.character.worldPosition )
	--dir.z = 0
	--dir = dir:normalize()
	--toPosition.z = self.unit.character.worldPosition.z
	--self.mainPath = { self.unit.character.worldPosition, toPosition }

	--print( "Path:", self.mainPath )
	print( "CombatPathingState found a path with", #self.mainPath, "nodes" )

	return #self.mainPath > 1
end

function CombatPathingState.sv_getBreachParams( self )
	assert( self.done == "breach" )
	return self.breachPosition, self.breachDirection
end

-- AiState common interface

function CombatPathingState.start( self )
	self:sv_debugText( "CombatPathingState started" )
	if not ( #self.mainPath > 1 ) then
		print( "CombatPathingState for unit", self.unit.id, "does not have enough nodes to start" )
		return
	end
	
	self.done = nil
	self.breachPosition = nil
	self.breachDirection = nil

	self.pathStack:init()
	self:sv_pushPath( self.mainPath )
	self.bestProgess = 1
	self.bestPosition = self.unit.character.worldPosition

	self.started = true
end

function CombatPathingState.stop( self )
	self.started = false
	
	if self.followPathState.started then
		self.followPathState:stop()
	end

	self:sv_debugDrawCleanup()

	self.bestProgess = nil
	self.bestPosition = nil
	self.wasOnTrack = nil
	self.backtrackCounter = nil
	self.backtrack = nil
	self.backtrackTimer = nil
	self:sv_debugText( "CombatPathingState stopped" )
end

function CombatPathingState.onFixedUpdate( self, timeStep )
	if not self.started then return end

	local followDone, followResult = self.followPathState:isDone()
	if followDone then
		self:sv_debugText( "FollowPathState is done with result: "..followResult )
		
		if self.backtrackCounter and self.backtrackCounter > 1 then
			self:sv_debugText( "There seems to be no way in. Start breaching!" )
			self:sv_breach()
			self:sv_popPath()
			return
		end
		self:sv_popPath()
	end

	if not self.done and self.followPathState.path == self.mainPath then
		local closest = closestPointInLines( self.mainPath, self.unit.character.worldPosition )
		local closestLinePos = closest.pt
		local progress = closest.i + closest.t
		local segmentLength = closest.len

		local color
		if ( self.unit.character.worldPosition - closestLinePos ):length() > self.tolerance or progress < self.bestProgess - 1.0 / segmentLength then
			color = sm.color.new( "ff8800" )
			if self.wasOnTrack then

				if self.backtrackCounter and self.backtrackCounter > 1 then
					self:sv_debugText( "I give up! ("..self.backtrackCounter..") Start breaching!" )
					self:sv_breach()
					return
				end

				if not self.backtrackCounter then
					self.backtrackCounter = 1
					self:sv_debugText( "Lost track! ("..self.backtrackCounter..") Starting position logging..." )
				else
					self.backtrackCounter = self.backtrackCounter + 1
					self:sv_debugText( "Lost track again! ("..self.backtrackCounter..") Starting position logging..." )
				end
				
				sm.debugDraw.addArrow( "u_"..self.unit.id.."_backtrack1", self.unit.character.worldPosition, closestLinePos, sm.color.new( "ff0000" ) )
				self.backtrack = { [1] = self.bestPosition, [2] = self.unit.character.worldPosition }
				self.backtrackTimer = 0

			elseif self.backtrackTimer then
				self.backtrackTimer = self.backtrackTimer + timeStep
				if self.backtrackTimer > 0.0 then --TWEAKABLE
					local patience = 0
					if #self.backtrack >= patience then --TWEAKABLE
						if self.backtrackCounter == 1 then
							self:sv_debugText( "Let's try the other way..." )
						else
							self:sv_debugText( "This is taking me no closer! Time to go back..." )
						end
						self:sv_clearBacktrackDebugDraw()
						reverse( self.backtrack )
						self:sv_pushPath( self.backtrack )
						self.backtrack = nil
						self.backtrackTimer = nil
					else
						sm.debugDraw.addArrow( "u_"..self.unit.id.."_backtrack"..#self.backtrack, self.unit.character.worldPosition, self.backtrack[#self.backtrack], sm.color.new( "ff0000" ) )
						self.backtrack[#self.backtrack + 1] = self.unit.character.worldPosition
						self.backtrackTimer = 0
					end
				end
			end
			self.wasOnTrack = false
		else
			color = sm.color.new( "0088ff" )
			if self.backtrack and not self.wasOnTrack then
				self:sv_debugText( "Back on main path" )
				self:sv_debugText( "PROGRESS: "..( math.floor( progress * 100 ) / 100 )..", BEST: "..( math.floor( self.bestProgess * 100 ) / 100 ) )
				self:sv_clearBacktrackDebugDraw()
			
				if progress > self.bestProgess then
					self:sv_debugText( "Yes! Making progress..." )
					self.backtrack = nil
					self.backtrackCounter = nil
					self.backtrackTimer = nil
					self.followPathState.checkSharpTurn = true
				elseif progress < self.bestProgess - 0.5 / segmentLength then
					self:sv_debugText( "Oh no! Back here again..." )
					reverse( self.backtrack )
					self:sv_pushPath( self.backtrack )
				else
					self:sv_debugText( "Time to try someting else..." )
				end
				self.backtrack = nil
				self.backtrackTimer = nil
			end
			self.wasOnTrack = true
			if progress > self.bestProgess then
				self.bestProgess = progress
				self.bestPosition = self.unit.character.worldPosition
			end
		end
		sm.debugDraw.addSphere( "u_"..self.unit.id.."_closestLinePos", closestLinePos, 0.25, color )
	end

	self.followPathState:onFixedUpdate( timeStep )
end

function CombatPathingState.onUnitUpdate( self, dt )
	if not self.started then return end
	
	self.followPathState:onUnitUpdate( dt )
end

function CombatPathingState.isDone( self )
	if self.done then
		return true, self.done
	end
	return false
end

function CombatPathingState.getMovementDirection( self )
	return self.followPathState:getMovementDirection()
end

function CombatPathingState.getFacingDirection( self )
	return self.followPathState:getFacingDirection()
end

function CombatPathingState.getMovementType( self )
	return self.followPathState:getMovementType()
end

-- Private

function CombatPathingState.sv_pushPath( self, path )
	self:sv_debugText( "Push path" )
	if self.followPathState.started then
		self.followPathState:stop()
	end

	-- Stack push
	if self.followPathState.path then
		self.pathStack:push( self.followPathState.path )
	end
	
	self.followPathState:sv_setPath( path )
	self.followPathState:start()
end

function CombatPathingState.sv_popPath( self )
	self:sv_debugText( "Pop path" )
	self.followPathState:stop()

	local path = self.pathStack:pop()
	self.followPathState:sv_setPath( path )
	
	if path then
		self.followPathState:start()
	else
		self:sv_debugText( "No path left to process, we must have arrived!" )
		self.done = "arrived"
	end
end

function CombatPathingState.sv_breach( self )
	local i0 = math.min( math.floor( self.followPathState.progress ), #self.followPathState.path - 1 )
	local i1 = i0 + 1

	self.breachPosition = self.bestPosition
	self.breachDirection = ( self.followPathState.path[i1] - self.followPathState.path[i0] ):normalize()

	self.done = "breach"
end

function CombatPathingState.sv_debugDrawCleanup( self )
	sm.debugDraw.removeSphere( "u_"..self.unit.id.."_closestLinePos" )
	
	self:sv_clearBacktrackDebugDraw()
end

function CombatPathingState.sv_clearBacktrackDebugDraw( self )
	if self.backtrack and #self.backtrack > 1 then
		for i = 1, #self.backtrack - 1 do
			sm.debugDraw.removeArrow( "u_"..self.unit.id.."_backtrack"..i )
		end
	end
end

function CombatPathingState.sv_debugText( self, text )
	sm.event.sendToCharacter( self.unit.character, "sv_e_unitDebugText", text )
end
