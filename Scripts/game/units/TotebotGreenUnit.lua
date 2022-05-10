dofile "$SURVIVAL_DATA/Scripts/game/units/unit_util.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Ticker.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_units.lua"
dofile "$SURVIVAL_DATA/Scripts/game/units/states/PathingState.lua"
dofile "$SURVIVAL_DATA/Scripts/game/units/states/BreachState.lua"
dofile "$SURVIVAL_DATA/Scripts/game/units/states/CombatAttackState.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"

TotebotGreenUnit = class( nil )

local RoamStartTimeMin = 40 * 4 -- 4 seconds
local RoamStartTimeMax = 40 * 8 -- 8 seconds

local CombatAttackRange = 1.0 -- Range where the unit will perform attacks
local CombatApproachRange = 2.25 -- Range where the unit will approach the player without obstacle checking

local StaggerProjectile = 0.5
local StaggerMelee = 1.0
local StaggerCooldownTickTime = 1.65 * 40

local AvoidLimit = 3
local AvoidRange = 3.5

local AllyRange = 20.0
local MeleeBreachLevel = 9

local HearRange = 40.0

function TotebotGreenUnit.server_onCreate( self )
	
	self.target = nil
	self.previousTarget = nil
	self.lastTargetPosition = nil
	self.ambushPosition = nil
	self.predictedVelocity = sm.vec3.new( 0, 0, 0 )
	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = {}
	end
	if self.saved.stats == nil then
		self.saved.stats = { hp = 60, maxhp = 60 }
	end

	if g_eventManager then
		self.tileStorageKey = g_eventManager:sv_getTileStorageKeyFromObject( self.unit.character )
	end

	if self.params then
		if self.params.tetherPoint then
			self.homePosition = self.params.tetherPoint + sm.vec3.new( 0, 0, self.unit.character:getHeight() * 0.5 )
			if self.params.ambush == true then
				self.ambushPosition = self.params.tetherPoint + sm.vec3.new( 0, 0, self.unit.character:getHeight() * 0.5 )
			end
			if self.params.raider == true then
				self.saved.raidPosition = self.params.tetherPoint + sm.vec3.new( 0, 0, self.unit.character:getHeight() * 0.5 )
			end
		end
		if self.params.raider then
			self.saved.raider = true
		end
		if self.params.temporary then
			self.saved.temporary = self.params.temporary
			self.saved.deathTickTimestamp = sm.game.getCurrentTick() + getTicksUntilDayCycleFraction( DAYCYCLE_DAWN )
		end
		if self.params.deathTick then
			self.saved.deathTickTimestamp = self.params.deathTick
		end
		if self.params.color then
			self.saved.color = self.params.color
		end
		if self.params.groupTag then
			self.saved.groupTag = self.tileStorageKey .. ":" .. self.params.groupTag
		end
	end
	if self.saved.color then
		self.unit.character:setColor( self.saved.color )
	end
	if not self.homePosition then
		self.homePosition = self.unit.character.worldPosition
	end
	self.storage:save( self.saved )
	self.unit.publicData = { groupTag = self.saved.groupTag }
	
	self.unit.eyeHeight = self.unit.character:getHeight() * 0.75
	self.unit.visionFrustum = {
		{ 3.0, math.rad( 80.0 ), math.rad( 80.0 ) },
		{ 20.0, math.rad( 40.0 ), math.rad( 35.0 ) },
		{ 40.0, math.rad( 20.0 ), math.rad( 20.0 ) }
	}
	self.unit:setWhiskerData( 3, math.rad( 60.0 ), 1.5, 5.0 )
	self.noiseScale = 1.0
	self.impactCooldownTicks = 0
	
	self.isInCombat = false
	self.combatTimer = Timer()
	self.combatTimer:start( 40 * 12 )

	self.stateTicker = Ticker()
	self.stateTicker:init()
	
	-- Idle	
	self.idleState = self.unit:createState( "idle" )
	self.idleState.debugName = "idleState"
	
	-- Stagger
	self.staggeredEventState = self.unit:createState( "wait" )
	self.staggeredEventState.time = 0.25
	self.staggeredEventState.interruptible = false
	self.staggeredEventState.debugName = "staggeredEventState"
	self.stagger = 0.0
	self.staggerCooldownTicks = 0
	
	-- Roam
	self.roamTimer = Timer()
	self.roamTimer:start( math.random( RoamStartTimeMin, RoamStartTimeMax ) )
	self.roamState = self.unit:createState( "roam" )
	self.roamState.debugName = "roamState"
	self.roamState.tetherPosition = self.unit.character.worldPosition
	self.roamState.waterAvoidance = false
	self.roamState.roamCenterOffset = 0.0

	-- Pathing
	self.pathingState = PathingState()
	self.pathingState:sv_onCreate( self.unit )
	self.pathingState:sv_setTolerance( 1.0 )
	self.pathingState:sv_setMovementType( "sprint" )
	self.pathingState:sv_setWaterAvoidance( false )
	self.pathingState.debugName = "pathingState"
	
	-- Attacks
	self.attackState01 = self.unit:createState( "meleeAttack" )
	self.attackState01.meleeType = melee_totebotattack
	self.attackState01.event = "melee"
	self.attackState01.damage = 15
	self.attackState01.attackRange = 1.15
	self.attackState01.animationCooldown = 0.825 * 40
	self.attackState01.attackCooldown = 1.0 * 40
	self.attackState01.globalCooldown = 0.0 * 40
	self.attackState01.attackDelay = 0.25 * 40
	self.attackState01.power = 3750.0
	
	-- Combat
	self.combatAttackState = CombatAttackState()
	self.combatAttackState:sv_onCreate( self.unit )
	self.stateTicker:addState( self.combatAttackState )
	self.combatAttackState:sv_addAttack( self.attackState01 )
	self.combatAttackState.debugName = "combatAttackState"

	-- Breach
	self.breachState = BreachState()
	self.breachState:sv_onCreate( self.unit, math.ceil( 40 * 2.0 ) )
	self.stateTicker:addState( self.breachState )
	self.breachState:sv_setBreachRange( CombatAttackRange )
	self.breachState:sv_setBreachLevel( MeleeBreachLevel )
	self.breachState:sv_addAttack( self.attackState01 )
	self.breachState.debugName = "breachState"
	
	-- Combat approach
	self.combatApproachState = self.unit:createState( "positioning" )
	self.combatApproachState.debugName = "combatApproachState"
	self.combatApproachState.timeout = 0.5
	self.combatApproachState.tolerance = CombatAttackRange
	self.combatApproachState.avoidance = false
	self.combatApproachState.movementType = "sprint"
	self.combatApproachState.debugName = "combatApproachState"
	
	-- Avoid
	self.avoidState = self.unit:createState( "positioning" )
	self.avoidState.debugName = "avoid"
	self.avoidState.timeout = 1.5
	self.avoidState.tolerance = 0.5
	self.avoidState.avoidance = false
	self.avoidState.movementType = "sprint"
	self.avoidState.debugName = "avoidState"
	self.avoidCount = 0
	
	-- LookAt
	self.lookAtState = self.unit:createState( "positioning" )
	self.lookAtState.debugName = "lookAt"
	self.lookAtState.timeout = 3.0
	self.lookAtState.tolerance = 0.5
	self.lookAtState.avoidance = false
	self.lookAtState.movementType = "stand"

	-- Flee
	self.dayFlee = self.unit:createState( "flee" )
	self.dayFlee.movementAngleThreshold = math.rad( 180 )
	self.dayFlee.maxFleeTime = 0.0
	self.dayFlee.maxDeviation = 45 * math.pi / 180
	self.dayFlee.debugName = "dayFlee"
	
	-- Tumble
	initTumble( self )
	
	-- Crushing
	initCrushing( self, DEFAULT_CRUSH_TICK_TIME )
	
	self.griefTimer = Timer()
	self.griefTimer:start( 40 * 9.0 )

	self.avoidResetTimer = Timer()
	self.avoidResetTimer:start( 40 * 16.0 )
	
	self.currentState = self.idleState
	self.currentState:start()
