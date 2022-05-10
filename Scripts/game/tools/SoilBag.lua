dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

SoilBag = class()

local soilbagRenderables = { "$SURVIVAL_DATA/Character/Char_Tools/Char_soilbag/char_soilbag.rend" }

local renderablesTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_soilbag.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_soilbag/char_soilbag_tp.rend" }
local renderablesFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_soilbag.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_soilbag/char_soilbag_fp.rend" }

sm.tool.preloadRenderables( soilbagRenderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

function SoilBag.client_onCreate( self )
	self.effect = sm.effect.createEffect( "ShapeRenderable" )
	self.effect:setParameter( "uuid", sm.uuid.new("42c8e4fc-0c38-4aa8-80ea-1835dd982d7c") )
	self.effect:setParameter( "visualization", true )
	self.effect:setScale( sm.vec3.new( sm.construction.constants.subdivideRatio, sm.construction.constants.subdivideRatio, sm.construction.constants.subdivideRatio ) )
	self:client_onRefresh()
end

function SoilBag.client_onRefresh( self )
	if self.tool:isLocal() then
		self.lastSentItem = nil
		self.activeItem = sm.localPlayer.getActiveItem()
	end
	self:cl_updateSoilbagRenderables()
	self:cl_loadAnimations()
end

function SoilBag.cl_loadAnimations( self )

	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			idle = { "soilbag_idle", { looping = true } },
			use = { "soilbag_use", { nextAnimation = "idle" } },
			pickup = { "soilbag_pickup", { nextAnimation = "idle" } },
			putdown = { "soilbag_putdown" }
		
		}
	)
	local movementAnimations = {

		idle = "soilbag_idle",
		
		runFwd = "soilbag_run_fwd",
		runBwd = "soilbag_run_bwd",
		
		jump = "soilbag_jump",
		jumpUp = "soilbag_jump_up",
		jumpDown = "soilbag_jump_down",

		land = "soilbag_jump_land",
		landFwd = "soilbag_jump_land_fwd",
		landBwd = "soilbag_jump_land_bwd",

		crouchIdle = "soilbag_crouch_idle",
		crouchFwd = "soilbag_crouch_fwd",
		crouchBwd = "soilbag_crouch_bwd"
	}
	
	for name, animation in pairs( movementAnimations ) do
		self.tool:setMovementAnimation( name, animation )
	end
	
	if self.tool:isLocal() then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				idle = { "soilbag_idle", { looping = true } },
				use = { "soilbag_use", { nextAnimation = "idle" } },
				equip = { "soilbag_pickup", { nextAnimation = "idle" } },
				unequip = { "soilbag_putdown" }
			}
		)
	end
	setTpAnimation( self.tpAnimations, "idle", 5.0 )
	self.blendTime = 0.2
	
end

