dofile "$SURVIVAL_DATA/Scripts/game/units/unit_util.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Ticker.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_units.lua"
dofile "$SURVIVAL_DATA/Scripts/game/units/states/PathingState.lua"
dofile "$SURVIVAL_DATA/Scripts/game/units/states/BreachState.lua"
dofile "$SURVIVAL_DATA/Scripts/game/units/states/CombatAttackState.lua"
dofile "$SURVIVAL_DATA/Scripts/game/units/states/CircleFollowState.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"

HaybotUnit = class( nil )

local WaterTumbleTickTime = 3.0 * 40
local AllyRange = 20.0
local MeleeBreachLevel = 9
local HearRange = 40.0

function HaybotUnit.server_onCreate( self )
	
	self.target = nil
	self.previousTarget = nil
	self.lastTargetPosition = nil
	self.ambushPosition = nil
	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = {}
	end
	if self.saved.stats == nil then
		self.saved.stats = { hp = 100, maxhp = 100 }
	end

	if g_eventManager then
		self.tileStorageKey = g_eventManager:sv_getTileStorageKeyFromObject( self.unit.character )
	end

	if self.params then
		if self.params.tetherPoint then
			self.homePosition = self.params.tetherPoint
			if self.params.ambush == true then
				self.ambushPosition = self.params.tetherPoint
			end
			if self.params.raider == true then
				self.saved.raidPosition = self.params.tetherPoint
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
	
	self.stateTicker = Ticker()
	self.stateTicker:init()
	
	self.allyUnits = {}

	-- Idle	
	self.idleState = self.unit:createState( "idle" )
	self.idleState.debugName = "idleState"
	self.idleState.randomEventCooldownMin = 4
	self.idleState.randomEventCooldownMax = 6
	self.idleState.randomEvents = { { name = "idlespecial01", time = 4.0, interruptible = true, chance = 0.5 },
									{ name = "idlespecial02", time = 7.5, interruptible = true, chance = 0.5 } }
	
	-- Stagger
	self.staggeredEventState = self.unit:createState( "wait" )
	self.staggeredEventState.debugName = "staggeredState"
	self.staggeredEventState.time = 0.25
	self.staggeredEventState.interruptible = false
	self.stagger = 0.0
	self.staggerProjectile = 0.5
	self.staggerMelee = 1.0
	self.staggerCooldownTickTime = 1.65 * 40
	self.staggerCooldownTicks = 0
	
	-- Circle follow
	self.circleFollowState = CircleFollowState()
	self.circleFollowState:sv_onCreate( self.unit, 3.7, 7.0, 20.0, 40 * 2, 40 * 10, 40 * 1.5, 40 * 3.5, 40 * 1.0, 40 * 2.0 )

	-- Roam
	self.roamStartTimeMin = 40 * 4 -- 4 seconds
	self.roamStartTimeMax = 40 * 8 -- 8 seconds
	self.roamTimer = Timer()
	self.roamTimer:start( math.random( self.roamStartTimeMin, self.roamStartTimeMax ) )
	self.roamState = self.unit:createState( "roam" )
	self.roamState.debugName = "roam"
	self.roamState.tetherPosition = self.unit.character.worldPosition
	self.roamState.roamCenterOffset = 0.0

	-- Pathing
	self.pathingState = PathingState()
	self.pathingState:sv_onCreate( self.unit )
	self.pathingState:sv_setTolerance( 1.0 )
	self.pathingState:sv_setMovementType( "sprint" )
	
	-- Attacks
	self.attackState01 = self.unit:createState( "meleeAttack" )
	self.attackState01.meleeType = melee_haybotpitchforkswipe
	self.attackState01.event = "attack01"
	self.attackState01.damage = 30
	self.attackState01.attackRange = 1.75
	self.attackState01.animationCooldown = 1.65 * 40
	self.attackState01.attackCooldown = 0.25 * 40
	self.attackState01.globalCooldown = 0.0 * 40
	self.attackState01.attackDelay = 0.25 * 40
	
	self.attackState02 = self.unit:createState( "meleeAttack" )
	self.attackState02.meleeType = melee_haybotpitchfork
	self.attackState02.event = "attack02"
	self.attackState02.damage = 20
	self.attackState02.attackRange = 1.75
	self.attackState02.animationCooldown = 0.825 * 40
	self.attackState02.attackCooldown = 2.0 * 40
	self.attackState02.globalCooldown = 0.0 * 40
	self.attackState02.attackDelay = 0.25 * 40
	
	self.attackState03 = self.unit:createState( "meleeAttack" )
	self.attackState03.meleeType = melee_haybotpitchfork
	self.attackState03.event = "attack03"
	self.attackState03.damage = 20
	self.attackState03.attackRange = 1.75
	self.attackState03.animationCooldown = 0.925 * 40
	self.attackState03.attackCooldown = 2.0 * 40
	self.attackState03.globalCooldown = 0.0 * 40
	self.attackState03.attackDelay = 0.25 * 40
	
	self.attackStateSprint01 = self.unit:createState( "meleeAttack" )
	self.attackStateSprint01.meleeType = melee_haybotpitchfork
	self.attackStateSprint01.event = "sprintattack01"
	self.attackStateSprint01.damage = 20
	self.attackStateSprint01.attackRange = 1.75
	self.attackStateSprint01.animationCooldown = 0.8 * 40
	self.attackStateSprint01.attackCooldown = 3.0 * 40
	self.attackStateSprint01.globalCooldown = 0.0 * 40
	self.attackStateSprint01.attackDelay = 0.3 * 40	
	
	-- Combat
	self.combatAttackState = CombatAttackState()
	self.combatAttackState:sv_onCreate( self.unit )
	self.stateTicker:addState( self.combatAttackState )
	-- self.combatAttackState:sv_addAttack( self.attackState01 )
	self.combatAttackState:sv_addAttack( self.attackState02 )
	self.combatAttackState:sv_addAttack( self.attackState03 )
	--self.combatAttackState:sv_addAttack( self.attackStateSprint01 )
	self.combatRange = 1.0 -- Range where the unit will perform attacks
	
	self.combatTicks = 0
	self.combatTicksAttack = 20 * 40
	self.combatTicksBerserk = 50 * 40
	self.combatTicksAttackCost = 20 * 40

	self.nextFakeAggroMin = 4 * 40
	self.nextFakeAggroMax = 6 * 40
	self.nextFakeAggro = math.random( self.nextFakeAggroMin, self.nextFakeAggroMax )
	
	self.nextAggroMin = 10 * 40
	self.nextAggroMax = 16 * 40
	self.nextAggro = math.random( self.nextAggroMin, self.nextAggroMax )
	
	-- Breach
	self.breachState = BreachState()
	self.breachState:sv_onCreate( self.unit, math.ceil( 40 * 2.0 ) )
	self.stateTicker:addState( self.breachState )
	self.breachState:sv_setBreachRange( self.combatRange )
	self.breachState:sv_setBreachLevel( MeleeBreachLevel )
	--self.breachState:sv_addAttack( self.attackState02 )
	self.breachState:sv_addAttack( self.attackState03 )
	
	-- Combat approach
	self.combatApproachState = self.unit:createState( "positioning" )
	self.combatApproachState.debugName = "combatApproachState"
	self.combatApproachState.timeout = 0.5
	self.combatApproachState.tolerance = self.combatRange
	self.combatApproachState.avoidance = false
	self.combatApproachState.movementType = "sprint"
	self.pathingCombatRange = 2.0 -- Range where the unit will approach the player without obstacle checking
	
	-- Avoid
	self.avoidState = self.unit:createState( "positioning" )
	self.avoidState.debugName = "avoid"
	self.avoidState.timeout = 1.5
	self.avoidState.tolerance = 0.5
	self.avoidState.avoidance = false
	self.avoidState.movementType = "sprint"
	self.avoidCount = 0
	self.avoidLimit = 3

	-- LookAt
	self.lookAtState = self.unit:createState( "positioning" )
	self.lookAtState.debugName = "lookAt"
	self.lookAtState.timeout = 3.0
	self.lookAtState.tolerance = 0.5
	self.lookAtState.avoidance = false
	self.lookAtState.movementType = "stand"
	
	-- Swim
	self.swimState = self.unit:createState( "followDirection" )
	self.swimState.debugName = "swim"
	self.swimState.avoidance = false
	self.swimState.movementType = "walk"
	self.lastStablePosition = nil

	-- Tumble
	initTumble( self )
	
	-- Crushing
	initCrushing( self, DEFAULT_CRUSH_TICK_TIME )
	
	-- Flee
	self.dayFlee = self.unit:createState( "flee" )
	self.dayFlee.movementAngleThreshold = math.rad( 180 )
	self.dayFlee.maxFleeTime = 0.0
	self.dayFlee.maxDeviation = 45 * math.pi / 180
	
	self.griefTimer = Timer()
	self.griefTimer:start( 40 * 9.0 )
	
	self.currentState = self.idleState
	self.currentState:start()
	