end

function TotebotGreenUnit.server_onRefresh( self )
	print( "-- TotebotGreenUnit refreshed --" )
end

function TotebotGreenUnit.server_onDestroy( self )
	print( "-- TotebotGreenUnit terminated --" )
end

function TotebotGreenUnit.server_onFixedUpdate( self, dt )
	
	-- Temporary units are destroyed at dawn
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
	
	self.stateTicker:tick()
	
	if updateCrushing( self ) then
		print("'TotebotGreenUnit' was crushed!")
		self:sv_onDeath( sm.vec3.new( 0, 0, 0 ) )
	end
	
	updateTumble( self )
	updateAirTumble( self, self.idleState )
	
	self.griefTimer:tick()
	
	if self.avoidCount > 0 then
		self.avoidResetTimer:tick()
		if self.avoidResetTimer:done() then
			self.avoidCount = 0
			self.avoidResetTimer:reset()
		end
	end
	
	if self.currentState then
		if self.target and not sm.exists( self.target ) then
			self.target = nil
		end

		-- Predict target velocity
		if self.target and type( self.target ) == "Character" then
			if self.predictedVelocity:length() > 0 and self.target:getVelocity():length() > self.predictedVelocity:length() then
				self.predictedVelocity = magicPositionInterpolation( self.predictedVelocity, self.target:getVelocity(), dt, 1.0 / 10.0 )
			else
				self.predictedVelocity = self.target:getVelocity()
			end
		else
			self.predictedVelocity = sm.vec3.new( 0, 0, 0 )
		end

		self.currentState:onFixedUpdate( dt )
		self.unit:setMovementDirection( self.currentState:getMovementDirection() )
		self.unit:setMovementType( self.currentState:getMovementType() )
		self.unit:setFacingDirection( self.currentState:getFacingDirection() )
		
		-- Random roaming during idle
		if self.currentState == self.idleState then
			self.roamTimer:tick()
		end

		if self.isInCombat then
			self.combatTimer:tick()
		end

		self.staggerCooldownTicks = math.max( self.staggerCooldownTicks - 1, 0 )
		self.impactCooldownTicks = math.max( self.impactCooldownTicks - 1, 0 )
		
	end
	
	-- Update target for totebot character
	if self.target ~= self.previousTarget then
		self:sv_updateCharacterTarget()
		self.previousTarget = self.target
	end
