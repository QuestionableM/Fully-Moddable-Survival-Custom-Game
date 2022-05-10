dofile( "$SURVIVAL_DATA/Scripts/game/util/Curve.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/util/pipes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

---@class Vacuum : ShapeClass
---@field sv table
---@field cl table
Vacuum = class()
Vacuum.poseWeightCount = 1
Vacuum.connectionInput = sm.interactable.connectionType.logic
Vacuum.maxParentCount = 1
Vacuum.maxChildCount = 0

local FireDelay = PIPE_TRAVEL_TICK_TIME -- ticks

local VacuumMode = { outgoing = 1, incoming = 2 }

local UuidToProjectile = {

	[tostring(obj_consumable_water)] = { uuid = projectile_water },
	[tostring(obj_consumable_fertilizer)] = { uuid = projectile_fertilizer },
	[tostring(obj_consumable_chemical)] = { uuid = projectile_chemical },

	[tostring(obj_plantables_banana)] = { uuid = projectile_banana },
	[tostring(obj_plantables_blueberry)] = { uuid = projectile_blueberry },
	[tostring(obj_plantables_orange)] = { uuid = projectile_orange },
	[tostring(obj_plantables_pineapple)] = { uuid = projectile_pineapple },
	[tostring(obj_plantables_carrot)] = { uuid = projectile_carrot },
	[tostring(obj_plantables_redbeet)] = { uuid = projectile_redbeet },
	[tostring(obj_plantables_tomato)] = { uuid = projectile_tomato },
	[tostring(obj_plantables_broccoli)] = { uuid = projectile_broccoli },
	[tostring(obj_plantables_potato)] = { uuid = projectile_potato },

	[tostring(obj_seed_banana)] = { uuid = projectile_seed, hvs = hvs_growing_banana },
	[tostring(obj_seed_blueberry)] = { uuid = projectile_seed, hvs = hvs_growing_blueberry },
	[tostring(obj_seed_orange)] = { uuid = projectile_seed, hvs = hvs_growing_orange },
	[tostring(obj_seed_pineapple)] = { uuid = projectile_seed, hvs = hvs_growing_pineapple },
	[tostring(obj_seed_carrot)] = { uuid = projectile_seed, hvs = hvs_growing_carrot },
	[tostring(obj_seed_potato)] = { uuid = projectile_seed, hvs = hvs_growing_potato },
	[tostring(obj_seed_redbeet)] = { uuid = projectile_seed, hvs = hvs_growing_redbeet },
	[tostring(obj_seed_tomato)] = { uuid = projectile_seed, hvs = hvs_growing_tomato },
	[tostring(obj_seed_broccoli)] = { uuid = projectile_seed, hvs = hvs_growing_broccoli },
	[tostring(obj_seed_cotton)] = { uuid = projectile_seed, hvs = hvs_growing_cotton },
}

function Vacuum.server_onCreate( self )
	self.sv = {}

	-- client table goes to client
	self.sv.client = {}
	self.sv.client.pipeNetwork = {}
	self.sv.client.state = PipeState.off
	self.sv.client.showBlockVisualization = false

	-- storage table goes to storage
	self.sv.storage = self.storage:load()
	if self.sv.storage == nil then
		self.sv.storage = { mode = VacuumMode.outgoing } -- Default value
		self.storage:save( self.sv.storage )
	end

	self.sv.dirtyClientTable = false
	self.sv.dirtyStorageTable = false

	self.sv.fireDelayProgress = 0
	self.sv.canFire = true
	self.sv.areaTrigger = nil
	self.sv.connectedContainers = {}
	self.sv.foundContainer = nil
	self.sv.foundItem = sm.uuid.getNil()
	self.sv.parentActive = false
	self:sv_buildPipeNetwork()
	self:sv_updateStates()

	-- public data used to interface with the packing station
	self.interactable:setPublicData( { packingStationTick = 0 } )
end

function Vacuum.sv_markClientTableAsDirty( self )
	self.sv.dirtyClientTable = true
end

function Vacuum.sv_markStorageTableAsDirty( self )
	self.sv.dirtyStorageTable = true
	self:sv_markClientTableAsDirty()
end

function Vacuum.sv_n_toogle( self )
	if self.sv.storage.mode == VacuumMode.outgoing then
		self:server_outgoingReset()
		self.sv.storage.mode = VacuumMode.incoming
	else
		self.sv.storage.mode = VacuumMode.outgoing
	end

	self:sv_updateStates()
	self:sv_markStorageTableAsDirty()
end

function Vacuum.sv_updateStates( self )

	if self.sv.storage.mode == VacuumMode.incoming then
		if not self.sv.areaTrigger then
			local size = sm.vec3.new( 0.5, 0.5, 0.5 )
			local filter = sm.areaTrigger.filter.staticBody + sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.areaTrigger + sm.areaTrigger.filter.harvestable
			self.sv.areaTrigger = sm.areaTrigger.createAttachedBox( self.interactable, size, sm.vec3.new(0.0, -1.0, 0.0), sm.quat.identity(), filter )
		end
	else
		if self.sv.areaTrigger then
			sm.areaTrigger.destroy( self.sv.areaTrigger )
			self.sv.areaTrigger = nil
		end
	end
end

function Vacuum.sv_buildPipeNetwork( self )

	self.sv.client.pipeNetwork = {}
	self.sv.connectedContainers = {}

	local function fnOnVertex( vertex )

		if isAnyOf( vertex.shape:getShapeUuid(), ContainerUuids ) then -- Is Container
			assert( vertex.shape:getInteractable():getContainer() )
			local container = {
				shape = vertex.shape,
				distance = vertex.distance,
				shapesOnContainerPath = vertex.shapesOnPath
			}

			table.insert( self.sv.connectedContainers, container )
		elseif isAnyOf( vertex.shape:getShapeUuid(), PipeUuids ) then -- Is Pipe
			assert( vertex.shape:getInteractable() )
			local pipe = {
				shape = vertex.shape,
				state = PipeState.off
			}

			table.insert( self.sv.client.pipeNetwork, pipe )
		end

		return true
	end

	ConstructPipedShapeGraph( self.shape, fnOnVertex )

	-- Sort container by closests
	table.sort( self.sv.connectedContainers, function(a, b) return a.distance < b.distance end )

	-- Synch the pipe network and initial state to clients
	local state = PipeState.off

	for _, container in ipairs( self.sv.connectedContainers ) do
		for _, shape in ipairs( container.shapesOnContainerPath ) do
			for _, pipe in ipairs( self.sv.client.pipeNetwork ) do
				if pipe.shape:getId() == shape:getId() then
					pipe.state = PipeState.connected
				end
			end
		end
	end

	self.sv.client.state = state
	self:sv_markClientTableAsDirty()
end

function Vacuum.constructionRayCast( self )
	local start = self.shape:getWorldPosition()
	local stop = self.shape:getWorldPosition() - self.shape.at * 4.625
	local valid, result = sm.physics.raycast( start, stop, self.shape )
	if valid then
		local groundPointOffset = -( sm.construction.constants.subdivideRatio_2 - 0.04 + sm.construction.constants.shapeSpacing + 0.005 )
		local pointLocal = result.pointLocal
		if result.type ~= "body" and result.type ~= "joint" then
			pointLocal = pointLocal + result.normalLocal * groundPointOffset
		end

		local n = sm.vec3.closestAxis( result.normalLocal )
		local a = pointLocal * sm.construction.constants.subdivisions - n * 0.5
		local gridPos = sm.vec3.new( math.floor( a.x ), math.floor( a.y ), math.floor( a.z ) ) + n

		local function getTypeData()
			local shapeOffset = sm.vec3.new( sm.construction.constants.subdivideRatio_2, sm.construction.constants.subdivideRatio_2, sm.construction.constants.subdivideRatio_2 )
			local localPos = gridPos * sm.construction.constants.subdivideRatio + shapeOffset
			if result.type == "body" then
				local shape = result:getShape()
				if shape and sm.exists( shape ) then
					return shape:getBody():transformPoint( localPos ), shape
				else
					valid = false
				end
			elseif result.type == "joint" then
				local joint = result:getJoint()
				if joint and sm.exists( joint ) then
					return joint:getShapeA():getBody():transformPoint( localPos ), joint
				else
					valid = false
				end
			elseif result.type == "lift" then
				local lift, topShape = result:getLiftData()
				if lift and ( not topShape or lift:hasBodies() ) then
					valid = false
				end
				return localPos, lift
			elseif result.type == "character" then
				valid = false
			elseif result.type == "harvestable" then
				valid = false
			end
			return localPos
		end

		local worldPos, obj = getTypeData()
		return valid, gridPos, result.normalLocal, worldPos, obj
	end
	return valid
end

function Vacuum.server_outgoingReload( self, container, item )
	self.sv.foundContainer, self.sv.foundItem = container, item

	local isBlock = sm.item.isBlock( self.sv.foundItem )
	if self.sv.client.showBlockVisualization ~= isBlock then
		self.sv.client.showBlockVisualization = isBlock
		self:sv_markClientTableAsDirty()
	end

	if self.sv.canFire then
		self.sv.fireDelayProgress = FireDelay
		self.sv.canFire = false
	end

	if self.sv.foundContainer then
		self.network:sendToClients( "cl_n_onOutgoingReload", { shapesOnContainerPath = self.sv.foundContainer.shapesOnContainerPath, item = self.sv.foundItem } )
	end
end

function Vacuum.server_outgoingReset( self )
	self.sv.canFire = false
	self.sv.foundContainer = nil
	self.sv.foundItem = sm.uuid.getNil()

	if self.sv.client.showBlockVisualization then
		self.sv.client.showBlockVisualization = false
		self:sv_markClientTableAsDirty()
	end
end

function Vacuum.server_outgoingLoaded( self )
	return self.sv.foundContainer and self.sv.foundItem ~= sm.uuid.getNil()
end

function Vacuum.server_outgoingShouldReload( self, container, item )
	return self.sv.foundItem ~= item
end

function Vacuum.server_onFixedUpdate( self )

	local function setVacuumState( state, shapes )
		if self.sv.client.state ~= state then
			self.sv.client.state = state
			self:sv_markClientTableAsDirty()
		end

		for _, obj in ipairs( self.sv.client.pipeNetwork ) do
			for _, shape in ipairs( shapes ) do
				if obj.shape:getId() == shape:getId() then
					if obj.state ~= state then
						obj.state = state
						self:sv_markClientTableAsDirty()
					end
				end
			end
		end
	end

	local function setVacuumStateOnAllShapes( state )
		if self.sv.client.state ~= state then
			self.sv.client.state = state
			self:sv_markClientTableAsDirty()
		end

		for _, container in ipairs( self.sv.connectedContainers ) do
			for _, shape in ipairs( container.shapesOnContainerPath ) do
				for _, pipe in ipairs( self.sv.client.pipeNetwork ) do
					if pipe.shape:getId() == shape:getId() then
						pipe.state = state
						self:sv_markClientTableAsDirty()
					end
				end
			end
		end

	end

	-- Update fire delay progress
	if not self.sv.canFire then
		self.sv.fireDelayProgress = self.sv.fireDelayProgress - 1
		if self.sv.fireDelayProgress <= 0 then
			self.sv.fireDelayProgress = FireDelay
			self.sv.canFire = true
		end
	end

	-- Optimize this either through a simple has changed that only checks the body and not shapes
	-- Or let the body check and fire an event whenever it detects a change
	if  self.shape:getBody():hasChanged( sm.game.getCurrentTick() - 1 ) then
		self:sv_buildPipeNetwork()
	end

	if self.sv.storage.mode == VacuumMode.outgoing and #self.sv.connectedContainers > 0 then

		local publicData = self.interactable:getPublicData()
		assert(publicData)

		local interfacingWithPackingStation = sm.game.getCurrentTick() - 4 < publicData.packingStationTick
		if interfacingWithPackingStation then

			assert( publicData.packingStationProjectileUuid )
			local function findItemUidFromProjectileUuid()
				for uid, projectile in pairs( UuidToProjectile ) do
					if projectile.uuid == publicData.packingStationProjectileUuid then
						return sm.uuid.new( uid );
					end
				end
				return sm.uuid.getNil()
			end

			local itemUid = findItemUidFromProjectileUuid()
			assert( itemUid )

			local function findContainerAndItemWithUid()
				for _, container in ipairs( self.sv.connectedContainers ) do
					if sm.exists( container.shape ) then
						if not container.shape:getInteractable():getContainer():isEmpty() then
							if sm.container.canSpend( container.shape:getInteractable():getContainer(), itemUid, 1 ) then
								return container, itemUid
							end
						end
					end
				end
				return nil, sm.uuid.getNil()
			end

			local container, item = findContainerAndItemWithUid()
			if item == itemUid then
				if self:server_outgoingShouldReload( container, item ) then
					self:server_outgoingReload( container, item )
				end
				publicData.requestExternalOpen = true
				setVacuumState( PipeState.valid, self.sv.connectedContainers[1].shapesOnContainerPath )
			else
				publicData.requestExternalOpen = false
				setVacuumState( PipeState.invalid, self.sv.connectedContainers[1].shapesOnContainerPath )
			end

		else
			if publicData.requestExternalOpen then
				self:server_outgoingReset()
			end
			publicData.requestExternalOpen = false
			setVacuumState( PipeState.connected, self.sv.connectedContainers[1].shapesOnContainerPath )
		end

		if not interfacingWithPackingStation then

			local function findFirstContainerAndItem()
				for _, container in ipairs( self.sv.connectedContainers ) do
					if sm.exists( container.shape ) then
						if not container.shape:getInteractable():getContainer():isEmpty() then
							for slot = 0, container.shape:getInteractable():getContainer():getSize() - 1 do
								local item = container.shape:getInteractable():getContainer():getItem( slot )
								if UuidToProjectile[tostring(item.uuid)] or sm.item.isBlock( item.uuid ) then
									return container, item.uuid
								end
							end

						end
					end
				end
				return nil, sm.uuid.getNil()
			end
			local container, item = findFirstContainerAndItem()
			if self:server_outgoingShouldReload( container, item ) then
				self:server_outgoingReload( container, item )
			end
		end

		local function isValidPlacement()
			if sm.item.isBlock( self.sv.foundItem ) then
				local hit, gridPos, normalLocal, worldPos, obj = self:constructionRayCast()
				if hit then
					local function countTerrain()
						if type(obj) == "Shape" then
							return obj:getBody():isDynamic()
						end
						return false
					end
					return sm.physics.sphereContactCount( worldPos, 0.125, countTerrain() ) == 0 and
					sm.construction.validateLocalPosition( self.sv.foundItem, gridPos, normalLocal, obj ), gridPos, obj
				end
			end
		end
		local valid, gridPos, obj = isValidPlacement()

		local parent = self.shape:getInteractable():getSingleParent()
		if parent then
			if parent.active and not self.sv.parentActive and self.sv.canFire then
				local projectile = UuidToProjectile[tostring( self.sv.foundItem )]
				if projectile then
					sm.container.beginTransaction()
					sm.container.spend( self.sv.foundContainer.shape:getInteractable():getContainer(), self.sv.foundItem, 1, true )
					if sm.container.endTransaction() then
						-- If successful spend, fire an projectile
						if projectile.hvs then
							sm.projectile.shapeCustomProjectileAttack(
								{ hvs = projectile.hvs },
								projectile.uuid,
								0,
								sm.vec3.new( 0.0, 0.25, 0.0 ),
								sm.vec3.new( 0, -20, 0 ),
								self.shape )
						else
							sm.projectile.shapeFire(
								self.shape,
								projectile.uuid,
								sm.vec3.new( 0.0, 0.25, 0.0 ),
								sm.vec3.new( 0, -20, 0 ) )
						end

						self.network:sendToClients( "cl_n_onOutgoingFire", { shapesOnContainerPath = self.sv.foundContainer.shapesOnContainerPath } )
					end
					self:server_outgoingReset()
				elseif valid then
					sm.container.beginTransaction()
					sm.container.spend( self.sv.foundContainer.shape:getInteractable():getContainer(), self.sv.foundItem, 1, true )
					if sm.container.endTransaction() then
						sm.construction.buildBlock( self.sv.foundItem, gridPos, obj )
						self.network:sendToClients( "cl_n_onOutgoingFire", { shapesOnContainerPath = self.sv.foundContainer.shapesOnContainerPath } )
					end
					self:server_outgoingReset()
				else
					self.network:sendToClients( "cl_n_onError", { shapesOnContainerPath = self.sv.connectedContainers[1].shapesOnContainerPath } )
				end
			end
			self.sv.parentActive = parent.active
		end

	elseif self.sv.storage.mode == VacuumMode.incoming and #self.sv.connectedContainers > 0 then

		local incomingObjects = {}

		for _, result in ipairs(  self.sv.areaTrigger:getContents() ) do
			if sm.exists( result ) then
				if type( result ) == "Harvestable" then
					local pubData = result.publicData
					if not pubData or not pubData.harvested then
						if result:getUuid() == hvs_farmables_oilgeyser then
							local quantity = randomStackAmount( 1, 2, 4 )
							local container = FindContainerToCollectTo( self.sv.connectedContainers, obj_resource_crudeoil, quantity )
							if container then
								table.insert( incomingObjects, { container = container, harvestable = result, uuid = obj_resource_crudeoil, amount = quantity } )
							end
						elseif result:getUuid() == hvs_farmables_cottonplant then
							local container = FindContainerToCollectTo( self.sv.connectedContainers, obj_resource_cotton, 1 )
							if container then
								table.insert( incomingObjects, { container = container, harvestable = result, uuid = obj_resource_cotton, amount = 1 } )
							end
						elseif result:getUuid() == hvs_farmables_pigmentflower then
							local container = FindContainerToCollectTo( self.sv.connectedContainers, obj_resource_flower, 1 )
							if container then
								table.insert( incomingObjects, { container = container, harvestable = result, uuid = obj_resource_flower, amount = 1 } )
							end
						elseif pubData and pubData.vacuumable then
							local container = FindContainerToCollectTo( self.sv.connectedContainers, pubData.uuid, pubData.quantity )
							if container then
								table.insert( incomingObjects, { container = container, harvestable = result, uuid = pubData.uuid, amount = pubData.quantity } )
							end
						elseif result:getType() == "mature" then
							local data = result:getData()
							if data then
								local partUuid = data["harvest"]
								local amount = data["amount"]
								if partUuid and amount then
									partUuid = sm.uuid.new( partUuid )
									local container = FindContainerToCollectTo( self.sv.connectedContainers, partUuid, amount )
									if container then
										-- Collect seeds from harvestable
										local seedUuid = data["seed"]
										local seedIncomingObj = nil
										if seedUuid then
											local seedAmount = randomStackAmountAvg2()
											seedUuid = sm.uuid.new( seedUuid )
											local seedContainer = FindContainerToCollectTo( self.sv.connectedContainers, seedUuid, seedAmount )
											if seedContainer then
												seedIncomingObj = { container = seedContainer, uuid = seedUuid, amount = seedAmount }
											end
										end

										table.insert( incomingObjects, { container = container, harvestable = result, uuid = partUuid, amount = amount, seedIncomingObj = seedIncomingObj } )
									end
								end
							end
						end
					end
				elseif type( result ) == "AreaTrigger" then
					local userData = result:getUserData()
					if userData and ( userData.water == true or userData.chemical == true or userData.oil == true ) then
						local uidLiquidType = obj_consumable_water
						if userData.chemical == true then
							uidLiquidType = obj_consumable_chemical
						elseif userData.oil == true then
							uidLiquidType = obj_resource_crudeoil
						end
						local container = FindContainerToCollectTo( self.sv.connectedContainers, uidLiquidType, 1 )
						if container then

							local waterZ = result:getWorldMax().z
							local raycastStart = self.shape:getWorldPosition() + self.shape.at
							if raycastStart.z > waterZ then

								local raycastEnd = self.shape:getWorldPosition() - self.shape.at * 4

								local hit, result = sm.physics.raycast( raycastStart, raycastEnd, self.shape:getBody(), sm.physics.filter.static + sm.physics.filter.areaTrigger )
								if hit and result.type == "areaTrigger" then
									table.insert( incomingObjects, { container = container, uuid = uidLiquidType, amount = 1 } )
								end
							else
								table.insert( incomingObjects, { container = container, uuid = uidLiquidType, amount = 1 } )
							end
						end
					end
				-- elseif type( result ) == "Body" then
				-- 	for _, shape in ipairs( result:getShapes() ) do
				-- 		if shape:getBody():getCreationId() ~= self.shape:getBody():getCreationId() and shape:getBody():isDynamic() then
				-- 			local container = findContainerWithFreeSlots( shape:getShapeUuid(), 1 )
				-- 			if container then
				-- 				table.insert( incomingObjects, { container = container, shape = shape, uuid = shape:getShapeUuid(), amount = 1 } )
				-- 			end
				-- 		end
				-- 	end
				end
			end
		end

		-- If active
		local parent = self.shape:getInteractable():getSingleParent()
		if parent and parent.active and self.sv.canFire then
			for _, incomingObject in ipairs( incomingObjects ) do
				if incomingObject.container then
					sm.container.beginTransaction()

					sm.container.collect( incomingObject.container.shape:getInteractable():getContainer(), incomingObject.uuid, incomingObject.amount, true)
					if incomingObject.seedIncomingObj then
						sm.container.collect( incomingObject.seedIncomingObj.container.shape:getInteractable():getContainer(), incomingObject.seedIncomingObj.uuid, incomingObject.seedIncomingObj.amount, true)
					end

					if sm.container.endTransaction() then

						self.network:sendToClients( "cl_n_onIncomingFire", { shapesOnContainerPath = incomingObject.container.shapesOnContainerPath, item = incomingObject.uuid } )
						if incomingObject.shape then
							incomingObject.shape:destroyShape()
						end
						if incomingObject.harvestable then
							local pubData = incomingObject.harvestable.publicData
							if pubData then
								pubData.harvested = true
							end

							if incomingObject.harvestable:getType() == "mature" then
								sm.effect.playEffect( "Plants - Picked", sm.harvestable.getPosition( incomingObject.harvestable ) )
								sm.harvestable.createHarvestable( hvs_soil, sm.harvestable.getPosition( incomingObject.harvestable ), sm.harvestable.getRotation( incomingObject.harvestable ) )
							elseif incomingObject.harvestable:getUuid() == hvs_farmables_pigmentflower then
								sm.effect.playEffect( "Pigmentflower - Picked", sm.harvestable.getPosition( incomingObject.harvestable ) )
								sm.harvestable.createHarvestable( hvs_farmables_growing_pigmentflower, sm.harvestable.getPosition( incomingObject.harvestable ), sm.harvestable.getRotation( incomingObject.harvestable ) )
							elseif incomingObject.harvestable:getUuid() == hvs_farmables_cottonplant then
								sm.effect.playEffect( "Cotton - Picked", sm.harvestable.getPosition( incomingObject.harvestable ) )
								sm.harvestable.createHarvestable( hvs_farmables_growing_cottonplant, sm.harvestable.getPosition( incomingObject.harvestable ), sm.harvestable.getRotation( incomingObject.harvestable ) )
							elseif incomingObject.harvestable:getUuid() == hvs_farmables_oilgeyser then
								sm.effect.playEffect( "Oilgeyser - Picked", sm.harvestable.getPosition( incomingObject.harvestable ) )
								sm.harvestable.createHarvestable( hvs_farmables_growing_oilgeyser, sm.harvestable.getPosition( incomingObject.harvestable ), sm.harvestable.getRotation( incomingObject.harvestable ) )
							end

							sm.harvestable.destroy( incomingObject.harvestable )
						end
					end
				else
					self.network:sendToClients( "cl_n_onError", { shapesOnContainerPath = self.sv.connectedContainers[1].shapesOnContainerPath } )
				end
			end

			if #incomingObjects == 0 then
				self.network:sendToClients( "cl_n_onError", { shapesOnContainerPath = self.sv.connectedContainers[1].shapesOnContainerPath } )
			end
			self.sv.canFire = false
		end

		-- Synch visual feedback
		if #incomingObjects > 0 then

			-- Highlight the longest connection
			local longestConnection = incomingObjects[1].container
			for _, incomingObject in ipairs( incomingObjects ) do
				if #incomingObject.container.shapesOnContainerPath > #longestConnection.shapesOnContainerPath then
					longestConnection = incomingObject.container
				end
			end

			setVacuumState( PipeState.valid, longestConnection.shapesOnContainerPath )
		else
			setVacuumStateOnAllShapes( PipeState.connected )
		end
	end

	-- Storage table dirty
	if self.sv.dirtyStorageTable then
		self.storage:save( self.sv.storage )
		self.sv.dirtyStorageTable = false
	end

	-- Client table dirty
	if self.sv.dirtyClientTable then
		self.network:setClientData( { mode = self.sv.storage.mode, pipeNetwork = self.sv.client.pipeNetwork, state = self.sv.client.state, showBlockVisualization = self.sv.client.showBlockVisualization } )
		self.sv.dirtyClientTable = false
	end

end

-- Client
function Vacuum.client_onCreate( self )
	self.cl = {}

	-- Update from onClientDataUpdate
	self.cl.mode = VacuumMode.outgoing
	self.cl.pipeNetwork = {}
	self.cl.state = PipeState.off
	self.cl.showBlockVisualization = false

	self.cl.overrideUvFrameIndexTask = nil
	self.cl.poseAnimTask = nil
	self.cl.vacuumEffect = nil

	self.cl.pipeEffectPlayer = PipeEffectPlayer()
	self.cl.pipeEffectPlayer:onCreate()
end

function Vacuum.client_onClientDataUpdate( self, clientData )
	assert( clientData.mode )
	assert( clientData.state )
	self.cl.mode = clientData.mode
	self.cl.pipeNetwork = clientData.pipeNetwork
	self.cl.state = clientData.state
	self.cl.showBlockVisualization = clientData.showBlockVisualization
end

function Vacuum.client_onInteract( self, character, state )
	if state == true then
		self.network:sendToServer( "sv_n_toogle" )
	end
end

function Vacuum.client_onUpdate( self, dt )

	-- Update pose anims
	self:cl_updatePoseAnims( dt )

	-- Update Uv Index frames
	self:cl_updateUvIndexFrames( dt )

	-- Update effects through pipes
	self.cl.pipeEffectPlayer:update( dt )

	-- Visualize block if a block is loaded
	if self.cl.state == PipeState.connected and self.cl.showBlockVisualization then
		local valid, gridPos, localNormal, worldPos, obj = self:constructionRayCast()
		if valid then
			local function countTerrain()
				if type(obj) == "Shape" then
					return obj:getBody():isDynamic()
				end
				return false
			end
			sm.visualization.setBlockVisualization(gridPos,
				sm.physics.sphereContactCount( worldPos, sm.construction.constants.subdivideRatio_2, countTerrain() ) > 0 or not sm.construction.validateLocalPosition( blk_cardboard, gridPos, localNormal, obj ),
				obj)
		end
	end
end

-- Events

function Vacuum.cl_n_onOutgoingReload( self, data )

	local shapeList = {}
	for idx, shape in reverse_ipairs( data.shapesOnContainerPath ) do
		table.insert( shapeList, shape )
	end
	table.insert( shapeList, self.shape )

	self.cl.pipeEffectPlayer:pushShapeEffectTask( shapeList, data.item )

	self:cl_setOverrideUvIndexFrame( shapeList, PipeState.valid )
end

function Vacuum.cl_n_onOutgoingFire( self, data )
	local shapeList = data.shapesOnContainerPath
	if shapeList then
		table.insert( shapeList, self.shape )
	end

	self:cl_setOverrideUvIndexFrame( shapeList, PipeState.valid )
	self:cl_setPoseAnimTask( "outgoingFire" )

	self.cl.vacuumEffect = sm.effect.createEffect( "Vacuumpipe - Blowout", self.interactable )
	self.cl.vacuumEffect:setOffsetRotation( sm.quat.angleAxis( math.pi*0.5, sm.vec3.new( 1, 0, 0 ) ) )
	self.cl.vacuumEffect:start()
end

function Vacuum.cl_n_onIncomingFire( self, data )

	table.insert( data.shapesOnContainerPath, 1, self.shape )

	self.cl.pipeEffectPlayer:pushShapeEffectTask( data.shapesOnContainerPath, data.item )

	self:cl_setOverrideUvIndexFrame( data.shapesOnContainerPath, PipeState.valid )
	self:cl_setPoseAnimTask( "incomingFire" )

	self.cl.vacuumEffect = sm.effect.createEffect( "Vacuumpipe - Suction", self.interactable )
	self.cl.vacuumEffect:setOffsetRotation( sm.quat.angleAxis( math.pi*0.5, sm.vec3.new( 1, 0, 0 ) ) )
	self.cl.vacuumEffect:start()
end

function Vacuum.cl_n_onError( self, data )
	self:cl_setOverrideUvIndexFrame( data.shapesOnContainerPath, PipeState.invalid )
end

-- State sets

function Vacuum.cl_pushEffectTask( self, shapeList, effect )
	self.cl.pipeEffectPlayer:pushEffectTask( shapeList, effect )
end

function Vacuum.cl_setOverrideUvIndexFrame( self, shapeList, state )
	local shapeMap = {}
	if shapeList then
		for _, shape in ipairs( shapeList ) do
			shapeMap[shape:getId()] = state
		end
	end
	self.cl.overrideUvFrameIndexTask = { shapeMap = shapeMap, state = state, progress = 0 }
end

function Vacuum.cl_setPoseAnimTask( self, name )
	self.cl.poseAnimTask = { name = name, progress = 0 }
end

-- Updates

PoseCurves = {}
PoseCurves["outgoingFire"] = Curve()
PoseCurves["outgoingFire"]:init({{v=0.5, t=0.0},{v=1.0, t=0.1},{v=0.5, t=0.2},{v=0.0, t=0.3},{v=0.5, t=0.6}})

PoseCurves["incomingFire"] = Curve()
PoseCurves["incomingFire"]:init({{v=0.5, t=0.0},{v=0.0, t=0.1},{v=0.5, t=0.2},{v=1.0, t=0.3},{v=0.5, t=0.6}})

function Vacuum.cl_updatePoseAnims( self, dt )

	if self.cl.poseAnimTask then

		self.cl.poseAnimTask.progress = self.cl.poseAnimTask.progress + dt

		local curve = PoseCurves[self.cl.poseAnimTask.name]
		if curve then
			self.shape:getInteractable():setPoseWeight( 0, curve:getValue( self.cl.poseAnimTask.progress ) )

			if self.cl.poseAnimTask.progress > curve:duration() then
				self.cl.poseAnimTask = nil
			end
		else
			self.cl.poseAnimTask = nil
		end
	end

end

local GlowCurve = Curve()
GlowCurve:init({{v=1.0, t=0.0}, {v=0.5, t=0.05}, {v=0.0, t=0.1}, {v=0.5, t=0.3}, {v=1.0, t=0.4}, {v=0.5, t=0.5}, {v=0.0, t=0.7}, {v=0.5, t=0.75}, {v=1.0, t=0.8}})

function Vacuum.cl_updateUvIndexFrames( self, dt )

	local glowMultiplier = 1.0

	-- Events allow for overriding the uv index frames, time it out
	if self.cl.overrideUvFrameIndexTask then
		self.cl.overrideUvFrameIndexTask.progress = self.cl.overrideUvFrameIndexTask.progress + dt

		glowMultiplier = GlowCurve:getValue( self.cl.overrideUvFrameIndexTask.progress )

		if self.cl.overrideUvFrameIndexTask.progress > 0.1 then

			self.cl.overrideUvFrameIndexTask.change = true
		end

		if self.cl.overrideUvFrameIndexTask.progress > 0.7 then

			self.cl.overrideUvFrameIndexTask.change = false
		end

		if self.cl.overrideUvFrameIndexTask.progress > GlowCurve:duration() then

			self.cl.overrideUvFrameIndexTask = nil
		end
	end

	-- Light up vacuum
	local state = self.cl.state
	if self.cl.overrideUvFrameIndexTask and self.cl.overrideUvFrameIndexTask.change == true then
		state = self.cl.overrideUvFrameIndexTask.state
	end

	VacuumFrameIndexTable = {
		[VacuumMode.outgoing] = {
			[PipeState.off] = 0,
			[PipeState.invalid] = 1,
			[PipeState.connected] = 2,
			[PipeState.valid] = 4
		},
		[VacuumMode.incoming] = {
			[PipeState.off] = 0,
			[PipeState.invalid] = 1,
			[PipeState.connected] = 3,
			[PipeState.valid] = 5
		}
	}
	assert( self.cl.mode > 0 and self.cl.mode <= 2 )
	assert( state > 0 and state <= 4 )
	local vacuumFrameIndex = VacuumFrameIndexTable[self.cl.mode][state]
	self.interactable:setUvFrameIndex( vacuumFrameIndex )
	if self.cl.overrideUvFrameIndexTask then
		self.interactable:setGlowMultiplier( glowMultiplier )
	else
		self.interactable:setGlowMultiplier( 1.0 )
	end

	local function fnOverride( pipe )

		local state = pipe.state
		local glow = 1.0

		if self.cl.overrideUvFrameIndexTask then
			local overrideState = self.cl.overrideUvFrameIndexTask.shapeMap[pipe.shape:getId()]
			if overrideState then
				if self.cl.overrideUvFrameIndexTask.change == true then
					state = overrideState
				end
				glow = glowMultiplier
			end
		end

		return state, glow
	end

	-- Light up pipes
	LightUpPipes( self.cl.pipeNetwork, fnOverride )
end