end

function HaybotUnit.server_onRefresh( self )
	print( "-- HaybotUnit refreshed --" )
end

function HaybotUnit.server_onDestroy( self )
	print( "-- HaybotUnit terminated --" )
end

function HaybotUnit.server_onFixedUpdate( self, dt )
	if sm.exists( self.unit ) and not self.destroyed then
		if self.saved.deathTickTimestamp and sm.game.getCurrentTick() >= self.saved.deathTickTimestamp then
			self.unit:destroy()
			self.destroyed = true
			return
		end
	end
	
	self.stateTicker:tick()
	
	if updateCrushing( self ) then
		print("'HaybotUnit' was crushed!")
		self:sv_onDeath( sm.vec3.new( 0, 0, 0 ) )
	end
	
	updateTumble( self )
	updateAirTumble( self, self.idleState )
	
	self.griefTimer:tick()

	local currentTargetPosition
	if self.target and sm.exists( self.target ) then
		currentTargetPosition = self.target.worldPosition
	else
		self.avoidCount = 0
	end
	if self.currentState then
		self.currentState:onFixedUpdate( dt )
	
		self.unit:setMovementDirection( self.currentState:getMovementDirection() )
		self.unit:setMovementType( self.currentState:getMovementType() )
		if self.currentState ~= self.swimState then
			if currentTargetPosition and self.currentState ~= self.combatAttackState and self.currentState ~= self.breachState and self.currentState ~= self.avoidState and self.currentState ~= self.dayFlee then
				self.unit:setFacingDirection( ( currentTargetPosition - self.unit.character.worldPosition ):normalize() )
			else
				self.unit:setFacingDirection( self.currentState:getFacingDirection() )
			end
		end
		
		-- Random roaming during idle
		if self.currentState == self.idleState then
			self.roamTimer:tick()
		end
		
		-- Always aggro when next to the target
		local closeCombat = false
		if self.target and sm.exists( self.target ) then
			local fromToTarget = self.target.worldPosition - self.unit.character.worldPosition
			local distance = fromToTarget:length()
			if type( self.target ) == "Character" then
				distance = distance - self.target:getRadius()
			end
			if distance <= self.pathingCombatRange then
				closeCombat = true
			end
		end
		
		-- Decrease aggro with time
		self.combatTicks = math.max( self.combatTicks - 1, closeCombat and 1 or 0 )
		
		self.staggerCooldownTicks = math.max( self.staggerCooldownTicks - 1, 0 )
		self.impactCooldownTicks = math.max( self.impactCooldownTicks - 1, 0 )
		
		-- Occasionally add random aggro for fakeouts and small attacks
		if self.currentState == self.circleFollowState then
			-- Real attack
			self.nextAggro = self.nextAggro - 1
			if self.nextAggro <= 0 then
				self.nextAggro = math.random( self.nextAggroMin, self.nextAggroMax )
				self.combatTicks = math.max( self.combatTicks, self.combatTicksAttack )
			end

			-- Fake attack
			self.nextFakeAggro = self.nextFakeAggro - 1
			if self.nextFakeAggro <= 0 then
				self.nextFakeAggro = math.random( self.nextFakeAggroMin, self.nextFakeAggroMax )
				self.circleFollowState:sv_rush( 16 ) -- Sprint toward target during the given tick time
				self.avoidCount = 0
			end
		end
		
	end
	
	-- Update target for haybot character
	if self.target ~= self.previousTarget then
		self:sv_updateCharacterTarget()
		self.previousTarget = self.target
	end
