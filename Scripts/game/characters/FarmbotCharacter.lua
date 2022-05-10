dofile "$SURVIVAL_DATA/Scripts/util.lua"

FarmbotCharacter = class( nil )

local alertRenderableTp = "$SURVIVAL_DATA/Character/Char_Farmbot/char_farmbot_alert.rend"
local roamingRenderableTp = "$SURVIVAL_DATA/Character/Char_Farmbot/char_farmbot_roaming.rend"
sm.character.preloadRenderables( { alertRenderableTp, roamingRenderableTp } )

local alertMovementEffects = "$SURVIVAL_DATA/Character/Char_Farmbot/alert_movement_effects.json"
local roamingMovementEffects = "$SURVIVAL_DATA/Character/Char_Farmbot/roaming_movement_effects.json"

function FarmbotCharacter.client_onCreate( self )

	self.cl = {}
	self.cl.animations = {}
	self.cl.animationSwitches = {}
	self.cl.currentAnimationSet = roamingRenderableTp
	self.cl.currentMovementEffects = roamingMovementEffects
	self.cl.target = nil

	--print( "-- FarmbotCharacter created --" )
	self:client_onRefresh()
end

function FarmbotCharacter.client_onDestroy( self )
	--print( "-- FarmbotCharacter destroyed --" )
end

function FarmbotCharacter.client_onRefresh( self )
	--print( "-- FarmbotCharacter refreshed --" )
	self.cl.headAngle = 0.0
	self.cl.currentAnimation = ""
end

function FarmbotCharacter.client_onGraphicsLoaded( self )
	self.character:addRenderable( self.cl.currentAnimationSet )
	self.character:setMovementEffects( self.cl.currentMovementEffects )
	self:cl_initGraphics()
	self:cl_initAnimationSwitch()
	self.character:setGlowMultiplier( 1 )
	self.graphicsLoaded = true
end

function FarmbotCharacter.client_onGraphicsUnloaded( self )
	self.graphicsLoaded = false
end

function FarmbotCharacter.cl_initGraphics( self )
	
	if not self.cl.animations.idlespecial01 then
		self.cl.animations.idlespecial01 = {
			info = self.character:getAnimationInfo( "idlespecial01" ),
			time = 0,
			weight = 0
		}
	end
	if not self.cl.animations.idlespecial02 then
		self.cl.animations.idlespecial02 = {
			info = self.character:getAnimationInfo( "idlespecial02" ),
			time = 0,
			weight = 0
		}
	end
	if not self.cl.animations.kick then
		self.cl.animations.kick = {
			info = self.character:getAnimationInfo( "attack01" ),
			time = 0,
			weight = 0,
			active = false,
			additive = true
		}
	end
	if not self.cl.animations.walkingswipe then
		self.cl.animations.walkingswipe = {
			info = self.character:getAnimationInfo( "attack02" ),
			time = 0,
			weight = 0,
			disableMovementAnimations = true
		}
	end
	if not self.cl.animations.standingswipe then
		self.cl.animations.standingswipe = {
			info = self.character:getAnimationInfo( "attack03" ),
			time = 0,
			weight = 0
		}
	end
	if not self.cl.animations.breachattack then
		self.cl.animations.breachattack = {
			info = self.character:getAnimationInfo( "attack04" ),
			time = 0,
			weight = 0
		}
	end
	if not self.cl.animations.runningswipe then
		self.cl.animations.runningswipe = {
			info = self.character:getAnimationInfo( "attack05" ),
			time = 0,
			weight = 0,
			disableMovementAnimations = true
		}
	end
	if not self.cl.animations.destroy then
		self.cl.animations.destroy = {
			info = self.character:getAnimationInfo( "destroy" ),
			time = 0,
			weight = 0
		}
	end
	if not self.cl.animations.angry then
		self.cl.animations.angry = {
			info = self.character:getAnimationInfo( "angry" ),
			time = 0,
			weight = 0
		}
	end
	if not self.cl.animations.aimIn then
		self.cl.animations.aimIn = {
			info = self.character:getAnimationInfo( "aim_in" ),
			time = 0,
			weight = 0
		}
	end
	if not self.cl.animations.aimIdle then
		self.cl.animations.aimIdle = {
			info = self.character:getAnimationInfo( "aim_idle" ),
			time = 0,
			weight = 0,
			active = false,
			looping = true
		}
	end
	if not self.cl.animations.aimOut then
		self.cl.animations.aimOut = {
			info = self.character:getAnimationInfo( "aim_out" ),
			time = 0,
			weight = 0
		}
	end
	if not self.cl.animations.shoot then
		self.cl.animations.shoot = {
			info = self.character:getAnimationInfo( "shoot" ),
			time = 0,
			weight = 0
		}
	end
	self.animationsLoaded = true

	self.cl.blendSpeed = 5.0
	self.cl.blendTime = 0.2
