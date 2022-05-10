
ResourceContainer = class( nil )
ResourceContainer.ContainerSize = 25

function ResourceContainer.server_onCreate( self )
	if not self.interactable:getContainer( 0 ) then
		self.interactable:addContainer( 0, self.ContainerSize, 1 )
	end

	self.sv = {}
	self.sv.lastRearranged = sm.game.getCurrentTick()
	local shapeSize = sm.item.getShapeSize( self.shape:getShapeUuid() ) * 0.125
	local size = sm.vec3.new( shapeSize.x + 0.875, shapeSize.y + 0.875, shapeSize.z + 0.875 )
	local filter = sm.areaTrigger.filter.staticBody + sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.areaTrigger
	self.sv.areaTrigger = sm.areaTrigger.createAttachedBox( self.interactable, size, sm.vec3.zero(), sm.quat.identity(), filter, { resourceCollector = self.shape } )
	self.sv.areaTrigger:bindOnEnter( "trigger_onEnter" )
end

local RemovedHarvests = {}

function ResourceContainer.server_onFixedUpdate( self )
	local container = self.interactable:getContainer( 0 )
	if container then
		if container:hasChanged( self.sv.lastRearranged ) then
			local startChecking = false
			local changedSlot = nil
			for i = self.ContainerSize, 1, -1 do
				local slotItem = container:getItem( i - 1 )
				if slotItem.quantity == 0 and startChecking then
					changedSlot = i - 1
					break
				end
				if slotItem.quantity > 0 then
					startChecking = true
				end
			end
			if changedSlot then
				self:sv_rearrangeContents( changedSlot )
			end
			self.sv.lastRearranged = sm.game.getCurrentTick()
		end
	end
	
	RemovedHarvests = {}

end

function ResourceContainer.trigger_onEnter( self, trigger, contents )
	print(contents)
	for _, result in ipairs( contents ) do
		if sm.exists( result ) then
			if type( result ) == "Body" then
				for _, shape in ipairs( result:getShapes() ) do
					if shape:getBody():getCreationId() ~= self.shape:getBody():getCreationId() then
						if sm.shape.getIsHarvest( shape:getShapeUuid() ) then
							if not RemovedHarvests[shape:getId()] then								
								local container = self.interactable:getContainer( 0 )
								if container then
									local transactionSlot = nil
									for i = 1, self.ContainerSize do
										local slotItem = container:getItem( i - 1 )
										if slotItem.quantity == 0 then
											transactionSlot = i - 1
											break
										end
									end
					
									if transactionSlot then
										sm.container.beginTransaction()
										sm.container.collectToSlot( container, transactionSlot, shape:getShapeUuid(), 1, true )
										if sm.container.endTransaction() then
											self.network:sendToClients( "cl_n_addPickupItem", { shapeUuid = shape:getShapeUuid(), fromPosition = shape.worldPosition, fromRotation = shape.worldRotation, slotIndex = transactionSlot, showRenderable = true } )
											RemovedHarvests[shape:getId()] = true
											shape:destroyShape()
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

function ResourceContainer.sv_e_receiveItem( self, params )
	if sm.shape.getIsHarvest( params.itemA ) then
		local container = self.interactable:getContainer( 0 )
		if container then
			local transactionSlot = nil
			for i = 1, self.ContainerSize do
				local slotItem = container:getItem( i - 1 )
				if slotItem.quantity == 0 then
					transactionSlot = i - 1
					break
				end
			end

			if transactionSlot then
				sm.container.beginTransaction()
				sm.container.spend( params.containerA, params.itemA, params.quantityA, true )
				sm.container.collectToSlot( container, transactionSlot, params.itemA, params.quantityA, true )
				if sm.container.endTransaction() then
					self.network:sendToClients( "cl_n_addPickupItem", { shapeUuid = params.itemA, fromPosition = params.fromPosition, fromRotation = params.fromRotation, slotIndex = transactionSlot, showRenderable = false } )
				end
			end
		end
	end
end

function ResourceContainer.sv_n_takeHarvest( self, params )
	local container = self.interactable:getContainer( 0 )
	if container then
		local slotItem = container:getItem( params.slotIndex )
		sm.container.beginTransaction()
		sm.container.spendFromSlot( container, params.slotIndex, slotItem.uuid, 1, true )
		sm.container.collect( params.carryContainer, slotItem.uuid, 1, true )
		if sm.container.endTransaction() then
			self:sv_rearrangeContents( params.slotIndex )
		end
	end
