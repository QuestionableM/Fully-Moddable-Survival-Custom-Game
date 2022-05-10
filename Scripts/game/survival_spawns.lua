-- Constants

-- Multiplies with the number of nodes in a cell
local SpawnMultiplier = {
	["HAYBOT"] = 0.33,
	["TOTEBOT_GREEN"] = 0.33,
	["TAPEBOT"] = 0.33,
	["FARMBOT"] = 0.33,
	["WOC"] = 0.33,
	["GLOWGORP"] = 0.2,



}

-- Random spawn chance for non poi cells
local RandomSpawnChance = {
	["HAYBOT"] = 10,
	["TOTEBOT_GREEN"] = 10,
	["TAPEBOT"] = 10,
	["FARMBOT"] = 4,
	["WOC"] = 10,
	["GLOWGORP"] = 2,



}

-- Ticks between unit respawns
local UnitTicksBetweenRespawns = {
	["HAYBOT"] = DaysInTicks( 5 ),
	["TOTEBOT_GREEN"] = DaysInTicks( 5 ),
	["TAPEBOT"] = DaysInTicks( 5 ),
	["FARMBOT"] = DaysInTicks( 5 ),
	["WOC"] = DaysInTicks( 5 ),
	["GLOWGORP"] = DaysInTicks( 5 ),



}

-- true = on poi, false = not on poi
local StartareaLootcrateSpawnChance = { [true] = 40, [false] = 10 }
local LootcrateSpawnChance = { [true] = 35, [false] = 10 }
local LootcrateEpicChance = { [true] = 33, [false] = 5 }
local LootcrateUpgradeChance = { [true] = 0, [false] = 2 }

-- Seed