end

function TotebotGreenUnit.server_onCharacterChangedColor( self, color )
	if self.saved.color ~= color then
		self.saved.color = color
		self.storage:save( self.saved )
	end
end

function TotebotGreenUnit.server_onUnitUpdate( self, dt )
	
	if not sm.exists( self.unit ) then
		return
	end
	
	if self.currentState then
		self.currentState:onUnitUpdate( dt )
	end
	
	-- Temporary units are routed by the daylight
	if self.saved.temporary then
		if self.currentState ~= self.dayFlee and sm.game.getCurrentTick() >= self.saved.deathTickTimestamp - DaysInTicks( 1 / 24 ) then
			local prevState = self.currentState
			prevState:stop()
			self.currentState = self.dayFlee
			self.currentState:start()
		end
		if self.currentState == self.dayFlee then
			return
		end
	end
	
	if self.unit.character:isTumbling() then
		return
	end
	
	local targetCharacter
	local closestVisiblePlayerCharacter
	local closestHeardPlayerCharacter
	local closestVisibleWocCharacter
	local closestVisibleWormCharacter
	local closestVisibleCrop
	local closestVisibleTeamOpponent
	if not SurvivalGame then
		closestVisibleTeamOpponent = sm.ai.getClosestVisibleTeamOpponent( self.unit, self.unit.character:getColor() )
	end
	closestVisiblePlayerCharacter = sm.ai.getClosestVisiblePlayerCharacter( self.unit )
	if not closestVisiblePlayerCharacter then
		closestHeardPlayerCharacter = ListenForPlayerNoise( self.unit.character, self.noiseScale )
	end
	if not closestVisiblePlayerCharacter and not closestHeardPlayerCharacter then
		closestVisibleWocCharacter = sm.ai.getClosestVisibleCharacterType( self.unit, unit_woc )
	end
	if not closestVisibleWocCharacter and not closestVisiblePlayerCharacter and not closestHeardPlayerCharacter then
		closestVisibleWormCharacter = sm.ai.getClosestVisibleCharacterType( self.unit, unit_worm )
	end
	if self.saved.raider then
		closestVisibleCrop = sm.ai.getClosestVisibleCrop( self.unit )
	elseif not closestVisibleWormCharacter and not closestVisibleWocCharacter and not closestVisiblePlayerCharacter and not closestHeardPlayerCharacter then
		if self.griefTimer:done() then
			closestVisibleCrop = sm.ai.getClosestVisibleCrop( self.unit )
		end
	end

	-- Find target
	if closestVisibleTeamOpponent then
		targetCharacter = closestVisibleTeamOpponent
	elseif closestVisiblePlayerCharacter then
		targetCharacter = closestVisiblePlayerCharacter
	elseif closestHeardPlayerCharacter then
		targetCharacter = closestHeardPlayerCharacter
	elseif closestVisibleWocCharacter then
		targetCharacter = closestVisibleWocCharacter
	elseif closestVisibleWormCharacter then
		targetCharacter = closestVisibleWormCharacter
	end
	
	-- Share found target
	local foundTarget = false
	if targetCharacter and self.target == nil then
		for _, allyUnit in ipairs( sm.unit.getAllUnits() ) do
			if sm.exists( allyUnit ) and self.unit ~= allyUnit and allyUnit.character and isAnyOf( allyUnit.character:getCharacterType(), g_robots ) and InSameWorld( self.unit, allyUnit) then
				local inAllyRange = ( allyUnit.character.worldPosition - self.unit.character.worldPosition ):length() <= AllyRange
				if inAllyRange or InSameGroup( allyUnit, self.unit ) then
					local sameTeam = true
					if not SurvivalGame then
						sameTeam = InSameTeam( allyUnit, self.unit )
					end
					if sameTeam then
						sm.event.sendToUnit( allyUnit, "sv_e_receiveTarget", { targetCharacter = targetCharacter, sendingUnit = self.unit } )
					end
				end
			end
		end
		foundTarget = true
	end
	
	-- Check for targets acquired from callbacks
	if self.eventTarget and sm.exists( self.eventTarget ) and targetCharacter == nil then
		if type( self.eventTarget ) == "Character" then
			if not ( self.eventTarget:isPlayer() and not sm.game.getEnableAggro() ) then
				targetCharacter = self.eventTarget
			end
		end
	end
	self.eventTarget = nil

	if self.saved.raider then
		selectRaidTarget( self, targetCharacter, closestVisibleCrop )
	else
		if targetCharacter then
			self.target = targetCharacter
		else
			self.target = closestVisibleCrop
		end
	end
	if self.target and not sm.exists( self.target ) then
		self.target = nil
	end
	
	-- Cooldown after attacking a crop
	if type( self.target ) == "Harvestable" then
		local _, attackResult = self.combatAttackState:isDone()
		if attackResult == "started" or attackResult == "attacked" then
			self.griefTimer:reset()
		end
	end
	
	local inCombatApproachRange = false
	local inCombatAttackRange = false
	if self.target then
		self.lastTargetPosition = self.target.worldPosition
	end

	-- Check for positions acquired from noise
	local noiseShape = g_unitManager:sv_getClosestNoiseShape( self.unit.character.worldPosition, HearRange )
	if noiseShape and self.eventNoisePosition == nil then
		self.eventNoisePosition = noiseShape.worldPosition
	end
	local heardNoise = false
	if self.eventNoisePosition then
		self.lookAtState.desiredPosition = self.unit.character.worldPosition
		local fromToNoise = self.eventNoisePosition - self.unit.character.worldPosition
		fromToNoise.z = 0
		if fromToNoise:length() >= FLT_EPSILON then
			self.lookAtState.desiredDirection = fromToNoise:normalize()
		else
			self.lookAtState.desiredDirection = -self.unit.character.direction
		end
		heardNoise = true
	end
	self.eventNoisePosition = nil

	if self.lastTargetPosition then
		local fromToTarget = self.lastTargetPosition - self.unit.character.worldPosition
		local predictionScale = fromToTarget:length() / math.max( self.unit.character.velocity:length(), 1.0 )
		local predictedPosition = self.lastTargetPosition + self.predictedVelocity * predictionScale
		local desiredDirection = predictedPosition - self.unit.character.worldPosition
		local targetRadius = 0.0
		if self.target and type( self.target ) == "Character" then
			targetRadius = self.target:getRadius()
		end

		inCombatApproachRange = fromToTarget:length() - targetRadius <= CombatApproachRange
		inCombatAttackRange = fromToTarget:length() - targetRadius <= CombatAttackRange

		local attackDirection = ( desiredDirection:length() >= FLT_EPSILON ) and desiredDirection:normalize() or self.unit.character.direction
		self.combatAttackState:sv_setAttackDirection( attackDirection ) -- Turn ongoing attacks toward moving players
		self.combatApproachState.desiredPosition = self.lastTargetPosition
		self.combatApproachState.desiredDirection = fromToTarget:normalize()
	end

	-- Raiders will continue attacking an ambush position
	if self.saved.raidPosition then
		local flatFromToRaid = sm.vec3.new( self.saved.raidPosition.x,  self.saved.raidPosition.y, self.unit.character.worldPosition.z ) - self.unit.character.worldPosition
		if flatFromToRaid:length() >= RAIDER_AMBUSH_RADIUS then
			self.ambushPosition = self.saved.raidPosition
		end
	end
	
	-- Ambushers will always have somewhere they want to go
	if self.ambushPosition then
		if not self.lastTargetPosition and not self.target then
			self.lastTargetPosition = self.ambushPosition
		end
		local flatFromToAmbush = sm.vec3.new(  self.ambushPosition.x,  self.ambushPosition.y, self.unit.character.worldPosition.z ) - self.unit.character.worldPosition
		if flatFromToAmbush:length() <= 2.0 then
			-- Finished ambush
			self.ambushPosition = nil
		end
	end

	-- Raiders without a target search for shapes to destroy
	if self.saved.raidPosition and not self.ambushPosition and not self.lastTargetPosition and not self.target then
		local attackableShape, attackPosition = FindAttackableShape( self.saved.raidPosition, RAIDER_AMBUSH_RADIUS, MeleeBreachLevel )
		if attackableShape and attackPosition then
			self.lastTargetPosition = attackPosition
		end
	end

	local prevState = self.currentState
	local prevInCombat = self.isInCombat
	if self.lastTargetPosition then
		self.isInCombat = true
		self.combatTimer:reset()
	end
	if self.combatTimer:done() then
		self.isInCombat = false
	end

	-- Check for direct path
	local directPath = false
	if self.lastTargetPosition then
		local directPathDistance = 7.0 
		local fromToTarget = self.lastTargetPosition - self.unit.character.worldPosition
		local distance = fromToTarget:length()
		if distance <= directPathDistance then
			directPath = sm.ai.directPathAvailable( self.unit, self.lastTargetPosition, directPathDistance )
		end
	end

	-- Update pathingState destination and condition
	local pathingConditions = { { variable = sm.pathfinder.conditionProperty.target, value = ( self.lastTargetPosition and 1 or 0 ) } }
	self.pathingState:sv_setConditions( pathingConditions )
	if self.currentState == self.pathingState then
		if self.target then
			local currentTargetPosition = self.target.worldPosition
			if type( self.target ) == "Harvestable" then
				currentTargetPosition = self.target.worldPosition + sm.vec3.new( 0, 0, self.unit.character:getHeight() * 0.5 )
			end
			self.pathingState:sv_setDestination( currentTargetPosition )
		elseif self.lastTargetPosition then
			self.pathingState:sv_setDestination( self.lastTargetPosition )
		end
	end

	-- Breach check
	local breachDestination = nil
	if self.isInCombat and self.currentState ~= self.breachState then
		local nextTargetPosition
		if self.target then
			nextTargetPosition = self.target.worldPosition
		elseif self.lastTargetPosition then
			nextTargetPosition = self.lastTargetPosition
		end
		-- Always check for breachable in front of the unit
		if nextTargetPosition == nil then
			nextTargetPosition = self.unit.character.worldPosition + self.unit.character.direction
		end
		
		local breachDepth = 0.25
		local leveledNextTargetPosition = sm.vec3.new( nextTargetPosition.x, nextTargetPosition.y, self.unit.character.worldPosition.z )
		local valid, breachPosition, breachObject = sm.ai.getBreachablePosition( self.unit, leveledNextTargetPosition, breachDepth, MeleeBreachLevel )
		if valid and breachPosition then
			local flatFromToNextTarget = leveledNextTargetPosition
			flatFromToNextTarget.z = 0
			if flatFromToNextTarget:length() <= 0 then
				flatFromToNextTarget = sm.vec3.new( 0, 1, 0 )
			end
			breachDestination = nextTargetPosition + flatFromToNextTarget:normalize() * breachDepth
		end
	end

	-- Find dangerous obstacles
	local shouldAvoid = false
	local closestDangerShape, _ = g_unitManager:sv_getClosestDangers( self.unit.character.worldPosition )
	if closestDangerShape then
		local fromToDanger = closestDangerShape.worldPosition - self.unit.character.worldPosition
		local distance = fromToDanger:length()
		if distance <= AvoidRange and ( ( self.target and self.avoidCount < AvoidLimit ) or self.target == nil ) then
			self.avoidState.desiredPosition = self.unit.character.worldPosition - fromToDanger:normalize() * 2
			self.avoidState.desiredDirection = fromToDanger:normalize()
			shouldAvoid = true
		end
	end

	local done, result = self.currentState:isDone()
	local abortState = 	( self.currentState ~= self.combatAttackState ) and
						( self.currentState ~= self.avoidState ) and
						(
							( shouldAvoid ) or
							( self.currentState == self.pathingState and ( inCombatApproachRange or inCombatAttackRange ) and self.isInCombat ) or
							( prevInCombat and self.combatTimer:done() ) or
							( self.currentState == self.pathingState and breachDestination ) or
							( self.currentState == self.breachState and directPath ) or
							( self.currentState == self.lookAtState and self.isInCombat ) or
							( self.currentState == self.roamState and heardNoise )
						)

	if ( done or abortState ) then
		-- Select state
		if shouldAvoid then
			-- Move away from danger
			if self.currentState ~= self.avoidState  then
				self.avoidCount = math.min( self.avoidCount + 1, AvoidLimit )
			end
			self.currentState = self.avoidState
		elseif self.currentState == self.combatApproachState and done then
			-- Attack towards the approached target
			self.currentState = self.combatAttackState
		elseif breachDestination then
			-- Start breaching path obstacle
			self.breachState:sv_setDestination( breachDestination )
			self.currentState = self.breachState
		elseif self.currentState == self.pathingState and result == "failed" then
			self.avoidState.desiredDirection = self.unit.character.direction
			self.avoidState.desiredPosition = self.unit.character.worldPosition - self.avoidState.desiredDirection:normalize() * 2
			self.currentState = self.avoidState
		elseif self.isInCombat then
			-- Select combat state
			if self.target and inCombatAttackRange then
				-- Attack towards target character
				self.currentState = self.combatAttackState
			elseif self.target and inCombatApproachRange then
				-- Move close to the target to increase the likelihood of a hit
				self.currentState = self.combatApproachState
			elseif self.lastTargetPosition then
				if self.currentState ~= self.pathingState then
					self.pathingState:sv_setDestination( self.lastTargetPosition )
				else
					self.lastTargetPosition = nil
				end
				self.currentState = self.pathingState
			else
				-- Couldn't find the target
				self.isInCombat = false
			end
		else
			-- Select non-combat state
			if heardNoise then
				self.currentState = self.lookAtState
				self.roamTimer:start( math.random( RoamStartTimeMin, RoamStartTimeMax ) )
			elseif self.roamTimer:done() and not ( self.currentState == self.idleState and result == "started" ) then
				self.roamTimer:start( math.random( RoamStartTimeMin, RoamStartTimeMax ) )
				self.currentState = self.roamState
			elseif not ( self.currentState == self.roamState and result == "roaming" ) then
				self.currentState = self.idleState
			end
		end
	end

	if prevState ~= self.currentState then
		if ( prevState == self.roamState and self.currentState ~= self.idleState ) or ( prevState == self.idleState and self.currentState ~= self.roamState ) then
			self.unit:sendCharacterEvent( "alerted" )
		elseif self.currentState == self.idleState and prevState ~= self.roamState then
			self.unit:sendCharacterEvent( "roaming" )
		end
		
		prevState:stop()
		self.currentState:start()
		if DEBUG_AI_STATES then
			print( self.currentState.debugName )
		end
	end