end

function ResourceContainer.sv_rearrangeContents( self, removedSlotIndex )
	local container = self.interactable:getContainer( 0 )
	if container then

		local previousSlotIndex = removedSlotIndex
		for i = removedSlotIndex + 1, self.ContainerSize - 1 do
			local previousSlotItem = container:getItem( previousSlotIndex )
			local nextSlotItem = container:getItem( i )
			sm.container.beginTransaction()
			sm.container.spendFromSlot( container, i, nextSlotItem.uuid, 1, true )
			sm.container.collectToSlot( container, previousSlotIndex, nextSlotItem.uuid, 1, true )
			sm.container.endTransaction()
			previousSlotIndex = i
		end
		self.network:sendToClients( "cl_n_updateRearrange" )
		self.sv.lastRearranged = sm.game.getCurrentTick()
	end
end

function ResourceContainer.cl_n_updateRearrange( self, params )
	local container = self.interactable:getContainer( 0 )
	if container then
		for i = 1, self.ContainerSize do
			local slotItem = container:getItem( i - 1 )
			local harvestItem = self.cl.harvestItems[i]
			if harvestItem.effect then
				harvestItem.effect:stop()
				if slotItem.uuid == sm.uuid.getNil() then
					if harvestItem.effect:isPlaying() then
						harvestItem.effect:stop()
					end
				else
					if not harvestItem.effect:isPlaying() and not harvestItem.enteringContainer then
						harvestItem.effect:setParameter( "uuid", slotItem.uuid )
						harvestItem.effect:start()
					end
				end
			end
		end
	end

	-- Removed resource effect
	sm.effect.playEffect( "Resourcecollector - PutIn", self.shape.worldPosition )
end

function ResourceContainer.client_onCreate( self )
	self:cl_init()
end

function ResourceContainer.client_onRefresh( self )
	if self.cl then
		if self.cl.harvestItems then
			for _, harvestItem in ipairs( self.cl.harvestItems ) do
				if harvestItem.effect then
					harvestItem.effect:stop()
				end
			end
		end
	end
	self:cl_init()
end

function ResourceContainer.client_onDestroy( self )
	for _, harvestItem in ipairs( self.cl.harvestItems ) do
		if harvestItem.effect then
			harvestItem.effect:stop()
		end
	end
end

