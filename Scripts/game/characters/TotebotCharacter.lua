TotebotCharacter = class( nil )

local alertRenderableTp = "$SURVIVAL_DATA/Character/Char_Totebot/char_totebot_alert.rend"
local roamingRenderableTp = "$SURVIVAL_DATA/Character/Char_Totebot/char_totebot_roaming.rend"
sm.character.preloadRenderables( { alertRenderableTp, roamingRenderableTp } )

function TotebotCharacter.client_onCreate( self )
	self.cl = {}
	self.cl.animations = {}
	self.cl.animationSwitches = {}
	self.cl.effects = {}
	self.cl.currentAnimationSet = roamingRenderableTp
	self.cl.target = nil
	
	--print( "-- TotebotCharacter created --" )
	self:client_onRefresh()
end

function TotebotCharacter.client_onDestroy( self )
	--print( "-- TotebotCharacter destroyed --" )
end

function TotebotCharacter.client_onRefresh( self )
	--print( "-- TotebotCharacter refreshed --" )
end

function TotebotCharacter.client_onGraphicsLoaded( self )

	self.character:addRenderable( self.cl.currentAnimationSet )
	self:cl_initGraphics()
	self:cl_initAnimationSwitch()
	self.character:setGlowMultiplier( 1 )
	self.graphicsLoaded = true

	self.cl.effects = {}
	self.cl.effects.alerted = sm.effect.createEffect( "ToteBot - Alerted", self.character, "jnt_head" )
	self.cl.effects.hit = sm.effect.createEffect( "ToteBot - Hit", self.character, "jnt_head" )
	self.cl.effects.attack = sm.effect.createEffect( "ToteBot - Attack", self.character )
	self.cl.effects.sparks = sm.effect.createEffect( "ToteBot - Sparks", self.character, "cable6_jnt" )
	self.cl.effects.sparks:start()
end

function TotebotCharacter.client_onGraphicsUnloaded( self )
	self.graphicsLoaded = false

	if self.cl.effects.alerted then
		self.cl.effects.alerted:destroy()
		self.cl.effects.alerted = nil
	end
	if self.cl.effects.hit  then
		self.cl.effects.hit:destroy()
		self.cl.effects.hit = nil
	end
	if self.cl.effects.attack then
		self.cl.effects.attack:destroy()
		self.cl.effects.attack = nil
	end
	if self.cl.effects.sparks then
		self.cl.effects.sparks:destroy()
		self.cl.effects.sparks = nil
	end
end

function TotebotCharacter.cl_initGraphics( self )
	self.cl.animations.attack = {
		info = self.character:getAnimationInfo( "attack_melee" ),
		time = 0,
		weight = 0
	}
	self.animationsLoaded = true

	self.cl.blendSpeed = 5.0
	self.cl.blendTime = 0.2

	self.cl.currentAnimation = ""
	
	self.character:setMovementEffects( "$SURVIVAL_DATA/Character/Char_Totebot/movement_effects.json" )
	
	self.character:setGlowMultiplier( 1 )
end

function TotebotCharacter.cl_initAnimationSwitch( self )
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

function TotebotCharacter.client_onUpdate( self, deltaTime )
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
							end
						elseif name == "roaming" then
							if self.cl.currentAnimationSet ~= roamingRenderableTp then
								self.character:removeRenderable( self.cl.currentAnimationSet )
								self.cl.currentAnimationSet = roamingRenderableTp
								self.character:addRenderable( self.cl.currentAnimationSet )
								self:cl_initGraphics()
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

function TotebotCharacter.client_onEvent( self, event )
	self:cl_handleEvent( event )
end

function TotebotCharacter.cl_handleEvent( self, event )
	if not self.animationsLoaded then
		return
	end

	if sm.exists( self.character ) then
	
		if event == "melee" then
			self.cl.currentAnimation = "attack"
			self.cl.animations.attack.time = 0
			if self.graphicsLoaded then
				self.cl.effects.attack:start()
			end
		elseif event == "alerted" then
			if self.cl.animationSwitches.alerted then
				self.cl.currentSwitch = "alerted"
				self.cl.animationSwitches.alerted.time = 0
				self.cl.animationSwitches.alerted.triggeredEvent = false
				if self.graphicsLoaded then
					self.cl.effects.alerted:start()
				end
			end
		elseif event == "roaming" then
			if self.cl.animationSwitches.roaming then
				self.cl.currentSwitch = "roaming"
				self.cl.animationSwitches.roaming.time = 0
				self.cl.animationSwitches.roaming.triggeredEvent = false
			end
		elseif event == "death" then
			SpawnDebris( self.character, "jnt_spine1", "Robotparts - TotebotBody" )
			SpawnDebris( self.character, "jnt_01_upperleg", "Robotparts - TotebotLeg" )
			SpawnDebris( self.character, "jnt_02_upperleg", "Robotparts - TotebotLeg" )
			SpawnDebris( self.character, "jnt_03_upperleg", "Robotparts - TotebotLeg" )
			SpawnDebris( self.character, "jnt_04_upperleg", "Robotparts - TotebotLeg" )
			SpawnDebris( self.character, "jnt_05_upperleg", "Robotparts - TotebotLeg" )
			SpawnDebris( self.character, "jnt_06_upperleg", "Robotparts - TotebotLeg" )
			
			sm.effect.playEffect( "ToteBot - DestroyedParts", self.character.worldPosition, nil, nil, nil, { Color = self.character:getColor() } )
		else
			self.cl.currentAnimation = ""
		end
	end
end

function TotebotCharacter.sv_n_updateTarget( self, params )
	self.network:sendToClients( "cl_n_updateTarget", params )
end

function TotebotCharacter.cl_n_updateTarget( self, params )
	self.cl.target = params.target
end

function TotebotCharacter.sv_e_unitDebugText( self, text )
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