end

function TotebotGreenUnit.sv_e_worldEvent( self, params )
	if sm.exists( self.unit ) and self.isInCombat == false then
		if params.eventName == "projectileHit" then
			if self.unit.character then
				local distanceToProjectile = ( self.unit.character.worldPosition - params.hitPos ):length()
				if distanceToProjectile <= 4.0 then
					if self.eventTarget == nil and params.attacker and params.attacker.character then
						self.eventTarget = params.attacker.character
					end
				end
			end
		elseif params.eventName == "projectileFire" then
			if self.unit.character then
				local distanceToShooter = ( self.unit.character.worldPosition - params.firePos ):length()
				if distanceToShooter <= 10.0 then
					if self.eventTarget == nil and params.attacker and params.attacker.character then
						self.eventTarget = params.attacker.character
					end
				end
			end
		elseif params.eventName == "collisionSound" then
			if self.unit.character then
				local soundReach = math.min( math.max( math.log( 1 + params.impactEnergy ) * 10.0, 0.0 ), 40.0 )
				local distanceToSound = ( self.unit.character.worldPosition - params.collisionPosition ):length()
				if distanceToSound <= soundReach then
					if self.eventNoisePosition == nil then
						self.eventNoisePosition = params.collisionPosition
					end
				end
			end
		end
	end
