-- CircleFollowState.lua --
dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"

CircleFollowState = class( nil )

function CircleFollowState.sv_onCreate( self, unit, nearDistance, farDistance, outsideDistance, circleChangeTickIntervalMin, circleChangeTickIntervalMax, pauseTickIntervalMin, pauseTickIntervalMax, pauseTickTimeMin, pauseTickTimeMax )
	self.unit = unit
	
	self.targetPosition = nil
	self.targetRadius = 0.0
	
	self.nearDistance = nearDistance
	self.farDistance = farDistance
	self.outsideDistance = outsideDistance
	
	self.followDirectionState = self.unit:createState( "followDirection" )
	self.followDirectionState.movementType = "stand"
	self.followDirectionState.avoidance = true

	self.circleClockwise = ( math.random( 0, 1 ) == 1 )
	self.circleChangeTickIntervalMin = circleChangeTickIntervalMin
	self.circleChangeTickIntervalMax = circleChangeTickIntervalMax
	self.circleChangeCountdown = math.random( self.circleChangeTickIntervalMin, self.circleChangeTickIntervalMax )
	
	self.pauseTickIntervalMin = pauseTickIntervalMin
	self.pauseTickIntervalMax = pauseTickIntervalMax
	self.pauseCountdown = math.random( self.pauseTickIntervalMin, self.pauseTickIntervalMax )
	self.pauseTickTimeMin = pauseTickTimeMin
	self.pauseTickTimeMax = pauseTickTimeMax
	self.pauseTicks = 0
	
	self.rushTicks = 0
	self.avoidTicks = 0
	self.avoidPosition = nil
end

function CircleFollowState.sv_setTargetPosition( self, targetPosition )
	self.targetPosition = targetPosition
end

function CircleFollowState.sv_setTargetRadius( self, targetRadius )
	self.targetRadius = targetRadius
end

function CircleFollowState.sv_rush( self, rushTicks )
	self.rushTicks = math.max( self.rushTicks, rushTicks )
end

function CircleFollowState.sv_avoid( self, avoidTicks, avoidPosition )
	self.avoidTicks = math.max( self.avoidTicks, avoidTicks )
	self.avoidPosition = avoidPosition
end

function CircleFollowState.refresh( self ) end

--[[API functions]]
function CircleFollowState.start( self ) 
	self.followDirectionState:start()
end

function CircleFollowState.stop( self )
	self.followDirectionState:stop()
	self.targetPosition = nil
end

function CircleFollowState.onFixedUpdate( self, dt )
	self.followDirectionState:onFixedUpdate( dt )
	
	self.rushTicks = math.max( self.rushTicks - 1, 0 )
	self.avoidTicks = math.max( self.avoidTicks - 1, 0 )
	
	-- Occasionally change direction to circle around the target
	self.circleChangeCountdown = self.circleChangeCountdown - 1
	if self.circleChangeCountdown <= 0 then
		self.circleChangeCountdown = math.random( self.circleChangeTickIntervalMin, self.circleChangeTickIntervalMax )
		self.circleClockwise = not self.circleClockwise
	end
	
	-- Occasionally pause the circling movement around the target
	self.pauseTicks = math.max( self.pauseTicks - 1, 0 )
	if self.pauseTicks <= 0 then
		self.pauseCountdown = self.pauseCountdown - 1
		if self.pauseCountdown <= 0 then
			self.pauseCountdown = math.random( self.pauseTickIntervalMin, self.pauseTickIntervalMax )
			self.pauseTicks = math.random( self.pauseTickTimeMin, self.pauseTickTimeMax )
		end
	end

end

function CircleFollowState.onUnitUpdate( self, dt )
	self.followDirectionState:onUnitUpdate( dt )
	
	if self.targetPosition then
	
		local fromToTarget = self.targetPosition - self.unit.character.worldPosition
		if fromToTarget:length() <= 0 then
			fromToTarget = sm.vec3.new( 0, 1, 0 )
		end
		
		local walkOrStand = "walk"
		if self.pauseTicks > 0 then
			walkOrStand = "stand"
		end
		
		-- Stick close to the target and circle around
		local distance = math.max( fromToTarget:length() - self.targetRadius, 0.0 )
		local farNearHalfDiff = ( self.farDistance - self.nearDistance ) * 0.5
		local optimalMidDistance = self.nearDistance + farNearHalfDiff
		if self.avoidTicks > 0 and self.avoidPosition and distance <= optimalMidDistance then
			local fromToPosition = self.avoidPosition - self.unit.character.worldPosition
			if fromToPosition:length() <= 0 then
				fromToPosition = sm.vec3.new( 0, 1, 0 )
			end
			self.followDirectionState.desiredDirection = -fromToPosition:normalize()
			self.followDirectionState.movementType = "sprint"
			self.followDirectionState.avoidance = true
		elseif self.rushTicks > 0 then
			self.followDirectionState.desiredDirection = fromToTarget:normalize()
			self.followDirectionState.movementType = "sprint"
			self.followDirectionState.avoidance = false
		else
			if distance < self.nearDistance then
				-- Walk backward
				self.followDirectionState.desiredDirection = -fromToTarget:normalize()
				self.followDirectionState.movementType = "walk"
				self.followDirectionState.avoidance = true
			elseif distance < self.farDistance  then
				-- Circle strafing
				local circleDirectionSign = ( self.circleClockwise and -1 or 1 )
				local flatFromToTarget = fromToTarget:normalize()
				flatFromToTarget.z = 0
				if flatFromToTarget:length() >= FLT_EPSILON then
					flatFromToTarget = flatFromToTarget:normalize()
				else
					flatFromToTarget = sm.vec3.new( 0, 1, 0 )
				end
				self.followDirectionState.desiredDirection = flatFromToTarget:cross( sm.vec3.new( 0, 0, 1 ) ) * circleDirectionSign
				
				local circleCorrectionFraction = math.max( math.min( ( distance - optimalMidDistance ) / farNearHalfDiff, 1.0 ), 0.0 )
				self.followDirectionState.desiredDirection = sm.vec3.rotateZ( self.followDirectionState.desiredDirection, ( math.rad( 45 ) ) * circleCorrectionFraction * circleDirectionSign )
				self.followDirectionState.movementType = walkOrStand
				self.followDirectionState.avoidance = true
			elseif distance < self.outsideDistance then
				-- Walk forward
				self.followDirectionState.desiredDirection = fromToTarget:normalize()
				self.followDirectionState.movementType = "walk"
				self.followDirectionState.avoidance = true
			elseif distance > self.outsideDistance then
				-- Sprint forward
				self.followDirectionState.desiredDirection = fromToTarget:normalize()
				self.followDirectionState.movementType = "sprint"
				self.followDirectionState.avoidance = true
			end
		end
	else
		self.followDirectionState.movementType = "stand"
	end

end

function CircleFollowState.isDone( self )
	return true
end

function CircleFollowState.getMovementDirection( self )
	return self.followDirectionState.desiredDirection
end

function CircleFollowState.getFacingDirection( self )
	if self.targetPosition then
		local fromToTarget = self.targetPosition - self.unit.character.worldPosition
		if fromToTarget:length() <= 0 then
			fromToTarget = sm.vec3.new( 0, 1, 0 )
		end
		return fromToTarget:normalize()
	end
	return self.unit.character.direction
end

function CircleFollowState.getMovementType( self )
	return self.followDirectionState.movementType
end

function CircleFollowState.getWantsJump( self )
	return false
end