end

function HaybotUnit.server_onCharacterChangedColor( self, color )
	if self.saved.color ~= color then
		self.saved.color = color
		self.storage:save( self.saved )
	end
end

function HaybotUnit.server_onUnitUpdate( self, dt )
	
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
	local currentTargetPosition
	
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
	
	local restartPathing = false
	
	self.allyUnits = {}
	for _, allyUnit in ipairs( sm.unit.getAllUnits() ) do
		if sm.exists( allyUnit ) and self.unit ~= allyUnit and allyUnit.character and isAnyOf( allyUnit.character:getCharacterType(), g_robots ) and InSameWorld( self.unit, allyUnit) then
			if ( allyUnit.character.worldPosition - self.unit.character.worldPosition ):length() <= AllyRange then
				local sameTeam = true
				if not SurvivalGame then
					sameTeam = InSameTeam( allyUnit, self.unit )
				end
				if sameTeam then
					self.allyUnits[#self.allyUnits+1] = allyUnit
				end
			end
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
		for _, allyUnit in ipairs( self.allyUnits ) do
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
	
	local prevState = self.currentState
	if self.unit.character:isOnGround() and not self.unit.character:isSwimming() then
		self.lastStablePosition = self.unit.character.worldPosition
	end
	
	local inCombatApproachRange = false
	local inCombatAttackRange = false
	if self.target then
		currentTargetPosition = self.target.worldPosition
		if type( self.target ) == "Harvestable" then
			currentTargetPosition = self.target.worldPosition + sm.vec3.new( 0, 0, self.unit.character:getHeight() * 0.5 )
		end
		local fromToTarget = self.target.worldPosition - self.unit.character.worldPosition
		local distance = fromToTarget:length()
		if type( self.target ) == "Character" then
			distance = distance - self.target:getRadius()
		end
		inCombatApproachRange = distance <= self.pathingCombatRange
		inCombatAttackRange = distance <= self.combatRange

		self.combatAttackState:sv_setAttackDirection( fromToTarget:normalize() ) -- Turn ongoing attacks toward moving players
		self.lastTargetPosition = currentTargetPosition
		
		self.combatApproachState.desiredPosition = currentTargetPosition
		self.combatApproachState.desiredDirection = fromToTarget:normalize()
		self.attackState01.attackDirection = fromToTarget:normalize()
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
	
	-- Find dangerous obstacles
	local shouldAvoid = false
	local closestDangerShape, _ = g_unitManager:sv_getClosestDangers( self.unit.character.worldPosition )
	if closestDangerShape then
		local fromToDanger = closestDangerShape.worldPosition - self.unit.character.worldPosition
		local distance = fromToDanger:length()
		if distance <= 3.5 and ( ( self.target and self.avoidCount < self.avoidLimit ) or self.target == nil ) then
			self.avoidState.desiredPosition = self.unit.character.worldPosition - fromToDanger:normalize() * 2
			self.avoidState.desiredDirection = fromToDanger:normalize()
			shouldAvoid = true
		end
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
		local flatFromToAmbush = sm.vec3.new( self.ambushPosition.x,  self.ambushPosition.y, self.unit.character.worldPosition.z ) - self.unit.character.worldPosition
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

	-- Check for direct path
	local directPath
	if self.lastTargetPosition then
		local directPathDistance = 7.0 
		local fromToTarget = self.lastTargetPosition - self.unit.character.worldPosition
		local distance = fromToTarget:length()
		if distance <= directPathDistance then
			directPath = sm.ai.directPathAvailable( self.unit, self.lastTargetPosition, directPathDistance )
		end
	end
	
	local combatPathing = self.combatTicks > 0 or ( #self.allyUnits >= 2 and self.lastTargetPosition ) or closestVisibleCrop or closestVisibleWormCharacter
	-- Auto aggressive behaviour if the target is close, but unreachable
	if directPath == false and self.lastTargetPosition and not combatPathing then
		combatPathing = true
	end
	
	-- Update pathingState destination and condition
	local pathingConditions = { { variable = sm.pathfinder.conditionProperty.target, value = ( self.lastTargetPosition and 1 or 0 ) } }
	self.pathingState:sv_setConditions( pathingConditions )
	if self.currentState == self.pathingState then
		if currentTargetPosition then
			self.pathingState:sv_setDestination( currentTargetPosition )
		elseif self.lastTargetPosition then
			self.pathingState:sv_setDestination( self.lastTargetPosition )
		end
	end
	
	-- Breach check
	local breachDestination = nil
	if combatPathing then
		local nextTargetPosition
		if currentTargetPosition then
			nextTargetPosition = currentTargetPosition
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
			local valid, breachPosition = sm.ai.getBreachablePosition( self.unit, leveledNextTargetPosition, breachDepth, MeleeBreachLevel )
			if valid and breachPosition then
				local flatFromToNextTarget = leveledNextTargetPosition
				flatFromToNextTarget.z = 0
				if flatFromToNextTarget:length() <= 0 then
					flatFromToNextTarget = sm.vec3.new(0, 1, 0 )
				end
				breachDestination = nextTargetPosition + flatFromToNextTarget:normalize() * breachDepth
			end
		else
			self.combatTicks = 0
			combatPathing = false
		end
	end
	
	local done, result = self.currentState:isDone()
	local abortState = 	( self.currentState ~= self.combatAttackState ) and
						( self.currentState ~= self.attackState01 ) and
						( self.currentState ~= self.avoidState ) and
						(
							( self.currentState == self.pathingState and ( inCombatApproachRange or inCombatAttackRange ) and combatPathing ) or
							( breachDestination and self.currentState ~= self.breachState ) or
							( directPath and self.currentState == self.breachState ) or
							foundTarget or
							shouldAvoid or
							self.unit.character:isSwimming() or
							( self.currentState == self.lookAtState and self.lastTargetPosition --[[isInCombat--]] ) or
							( self.currentState == self.roamState and heardNoise )
						)

	if ( done or abortState ) then
		-- Reduce aggro with successful attacks
		if self.currentState == self.combatAttackState and ( result == "finished" or result == "ready" ) then
			self.combatTicks = math.max( self.combatTicks - self.combatTicksAttackCost, 0 )
		end
		
		-- Select state
		if self.unit.character:isSwimming() then
			local landPosition = self.lastStablePosition and self.lastStablePosition or self.homePosition
			if landPosition then
				local landDirection = landPosition - self.unit.character.worldPosition
				landDirection.z = 0
				if landDirection:length() >= FLT_EPSILON then
					landDirection = landDirection:normalize()
				else
					landDirection = sm.vec3.new( 0, 1, 0 )
				end
				self.swimState.desiredDirection = landDirection
			end
			self.currentState = self.swimState
		elseif self.currentState == self.staggeredEventState and self.target then
			--Counterattack
			self.currentState = self.attackState01
		elseif shouldAvoid then
			if self.currentState ~= self.avoidState  then
				self.avoidCount = math.min( self.avoidCount + 1, self.avoidLimit )
			end
			self.currentState = self.avoidState
		elseif self.currentState == self.combatApproachState and done then
			-- Attack towards the approached target
			self.currentState = self.combatAttackState
		elseif self.currentState == self.pathingState and result == "failed" then
			self.avoidState.desiredDirection = self.unit.character.direction
			self.avoidState.desiredPosition = self.unit.character.worldPosition - self.avoidState.desiredDirection:normalize() * 2
			self.currentState = self.avoidState
		elseif self.currentState == self.pathingState and result == "arrived" or self.currentState == self.breachState then
			if breachDestination then
				self.breachState:sv_setDestination( breachDestination )
				self.currentState = self.breachState
			else
				-- Special check for obstacles or direct routes to players after pathing
				local nextTargetPosition
				if currentTargetPosition then
					nextTargetPosition = currentTargetPosition
				elseif self.lastTargetPosition then
					nextTargetPosition = self.lastTargetPosition
				end
				if nextTargetPosition == nil then
					nextTargetPosition = self.unit.character.worldPosition + self.unit.character.direction
				end
				self.circleFollowState:sv_setTargetPosition( nextTargetPosition )
				self.currentState = self.circleFollowState
			end
		elseif self.currentState == self.pathingState and breachDestination then
			-- Start breaching path obstacle
			self.breachState:sv_setDestination( breachDestination )
			self.currentState = self.breachState
		elseif combatPathing then
			-- Select combat state
			if currentTargetPosition then
				local fromToTarget = currentTargetPosition - self.unit.character.worldPosition
				local distance = fromToTarget:length()
				local flatCurrentTargetPosition = sm.vec3.new(  currentTargetPosition.x, currentTargetPosition.y, self.unit.character.worldPosition.z )
				local flatFromToTarget = flatCurrentTargetPosition - self.unit.character.worldPosition
				local flatDistance = flatFromToTarget:length()
				if self.target and type( self.target ) == "Character" then
					flatDistance = flatDistance - self.target:getRadius()
				end
				
				if flatDistance <= self.combatRange then
					-- Attack towards target character
					self.combatAttackState:sv_setAttackDirection( fromToTarget:normalize() )
					self.currentState = self.combatAttackState
				elseif flatDistance <= self.pathingCombatRange and self.currentState ~= self.combatAttackState then
					-- Move close to the target to increase the likelihood of a hit
					self.combatApproachState.desiredPosition = flatCurrentTargetPosition
					self.combatApproachState.desiredDirection = fromToTarget:normalize()
					self.currentState = self.combatApproachState
				else
					-- Move towards target character
					if self.currentState ~= self.pathingState then
						self.pathingState:sv_setDestination( currentTargetPosition )
					end
					self.currentState = self.pathingState
				end
			elseif self.lastTargetPosition then
				if self.currentState ~= self.pathingState then
					self.pathingState:sv_setDestination( self.lastTargetPosition )
				end
				self.currentState = self.pathingState
				self.lastTargetPosition = nil
			else
				self.currentState = self.idleState
				self.combatTicks = 0
			end
		else
			-- Select non-combat state
			if self.target then 
				-- Stick close to the target and circle around
				self.circleFollowState:sv_setTargetPosition( self.target.worldPosition )
				local radius = 0.0
				if type( self.target ) == "Character" then
					radius = self.target:getRadius()
				end
				self.circleFollowState:sv_setTargetRadius( radius )
				self.currentState = self.circleFollowState
			elseif self.lastTargetPosition then
				if self.currentState ~= self.pathingState then
					self.pathingState:sv_setDestination( self.lastTargetPosition )
				end
				self.currentState = self.pathingState
				self.lastTargetPosition = nil
			elseif heardNoise then
				self.currentState = self.lookAtState
				self.roamTimer:start( math.random( self.roamStartTimeMin, self.roamStartTimeMax ) )
			elseif self.roamTimer:done() and not ( self.currentState == self.idleState and result == "started" ) then
				self.roamTimer:start( math.random( self.roamStartTimeMin, self.roamStartTimeMax ) )
				self.currentState = self.roamState
			elseif not ( self.currentState == self.roamState and result == "roaming" ) then
				self.currentState = self.idleState
			end
		end
	end
	
	if prevState ~= self.currentState or restartPathing then
		
		
		if ( prevState == self.roamState and self.currentState ~= self.idleState ) or ( prevState == self.idleState and self.currentState ~= self.roamState ) then
			self.unit:sendCharacterEvent( "alerted" )
		elseif self.currentState == self.idleState and prevState ~= self.roamState then
			self.unit:sendCharacterEvent( "roaming" )
		end
		
		prevState:stop()
		self.currentState:start()
		if DEBUG_AI_STATES then
			print("change state")
			if self.currentState == self.idleState then
				print("idleState")
			elseif self.currentState == self.pathingState then
				print("pathingState")
			elseif self.currentState == self.roamState then
				print("roamState")
			elseif self.currentState == self.circleFollowState then
				print("circleFollowState")
			elseif self.currentState == self.combatApproachState then
				print("combatApproachState")
			elseif self.currentState == self.staggeredEventState then
				print("staggeredEventState")
			elseif self.currentState == self.combatAttackState then
				print("combatAttackState")
			elseif self.currentState == self.breachState then
				print("breachState")
			else
				print("unknown")
			end
		end
		
	end
end

function HaybotUnit.sv_e_worldEvent( self, params )
	if sm.exists( self.unit ) and self.target == nil then
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

function HaybotUnit.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
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
			self:sv_addStagger( self.staggerProjectile )
			if self.eventTarget == nil then
				if type( attacker ) == "Player" or type( attacker ) == "Unit" then
					self.eventTarget = attacker:getCharacter()
				elseif type( attacker ) == "Shape" then
					self.eventTarget = attacker
				end
			end
			self.combatTicks = math.max( self.combatTicks, self.combatTicksBerserk )

			local impact = hitVelocity:normalize() * 6
			self:sv_takeDamage( damage, impact, hitPos )
		end
	end
	if projectileUuid == projectile_water then
		startTumble( self, WaterTumbleTickTime, self.idleState, self.unit.character.velocity + sm.vec3.new( 0, 0, 2 ) )
		sm.effect.playEffect( "Part - Electricity", self.unit.character.worldPosition )
	end
end

function HaybotUnit.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
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
		local ZAxis = sm.vec3.new( 0.0, 0.0, 1.0 )

		self:sv_addStagger( self.staggerMelee )
		if self.eventTarget == nil then
			self.eventTarget = attackingCharacter
		end
		self.combatTicks = math.max( self.combatTicks, self.combatTicksBerserk )

		local impact = hitDirection * 6
		self:sv_takeDamage( damage, impact, hitPos )
	end
end

function HaybotUnit.server_onExplosion( self, center, destructionLevel )
	if not sm.exists( self.unit ) then
		return
	end
	local impact = ( self.unit:getCharacter().worldPosition - center ):normalize()
	self:sv_takeDamage( self.saved.stats.maxhp, impact, self.unit:getCharacter().worldPosition )
end

function HaybotUnit.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
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

	local collisionDamageMultiplier = 3.0
	local damage, tumbleTicks, tumbleVelocity, impactReaction = CharacterCollision( self.unit.character, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal, self.saved.stats.maxhp / collisionDamageMultiplier )
	damage = damage * collisionDamageMultiplier
	if damage > 0 or tumbleTicks > 0 then
		self.impactCooldownTicks = 6
	end
	if damage > 0 then
		print("'HaybotUnit' took", damage, "collision damage")
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

function HaybotUnit.server_onCollisionCrush( self )
	if not sm.exists( self.unit ) then
		return
	end
	onCrush( self )
end

function HaybotUnit.sv_updateCharacterTarget( self )
	if self.unit.character then
		sm.event.sendToCharacter( self.unit.character, "sv_n_updateTarget", { target = self.target } )
	end
end

function HaybotUnit.sv_addStagger( self, stagger )
	
	-- Update stagger
	if self.staggerCooldownTicks <= 0 then
		self.staggerCooldownTicks = self.staggerCooldownTickTime
		self.stagger = self.stagger + stagger
		local triggerStaggered = false
		while self.stagger >= 1.0 do
			self.stagger = self.stagger - 1.0
			triggerStaggered = true
		end
		if triggerStaggered then
			local prevState = self.currentState
			self.currentState = self.staggeredEventState
			prevState:stop()
			self.currentState:start()
		end
	end
	
end

function HaybotUnit.sv_takeDamage( self, damage, impact, hitPos )
	if self.saved.stats.hp > 0 then
		self.saved.stats.hp = self.saved.stats.hp - damage
		self.saved.stats.hp = math.max( self.saved.stats.hp, 0 )
		print( "'HaybotUnit' received:", damage, "damage.", self.saved.stats.hp, "/", self.saved.stats.maxhp, "HP" )
		
		for _, allyUnit in ipairs( self.allyUnits ) do
			if sm.exists( allyUnit ) and allyUnit.character and allyUnit.character:getCharacterType() == unit_haybot then
				sm.event.sendToUnit( allyUnit, "sv_e_allyDamaged", { sendingUnit = self.unit } )
			end
		end
		
		local effectRotation = sm.quat.identity()
		if impact and impact:length() >= FLT_EPSILON then
			effectRotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), -impact:normalize() )
		end
		sm.effect.playEffect( "Haybot - Hit", hitPos, nil, effectRotation )

		if self.saved.stats.hp <= 0 then
			self:sv_onDeath( impact )
		else
			self.unit:sendCharacterEvent( "impact" )
			self.storage:save( self.saved )
		end
	end