end

function TotebotGreenUnit.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	if not sm.exists( self.unit ) or not sm.exists( attacker ) then
		return
	end
	local teamOpponent = false
	if type( attacker ) == "Unit" then
		if not SurvivalGame then
			teamOpponent = not InSameTeam( attacker, self.unit )
		end
	end

	if type( attacker ) == "Player" or type( attacker ) == "Shape" or teamOpponent then
		if damage > 0 then
			self:sv_addStagger( StaggerProjectile )
			if self.eventTarget == nil then
				if type( attacker ) == "Player" or type( attacker ) == "Unit" then
					self.eventTarget = attacker:getCharacter()
				elseif type( attacker ) == "Shape" then
					self.eventTarget = attacker
				end
			end
		end
		local impact = hitVelocity:normalize() * 6
		self:sv_takeDamage( damage, impact, hitPos )
	end
end

function TotebotGreenUnit.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
	if not sm.exists( self.unit ) or not sm.exists( attacker ) then
		return
	end
	local teamOpponent = false
	if type( attacker ) == "Unit" then
		if not SurvivalGame then
			teamOpponent = not InSameTeam( attacker, self.unit )
		end
	end

	if type( attacker ) == "Player" or teamOpponent then
		local attackingCharacter = attacker:getCharacter()
		self:sv_addStagger( StaggerMelee )
		if self.eventTarget == nil then
			self.eventTarget = attackingCharacter
		end

		local impact = hitDirection * 6
		self:sv_takeDamage( damage, impact, hitPos )
	end
