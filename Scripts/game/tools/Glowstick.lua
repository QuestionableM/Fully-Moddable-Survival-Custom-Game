dofile( "$GAME_DATA/Scripts/game/AnimationUtil.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

Glowstick = class()

local renderables =   {"$SURVIVAL_DATA/Character/Char_Glowstick/char_glowstick.rend" }
local renderablesTp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_glowstick.rend", "$SURVIVAL_DATA/Character/Char_Glowstick/char_glowstick_tp_animlist.rend"}
local renderablesFp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_glowstick.rend", "$SURVIVAL_DATA/Character/Char_Glowstick/char_glowstick_fp_animlist.rend"}

local currentRenderablesTp = {}
local currentRenderablesFp = {}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

function Glowstick.client_onCreate( self )
	self:cl_init()
end

function Glowstick.client_onRefresh( self )
	self:cl_init()
end

function Glowstick.cl_init( self )
	self:cl_loadAnimations()
	self.glowEffect = sm.effect.createEffect( "Glowstick - Hold" )
end

function Glowstick.cl_loadAnimations( self )
	
	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			idle = { "glowstick_idle" },
			use = { "glowstick_use", { nextAnimation = "idle" } },
			sprint = { "glowstick_sprint" },
			pickup = { "glowstick_pickup", { nextAnimation = "idle" } },
			putdown = { "glowstick_putdown" }
		
		}
	)
	local movementAnimations = {
	
		idle = "glowstick_idle",
		
		runFwd = "glowstick_run_fwd",
		runBwd = "glowstick_run_bwd",
		sprint = "glowstick_sprint",
		
		jump = "glowstick_jump_start",
		jumpUp = "glowstick_jump_up",
		jumpDown = "glowstick_jump_down",
		
		land = "glowstick_jump_land",
		landFwd = "glowstick_jump_land_fwd",
		landBwd = "glowstick_jump_land_bwd",

		crouchIdle = "glowstick_crouch_idle",
		crouchFwd = "glowstick_crouch_fwd",
		crouchBwd = "glowstick_crouch_bwd"
	}

	for name, animation in pairs( movementAnimations ) do
		self.tool:setMovementAnimation( name, animation )
	end

	if self.tool:isLocal() then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				idle = { "glowstick_idle", { looping = true } },
				use = { "glowstick_use", { nextAnimation = "idle" } },
				equip = { "glowstick_pickup", { nextAnimation = "idle" } },
				unequip = { "glowstick_putdown" }
			}
		)
	end
	setTpAnimation( self.tpAnimations, "idle", 5.0 )
	self.blendTime = 0.2
	
end

function Glowstick.client_onUpdate( self, dt )

	-- First person animation	
	local isSprinting =  self.tool:isSprinting() 
	local isCrouching =  self.tool:isCrouching() 
	
	if self.tool:isLocal() then
		updateFpAnimations( self.fpAnimations, self.equipped, dt )
	end
	
	if self.glowEffect then
		local effectPos = self.tool:getTpBonePos( "jnt_right_hand" )
		local character = self.tool:getOwner().character
		if character and sm.exists( character ) then
			effectPos.z = character.worldPosition.z
		end
		self.glowEffect:setPosition( effectPos )
		if self.equipped and not self.glowEffect:isPlaying() then
			self.glowEffect:start()
		elseif not self.equipped and self.glowEffect:isPlaying() then
			self.glowEffect:stop()
		end
	end
	

	if not self.equipped then
		if self.wantEquipped then
			self.wantEquipped = false
			self.equipped = true
		end
		return
	end	
	
	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight 
	local totalWeight = 0.0
	
	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )
			
			if animation.looping == true then
				if animation.time >= animation.info.duration then
					animation.time = animation.time - animation.info.duration
				end
			end
			if animation.time >= animation.info.duration - self.blendTime and not animation.looping then
				if ( name == "use" ) then
					setTpAnimation( self.tpAnimations, "idle", 10.0 )
				elseif name == "pickup" then
					setTpAnimation( self.tpAnimations, "idle", 0.001 )
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.tpAnimations, animation.nextAnimation, 0.001 )
				end
				
			end
		else
			animation.weight = math.max( animation.weight - ( self.tpAnimations.blendSpeed * dt ), 0.0 )
		end

		totalWeight = totalWeight + animation.weight
	end
	
	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs( self.tpAnimations.animations ) do
		
		local weight = animation.weight / totalWeight
		if name == "idle" then
			self.tool:updateMovementAnimation( animation.time, weight )
		elseif animation.crouch then
			self.tool:updateAnimation( animation.info.name, animation.time, weight * normalWeight )
			self.tool:updateAnimation( animation.crouch.name, animation.time, weight * crouchWeight )
		else
			self.tool:updateAnimation( animation.info.name, animation.time, weight )
		end
	end
	
