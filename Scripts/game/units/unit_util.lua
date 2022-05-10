
function getClosestCharacter( position, characters )
	local closestDistance2
	local closestCharacter
	for _,character in ipairs( characters ) do
		local distance2 = ( position - character.worldPosition ):length2()
		if closestDistance2 == nil or distance2 < closestDistance2 then
			closestCharacter = character
		end
	end
	return closestCharacter, math.sqrt( closestDistance2 )
end

function ListenForPlayerNoise( listeningCharacter, noiseScale )
	if not sm.game.getEnableAggro() then
		return nil
	end
	local closestCharacter = nil
	local bestFraction = -1
	local allPlayers = sm.player.getAllPlayers()
	for _, player in ipairs( allPlayers ) do
		if player.character and player.character:getWorld() == listeningCharacter:getWorld() then
			local noiseRadius = player.character:getCurrentMovementNoiseRadius() * noiseScale
			if noiseRadius > 0 then
				local noiseFraction = 1.0 - ( player.character.worldPosition - listeningCharacter.worldPosition ):length() / noiseRadius
				if noiseFraction > 0 and ( noiseFraction > bestFraction or bestFraction == -1 ) then
					bestFraction = noiseFraction
					closestCharacter = player.character
				end
			end
		end
	end
	if closestCharacter then
		local success, result = sm.physics.raycast( listeningCharacter.worldPosition, closestCharacter.worldPosition, listeningCharacter )
		if success and result.type == "character" and result:getCharacter() == closestCharacter then
			return closestCharacter
		end
	end
	return nil
end

function initTumble( self )
	self.tumbleReset = Timer()
	self.tumbleReset:start( DEFAULT_TUMBLE_TICK_TIME )
	self.airTicks = 0
end

function startTumble( self, tumbleTickTime, tumbleState, tumbleVelocity )
	if not self.unit.character:isTumbling() then
		self.unit.character:setTumbling( true )
		if tumbleTickTime then
			self.tumbleReset:start( tumbleTickTime )
		else
			self.tumbleReset:start( DEFAULT_TUMBLE_TICK_TIME )
		end
		if tumbleState then
			self.currentState:stop()
			self.currentState = tumbleState
			self.currentState:start()
		end

		if tumbleVelocity then
			self.unit.character:applyTumblingImpulse( tumbleVelocity * self.unit.character.mass )
		end
		return true
	end
	return false
end

function updateTumble( self )
	if self.unit.character:isTumbling() then
		local tumbleVelocity = self.unit.character:getTumblingLinearVelocity()
		if tumbleVelocity:length() < 1.0 then
			self.tumbleReset:tick()

			if self.tumbleReset:done() then
				self.unit.character:setTumbling( false )
				self.tumbleReset:reset()
			end
		else
			self.tumbleReset:reset()
		end
	end
end

function updateAirTumble( self, tumbleState )
	if not self.unit.character:isOnGround() and not self.unit.character:isSwimming() and not self.unit.character:isTumbling() then
		self.airTicks = self.airTicks + 1
		if self.airTicks >= AIR_TICK_TIME_TO_TUMBLE then
			local defaultAllowedPenetrationDepth = 0.04
			local startPos = self.unit.character.worldPosition
			local endPos = startPos - ( sm.vec3.new( 0.0, 0.0, self.unit.character:getHeight() * 0.5 + defaultAllowedPenetrationDepth ) )
			local success, _ = sm.physics.raycast( startPos, endPos, self.unit.character, sm.physics.filter.static + sm.physics.filter.dynamicBody )
			if success then
				self.airTicks = 0
			else
				startTumble( self, DEFAULT_TUMBLE_TICK_TIME, tumbleState, self.unit.character.velocity )
			end
		end
	else
		self.airTicks = 0
	end
end

function initCrushing( self, crushTickTime )
	self.crushTicks = 0
	self.crushTickTime = crushTickTime and crushTickTime or DEFAULT_CRUSH_TICK_TIME
	self.crushUpdate = false
end

function onCrush( self  )
	self.crushUpdate = true
end

function updateCrushing( self )
	
	if self.crushUpdate then
		self.crushTicks = math.min( self.crushTicks + 1, self.crushTickTime )
		self.crushUpdate = false
	else
		self.crushTicks = math.max( self.crushTicks - 1, 0 ) 
	end
	
	if self.crushTicks >= self.crushTickTime then
		return true
	else
		return false
	end
	
