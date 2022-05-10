
dofile "$SURVIVAL_DATA/Scripts/util.lua"

AnimationTester = class( nil )

function AnimationTester.cl_createAnimation( self, name, playTime )
	local animation = 
	{
		name = name,
		playProgress = 0.0,
		playTime = playTime,
		isActive = false,
		looping = false,
		playForward = true,
		nextAnimation = nil
	}
	return animation
end

function AnimationTester.cl_setAnimation( self, animation, playProgress )
	self:cl_unsetAnimation()
	animation.isActive = true
	animation.playProgress = playProgress
	self.interactable:setAnimEnabled(animation.name, true)
end

function AnimationTester.cl_unsetAnimation( self )
	for name, animation in pairs( self.cl.animations ) do
		animation.isActive = false
		animation.playProgress = 0.0
		self.interactable:setAnimEnabled( animation.name, false )
		self.interactable:setAnimProgress( animation.name, animation.playProgress )
	end
end

function AnimationTester.cl_updateAnimation( self, dt )
	
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
							self:cl_setAnimation(animation.nextAnimation, 0.0)
							return
						else
							if self.cl.mode then
								animation.playProgress = 1.0
							else
								self:cl_nextAnimation()
							end
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
							self:cl_setAnimation(animation.nextAnimation, 0.0)
							return
						else
							if self.cl.mode then
								animation.playProgress = -1.0
							else
								self:cl_nextAnimation()
							end
						end
					end
				end
				self.interactable:setAnimProgress(animation.name, 1.0 + animation.playProgress )
			end
		end
	end
	
end

function AnimationTester.client_onCreate(self)
	self.cl = {}
	self:cl_init()
end

function AnimationTester.client_onDestroy(self)
	for name, effect in pairs( self.cl.effects ) do
		effect:stop()
	end
end

function AnimationTester.cl_init(self)
	
	self.cl.idxAnimationNames = {}
	self.cl.effects = {}
	local animations = {}
	if self.data then
		if self.data.animationList then
			for i, animation in ipairs( self.data.animationList ) do
				local duration = self.interactable:getAnimDuration( animation.name )
				animations[animation.name] = self:cl_createAnimation( animation.name, duration )
				self.cl.idxAnimationNames[#self.cl.idxAnimationNames+1] = animation.name
				if animation.effect then
					self.cl.effects[animation.name] = sm.effect.createEffect( animation.effect.name, self.interactable, animation.effect.joint )
				end
			end		
		end
	end
	self.cl.mode = true
	self.cl.animations = animations
	self.cl.currentAnimationIdx = 1
	local name = self.cl.idxAnimationNames[self.cl.currentAnimationIdx]
	self:cl_setAnimation( self.cl.animations[name], 0.0 )

end

function AnimationTester.client_onRefresh(self)
	self:cl_init()
end

function AnimationTester.client_onUpdate(self, dt)
	self:cl_updateAnimation( dt )
end

function AnimationTester.client_onInteract(self, character, state)
	if state == true then
		self:cl_nextAnimation()
	end
end

function AnimationTester.cl_nextAnimation( self )
	self.cl.currentAnimationIdx = ( self.cl.currentAnimationIdx % #self.cl.idxAnimationNames ) +1
	local name = self.cl.idxAnimationNames[self.cl.currentAnimationIdx]
	self:cl_setAnimation( self.cl.animations[name], 0.0 )
	local effect = self.cl.effects[name]
	if effect then
		effect:start()
	end
end

function AnimationTester.cl_switchMode( self )
	self.cl.mode = not self.cl.mode
end

function AnimationTester.server_onMelee( self )
	self.network:sendToClients( "cl_switchMode" )
end
