function LoadCraftingRecipes( recipePaths )
	-- Preload all crafting recipes
	if not g_craftingRecipes then
		g_craftingRecipes = {}
		for name, path in pairs( recipePaths ) do
			local json = sm.json.open( path )
			local recipes = {}
			local recipesByIndex = {}

			local isRecipeValid = function( recipe )
				local recipeItemUuid = sm.uuid.new( recipe.itemId )
				if not sm.shape.uuidExists( recipeItemUuid ) then
					if not sm.tool.uuidExists( recipeItemUuid ) then
						return false
					end
				end

				recipe.craftTime = math.ceil( recipe.craftTime * 40 ) -- Seconds to ticks
				for _,ingredient in ipairs( recipe.ingredientList ) do
					ingredient.itemId = sm.uuid.new( ingredient.itemId ) -- Prepare uuid			
					if not sm.shape.uuidExists( ingredient.itemId ) then
						if not sm.tool.uuidExists( ingredient.itemId ) then
							return false
						end
					end
				end
				return true
			end

			for _, recipe in ipairs( json ) do
				
				if isRecipeValid( recipe ) then	
					recipes[recipe.itemId] = recipe
					table.insert( recipesByIndex, recipe )
				end

			end
			-- NOTE(daniel): Wardrobe is using 'recipes' by uuid, crafter is using 'recipesByIndex'
			g_craftingRecipes[name] = { path = path, recipes = recipes, recipesByIndex = recipesByIndex }
		end
	end

	-- Preload refinery recipes
	if not g_refineryRecipes then
		g_refineryRecipes = sm.json.open( "$CONTENT_DATA/CraftingRecipes/refinery.json" )
		for _,recipe in pairs( g_refineryRecipes ) do
			recipe.itemId = sm.uuid.new( recipe.itemId ) -- Prepare uuid
		end
	end
end