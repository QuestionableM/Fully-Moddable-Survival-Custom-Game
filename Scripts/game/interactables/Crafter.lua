-- Crafter.lua --

dofile "$SURVIVAL_DATA/Scripts/game/survival_items.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_survivalobjects.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/pipes.lua"

Crafter = class( nil )
Crafter.colorNormal = sm.color.new( 0x84ff32ff )
Crafter.colorHighlight = sm.color.new( 0xa7ff4fff )

local crafters = {
	-- Workbench
	[tostring( obj_survivalobject_workbench )] = {
		needsPower = true,
		slots = 1,
		speed = 1,
		recipeSets = {
			{ name = "workbench", locked = false }
		},
		subTitle = "Workbench",
		createGuiFunction = sm.gui.createWorkbenchGui
	},
	-- Dispenser
	[tostring( obj_survivalobject_dispenserbot )] = {
		needsPower = true,
		slots = 1,
		speed = 1,
		recipeSets = {
			{ name = "dispenser", locked = false }
		},
		subTitle = "Dispenser",
		createGuiFunction = sm.gui.createMechanicStationGui
	},
	-- Cookbot
	[tostring( obj_craftbot_cookbot )] = {
		needsPower = false,
		slots = 1,
		speed = 1,
		recipeSets = {
			{ name = "cookbot", locked = false }
		},
		subTitle = "Cookbot"
	},
	-- Craftbot 1
	[tostring( obj_craftbot_craftbot1 )] = {
		needsPower = false,
		slots = 2,
		speed = 1,
		upgrade = tostring( obj_craftbot_craftbot2 ),
		upgradeCost = 5,
		recipeSets = {
			{ name = "craftbot", locked = false }
		},
		subTitle = "#{LEVEL} 1",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- Craftbot 2
	[tostring( obj_craftbot_craftbot2 )] = {
		needsPower = false,
		slots = 4,
		speed = 1,
		upgrade = tostring( obj_craftbot_craftbot3 ),
		upgradeCost = 5,
		recipeSets = {
			{ name = "craftbot", locked = false }
		},
		subTitle = "#{LEVEL} 2",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- Craftbot 3
	[tostring( obj_craftbot_craftbot3 )] = {
		needsPower = false,
		slots = 6,
		speed = 1,
		upgrade = tostring( obj_craftbot_craftbot4 ),
		upgradeCost = 5,
		recipeSets = {
			{ name = "craftbot", locked = false }
		},
		subTitle = "#{LEVEL} 3",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- Craftbot 4
	[tostring( obj_craftbot_craftbot4 )] = {
		needsPower = false,
		slots = 8,
		speed = 1,
		upgrade = tostring( obj_craftbot_craftbot5 ),
		upgradeCost = 20,
		recipeSets = {
			{ name = "craftbot", locked = false }
		},
		subTitle = "#{LEVEL} 4",
		createGuiFunction = sm.gui.createCraftBotGui
	},
	-- Craftbot 5
	[tostring( obj_craftbot_craftbot5 )] = {
		needsPower = false,
		slots = 8,
		speed = 2,
		recipeSets = {
			{ name = "craftbot", locked = false }
		},
		subTitle = "#{LEVEL} 5",
		createGuiFunction = sm.gui.createCraftBotGui
	}
}

local effectRenderables = {
	[tostring( obj_consumable_carrotburger )] = { char_cookbot_food_03, char_cookbot_food_04 },
	[tostring( obj_consumable_pizzaburger )] = { char_cookbot_food_01, char_cookbot_food_02 },
	[tostring( obj_consumable_longsandwich )] = { char_cookbot_food_02, char_cookbot_food_03 }
}

function Crafter.server_onCreate( self )
	self:sv_init()
end

function Crafter.server_onRefresh( self )
	self.crafter = nil
	self.network:setClientData( { craftArray = {}, pipeGraphs = {} })
	self:sv_init()
end

function Crafter.server_canErase( self )
	return #self.sv.craftArray == 0
end

function Crafter.client_onCreate( self )
	self:cl_init()
end

function Crafter.client_onDestroy( self )
	for _,effect in ipairs( self.cl.mainEffects ) do
		effect:destroy()
	end

	for _,effect in ipairs( self.cl.secondaryEffects ) do
		effect:destroy()
	end

	for _,effect in ipairs( self.cl.tertiaryEffects ) do
		effect:destroy()
	end

	for _,effect in ipairs( self.cl.quaternaryEffects ) do
		effect:destroy()
	end
end

function Crafter.client_onRefresh( self )
	self.crafter = nil
	self:cl_disableAllAnimations()
	self:cl_init()
end

function Crafter.client_canErase( self )
	if #self.cl.craftArray > 0 then
		sm.gui.displayAlertText( "#{INFO_BUSY}", 1.5 )
		return false
	end
	return true
end

-- Server Init

function Crafter.sv_init( self )
	self.crafter = crafters[tostring( self.shape:getShapeUuid() )]
	self.sv = {}
	self.sv.clientDataDirty = false
	self.sv.storageDataDirty = true
	self.sv.craftArray = {}
	self.sv.saved = self.storage:load()
	if self.params then print( self.params ) end

	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.spawner = self.params and self.params.spawner or nil
		self:sv_updateStorage()
	end

	if self.sv.saved.craftArray then
		self.sv.craftArray = self.sv.saved.craftArray
	end

	self:sv_buildPipesAndContainerGraph()
end

function Crafter.sv_markClientDataDirty( self )
	self.sv.clientDataDirty = true
end

function Crafter.sv_sendClientData( self )
	if self.sv.clientDataDirty then
		self.network:setClientData( { craftArray = self.sv.craftArray, pipeGraphs = self.sv.pipeGraphs } )
		self.sv.clientDataDirty = false
	end
end

function Crafter.sv_markStorageDirty( self )
	self.sv.storageDataDirty = true
end

function Crafter.sv_updateStorage( self )
	if self.sv.storageDataDirty then
		self.sv.saved.craftArray = self.sv.craftArray
		self.storage:save( self.sv.saved )
		self.sv.storageDataDirty = false
	end
end

function Crafter.sv_buildPipesAndContainerGraph( self )

	self.sv.pipeGraphs = { output = { containers = {}, pipes = {} }, input = { containers = {}, pipes = {} } }

	local function fnOnContainerWithFilter( vertex, parent, fnFilter, graph )
		local container = {
			shape = vertex.shape,
			distance = vertex.distance,
			shapesOnContainerPath = vertex.shapesOnPath
		}
		if parent.distance == 0 then -- Our parent is the craftbot
			local shapeInCrafterPos = parent.shape:transformPoint( vertex.shape:getWorldPosition() )
			if not fnFilter( shapeInCrafterPos.x ) then
				return false
			end
		end
		table.insert( graph.containers, container )
		return true
	end

	local function fnOnPipeWithFilter( vertex, parent, fnFilter, graph )
		local pipe = {
			shape = vertex.shape,
			state = PipeState.off
		}
		if parent.distance == 0 then -- Our parent is the craftbot
			local shapeInCrafterPos = parent.shape:transformPoint( vertex.shape:getWorldPosition() )
			if not fnFilter( shapeInCrafterPos.x ) then
				return false
			end
		end
		table.insert( graph.pipes, pipe )
		return true
	end

	-- Construct the input graph
	local function fnOnVertex( vertex, parent )
		if isAnyOf( vertex.shape:getShapeUuid(), ContainerUuids ) then -- Is Container
			assert( vertex.shape:getInteractable():getContainer() )
			return fnOnContainerWithFilter( vertex, parent, function( value ) return value <= 0 end, self.sv.pipeGraphs["input"] )
		elseif isAnyOf( vertex.shape:getShapeUuid(), PipeUuids ) then -- Is Pipe
			return fnOnPipeWithFilter( vertex, parent, function( value ) return value <= 0 end, self.sv.pipeGraphs["input"] )
		end
		return true
	end

	ConstructPipedShapeGraph( self.shape, fnOnVertex )

	-- Construct the output graph
	local function fnOnVertex( vertex, parent )
		if isAnyOf( vertex.shape:getShapeUuid(), ContainerUuids ) then -- Is Container
			assert( vertex.shape:getInteractable():getContainer() )
			return fnOnContainerWithFilter( vertex, parent, function( value ) return value > 0 end, self.sv.pipeGraphs["output"] )
		elseif isAnyOf( vertex.shape:getShapeUuid(), PipeUuids ) then -- Is Pipe
			return fnOnPipeWithFilter( vertex, parent, function( value ) return value > 0 end, self.sv.pipeGraphs["output"] )
		end
		return true
	end

	ConstructPipedShapeGraph( self.shape, fnOnVertex )

	table.sort( self.sv.pipeGraphs["input"].containers, function(a, b) return a.distance < b.distance end )
	table.sort( self.sv.pipeGraphs["output"].containers, function(a, b) return a.distance < b.distance end )

	for _, container in ipairs( self.sv.pipeGraphs["input"].containers ) do
		for _, shape in ipairs( container.shapesOnContainerPath ) do
			for _, pipe in ipairs( self.sv.pipeGraphs["input"].pipes ) do
				if pipe.shape:getId() == shape:getId() then
					pipe.state = PipeState.connected
				end
			end
		end
	end


	for _, container in ipairs( self.sv.pipeGraphs["output"].containers ) do
		for _, shape in ipairs( container.shapesOnContainerPath ) do
			for _, pipe in ipairs( self.sv.pipeGraphs["output"].pipes ) do
				if pipe.shape:getId() == shape:getId() then
					pipe.state = PipeState.connected
				end
			end
		end
	end

	self:sv_markClientDataDirty()
end

-- Client Init

function Crafter.cl_init( self )
	local shapeUuid = self.shape:getShapeUuid()
	if self.crafter == nil then
		self.crafter = crafters[tostring( shapeUuid )]
	end
	self.cl = {}
	self.cl.craftArray = {}
	self.cl.uvFrame = 0
	self.cl.animState = nil
	self.cl.animName = nil
	self.cl.animDuration = 1
	self.cl.animTime = 0

	self.cl.currentMainEffect = nil
	self.cl.currentSecondaryEffect = nil
	self.cl.currentTertiaryEffect = nil
	self.cl.currentQuaternaryEffect = nil

	self.cl.mainEffects = {}
	self.cl.secondaryEffects = {}
	self.cl.tertiaryEffects = {}
	self.cl.quaternaryEffects = {}

	-- print( self.crafter.subTitle )
	-- print( "craft_start", self.interactable:getAnimDuration( "craft_start" ) )
	-- if self.interactable:hasAnim( "craft_loop" ) then
	-- 	print( "craft_loop", self.interactable:getAnimDuration( "craft_loop" ) )
	-- else
	-- 	print( "craft_loop01", self.interactable:getAnimDuration( "craft_loop01" ) )
	-- 	print( "craft_loop02", self.interactable:getAnimDuration( "craft_loop02" ) )
	-- 	print( "craft_loop03", self.interactable:getAnimDuration( "craft_loop03" ) )
	-- end
	-- print( "craft_finish", self.interactable:getAnimDuration( "craft_finish" ) )


	if shapeUuid == obj_craftbot_craftbot1 or shapeUuid == obj_craftbot_craftbot2 or shapeUuid == obj_craftbot_craftbot3 or shapeUuid == obj_craftbot_craftbot4 or shapeUuid == obj_craftbot_craftbot5  then
		self.cl.mainEffects["unfold"] = sm.effect.createEffect( "Craftbot - Unpack", self.interactable )
		self.cl.mainEffects["idle"] = sm.effect.createEffect( "Craftbot - Idle", self.interactable )
		self.cl.mainEffects["idlespecial01"] = sm.effect.createEffect( "Craftbot - IdleSpecial01", self.interactable )
		self.cl.mainEffects["idlespecial02"] = sm.effect.createEffect( "Craftbot - IdleSpecial02", self.interactable )
		self.cl.mainEffects["craft_start"] = sm.effect.createEffect( "Craftbot - Start", self.interactable )
		self.cl.mainEffects["craft_loop01"] = sm.effect.createEffect( "Craftbot - Work01", self.interactable )
		self.cl.mainEffects["craft_loop02"] = sm.effect.createEffect( "Craftbot - Work02", self.interactable )
		self.cl.mainEffects["craft_finish"] = sm.effect.createEffect( "Craftbot - Finish", self.interactable )

		self.cl.secondaryEffects["craft_loop01"] = sm.effect.createEffect( "Craftbot - Work", self.interactable )
		self.cl.secondaryEffects["craft_loop02"] = self.cl.secondaryEffects["craft_loop01"]
		self.cl.secondaryEffects["craft_loop03"] = self.cl.secondaryEffects["craft_loop01"]

		self.cl.tertiaryEffects["craft_loop02"] = sm.effect.createEffect( "Craftbot - Work02Torch", self.interactable, "l_arm03_jnt" )

	elseif shapeUuid == obj_craftbot_cookbot then

		self.cl.mainEffects["unfold"] = sm.effect.createEffect( "Cookbot - Unpack", self.interactable )
		self.cl.mainEffects["idle"] = sm.effect.createEffect( "Cookbot - Idle", self.interactable )
		self.cl.mainEffects["idlespecial01"] = sm.effect.createEffect( "Cookbot - IdleSpecial01", self.interactable )
		self.cl.mainEffects["idlespecial02"] = sm.effect.createEffect( "Cookbot - IdleSpecial02", self.interactable )
		self.cl.mainEffects["craft_start"] = sm.effect.createEffect( "Cookbot - Start", self.interactable )
		self.cl.mainEffects["craft_loop01"] = sm.effect.createEffect( "Cookbot - Work01", self.interactable )
		self.cl.mainEffects["craft_loop02"] = sm.effect.createEffect( "Cookbot - Work02", self.interactable )
		self.cl.mainEffects["craft_loop03"] = sm.effect.createEffect( "Cookbot - Work03", self.interactable )
		self.cl.mainEffects["craft_finish"] = sm.effect.createEffect( "Cookbot - Finish", self.interactable )

		self.cl.secondaryEffects["craft_loop01"] = sm.effect.createEffect( "Cookbot - Work", self.interactable )
		self.cl.secondaryEffects["craft_loop02"] = self.cl.secondaryEffects["craft_loop01"]
		self.cl.secondaryEffects["craft_loop03"] = sm.effect.createEffect( "Cookbot - Work03Salt", self.interactable, "shaker_jnt" )

		self.cl.tertiaryEffects["craft_start"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food01_jnt" )
		self.cl.tertiaryEffects["craft_loop01"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food01_jnt" )
		self.cl.tertiaryEffects["craft_loop02"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food01_jnt" )
		self.cl.tertiaryEffects["craft_loop03"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food01_jnt" )
		self.cl.tertiaryEffects["craft_finish"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food01_jnt" )

		self.cl.quaternaryEffects["craft_start"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food02_jnt" )
		self.cl.quaternaryEffects["craft_loop01"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food02_jnt" )
		self.cl.quaternaryEffects["craft_loop02"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food02_jnt" )
		self.cl.quaternaryEffects["craft_loop03"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food02_jnt" )
		self.cl.quaternaryEffects["craft_finish"] = sm.effect.createEffect( "ShapeRenderable", self.interactable, "food02_jnt" )


	elseif shapeUuid == obj_survivalobject_workbench then

		self.cl.mainEffects["craft_loop"] = sm.effect.createEffect( "Workbench - Work01", self.interactable )
		self.cl.mainEffects["craft_finish"] = sm.effect.createEffect( "Workbench - Finish", self.interactable )
		self.cl.mainEffects["idle"] = sm.effect.createEffect( "Workbench - Idle", self.interactable )

	elseif shapeUuid == obj_survivalobject_dispenserbot then

		self.cl.mainEffects["craft_loop"] = sm.effect.createEffect( "Dispenserbot - Work01", self.interactable )
		self.cl.mainEffects["idle"] = sm.effect.createEffect( "Workbench - Idle", self.interactable )

	end

	self:cl_setupUI()

	self.cl.pipeGraphs = { output = { containers = {}, pipes = {} }, input = { containers = {}, pipes = {} } }

	self.cl.pipeEffectPlayer = PipeEffectPlayer()
	self.cl.pipeEffectPlayer:onCreate()
end

function Crafter.cl_setupUI( self )
	self.cl.guiInterface = self.crafter.createGuiFunction()
	
	self.cl.guiInterface:setButtonCallback( "Upgrade", "cl_onUpgrade" )
	self.cl.guiInterface:setGridButtonCallback( "Craft", "cl_onCraft" )
	self.cl.guiInterface:setGridButtonCallback( "Repeat", "cl_onRepeat" )
	self.cl.guiInterface:setGridButtonCallback( "Collect", "cl_onCollect" )

	self:cl_updateRecipeGrid()
end

function Crafter.cl_updateRecipeGrid( self )
	self.cl.guiInterface:clearGrid( "RecipeGrid" )
	for _, recipeSet in ipairs( self.crafter.recipeSets ) do
		print( "Adding", g_craftingRecipes[recipeSet.name].path )
		self.cl.guiInterface:addGridItemsFromFile( "RecipeGrid", g_craftingRecipes[recipeSet.name].path, { locked = recipeSet.locked } )
	end
end

function Crafter.client_onClientDataUpdate( self, data )
	self.cl.craftArray = data.craftArray
	self.cl.pipeGraphs = data.pipeGraphs

	-- Experimental needs testing
	for _, val in ipairs( self.cl.craftArray ) do
		if val.time == -1 and val.startTick then
			local estimate = max( sm.game.getServerTick() - val.startTick, 0 ) -- Estimate how long time has passed since server started crafing and client recieved craft
			val.time = estimate
		end
	end
end

-- Internal util

function Crafter.getParent( self )
	if self.crafter.needsPower then
		return self.interactable:getSingleParent()
	end
	return nil
end

function Crafter.getRecipeByIndex( self, index )

	-- Convert one dimensional index to recipeSet and recipeIndex
	local recipeName = 0
	local recipeIndex = 0
	local offset = 0
	for _, recipeSet in ipairs( self.crafter.recipeSets ) do
		assert( g_craftingRecipes[recipeSet.name].recipesByIndex )
		local recipeCount = #g_craftingRecipes[recipeSet.name].recipesByIndex

		if index <= offset + recipeCount then
			recipeIndex = index - offset
			recipeName = recipeSet.name
			break
		end
		offset = offset + recipeCount
	end
 
	print( recipeIndex )
	local recipe = g_craftingRecipes[recipeName].recipesByIndex[recipeIndex]
	assert(recipe)
	if recipe then
		return recipe, g_craftingRecipes[recipeName].locked
	end

	return nil, nil
end

-- Server

function Crafter.server_onFixedUpdate( self )
	-- If body has changed, refresh the pipe graph
	if self.shape:getBody():hasChanged( sm.game.getCurrentTick() - 1 ) then
		self:sv_buildPipesAndContainerGraph()
	end

	local parent = self:getParent()
	if not self.crafter.needsPower or ( parent and parent.active ) then
		-- Update first in array
		for idx, val in ipairs( self.sv.craftArray ) do
			if val then
				local recipe = val.recipe
				local recipeCraftTime = math.ceil( recipe.craftTime / self.crafter.speed ) + 120 -- 1s windup + 2s winddown

				if val.time < recipeCraftTime then

					-- Begin crafting new item
					if val.time == -1 then
						val.startTick = sm.game.getServerTick()
						self:sv_markClientDataDirty()
					end

					val.time = val.time + 1

					local isSpawner = self.sv.saved and self.sv.saved.spawner

					if isSpawner then
						if val.time + 10 == recipeCraftTime then
							--print( "Open the gates!" )
							self.sv.saved.spawner.active = true
						end
					end

					if val.time >= recipeCraftTime then

						if isSpawner then
							print( "Spawning {"..recipe.itemId.."}" )
							self:sv_spawn( self.sv.saved.spawner )
						end

						local containerObj = FindContainerToCollectTo( self.sv.pipeGraphs["output"].containers, sm.uuid.new( recipe.itemId ), recipe.quantity )
						if containerObj then
							sm.container.beginTransaction()
							sm.container.collect( containerObj.shape:getInteractable():getContainer(), sm.uuid.new( recipe.itemId ), recipe.quantity )
							if recipe.extras then
								print( recipe.extras )
								for _,extra in ipairs( recipe.extras ) do
									sm.container.collect( containerObj.shape:getInteractable():getContainer(), sm.uuid.new( extra.itemId ), extra.quantity )
								end
							end
							if sm.container.endTransaction() then -- Has space

								table.remove( self.sv.craftArray, idx )

								if val.loop and #self.sv.pipeGraphs["input"].containers > 0 then
									self:sv_craft( { recipe = val.recipe, loop = true } )
								end

								self:sv_markStorageDirty()
								self.network:sendToClients( "cl_n_onCollectToChest", { shapesOnContainerPath = containerObj.shapesOnContainerPath, itemId = sm.uuid.new( recipe.itemId ) } )
								-- Pass extra?
							else
								print( "Container full" )
							end
						end

					end

					--self:sv_markClientDataDirty()
					break
				end
			end
		end
	end

	self:sv_sendClientData()
	self:sv_updateStorage()
end

--Client

local UV_OFFLINE = 0
local UV_READY = 1
local UV_FULL = 2
local UV_HEART = 3
local UV_WORKING_START = 4
local UV_WORKING_COUNT = 4
local UV_JAMMED_START = 8
local UV_JAMMED_COUNT = 4

function Crafter.client_onFixedUpdate( self )
	for idx, val in ipairs( self.cl.craftArray ) do
		if val then
			local recipe = val.recipe
			local recipeCraftTime = math.ceil( recipe.craftTime / self.crafter.speed ) + 120-- 1s windup + 2s winddown

			if val.time < recipeCraftTime then
				val.time = val.time + 1

				if val.time >= recipeCraftTime and #self.cl.pipeGraphs.output.containers > 0 then
					table.remove( self.cl.craftArray, idx )
				end

				break
			end
		end
	end
end

function Crafter.client_onUpdate( self, deltaTime )

	local prevAnimState = self.cl.animState

	local craftTimeRemaining = 0

	local parent = self:getParent()
	if not self.crafter.needsPower or ( parent and parent.active ) then
		local guiActive = false
		if self.cl.guiInterface then
			guiActive = self.cl.guiInterface:isActive()
		end
		
		local hasItems = false
		local isCrafting = false

		if guiActive then
			self:cl_drawProcess()
		end

		for idx = 1, self.crafter.slots do
			local val = self.cl.craftArray[idx]
			if val then
				hasItems = true
				local recipe = val.recipe
				local recipeCraftTime = math.ceil( recipe.craftTime / self.crafter.speed ) + 120
				if val.time >= 0 and val.time < recipeCraftTime then -- The one beeing crafted
					isCrafting = true
					craftTimeRemaining = ( recipeCraftTime - val.time ) / 40
				end
			end
		end

		if isCrafting then
			self.cl.animState = "craft"
			self.cl.uvFrame = self.cl.uvFrame + deltaTime * 8
			self.cl.uvFrame = self.cl.uvFrame % UV_WORKING_COUNT
			self.interactable:setUvFrameIndex( math.floor( self.cl.uvFrame ) + UV_WORKING_START )
		elseif hasItems then
			self.cl.animState = "idle"
			self.interactable:setUvFrameIndex( UV_FULL )
		else
			self.cl.animState = "idle"
			self.interactable:setUvFrameIndex( UV_READY )
		end
	else
		self.cl.animState = "offline"
		self.interactable:setUvFrameIndex( UV_OFFLINE )
	end

	self.cl.animTime = self.cl.animTime + deltaTime
	local animDone = false
	if self.cl.animTime > self.cl.animDuration then
		self.cl.animTime = math.fmod( self.cl.animTime, self.cl.animDuration )

		--print( "ANIMATION DONE:", self.cl.animName )
		animDone = true
	end

	local craftbotParameter = 1

	if self.cl.animState ~= prevAnimState then
		--print( "NEW ANIMATION STATE:", self.cl.animState )
	end

	local prevAnimName = self.cl.animName

	if self.cl.animState == "offline" then
		assert( self.crafter.needsPower )
		self.cl.animName = "offline"

	elseif self.cl.animState == "idle" then
		if self.cl.animName == "offline" or self.cl.animName == nil then
			if self.crafter.needsPower then
				self.cl.animName = "turnon"
			else
				self.cl.animName = "unfold"
			end
			animDone = true
		elseif self.cl.animName == "turnon" or self.cl.animName == "unfold" or self.cl.animName == "craft_finish" then
			if animDone then
				self.cl.animName = "idle"
			end
		elseif self.cl.animName == "idle" then
			if animDone then
				local rand = math.random( 1, 5 )
				if rand == 1 then
					self.cl.animName = "idlespecial01"
				elseif rand == 2 then
					self.cl.animName = "idlespecial02"
				else
					self.cl.animName = "idle"
				end
			end
		elseif self.cl.animName == "idlespecial01" or self.cl.animName == "idlespecial02" then
			if animDone then
				self.cl.animName = "idle"
			end
		else
			--assert( self.cl.animName == "craft_finish" )
			if animDone then
				self.cl.animName = "idle"
			end
		end

	elseif self.cl.animState == "craft" then
		if self.cl.animName == "idle" or self.cl.animName == "idlespecial01" or self.cl.animName == "idlespecial02" or self.cl.animName == "turnon" or self.cl.animName == "unfold" or self.cl.animName == nil then
			self.cl.animName = "craft_start"
			animDone = true

		elseif self.cl.animName == "craft_start" then
			if animDone then
				if self.interactable:hasAnim( "craft_loop" ) then
					self.cl.animName = "craft_loop"
				else
					self.cl.animName = "craft_loop01"
				end
			end

		elseif self.cl.animName == "craft_loop" then
			if animDone then
				if craftTimeRemaining <= 2 then
					self.cl.animName = "craft_finish"
				else
					--keep looping
				end
			end

		elseif self.cl.animName == "craft_loop01" or self.cl.animName == "craft_loop02" or self.cl.animName == "craft_loop03" then
			if animDone then
				if craftTimeRemaining <= 2 then
					self.cl.animName = "craft_finish"
				else
					local rand = math.random( 1, 4 )
					if rand == 1 and craftTimeRemaining >= self.interactable:getAnimDuration( "craft_loop02" ) then
						self.cl.animName = "craft_loop02"
						craftbotParameter = 2
					elseif rand == 2 and craftTimeRemaining >= self.interactable:getAnimDuration( "craft_loop03" ) then
						self.cl.animName = "craft_loop03"
						craftbotParameter = 3
					else
						self.cl.animName = "craft_loop01"
						craftbotParameter = 1
					end
				end
			end

		elseif self.cl.animName == "craft_finish" then
			if animDone then
				self.cl.animName = "craft_start"
			end

		end
	end

	if self.cl.animName ~= prevAnimName then
		--print( "NEW ANIMATION:", self.cl.animName )

		if prevAnimName then
			self.interactable:setAnimEnabled( prevAnimName, false )
			self.interactable:setAnimProgress( prevAnimName, 0 )
		end

		self.cl.animDuration = self.interactable:getAnimDuration( self.cl.animName )
		self.cl.animTime = 0

		--print( "DURATION:", self.cl.animDuration )

		self.interactable:setAnimEnabled( self.cl.animName, true )
	end

	if animDone then

		local mainEffect = self.cl.mainEffects[self.cl.animName]
		local secondaryEffect = self.cl.secondaryEffects[self.cl.animName]
		local tertiaryEffect = self.cl.tertiaryEffects[self.cl.animName]
		local quaternaryEffect = self.cl.quaternaryEffects[self.cl.animName]

		if mainEffect ~= self.cl.currentMainEffect then

			if self.cl.currentMainEffect ~= self.cl.mainEffects["craft_finish"] then
				if self.cl.currentMainEffect then
					self.cl.currentMainEffect:stop()
				end
			end
			self.cl.currentMainEffect = mainEffect
		end

		if secondaryEffect ~= self.cl.currentSecondaryEffect then

			if self.cl.currentSecondaryEffect then
				self.cl.currentSecondaryEffect:stop()
			end

			self.cl.currentSecondaryEffect = secondaryEffect
		end

		if tertiaryEffect ~= self.cl.currentTertiaryEffect then

			if self.cl.currentTertiaryEffect then
				self.cl.currentTertiaryEffect:stop()
			end

			self.cl.currentTertiaryEffect = tertiaryEffect
		end

		if quaternaryEffect ~= self.cl.currentQuaternaryEffect then

			if self.cl.currentQuaternaryEffect then
				self.cl.currentQuaternaryEffect:stop()
			end

			self.cl.currentQuaternaryEffect = quaternaryEffect
		end

		if self.cl.currentMainEffect then
			self.cl.currentMainEffect:setParameter( "craftbot", craftbotParameter )

			if not self.cl.currentMainEffect:isPlaying() then
				self.cl.currentMainEffect:start()
			end
		end

		if self.cl.currentSecondaryEffect then
			self.cl.currentSecondaryEffect:setParameter( "craftbot", craftbotParameter )

			if not self.cl.currentSecondaryEffect:isPlaying() then
				self.cl.currentSecondaryEffect:start()
			end
		end

		if self.cl.currentTertiaryEffect then
			self.cl.currentTertiaryEffect:setParameter( "craftbot", craftbotParameter )

			if self.shape:getShapeUuid() == obj_craftbot_cookbot then
				local val = self.cl.craftArray and self.cl.craftArray[1] or nil
				if val then
					local cookbotRenderables = effectRenderables[val.recipe.itemId]
					if cookbotRenderables and cookbotRenderables[1] then
						self.cl.currentTertiaryEffect:setParameter( "uuid", cookbotRenderables[1] )
						self.cl.currentTertiaryEffect:setScale( sm.vec3.new( 0.25, 0.25, 0.25 ) )
					end
				end
			end

			if not self.cl.currentTertiaryEffect:isPlaying() then
				self.cl.currentTertiaryEffect:start()
			end
		end

		if self.cl.currentQuaternaryEffect then
			self.cl.currentQuaternaryEffect:setParameter( "craftbot", craftbotParameter )

			if self.shape:getShapeUuid() == obj_craftbot_cookbot then
				local val = self.cl.craftArray and self.cl.craftArray[1] or nil
				if val then
					local cookbotRenderables = effectRenderables[val.recipe.itemId]
					if cookbotRenderables and cookbotRenderables[2] then
						self.cl.currentQuaternaryEffect:setParameter( "uuid", cookbotRenderables[2] )
						self.cl.currentQuaternaryEffect:setScale( sm.vec3.new( 0.25, 0.25, 0.25 ) )
					end
				end
			end

			if not self.cl.currentQuaternaryEffect:isPlaying() then
				self.cl.currentQuaternaryEffect:start()
			end
		end
	end
	assert(self.cl.animName)
	self.interactable:setAnimProgress( self.cl.animName, self.cl.animTime / self.cl.animDuration )

	-- Pipe visualization

	if self.cl.pipeGraphs.input then
		LightUpPipes( self.cl.pipeGraphs.input.pipes )
	end

	if self.cl.pipeGraphs.output then
		LightUpPipes( self.cl.pipeGraphs.output.pipes )
	end

	self.cl.pipeEffectPlayer:update( deltaTime )
end

function Crafter.cl_disableAllAnimations( self )
	if self.interactable:hasAnim( "turnon" ) then
		self.interactable:setAnimEnabled( "turnon", false )
	else
		self.interactable:setAnimEnabled( "unfold", false )
	end
	self.interactable:setAnimEnabled( "idle", false )
	self.interactable:setAnimEnabled( "idlespecial01", false )
	self.interactable:setAnimEnabled( "idlespecial02", false )
	self.interactable:setAnimEnabled( "craft_start", false )
	if self.interactable:hasAnim( "craft_loop" ) then
		self.interactable:setAnimEnabled( "craft_loop", false )
	else
		self.interactable:setAnimEnabled( "craft_loop01", false )
		self.interactable:setAnimEnabled( "craft_loop02", false )
		self.interactable:setAnimEnabled( "craft_loop03", false )
	end
	self.interactable:setAnimEnabled( "craft_finish", false )
	self.interactable:setAnimEnabled( "aimbend_updown", false )
	self.interactable:setAnimEnabled( "aimbend_leftright", false )
	self.interactable:setAnimEnabled( "offline", false )
end

function Crafter.client_canInteract( self )
	local parent = self:getParent()
	if not self.crafter.needsPower or ( parent and parent.active ) then
		sm.gui.setCenterIcon( "Use" )
		local keyBindingText =  sm.gui.getKeyBinding( "Use", true )
		sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_USE}" )
	else
		sm.gui.setCenterIcon( "Hit" )
		sm.gui.setInteractionText( "#{INFO_REQUIRES_POWER}" )
		return false
	end
	return true
end

function Crafter.cl_setGuiContainers( self )
	if isAnyOf( self.shape:getShapeUuid(), { obj_craftbot_craftbot1, obj_craftbot_craftbot2, obj_craftbot_craftbot3, obj_craftbot_craftbot4, obj_craftbot_craftbot5 } ) then
		local containers = {}
		if #self.cl.pipeGraphs.input.containers > 0 then
			for _, val in ipairs( self.cl.pipeGraphs.input.containers ) do
				table.insert( containers, val.shape:getInteractable():getContainer( 0 ) )
			end
		else
			table.insert( containers, sm.localPlayer.getPlayer():getInventory() )
		end
		self.cl.guiInterface:setContainers( "", containers )
	else
		self.cl.guiInterface:setContainer( "", sm.localPlayer.getPlayer():getInventory() )
	end
end

function Crafter.client_onInteract( self, character, state )
	if state == true then
		local parent = self:getParent()
		if not self.crafter.needsPower or ( parent and parent.active ) then

			self:cl_setGuiContainers()

			if self.interactable.shape.uuid ~= obj_survivalobject_dispenserbot then
				for idx = 1, self.crafter.slots do
					local val = self.cl.craftArray[idx]
					if val then
						local recipe = val.recipe
						local recipeCraftTime = math.ceil( recipe.craftTime / self.crafter.speed ) + 120

						local gridItem = {}
						gridItem.itemId = recipe.itemId
						gridItem.craftTime = recipeCraftTime
						gridItem.remainingTicks = recipeCraftTime - clamp( val.time, 0, recipeCraftTime )
						gridItem.locked = false
						gridItem.repeating = val.loop
						self.cl.guiInterface:setGridItem( "ProcessGrid", idx - 1, gridItem )

					else
						local gridItem = {}
						gridItem.itemId = "00000000-0000-0000-0000-000000000000"
						gridItem.craftTime = 0
						gridItem.remainingTicks = 0
						gridItem.locked = false
						gridItem.repeating = false
						self.cl.guiInterface:setGridItem( "ProcessGrid", idx - 1, gridItem )
					end
				end

				if self.crafter.slots < 8 then
					local shapeUuid = self.shape:getShapeUuid()

					local gridItem = {}
					gridItem.locked = true

					if shapeUuid == obj_craftbot_craftbot1 then

						gridItem.unlockLevel = 2

						self.cl.guiInterface:setGridItem( "ProcessGrid", 2, gridItem )
						self.cl.guiInterface:setGridItem( "ProcessGrid", 3, gridItem )

						gridItem.unlockLevel = 3

						self.cl.guiInterface:setGridItem( "ProcessGrid", 4, gridItem )
						self.cl.guiInterface:setGridItem( "ProcessGrid", 5, gridItem )

						gridItem.unlockLevel = 4

						self.cl.guiInterface:setGridItem( "ProcessGrid", 6, gridItem )
						self.cl.guiInterface:setGridItem( "ProcessGrid", 7, gridItem )

					elseif shapeUuid == obj_craftbot_craftbot2 then

						gridItem.unlockLevel = 3

						self.cl.guiInterface:setGridItem( "ProcessGrid", 4, gridItem )
						self.cl.guiInterface:setGridItem( "ProcessGrid", 5, gridItem )

						gridItem.unlockLevel = 4

						self.cl.guiInterface:setGridItem( "ProcessGrid", 6, gridItem )
						self.cl.guiInterface:setGridItem( "ProcessGrid", 7, gridItem )

					elseif shapeUuid == obj_craftbot_craftbot3 then
						
						gridItem.unlockLevel = 4

						self.cl.guiInterface:setGridItem( "ProcessGrid", 6, gridItem )
						self.cl.guiInterface:setGridItem( "ProcessGrid", 7, gridItem )

					end
				end
			end

			self.cl.guiInterface:setText( "SubTitle", self.crafter.subTitle )
			self.cl.guiInterface:open()

			local pipeConnection = #self.cl.pipeGraphs.output.containers > 0

			self.cl.guiInterface:setVisible( "PipeConnection", pipeConnection )

			if sm.game.getEnableUpgrade() and self.crafter.upgradeCost then
				local upgradeData = {}
				upgradeData.cost = self.crafter.upgradeCost
				upgradeData.available = sm.container.totalQuantity( sm.localPlayer.getPlayer():getInventory(), obj_consumable_component )
				self.cl.guiInterface:setData( "Upgrade", upgradeData )

				if self.crafter.upgrade then
					local nextLevel = crafters[ self.crafter.upgrade ]
					local upgradeInfo = {}
					local nextLevelSlots = nextLevel.slots - self.crafter.slots
					if nextLevelSlots > 0 then
						upgradeInfo["Slots"] = nextLevelSlots
					end
					local nextLevelSpeed = nextLevel.speed - self.crafter.speed
					if nextLevelSpeed > 0 then
						upgradeInfo["Speed"] = nextLevelSpeed
					end
					self.cl.guiInterface:setData( "UpgradeInfo", upgradeInfo )
				else
					self.cl.guiInterface:setData( "UpgradeInfo", nil )
				end
			else
				self.cl.guiInterface:setVisible( "Upgrade", false )
			end
		end
	end
end

function Crafter.cl_drawProcess( self )

	for idx = 1, self.crafter.slots do
		local val = self.cl.craftArray[idx]
		if val then
			hasItems = true

			local recipe = val.recipe
			local recipeCraftTime = math.ceil( recipe.craftTime / self.crafter.speed ) + 120
			
			if self.interactable.shape.uuid ~= obj_survivalobject_dispenserbot then
				local gridItem = {}
				gridItem.itemId = recipe.itemId
				gridItem.craftTime = recipeCraftTime
				gridItem.remainingTicks = recipeCraftTime - clamp( val.time, 0, recipeCraftTime )
				gridItem.locked = false
				gridItem.repeating = val.loop
				self.cl.guiInterface:setGridItem( "ProcessGrid", idx - 1, gridItem )
			end
		else
			if self.interactable.shape.uuid ~= obj_survivalobject_dispenserbot then
				local gridItem = {}
				gridItem.itemId = "00000000-0000-0000-0000-000000000000"
				gridItem.craftTime = 0
				gridItem.remainingTicks = 0
				gridItem.locked = false
				gridItem.repeating = false
				self.cl.guiInterface:setGridItem( "ProcessGrid", idx - 1, gridItem )
			end
		end
	end
end

-- Gui callbacks

function Crafter.cl_onCraft( self, buttonName, index, data )
	print( "ONCRAFT", index )
	local _, locked = self:getRecipeByIndex( index + 1 )
	if locked then
		print( "Recipe is locked" )
	else
		self.network:sendToServer( "sv_n_craft", { index = index + 1 } )
	end
end

function Crafter.sv_n_craft( self, params, player )
	local recipe, locked = self:getRecipeByIndex( params.index )
	if locked then
		print( "Recipe is locked" )
	else
		self:sv_craft( { recipe = recipe }, player )
	end
end

function Crafter.sv_craft( self, params, player )
	if #self.sv.craftArray < self.crafter.slots then
		local recipe = params.recipe

		-- Charge container
		sm.container.beginTransaction()

		local containerArray = {}
		local hasInputContainers = #self.sv.pipeGraphs.input.containers > 0

		for _, ingredient in ipairs( recipe.ingredientList ) do
			if hasInputContainers then

				local consumeCount = ingredient.quantity

				for _, container in ipairs( self.sv.pipeGraphs.input.containers ) do
					if consumeCount > 0 then
						consumeCount = consumeCount - sm.container.spend( container.shape:getInteractable():getContainer(), ingredient.itemId, consumeCount, false )
						table.insert( containerArray, { shapesOnContainerPath = container.shapesOnContainerPath, itemId = ingredient.itemId } )
					else
						break
					end
				end

				if consumeCount > 0 then
					print("Could not consume enough of ", ingredient.itemId, " Needed ", consumeCount, " more")
					sm.container.abortTransaction()
					return
				end
			else
				if player and sm.game.getLimitedInventory() then
					sm.container.spend( player:getInventory(), ingredient.itemId, ingredient.quantity )
				end
			end
		end


		if sm.container.endTransaction() then -- Can afford
			print( "Crafting:", recipe.itemId, "x"..recipe.quantity )

			table.insert( self.sv.craftArray, { recipe = recipe, time = -1, loop = params.loop or false } )

			self:sv_markStorageDirty()
			self:sv_markClientDataDirty()

			if #containerArray > 0 then
				self.network:sendToClients( "cl_n_onCraftFromChest", containerArray )
			end
		else
			print( "Can't afford to craft" )
		end
	else
		print( "Craft queue full" )
	end
end

function Crafter.cl_n_onCraftFromChest( self, params )
	for _, tbl in ipairs( params ) do
		local shapeList = {}
		for _, shape in reverse_ipairs( tbl.shapesOnContainerPath ) do
			table.insert( shapeList, shape )
		end

		local endNode = PipeEffectNode()
		endNode.shape = self.shape
		endNode.point = sm.vec3.new( -5.0, -2.5, 0.0 ) * sm.construction.constants.subdivideRatio
		table.insert( shapeList, endNode )

		self.cl.pipeEffectPlayer:pushShapeEffectTask( shapeList, tbl.itemId )
	end
end

function Crafter.cl_n_onCollectToChest( self, params )

	local startNode = PipeEffectNode()
	startNode.shape = self.shape
	startNode.point = sm.vec3.new( 5.0, -2.5, 0.0 ) * sm.construction.constants.subdivideRatio
	table.insert( params.shapesOnContainerPath, 1, startNode)

	self.cl.pipeEffectPlayer:pushShapeEffectTask( params.shapesOnContainerPath, params.itemId )
end

function Crafter.cl_onRepeat( self, buttonName, index, gridItem )
	print( "Repeat pressed", index )
	self.network:sendToServer( "sv_n_repeat", { slot = index } )
end

function Crafter.cl_onCollect( self, buttonName, index, gridItem )
	self.network:sendToServer( "sv_n_collect", { slot = index } )
end

function Crafter.sv_n_repeat( self, params )
	local val = self.sv.craftArray[params.slot + 1]
	if val then
		val.loop = not val.loop
		self:sv_markStorageDirty()
		self:sv_markClientDataDirty()
	end
end

function Crafter.sv_n_collect( self, params, player )
	local val = self.sv.craftArray[params.slot + 1]
	if val then
		local recipe = val.recipe
		if val.time >= math.ceil( recipe.craftTime / self.crafter.speed ) then
			print( "Collecting "..recipe.quantity.."x {"..recipe.itemId.."} to container", player:getInventory() )

			sm.container.beginTransaction()
			sm.container.collect( player:getInventory(), sm.uuid.new( recipe.itemId ), recipe.quantity )
			if recipe.extras then
				print( recipe.extras )
				for _,extra in ipairs( recipe.extras ) do
					sm.container.collect( player:getInventory(), sm.uuid.new( extra.itemId ), extra.quantity )
				end
			end
			if sm.container.endTransaction() then -- Has space
				table.remove( self.sv.craftArray, params.slot + 1 )
				self:sv_markStorageDirty()
				self:sv_markClientDataDirty()
			else
				self.network:sendToClient( player, "cl_n_onMessage", "#{INFO_INVENTORY_FULL}" )
			end
		else
			print( "Not done" )
		end
	end
end

function Crafter.sv_spawn( self, spawner )
	print( spawner )

	local val = self.sv.craftArray[1]
	local recipe = val.recipe
	assert( recipe.quantity == 1 )

	local uid = sm.uuid.new( recipe.itemId )
	local rotation = sm.quat.angleAxis( math.pi*0.5, sm.vec3.new( 1, 0, 0 ) )
	local size = rotation * sm.item.getShapeSize( uid )
	local spawnPoint = self.sv.saved.spawner.shape:getWorldPosition() + sm.vec3.new( 0, 0, -1.5 ) - size * sm.vec3.new( 0.125, 0.125, 0.25 )
	local shapeLocalRotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), sm.vec3.new( 0, 1, 0 ) )
	local body = sm.body.createBody( spawnPoint, rotation * shapeLocalRotation, true )
	local shape = body:createPart( uid, sm.vec3.new( 0, 0, 0), sm.vec3.new( 0, -1, 0 ), sm.vec3.new( 1, 0, 0 ), true )

	table.remove( self.sv.craftArray, 1 )
	self:sv_markStorageDirty()
	self:sv_markClientDataDirty()
end

function Crafter.cl_onUpgrade( self, buttonName )
	self.network:sendToServer( "sv_n_upgrade" )
end

function Crafter.sv_n_upgrade( self, params, player )
	print( "Upgrading" )
	local function fnUpgrade()
		local upgrade = self.crafter.upgrade
		self.crafter = crafters[upgrade]
		self.network:sendToClients( "cl_n_upgrade", upgrade )
		self.shape:replaceShape( sm.uuid.new( upgrade ) )
	end

	if sm.game.getEnableUpgrade() then
		if self.crafter.upgrade then
			if sm.container.beginTransaction() then
				sm.container.spend( player:getInventory(), obj_consumable_component, self.crafter.upgradeCost, true )
				if sm.container.endTransaction() then
					fnUpgrade()
				end
			end
		else
			print( "Can't be upgraded" )
		end
	end
end

function Crafter.cl_n_upgrade( self, upgrade )
	print( "Client Upgrading" )
	if not sm.isHost then
		self.crafter = crafters[upgrade]
	end
	self:cl_updateRecipeGrid()

	if self.cl.guiInterface:isActive() then

		if sm.game.getEnableUpgrade() and self.crafter.upgradeCost then
			local upgradeData = {}
			upgradeData.cost = self.crafter.upgradeCost
			upgradeData.available = sm.container.totalQuantity( sm.localPlayer.getPlayer():getInventory(), obj_consumable_component )
			self.cl.guiInterface:setData( "Upgrade", upgradeData )
		else
			self.cl.guiInterface:setVisible( "Upgrade", false )
		end

		self.cl.guiInterface:setText( "SubTitle", self.crafter.subTitle )

		if self.crafter.upgrade then
			local nextLevel = crafters[ self.crafter.upgrade ]
			local upgradeInfo = {}
			local nextLevelSlots = nextLevel.slots - self.crafter.slots
			if nextLevelSlots > 0 then
				upgradeInfo["Slots"] = nextLevelSlots
			end
			local nextLevelSpeed = nextLevel.speed - self.crafter.speed
			if nextLevelSpeed > 0 then
				upgradeInfo["Speed"] = nextLevelSpeed
			end
			self.cl.guiInterface:setData( "UpgradeInfo", upgradeInfo )
		else
			self.cl.guiInterface:setData( "UpgradeInfo", nil )
		end
	end
end

function Crafter.cl_n_onMessage( self, msg )
	sm.gui.displayAlertText( msg )
end

Workbench = class( Crafter )
Workbench.maxParentCount = 1
Workbench.connectionInput = sm.interactable.connectionType.logic

Dispenser = class( Crafter )
Dispenser.maxParentCount = 1
Dispenser.connectionInput = sm.interactable.connectionType.logic

Craftbot = class( Crafter )

