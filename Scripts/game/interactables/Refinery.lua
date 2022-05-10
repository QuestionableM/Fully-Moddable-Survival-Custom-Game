	
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/pipes.lua"

Refinery = class( nil )
local StackSize = 256
local AnimUnpackTime = 1
local AnimStartTime = 0.8667
local AnimUseTime = 4
local AnimFinishTime = 2

function Refinery.server_onCreate(self)
	self.sv = {}
	if not self.shape:getInteractable():getContainer(1) then
		self.shape:getInteractable():addContainer( 1, 1, 1 )
	end
	local container = self.shape:getInteractable():getContainer(0)
	if not container then
		container = self.shape:getInteractable():addContainer( 0, 1, StackSize )
	end
	container.allowCollect = false

	self:sv_init()
end

function Refinery.getInputContainer( self )
	return self.shape:getInteractable():getContainer(1)
end

function Refinery.getOutputContainer( self )
	return self.shape:getInteractable():getContainer(0)
end

function Refinery.server_canErase( self )
	local containerIn = self.shape:getInteractable():getContainer(0)
	local containerOut = self.shape:getInteractable():getContainer(1)

	if not containerIn:isEmpty() or not containerOut:isEmpty() then
		return false
	end
	return true
end

function Refinery.client_canErase( self )
	local containerIn = self.shape:getInteractable():getContainer(0)
	local containerOut = self.shape:getInteractable():getContainer(1)

	if not containerIn:isEmpty() or not containerOut:isEmpty() then
		sm.gui.displayAlertText( "#{INFO_BUSY}", 1.5 )
		return false
	end
	return true
end

function Refinery.client_onCreate(self)
	self.cl = {}
	self:cl_init()
	self.cl.suckStartEffect = sm.effect.createEffect( "Refinery - SuckStart", self.interactable, "jnt_suction" )
	self.cl.workWoodEffect = sm.effect.createEffect( "Refinery - WorkWood", self.interactable, "root_jnt" )
	self.cl.workStoneEffect = sm.effect.createEffect( "Refinery - WorkStone", self.interactable, "root_jnt" )
	self.cl.workMetalEffect = sm.effect.createEffect( "Refinery - WorkMetal", self.interactable, "root_jnt" )
	self.cl.suckFinishEffect = sm.effect.createEffect( "Refinery - Finish", self.interactable, "jnt_suction" )
	self.cl.unpackEffect = sm.effect.createEffect( "Refinery - Unpack", self.interactable, "root_jnt" )

	self.cl.harvestEffect = sm.effect.createEffect( "ShapeRenderable", self.interactable, "rendable_jnt" )
	self.cl.scrapWoodEffect = sm.effect.createEffect( "Refinery - ScrapWoodBlock", self.interactable, "root_jnt" )
	self.cl.scrapStoneEffect = sm.effect.createEffect( "Refinery - ScrapStoneBlock", self.interactable, "root_jnt" )
	self.cl.scrapMetalEffect = sm.effect.createEffect( "Refinery - ScrapMetalBlock", self.interactable, "root_jnt" )
	self.cl.woodEffect = sm.effect.createEffect( "Refinery - WoodBlock", self.interactable, "root_jnt" )
	self.cl.metalEffect = sm.effect.createEffect( "Refinery - MetalBlock", self.interactable, "root_jnt" )

	self.cl.scrapWoodEffectLog = sm.effect.createEffect( "Refinery - ScrapWoodBlockLog", self.interactable, "rendable_jnt" )
	self.cl.scrapStoneEffectLog = sm.effect.createEffect( "Refinery - ScrapStoneBlockLog", self.interactable, "rendable_jnt" )
	self.cl.scrapMetalEffectLog = sm.effect.createEffect( "Refinery - ScrapMetalBlockLog", self.interactable, "rendable_jnt" )
	self.cl.woodEffectLog = sm.effect.createEffect( "Refinery - WoodBlockLog", self.interactable, "rendable_jnt" )
	self.cl.metalEffectLog = sm.effect.createEffect( "Refinery - MetalBlockLog", self.interactable, "rendable_jnt" )

	self.cl.unpackEffect:start()
end

function Refinery.client_onClientDataUpdate( self, clientData )
	self.cl.pipes = clientData.pipes
end