end

function Glowstick.client_onEquip( self )
	
	self.wantEquipped = true
	
	currentRenderablesTp = {}
	currentRenderablesFp = {}
	
	for k,v in pairs( renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	
	self.tool:setTpRenderables( currentRenderablesTp )
	if self.tool:isLocal() then
		self.tool:setFpRenderables( currentRenderablesFp )
	end
	
	self:cl_loadAnimations()
	
	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
	if self.tool:isLocal() then
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end

end

function Glowstick.client_onUnequip( self )
	self.wantEquipped = false
	self.equipped = false
	self.pendingThrowFlag = false
	if sm.exists( self.tool ) then
		setTpAnimation( self.tpAnimations, "putdown" )
		if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
			swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
		end
	end
end

-- Start


-- Interact
function Glowstick.client_onEquippedUpdate( self, primaryState, secondaryState, forceBuildActive )

	if self.pendingThrowFlag then
		local time = 0.0
		local frameTime = 0.0
		if self.fpAnimations.currentAnimation == "use" then
			time = self.fpAnimations.animations["use"].time
			frameTime = 1.175
		end
		if time >= frameTime and frameTime ~= 0 then
			self.pendingThrowFlag = false
			if self.tool:getOwner().character then
				local dir = sm.localPlayer.getDirection()
				local firePos = GetOwnerPosition( self.tool ) + sm.vec3.new( 0, 0, 0.5 )
				-- Scale down throw velocity when looking down
				local maxVelocity = 20.0
				local minVelocity = 5.0
				local directionForceScale = math.min( ( dir:dot( sm.vec3.new( 0, 0, 1 ) ) + 1.0 ), 1.0 )
				local fireVelocity = math.max( maxVelocity * directionForceScale, minVelocity )
				sm.projectile.projectileAttack( projectile_glowstick, 0, firePos, dir * fireVelocity, self.tool:getOwner() )
				local params = { selectedSlot = sm.localPlayer.getSelectedHotbarSlot() }
				self.network:sendToServer( "sv_n_onUse", params )
			end
		end
		return true, true
	elseif not forceBuildActive then
		if primaryState == sm.tool.interactState.start then
			local activeItem = sm.localPlayer.getActiveItem()
			if sm.container.canSpend( sm.localPlayer.getInventory(), activeItem, 1 ) then
				self:onUse()
				self.pendingThrowFlag = true
			end
		end
		return true, false
	end
	
	return false, false
	
end

function Glowstick.onUse( self )
	if self.tool:isLocal() then
		setFpAnimation( self.fpAnimations, "use", 0.25 )
	end
	setTpAnimation( self.tpAnimations, "use", 10.0 )

	sm.effect.playHostedEffect( "Glowstick - Throw", self.tool:getOwner():getCharacter() )
end

function Glowstick.cl_n_onUse( self )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onUse()
	end
end

function Glowstick.sv_n_onUse( self, params, player )
	self.network:sendToClients( "cl_n_onUse" )
end
