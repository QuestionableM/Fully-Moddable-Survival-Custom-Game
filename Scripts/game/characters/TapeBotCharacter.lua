dofile "$SURVIVAL_DATA/Scripts/util.lua"

TapeBotCharacter = class( nil )

local alertRenderableTp = "$SURVIVAL_DATA/Character/Char_Tapebot/char_tapebot_alert.rend"
local roamingRenderableTp = "$SURVIVAL_DATA/Character/Char_Tapebot/char_tapebot_roaming.rend"
sm.character.preloadRenderables( { alertRenderableTp, roamingRenderableTp } )

local alertMovementEffects = "$SURVIVAL_DATA/Character/Char_Tapebot/alert_movement_effects.json"
local roamingMovementEffects = "$SURVIVAL_DATA/Character/Char_Tapebot/roaming_movement_effects.json"

function TapeBotCharacter.client_onCreate( self )

	self.cl = {}
	self.cl.animations = {}
	self.cl.animationSwitches = {}
	self.cl.currentAnimationSet = roamingRenderableTp
	self.cl.currentMovementEffects = roamingMovementEffects
	self.cl.target = nil
	
	--print( "-- TapeBotCharacter created --" )
	self:client_onRefresh()
end

function TapeBotCharacter.client_onDestroy( self )
	--print( "-- TapeBotCharacter destroyed --" )
end

function TapeBotCharacter.client_onRefresh( self )
	--print( "-- TapeBotCharacter refreshed --" )
	self.cl.headAngle = 0.5
end

function TapeBotCharacter.client_onGraphicsLoaded( self )
	self.character:addRenderable( self.cl.currentAnimationSet )
	self.character:setMovementEffects( self.cl.currentMovementEffects )
	self:cl_initGraphics()
	self:cl_initAnimationSwitch()
	self.character:setGlowMultiplier( 1 )
	self.graphicsLoaded = true
end

function TapeBotCharacter.client_onGraphicsUnloaded( self )
	self.graphicsLoaded = false
end

function TapeBotCharacter.cl_initGraphics( self )
	
	self.cl.animations.shoot = {
		info = self.character:getAnimationInfo( "shoot" ),
		time = 0,
		weight = 0
	}
	self.animationsLoaded = true

	self.cl.blendSpeed = 5.0
	self.cl.blendTime = 0.2

	self.cl.currentAnimation = ""
end

function TapeBotCharacter.cl_initAnimationSwitch( self )
	self.cl.animationSwitches.alerted = {
		info = self.character:getAnimationInfo( "alerted" ),
		time = 0,
		weight = 0,
		triggeredEvent = false
	}
	self.cl.animationSwitches.roaming = {
		info = self.character:getAnimationInfo( "roaming" ),
		time = 0,
		weight = 0,
		triggeredEvent = false
	}
	self.cl.currentSwitch = ""
end

function TapeBotCharacter.client_onUpdate( self, deltaTime )
	if not self.graphicsLoaded then
		return
	end

	--Animation debug text
	local activeAnimations = self.character:getActiveAnimations()
	local debugText = ""
	sm.gui.setCharacterDebugText( self.character, "" ) -- Clear debug text
	if activeAnimations then
		for i, animation in ipairs( activeAnimations ) do
			if animation.name ~= "" and animation.name ~= "spine_turn" then
				local truncatedWeight = math.floor( animation.weight * 10 + 0.5 ) / 10
				sm.gui.setCharacterDebugText( self.character, tostring( animation.name .. " : " .. truncatedWeight ), false ) -- Add debug text without clearing
			end
		end
	end
	
	-- Update spine bending animation
	local lookDirection = self.character.direction
	if self.cl.currentAnimationSet == alertRenderableTp then
		if self.cl.target and sm.exists( self.cl.target ) then
			lookDirection = ( self.cl.target.worldPosition - self.character.worldPosition ):normalize()
		end
	end
	local angle = math.asin( lookDirection:dot( sm.vec3.new( 0, 0, 1 ) ) ) / ( math.pi / 2 )
	local desiredHeadAngle = ( 0.5 + angle * 0.5 )
	local headLerpSpeed = 1.0 / 3.0
	local blend = math.pow( 1 - ( 1 - headLerpSpeed ), ( deltaTime * 60 ) )
	self.cl.headAngle = lerp( self.cl.headAngle, desiredHeadAngle, blend )
	self.character:updateAnimation( "tapebot_aimbend_uppdown", self.cl.headAngle, 1.0, true )
	
	-- Update animations
	for name, animation in pairs(self.cl.animations) do
		if animation.info then
			animation.time = animation.time + deltaTime
		
			if name == self.cl.currentAnimation then
				animation.weight = math.min(animation.weight+(self.cl.blendSpeed * deltaTime), 1.0)
				if animation.time >= animation.info.duration then
					self.cl.currentAnimation = ""
				end
			else
				animation.weight = math.max(animation.weight-(self.cl.blendSpeed * deltaTime ), 0.0)
			end
		
			self.character:updateAnimation( animation.info.name, animation.time, animation.weight )
		end
	end
	
	-- Update state change
	for name, animationSwitch in pairs( self.cl.animationSwitches ) do
		if animationSwitch.info then
			animationSwitch.time = animationSwitch.time + deltaTime
			
			if name == self.cl.currentSwitch then
				animationSwitch.weight = math.max( 1 - 2 * math.abs( ( animationSwitch.time / animationSwitch.info.duration ) - 0.5 ), 0 )
				if animationSwitch.time >= animationSwitch.info.duration * 0.5 and not animationSwitch.triggeredEvent then
					animationSwitch.triggeredEvent = true
					
					if name == "alerted" then
						if self.cl.currentAnimationSet ~= alertRenderableTp then
							self.character:removeRenderable( self.cl.currentAnimationSet )
							self.cl.currentAnimationSet = alertRenderableTp
							self.character:addRenderable( self.cl.currentAnimationSet )
							self:cl_initGraphics()
							
							self.cl.currentMovementEffects = alertMovementEffects
							self.character:setMovementEffects( self.cl.currentMovementEffects )
						end
					elseif name == "roaming" then
						if self.cl.currentAnimationSet ~= roamingRenderableTp then
							self.character:removeRenderable( self.cl.currentAnimationSet )
							self.cl.currentAnimationSet = roamingRenderableTp
							self.character:addRenderable( self.cl.currentAnimationSet )
							self:cl_initGraphics()
							
							self.cl.currentMovementEffects = roamingMovementEffects
							self.character:setMovementEffects( self.cl.currentMovementEffects )
						end
					end
				end
				
				if animationSwitch.time >= animationSwitch.info.duration then
					self.cl.currentSwitch = ""
					animationSwitch.time = 0
					animationSwitch.weight = 0
					animationSwitch.triggeredEvent = false
				end
			else
				animationSwitch.time = 0
				animationSwitch.weight = 0
				animationSwitch.triggeredEvent = false
			end
			
			self.character:updateAnimation( animationSwitch.info.name, animationSwitch.time, animationSwitch.weight )
		end
	end
	