function ResourceContainer.cl_init( self )

	self.cl = {}
	self.cl.pickupItems = {}

	self.cl.harvestItems = {}
	for i = 1, self.ContainerSize do
		local harvestItem = {}
		harvestItem.effect = sm.effect.createEffect( "ShapeRenderable", self.interactable )

		local positionOffset, rotationOffset = self:calculateSlotItemOffset( i - 1 )
		harvestItem.effect:setOffsetPosition( positionOffset )
		harvestItem.effect:setOffsetRotation( rotationOffset )
		harvestItem.effect:setScale( sm.vec3.new( 0.25, 0.25, 0.25 ) )
		harvestItem.enteringContainer = false

		self.cl.harvestItems[#self.cl.harvestItems+1] = harvestItem
	end
end

function ResourceContainer.cl_n_addPickupItem( self, params )
	if self.cl == nil then
		self.cl = {}
	end
	if self.cl.pickupItems == nil then
		self.cl.pickupItems = {}
	end

	if params.showRenderable then
		local pickupItem = {}
		pickupItem.effect = sm.effect.createEffect( "ShapeRenderable" )
		pickupItem.effect:setParameter( "uuid", params.shapeUuid )
		pickupItem.effect:setPosition( params.fromPosition )
		pickupItem.effect:setRotation( params.fromRotation )
		pickupItem.effect:setScale( sm.vec3.new( 0.25, 0.25, 0.25 ) )
		pickupItem.effect:start()
		pickupItem.elapsedTime = 0.0
		pickupItem.fromPosition = params.fromPosition
		pickupItem.fromRotation = params.fromRotation
		pickupItem.slotIndex = params.slotIndex

		self.cl.pickupItems[#self.cl.pickupItems+1] = pickupItem
	end

	-- Added resource effect
	sm.effect.playEffect( "Resourcecollector - TakeOut", self.shape.worldPosition )
end

function ResourceContainer.client_onUpdate( self, dt )

	local container = self.interactable:getContainer( 0 )
	if container then

		-- Update pickup item effects
		local pickupTime = 0.3
		local remainingPickupItems = {}
		for _, pickupItem in ipairs( self.cl.pickupItems ) do
			pickupItem.elapsedTime = pickupItem.elapsedTime + dt
			if pickupItem.elapsedTime >= pickupTime then
				pickupItem.effect:stop()
				self.cl.harvestItems[pickupItem.slotIndex+1].enteringContainer = false
			else
				self.cl.harvestItems[pickupItem.slotIndex+1].enteringContainer = true
				local windup = 0.4
				local progress = math.min( pickupItem.elapsedTime / pickupTime, 1.0 )
				if progress > windup then
					local positionOffset, rotationOffset = self:calculateSlotItemOffset( pickupItem.slotIndex )
					local toPosition = self.shape.worldPosition + self.shape.worldRotation * positionOffset
					local toRotation = self.shape.worldRotation * rotationOffset
					local windupProgress = ( ( progress - windup )/( 1 - windup ) )
					pickupItem.effect:setPosition( sm.vec3.lerp( pickupItem.fromPosition, toPosition, windupProgress ) )
					pickupItem.effect:setRotation( sm.quat.slerp( pickupItem.fromRotation, toRotation, windupProgress ) )
				end
				remainingPickupItems[#remainingPickupItems+1] = pickupItem
			end
		end
		self.cl.pickupItems = remainingPickupItems

		-- Update attached renderable effects
		for i = 1, self.ContainerSize do
			local slotItem = container:getItem( i - 1 )
			local harvestItem = self.cl.harvestItems[i]
			if harvestItem.effect then
				if slotItem.uuid == sm.uuid.getNil() then
					if harvestItem.effect:isPlaying() then
						harvestItem.effect:stop()
					end
				else
					if not harvestItem.effect:isPlaying() and not harvestItem.enteringContainer then
						harvestItem.effect:setParameter( "uuid", slotItem.uuid )
						harvestItem.effect:start()
					end
				end
			end
		end
	end
end

function ResourceContainer.client_canInteract( self )
	local container = self.interactable:getContainer( 0 )
	if container and not container:isEmpty() and sm.localPlayer.getCarry():isEmpty() then
		local slotIndex = self:cl_getRaycastSlot()
		local slotItem = container:getItem( slotIndex )
		if slotItem.quantity > 0 then
			sm.gui.setCenterIcon( "Use" )
			local keyBindingText =  sm.gui.getKeyBinding( "Use", true )
			sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_PICK_UP} " .. sm.shape.getShapeTitle( slotItem.uuid ) )
			return true
		end
	end
	return false
end

function ResourceContainer.client_onInteract( self, user, state )
	if state then
		local container = self.interactable:getContainer( 0 )
		if not container:isEmpty() and sm.localPlayer.getCarry():isEmpty() then
			local params = { carryContainer = sm.localPlayer.getCarry(), slotIndex = self:cl_getRaycastSlot()  }
			self.network:sendToServer( "sv_n_takeHarvest", params )
		end
	end
end

function ResourceContainer.cl_getRaycastSlot( self )
	local container = self.interactable:getContainer( 0 )
	local interactRange = 7.5
	local success, result = sm.localPlayer.getRaycast( interactRange )
	if success then
		-- Adjust for angle and transform to local
		local f = -0.25 / ( result.directionWorld:normalize():dot( result.normalWorld ) * interactRange )
		local intersectionWorldPos = result.originWorld + result.directionWorld * ( result.fraction - f )
		local localPoint = self.shape:transformPoint( intersectionWorldPos ) * 4 + sm.vec3.new( 2.5, 2.5, 0 )

		local xIndex = math.min( math.max( math.floor( localPoint.x ), 0 ), 4 )
		local yIndex = math.min( math.max( math.floor( localPoint.y ), 0 ), 4 ) * 5
		local slotIndex = math.min( math.max( xIndex + yIndex, 0 ), 24 )

		return slotIndex
	end
	return 0
end

function ResourceContainer.calculateSlotItemOffset( self, slotIndex )
	local width = 5
	local height = 5
	local offsetCornerPosition = sm.vec3.new( -0.5, -0.5, 0 )
	local rotationOffset = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), sm.vec3.new( 0, 1, 0 ) )
	local positionOffset = offsetCornerPosition + sm.vec3.new( 0.25 * ( slotIndex % width ) , 0.25 * ( math.floor( slotIndex / width ) % height ), 0 )

	return positionOffset, rotationOffset
end