end

function FarmbotCharacter.cl_initAnimationSwitch( self )
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

function FarmbotCharacter.client_onUpdate( self, deltaTime )
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
	
	---- Update spine bending animation
	--local lookDirection = self.character.direction
	--if self.cl.currentAnimationSet == alertRenderableTp then
	--	if self.cl.target and sm.exists( self.cl.target ) then
	--		lookDirection = ( self.cl.target.worldPosition - self.character.worldPosition ):normalize()
	--	end
	--end
	--local angle = math.asin( lookDirection:dot( sm.vec3.new( 0, 0, 1 ) ) ) / ( math.pi / 2 )
	--local desiredHeadAngle = ( 0.5 + angle * 0.5 )
	--local headLerpSpeed = 1.0 / 6.0
	--local blend = math.pow( 1 - ( 1 - headLerpSpeed ), ( deltaTime * 60 ) )
	--self.cl.headAngle = lerp( self.cl.headAngle, desiredHeadAngle, blend )
	--self.character:updateAnimation( "tapebot_aimbend_uppdown", self.cl.headAngle, 1.0, true )
	
	-- Update animations
	local totalNonAdditiveWeight = 0.0
	for name, animation in pairs(self.cl.animations) do
		if animation.info and name ~= "aimIdle" then
			animation.time = animation.time + deltaTime
		
			if name == self.cl.currentAnimation then
				if animation.disableMovementAnimations then
					animation.weight = 1.0
					self.character:setMovementWeights( 0, 0 )
				else
					animation.weight = math.min(animation.weight+(self.cl.blendSpeed * deltaTime), 1.0)
					self.character:setMovementWeights( 1, 1 )
				end
				if animation.time >= animation.info.duration then
					self.cl.currentAnimation = ""
					if animation.disableMovementAnimations then
						self.character:setMovementWeights( 1, 1 )
					end
				end
			elseif animation.active then
				if animation.disableMovementAnimations then
					animation.weight = 1.0
					self.character:setMovementWeights( 0, 0 )
				else
					animation.weight = math.min(animation.weight+(self.cl.blendSpeed * deltaTime), 1.0)
					self.character:setMovementWeights( 1, 1 )
				end
				if animation.time >= animation.info.duration then
					if animation.looping then
						animation.time = animation.time % animation.info.duration
					else
						self.cl.animations[name].active = false
						if animation.disableMovementAnimations then
							self.character:setMovementWeights( 1, 1 )
						end
					end
				end
			else
				if animation.disableMovementAnimations then
					animation.weight = 0.0
				else
					animation.weight = math.max(animation.weight-( self.cl.blendSpeed * deltaTime ), 0.0)
				end
			end

			if not animation.additive then
				totalNonAdditiveWeight = totalNonAdditiveWeight + animation.weight
			end
			self.character:updateAnimation( animation.info.name, animation.time, animation.weight, animation.additive )
		end
	end
	local aimIdleAnimation = self.cl.animations["aimIdle"]
	if aimIdleAnimation.info then
		aimIdleAnimation.time = aimIdleAnimation.time + deltaTime
		if aimIdleAnimation.active then
			aimIdleAnimation.weight = math.min( math.max( aimIdleAnimation.weight + ( self.cl.blendSpeed * deltaTime ), 0.0), math.max( 1.0 - totalNonAdditiveWeight, 0.0 ) )
		else
			aimIdleAnimation.weight = math.max( aimIdleAnimation.weight - ( self.cl.blendSpeed * deltaTime ), 0.0)
		end
		self.character:updateAnimation( aimIdleAnimation.info.name, aimIdleAnimation.time, aimIdleAnimation.weight, aimIdleAnimation.additive )
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

function FarmbotCharacter.client_onEvent( self, event )
	self:client_handleEvent( event )
end