function Refinery.client_onDestroy(self)
	if self.cl.suckStartEffect then
		self.cl.suckStartEffect:stop()
		self.cl.suckStartEffect:destroy()
	end
	if self.cl.workWoodEffect then
		self.cl.workWoodEffect:stop()
		self.cl.workWoodEffect:destroy()
	end
	if self.cl.workStoneEffect then
		self.cl.workStoneEffect:stop()
		self.cl.workStoneEffect:destroy()
	end
	if self.cl.workMetalEffect then
		self.cl.workMetalEffect:stop()
		self.cl.workMetalEffect:destroy()
	end
	if self.cl.suckFinishEffect then
		self.cl.suckFinishEffect:stop()
		self.cl.suckFinishEffect:destroy()
	end
	if self.cl.unpackEffect then
		self.cl.unpackEffect:stop()
		self.cl.unpackEffect:destroy()
	end
	if self.cl.harvestEffect then
		self.cl.harvestEffect:stop()
		self.cl.harvestEffect:destroy()
	end
	if self.cl.scrapWoodEffect then
		self.cl.scrapWoodEffect:stop()
		self.cl.scrapWoodEffect:destroy()
	end
	if self.cl.scrapStoneEffect then
		self.cl.scrapStoneEffect:stop()
		self.cl.scrapStoneEffect:destroy()
	end
	if self.cl.scrapMetalEffect then
		self.cl.scrapMetalEffect:stop()
		self.cl.scrapMetalEffect:destroy()
	end
	if self.cl.woodEffect then
		self.cl.woodEffect:stop()
		self.cl.woodEffect:destroy()
	end
	if self.cl.metalEffect then
		self.cl.metalEffect:stop()
		self.cl.metalEffect:destroy()
	end
	if self.cl.scrapWoodEffectLog then
		self.cl.scrapWoodEffectLog:stop()
		self.cl.scrapWoodEffectLog:destroy()
	end
	if self.cl.scrapStoneEffectLog then
		self.cl.scrapStoneEffectLog:stop()
		self.cl.scrapStoneEffectLog:destroy()
	end
	if self.cl.scrapMetalEffectLog then
		self.cl.scrapMetalEffectLog:stop()
		self.cl.scrapMetalEffectLog:destroy()
	end
	if self.cl.woodEffectLog then
		self.cl.woodEffectLog:stop()
		self.cl.woodEffectLog:destroy()
	end
	if self.cl.metalEffectLog then
		self.cl.metalEffectLog:stop()
		self.cl.metalEffectLog:destroy()
	end
end

function Refinery.sv_init(self)

	self.sv.updateProgress = 0.0
	self.sv.updateTime = 1.0 		--seconds

	self.sv.hasInputItem = false
	self.sv.outputFull = false

	self.sv.isProducing = false
	self.sv.productionProgress = 0.0
	self.sv.productionTime = AnimStartTime + AnimUseTime + AnimFinishTime

	if self.sv.areaTrigger then
		sm.areaTrigger.destroy( self.sv.areaTrigger )
		self.sv.areaTrigger = nil
	end

	local size = sm.vec3.new( 0.5, 0.5, 0.5 )
	local position = sm.vec3.new( -2.0, -0.25, 0.0 )
	local filter = sm.areaTrigger.filter.areaTrigger
	self.sv.areaTrigger = sm.areaTrigger.createAttachedBox( self.interactable, size, position, sm.quat.identity(), filter )

	self.sv.pipes = {}
	self.sv.containers = {}
	self.sv.clientDataDirty = false

	self:server_getConnectedPipesAndChests()

end

function Refinery.cl_createAnimation( self, name, playTime )
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

function Refinery.cl_setAnimation( self, animation, playProgress )

	self:cl_unsetAnimation()
	animation.isActive = true
	animation.playProgress = playProgress
	self.interactable:setAnimEnabled(animation.name, true)
	self.cl.currentAnimation = animation.name
end

function Refinery.cl_unsetAnimation( self )

	for name, animation in pairs( self.cl.animations ) do
		animation.isActive = false
		animation.playProgress = 0.0
		self.interactable:setAnimEnabled(animation.name, false)
		self.interactable:setAnimProgress(animation.name, animation.playProgress )
	end
	self.cl.currentAnimation = ""
end

function Refinery.cl_updateAnimation( self, dt )

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
							self:cl_setAnimation(animation.nextAnimation, 0.0)
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

function Refinery.cl_init(self)

	local animations = {}
	animations["unpack"] = self:cl_createAnimation( "Refinery_unpack", AnimUnpackTime )
	animations["start"] = self:cl_createAnimation( "Refinery_start", AnimStartTime )
	animations["use"] = self:cl_createAnimation( "Refinery_use", AnimUseTime )
	animations["finish"] = self:cl_createAnimation( "Refinery_finish", AnimFinishTime )
	animations["start"].nextAnimation = animations["use"]
	animations["use"].nextAnimation = animations["finish"]
	self.cl.animations = animations
	self.cl.currentAnimation = ""

	self:cl_setAnimation(self.cl.animations["unpack"], 0.0)

	self.cl.isProducing = false
	self.cl.productionProgress = 0.0
	self.cl.productionTime = AnimStartTime + AnimUseTime + AnimFinishTime

	self.cl.pipes = {}
	self.cl.pipeEffectPlayer = PipeEffectPlayer()
	self.cl.pipeEffectPlayer:onCreate()
