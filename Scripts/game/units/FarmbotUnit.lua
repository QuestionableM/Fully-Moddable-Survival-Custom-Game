dofile( "$SURVIVAL_DATA/Scripts/game/units/unit_util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/util/Ticker.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/util/Timer.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/units/states/PathingState.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/units/states/BreachState.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/units/states/CombatAttackState.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/units/states/CombatFollowAttackState.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_loot.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_constants.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_meleeattacks.lua" )


FarmbotUnit = class( nil )

local RoamStartTimeMin = 40 * 4 -- 4 seconds
local RoamStartTimeMax = 40 * 8 -- 8 seconds
local VoiceTickTimeMin = 40 * 5.0
local VoiceTickTimeMax = 40 * 9.0
local ChaseTickTime = 40 * 2.5
local SprintRange = 25.0
local CombatAttackRange = 3.25 -- Range where the unit will perform attacks
local CombatFollowRange = 10.0 -- Range where the unit will follow and attack the player
local FireRange = 16.0
local FireLaneWidth = 0.8
local ShotsPerBarrage = 3
local RangedHeightDiff = 3 -- Height difference where the farmbot considers the target position to be hard to reach
local RangedPitchAngle = 10 -- Angle in degrees where the farmbot considers the target position to be hard to reach
local DeathExplosionTime = 4.5
local AllyRange = 20.0
local MeleeBreachLevel = 9
local HearRange = 40.0