local function SeedSpawnFunction( cell, nodes )
	local SeedSpawnUuids = {
		obj_seed_carrot,
		obj_seed_potato,
		obj_seed_redbeet,
		obj_seed_tomato
	}
	for _, node in ipairs( nodes ) do
		local uid = SeedSpawnUuids[math.random( 1, #SeedSpawnUuids )] -- Randomize a seed
		local part = sm.shape.createPart( uid, node.position, node.rotation, false, false ) -- static, ignore if collides
		part.stackedAmount = randomStackAmountAvg5()
	end

end

-- Gas

local function GasSpawnFunction( cell, nodes )
	for _, node in ipairs( nodes ) do
		local uid = obj_consumable_gas
		local part = sm.shape.createPart( uid, node.position, node.rotation, false, false ) -- static, ignore if collides
		part.stackedAmount = randomStackAmountAvg5()
	end
end

-- Units

function CreateUnit( tag, node, respawning )

	local toYaw = function( rotation )
		local spawnDirection = rotation * sm.vec3.new( 0, 0, 1 )
		return math.atan2( spawnDirection.y, spawnDirection.x ) - math.pi / 2
	end
	local params = { tetherPoint = node.position }
	if node.params then
		append( params, node.params )
	end
	if respawning then
		params.deathTick = sm.game.getCurrentTick() + UnitTicksBetweenRespawns[tag] + 400
	end

	local unit
	if tag == "HAYBOT" then
		unit = sm.unit.createUnit( unit_haybot, node.position, toYaw( node.rotation ), params )
	elseif tag == "TOTEBOT_GREEN" then
		unit = sm.unit.createUnit( unit_totebot_green, node.position, toYaw( node.rotation ), params )
	elseif tag == "FARMBOT" then
		unit = sm.unit.createUnit( unit_farmbot, node.position, toYaw( node.rotation ), params )
	elseif tag == "TAPEBOT" then
		unit = sm.unit.createUnit( g_tapebots[math.random( 1, #g_tapebots )], node.position, toYaw( node.rotation ), params )
	elseif tag == "WOC" then
		unit = sm.unit.createUnit( unit_woc, node.position, toYaw( node.rotation ), params )
	elseif tag == "GLOWGORP" then
		unit = sm.unit.createUnit( unit_worm, node.position, toYaw( node.rotation ), params )




	else
		assert( false, "No unit constructor for tag "..tag )
	end
	assert(unit)
	return unit
end

local function SpawnUnits( cell, nodes, spawnMax, storage, tag )

	shuffle( nodes )
	local spawnCount = 0

	local respawning = not cell.isStartArea
	for _, node in ipairs( nodes ) do
		--print( node )
		if node.params and node.params.guaranteed then
			print( "Spawning guaranteed", tag )
			table.insert( storage.units, CreateUnit( tag, node, respawning ) )
			spawnCount = spawnCount + 1
		elseif cell.isPoi then
			if spawnCount < spawnMax then
				print( "Spawning", tag, "on poi" )
				table.insert( storage.units, CreateUnit( tag, node, respawning ) )
				spawnCount = spawnCount + 1
			end
		elseif math.random( 100 ) <= RandomSpawnChance[tag] then
			print( "Spawning random", tag )
			table.insert( storage.units, CreateUnit( tag, node, respawning ) )
			spawnCount = spawnCount + 1
		end
	end

	return spawnCount
end

local function UnitSpawnFunction( cell, nodes, tag ) 
	local storage = { units = {} }

	-- Spawn units on nodes
	local spawnCount = SpawnUnits( cell, nodes, #nodes * SpawnMultiplier[tag], storage, tag )
	assert( #storage.units == spawnCount )

	return storage
end

-- This respawn function remove all old units from this cell and creates new ones
local function UnitRespawnAllFunction( cell, nodes, storage, tag ) 

	-- Remove old units
	for _, unit in ipairs( storage.units ) do
		if sm.exists( unit ) then
			unit:destroy()
		end
	end
	storage.units = {}

	-- Respawn units on nodes
	SpawnUnits( cell, nodes, #nodes * SpawnMultiplier[tag], storage, tag )

	return storage
end

-- This respawn function only respawns units that no longer exists
local function UnitRespawnFunction( cell, nodes, storage, tag ) 

	-- Count how many units are alive
	local aliveCount = 0
	for idx, unit in reverse_ipairs( storage.units ) do
		if sm.exists( unit ) then
			aliveCount = aliveCount + 1
		else
			table.remove( storage.units, idx )
		end
	end

	-- Respawn units on nodes
	SpawnUnits( cell, nodes, #nodes * SpawnMultiplier[tag] - aliveCount, storage, tag )

	return storage
end

-- Lootcrate

local function SpawnLootCrate( cell, nodes, spawnMax, storage, tag )
	local spawnCount = 0

	shuffle( nodes )
	for _, node in ipairs( nodes ) do

		if spawnCount >= spawnMax then
			return spawnCount
		end

		local guaranteed = node.params and node.params.guaranteed
		if cell.isStartArea then
			if guaranteed or math.random( 100 ) <= StartareaLootcrateSpawnChance[cell.isPoi] then
				local harvestable = sm.harvestable.createHarvestable( hvs_lootcrate, node.position, node.rotation )
				harvestable:setParams( { lootTable = "loot_crate_startarea" } )
				print( "Spawned STARTAREA LOOTCRATE", ( guaranteed and "(guaranteed)" or "" ) )
				table.insert( storage.harvestables, harvestable )
				spawnCount = spawnCount + 1
			else
				print( "Skipped STARTAREA LOOTCRATE node" )
			end
		else
			if guaranteed or math.random( 100 ) <= LootcrateSpawnChance[cell.isPoi] then
				if math.random( 100 ) <= LootcrateUpgradeChance[cell.isPoi] then
					local harvestable = sm.harvestable.createHarvestable( hvs_lootcrateepic, node.position, node.rotation )
					harvestable:setParams( { lootTable = cell.isWarehouse and "loot_crate_epic_warehouse" or "loot_crate_epic" } )
					print( "Spawned EPIC LOOTCRATE, UPGRADE", ( guaranteed and "(guaranteed)" or "" ) )
					table.insert( storage.harvestables, harvestable )
					spawnCount = spawnCount + 1
				else
					local harvestable = sm.harvestable.createHarvestable( hvs_lootcrate, node.position, node.rotation )
					harvestable:setParams( { lootTable = cell.isWarehouse and "loot_crate_standard_warehouse" or "loot_crate_standard" } )
					print( "Spawned LOOTCRATE", ( guaranteed and "(guaranteed)" or "" ) )
					table.insert( storage.harvestables, harvestable )
					spawnCount = spawnCount + 1
				end
			else
				print( "Skipped LOOTCRATE node" )
			end
		end
	end
	return spawnCount
end

local function LootSpawnFunction( cell, nodes, tag )
	local storage = { harvestables = {} }
	local spawnCount = SpawnLootCrate( cell, nodes, #nodes, storage, tag )
	assert( spawnCount == #storage.harvestables )
	return storage
end

local function LootRespawnFunction( cell, nodes, storage, tag  )

	-- Remove old harvestables
	for _, hvs in ipairs( storage.harvestables ) do
		if sm.exists( hvs ) then
			hvs:destroy()
		end
	end
	storage.harvestables = {}

	 -- Respawn loot on nodes
	 SpawnLootCrate( cell, nodes, #nodes, storage, tag )
	return storage
end

-- Epic lootcrate

local function SpawnEpicLootCrate( cell, nodes, spawnMax, storage, tag )
	local spawnCount = 0

	shuffle( nodes )
	for _, node in ipairs( nodes ) do

		if spawnCount >= spawnMax then
			return spawnCount
		end

		local guaranteed = node.params and node.params.guaranteed
		if guaranteed or math.random( 100 ) <= LootcrateEpicChance[cell.isPoi] then
			local harvestable = sm.harvestable.createHarvestable( hvs_lootcrateepic, node.position, node.rotation )
			harvestable:setParams( { lootTable = cell.isWarehouse and "loot_crate_epic_warehouse" or "loot_crate_epic" } )
			print( "Spawned EPIC LOOTCRATE", ( guaranteed and "(guaranteed)" or "" ) )
			table.insert( storage.harvestables, harvestable )
			spawnCount = spawnCount + 1
		else
			print( "Skipped EPIC LOOTCRATE node" )
		end
	end
	return spawnCount
end

local function EpicLootSpawnFunction( cell, nodes, tag )
	local storage = { harvestables = {} }
	local spawnCount = SpawnEpicLootCrate( cell, nodes, #nodes, storage, tag )
	assert( spawnCount == #storage.harvestables )
	return storage
end

local function EpicLootRespawnFunction( cell, nodes, storage, tag )
	local spawnCount = #storage.harvestables

	-- Count how many loot harvestables are alive
	local aliveCount = 0
	for idx, hvs in reverse_ipairs( storage.harvestables ) do
		if sm.exists( hvs ) then
			aliveCount = aliveCount + 1
		else
			table.remove( storage.harvestables, idx )
		end
	end

	 -- Respawn loot on nodes
	 SpawnEpicLootCrate( cell, nodes, spawnCount - aliveCount, storage, tag )
	return storage
end

-- Ruin chests

local function ChestSpawnFunction( cell, interactables, tag )
	local storage = { containers = {} }
	assert( interactables )
	for _, interactable in ipairs( interactables ) do
		local container = interactable:getContainer()
		local loot
		if cell.isStartArea then
			loot = SelectLoot( "loot_ruinchest_startarea", container:getSize() )
		else
			loot = SelectLoot( "loot_ruinchest", container:getSize() )
		end

		sm.container.beginTransaction()
		for i,loot in ipairs( loot ) do
			sm.container.setItem( container, i - 1, loot.uuid, loot.quantity )
		end
		sm.container.endTransaction()	  
		
		table.insert( storage.containers, container )
	end
	return storage
end

local function ChestRespawnFunction( cell, nodes, storage, tag )

	-- Refill empty containers
	assert( storage.containers )
	for idx, container in reverse_ipairs( storage.containers ) do
		if sm.exists( container ) then
			if container:isEmpty() then
				local loot
				if cell.isStartArea then
					loot = SelectLoot( "loot_ruinchest_startarea", container:getSize() )
				else
					loot = SelectLoot( "loot_ruinchest", container:getSize() )
				end
		
				sm.container.beginTransaction()
				for i,loot in ipairs( loot ) do
					sm.container.setItem( container, i - 1, loot.uuid, loot.quantity )
				end
				sm.container.endTransaction()
			end
		else
			table.remove( storage.containers, idx )
		end
	end
	return storage
end

-- Farmer balls

local function FarmerBallSpawnFunction( cell, interactables, tag )
	local storage = { farmers = {} }
	assert( interactables )
	for _, interactable in ipairs( interactables ) do
		local farmer = { part = interactable:getShape(), pos = interactable:getShape():getWorldPosition(), rot = interactable:getShape():getWorldRotation() }
		table.insert( storage.farmers, farmer )
	end
	return storage
end

local function FarmerBallRespawnFunction( cell, nodes, storage, tag )
	assert( storage.farmers )
	for _, farmer in ipairs( storage.farmers ) do
		if not sm.exists( farmer.part ) then
			farmer.part = sm.shape.createPart( obj_survivalobject_farmerball, farmer.pos, farmer.rot, true, false ) -- static, ignore if collides
		end
	end
	return storage
end

local SpawnDescriptions = {
	-- Seeds
	["SEED_SPAWN"] = {
		channel = STORAGE_CHANNEL_SEED_SPAWNS,
		ticksBetweenRespawns = DaysInTicks( 5 ),
		spawn = SeedSpawnFunction,
		respawn = SeedSpawnFunction
	},

	-- Gas
	["GAS_SPAWN"] = {
		channel = STORAGE_CHANNEL_GAS_SPAWNS,
		ticksBetweenRespawns = DaysInTicks( 5 ),
		spawn = GasSpawnFunction,
		respawn = GasSpawnFunction
	},

	-- Units
	["HAYBOT"] = {
		channel = STORAGE_CHANNEL_HAYBOT_SPAWNS,
		ticksBetweenRespawns = UnitTicksBetweenRespawns["HAYBOT"],
		spawn = UnitSpawnFunction,
		respawn = UnitRespawnAllFunction,
	},
	["TOTEBOT_GREEN"] = {
		channel = STORAGE_CHANNEL_TOTEBOT_GREEN_SPAWNS,
		ticksBetweenRespawns = UnitTicksBetweenRespawns["TOTEBOT_GREEN"],
		spawn = UnitSpawnFunction,
		respawn = UnitRespawnAllFunction,
	},
	["TAPEBOT"] = {
		channel = STORAGE_CHANNEL_TAPEBOT_SPAWNS,
		ticksBetweenRespawns = UnitTicksBetweenRespawns["TAPEBOT"],
		spawn = UnitSpawnFunction,
		respawn = UnitRespawnAllFunction,
	},
	["FARMBOT"] = {
		channel = STORAGE_CHANNEL_FARMBOT_SPAWNS,
		ticksBetweenRespawns = UnitTicksBetweenRespawns["FARMBOT"],
		spawn = UnitSpawnFunction,
		respawn = UnitRespawnAllFunction,
	},
	["WOC"] = {
		channel = STORAGE_CHANNEL_WOC_SPAWNS,
		ticksBetweenRespawns = UnitTicksBetweenRespawns["WOC"],
		spawn = UnitSpawnFunction,
		respawn = UnitRespawnFunction,
	},
	["GLOWGORP"] = {
		channel = STORAGE_CHANNEL_GLOWGORP_SPAWNS,
		ticksBetweenRespawns = UnitTicksBetweenRespawns["GLOWGORP"],
		spawn = UnitSpawnFunction,
		respawn = UnitRespawnFunction,
	},









	-- Loot
	["LOOTCRATE"] = {
		channel = STORAGE_CHANNEL_LOOTCRATE_SPAWNS,
		ticksBetweenRespawns = DaysInTicks( 5 ),
		spawn = LootSpawnFunction,
		respawn = LootRespawnFunction,
	},

	["EPICLOOTCRATE"] = {
		channel = STORAGE_CHANNEL_EPICLOOTCRATE_SPAWNS,
		ticksBetweenRespawns = DaysInTicks( 5 ),
		spawn = EpicLootSpawnFunction,
		respawn = EpicLootRespawnFunction,
	},

	-- Ruin chests
	[tostring(obj_survivalobject_ruinchest)] = {
		channel = STORAGE_CHANNEL_RUINCHEST_SPAWNS,
		ticksBetweenRespawns = DaysInTicks( 5 ),
		spawn = ChestSpawnFunction,
		respawn = ChestRespawnFunction,
	},

	-- Farmer balls
	[tostring(obj_survivalobject_farmerball)] = {
		channel = STORAGE_CHANNEL_FARMERBALL_SPAWNS,
		ticksBetweenRespawns = DaysInTicks( 30 ),
		spawn = FarmerBallSpawnFunction,
		respawn = FarmerBallRespawnFunction,
	}
}

function SpawnFromNodeOnCellLoaded( cell, tag )
	local cellKey = CellKey(cell.x, cell.y)
	local spawnDesc = SpawnDescriptions[tag];
	assert( spawnDesc, "No spawn description attached to this tag!" )
	
	local nodes = sm.cell.getNodesByTag( cell.x, cell.y, tag )
	assert(nodes)
	if  #nodes > 0 then
		local storage = spawnDesc.spawn( cell, nodes, tag )
		sm.storage.save( { spawnDesc.channel, cell.worldId, cellKey }, { tick = sm.game.getCurrentTick(), storage = storage } )
	end
end

function RespawnFromNodeOnCellReloaded( cell, tag )
	local cellKey = CellKey(cell.x, cell.y)
	local spawnDesc = SpawnDescriptions[tag];
	assert( spawnDesc, "No spawn description attached to this tag!" )
	if spawnDesc.respawn == nil then
		return
	end
	
	local nodes = sm.cell.getNodesByTag( cell.x, cell.y, tag )
	if #nodes == 0 then
		return
	end
	
	local currentTick = sm.game.getCurrentTick()
	local loaded = sm.storage.load( { spawnDesc.channel, cell.worldId, cellKey } ) or { tick = currentTick }
	assert( currentTick >= loaded.tick, "currentTick: "..currentTick..", loaded.tick: "..loaded.tick )
	assert( spawnDesc.ticksBetweenRespawns )

	if ( currentTick - loaded.tick ) > spawnDesc.ticksBetweenRespawns then
		local storage = spawnDesc.respawn( cell, nodes, loaded.storage, tag )
		sm.storage.save( { spawnDesc.channel, cell.worldId, cellKey }, { tick = currentTick, storage = storage } )
	end

end

function SpawnFromUuidOnCellLoaded( cell, uuid )
	local cellKey = CellKey(cell.x, cell.y)
	local spawnDesc = SpawnDescriptions[tostring(uuid)];
	assert( spawnDesc, "No spawn description attached to this tag!" )
	
	local interactables = sm.cell.getInteractablesByUuid( cell.x, cell.y, uuid )
	assert(interactables)
	if  #interactables > 0 then
		local storage = spawnDesc.spawn( cell, interactables, uuid )
		sm.storage.save( { spawnDesc.channel, cell.worldId, cellKey }, { tick = sm.game.getCurrentTick(), storage = storage } )
	end
end

function RespawnFromUuidOnCellReloaded( cell, uuid )
	local cellKey = CellKey(cell.x, cell.y)
	local spawnDesc = SpawnDescriptions[tostring(uuid)];
	assert( spawnDesc, "No spawn description attached to this tag!" )
	if spawnDesc.respawn == nil then
		return
	end

	local currentTick = sm.game.getCurrentTick()
	local loaded = sm.storage.load( { spawnDesc.channel, cell.worldId, cellKey } ) or { tick = currentTick }
	assert( currentTick >= loaded.tick, "currentTick: "..currentTick..", loaded.tick: "..loaded.tick )
	assert( spawnDesc.ticksBetweenRespawns )

	if ( currentTick - loaded.tick ) > spawnDesc.ticksBetweenRespawns then
		local storage = spawnDesc.respawn( cell, nil, loaded.storage, uuid )
		sm.storage.save( { spawnDesc.channel, cell.worldId, cellKey }, { tick = currentTick, storage = storage } )
	end

end