end

function Refinery.server_onRefresh(self)
	self:sv_init()
end

function Refinery.client_onRefresh(self)
	self:cl_init()
	self.cl.previousAnimation = nil
end

function Refinery.client_onUpdate(self, dt)

	self.cl.pipeEffectPlayer:update( dt )

	local container0 = self.shape:getInteractable():getContainer(1)
	local container1 = self.shape:getInteractable():getContainer(0)
	if not container0 or not container1 then
		return
	end

	local particleSmoke = "paint_smoke"
	local particleTransport = "Box_Kim"
	local particleMetal = "hammer_metal"

	local inputItemUuids = sm.container.itemUuid(self.shape:getInteractable():getContainer(1))
	local harvestUuid = inputItemUuids[1]

	self:cl_updateAnimation( dt )

	if self.cl.isProducing then
		self.cl.productionProgress = self.cl.productionProgress + dt/self.cl.productionTime
		if self.cl.productionProgress >= 1.0 then
			self.cl.productionProgress = 1.0
		end
	else
		self.cl.productionProgress = 0.0
	end

	if self.cl.animations["start"].isActive then
		if self.cl.previousAnimation ~= self.cl.currentAnimation then
			self.cl.suckStartEffect:start()
			self.cl.harvestEffect:setParameter( "uuid", harvestUuid )
			self.cl.harvestEffect:setScale( sm.vec3.new( 0.25, 0.25, 0.25 ) )
			self.cl.harvestEffect:setParameter( "Color", sm.shape.getShapeTypeColor( harvestUuid ) )
			self.cl.harvestEffect:start()
		end
		
	elseif self.cl.animations["use"].isActive then
		if self.cl.previousAnimation ~= self.cl.currentAnimation then
			if harvestUuid == obj_harvest_wood or harvestUuid == obj_harvest_wood2 then
				self.cl.workWoodEffect:start()
			elseif harvestUuid == obj_harvest_stone then
				self.cl.workStoneEffect:start()
			elseif harvestUuid == obj_harvest_metal or harvestUuid == obj_harvest_metal2 then
				self.cl.workMetalEffect:start()
			end
		end
	elseif self.cl.animations["finish"].isActive then
		if self.cl.previousAnimation ~= self.cl.currentAnimation then
			self.cl.harvestEffect:stop()
			self.cl.suckFinishEffect:start()
			if harvestUuid == obj_harvest_wood then
				self.cl.scrapWoodEffect:start()
				self.cl.scrapWoodEffectLog:start()
			elseif harvestUuid == obj_harvest_stone then
				self.cl.scrapStoneEffect:start()
				self.cl.scrapStoneEffectLog:start()
			elseif harvestUuid == obj_harvest_metal then
				self.cl.scrapMetalEffect:start()
				self.cl.scrapMetalEffectLog:start()
			elseif harvestUuid == obj_harvest_metal2 then
				self.cl.metalEffect:start()
				self.cl.metalEffectLog:start()
			elseif harvestUuid == obj_harvest_wood2 then
				self.cl.woodEffect:start()
				self.cl.woodEffectLog:start()
			end
		end
	end

	self.cl.previousAnimation = self.cl.currentAnimation

	LightUpPipes( self.cl.pipes )
end

function Refinery.client_onInteract(self, _, state)
	if state == true then
		local gui = sm.gui.createContainerGui( true )
		gui:setText( "UpperName", "#{CONTAINER_TITLE_REFINERY}" )
		gui:setContainer( "UpperGrid", self.shape:getInteractable():getContainer(0) )
		gui:setText( "LowerName", "#{INVENTORY_TITLE}" )
		gui:setContainer( "LowerGrid", sm.localPlayer.getInventory() )
		gui:open()
	end
end


function Refinery.server_markClientDataDirty( self )
	self.sv.clientDataDirty = true
end

function Refinery.server_sendClientData( self )
	if self.sv.clientDataDirty then
		self.network:setClientData( { pipes = self.sv.pipes } )
		self.sv.clientDataDirty = false
	end
end

