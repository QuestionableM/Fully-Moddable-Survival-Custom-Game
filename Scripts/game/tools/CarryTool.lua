dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

CarryTool = class( nil )

local scrapwoodRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_scrapwood.rend"
}

local stoneRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_stone.rend"
}

local scrapmetalRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_scrapmetal.rend"
}

local woodRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_wood.rend"
}

local metalRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_metal.rend"
}

local harvestItems =
{
	obj_harvest_wood,
	obj_harvest_wood2,
	obj_harvest_metal,
	obj_harvest_metal2,
	obj_harvest_stone
}

local heavyRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool.rend"
}

local wormRenderables = {
	"$SURVIVAL_DATA/Character/Char_Tools/Char_toolgorp/char_toolgorp.rend"
}

local renderablesItemTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_item.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_tp_animlist.rend" }
local renderablesItemFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_item.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_item/char_item_fp_animlist.rend" }

local renderablesHeavyTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_heavytool.rend", "$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool_tp_animlist.rend" }
local renderablesHeavyFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_heavytool.rend", "$SURVIVAL_DATA/Character/Char_Tools/char_heavytool/char_heavytool_fp_animlist.rend" }

local renderablesWormTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_toolgorp.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_toolgorp/char_toolgorp_tp.rend" }
local renderablesWormFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_toolgorp.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_toolgorp/char_toolgorp_fp.rend" }


CarryTool.emptyTpRenderables = {}
CarryTool.emptyFpRenderables = {}

sm.tool.preloadRenderables( scrapwoodRenderables )
sm.tool.preloadRenderables( stoneRenderables )
sm.tool.preloadRenderables( scrapmetalRenderables )
sm.tool.preloadRenderables( woodRenderables )
sm.tool.preloadRenderables( metalRenderables )
sm.tool.preloadRenderables( heavyRenderables )
sm.tool.preloadRenderables( wormRenderables )
sm.tool.preloadRenderables( renderablesItemTp )
sm.tool.preloadRenderables( renderablesItemFp )
sm.tool.preloadRenderables( renderablesHeavyTp )
sm.tool.preloadRenderables( renderablesHeavyFp )
sm.tool.preloadRenderables( renderablesWormTp )
sm.tool.preloadRenderables( renderablesWormFp )

function CarryTool.client_onCreate( self )
	self.tpAnimations = createTpAnimations( self.tool, {} )
	if self.tool:isLocal() then
		self.fpAnimations = createFpAnimations( self.tool, {} )
	end

	self.activeItem = sm.uuid.getNil()
	self.activeColor = sm.color.new( 1,1,1,1 )
	if not self.tool:isLocal() then
		self.desiredActiveItem = sm.uuid.getNil()
		self.desiredColor = sm.color.new( 1,1,1,1 )
	end
end

function CarryTool.client_onRefresh( self )
	self:cl_updateActiveCarry()
end

function CarryTool.client_onClientDataUpdate( self, clientData )
	if not self.tool:isLocal() then
		self.desiredActiveItem = clientData.activeUid
		self.desiredColor = clientData.activeColor
	end
end