function FarmbotUnit.server_onCreate( self )
	
	self.target = nil
	self.previousTarget = nil
	self.lastTargetPosition = nil
	self.lastAimPosition = nil
	self.ambushPosition = nil
	self.predictedVelocity = sm.vec3.new( 0, 0, 0 )
	
	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = {}
	end
	if self.saved.stats == nil then
		self.saved.stats = { hp = 1600, maxhp = 1600 }
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
		if self.params.isPatrolling ~= nil then
			self.saved.patrolling = self.params.isPatrolling
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
	if self.saved.patrolling == nil then
		self.saved.patrolling = true
	end
	if not self.homePosition then
		self.homePosition = self.unit.character.worldPosition
	end
	self.storage:save( self.saved )
	self.unit.publicData = { groupTag = self.saved.groupTag }
	
	self.unit.eyeHeight = self.unit.character:getHeight() * 0.75
	self.unit.visionFrustum = {
		{ 16.0, math.rad( 80.0 ), math.rad( 50.0 ) },
		{ 26.0, math.rad( 40.0 ), math.rad( 35.0 ) },
		{ 40.0, math.rad( 20.0 ), math.rad( 20.0 ) }
	}
	self.unit:setWhiskerData( 4, math.rad( 70.0 ), 1.0, 4.75 )
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
	self.idleState.randomEventCooldownMin = 4
	self.idleState.randomEventCooldownMax = 7.5
	self.idleState.randomEvents = { { name = "idlespecial01", time = 6.0, interruptible = true, chance = 0.5 },
									{ name = "idlespecial02", time = 6.0, interruptible = true, chance = 0.5 } }
	
	-- Roam
	self.roamTimer = Timer()
	self.roamTimer:start( math.random( RoamStartTimeMin, RoamStartTimeMax ) )
	self.roamState = self.unit:createState( "roam" )
	self.roamState.debugName = "roam"
	self.roamState.tetherPosition = self.unit.character.worldPosition
	self.roamState.roamCenterOffset = 0.0
		
	-- Pathing
	self.pathingState = PathingState()
	self.pathingState:sv_onCreate( self.unit )
	self.pathingState:sv_setMovementType( "walk" )
	self.pathingState.debugName = "pathingState"
	
	-- Attacks
	self.attackState01 = self.unit:createState( "meleeAttack" )
	self.attackState01.meleeType = melee_farmbotswipe
	self.attackState01.event = "kick"
	self.attackState01.damage = 10
	self.attackState01.attackRange = 2.7
	self.attackState01.animationCooldown = 1.0 * 40
	self.attackState01.attackCooldown = 6.0 * 40
	self.attackState01.globalCooldown = 0.0 * 40
	self.attackState01.attackDelay = 0.375 * 40
	self.attackState01.power = 10000.0
	
	self.attackState02 = self.unit:createState( "meleeAttack" )
	self.attackState02.meleeType = melee_farmbotswipe
	self.attackState02.event = "walkingswipe"
	self.attackState02.damage = 35
	self.attackState02.attackRange = 3.75
	self.attackState02.animationCooldown = 1.86 * 40
	self.attackState02.attackCooldown = 3.0 * 40
	self.attackState02.globalCooldown = 0.0 * 40
	self.attackState02.attackDelay = 0.75 * 40

	self.attackState03 = self.unit:createState( "meleeAttack" )
	self.attackState03.meleeType = melee_farmbotswipe
	self.attackState03.event = "standingswipe"
	self.attackState03.damage = 35
	self.attackState03.attackRange = 3.75
	self.attackState03.animationCooldown = 1.86 * 40
	self.attackState03.attackCooldown = 1.75 * 40
	self.attackState03.globalCooldown = 0.0 * 40
	self.attackState03.attackDelay = 0.75 * 40
	
	self.attackPartState = self.unit:createState( "meleeAttack" )
	self.attackPartState.meleeType = melee_farmbotbreach
	self.attackPartState.event = "breachattack"
	self.attackPartState.damage = 60
	self.attackPartState.attackRange = 3.75
	self.attackPartState.animationCooldown = 3.66 * 40
	self.attackPartState.attackCooldown = 4.5 * 40
	self.attackPartState.globalCooldown = 5.0 * 40
	self.attackPartState.attackDelay = 1.55 * 40

	self.attackState05 = self.unit:createState( "meleeAttack" )
	self.attackState05.meleeType = melee_farmbotswipe
	self.attackState05.event = "runningswipe"
	self.attackState05.damage = 35
	self.attackState05.attackRange = 3.75
	self.attackState05.animationCooldown = 1.86 * 40
	self.attackState05.attackCooldown = 8.0 * 40
	self.attackState05.globalCooldown = 0.0 * 40
	self.attackState05.attackDelay = 0.75 * 40
	
	-- Combat
	self.combatAttackState = CombatAttackState()
	self.combatAttackState:sv_onCreate( self.unit )
	self.combatAttackState.debugName = "combatAttackState"
	self.stateTicker:addState( self.combatAttackState )
	self.combatAttackState:sv_addAttack( self.attackState03 )
	
	-- CombatFollow
	self.combatFollowAttackState = CombatFollowAttackState()
	self.combatFollowAttackState:sv_onCreate( self.unit )
	self.combatFollowAttackState.debugName = "combatFollowAttackState"
	self.stateTicker:addState( self.combatFollowAttackState )
	self.combatFollowAttackState:sv_addAttack( self.attackState01 )
	self.combatFollowAttackState:sv_addAttack( self.attackState02 )

	-- CombatChase
	self.combatChaseAttackState = CombatFollowAttackState()
	self.combatChaseAttackState:sv_onCreate( self.unit )
	self.combatChaseAttackState:sv_setMovementType( "sprint" )
	self.combatChaseAttackState.debugName = "combatChaseAttackState"
	self.stateTicker:addState( self.combatFollowAttackState )
	self.combatChaseAttackState:sv_addAttack( self.attackState05 )
	
	-- Breach
	self.breachState = BreachState()
	self.breachState:sv_onCreate( self.unit, math.ceil( 40 * 2.0 ) )
	self.breachState.debugName = "breachState"
	self.stateTicker:addState( self.breachState )
	self.breachState:sv_setBreachRange( CombatAttackRange )
	self.breachState:sv_setBreachLevel( MeleeBreachLevel )
	self.breachState:sv_addAttack( self.attackPartState )
	
	-- Aim in
	self.aimInEventState = self.unit:createState( "wait" )
	self.aimInEventState.debugName = "aimInEventState"
	self.aimInEventState.time = 1.0
	self.aimInEventState.interruptible = false
	self.aimInEventState.name = "aimIn"

	-- RangedAttackWait
	self.rangedWaitState = self.unit:createState( "wait" )
	self.rangedWaitState.debugName = "rangedAttackWait"
	self.rangedWaitState.time = 2.0
	self.rangedWaitState.interruptible = false

	-- RangedAttack
	self.rangedAttack = self.unit:createState( "rangedAttack" )
	self.rangedAttack.debugName = "rangedAttack"
	self.rangedAttack.spreadAngle = 5.0
	self.rangedAttack.cooldown = 1.0
	self.rangedAttack.aimTime = 0.0
	self.rangedAttack.projectile = projectile_pesticide
	self.rangedAttack.event = "shoot"
	self.rangedAttack.damage = 4
	self.rangedAttack.offset = sm.vec3.new( -0.75, 1.0, 1.25 )
	self.rangedAttack.velocity = 16
	self.rangedAttack.preferHighAngle = true
	self.rangedAttack.delay = 12

	-- Aim out
	self.aimOutEventState = self.unit:createState( "wait" )
	self.aimOutEventState.debugName = "aimOutEventState"
	self.aimOutEventState.time = 1.0
	self.aimOutEventState.interruptible = false
	self.aimOutEventState.name = "aimOut"
	
	self.rangedStates = { self.aimInEventState, self.rangedAttack, self.aimOutEventState, self.rangedWaitState }

	-- Destroyed
	self.destroyedEventState = self.unit:createState( "wait" )
	self.destroyedEventState.debugName = "destroyedState"
	self.destroyedEventState.time = DeathExplosionTime
	self.destroyedEventState.interruptible = false
	self.destroyedEventState.name = "explode"
	
	-- Angry
	self.angryEventState = self.unit:createState( "wait" )
	self.angryEventState.debugName = "angryState"
	self.angryEventState.time = 3.0
	self.angryEventState.interruptible = false
	self.angryEventState.name = "angry"

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
	initCrushing( self, 20 )
	
	-- Stomp
	self.stompTimer = Timer()
	self.stompTimer:start( 0.375 * 40 )
	
	-- Chase timer
	self.chaseTicks = 0
	
	self.currentState = self.idleState
	self.currentState:start()

	-- Voice
	self.voiceTimer = Timer()
	self.voiceTimer:start( math.random( VoiceTickTimeMin, VoiceTickTimeMax ) )
	
	print( "-- FarmbotUnit created --" )