end

function TapeBotCharacter.client_onEvent( self, event )
	self:client_handleEvent( event )
end

function TapeBotCharacter.client_handleEvent( self, event )
	if not self.animationsLoaded then
		return
	end

	if event == "shoot" then
		if self.cl.animations.shoot then
			self.cl.currentAnimation = "shoot"
			self.cl.animations.shoot.time = 0
		end
		if self.graphicsLoaded then
			local catapultPos = self.character:getTpBonePos( "r_catapult_jnt" )
			local catapultRot = self.character:getTpBoneRot( "r_catapult_jnt" )
			local fireOffset = catapultRot * sm.vec3.new( 0, 0, 1 )
			sm.effect.playEffect( "TapeBot - Shoot", catapultPos + fireOffset, nil, catapultRot )
		end
	elseif event == "alerted" then
		if self.cl.animationSwitches.alerted then
			self.cl.currentSwitch = "alerted"
			self.cl.animationSwitches.alerted.time = 0
			self.cl.animationSwitches.alerted.triggeredEvent = false
			self.cl.currentAnimation = ""
		end
	elseif event == "roaming" then
		if self.cl.animationSwitches.roaming then
			self.cl.currentSwitch = "roaming"
			self.cl.animationSwitches.roaming.time = 0
			self.cl.animationSwitches.roaming.triggeredEvent = false
			self.cl.currentAnimation = ""
		end
	elseif event == "hit" then
		self.cl.currentAnimation = ""
	elseif event == "death" then
		if self.character:getCharacterType() == unit_tapebot_red then
			SpawnDebris( self.character, "head_jnt", "Robotparts - RedtapebotHead" )
		else
			SpawnDebris( self.character, "head_jnt", "Robotparts - TapebotHead" )
		end
		SpawnDebris( self.character, "spine1_jnt", "Robotparts - TapebotTorso" )
		SpawnDebris( self.character, "l_arm_jnt", "Robotparts - TapebotLeftarm" )
		sm.effect.playEffect( "TapeBot - Destroyed", self.character.worldPosition, nil, nil, nil, { Color = self.character:getColor() } )
	end
end

function TapeBotCharacter.sv_n_updateTarget( self, params )
	self.network:sendToClients( "cl_n_updateTarget", params )
end

function TapeBotCharacter.cl_n_updateTarget( self, params )
	self.cl.target = params.target
end

function TapeBotCharacter.sv_e_unitDebugText( self, text )
	-- No sync cheat
	if self.unitDebugText == nil then
		self.unitDebugText = {}
	end
	local MaxRows = 10
	if #self.unitDebugText == MaxRows then
		for i = 1, MaxRows - 1 do
			self.unitDebugText[i] = self.unitDebugText[i + 1]
		end
		self.unitDebugText[MaxRows] = text
	else
		self.unitDebugText[#self.unitDebugText + 1] = text
	end
end
