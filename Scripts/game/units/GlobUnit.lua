dofile "$SURVIVAL_DATA/Scripts/game/units/unit_util.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile( "$SURVIVAL_DATA/Scripts/game/util/Timer.lua" )
dofile "$SURVIVAL_DATA/Scripts/game/units/states/PathingState.lua"

GlobUnit = class( nil )

local RoamStartTimeMin = 40 * 10 -- 10 seconds
local RoamStartTimeMax = 40 * 25 -- 25 seconds
local FleeTimeMin = 40 * 14 -- 14 seconds
local FleeTimeMax = 40 * 20 -- 20 seconds
local EdibleSearchRadius = 5.0
local EdibleReach = 0.75
local CardboardPerGoop = 15

function GlobUnit.server_onCreate( self )

	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = {}
	end
	if self.saved.stats == nil then
		self.saved.stats = { hp = 100, maxhp = 100, cardboardEaten = 0 }
	end

	if self.params then
		if self.params.tetherPoint then
			self.homePosition = self.params.tetherPoint + sm.vec3.new( 0, 0, self.unit.character:getHeight() * 0.5 )
		end
		if self.params.deathTick then
			self.saved.deathTickTimestamp = self.params.deathTick
		end
	end
	if not self.homePosition then
		self.homePosition = self.unit.character.worldPosition
	end
	if not self.saved.deathTickTimestamp then
		self.saved.deathTickTimestamp = sm.game.getCurrentTick() + DaysInTicks( 30 )
	end
	self.storage:save( self.saved )

	self.unit:setWhiskerData( 3, 60 * math.pi / 180, 1.5, 5.0 )
	self.impactCooldownTicks = 0

	-- Idle
	self.idleState = self.unit:createState( "idle" )
	self.idleState.randomEvents = { { name = "eat", chance = 0.2, interruptible = false, time = 4 },
									{ name = "noise", chance = 0.4 } }
	self.idleState.debugName = "idleState"

	-- Roam
	self.roamTimer = Timer()
	self.roamTimer:start( math.random( RoamStartTimeMin, RoamStartTimeMax ) )
	self.roamState = self.unit:createState( "flockingRoam" )
	self.roamState.tetherPosition = self.homePosition
	self.roamState.roamCenterOffset = 0.0
	
	-- Flee
	self.fleeState = self.unit:createState( "flee" )
	self.fleeState.movementAngleThreshold = math.rad( 180 )
	
	-- Pathing
	self.pathingState = PathingState()
	self.pathingState:sv_onCreate( self.unit )
	self.pathingState:sv_setTolerance( 0.5 )
	self.pathingState:sv_setMovementType( "walk" )
	self.pathingState:sv_setWaterAvoidance( false )
	self.pathingState:sv_setWhiskerAvoidance( false )
	self.pathingState.debugName = "pathingState"

	-- Eat
	self.eatEventState = self.unit:createState( "wait" )
	self.eatEventState.debugName = "eatEventState"
	self.eatEventState.time = 4.0
	self.eatEventState.interruptible = false
	self.eatEventState.name = "eat"
	
	-- Crushing
	initCrushing( self, DEFAULT_CRUSH_TICK_TIME )
	
	self.currentState = self.idleState
	self.currentState:start()
end

function GlobUnit.server_onRefresh( self )
	print( "-- GlobUnit refreshed --" )
end

function GlobUnit.server_onDestroy( self )
	print( "-- GlobUnit terminated --" )
end

function GlobUnit.server_onFixedUpdate( self, dt )

	if sm.exists( self.unit ) and not self.destroyed then
		if self.saved.deathTickTimestamp and sm.game.getCurrentTick() >= self.saved.deathTickTimestamp then
			self.unit:destroy()
			self.destroyed = true
			return
		end
	end

	if self.unit.character:isSwimming() then
		self.roamState.cliffAvoidance = false
		self.pathingState:sv_setCliffAvoidance( false )
	else
		self.roamState.cliffAvoidance = true
		self.pathingState:sv_setCliffAvoidance( true )
	end

	if updateCrushing( self ) then
		print("'GlobUnit' was crushed!")
		self:sv_takeDamage( self.saved.stats.maxhp )
	end

	if self.currentState then
		self.currentState:onFixedUpdate( dt )
		self.unit:setMovementDirection( self.currentState:getMovementDirection() )
		self.unit:setMovementType( self.currentState:getMovementType() )
		self.unit:setFacingDirection( self.currentState:getFacingDirection() )
		
		-- Random roaming during idle
		if self.currentState == self.idleState then
			self.roamTimer:tick()
		end
		self.impactCooldownTicks = math.max( self.impactCooldownTicks - 1, 0 )
	end

	if self.saved.stats.cardboardEaten >= CardboardPerGoop then
		self.saved.stats.cardboardEaten = self.saved.stats.cardboardEaten - CardboardPerGoop
		if SurvivalGame then
			local loot = SelectLoot( "loot_glow_goop" )
			SpawnLoot( self.unit, loot )
		end
		self.storage:save( self.saved )
	end
end