end

function FarmbotUnit.server_onRefresh( self )
	print( "-- FarmbotUnit refreshed --" )
end

function FarmbotUnit.server_onDestroy( self )
	print( "-- FarmbotUnit terminated --" )
end

function FarmbotUnit.server_onFixedUpdate( self, dt )
	if sm.exists( self.unit ) and not self.destroyed then
		if self.saved.deathTickTimestamp and sm.game.getCurrentTick() >= self.saved.deathTickTimestamp then
			self.unit:destroy()
			self.destroyed = true
			return
		end
	end
	
	if not sm.exists( self.unit ) then
		return
	end
	
	self.stateTicker:tick()
	
	if updateCrushing( self ) then
		print("'FarmbotUnit' was crushed!")
		self:sv_onDeath()
	end
	
	updateTumble( self )
	
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
		
		self:updateAim( dt )
		self.currentState:onFixedUpdate( dt )
	
		self.unit:setMovementDirection( self.currentState:getMovementDirection() )
		local currentMovementType = self.currentState:getMovementType()
		self.unit:setMovementType( currentMovementType )
		self.unit:setFacingDirection( self.currentState:getFacingDirection() )
		
		if self.currentState == self.idleState then
			self.roamTimer:tick()
		end
		
		if self.isInCombat then
			self.combatTimer:tick()
		end
		
		self.impactCooldownTicks = math.max( self.impactCooldownTicks - 1, 0 )
		
		if self.currentState == self.combatFollowAttackState or self.currentState == self.combatChaseAttackState or self.currentState == self.pathingState then
			self.stompTimer:tick()
			if self.stompTimer:done() then
				self.stompTimer:reset()
				sm.melee.meleeAttack( melee_farmbotstep, 3, self.unit.character.worldPosition + self.unit.character.direction * 0.875 - sm.vec3.new( 0, 0, self.unit.character:getHeight() * 0.375 ), self.unit.character.direction * 1.75, self.unit, 0, 4000 )
			end
		else
			self.stompTimer:reset()
		end
		
		self.chaseTicks = math.max( self.chaseTicks - 1, 0 )
		
		self.voiceTimer:tick()
		if self.voiceTimer:done() then
			self.voiceTimer:start( math.random( VoiceTickTimeMin, VoiceTickTimeMax ) )
			local effectParams = {}
			if not self.isInCombat then
				if currentMovementType == "stand" then
					effectParams.Voice = 1
				else
					effectParams.Voice = 2
				end
			else
				if currentMovementType == "stand" then
					effectParams.Voice = 3
				elseif currentMovementType == "walk" then
					effectParams.Voice = 4
				elseif currentMovementType == "sprint" then
					effectParams.Voice =  5
				end
			end
			sm.event.sendToCharacter( self.unit.character, "sv_e_characterEffect", { effectName = "Farmbot - Voice", effectParams = effectParams } )
		end
	end
	
	-- Update target for character
	if self.target ~= self.previousTarget then
		self:sv_updateCharacterTarget()
		self.previousTarget = self.target
	end
