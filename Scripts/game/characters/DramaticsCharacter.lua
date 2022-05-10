DramaticsCharacter = class( nil )

function DramaticsCharacter.server_onCreate( self )
	BaseCharacter.server_onCreate( self )
	local player = self.character:getPlayer()
	if player then
		sm.event.sendToPlayer( player, "sv_e_onSpawnCharacter" )
	end
end

function DramaticsCharacter.client_onCreate( self )
	self.animations = {}
	--self.isLocal = self.character:getPlayer() == sm.localPlayer.getPlayer()
	--TODO isLocal check that works the first frame, sm.localPlayer.getPlayer() crashes the game
	self.isLocal = false
	self.currentAnimation = ""
	self.currentFPAnimation = ""
end

function DramaticsCharacter.client_onGraphicsLoaded( self )
	self.isLocal = self.character:getPlayer() == sm.localPlayer.getPlayer()
	self.graphicsLoaded = true

	-- Third person animations
	self.animations = {}

	self.animations.dramatics_standup = {
		info = self.character:getAnimationInfo( "dramatics_standup" ),
		time = 0,
		weight = 0
	}

	self.animations.dramatics_victory_in = {
		info = self.character:getAnimationInfo( "dramatics_victory_in" ),
		time = 0,
		weight = 0
	}

	self.animations.dramatics_victory_loop = {
		info = self.character:getAnimationInfo( "dramatics_victory_loop" ),
		time = 0,
		weight = 0,
		looping = true
	}

	self.abortableCutsceneAnimations = { "dramatics_standup" }

	self.blendSpeed = 5.0
	self.blendTime = 0.2

	-- First person animations
	if self.isLocal then
		self.FPanimations = {}
	end
	self.animationsLoaded = true
end

function DramaticsCharacter.client_onGraphicsUnloaded( self )
	self.graphicsLoaded = false
	self.currentAnimation = ""
	self.currentFPAnimation = ""
end

function DramaticsCharacter.client_onUpdate( self, deltaTime )
	if not self.graphicsLoaded then
		return
	end

	-- Third person animations
	for name, animation in pairs(self.animations) do
		if animation.info then
			animation.time = animation.time + deltaTime

			if animation.info.looping == true then
				if animation.time >= animation.info.duration then
					animation.time = animation.time - animation.info.duration
				end
			end
			if name == self.currentAnimation then
				animation.weight = math.min(animation.weight+(self.blendSpeed * deltaTime), 1.0)
				if animation.time >= animation.info.duration then
					self.currentAnimation = ""
				end
			else
				animation.weight = math.max(animation.weight-(self.blendSpeed * deltaTime ), 0.0)
			end

			self.character:updateAnimation( animation.info.name, animation.time, animation.weight )
		end
	end

	if self.isLocal then
		self:cl_localUpdate( deltaTime )
	end
end

function DramaticsCharacter.cl_localUpdate( self, deltaTime )
	-- First person animations
	for name, animation in pairs( self.FPanimations ) do
		if animation.info then
			animation.time = animation.time + deltaTime

			if animation.info.looping == true then
				if animation.time >= animation.info.duration then
					animation.time = animation.time - animation.info.duration
				end
			end
			if name == self.currentFPAnimation then
				animation.weight = math.min(animation.weight+(self.blendSpeed * deltaTime), 1.0)
				if animation.time >= animation.info.duration then
					self.currentFPAnimation = ""
				end
			else
				animation.weight = math.max(animation.weight-(self.blendSpeed * deltaTime ), 0.0)
			end
			sm.localPlayer.updateFpAnimation( animation.info.name, animation.time, animation.weight, animation.info.looping )
		end
	end
end

function DramaticsCharacter.client_onEvent( self, event )
	self:cl_handleEvent( event )
end

function DramaticsCharacter.cl_handleEvent( self, event )
	if not self.animationsLoaded then
		return
	end

	if event == "dramatics_standup" then
		self.currentAnimation = "dramatics_standup"
		self.animations.dramatics_standup.time = 0
	elseif event == "dramatics_victory_in" then
		self.currentAnimation = "dramatics_victory_in"
		self.animations.dramatics_victory_in.time = 0
	elseif event == "dramatics_victory_loop" then
		self.currentAnimation = "dramatics_victory_loop"
		self.animations.dramatics_victory_loop.time = 0
	end
end

function DramaticsCharacter.cl_e_onCancel( self )
	-- Abort cutscene animations
	if isAnyOf( self.currentAnimation, self.cutsceneAnimations ) then
		self.animations[self.currentAnimation].time = 0
		self.currentAnimation = ""
	end
end