WocCharacter = class( nil )

function WocCharacter.server_onCreate( self )
	self:server_onRefresh()
end

function WocCharacter.server_onRefresh( self )

end

function WocCharacter.client_onCreate( self )
	self.animations = {}
	--print( "-- WocCharacter created --" )
	self:client_onRefresh()
	
end

function WocCharacter.client_onDestroy( self )
	--print( "-- WocCharacter destroyed --" )
end

function WocCharacter.client_onRefresh( self )
	--print( "-- WocCharacter refreshed --" )
end

function WocCharacter.client_onGraphicsLoaded( self )
	self.animations.tinker = {
		info = self.character:getAnimationInfo( "cow_eat_grass" ),
		time = 0,
		weight = 0
	}
	self.animationsLoaded = true

	self.blendSpeed = 5.0
	self.blendTime = 0.2
	
	self.currentAnimation = ""
	
	self.character:setMovementEffects( "$SURVIVAL_DATA/Character/Char_Cow/movement_effects.json" )
	self.eatEffect = sm.effect.createEffect( "Woc - Eating", self.character, "jnt_head" )
	self.mooEffect = sm.effect.createEffect( "Woc - Moo", self.character, "jnt_head" )
	self.graphicsLoaded = true
end

function WocCharacter.client_onGraphicsUnloaded( self )
	self.graphicsLoaded = false

	if self.eatEffect then
		self.eatEffect:destroy()
		self.eatEffect = nil
	end
	if self.mooEffect then
		self.mooEffect:destroy()
		self.mooEffect = nil
	end
end

function WocCharacter.client_onUpdate( self, deltaTime )
	if not self.graphicsLoaded then
		return
	end

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

	for name, animation in pairs(self.animations) do
		animation.time = animation.time + deltaTime
	
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

function WocCharacter.client_onEvent( self, event )
	if not self.animationsLoaded then
		return
	end

	if event == "eat" then
		self.currentAnimation = "tinker"
		self.animations.tinker.time = 0
		if self.graphicsLoaded then
			self.eatEffect:start()
		end
	elseif event == "moo" then
		if self.graphicsLoaded then
			self.mooEffect:start()
		end
	elseif event == "hit" then
		self.currentAnimation = ""
		if self.graphicsLoaded then
			self.eatEffect:stop()
		end
	end

end

function WocCharacter.sv_e_unitDebugText( self, text )
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