function GlobUnit.server_onUnitUpdate( self, dt )

	if not sm.exists( self.unit ) then
		return
	end

	if self.currentState then
		self.currentState:onUnitUpdate( dt )
	end

	if self.unit.character:isTumbling() then
		return
	end

	-- Find cardboard
	local targetCardboard, cardboardInRange = FindNearbyEdible( self.unit.character, blk_cardboard, EdibleSearchRadius, EdibleReach )
	cardboardInRange = false
	local targetPosition = nil
	local targetLocalPosition = nil
	if targetCardboard then
		targetLocalPosition = targetCardboard:getClosestBlockLocalPosition( self.unit.character.worldPosition )
		targetPosition = targetCardboard.body:transformPoint( ( targetLocalPosition + sm.vec3.new( 0.5, 0.5, 0.5 ) ) * 0.25 )
		cardboardInRange = ( targetPosition - self.unit.character.worldPosition ):length() <= EdibleReach

		if math.abs( targetPosition.z - self.unit.character.worldPosition.z ) > EdibleReach then
			-- Ignore cardboard at unreachable heights
			targetCardboard = nil
			targetPosition = nil
			targetLocalPosition = nil
			cardboardInRange = false
		else
			self.pathingState:sv_setDestination( targetPosition )
		end
	end

	local prevState = self.currentState
	local done, result = self.currentState:isDone()
	local abortState = 	(
							( self.fleeFrom ) or
							( ( self.currentState == self.pathingState or self.currentState == self.roamState ) and cardboardInRange ) or
							( ( self.currentState == self.pathingState or self.currentState == self.roamState ) and targetCardboard == nil )
						)

	if ( done or abortState ) then
		-- Select state
		if self.fleeFrom then
			self:sv_flee( self.fleeFrom )
			prevState = self.currentState
			self.fleeFrom = nil
		elseif self.currentState == self.fleeState or self.currentState == self.eatEventState then
			self.currentState = self.idleState
		elseif targetCardboard and targetPosition and targetLocalPosition then
			if cardboardInRange then
				self.currentState = self.eatEventState
				self.saved.stats.cardboardEaten = self.saved.stats.cardboardEaten + 1
				self.saved.stats.hp = self.saved.stats.maxhp
				self.saved.deathTickTimestamp = sm.game.getCurrentTick() + DaysInTicks( 30 ) -- Neglected Globs die after 30 days
				targetCardboard:destroyBlock( targetLocalPosition, sm.vec3.new( 1, 1, 1 ) )
				self.storage:save( self.saved )
			else
				self.pathingState:sv_setDestination( targetPosition )
				self.currentState = self.pathingState
			end
		elseif self.roamTimer:done() and not ( self.currentState == self.idleState and result == "started" ) then
			self.roamTimer:start( math.random( RoamStartTimeMin, RoamStartTimeMax ) )
			self.currentState = self.roamState
		elseif not ( self.currentState == self.roamState and result == "roaming" ) then
			self.currentState = self.idleState
		end
	end

	if prevState ~= self.currentState then
		prevState:stop()
		self.currentState:start()
		if DEBUG_AI_STATES then
			print( self.currentState.debugName )
		end
	end
end

function GlobUnit.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	if not sm.exists( self.unit ) or not sm.exists( attacker ) then
		return
	end
	if damage > 0 then
		if self.fleeFrom == nil then
			self.fleeFrom = attacker
			self.unit:sendCharacterEvent( "hit" )
		end
	end

	self:sv_takeDamage( damage )
end

function GlobUnit.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
	if not sm.exists( self.unit ) or not sm.exists( attacker ) then
		return
	end
	local attackingCharacter = attacker:getCharacter()
	if self.fleeFrom == nil then
		self.fleeFrom = attacker
		self.unit:sendCharacterEvent( "hit" )
	end

	self:sv_takeDamage( damage )
	ApplyKnockback( self.unit.character, hitDirection, power * 0.5 )
end

function GlobUnit.server_onExplosion( self, center, destructionLevel )
	if not sm.exists( self.unit ) then
		return
	end
	if self.fleeFrom == nil then
		self.fleeFrom = center
		self.unit:sendCharacterEvent( "hit" )
	end
	self:sv_takeDamage( self.saved.stats.maxhp * ( destructionLevel / 10 ) )
end

function GlobUnit.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	if not sm.exists( self.unit ) then
		return
	end

	if self.impactCooldownTicks > 0 then
		return
	end

	local damage, _, _, _ = CharacterCollision( self.unit.character, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal, self.saved.stats.maxhp )
	if damage > 0 then
		self.impactCooldownTicks = 6
	end
	if damage > 0 then
		print("'GlobUnit' took", damage, "collision damage")
		self:sv_takeDamage( damage )
	end
end

function GlobUnit.server_onCollisionCrush( self )
	if not sm.exists( self.unit ) then
		return
	end
	onCrush( self )
end

function GlobUnit.sv_flee( self, from )
	self.currentState:stop()
	self.currentState = self.fleeState
	self.fleeState.fleeFrom = from
	self.fleeState.maxFleeTime = math.random( FleeTimeMin, FleeTimeMax ) / 40
	self.fleeState.maxDeviation = 45 * math.pi / 180
	self.currentState:start()
end

function GlobUnit.sv_takeDamage( self, damage )
	if self.saved.stats.hp > 0 then
		self.saved.stats.hp = self.saved.stats.hp - damage
		self.saved.stats.hp = math.max( self.saved.stats.hp, 0 )
		print( "'GlobUnit' received:", damage, "damage.", self.saved.stats.hp, "/", self.saved.stats.maxhp, "HP" )
		sm.effect.playEffect( "Glowgorp - Hit", self.unit.character.worldPosition )

		if self.saved.stats.hp <= 0 then
			self:sv_onDeath()
			sm.effect.playEffect( "Glowgorp - Destruct", self.unit.character.worldPosition )
		else
			self.storage:save( self.saved )
		end
	end
end

function GlobUnit.sv_onDeath( self )
	local character = self.unit:getCharacter()
	if not self.destroyed then
		self.saved.stats.hp = 0
		self.unit:destroy()
		print("'GlobUnit' killed!")
		self.destroyed = true
	end
end
