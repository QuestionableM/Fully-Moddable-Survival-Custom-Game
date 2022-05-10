dofile "$SURVIVAL_DATA/Scripts/util.lua"
HaybotCharacter = class( nil )

local alertRenderableTp = "$SURVIVAL_DATA/Character/Char_Haybot/char_haybot_alert.rend"
local roamingRenderableTp = "$SURVIVAL_DATA/Character/Char_Haybot/char_haybot_roaming.rend"
sm.character.preloadRenderables( { alertRenderableTp, roamingRenderableTp } )

local alertMovementEffects = "$SURVIVAL_DATA/Character/Char_Haybot/alert_movement_effects.json"
local roamingMovementEffects = "$SURVIVAL_DATA/Character/Char_Haybot/alert_movement_effects.json"

function HaybotCharacter.server_onCreate( self )
	self:server_onRefresh()
end

function HaybotCharacter.server_onRefresh( self )
	self.sv = {}
	self.sv.spawnPosition = self.character.worldPosition
	self.sv.spawnWorld = self.character:getWorld()
end

function HaybotCharacter.client_onCreate( self )
	self.cl = {}
	self.cl.animations = {}
	self.cl.animationSwitches = {}
	self.cl.currentAnimationSet = roamingRenderableTp
	self.cl.currentMovementEffects = roamingMovementEffects
	self.cl.target = nil
	
	--print( "-- HaybotCharacter created --" )
	self:client_onRefresh()
end

function HaybotCharacter.client_onDestroy( self )
	--print( "-- HaybotCharacter destroyed --" )
end

function HaybotCharacter.client_onRefresh( self )
	--print( "-- HaybotCharacter refreshed --" )
	self.cl.headAngle = 0.5
end

function HaybotCharacter.client_onGraphicsLoaded( self )

	self.character:addRenderable( self.cl.currentAnimationSet )
	self.character:setMovementEffects( self.cl.currentMovementEffects )
	self:cl_initGraphics()
	self:cl_initAnimationSwitch()
	self.character:setGlowMultiplier( 1 )
	self.graphicsLoaded = true

end

function HaybotCharacter.client_onGraphicsUnloaded( self )
	self.graphicsLoaded = false
end

function HaybotCharacter.cl_initGraphics( self )
	
	self.cl.animations.attack01 = {
		info = self.character:getAnimationInfo( "attack01" ),
		time = 0,
		weight = 0
	}
	self.cl.animations.attack02 = {
		info = self.character:getAnimationInfo( "attack02" ),
		time = 0,
		weight = 0
	}
	self.cl.animations.attack03 = {
		info = self.character:getAnimationInfo( "attack03" ),
		time = 0,
		weight = 0
	}
	self.cl.animations.sprintattack01 = {
		info = self.character:getAnimationInfo( "sprintattack01" ),
		time = 0,
		weight = 0
	}
	self.cl.animations.stagger = {
		info = self.character:getAnimationInfo( "stagger" ),
		time = 0,
		weight = 0
	}
	self.cl.animations.stagger_alert = {
		info = self.character:getAnimationInfo( "stagger_alert" ),
		time = 0,
		weight = 0
	}
	self.cl.animations.idlespecial01 = {
		info = self.character:getAnimationInfo( "idlespecial01" ),
		time = 0,
		weight = 0
	}
	self.cl.animations.idlespecial02 = {
		info = self.character:getAnimationInfo( "idlespecial02" ),
		time = 0,
		weight = 0
	}
	self.cl.animations.impact = {
		info = self.character:getAnimationInfo( "impact" ),
		time = 0,
		weight = 0,
		active = false,
		additive = true
	}
	self.animationsLoaded = true
	
	self.cl.blendSpeed = 5.0
	self.cl.blendTime = 0.2
	self.cl.currentAnimation = ""
end

function HaybotCharacter.cl_initAnimationSwitch( self )
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