end

function FarmbotUnit.server_onCharacterChangedColor( self, color )
	if self.saved.color ~= color then
		self.saved.color = color
		self.storage:save( self.saved )
	end
end

function FarmbotUnit.updateAim( self, dt )
	self.canShootTarget = false
	if self.target and sm.exists( self.target ) and type( self.target ) == "Character" and not self.target:isDowned() then
		local success, aimPoint = sm.ai.getAimPosition( self.unit.character, self.target, FireRange, FireLaneWidth )
		if success then
			-- Predict target movement from its velocity
			local distanceToTarget = ( aimPoint - self.unit.character.worldPosition ):length()
			local predictionScale = distanceToTarget / math.max( self.rangedAttack.velocity, 1.0 )
			self.rangedAttack.aimPoint = aimPoint + self.predictedVelocity * predictionScale
		elseif self.lastAimPosition then
			self.rangedAttack.aimPoint = self.lastAimPosition
		end
		self.canShootTarget = success
		self.lastAimPosition = self.rangedAttack.aimPoint
	elseif self.lastAimPosition then
		self.rangedAttack.aimPoint = self.lastAimPosition
	end
	return false
end

function FarmbotUnit.server_onUnitUpdate( self, dt )
	
	if not sm.exists( self.unit ) then
		return
	end

	if self.saved.stats.hp <= 0 and self.currentState ~= self.destroyedEventState then
		self:sv_onDeath()
	end

	if self.unit.character:isTumbling() and self.currentState ~= self.destroyedEventState then
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
	if self.saved.raider or ( not closestVisibleWormCharacter and not closestVisibleWocCharacter and not closestVisiblePlayerCharacter and not closestHeardPlayerCharacter ) then
		closestVisibleCrop = sm.ai.getClosestVisibleCrop( self.unit )
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
	
	local inFireRange = false
	local atUnreachableHeight = false
	local inCombatFollowRange = false
	local inCombatAttackRange = false
	local inSprintRange = false
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

		inFireRange = fromToTarget:length() - targetRadius <= FireRange
		inCombatFollowRange = fromToTarget:length() - targetRadius <= CombatFollowRange
		inCombatAttackRange = fromToTarget:length() - targetRadius <= CombatAttackRange
		inSprintRange = fromToTarget:length() - targetRadius >= SprintRange
		
		local flatFromToTarget = sm.vec3.new( fromToTarget.x, fromToTarget.y, 0 )
		flatFromToTarget = ( flatFromToTarget:length() >= FLT_EPSILON ) and flatFromToTarget:normalize() or self.unit.character.direction
		local flatDesiredDirection = sm.vec3.new( desiredDirection.x, desiredDirection.y, 0 )
		flatDesiredDirection = ( flatDesiredDirection:length() >= FLT_EPSILON ) and flatDesiredDirection:normalize() or self.unit.character.direction
		
		local pitchAngle = math.deg( math.acos( flatFromToTarget:dot( fromToTarget:normalize() ) ) )
		atUnreachableHeight = pitchAngle >= RangedPitchAngle and math.abs( fromToTarget.z ) >= RangedHeightDiff

		self.combatAttackState:sv_setAttackDirection( flatDesiredDirection ) -- Turn ongoing attacks toward moving players
	end

	-- Chase far-away targets
	if self.currentState ~= self.angryEventState and inSprintRange then
		self.chaseTicks = ChaseTickTime
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
	local breachStatic = false
	if self.isInCombat then
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
		
		if nextTargetPosition then
			local breachDepth = 0.25
			local leveledNextTargetPosition = sm.vec3.new( nextTargetPosition.x, nextTargetPosition.y, self.unit.character.worldPosition.z )
			local valid, breachPosition, breachObject = sm.ai.getBreachablePosition( self.unit, leveledNextTargetPosition, breachDepth + self.unit.character:getRadius(), MeleeBreachLevel )
			if valid and breachPosition then
				local flatFromToNextTarget = leveledNextTargetPosition
				flatFromToNextTarget.z = 0
				if flatFromToNextTarget:length() <= 0 then
					flatFromToNextTarget = sm.vec3.new(0, 1, 0 )
				end
				breachDestination = nextTargetPosition + flatFromToNextTarget:normalize() * ( breachDepth + self.unit.character:getRadius() )
				if ( type( breachObject ) == "Lift" or type( breachObject ) == "Harvestable" ) and sm.exists( breachObject ) then
					breachStatic = true
				elseif type( breachObject ) == "Shape" and sm.exists( breachObject ) then
					breachStatic = breachObject.body:isStatic()
				end
			end
		else
			self.isInCombat = false
		end
	end
	
	-- Check ranged option
	if self.lastAimPosition == nil and self.lastTargetPosition then
		self.lastAimPosition = self.lastTargetPosition
	end
	local shouldShoot = ( inFireRange and atUnreachableHeight and self.canShootTarget )

	local done, result = self.currentState:isDone()
	local abortState = 	( self.currentState ~= self.destroyedEventState and self.currentState ~= self.angryEventState and self.currentState ~= self.combatAttackState ) and
						( not isAnyOf( self.currentState, self.rangedStates ) ) and
						(
							( shouldShoot ) or 
							( self.currentState == self.pathingState and ( inCombatFollowRange or inCombatAttackRange ) and self.isInCombat ) or 
							( prevInCombat and self.combatTimer:done() ) or
							( self.currentState == self.pathingState and breachDestination ) or
							( self.currentState == self.breachState and directPath  ) or
							( self.chaseTicks > 0 and inSprintRange and self.currentState ~= self.combatChaseAttackState ) or
							( self.currentState == self.combatChaseAttackState and self.chaseTicks <= 0 ) or
							( self.currentState == self.lookAtState and self.isInCombat ) or
							( self.currentState == self.roamState and heardNoise )
						)
	if ( done or abortState ) then
		if self.currentState == self.destroyedEventState then
			print("'FarmbotUnit' destroyed!")
			self:sv_onDeath()
		elseif self.currentState == self.aimInEventState then
			-- Fire projectiles
			self.currentState = self.rangedAttack
		elseif self.currentState == self.rangedAttack then
			if self.rangedAttack.shotsFired >= ShotsPerBarrage then
				-- Wait for the next barrage
				self.currentState = self.rangedWaitState
			end
		elseif self.currentState == self.rangedWaitState then
			if shouldShoot then
				-- Fire projectiles
				self.currentState = self.rangedAttack
			else
				-- Stop aiming
				self.currentState = self.aimOutEventState
				self.lastAimPosition = nil
			end
		elseif self.currentState == self.pathingState and result == "failed" then
			self.lookAtState.desiredDirection = -self.unit.character.direction
			self.lookAtState.desiredPosition = self.unit.character.worldPosition
			self.currentState = self.lookAtState
			self.roamTimer:start( math.random( RoamStartTimeMin, RoamStartTimeMax ) )
		elseif self.isInCombat and not prevInCombat then
			self.currentState = self.angryEventState
			self.chaseTicks = ChaseTickTime
		elseif shouldShoot then
			-- Start aiming
			self.currentState = self.aimInEventState
		elseif breachDestination and ( breachStatic or self.target == nil ) then
			-- Start breaching path obstacle
			self.breachState:sv_setDestination( breachDestination )
			self.currentState = self.breachState
		elseif self.isInCombat then
			-- Select combat state
			
			if self.target and self.chaseTicks > 0 then
				self.combatChaseAttackState:sv_setTarget( self.target )
				self.currentState = self.combatChaseAttackState
			elseif self.target and inCombatAttackRange then
				self.currentState = self.combatAttackState
			elseif self.target and inCombatFollowRange then
				self.combatFollowAttackState:sv_setTarget( self.target )
				self.currentState = self.combatFollowAttackState
			elseif self.lastTargetPosition then
				if self.currentState ~= self.pathingState then
					self.pathingState:sv_setDestination( self.lastTargetPosition )
				end
				self.currentState = self.pathingState
				self.lastTargetPosition = nil
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

