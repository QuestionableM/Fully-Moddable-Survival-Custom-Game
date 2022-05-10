MergeCreationFlag = 0x2

local function pickRandomElementFromTable( tbl )
	local result

	-- Sum the total
	local total = 0
	for _, v in ipairs( tbl ) do
		local value = 1
		if type( v ) == "table" and v[2] then
			value = v[2]
		end
		total = total + value	
	end

	-- Random 
	local r =  math.random( 1, total )

	-- Pick the value
	local threshold = 0
	for _, v in ipairs( tbl ) do
		local value = 1
		if type( v ) == "table" and v[2] then
			value = v[2]
		end

		if r <= value + threshold then
			if type( v ) == "table" then
				result = v[1]
			else
				result = v
			end
			break
		end
		threshold = threshold + value
	end

	return result
end

function RandomizePrefab( prefab, randomTable )
	if randomTable then
		local key = string.sub( prefab.name, 29, #prefab.name - 10 )
		local tbl = randomTable[key]
		if tbl then
			prefab.name = pickRandomElementFromTable( tbl )
		end
	end
end

function RandomizeCreation( creation, randomTable )
	if randomTable then
		local key = string.sub( creation.pathOrJson, 32, #creation.pathOrJson - 13 )
		local tbl = randomTable[key]
		if tbl then
			creation.pathOrJson = pickRandomElementFromTable( tbl )
		end
	end
end
