dofile "$SURVIVAL_DATA/Scripts/game/interactables/Crafter.lua"

local nameToIdx = {}
nameToIdx["Pizza"]   = 1
nameToIdx["Veggie"]  = 2
nameToIdx["Revival"] = 3

Cookbot = class( Crafter )

function Cookbot.cl_setupUI( self )
end

function Cookbot.client_onInteract( self, character, state )
	if state ~= true then
		return
	end

	self.cl.guiInterface = sm.gui.createGuiFromLayout(
		"$GAME_DATA/Gui/Layouts/Interactable/Interactable_CookBot.layout" )

	self.cl.guiInterface:setButtonCallback( "Pizza", "cl_onFoodButtonClicked" )
	self.cl.guiInterface:setButtonCallback( "Veggie", "cl_onFoodButtonClicked" )
	self.cl.guiInterface:setButtonCallback( "Revival", "cl_onFoodButtonClicked" )
	self.cl.guiInterface:setButtonCallback( "Craft", "cl_onCraft" )
	self.cl.guiInterface:setOnCloseCallback( "cl_onClose" )

	local matGrid = {
		type = "materialGrid",
		layout = "$GAME_DATA/Gui/Layouts/Interactable/Interactable_CraftBot_IngredientItem.layout",
		itemWidth = 44,
		itemHeight = 60,
		itemCount = 4,
	}

	self.cl.guiInterface:createGridFromJson( "MaterialGrid", matGrid )
	self.cl.guiInterface:setText( "SubTitle", self.crafter.subTitle )
	self:cl_createProcessGrid()
	self.cl.guiInterface:open()

	if self.cl.selectedButton then
		self:cl_onFoodButtonClicked( self.cl.selectedButton )
	else
		self:cl_onFoodButtonClicked( "Pizza" )
	end
end

function Cookbot.cl_onFoodButtonClicked( self, buttonName )
	if self.cl.selectedButton then
		self.cl.guiInterface:setButtonState( self.cl.selectedButton, false )
	end
	self.cl.selectedButton = buttonName
	self.cl.guiInterface:setContainer( "", sm.localPlayer.getPlayer():getInventory())

	local recipe = self:getRecipeByIndex( nameToIdx[buttonName] )
	local recipeUuid = sm.uuid.new( recipe["itemId"] )

	self.cl.guiInterface:setText( "ItemDescription",
	sm.shape.getShapeDescription( recipeUuid ) )

	self.cl.guiInterface:setText( "ItemName",
	sm.shape.getShapeTitle( recipeUuid ) )

	self.cl.guiInterface:setMeshPreview( "Preview", recipeUuid )

	local craftTime = math.ceil( recipe.craftTime / self.crafter.speed ) + 120
	self.cl.guiInterface:setText( "Time", sm.gui.ticksToTimeString( craftTime ) )

	for idx, ingredient in ipairs( recipe["ingredientList"] ) do
		local griditem  = {
			itemId = tostring( ingredient.itemId ),
			quantity = ingredient.quantity,
		}

		self.cl.guiInterface:setGridItem( "MaterialGrid", idx - 1, griditem );
	end

	self.cl.selectedRecipe = recipe;
	self.cl.guiInterface:setButtonState( buttonName, true )
end

function Cookbot.cl_onCraft( self, buttonName )
	if self.cl.selectedButton == nil then
		return
	end
	self.network:sendToServer( "sv_n_craft", { index = nameToIdx[self.cl.selectedButton] } )
end

function Cookbot.cl_createProcessGrid( self )
	local procGrid = {
		type = "processGrid",
		layout = "$GAME_DATA/Gui/Layouts/Interactable/Interactable_CraftBot_ProcessItem.layout",
		itemWidth = 98,
		itemHeight = 116,
		itemCount = self.crafter.slots,
	}
	self.cl.guiInterface:createGridFromJson( "ProcessGrid", procGrid )
	self.cl.guiInterface:setGridButtonCallback( "Collect", "cl_onCollect" )
	self:cl_drawProcess()
end


function Cookbot.cl_drawProcess( self )
	for idx = 1, self.crafter.slots do
		local val = self.cl.craftArray[idx]
		if val then
			local recipe = val.recipe
			local recipeCraftTime = math.ceil( recipe.craftTime / self.crafter.speed ) + 120
			local gridItem = {
				itemId = tostring( recipe.itemId ),
				craftTime = recipeCraftTime,
				remainingTicks = recipeCraftTime - clamp( val.time, 0, recipeCraftTime ),
				locked = false,
				repeating = val.loop,
			}

			self.cl.guiInterface:setGridItem( "ProcessGrid", idx - 1, gridItem )
			self.cl.guiInterface:setButtonState( "ProcessBackground", gridItem.remainingTicks == 0 )

			if gridItem.remainingTicks == 0 then
				self.cl.guiInterface:playGridEffect( "ProcessGrid", idx - 1, "Gui - CraftingDone", false )
			end
		else
			local gridItem = {
				itemId = "00000000-0000-0000-0000-000000000000",
				craftTime = 0,
				remainingTicks = 0,
				locked = false,
				repeating = false,
			}
			self.cl.guiInterface:setGridItem( "ProcessGrid", idx - 1, gridItem )
			if idx == 1 then
				self.cl.guiInterface:setButtonState( "ProcessBackground", false )
			end
		end
	end
end

function Cookbot.cl_onCollect( self, name, index )
	self.cl.guiInterface:playGridEffect( "ProcessGrid", index, "Gui - CraftingDoneCollectButton", true )
	self.network:sendToServer( "sv_n_collect", { slot = index } )
end

function Cookbot.cl_onClose( self )
	if self.cl.guiInterface then
		self.cl.guiInterface:destroy()
		self.cl.guiInterface = nil
	end
end