function FarmbotUnit.sv_e_worldEvent( self, params )
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

function FarmbotUnit.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
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

function FarmbotUnit.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
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
		if self.eventTarget == nil then
			self.eventTarget = attackingCharacter
		end
		local effectRotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), -hitDirection )
		sm.effect.playEffect( "Sledgehammer - NoProgress", hitPos, nil, effectRotation )
		if teamOpponent then
			local impact = hitDirection * 6
			self:sv_takeDamage( damage, impact, hitPos )
		end
	end
end

function FarmbotUnit.server_onExplosion( self, center, destructionLevel )
	if not sm.exists( self.unit ) then
		return
	end
	local impact = ( self.unit:getCharacter().worldPosition - center ):normalize() * 6
	self:sv_takeDamage( self.saved.stats.maxhp * ( destructionLevel / 10 ), impact, self.unit:getCharacter().worldPosition )
end

function FarmbotUnit.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal  )	
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

	local collisionDamageMultiplier = 4.0 -- 4x collision damage. 1/4 maxhp to CharacterCollision for fall damage calculation.
	local damage, tumbleTicks, tumbleVelocity, impactReaction = CharacterCollision( self.unit.character, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal, self.saved.stats.maxhp / collisionDamageMultiplier )
	damage = damage * collisionDamageMultiplier
	if damage > 0 or tumbleTicks > 0 then
		self.impactCooldownTicks = 6
	end
	if damage > 0 then
		print("'FarmbotUnit' took", damage, "collision damage")
		self:sv_takeDamage( damage, collisionNormal, collisionPosition )
	end
	if tumbleTicks > 0 then
		if self.currentState ~= self.destroyedEventState then
			self.unit:sendCharacterEvent( "tumble" )
			if startTumble( self, tumbleTicks, self.idleState, tumbleVelocity ) then
				if type( other ) == "Shape" and sm.exists( other ) and other.body:isDynamic() then
					sm.physics.applyImpulse( other.body, impactReaction * other.body.mass, true, collisionPosition - other.body.worldPosition )
				end
			end
		end
	end