end

function TotebotGreenUnit.server_onExplosion( self, center, destructionLevel )
	if not sm.exists( self.unit ) then
		return
	end
	local impact = ( self.unit:getCharacter().worldPosition - center ):normalize() * 6
	self:sv_takeDamage( self.saved.stats.maxhp * ( destructionLevel / 10 ), impact, self.unit:getCharacter().worldPosition )
end

function TotebotGreenUnit.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	if not sm.exists( self.unit ) then
		return
	end

	if type( other ) == "Character" then
		if not sm.exists( other ) then
			return
		end
		local teamOpponent = false
		if not SurvivalGame then
			teamOpponent = not InSameTeam( other, self.unit )
		end
		if other:isPlayer() or teamOpponent then
			if self.eventTarget == nil then
				self.eventTarget = other
			end
		end
	elseif type( other ) == "Shape" then
		if not sm.exists( other ) then
			return
		end
		if self.target == nil and self.eventTarget == nil then
			local creationBodies = other.body:getCreationBodies()
			for _, body in ipairs( creationBodies ) do
				local seatedCharacters = body:getAllSeatedCharacter()
				if #seatedCharacters > 0 then
					self.eventTarget = seatedCharacters[1]
					break
				end
			end
		end
	end
	
	if self.impactCooldownTicks > 0 then
		return
	end

	local collisionDamageMultiplier = 1.0
	local damage, tumbleTicks, tumbleVelocity, impactReaction = CharacterCollision( self.unit.character, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal, self.saved.stats.maxhp / collisionDamageMultiplier )
	damage = damage * collisionDamageMultiplier
	if damage > 0 or tumbleTicks > 0 then
		self.impactCooldownTicks = 6
	end
	if damage > 0 then
		print("'TotebotGreenUnit' took", damage, "collision damage")
		self:sv_takeDamage( damage, collisionNormal, collisionPosition )
	end
	if tumbleTicks > 0 then
		if startTumble( self, tumbleTicks, self.idleState, tumbleVelocity ) then
			if type( other ) == "Shape" and sm.exists( other ) and other.body:isDynamic() then
				sm.physics.applyImpulse( other.body, impactReaction * other.body.mass, true, collisionPosition - other.body.worldPosition )
			end
		end
	end
	
