-- CombatFollowAttackState.lua --

CombatFollowAttackState = class( nil )

function CombatFollowAttackState.sv_onCreate( self, unit ) 
	self.unit = unit

	self.attacks = {}
	self.desiredDirection = sm.vec3.new( 0, 1, 0 )
	self.movementType = "walk"
	self.target = nil
	self.globalCooldown = 0
	self.currentAttackIndex = nil
	self.done = nil
end

function CombatFollowAttackState.refresh( self ) end

function CombatFollowAttackState.sv_addAttack( self, attackState ) 
	self.attacks[#self.attacks+1] = attackState
end

function CombatFollowAttackState.sv_setTarget( self, target )
	self.target = target
end

function CombatFollowAttackState.sv_setMovementType( self, movementType )
	self.desiredMovementType = movementType
	self.movementType = movementType
end

function CombatFollowAttackState.sv_canAttack( self )
	return self:sv_getAvailableAttackIndex() ~= nil and self.globalCooldown <= 0
end

function CombatFollowAttackState.sv_getAvailableAttackIndex( self ) 
	for i, attackState in ipairs( self.attacks ) do
		local done, result = attackState:isDone()
		if done and result == "ready" then
			return i
		end
	end
	return nil
end

function CombatFollowAttackState.sv_getMinMaxAttackRange( self )
	local minRange, maxRange
	for i, attackState in ipairs( self.attacks ) do
		if minRange == nil then
			minRange = attackState.attackRange
		else
			if attackState.attackRange < minRange then
				minRange = attackState.attackRange
			end
		end
		if maxRange == nil then
			maxRange = attackState.attackRange
		else
			if attackState.attackRange > maxRange then
				maxRange = attackState.attackRange
			end
		end
	end
	return minRange, maxRange
end

function CombatFollowAttackState.sv_getFurthestPossibleAttackRange( self )
	local maxRange
	for i, attackState in ipairs( self.attacks ) do
		local done, result = attackState:isDone()
		if done then
			if maxRange == nil then
				maxRange = attackState.attackRange
			else
				if attackState.attackRange > maxRange then
					maxRange = attackState.attackRange
				end
			end
		end
	end
	return maxRange
end

--[[API functions]]

function CombatFollowAttackState.start( self )
	self.currentAttackIndex = nil
	self.done = nil
end

function CombatFollowAttackState.stop( self )
	if self.currentAttackIndex then
		local currentAttackState = self.attacks[self.currentAttackIndex]
		currentAttackState:stop()
	end
	self.target = nil
	self.currentAttackIndex = nil
	self.done = nil
end

function CombatFollowAttackState.tick( self )
	if self.globalCooldown > 0 then
		self.globalCooldown = self.globalCooldown - 1
		if self.globalCooldown <= 0 then
			self.globalCooldown = 0
		end
	end
end

function CombatFollowAttackState.onFixedUpdate( self, dt ) 
	if not self.target or not sm.exists( self.target ) then
		self.target = nil
		self.done = "lost"
		self.movementType = "stand"
		return
	end
	local fromToTarget = self.target.worldPosition - self.unit.character.worldPosition
	local distance = fromToTarget:length()
	local flatCurrentTargetPosition = sm.vec3.new( self.target.worldPosition.x, self.target.worldPosition.y, self.unit.character.worldPosition.z )
	local flatFromToTarget = flatCurrentTargetPosition - self.unit.character.worldPosition
	self.desiredDirection = fromToTarget:normalize()
	if self.currentAttackIndex then
		local currentAttackState = self.attacks[self.currentAttackIndex]
		currentAttackState.attackDirection = self.unit.character.direction
	end
	
	if self.desiredMovementType then
		self.movementType = self.desiredMovementType
	else
		self.movementType = "walk"
	end

end

function CombatFollowAttackState.onUnitUpdate( self, dt ) 

	if self.currentAttackIndex == nil then
		if self.globalCooldown <= 0  then
			self.currentAttackIndex = self:sv_getAvailableAttackIndex()
			if self.currentAttackIndex then
				local currentAttackState = self.attacks[self.currentAttackIndex]
				self.globalCooldown = currentAttackState.globalCooldown
				currentAttackState.attackDirection = self.unit.character.direction
				currentAttackState:start()
				self.done = nil
			end
		end
	end
	
	if self.currentAttackIndex then
		local currentAttackState = self.attacks[self.currentAttackIndex]
		currentAttackState.attackDirection = self.unit.character.direction
		local done, result = currentAttackState:isDone()
		if done then
			self.currentAttackIndex = nil
			currentAttackState:stop()
		end
		self.done = result
	end
	
end

function CombatFollowAttackState.isDone( self )
	return self.done == "finished" or self.done == "ready" or self.done == "lost", self.done
end

function CombatFollowAttackState.getMovementDirection( self )
	if self.desiredDirection then
		return self.desiredDirection
	elseif self.currentAttackIndex then
		local currentAttackState = self.attacks[self.currentAttackIndex]
		return currentAttackState:getMovementDirection()
	end
	return self.unit.character.direction
end

function CombatFollowAttackState.getFacingDirection( self )
	if self.desiredDirection then
		return self.desiredDirection
	elseif self.currentAttackIndex then
		local currentAttackState = self.attacks[self.currentAttackIndex]
		return currentAttackState:getFacingDirection()
	end
	return self.unit.character.direction
end

function CombatFollowAttackState.getMovementType( self )
	return self.movementType
end

function CombatFollowAttackState.getWantsJump( self )
	return false
end