end

function FarmbotUnit.sv_updateCharacterTarget( self )
	if self.unit.character then
		sm.event.sendToCharacter( self.unit.character, "sv_e_updateTarget", { target = self.target } )
	end
end

function FarmbotUnit.sv_takeDamage( self, damage, impact, hitPos )
	if self.saved.stats.hp > 0 then
		self.saved.stats.hp = self.saved.stats.hp - damage
		self.saved.stats.hp = math.max( self.saved.stats.hp, 0 )
		print( "'FarmbotUnit' received:", damage, "damage.", self.saved.stats.hp, "/", self.saved.stats.maxhp, "HP" )
		local effectRotation = sm.quat.identity()
		if hitPos and impact and impact:length() >= FLT_EPSILON then
			effectRotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), -impact:normalize() )
		end
		sm.effect.playEffect( "Farmbot - Hit", hitPos, nil, effectRotation )

		if self.saved.stats.hp <= 0 then
			self.unit.character:setTumbling( false )
			startTumble( self, self.destroyedEventState.time * 40, self.destroyedEventState, self.unit.character.velocity + sm.vec3.new( 0, 0, 2.5 ) )
		else
			self.storage:save( self.saved )
		end
	end
end

function FarmbotUnit.sv_onDeath( self )
	local character = self.unit:getCharacter()
	if not self.destroyed then
		g_unitManager:sv_addDeathMarker( character.worldPosition )
		self.saved.stats.hp = 0
		self.unit:destroy()
		print("'FarmbotUnit' killed!")
		-- Create explosion
		sm.physics.explode( character.worldPosition, 7, 2, 6, 25, "Farmbot - Destroyed", nil, { Color = self.unit.character:getColor() } )
		self.unit:sendCharacterEvent( "death" )
		if SurvivalGame then
			local loot = SelectLoot( "loot_farmbot" )
			SpawnLoot( self.unit, loot )
		end
		self.destroyed = true
	end
end

function FarmbotUnit.sv_e_receiveTarget( self, params )
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