function FarmbotCharacter.client_handleEvent( self, event )
	if not self.animationsLoaded then
		return
	end

	if event == "alerted" then
		if self.cl.animationSwitches.alerted then
			self.cl.currentSwitch = "alerted"
			self.cl.animationSwitches.alerted.time = 0
			self.cl.animationSwitches.alerted.triggeredEvent = false
		end
	elseif event == "roaming" then
		if self.cl.animationSwitches.roaming then
			self.cl.currentSwitch = "roaming"
			self.cl.animationSwitches.roaming.time = 0
			self.cl.animationSwitches.roaming.triggeredEvent = false
		end
	elseif event == "angry" then
		self.cl.currentAnimation = "angry"
		self.cl.animations.angry.time = 0
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
	elseif event == "kick" then
		self.cl.animations.kick.active = true
		self.cl.animations.kick.time = 0
	elseif event == "walkingswipe" then
		self.cl.currentAnimation = "walkingswipe"
		self.cl.animations.walkingswipe.time = 0
	elseif event == "standingswipe" then
		self.cl.currentAnimation = "standingswipe"
		self.cl.animations.standingswipe.time = 0
	elseif event == "breachattack" then
		self.cl.currentAnimation = "breachattack"
		self.cl.animations.breachattack.time = 0
	elseif event == "runningswipe" then
		self.cl.currentAnimation = "runningswipe"
		self.cl.animations.runningswipe.time = 0
	elseif event == "explode" then
		self.cl.currentAnimation = "destroy"
		self.cl.animations.destroy.time = 0

		sm.effect.playHostedEffect( "Farmbot - DestructionStartup01", self.character, "jnt_spine2" )
		sm.effect.playHostedEffect( "Farmbot - DestructionStartup02", self.character, "head_jnt" )
		sm.effect.playHostedEffect( "Farmbot - DestructionStartup02", self.character, "r_arm01_jnt" )
		sm.effect.playHostedEffect( "Farmbot - DestructionStartup02", self.character, "l_arm01_jnt" )
		sm.effect.playHostedEffect( "Farmbot - DestructionStartup03", self.character, "r_arm04_jnt" )
		sm.effect.playHostedEffect( "Farmbot - DestructionStartup04", self.character, "leg02_jnt" )
		sm.effect.playHostedEffect( "Farmbot - DestructionStartup04", self.character, "leg04_jnt" )
	elseif event == "aimIn" then
		self.cl.currentAnimation = "aimIn"
		self.cl.animations.aimIn.time = 0
		self.cl.animations.aimIdle.active = true
		self.cl.animations.aimIdle.time = 0
	elseif event == "shoot" then
		self.cl.currentAnimation = "shoot"
		self.cl.animations.shoot.time = 0
		if self.graphicsLoaded then
			local muzzlePos = self.character:getTpBonePos( "nossle_jnt" )
			local muzzleRot = self.character:getTpBoneRot( "nossle_jnt" )
			sm.effect.playEffect( "Farmbot - Shoot", muzzlePos, nil, muzzleRot )
		end
	elseif event == "aimOut" then
		self.cl.currentAnimation = "aimOut"
		self.cl.animations.aimOut.time = 0
		self.cl.animations.aimIdle.active = false
		self.cl.animations.aimIdle.time = 0
	elseif event == "tumble" then
		self.cl.currentAnimation = ""
		self.cl.animations.aimIn.time = 0
		self.cl.animations.aimOut.time = 0
		self.cl.animations.aimIdle.active = false
		self.cl.animations.aimIdle.time = 0
	elseif event == "death" then
		SpawnDebris( self.character, "head_jnt", "Robotparts - FarmbotHead" )
		SpawnDebris( self.character, "l_arm02_jnt", "Robotparts - FarmbotCannonarm" )
		SpawnDebris( self.character, "drill_jnt", "Robotparts - FarmbotDrill" )
		SpawnDebris( self.character, "r_arm05_jnt", "Robotparts - FarmbotScyth" )
	end
end

function FarmbotCharacter.sv_e_updateTarget( self, params )
	self.network:sendToClients( "cl_n_updateTarget", params )
end

function FarmbotCharacter.cl_n_updateTarget( self, params )
	self.cl.target = params.target
end

function FarmbotCharacter.sv_e_characterEffect( self, params )
	self.network:sendToClients( "cl_n_characterEffect", params )
end

function FarmbotCharacter.cl_n_characterEffect( self, params )
	sm.effect.playHostedEffect( params.effectName, self.character, params.jointName, params.effectParams )
end

function FarmbotCharacter.sv_e_unitDebugText( self, text )
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
