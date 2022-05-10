-- HideoutTrader.lua --
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

HideoutTrader = class( nil )
HideoutTrader.maxParentCount = 1
HideoutTrader.maxChildCount = 0
HideoutTrader.connectionInput = sm.interactable.connectionType.logic
HideoutTrader.connectionOutput = sm.interactable.connectionType.none
HideoutTrader.colorNormal = sm.color.new( 0xdeadbeef )
HideoutTrader.colorHighlight = sm.color.new( 0xdeadbeef )
HideoutTrader.VacuumTickTime = 40 * 2.0

local OpenShutterDistance = 7.0
local CloseShutterDistance = 9.0

local HideoutVacuumItems = {
	obj_crates_blueberry,
	obj_crates_banana,
	obj_crates_pineapple,
	obj_crates_orange,
	obj_crates_redbeet,
	obj_crates_carrot,
	obj_crates_tomato,
	obj_crates_broccoli,
	obj_survivalobject_farmerball
}

function HideoutTrader.server_onCreate( self )

	self.sv = {}

	-- Storage
	self.sv.storage = self.storage:load()
	if self.sv.storage == nil then
		self.sv.storage = {}
	end
	if self.params then
		if self.params.vacuumInteractable then
			self.sv.storage.vacuumInteractable = self.params.vacuumInteractable
		end
		if self.params.buttonInteractable then
			self.sv.storage.buttonInteractable = self.params.buttonInteractable
		end
		if self.params.cameraNode then
			self.sv.storage.cameraNode = self.params.cameraNode
		end
		if self.params.dropzoneNode then
			self.sv.storage.dropzoneNode = self.params.dropzoneNode
		end
		self.storage:save( self.sv.storage )
	end

	-- Server
	local shouldSave = false
	if self.sv.storage.vacuumInteractable then
		self.sv.vacuumInteractable = self.sv.storage.vacuumInteractable
	else
		sm.log.info("Patching missing vacuum interactable, attempting to find it")
		self.sv.storage.vacuumInteractable = FindFirstInteractable( "d1840356-ad77-4505-a9a0-10d11a77986f" )
		assert( self.sv.storage.vacuumInteractable, "Failed to find vacuum interactable" )
		self.sv.vacuumInteractable = self.sv.storage.vacuumInteractable
		shouldSave = true
	end

	if self.sv.storage.buttonInteractable then
		self.sv.buttonInteractable = self.sv.storage.buttonInteractable
	else
		sm.log.info("Patching missing button interactable, attempting to find it")
		self.sv.storage.buttonInteractable = FindFirstInteractable( "712a5ebd-0793-49ba-b1ef-681a8fdceba6" )
		assert( self.sv.storage.buttonInteractable, "Failed to find button interactable" )
		self.sv.buttonInteractable = self.sv.storage.buttonInteractable
		shouldSave = true
	end

	if self.sv.storage.cameraNode then
		self.sv.cameraNode = self.sv.storage.cameraNode
	else
		sm.log.info("Patching missing camera node, attempting to find it")
		local x, y = getCell( self.shape:getWorldPosition().x, self.shape:getWorldPosition().y )
		local cameraNodes = sm.cell.getNodesByTag( x, y, "CAMERA" )
		self.sv.storage.cameraNode = cameraNodes[1]
		assert( self.sv.storage.cameraNode, "Failed to find camera node")
		self.sv.cameraNode = self.sv.storage.cameraNode
		shouldSave = true 
	end

	if self.sv.storage.dropzoneNode then
		self.sv.dropzoneNode = self.sv.storage.dropzoneNode
	else
		sm.log.info("Patching missing dropzone node, attempting to find it")
		local x, y = getCell( self.shape:getWorldPosition().x, self.shape:getWorldPosition().y )
		local dropzoneNodes = sm.cell.getNodesByTag( x, y, "HIDEOUT_DROPZONE" )
		self.sv.storage.dropzoneNode = dropzoneNodes[1]
		assert( self.sv.storage.dropzoneNode, "Failed to find dropzone node")
		self.sv.dropzoneNode = self.sv.storage.dropzoneNode
		shouldSave = true  
	end

	assert( self.sv.vacuumInteractable )
	assert( self.sv.buttonInteractable )
	assert( self.sv.cameraNode )
	assert( self.sv.dropzoneNode )

	if shouldSave then
		self.storage:save( self.sv.storage )
		shouldSave = false
	end

	self:sv_init()