end

function TotebotGreenUnit.server_onCollisionCrush( self )
	if not sm.exists( self.unit ) then
		return
	end
	onCrush( self )
end

function TotebotGreenUnit.sv_updateCharacterTarget( self )
	if self.unit.character then
		sm.event.sendToCharacter( self.unit.character, "sv_n_updateTarget", { target = self.target } )
	end
end

function TotebotGreenUnit.sv_addStagger( self, stagger )
	
	-- Update stagger
	if self.staggerCooldownTicks <= 0 then
		self.staggerCooldownTicks = StaggerCooldownTickTime
		self.stagger = self.stagger + stagger
		local triggerStaggered = ( self.stagger >= 1.0 )
		self.stagger = math.fmod( self.stagger, 1.0 )

		if triggerStaggered then
			local prevState = self.currentState
			self.currentState = self.staggeredEventState
			prevState:stop()
			self.currentState:start()
		end
	end
	
end

function TotebotGreenUnit.sv_takeDamage( self, damage, impact, hitPos )
	if self.saved.stats.hp > 0 then
		self.saved.stats.hp = self.saved.stats.hp - damage
		self.saved.stats.hp = math.max( self.saved.stats.hp, 0 )
		print( "'TotebotGreenUnit' received:", damage, "damage.", self.saved.stats.hp, "/", self.saved.stats.maxhp, "HP" )
		
		local effectRotation = sm.quat.identity()
		if hitPos and impact and impact:length() >= FLT_EPSILON then
			effectRotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), -impact:normalize() )
		end
		sm.effect.playEffect( "ToteBot - Hit", hitPos, nil, effectRotation )

		if self.saved.stats.hp <= 0 then
			self:sv_onDeath( impact )
		else
			self.storage:save( self.saved )
		end
	end