function HaybotCharacter.client_onUpdate( self, deltaTime )
	if not self.graphicsLoaded then
		return
	end
	
	if sm.exists( self.character ) then
		--Animation debug text
		local activeAnimations = self.character:getActiveAnimations()
		sm.gui.setCharacterDebugText( self.character, "" ) -- Clear debug text
		if activeAnimations then
			for i, animation in ipairs( activeAnimations ) do
				if animation.name ~= "" and animation.name ~= "spine_turn" then
					local truncatedWeight = math.floor( animation.weight * 10 + 0.5 ) / 10
					sm.gui.setCharacterDebugText( self.character, tostring( animation.name .. " : " .. truncatedWeight ), false ) -- Add debug text without clearing
				end
			end
		end
		
		if self.unitDebugText then
			sm.gui.setCharacterDebugText( self.character, "#ff7f00UNIT LOG:", false ) -- Clear debug text
			for i,text in ipairs( self.unitDebugText ) do
				sm.gui.setCharacterDebugText( self.character, ( i == #self.unitDebugText and ">" or "" )..text, false ) -- Add debug text without clearing
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
		self.character:updateAnimation( "haybot_aimbend_uppdown", self.cl.headAngle, 1.0, true )
		
		-- Update animations
		for name, animation in pairs( self.cl.animations ) do
			if animation.info then
				animation.time = animation.time + deltaTime
			
				if name == self.cl.currentAnimation then
					animation.weight = math.min(animation.weight+(self.cl.blendSpeed * deltaTime), 1.0)
					if animation.time >= animation.info.duration then
						self.cl.currentAnimation = ""
					end
				elseif animation.active then
					animation.weight = math.min(animation.weight+(self.cl.blendSpeed * deltaTime), 1.0)
					if animation.time >= animation.info.duration then
						self.cl.animations[name].active = false
					end
				else
					animation.weight = math.max(animation.weight-( self.cl.blendSpeed * deltaTime ), 0.0)
				end
				
				self.character:updateAnimation( animation.info.name, animation.time, animation.weight, animation.additive )
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
	
end

function HaybotCharacter.client_onEvent( self, event )
	self:cl_handleEvent( event )
end

function HaybotCharacter.cl_handleEvent( self, event )
	if not self.animationsLoaded then
		return
	end
	
	if event == "attack01" then
		if self.cl.animations.attack01 then
			self.cl.currentAnimation = "attack01"
			self.cl.animations.attack01.time = 0
		end
	elseif event == "attack02" then
		if self.cl.animations.attack02 then
			self.cl.currentAnimation = "attack02"
			self.cl.animations.attack02.time = 0
		end
	elseif event == "attack03" then
		if self.cl.animations.attack03 then
			self.cl.currentAnimation = "attack03"
			self.cl.animations.attack03.time = 0
		end
	elseif event == "sprintattack01" then
		if self.cl.animations.sprintattack01 then
			self.cl.currentAnimation = "sprintattack01"
			self.cl.animations.sprintattack01.time = 0
		end
	elseif event == "stagger" then
		if self.cl.currentAnimationSet == roamingRenderableTp then
			if self.cl.animations.stagger then
				self.cl.currentAnimation = "stagger"
				self.cl.animations.stagger.time = 0
			end
		else
			if self.cl.animations.stagger_alert then
				self.cl.currentAnimation = "stagger_alert"
				self.cl.animations.stagger_alert.time = 0
			end
		end
	elseif event == "impact" then
		if self.cl.animations.impact then
			self.cl.animations.impact.active = true
			self.cl.animations.impact.time = 0
		end
	elseif event == "idlespecial01" then
		if self.cl.animations.idlespecial01 then
			self.cl.currentAnimation = "idlespecial01"
			self.cl.animations.idlespecial01.time = 0
		end
	elseif event == "idlespecial02" then
		if self.cl.animations.idlespecial02 then
			self.cl.currentAnimation = "idlespecial02"
			self.cl.animations.idlespecial02.time = 0
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
		sm.effect.playEffect( "Haybot - Hit", self.character.worldPosition )
		self.cl.currentAnimation = ""
	elseif event == "stop" then
		self.cl.currentAnimation = ""
	elseif event == "death" then
		SpawnDebris( self.character, "head_jnt", "Robotparts - HaybotHead" )
		SpawnDebris( self.character, "torso_jnt", "Robotparts - HaybotBody" )
		SpawnDebris( self.character, "pelvis_jnt", "Robotparts - HaybotPelvis" )
		SpawnDebris( self.character, "r_leg06_jnt", "Robotparts - HaybotFork" )
		sm.effect.playEffect( "Haybot - Destroyed", self.character.worldPosition, nil, nil, nil, { Color = self.character:getColor() } )
	end
	
end

function HaybotCharacter.sv_n_updateTarget( self, params )
	self.network:sendToClients( "cl_n_updateTarget", params )
end

function HaybotCharacter.cl_n_updateTarget( self, params )
	self.cl.target = params.target
end

function HaybotCharacter.sv_e_unitDebugText( self, text )
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