function CarryTool.cl_loadAnimations( self, activeUid )

	if isAnyOf( activeUid, harvestItems ) then
		self.tpAnimations = createTpAnimations(
			self.tool,
			{
				idle = { "item_idle", { looping = true } },
				sprint = { "item_sprint_idle" },
				pickup = { "item_pickup", { nextAnimation = "idle" } },
				putdown = { "item_putdown" }

			}
		)
		local movementAnimations = {

			idle = "item_idle",

			runFwd = "item_run",
			runBwd = "item_runbwd",

			sprint = "item_sprint_idle",

			jump = "item_jump",
			jumpUp = "item_jump_up",
			jumpDown = "item_jump_down",

			land = "item_jump_land",
			landFwd = "item_jump_land_fwd",
			landBwd = "item_jump_land_bwd",

			crouchIdle = "item_crouch_idle",
			crouchFwd = "item_crouch_run",
			crouchBwd = "item_crouch_runbwd"
		}

		for name, animation in pairs( movementAnimations ) do
			self.tool:setMovementAnimation( name, animation )
		end

		if self.tool:isLocal() then
			self.fpAnimations = createFpAnimations(
				self.tool,
				{
					idle = { "item_idle", { looping = true } },

					sprintInto = { "item_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
					sprintIdle = { "item_sprint_idle", { looping = true } },
					sprintExit = { "item_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },

					equip = { "item_pickup", { nextAnimation = "idle" } },
					unequip = { "item_putdown" }
				}
			)
		end
		setTpAnimation( self.tpAnimations, "idle", 5.0 )
		self.blendTime = 0.2
	elseif activeUid == obj_character_worm then
		self.tpAnimations = createTpAnimations(
			self.tool,
			{
				idle = { "toolgorp_idle", { looping = true } },
				sprint = { "toolgorp_sprint" },
				pickup = { "toolgorp_pickup", { nextAnimation = "idle" } },
				putdown = { "toolgorp_putdown" }

			}
		)
		local movementAnimations = {

			idle = "toolgorp_idle",

			runFwd = "toolgorp_run_fwd",
			runBwd = "toolgorp_run_bwd",

			sprint = "toolgorp_sprint",

			jump = "toolgorp_jump",
			jumpUp = "toolgorp_jump_up",
			jumpDown = "toolgorp_jump_down",

			land = "toolgorp_jump_land",
			landFwd = "toolgorp_jump_land_fwd",
			landBwd = "toolgorp_jump_land_bwd",

			crouchIdle = "toolgorp_crouch_idle",
			crouchFwd = "toolgorp_crouch_fwd",
			crouchBwd = "toolgorp_crouch_bwd",

			swimIdle = "toolgorp_swim_idle",
			swimFwd = "toolgorp_swim_fwd",
			swimBwd = "toolgorp_swim_bwd"
		}

		for name, animation in pairs( movementAnimations ) do
			self.tool:setMovementAnimation( name, animation )
		end

		if self.tool:isLocal() then
			self.fpAnimations = createFpAnimations(
				self.tool,
				{
					idle = { "toolgorp_idle", { looping = true } },

					sprintInto = { "toolgorp_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
					sprintIdle = { "toolgorp_sprint_idle", { looping = true } },
					sprintExit = { "toolgorp_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },

					jump = { "toolgorp_jump", { nextAnimation = "idle" } },
					land = { "toolgorp_jump_land", { nextAnimation = "idle" } },

					equip = { "toolgorp_pickup", { nextAnimation = "idle" } },
					unequip = { "toolgorp_putdown" }
				}
			)
		end
		setTpAnimation( self.tpAnimations, "idle", 5.0 )
		self.blendTime = 0.2
	elseif activeUid ~= nil and activeUid ~= sm.uuid.getNil() then
		self.tpAnimations = createTpAnimations(
			self.tool,
			{
				idle = { "heavytool_idle", { looping = true } },
				sprint = { "heavytool_sprint_idle" },
				pickup = { "heavytool_pickup", { nextAnimation = "idle" } },
				putdown = { "heavytool_putdown" }

			}
		)
		local movementAnimations = {

			idle = "heavytool_idle",

			runFwd = "heavytool_run",
			runBwd = "heavytool_runbwd",

			sprint = "heavytool_sprint_idle",

			jump = "heavytool_jump",
			jumpUp = "heavytool_jump_up",
			jumpDown = "heavytool_jump_down",

			land = "heavytool_jump_land",
			landFwd = "heavytool_jump_land_fwd",
			landBwd = "heavytool_jump_land_bwd",

			crouchIdle = "heavytool_crouch_idle",
			crouchFwd = "heavytool_crouch_run",
			crouchBwd = "heavytool_crouch_runbwd"
		}

		for name, animation in pairs( movementAnimations ) do
			self.tool:setMovementAnimation( name, animation )
		end

		if self.tool:isLocal() then
			self.fpAnimations = createFpAnimations(
				self.tool,
				{
					idle = { "heavytool_idle", { looping = true } },

					sprintInto = { "heavytool_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
					sprintIdle = { "heavytool_sprint_idle", { looping = true } },
					sprintExit = { "heavytool_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },

					equip = { "heavytool_pickup", { nextAnimation = "idle" } },
					unequip = { "heavytool_putdown" }
				}
			)
		end
		setTpAnimation( self.tpAnimations, "idle", 5.0 )
		self.blendTime = 0.2
	end
end

function CarryTool.client_onUpdate( self, dt )

	if self.tool:isLocal() then
		if self.equipped then
			if self.tool:isSprinting() and self.fpAnimations.currentAnimation ~= "sprintInto" and self.fpAnimations.currentAnimation ~= "sprintIdle" then
				swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.0 )
			elseif not self.tool:isSprinting() and ( self.fpAnimations.currentAnimation == "sprintIdle" or self.fpAnimations.currentAnimation == "sprintInto" ) then
				swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.0 )
			end
		end
		updateFpAnimations( self.fpAnimations, self.equipped, dt )
	end

	-- Update the equipped item for the clients that do not own the tool
	if not self.tool:isLocal() and self.activeItem ~= self.desiredActiveItem and self.tool:isEquipped() then
		self.activeItem = self.desiredActiveItem
		self.activeColor = self.desiredColor
		self:cl_updateActiveCarry()
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
				if ( name == "use" or name == "useempty" ) then
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

function CarryTool.client_onToggle( self )
	return false
end

function CarryTool.client_onEquip( self, animate )

	if self.tool:isLocal() then
		self.tool:setBlockSprint( true )
		local carryContainer = sm.localPlayer.getCarry()
		self.activeItem = carryContainer:getItem( 0 ).uuid
		self.activeColor = sm.localPlayer.getCarryColor()
		
		self:cl_updateActiveCarry()
		self.network:sendToServer( "sv_n_updateCarryRenderables", { activeItem = self.activeItem, activeColor = self.activeColor } )
		if self.activeItem == obj_character_worm then
			sm.effect.playEffect( "Glowgorp - Pickup", self.tool:getOwner().character.worldPosition )
		end
	else
		if not animate then
			-- reload renderable
			self.activeItem = sm.uuid.getNil()
		end
	end

	self.wantEquipped = true
end

function CarryTool.sv_n_updateCarryRenderables( self, param, player )
	self.network:setClientData( { activeUid = param.activeItem, activeColor = param.activeColor } )
end

function CarryTool.cl_updateActiveCarry( self )
	self:cl_updateCarryRenderables( self.activeItem, self.activeColor )
	self:cl_loadAnimations( self.activeItem )
	if self.activeItem == nil or self.activeItem == sm.uuid.getNil() then
		setTpAnimation( self.tpAnimations, "putdown" )
		if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
			swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
		end
	else
		setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
		if self.tool:isLocal() then
			swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
		end
	end
end

function CarryTool.cl_updateCarryRenderables( self, activeUid, activeColor )

	local carryRenderables = {}
	local animationRenderablesTp = {}
	local animationRenderablesFp = {}

	if activeUid == sm.uuid.getNil() or activeUid == nil then
		animationRenderablesTp = self.emptyTpRenderables
		animationRenderablesFp = self.emptyFpRenderables
		self.emptyTpRenderables = {}
		self.emptyFpRenderables = {}
	elseif activeUid == obj_harvest_wood then
		carryRenderables = scrapwoodRenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	elseif activeUid == obj_harvest_metal then
		carryRenderables = scrapmetalRenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	elseif activeUid == obj_harvest_stone then
		carryRenderables = stoneRenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	elseif  activeUid == obj_harvest_wood2 then
		carryRenderables = woodRenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	elseif  activeUid == obj_harvest_metal2 then
		carryRenderables = metalRenderables
		animationRenderablesTp = renderablesItemTp
		animationRenderablesFp = renderablesItemFp
	elseif activeUid == obj_character_worm then
		carryRenderables = wormRenderables
		animationRenderablesTp = renderablesWormTp
		animationRenderablesFp = renderablesWormFp
	else
		carryRenderables = heavyRenderables
		animationRenderablesTp = renderablesHeavyTp
		animationRenderablesFp = renderablesHeavyFp
	end

	local currentRenderablesTp = {}
	local currentRenderablesFp = {}

	for k,v in pairs( animationRenderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( animationRenderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	self.emptyTpRenderables = shallowcopy( animationRenderablesTp )
	self.emptyFpRenderables = shallowcopy( animationRenderablesFp )

	for k,v in pairs( carryRenderables ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( carryRenderables ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	self.tool:setTpRenderables( currentRenderablesTp )
	self.tool:setTpColor( activeColor )
	if self.tool:isLocal() then
		self.tool:setFpRenderables( currentRenderablesFp )
		self.tool:setFpColor( activeColor )
	end

end

function CarryTool.client_onUnequip( self )

	self.activeItem = sm.uuid.getNil()
	if sm.exists( self.tool ) then
		self:cl_updateActiveCarry()
		if self.tool:isLocal() then
			self.tool:setBlockSprint( false )
			self.network:sendToServer( "sv_n_updateCarryRenderables", { activeItem = self.activeItem, activeColor = self.activeColor } )
		end
	end

	self.wantEquipped = false
	self.equipped = false
end

function CarryTool.client_onEquippedUpdate( self, primaryState, secondaryState )

	local playerCarry = sm.localPlayer.getCarry()
	local playerCarryColor = sm.localPlayer.getCarryColor()
	local carryUuid = sm.container.itemUuid( playerCarry )[1]
	local characterShape = sm.item.getCharacterShape( carryUuid )
	local isHarvest = sm.shape.getIsHarvest( carryUuid )

	if isHarvest and secondaryState ~= sm.tool.interactState.start then
		local aimRange = 7.5
		local success, result = sm.localPlayer.getRaycast( aimRange )
		if result.type == "body" then
			local shape = result:getShape()
			local shapeContainer = nil
			if shape:getShapeUuid() == obj_craftbot_refinery then
				shapeContainer = shape.interactable:getContainer( 1 )
			elseif shape:getShapeUuid() == obj_craftbot_resourcecontainer then
				shapeContainer = shape.interactable:getContainer( 0 )
			end
			if shapeContainer then
				if sm.container.canCollect( shapeContainer, carryUuid, 1 ) then
					sm.gui.setCenterIcon( "Use" )
					local keyBindingText =  sm.gui.getKeyBinding( "Create", true )
					sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_INSERT}" )

					if primaryState == sm.tool.interactState.start then
						local character = self.tool:getOwner().character
						local fromPosition = character:getTpBonePos( "jnt_right_weapon" )
						local fromRotation = character:getTpBoneRot( "jnt_right_weapon" )
						local params = { containerA = playerCarry, itemA = carryUuid, quantityA = 1, targetShape = shape, fromPosition = fromPosition, fromRotation = fromRotation, color = playerCarryColor  }
						self.network:sendToServer( "sv_n_sendItem", params )
					end
					return true, true
				end
			end
		end
	elseif ( primaryState == sm.tool.interactState.start and characterShape ) or secondaryState == sm.tool.interactState.start then
		local dropRange = 7.5
		local success, result = sm.localPlayer.getRaycast( dropRange )

		local fraction = 1
		if success then
			fraction = result.fraction
		end

		local aimPosition = sm.localPlayer.getRaycastStart() + sm.localPlayer.getDirection() * dropRange * fraction
		local camUp = sm.camera.getUp()
		local camRight = sm.camera.getRight()
		local camDirection = sm.camera.getDirection()

		local params = { containerA = playerCarry, itemA = carryUuid, quantityA = 1, aimPosition = aimPosition, camUp = camUp, camRight = camRight, camDirection = camDirection, raycastNormal = result.normalWorld, color = playerCarryColor }
		if characterShape then
			params.characterShape = characterShape
			if primaryState == sm.tool.interactState.start then
				params.checkCollision = true
			end
		end

		self.network:sendToServer( "sv_n_dropCarry", params )
		return true, true
	end

	if characterShape then
		return true, true
	end

	return false, false

end

function CarryTool.sv_n_dropCarry( self, params )

	local meshRot = sm.quat.angleAxis( math.pi * 0.5, sm.vec3.new( 1, 0, 0 ) ) -- TODO Look at the construction rotation set?

	local forward = sm.vec3.new( params.camDirection.x, params.camDirection.y, 0 ):safeNormalize( sm.vec3.new( 0, 1, 0 ) )
	local pitch = math.asin( params.camDirection.z )
	local yaw = math.atan2( forward.x, -forward.y )
	local rotation = sm.quat.angleAxis( pitch, params.camRight ) * sm.quat.angleAxis( yaw, sm.vec3.new( 0, 0, 1 ) ) -- TODO Preview rotation?
	if params.characterShape then

		local offset = params.raycastNormal * params.characterShape.placementSphereRadius
		local spawnPosition = params.aimPosition + offset
		local collision = false
		if params.checkCollision then
			collision = sm.physics.sphereContactCount( spawnPosition, params.characterShape.placementSphereRadius ) > 0
		end
		if not collision then
			if sm.container.beginTransaction() then
				sm.container.spendFromSlot( params.containerA, 0, params.itemA, params.quantityA, true )
				if sm.container.endTransaction() then
					sm.unit.createUnit( sm.uuid.new( params.characterShape.characterUuid ), spawnPosition, math.random()*2*math.pi )
				end
			end
		end
	else
		local shapeOffset = sm.item.getShapeOffset( params.itemA )
		local rotatedOffset = rotation * meshRot * shapeOffset
		rotatedOffset.z = 0
		local spawnPosition = params.aimPosition - rotatedOffset
		if sm.container.beginTransaction() then
			sm.container.spendFromSlot( params.containerA, 0, params.itemA, params.quantityA, true )
			if sm.container.endTransaction() then

				local shape = nil
				if sm.item.isBlueprintShape( params.itemA ) then
					shape = sm.creation.buildBlueprintShape( params.itemA,
						spawnPosition, rotation, -- Global transform
						sm.vec3.new(0,0,0), meshRot ) -- Local transform
				else
					local body = sm.body.createBody( spawnPosition, rotation )
					shape = body:createPart( params.itemA, sm.vec3.new( 0, 0, 0), sm.vec3.new( 0, -1, 0 ), sm.vec3.new( 1, 0, 0 ), true )
				end
				assert(shape)
				shape:setColor( params.color )

				if params.containerA:getSize() > 1 then -- Additional items in carry
					local interactable = shape:getInteractable()
					local container = interactable:getContainer( 0 )
					if container == nil then
						container = interactable:addContainer( 0, params.containerA:getSize() - 1, params.containerA:getMaxStackSize() )
					end
					sm.container.beginTransaction()
					for slot = 2, params.containerA:getSize() do
						local item = params.containerA:getItem( slot - 1 )
						--sm.container.spendFromSlot( params.containerA, slot - 1, item.uuid, item.quantity, true )
						--sm.container.collectToSlot( container, slot - 2, item.uuid, item.quantity, true )
						sm.container.setItem( params.containerA, slot - 1, sm.uuid.getNil(), 0 )
						sm.container.setItem( container, slot - 2, item.uuid, item.quantity, item.instance )
					end
					if not sm.container.endTransaction() then
						sm.log.error("Failed to move carry items!")
					end
				end
				
			end
		end
	end

end

function CarryTool.sv_n_sendItem( self, params )
	sm.event.sendToInteractable( params.targetShape.interactable, "sv_e_receiveItem", params )
end