end

function HaybotUnit.sv_onDeath( self, impact )
	local character = self.unit:getCharacter()
	if not self.destroyed then
		g_unitManager:sv_addDeathMarker( character.worldPosition )
		self.saved.stats.hp = 0
		self.unit:destroy()
		print("'HaybotUnit' killed!")
		self.unit:sendCharacterEvent( "death" )
		self:sv_spawnParts( impact )
		if SurvivalGame then
			local loot = SelectLoot( "loot_haybot" )
			SpawnLoot( self.unit, loot )
		end
		self.destroyed = true
	end
end

function HaybotUnit.sv_spawnParts( self, impact )
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
	local tiltAxis = sm.vec3.new( 0, 1, 0 ):rotateZ( math.rad( math.random( 0, 359 ) ) )
	local tiltRotation = sm.quat.angleAxis( math.rad( math.random( 18, 22 ) ), tiltAxis )
	
	if not g_disableScrapHarvest then
		local scrapBody = sm.body.createBody( bodyPos, tiltRotation, true )
		local scrapShape = scrapBody:createPart( obj_harvest_metal, sm.vec3.new( -1, 2, -1 ), sm.vec3.new( 0, -1, 0 ), sm.vec3.new( 1, 0, 0 ), true )
		scrapShape.color = color
	end
end

function HaybotUnit.sv_e_receiveTarget( self, params )
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

function HaybotUnit.sv_e_allyDamaged( self, params )
	if sm.exists( params.sendingUnit ) and sm.exists( self.unit ) and ( params.sendingUnit.character.worldPosition - self.unit.character.worldPosition ):length() <= AllyRange then
		self.circleFollowState:sv_avoid( 30,  params.sendingUnit.character.worldPosition ) -- Sprint evasively during the given tick time
	end
end