end

function selectRaidTarget( self, targetCharacter, closestVisibleCrop )
	
	local prioritizeCharacterDistance = 3.0
	local deaggroDistance = 34.0
	local aggroDistance = 30.0

	-- Raiders prioritize targeting crops over distant players
	local closeToCharacter = false
	local inAggroDistance = false
	local overDeaggroDistance = true
	if targetCharacter then
		closeToCharacter = ( targetCharacter and ( targetCharacter.worldPosition - self.unit.character.worldPosition ):length() <= prioritizeCharacterDistance )
		inAggroDistance = ( targetCharacter and ( targetCharacter.worldPosition - self.homePosition ):length() <= aggroDistance )
		overDeaggroDistance = ( targetCharacter and ( targetCharacter.worldPosition - self.homePosition ):length() >= deaggroDistance )
	end
	local characterIsWithinAggroRange = inAggroDistance or ( self.target == targetCharacter and not overDeaggroDistance )
	if ( closeToCharacter or closestVisibleCrop == nil ) and characterIsWithinAggroRange then
		self.target = targetCharacter
	else
		self.target = closestVisibleCrop
	end
	
end

function FindNearbyEdible( character, edibleUuid, searchRadius, reach )
	local closestShape = nil
	local closestDistance = math.huge
	local nearbyShapes = sm.shape.shapesInSphere( character.worldPosition, searchRadius )
	for _, shape in ipairs( nearbyShapes )do
		if shape:getShapeUuid() == edibleUuid then
			local distanceToShape = ( shape.worldPosition - character.worldPosition ):length()
			if distanceToShape < closestDistance then
				closestDistance = distanceToShape
				closestShape = shape
			end
		end
	end

	if closestShape and sm.exists( closestShape ) then
		return closestShape, closestDistance <= reach
	end
	return nil, false
end

function GetClosestPlayerCharacter( position, world )
	local closestPlayer = nil
	local closestDd = math.huge
	local players = sm.player.getAllPlayers()
	for _, player in ipairs( players ) do
		local validTarget = player.character and
							world == player.character:getWorld() and
							not player.character:isDowned()
		if validTarget then
			local dd = ( player.character.worldPosition - position ):length2()
			if dd <= closestDd then
				closestPlayer = player
				closestDd = dd
			end
		end
	end
	if closestPlayer then
		return closestPlayer.character
	end
	return nil
end

function GetPlayerCharactersInSphere( position, radius, world )
	local playerCharacters = {}
	local players = sm.player.getAllPlayers()
	for _, player in ipairs( players ) do
		local validTarget = player.character and
							world == player.character:getWorld() and
							not player.character:isDowned()
		if validTarget then
			local dd = ( player.character.worldPosition - position ):length2()
			if dd <= radius * radius then
				playerCharacters[#playerCharacters+1] = player.character
			end
		end
	end
	return playerCharacters
end

local function getCharacter( userdataObject )
	if userdataObject and isAnyOf( type( userdataObject ), { "Character", "Player", "Unit" } ) then
		if sm.exists( userdataObject ) then
			if type( userdataObject ) == "Player" or type( userdataObject ) == "Unit" then
				return userdataObject.character
			elseif type( userdataObject ) == "Character" then
				return userdataObject
			end
			return nil
		else
			return nil
		end
	end
	sm.log.warning( "Tried to get character for an unsupported type: "..type( userdataObject ) )
	return nil
end

function InSameTeam( userdataObjectA, userdataObjectB )
	local characterA = getCharacter( userdataObjectA )
	local characterB = getCharacter( userdataObjectB )
	if characterA == nil or characterB == nil then
		return false
	end

	if not characterA:isDefaultColor() and not characterB:isDefaultColor() then
		return characterA:getColor() == characterB:getColor()
	elseif not characterA:isPlayer() and not characterB:isPlayer() then
		return characterA:isDefaultColor() and characterB:isDefaultColor()
	end
	return false
end

function InSameGroup( unitA, unitB )
	local groupA = unitA.publicData and unitA.publicData.groupTag or nil
	local groupB = unitB.publicData and unitB.publicData.groupTag or nil
	return groupA and groupB and groupA == groupB
end