end

function TotebotGreenUnit.sv_onDeath( self, impact )
	local character = self.unit:getCharacter()
	if not self.destroyed then
		self.unit:sendCharacterEvent( "death" )
		g_unitManager:sv_addDeathMarker( character.worldPosition )
		self.saved.stats.hp = 0
		self.unit:destroy()
		print("'TotebotGreenUnit' killed!")
		self:sv_spawnParts( impact )
		if SurvivalGame then
			local loot = SelectLoot( "loot_totebot_green" )
			SpawnLoot( self.unit, loot )
		end
		self.destroyed = true
	end
end

function TotebotGreenUnit.sv_spawnParts( self, impact )
	local character = self.unit:getCharacter()

	local lookDirection = character:getDirection()
	local bodyPos = character.worldPosition
	local bodyRot = sm.quat.identity()
	lookDirection = sm.vec3.new( lookDirection.x, lookDirection.y, 0 )
	if lookDirection:length() >= FLT_EPSILON then
		lookDirection = lookDirection:normalize()
		bodyRot = sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), lookDirection  ) --Turn parts sideways
	end
	local bodyOffset = bodyRot * sm.vec3.new( -0.25, 0.25, 0.375 )
	bodyPos = bodyPos - bodyOffset

	local color = self.unit.character:getColor()
	if SurvivalGame then
		if math.random( 1, 5 ) == 1 then
			local headBody = sm.body.createBody( bodyPos, bodyRot, true )
			local headShape = headBody:createPart( obj_interactive_robotbliphead01, sm.vec3.new( 0, 1, 2 ), sm.vec3.new( 0, 1, 0 ), sm.vec3.new( -1, 0, 0 ), true )
			headShape.color = color
			sm.physics.applyImpulse( headShape, impact * headShape.mass, true )
		end
	end
end

function TotebotGreenUnit.sv_e_receiveTarget( self, params )
	if self.unit ~= params.unit then
		if self.eventTarget == nil then
			local sameTeam = false
			if not SurvivalGame then
				sameTeam = InSameTeam( params.targetCharacter, self.unit )
			end
			if not sameTeam then
				self.eventTarget = params.targetCharacter
			end
		end
	end
end