end

function HideoutTrader.sv_save( self )
	self.sv.storage.vacuumInteractable = self.sv.vacuumInteractable
	self.sv.storage.buttonInteractable = self.sv.buttonInteractable
	self.sv.storage.cameraNode = self.sv.cameraNode
	self.sv.storage.dropzoneNode = self.sv.dropzoneNode
	self.storage:save( self.sv.storage )
end

function HideoutTrader.server_onRefresh( self )
	self:sv_init()
end

function HideoutTrader.sv_init( self )

	self.sv.buttonInteractable:connect( self.interactable )

	local container = self.interactable:getContainer( 0 )
	if not container then
		container = self.interactable:addContainer( 0, 16 )
	end
	container:setFilters( HideoutVacuumItems )

	if self.sv.areaTrigger then
		sm.areaTrigger.destroy( self.sv.areaTrigger )
		self.areaTrigger = nil
	end

	if self.sv.dropzoneNode then
		local halfExtents = self.sv.dropzoneNode.scale * 0.5
		local position = self.sv.dropzoneNode.position
		local filter = sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.staticBody
		self.sv.areaTrigger = sm.areaTrigger.createBox( halfExtents, self.sv.dropzoneNode.position, self.sv.dropzoneNode.rotation, filter )
	end

	self.sv.vacuumTicks = 0
	self.sv.vacuumActive = false

	self.network:setClientData( { cameraNode = self.sv.cameraNode, vacuumInteractable = self.sv.vacuumInteractable } )
end

function HideoutTrader.sv_tryCompleteQuest( self, params, player )

	sm.container.beginTransaction()

	-- Collect
	for i, collect in ipairs( params.ingredientList ) do
		local itemUid = sm.uuid.new( collect.itemId )
		local container
		if isAnyOf( itemUid, HideoutVacuumItems ) then
			container = self.interactable:getContainer( 0 )
		else
			container = player:getInventory()
		end
		sm.container.spend( container, itemUid, collect.quantity, true )
	end

	-- Reward
	--[[for i, reward in ipairs( params.rewardList ) do

		local itemUid = sm.uuid.new( reward.itemId )
		sm.container.collect( inventory, itemUid, reward.quantity, true )
	end]]--

	local inventory = player:getInventory()
	sm.container.collect( inventory, sm.uuid.new( params.itemId ), params.quantity, true )

	if not sm.container.endTransaction() then
		--The player failed the trade transaction, abort
		return
	end

	self.network:sendToClients( "cl_questCompleted", player )

end

function HideoutTrader.sv_vacuumObject( self )
	local container = self.interactable:getContainer( 0 )
	if container == nil then
		return false
	end

	local contents = self.sv.areaTrigger:getContents()
	for _, body in ipairs( contents ) do
		if sm.exists( body ) then
			for _, shape in ipairs( body:getShapes() ) do
				if sm.exists( shape ) then
					local shapeUuid = shape:getShapeUuid()
					if not sm.item.isBlock( shapeUuid ) then
						if isAnyOf( shapeUuid, HideoutVacuumItems ) then
							sm.container.beginTransaction()
							sm.container.collect( container, shapeUuid, 1, true )
							if sm.container.endTransaction() then
								self.network:sendToClients( "cl_n_addVacuumItem", { shapeUuid = shapeUuid, fromPosition = shape.worldPosition, fromRotation = shape.worldRotation } )
								sm.shape.destroyShape( shape )
								return true
							end
						end
					end
				end
			end
		end
	end
	return false
end

function HideoutTrader.server_onFixedUpdate( self, timeStep )

	local buttonIsActive = false
	local parent = self.interactable:getSingleParent()
	if parent then
		buttonIsActive = parent:isActive()
	end

	if buttonIsActive and not self.sv.vacuumActive then
		self.sv.vacuumActive = self:sv_vacuumObject()
	end

	if self.sv.vacuumActive then
		self.sv.vacuumTicks = self.sv.vacuumTicks + 1
		if self.sv.vacuumTicks >= self.VacuumTickTime then
			self.sv.vacuumTicks = 0
			self.sv.vacuumActive = false
		end
	end

	if self.sv.vacuumInteractable and sm.exists( self.sv.vacuumInteractable ) then
		self.sv.vacuumInteractable.active = self.sv.vacuumActive
	end
end

-- Client

function HideoutTrader.client_onCreate( self )
	self:cl_init()
end

