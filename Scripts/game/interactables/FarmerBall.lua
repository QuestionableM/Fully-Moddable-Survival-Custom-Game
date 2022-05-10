-- FarmerBall.lua --

FarmerBall = class()


function FarmerBall.client_onCreate( self )
	self.cl = {}
	
	self.cl.rollingEffect = sm.effect.createEffect( "FarmerBall - Rolling", self.interactable )
	self.cl.idleEffect = sm.effect.createEffect( "FarmerBall - Help", self.interactable )
	self.cl.rollingEffect:start()
	
	-- Setup animations
	self.cl.animationEffects = {}
	local animations = {}
	if self.data then
		if self.data.animationList then
			for i, animation in ipairs( self.data.animationList ) do
				local duration = self.interactable:getAnimDuration( animation.name )
				animations[animation.name] = self:cl_createAnimation( animation.name, duration, animation.nextAnimation, animation.looping, animation.playForward )
				if animation.effect then
					self.cl.animationEffects[animation.name] = sm.effect.createEffect( animation.effect.name, self.interactable, animation.effect.joint )
				end
			end		
		end
	end
	self.cl.animations = animations
	self:cl_setAnimation( self.cl.animations["Idle"], 0.0 )
	
	-- Additive animations
	self.interactable:setAnimEnabled( "Velocity", true)
	self.interactable:setAnimProgress( "Velocity", 0.0 )
	self.cl.animVelocity = 0.0
	
	self.interactable:setAnimEnabled( "Shake", true)
	self.interactable:setAnimProgress( "Shake", 0.0 )
	self.cl.shakeAnimation = self:cl_createAnimation( "Shake", self.interactable:getAnimDuration( "Shake" ) )
end

function FarmerBall.client_onDestroy( self )
	self.cl.rollingEffect:destroy()
	self.cl.idleEffect:destroy()
end

function FarmerBall.client_onUpdate( self, dt )
	local velocity = self.shape:getBody():getAngularVelocity():length()
	self.cl.rollingEffect:setParameter( "Velocity_max_50", velocity )
	
	if velocity > 0 then
		if self.cl.idleEffect:isPlaying() then
			self.cl.idleEffect:stop()
		end
	else
		if not self.cl.idleEffect:isPlaying() then
			self.cl.idleEffect:start()
		end
	end
	
	self:cl_selectAnimation( dt, velocity )
	self:cl_updateAnimation( dt )
end

function FarmerBall.cl_createAnimation( self, name, playTime, nextAnimation, looping, playForward )
	local animation = 
	{
		-- Required
		name = name,
		playProgress = 0.0,
		playTime = playTime,
		isActive = false,
		-- Optional
		looping = looping,
		playForward = ( playForward or playForward == nil ),
		nextAnimation = nextAnimation
	}
	return animation
end

function FarmerBall.cl_setAnimation( self, animation, playProgress )
	self:cl_unsetAnimation()
	animation.isActive = true
	animation.playProgress = playProgress
	self.interactable:setAnimEnabled(animation.name, true)
	local effect = self.cl.animationEffects[animation.name]
	if playProgress == 0.0 and effect then
		effect:start()
	end
end

function FarmerBall.cl_unsetAnimation( self )
	for name, animation in pairs( self.cl.animations ) do
		animation.isActive = false
		animation.playProgress = 0.0
		self.interactable:setAnimEnabled( animation.name, false )
		self.interactable:setAnimProgress( animation.name, animation.playProgress )
	end
end

function FarmerBall.cl_selectAnimation( self, dt, velocity )

	-- Velocity additive animation
	local topVelocity = 8.0 -- TWEAKABLE ( 0.0, huge )
	local desiredAnimVelocity = math.min( math.max( velocity / topVelocity, 0.0 ), 1.0 )
	local animVelocityDelta = math.abs( desiredAnimVelocity - self.cl.animVelocity )
	self.cl.animVelocity = magicInterpolation( self.cl.animVelocity, desiredAnimVelocity, dt, 1.0 / 15.0 )
	self.interactable:setAnimProgress( "Velocity", self.cl.animVelocity )
	
	-- Shake additive animation
	local shakeThreshold = 0.1 -- TWEAKABLE ( 0.0, 1.0 )
	if animVelocityDelta > shakeThreshold then
		self.cl.shakeAnimation.isActive = true
	end
	if self.cl.shakeAnimation.isActive then
		self.cl.shakeAnimation.playProgress = self.cl.shakeAnimation.playProgress + dt / self.cl.shakeAnimation.playTime
		if self.cl.shakeAnimation.playProgress > 1.0 then
			self.cl.shakeAnimation.playProgress = 0.0
			self.cl.shakeAnimation.isActive = false
		end
	end
	self.interactable:setAnimProgress( "Shake", self.cl.shakeAnimation.playProgress )
	
	-- Random Idle and Idlescream animation
	if self.cl.animations["Idle"].isActive and self.cl.animations["Idle"].playProgress >= 1.0 then
		local screamChance = 50 -- TWEAKABLE ( 0, 100 )
		if math.random( 0, 99 ) < screamChance then
			self:cl_setAnimation( self.cl.animations["Idlescream"], self.cl.animations["Idle"].playProgress - 1.0 )
		else
			self:cl_setAnimation( self.cl.animations["Idle"], self.cl.animations["Idle"].playProgress - 1.0 )
		end
	end
	if self.cl.animations["Idlescream"].isActive and self.cl.animations["Idlescream"].playProgress >= 1.0 then
		self:cl_setAnimation( self.cl.animations["Idle"], self.cl.animations["Idlescream"].playProgress - 1.0 )
	end
end

function FarmerBall.cl_updateAnimation( self, dt )
	
	for name, animation in pairs( self.cl.animations ) do
		if animation.isActive then
			self.interactable:setAnimEnabled(animation.name, true)
			if animation.playForward then
				animation.playProgress = animation.playProgress + dt / animation.playTime
				if animation.playProgress > 1.0 then
					if animation.looping then
						animation.playProgress = animation.playProgress - 1.0
					else
						if animation.nextAnimation then
							self:cl_setAnimation( self.cl.animations[animation.nextAnimation], 0.0)
							return
						else
							animation.playProgress = 1.0
						end
					end
				end
				self.interactable:setAnimProgress(animation.name, animation.playProgress ) 
			else
				animation.playProgress = animation.playProgress - dt / animation.playTime
				if animation.playProgress < -1.0 then
					if animation.looping then
						animation.playProgress = animation.playProgress + 1.0
					else
						if animation.nextAnimation then
							self:cl_setAnimation( self.cl.animations[animation.nextAnimation], 0.0)
							return
						else
							animation.playProgress = -1.0
						end
					end
				end
				self.interactable:setAnimProgress(animation.name, 1.0 + animation.playProgress )
			end
		end
	end
	
end