function Refinery.server_getConnectedPipesAndChests( self )
	self.sv.pipes = {}
	self.sv.containers = {}

	local function fnOnVertex( vertex )

		if isAnyOf( vertex.shape:getShapeUuid(), { obj_craftbot_craftbot1, obj_craftbot_craftbot2, obj_craftbot_craftbot3, obj_craftbot_craftbot4, obj_craftbot_craftbot5, obj_craftbot_refinery } ) then
			return false
		elseif isAnyOf( vertex.shape:getShapeUuid(), ContainerUuids ) then -- Is Container
			assert( vertex.shape:getInteractable():getContainer() )
			local container = {
				shape = vertex.shape,
				distance = vertex.distance,
				shapesOnContainerPath = vertex.shapesOnPath
			}

			table.insert( self.sv.containers, container )
		elseif isAnyOf( vertex.shape:getShapeUuid(), PipeUuids ) then -- Is Pipe
			assert( vertex.shape:getInteractable() )
			local pipe = {
				shape = vertex.shape,
				state = PipeState.off
			}
			table.insert( self.sv.pipes, pipe )
		end

		return true
	end

	ConstructPipedShapeGraph( self.shape, fnOnVertex )

	table.sort( self.sv.containers, function(a, b) return a.distance < b.distance end )

	for _, container in ipairs( self.sv.containers ) do
		for _, shape in ipairs( container.shapesOnContainerPath ) do
			for _, pipe in ipairs( self.sv.pipes ) do
				if pipe.shape:getId() == shape:getId() then
					pipe.state = PipeState.connected
				end
			end
		end
	end

	self:server_markClientDataDirty()

end

function Refinery.server_onFixedUpdate( self, dt )

	if self.shape:getBody():hasChanged( sm.game.getCurrentTick() - 1 ) then
		self:server_getConnectedPipesAndChests()
	end

	if self.sv.isProducing then

		local inputItemUuids = sm.container.itemUuid( self:getInputContainer() )
		local harvestUuid = inputItemUuids[1]
		local recipe = g_refineryRecipes[tostring(inputItemUuids[1])]

		if recipe then
			self.sv.productionProgress = self.sv.productionProgress + dt/self.sv.productionTime
			if self.sv.productionProgress >= 1.0 then
				if sm.container.beginTransaction() then

					local outputContainer
					local objContainer
					if #self.sv.containers > 0 then
						objContainer = FindContainerToCollectTo( self.sv.containers, recipe.itemId, recipe.quantity )
						if objContainer then
							outputContainer = objContainer.shape:getInteractable():getContainer()
						end
					end
					if outputContainer == nil then
						outputContainer = self.shape:getInteractable():getContainer( 0 )
					end

					sm.container.spend( self.shape:getInteractable():getContainer( 1 ), harvestUuid, 1, true )
					sm.container.collect( outputContainer, recipe.itemId, recipe.quantity, true )
					if sm.container.endTransaction() then
						self.sv.productionProgress = 0.0
						self.sv.isProducing = false

						if objContainer then
							self.network:sendToClients("cl_finishProduction", { shapesOnContainerPath = objContainer.shapesOnContainerPath, item = recipe.itemId } )
						else
							self.network:sendToClients("cl_finishProduction")
						end
					end
				end
			end
		else
			self.sv.isProducing = false
			self.sv.productionProgress = 0.0
			local params = { isProducing = false}
			self.network:sendToClients("cl_setIsProducing", params)
		end
	else
		self.sv.productionProgress = 0
	end

	--------------------

	self.sv.updateProgress = self.sv.updateProgress + dt/self.sv.updateTime
	if self.sv.updateProgress >= 1.0 then
		self.sv.updateProgress = 0.0

		local inputItemUuids = sm.container.itemUuid( self:getInputContainer() )
		local harvestUuid = inputItemUuids[1]
		local recipe = g_refineryRecipes[tostring(inputItemUuids[1])]

		local outputItem = nil

		if inputItemUuids[1] == sm.uuid.getNil() then
			self.sv.hasInputItem = false
		else
			if sm.shape.getIsHarvest(inputItemUuids[1]) then
				self.sv.hasInputItem = true
			else
				self.sv.hasInputItem = false
				print("ERROR, invalid object")
				--borde inte hända men spotta ut allt ur container 0 om detta händer
			end
		end

		-------------------
		--Determine if the output is occupied or available for more
		local outputItemUuids = sm.container.itemUuid( self:getOutputContainer() )
		if outputItemUuids[1] == sm.uuid.getNil() then
			self.sv.outputFull = false
		else
			outputItem = outputItemUuids[1]
			local currentOutputQuantity = sm.container.quantity( self:getOutputContainer() )[1]
			if recipe then		
				if #self.sv.containers > 0 then
					local objContainer = FindContainerToCollectTo( self.sv.containers, recipe.itemId, recipe.quantity )
					if objContainer then
						self.sv.outputFull = false
					end
				else
					if recipe.itemId ~= outputItem or recipe.quantity + currentOutputQuantity > StackSize then
						self.sv.outputFull = true
					else
						self.sv.outputFull = false
					end
				end
			else
				self.sv.outputFull = true
			end
		end
		-------------------

		if self.sv.hasInputItem and not self.sv.outputFull then
			--Can produce so start production
			if not self.sv.isProducing then
				self.sv.isProducing = true
				self.sv.productionProgress = 0.0
				local params = { isProducing = true}
				self.network:sendToClients("cl_setIsProducing", params)
			end
		elseif not self.sv.hasInputItem then

			----Try to collect nearby harvest
			local foundHarvest = false
			for _, object in ipairs( self.sv.areaTrigger:getContents() ) do
				if foundHarvest then
					break
				end
				if type( object ) == "AreaTrigger" then
					local trigger = object
					if sm.exists( trigger ) then
						local userData = trigger:getUserData()
						if userData and userData.resourceCollector then
							local shape = userData.resourceCollector
							--Search shape containers
							if shape:getInteractable() then

								local otherContainerInput = shape:getInteractable():getContainer(1)
								local otherContainerOutput = shape:getInteractable():getContainer(0)
								local otherContainer
								if otherContainerOutput then
									otherContainer = otherContainerOutput
								else
									otherContainer = otherContainerInput
								end
								if otherContainer then

									local otherItemUuids = sm.container.itemUuid( otherContainer )
									for _, itemUuid in ipairs( otherItemUuids ) do
										if foundHarvest then
											break
										end
										if sm.shape.getIsHarvest(itemUuid) then
											foundHarvest = true
											if sm.container.beginTransaction() then
												sm.container.collect(self.shape:getInteractable():getContainer(1), itemUuid, 1, true)
												sm.container.spend(otherContainer, itemUuid, 1, true)
												sm.container.endTransaction()
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

		if not self.sv.hasInputItem or self.sv.outputFull then
			--Abort any ongoing production because production can't continue
			if self.sv.isProducing then
				self.sv.isProducing = false
				self.sv.productionProgress = 0.0
				local params = { isProducing = false}
				self.network:sendToClients("cl_setIsProducing", params)
			end
		end
	end


	self:server_sendClientData()