function SoilBag.cl_updateSoilbagRenderables( self )

	local currentRenderablesTp = {}
	local currentRenderablesFp = {}
	
	for k,v in pairs( renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	for k,v in pairs( soilbagRenderables ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( soilbagRenderables ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	
	self.tool:setTpRenderables( currentRenderablesTp )
	if self.tool:isLocal() then
		self.tool:setFpRenderables( currentRenderablesFp )
	end
	
end

function SoilBag.client_onDestroy( self )
	self.effect:stop()
end

function SoilBag.client_onUpdate( self, dt )

	-- First person animation	
	local isCrouching =  self.tool:isCrouching() 
	
	if self.tool:isLocal() then
		self.tool:setBlockSprint( ( self.equipped and true or false ) )
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
			
			if animation.time >= animation.info.duration - self.blendTime then
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

function SoilBag.constructionRayCast( self )

	local valid, result = sm.localPlayer.getRaycast( 7.5 )
	if valid then
		if result.type == "terrainSurface" then

			local groundPointOffset = -( sm.construction.constants.subdivideRatio_2 - 0.04 + sm.construction.constants.shapeSpacing + 0.005 )
			local pointLocal = result.pointLocal + result.normalLocal * groundPointOffset

			-- Compute grid pos
			local size = sm.vec3.new( 3, 3, 1 )
			local size_2 = sm.vec3.new( 1, 1, 0 )
			local a = pointLocal * sm.construction.constants.subdivisions
			local gridPos = sm.vec3.new( math.floor( a.x ), math.floor( a.y ), a.z ) - size_2

			-- Compute world pos
			local worldPos = gridPos * sm.construction.constants.subdivideRatio + ( size * sm.construction.constants.subdivideRatio ) * 0.5

			return valid, worldPos, result.normalWorld
		end
	end
	return false
end

function SoilBag.client_onEquippedUpdate( self, primaryState, secondaryState, forceBuildActive )
	if self.tool:isLocal() then

		if forceBuildActive then
			if self.effect:isPlaying() then
				self.effect:stop()
			end
			return false, false
		end
		
		local valid, worldPos, worldNormal = ConstructionRayCast( { "terrainSurface" } )
		if valid then

			self.effect:setPosition( worldPos )
			self.effect:setRotation( sm.quat.angleAxis( math.pi*0.5, sm.vec3.new( 1, 0, 0 ) ) )

			if worldNormal.z < 0.97236992 then
				sm.gui.setInteractionText( "#{INFO_TOO_STEEP}" )
				self.effect:setParameter( "valid", false )

			elseif sm.physics.sphereContactCount( worldPos, 0.375, false, true ) > 0 then
				self.effect:setParameter( "valid", false )

			else
				sm.gui.setCenterIcon( "Use" )
				local keyBindingText =  sm.gui.getKeyBinding( "Create", true )
				sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_PUT_SOIL}" )

				self.effect:setParameter( "valid", true )

				if primaryState == sm.tool.interactState.start then
					self.network:sendToServer( "sv_n_putSoil", { pos = worldPos, slot = sm.localPlayer.getSelectedHotbarSlot() } )
					self:putSoil()
				end
			end

			local keyBindingText =  sm.gui.getKeyBinding( "ForceBuild", true )
			sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_FORCE_BUILD}" )

			if not self.effect:isPlaying() then
				self.effect:start()
			end

			return true, false
		else
			self.effect:stop()
			return false, false
		end
	end
	return false, false
end

function SoilBag.client_onEquip( self )
	if self.tool:isLocal() then
		self.activeItem = sm.localPlayer.getActiveItem()
		self:cl_updateSoilbagRenderables()
		self:cl_loadAnimations()
	end
	
	self.wantEquipped = true
	
	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
	if self.tool:isLocal() then
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function SoilBag.client_onUnequip( self )
	self.effect:stop()

	self.wantEquipped = false
	self.equipped = false
	if sm.exists( self.tool ) then
		setTpAnimation( self.tpAnimations, "putdown" )
		if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
			swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
		end
	end
end

function SoilBag.sv_n_putSoil( self, params, player )
	sm.container.beginTransaction()
	sm.container.spendFromSlot( player:getInventory(), params.slot, obj_consumable_soilbag, 1 )
	if sm.container.endTransaction() then
		local rot = math.random( 0, 3 ) * math.pi * 0.5
		sm.harvestable.createHarvestable( hvs_soil, params.pos, sm.quat.angleAxis( rot, sm.vec3.new( 0, 0, 1 ) ) * sm.quat.new( 0.70710678, 0, 0, 0.70710678 ) )
		sm.effect.playEffect( "Plants - SoilbagUse", params.pos, nil, sm.quat.angleAxis( rot, sm.vec3.new( 0, 0, 1 ) ) * sm.quat.new( 0.70710678, 0, 0, 0.70710678 ) )
		self.network:sendToClients( "cl_n_putSoil", params )
	end
end

function SoilBag.cl_n_putSoil( self, params )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:putSoil()
	end
end

function SoilBag.putSoil( self )
	if self.tool:isLocal() then
		setFpAnimation( self.fpAnimations, "use", 0.25 )
	end
	setTpAnimation( self.tpAnimations, "use", 10.0 )
end