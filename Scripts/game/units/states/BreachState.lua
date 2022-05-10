-- BreachState.lua --
dofile "$SURVIVAL_DATA/Scripts/game/units/states/CombatAttackState.lua"

BreachState = class( nil )

function BreachState.sv_onCreate( self, unit, breachTimeoutTime  ) 
	self.unit = unit

	self.idleState = self.unit:createState( "idle" )
	
	self.followDirectionState = unit:createState( "followDirection" )
	self.followDirectionState.movementType = "walk"
	self.followDirectionState.maxDeviation = 0
	self.followDirectionState.avoidance = false
	self.followDirectionState.desiredDirection = sm.vec3.new( 0, 1, 0)
	
	self.combatAttackState = CombatAttackState()
	self.combatAttackState:sv_onCreate( self.unit )
	
	self.currentState = self.idleState
	
	self.breachRange = 1.0
	self.breachLevel = 5
	self.closeEnough = 0.25
	self.breachTimeoutTime = breachTimeoutTime
	self.breachTimeout = breachTimeoutTime
	self.targetPosition = nil -- Where it wants to go
	self.breachPosition = nil -- Where it needs to hit to progress
	self.done = nil
end

function BreachState.refresh( self ) end

function BreachState.sv_setDestination( self, targetPosition )
	self.targetPosition = targetPosition
	self.done = nil
	self.breachTimeout = self.breachTimeoutTime
end

function BreachState.sv_setBreachRange( self, range ) 
	self.breachRange = range
end

function BreachState.sv_setBreachLevel( self, breachLevel ) 
	self.breachLevel = breachLevel
end

function BreachState.sv_addAttack( self, attackState ) 
	self.combatAttackState:sv_addAttack( attackState )
end

--[[API functions]]
function BreachState.start( self )
	self.done = nil
	self.breachPosition = nil
	self.breachTimeout = self.breachTimeoutTime
	local prevState = self.currentState
	self.currentState = self.idleState
	prevState:stop()
	self.currentState:start()
end

function BreachState.stop( self )
	self.done = nil
	self.breachPosition = nil
	self.breachTimeout = self.breachTimeoutTime
	self.currentState:stop()
end

function BreachState.tick( self )
	self.combatAttackState:tick()
	
	if self.currentState then
		local done, _ = self:isDone()
		if self.currentState == self.combatAttackState or done then
			self.breachTimeout = self.breachTimeoutTime
		else
			self.breachTimeout = math.max( self.breachTimeout - 1, 0 )
		end
	end
end

function BreachState.onFixedUpdate( self, dt )

	if self.currentState then
		self.currentState:onFixedUpdate( dt )
	end
	
	if self.breachPosition then
		sm.debugDraw.addArrow( "u_"..self.unit.id.."breachPosition", self.breachPosition, self.breachPosition + sm.vec3.new( 0 ,0, 1 ), sm.color.new( "ffffff" ) )
	else
		sm.debugDraw.removeArrow( "u_"..self.unit.id.."breachPosition" )
	end
	
end

function BreachState.onUnitUpdate( self, dt ) 
	
	if self.currentState then
		self.currentState:onUnitUpdate( dt )
	end
	local prevState = self.currentState
	
	if self.targetPosition then
		local xyDistance = ( sm.vec3.new( self.targetPosition.x, self.targetPosition.y, 0 ) - sm.vec3.new( self.unit.character.worldPosition.x, self.unit.character.worldPosition.y, 0 ) ):length()
		if xyDistance <= self.closeEnough then
			self.targetPosition = nil
			self.done = "breached"
		end
	end
	
	-- Calculate breach position
	self.breachPosition = nil
	if self.targetPosition then
		local leveledTargetPosition = sm.vec3.new( self.targetPosition.x, self.targetPosition.y, self.unit.character.worldPosition.z )
		local valid, breachPosition, breachObject = sm.ai.getBreachablePosition( self.unit, leveledTargetPosition, self.breachRange, self.breachLevel )
		if valid and breachPosition then
			self.done = nil
			self.breachPosition = breachPosition
		elseif not valid and breachPosition then
			self.done = "fail"
		end
	end
	
	-- Select state
	local done, result = self.currentState:isDone()
	if self.breachTimeout <= 0 then
		self.done = "timeout"
		self.currentState = self.idleState
	elseif self.breachPosition then
		local desiredDirection = ( self.breachPosition - self.unit.character.worldPosition ):normalize()
		self.combatAttackState:sv_setAttackDirection( desiredDirection )
		self.currentState = self.combatAttackState
	elseif self.currentState == self.combatAttackState and not done then
		self.currentState = self.combatAttackState
	elseif self.targetPosition then
		local desiredDirection = ( self.targetPosition - self.unit.character.worldPosition ):normalize()
		if math.abs( desiredDirection.z ) == 1 then
			desiredDirection = self.unit.character.direction
		end
		self.followDirectionState.desiredDirection = desiredDirection
		self.currentState = self.followDirectionState
	else
		self.currentState = self.idleState
	end

	
	if prevState ~= self.currentState then
		prevState:stop()
		self.currentState:start()
	end
end

function BreachState.isDone( self )
	return self.done == "breached" or self.done == "timeout" or self.done == "fail", self.done
end

function BreachState.getMovementDirection( self )
	if self.targetPosition then
		local desiredDirection = ( self.targetPosition - self.unit.character.worldPosition ):normalize()
		if math.abs( desiredDirection.z ) == 1 then
			desiredDirection = sm.vec3.new( 0, 1, 0 )
		end
		return desiredDirection
	end
	return self.unit.character.direction
end

function BreachState.getFacingDirection( self )
	if self.breachPosition then
		local desiredDirection = ( self.breachPosition - self.unit.character.worldPosition ):normalize()
		if math.abs( desiredDirection.z ) == 1 then
			desiredDirection = sm.vec3.new( 0, 1, 0 )
		end
		return desiredDirection
	elseif self.targetPosition then
		local desiredDirection = ( self.targetPosition - self.unit.character.worldPosition ):normalize()
		if math.abs( desiredDirection.z ) == 1 then
			desiredDirection = sm.vec3.new( 0, 1, 0 )
		end
		return desiredDirection
	end
	return self.unit.character.direction
end

function BreachState.getMovementType( self )
	return self.currentState:getMovementType()
end

function BreachState.getWantsJump( self )
	return false
end