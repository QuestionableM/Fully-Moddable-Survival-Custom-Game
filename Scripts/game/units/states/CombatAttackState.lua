-- CombatAttackState.lua --

CombatAttackState = class( nil )

function CombatAttackState.sv_onCreate( self, unit ) 
	self.unit = unit

	self.attacks = {}
	self.attackDirection = sm.vec3.new( 0, 1, 0 )
	self.globalCooldown = 0
	self.currentAttackIndex = nil
	self.done = nil
end

function CombatAttackState.refresh( self ) end

function CombatAttackState.sv_addAttack( self, attackState ) 
	self.attacks[#self.attacks+1] = attackState
end

function CombatAttackState.sv_setAttackDirection( self, attackDirection )
	self.attackDirection = attackDirection
end

function CombatAttackState.sv_canAttack( self )
	return self:sv_getAvailableAttackIndex() ~= nil and self.globalCooldown <= 0
end

function CombatAttackState.sv_getAvailableAttackIndex( self ) 
	for i, attackState in ipairs( self.attacks ) do
		local done, result = attackState:isDone()
		if done and result == "ready" then
			return i
		end
	end
	return nil
end

function CombatAttackState.sv_getMinMaxAttackRange( self )
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

function CombatAttackState.sv_getFurthestPossibleAttackRange( self )
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

function CombatAttackState.start( self )
	self.currentAttackIndex = nil
	self.done = nil
end

function CombatAttackState.stop( self )
	if self.currentAttackIndex then
		local currentAttackState = self.attacks[self.currentAttackIndex]
		currentAttackState:stop()
	end
	self.currentAttackIndex = nil
	self.done = nil
end

function CombatAttackState.tick( self )
	if self.globalCooldown > 0 then
		self.globalCooldown = self.globalCooldown - 1
		if self.globalCooldown <= 0 then
			self.globalCooldown = 0
		end
	end
end

function CombatAttackState.onFixedUpdate( self, dt ) end

function CombatAttackState.onUnitUpdate( self, dt ) 
	
	if self.currentAttackIndex == nil then
		if self.globalCooldown <= 0  then
			self.currentAttackIndex = self:sv_getAvailableAttackIndex()
			if self.currentAttackIndex then
				local currentAttackState = self.attacks[self.currentAttackIndex]
				self.globalCooldown = currentAttackState.globalCooldown
				currentAttackState.attackDirection = self.attackDirection
				currentAttackState:start()
				self.done = nil
			end
		end
	end
	
	if self.currentAttackIndex then
		local currentAttackState = self.attacks[self.currentAttackIndex]
		currentAttackState.attackDirection = self.attackDirection
		local done, result = currentAttackState:isDone()
		if done then
			self.currentAttackIndex = nil
			currentAttackState:stop()
		end
		self.done = result
	end
	
end

function CombatAttackState.isDone( self )
	return self.done == "finished" or self.done == "ready", self.done
end

function CombatAttackState.getMovementDirection( self )
	if self.currentAttackIndex then
		local currentAttackState = self.attacks[self.currentAttackIndex]
		return currentAttackState:getMovementDirection()
	elseif self.attackDirection then
		return self.attackDirection
	end
	return self.unit.character.direction
end

function CombatAttackState.getFacingDirection( self )
	if self.currentAttackIndex then
		local currentAttackState = self.attacks[self.currentAttackIndex]
		return currentAttackState:getFacingDirection()
	elseif self.attackDirection then
		return self.attackDirection
	end
	return self.unit.character.direction
end

function CombatAttackState.getMovementType( self )
	if self.currentAttackIndex then
		local currentAttackState = self.attacks[self.currentAttackIndex]
		return currentAttackState:getMovementType()
	end
	return "stand"
end

function CombatAttackState.getWantsJump( self )
	return false
end