function HideoutTrader.client_onRefresh( self )
	if self.cl then
		if self.cl.user then
			self.cl.user.clientPublicData.interactableCameraData = nil
			self.cl.user.character:setLockingInteractable( nil )
			self.cl.user = nil
			self.cl.guiInterface:close()
		end
	end
	self:cl_init()
end

function HideoutTrader.cl_init( self )
	if self.cl == nil then
		self.cl = {}
	end
	if self.cl.vacuumItems == nil then
		self.cl.vacuumItems = {}
	end

	self.cl.guiInterface = sm.gui.createHideoutGui()
	self.cl.guiInterface:setGridButtonCallback( "Trade", "cl_onCompleteQuest" )
	self.cl.guiInterface:setOnCloseCallback( "cl_onClose" )
	self:cl_updateTradeGrid()

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
	self:cl_setAnimation( self.cl.animations["Close"], 1.0 )
end

function HideoutTrader.client_onDestroy(self)
	-- Destroy animation effects
	for name, effect in pairs( self.cl.animationEffects ) do
		effect:stop()
	end
end

function HideoutTrader.cl_updateTradeGrid( self )
	self.cl.guiInterface:clearGrid( "TradeGrid" )
	self.cl.guiInterface:addGridItemsFromFile( "TradeGrid", "$SURVIVAL_DATA/CraftingRecipes/hideout.json" )
end

