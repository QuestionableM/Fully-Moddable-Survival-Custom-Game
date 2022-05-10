
dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

Fertilizer = class()

local renderables =   {"$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer.rend" }
local renderablesTp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_fertilizer.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_tp_animlist.rend"}
local renderablesFp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_fertilizer.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_fp_animlist.rend"}

local currentRenderablesTp = {}
local currentRenderablesFp = {}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )


function Fertilizer.client_onCreate( self )
	self:cl_init()
end

function Fertilizer.client_onRefresh( self )
	self:cl_init()
end

function Fertilizer.cl_init( self )
	self:cl_loadAnimations()
end

function Fertilizer.cl_loadAnimations( self )

	self.tpAnimations = createTpAnimations(
			self.tool,
			{
				idle = { "fertilizer_idle", { looping = true } },
				use = { "fertilizer_paint", { nextAnimation = "idle" } },
				sprint = { "fertilizer_sprint" },
				pickup = { "fertilizer_pickup", { nextAnimation = "idle" } },
				putdown = { "fertilizer_putdown" }

			}
		)
		local movementAnimations = {

			idle = "fertilizer_idle",
			idleRelaxed = "fertilizer_idle_relaxed",

			runFwd = "fertilizer_run_fwd",
			runBwd = "fertilizer_run_bwd",
			sprint = "fertilizer_sprint",

			jump = "fertilizer_jump",
			jumpUp = "fertilizer_jump_up",
			jumpDown = "fertilizer_jump_down",

			land = "fertilizer_jump_land",
			landFwd = "fertilizer_jump_land_fwd",
			landBwd = "fertilizer_jump_land_bwd",

			crouchIdle = "fertilizer_crouch_idle",
			crouchFwd = "fertilizer_crouch_fwd",
			crouchBwd = "fertilizer_crouch_bwd"
		}

		for name, animation in pairs( movementAnimations ) do
			self.tool:setMovementAnimation( name, animation )
		end

		if self.tool:isLocal() then
			self.fpAnimations = createFpAnimations(
				self.tool,
				{
					idle = { "fertilizer_idle", { looping = true } },

					sprintInto = { "fertilizer_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
					sprintIdle = { "fertilizer_sprint_idle", { looping = true } },
					sprintExit = { "fertilizer_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },

					use = { "fertilizer_paint", { nextAnimation = "idle" } },

					equip = { "fertilizer_pickup", { nextAnimation = "idle" } },
					unequip = { "fertilizer_putdown" }
				}
			)
		end
		setTpAnimation( self.tpAnimations, "idle", 5.0 )
		self.blendTime = 0.2

end

function Fertilizer.client_onUpdate( self, dt )

	-- First person animation
	local isSprinting =  self.tool:isSprinting()
	local isCrouching =  self.tool:isCrouching()

	if self.tool:isLocal() then
		if self.equipped then
			if isSprinting and self.fpAnimations.currentAnimation ~= "sprintInto" and self.fpAnimations.currentAnimation ~= "sprintIdle" then
				swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.0 )
			elseif not self.tool:isSprinting() and ( self.fpAnimations.currentAnimation == "sprintIdle" or self.fpAnimations.currentAnimation == "sprintInto" ) then
				swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.0 )
			end
		end
		updateFpAnimations( self.fpAnimations, self.equipped, dt )
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

function Fertilizer.client_onEquip( self )

	self.wantEquipped = true

	currentRenderablesTp = {}
	currentRenderablesFp = {}

	for k,v in pairs( renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	local color = sm.item.getShapeDefaultColor( obj_consumable_fertilizer )
	self.tool:setTpRenderables( currentRenderablesTp )
	self.tool:setTpColor( color )
	if self.tool:isLocal() then
		self.tool:setFpRenderables( currentRenderablesFp )
		self.tool:setFpColor( color )
	end

	self:cl_loadAnimations()

	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
	if self.tool:isLocal() then
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function Fertilizer.client_onUnequip( self )
	self.wantEquipped = false
	self.equipped = false
	if sm.exists( self.tool ) then
		setTpAnimation( self.tpAnimations, "putdown" )
		if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
			swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
		end
	end
end

function Fertilizer.client_onEquippedUpdate( self, primaryState, secondaryState )

	-- Detect soil
	local farmHarvestable = nil
	local success, result = sm.localPlayer.getRaycast( 7.5 )
	if result.type == "harvestable" then
		local harvestable = result:getHarvestable()
		if harvestable:getType() == "farm" then
			farmHarvestable = harvestable

			if not farmHarvestable.clientPublicData or not farmHarvestable.clientPublicData.fertilizer then
				sm.gui.setCenterIcon( "Use" )
				local keyBindingText =  sm.gui.getKeyBinding( "Create", true )
				sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_FERTILIZE}" )

				-- Fertilize harvestable
				if primaryState == sm.tool.interactState.start then
					local params = { targetSoil = farmHarvestable, playerInventory = sm.localPlayer.getInventory(), slot = sm.localPlayer.getSelectedHotbarSlot() }
					self:onUse()
					self.network:sendToServer( "sv_n_fertilize", params )
				end
			end
		end
	end

	return farmHarvestable ~= nil, false

end

function Fertilizer.onUse( self )
	if self.tool:isLocal() then
		setFpAnimation( self.fpAnimations, "use", 0.25 )
	end
	setTpAnimation( self.tpAnimations, "use", 10.0 )

	if self.tool:isLocal() and self.tool:isInFirstPersonView() then
		local effectPos = sm.localPlayer.getFpBonePos( "jnt_fertilizer" )
		if effectPos then
			local rot = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), sm.localPlayer.getDirection() )

			local fovScale = ( sm.camera.getFov() - 45 ) / 45

			local xOffset45 = sm.localPlayer.getRight() * 0.12
			local yOffset45 = sm.localPlayer.getDirection() * 0.65
			local zOffset45 = sm.localPlayer.getUp() * -0.1
			local offset45 = xOffset45 + yOffset45 + zOffset45

			local xOffset90 = sm.localPlayer.getRight() * 0.375
			local yOffset90 = sm.localPlayer.getDirection() * 0.65
			local zOffset90 = sm.localPlayer.getUp() * -0.3
			local offset90 = xOffset90 + yOffset90 + zOffset90

			local offset = sm.vec3.lerp( offset45, offset90, fovScale )

			sm.effect.playEffect( "Itemtool - FPFertilizerUse", effectPos + offset, nil, rot )
		end
	else
		sm.effect.playHostedEffect("Itemtool - FertilizerUse", self.tool:getOwner():getCharacter(), "jnt_fertilizer" )
	end
end

function Fertilizer.cl_n_onUse( self )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onUse()
	end
end

function Fertilizer.sv_n_fertilize( self, params )
	if params.targetSoil and sm.exists( params.targetSoil ) then
		sm.event.sendToHarvestable( params.targetSoil, "sv_e_fertilize", params )
		self.network:sendToClients( "cl_n_onUse" )
	end
end