end

function Refinery.sv_takeHarvest(self, params)
	if self.sv.productionProgress <= 0.5 then
		if sm.container.beginTransaction() then
			sm.container.spend(params.inputContainer, params.itemUuid, 1, true)
			sm.container.collect(params.carryContainer, params.itemUuid, 1, true)
			sm.container.endTransaction()
		end
	end
end

function Refinery.sv_e_receiveItem( self, params )
	if sm.shape.getIsHarvest( params.itemA ) then
		local container = self.interactable:getContainer( 1 )
		if container then
			sm.container.beginTransaction()
			sm.container.spend( params.containerA, params.itemA, params.quantityA, true )
			sm.container.collect( container, params.itemA, params.quantityA, true )
			sm.container.endTransaction()
		end
	end
end

function Refinery.sv_collectPart(self, params)

	if sm.container.beginTransaction() then
		sm.container.collect(params.container, params.shape.shapeUuid, 1, true)
		if sm.container.endTransaction() then
			sm.body.removePart(params.body, params.shape)
			sm.shape.destroy(params.shape)
			sm.body.destroy(params.body)
		end
	end

end

function Refinery.cl_setIsProducing( self, params )

	self.cl.productionProgress = 0.0
	self.cl.isProducing = params.isProducing
	if params.isProducing then
		self:cl_setAnimation(self.cl.animations["start"], 0.0)
	else
		self:cl_unsetAnimation()
	end
end

function Refinery.cl_finishProduction( self, params )

	self.cl.productionProgress = 0.0
	self.cl.isProducing = false
	self:cl_setAnimation(self.cl.animations["unpack"], 1.0)

	if params then
		local startNode = PipeEffectNode()
		startNode.shape = self.shape
		startNode.point = sm.vec3.new( -4.0, -4.0, 0.5 ) * sm.construction.constants.subdivideRatio
		table.insert( params.shapesOnContainerPath, 1, startNode )

		self.cl.pipeEffectPlayer:pushShapeEffectTask( params.shapesOnContainerPath, params.item )
	end

end