function HideoutTrader.cl_n_addVacuumItem( self, params )
	if self.cl == nil then
		self.cl = {}
	end
	if self.cl.vacuumItems == nil then
		self.cl.vacuumItems = {}
	end

	local vacuumItem = {}
	vacuumItem.effect = sm.effect.createEffect( "ShapeRenderable" )
	vacuumItem.effect:setParameter( "uuid", params.shapeUuid )
	vacuumItem.effect:setPosition( params.fromPosition )
	vacuumItem.effect:setRotation( params.fromRotation )
	vacuumItem.effect:setScale( sm.vec3.new( 0.25, 0.25, 0.25 ) )
	vacuumItem.effect:start()
	vacuumItem.elapsedTime = 0.0
	vacuumItem.fromPosition = params.fromPosition
	vacuumItem.fromRotation = params.fromRotation
	local vacuumPosition = self.cl.vacuumInteractable:getWorldBonePosition( "suction3_jnt" )
	vacuumItem.toRotation = sm.vec3.getRotation( sm.vec3.new( 0, -1, 0 ), ( vacuumItem.fromPosition - vacuumPosition ):normalize() )

	local shapeSize = sm.item.getShapeSize( params.shapeUuid )
	local maxSize = math.max( math.max( shapeSize.x, shapeSize.y ), shapeSize.z )
	vacuumItem.blockScale = sm.vec3.new( 0.25, 0.25, 0.25 ) / maxSize
	self.cl.vacuumItems[#self.cl.vacuumItems+1] = vacuumItem
end

function HideoutTrader.client_onClientDataUpdate( self, clientData )
	if self.cl == nil then
		self.cl = {}
	end
	self.cl.cameraNode = clientData.cameraNode
	self.cl.vacuumInteractable = clientData.vacuumInteractable
end

function HideoutTrader.cl_onCompleteQuest( self, buttonName, index, data )

	self.network:sendToServer( "sv_tryCompleteQuest", data )
end

function HideoutTrader.cl_questCompleted( self, player )
	self.cl.playCompletedAnimation = true
end

function HideoutTrader.client_onInteract( self, character, state )
	if state == true then
		if self.cl.user == nil then
			character:setLockingInteractable( self.interactable )
			self.cl.user = character:getPlayer()
			self.cl.guiInterface:setContainer("Hideout", self.interactable:getContainer() )
			self.cl.guiInterface:setContainer("Inventory", character:getPlayer():getInventory() )
			self.cl.guiInterface:open()
		end
	end
end

function HideoutTrader.cl_onClose( self )
	if self.cl.user then
		self.cl.user.clientPublicData.interactableCameraData = nil
		self.cl.user.character:setLockingInteractable( nil )
		self.cl.user = nil
	end
end

function HideoutTrader.client_onUpdate( self, dt )

	self:cl_selectAnimation()
	self:cl_updateAnimation( dt )

	if self.cl.user == sm.localPlayer.getPlayer() then
		local cameraDesiredDirection = sm.camera.getDirection()
		local cameraDesiredPosition = sm.camera.getPosition()

		if self.cl.cameraNode then
			cameraDesiredDirection = self.cl.cameraNode.rotation * sm.vec3.new( 0, 1, 0 )
			cameraDesiredPosition = self.cl.cameraNode.position
		end

		local cameraPosition = magicPositionInterpolation( sm.camera.getPosition(), cameraDesiredPosition, dt, 1.0 / 10.0 )
		local cameraDirection = magicDirectionInterpolation( sm.camera.getDirection(), cameraDesiredDirection, dt, 1.0 / 10.0 )

		-- Finalize
		local interactableCameraData = {}
		interactableCameraData.hideGui = false
		interactableCameraData.cameraState = sm.camera.state.cutsceneTP
		interactableCameraData.cameraPosition = cameraPosition
		interactableCameraData.cameraDirection = cameraDirection
		interactableCameraData.cameraFov = sm.camera.getDefaultFov()
		interactableCameraData.lockedControls = true
		self.cl.user.clientPublicData.interactableCameraData = interactableCameraData
	end

	local vacuumPosition = self.cl.vacuumInteractable:getWorldBonePosition( "suction3_jnt" )
	local arriveFraction = 0.4
	local vacuumTime = ( self.VacuumTickTime / 40 ) * arriveFraction
	local remainingVacuumItems = {}
	for _, vacuumItem in ipairs( self.cl.vacuumItems ) do
		vacuumItem.elapsedTime = vacuumItem.elapsedTime + dt
		if vacuumItem.elapsedTime >= vacuumTime then
			vacuumItem.effect:stop()
		else
			local windup = 0.6
			local progress = math.min( vacuumItem.elapsedTime / vacuumTime, 1.0 )
			if progress > windup then
				local windupProgress = ( ( progress - windup )/( 1 - windup ) )
				vacuumItem.effect:setPosition( sm.vec3.lerp( vacuumItem.fromPosition, vacuumPosition, windupProgress ) )
				vacuumItem.effect:setRotation( sm.quat.slerp( vacuumItem.fromRotation, vacuumItem.toRotation, windupProgress ) )
				vacuumItem.effect:setScale( sm.vec3.lerp( sm.vec3.new( 0.25, 0.25, 0.25 ), vacuumItem.blockScale, windupProgress ) )
			end
			remainingVacuumItems[#remainingVacuumItems+1] = vacuumItem
		end
	end
	self.cl.vacuumItems = remainingVacuumItems
end

function HideoutTrader.cl_createAnimation( self, name, playTime, nextAnimation, looping, playForward )
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

function HideoutTrader.cl_setAnimation( self, animation, playProgress )
	self:cl_unsetAnimation()
	animation.isActive = true
	animation.playProgress = playProgress
	self.interactable:setAnimEnabled(animation.name, true)
	local effect = self.cl.animationEffects[animation.name]
	if playProgress == 0.0 and effect then
		effect:start()
	end
end

function HideoutTrader.cl_unsetAnimation( self )
	for name, animation in pairs( self.cl.animations ) do
		animation.isActive = false
		animation.playProgress = 0.0
		self.interactable:setAnimEnabled( animation.name, false )
		self.interactable:setAnimProgress( animation.name, animation.playProgress )
	end
end

function HideoutTrader.cl_selectAnimation( self )

	if self.cl.animations["Close"].isActive and self.cl.animations["Close"].playProgress >= 1.0 then
		if GetClosestPlayer( self.shape.worldPosition, OpenShutterDistance, self.shape.body:getWorld() ) ~= nil then
			self:cl_setAnimation( self.cl.animations["Open"], 0.0 )
		end
	end

	if self.cl.animations["Idle"].isActive then
		if self.cl.playCompletedAnimation then
			local randIndex = math.random( 1, 3)
			if randIndex == 1 then
				self:cl_setAnimation( self.cl.animations["Confirm01"], 0.0 )
			elseif randIndex == 2 then
				self:cl_setAnimation( self.cl.animations["Confirm02"], 0.0 )
			elseif randIndex == 3 then
				self:cl_setAnimation( self.cl.animations["Confirm03"], 0.0 )
			end
		else
			if GetClosestPlayer( self.shape.worldPosition, CloseShutterDistance, self.shape.body:getWorld() ) == nil then
				self:cl_setAnimation( self.cl.animations["Close"], 0.0 )
			end
		end
	end
	self.cl.playCompletedAnimation = false

end

function HideoutTrader.cl_updateAnimation( self, dt )

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
