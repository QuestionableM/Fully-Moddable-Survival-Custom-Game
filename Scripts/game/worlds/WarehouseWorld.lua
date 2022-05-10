dofile( "$SURVIVAL_DATA/Scripts/game/SurvivalGame.lua")
dofile( "$SURVIVAL_DATA/Scripts/game/worlds/BaseWorld.lua")
dofile( "$SURVIVAL_DATA/Scripts/game/survival_units.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_constants.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_loot.lua" )

WarehouseWorld = class( BaseWorld )
WarehouseWorld.terrainScript = "$SURVIVAL_DATA/Scripts/terrain/terrain_warehouse.lua"
WarehouseWorld.enableSurface = false
WarehouseWorld.enableAssets = true
WarehouseWorld.enableClutter = false
WarehouseWorld.enableNodes = true
WarehouseWorld.enableCreations = true
WarehouseWorld.enableHarvestables = true
WarehouseWorld.enableKinematics = true
WarehouseWorld.renderMode = "warehouse"
WarehouseWorld.isIndoor = true
WarehouseWorld.worldBorder = false

local WarehouseTileList = {
	[1] = { "$SURVIVAL_DATA/DungeonTiles/Warehouse_Interior_StorageFloor_01.tile",
			"$SURVIVAL_DATA/DungeonTiles/Warehouse_Interior_StorageFloor_02.tile",
			"$SURVIVAL_DATA/DungeonTiles/Warehouse_Interior_StorageFloor_03.tile",
			"$SURVIVAL_DATA/DungeonTiles/Warehouse_Interior_StorageFloor_04.tile",
			"$SURVIVAL_DATA/DungeonTiles/Warehouse_Interior_StorageFloor_05.tile"
	},
	[2] = { "$SURVIVAL_DATA/DungeonTiles/Warehouse_Interior_OfficeFloor_01.tile",
			"$SURVIVAL_DATA/DungeonTiles/Warehouse_Interior_OfficeFloor_02.tile",
			"$SURVIVAL_DATA/DungeonTiles/Warehouse_Interior_OfficeFloor_03.tile",
	},
	[3] = { "$SURVIVAL_DATA/DungeonTiles/Warehouse_Interior_ConstructionFloor_01.tile",
			"$SURVIVAL_DATA/DungeonTiles/Warehouse_Interior_ConstructionFloor_02.tile",
	},
	[4] = { "$SURVIVAL_DATA/DungeonTiles/Warehouse_Interior_EncryptorFloor_01.tile" },
}

local WarehouseLevelSelect = {
	[2] = { [1] = 1, [2] = 4 },
	[3] = { [1] = 1, [2] = 2, [3] = 4 },
	[4] = { [1] = 1, [2] = 2, [3] = 3, [4] = 4 },
}

local WarehouseShieldExceptions =
{
	obj_destructable_tape_doorwaytape01,
	obj_destructable_tape_doorwaytape01_destroyed,
	obj_destructable_tape_cornertape01,
	obj_destructable_tape_cornertape02,
	obj_destructable_tape_cornertape03,
	obj_destructable_tape_cornertape04,
	obj_destructable_tape_corridor01,
	obj_destructable_tape_corridor02,
	obj_destructable_tape_corridor03,
	obj_destructable_tape_taperoll01,
	obj_destructable_tape_taperoll02,
	obj_destructable_tape_taperoll03,
	obj_destructable_tape_taperoll04,
	obj_destructable_tape_tape01,
	obj_destructable_tape_tape02,
	obj_destructable_tape_tape03,
	obj_destructable_tape_tape04,
	obj_destructable_tape_tape05,
	obj_destructable_tape_tape06,
	obj_destructable_tape_cocoon01,
	obj_destructable_tape_cocoon02,
	obj_destructable_tape_rooftape01,
	obj_destructable_tape_rooftape02,
	obj_destructable_tape_rooftape03,
	obj_destructable_tape_rooftape04,
	obj_destructable_tape_acrosstheroom01,
	obj_destructable_tape_acrosstheroom02,
	obj_destructable_tape_acrosstheroom03,
	obj_destructable_tape_big_walltape01,
	obj_destructable_tape_big_walltape02,
	obj_destructable_tape_big_walltape03,
	obj_destructable_tape_big_walltape04,
	obj_destructable_tape_big_walltape05,
	obj_destructable_taperolls_big,
	obj_destructable_taperolls_small
}

function WarehouseWorld.server_onCreate( self )
	BaseWorld.server_onCreate( self )
	print( "WarehouseWorld - server create" )
	print( self.data )
	self.unitCount = 0














		assert(self.data.level ~= nil, "Created a warehouse world without a level!")
		assert(self.data.level > 0 and self.data.level <= #WarehouseTileList, "Created with warehouse world with invalid level parameter")
		assert(self.data.maxLevels > 1 and self.data.maxLevels <= #WarehouseTileList, "Created with warehouse world with invalid maxLevels parameter")

		local index = WarehouseLevelSelect[self.data.maxLevels][self.data.level]
		assert(index)
		local tileList = WarehouseTileList[index]
		assert(tileList and #tileList > 0)
		local tile = tileList[math.random( #tileList )]

		self.data.tiles = {}
		table.insert( self.data.tiles, tile )
		self.data.creations = {}
		self.data.lightReductionChance = 30

		self.world:setTerrainScriptData( self.data )

		self:sv_createKillBox()



end

function WarehouseWorld.client_onCreate( self )
	BaseWorld.client_onCreate( self )
	print( "WarehouseWorld - client create" )
	print( self.data )

	self.ambienceEffect = sm.effect.createEffect( "WarehouseAmbiance" )
	self.ambienceEffect:start()
end

function WarehouseWorld.sv_e_onChatCommand( self, params )
	BaseWorld.sv_e_onChatCommand( self, params )
end

function WarehouseWorld.sv_createKillBox( self )

	-- Filter
	local filter = sm.areaTrigger.filter.character + sm.areaTrigger.filter.dynamicBody

	-- Kill effect box
	local rotation = sm.quat.identity()

	-- Kill box -Z
	local halfSize = sm.vec3.new( 8192, 8192, 512.0 )
	local position = sm.vec3.new( 0.0, 0.0, -1024.0 )
	self.killAreaTriggerNZ = sm.areaTrigger.createBox( halfSize, position, rotation, filter )
	self.killAreaTriggerNZ:bindOnEnter( "trigger_onEnterKillBox" )

	-- Kill box +Z
	local halfSize = sm.vec3.new( 8192, 8192, 512.0 )
	local position = sm.vec3.new( 0.0, 0.0, 1024.0 )
	self.killAreaTriggerPZ = sm.areaTrigger.createBox( halfSize, position, rotation, filter )
	self.killAreaTriggerPZ:bindOnEnter( "trigger_onEnterKillBox" )

	-- Kill box +Y
	local halfSize = sm.vec3.new( 8192, 512.0, 8192 )
	local position = sm.vec3.new( 0.0, 1024.0, 0.0 )
	self.killAreaTriggerPY = sm.areaTrigger.createBox( halfSize, position, rotation, filter )
	self.killAreaTriggerPY:bindOnEnter( "trigger_onEnterKillBox" )

	-- Kill box -Y
	local halfSize = sm.vec3.new( 8192, 512.0, 8192 )
	local position = sm.vec3.new( 0.0, -1024.0, 0.0 )
	self.killAreaTriggerNY = sm.areaTrigger.createBox( halfSize, position, rotation, filter )
	self.killAreaTriggerNY:bindOnEnter( "trigger_onEnterKillBox" )

	-- Kill box +X
	local halfSize = sm.vec3.new( 512.0, 8192, 8192 )
	local position = sm.vec3.new( 1024.0, 0.0, 0.0 )
	self.killAreaTriggerPX = sm.areaTrigger.createBox( halfSize, position, rotation, filter )
	self.killAreaTriggerPX:bindOnEnter( "trigger_onEnterKillBox" )

	-- Kill box -X
	local halfSize = sm.vec3.new( 512.0, 8192, 8192 )
	local position = sm.vec3.new( -1024.0, 0.0, 0.0 )
	self.killAreaTriggerNX = sm.areaTrigger.createBox( halfSize, position, rotation, filter )
	self.killAreaTriggerNX:bindOnEnter( "trigger_onEnterKillBox" )
end

function WarehouseWorld.trigger_onEnterKillBox( self, trigger, results )

	-- New objects in the kill box
	for _,result in ipairs( results ) do
		if sm.exists( result ) then
			-- Respawn character
			if type( result ) == "Character" then
				if result:isPlayer() then
					sm.event.sendToPlayer( result:getPlayer(), "sv_e_receiveDamage", { damage = 9999 } )
				else
					result:getUnit():destroy()
				end
			end
			--Destroy shapes
			if type( result ) == "Body" then
				for _, shape in ipairs( result:getShapes() ) do
					sm.shape.destroyShape( shape )
				end
			end
		end
	end

end


function WarehouseWorld.client_onUpdate( self, deltaTime )
	BaseWorld.client_onUpdate( self, deltaTime )
	local player = sm.localPlayer.getPlayer()
	local character = player:getCharacter()
	if character and character:getWorld() == self.world then
		if g_survivalMusicWorld ~= self.world then
			g_survivalMusicWorld = self.world
			g_survivalMusic:stop()
		end
		if not g_survivalMusic:isPlaying() then
			g_survivalMusic:start()
		end
		if self.data.level == self.data.maxLevels then
			g_survivalMusic:setParameter( "music", 6 ) -- warehouse top floor
		else
			g_survivalMusic:setParameter( "music", 5 ) -- warehouse
		end
	end
end

function WarehouseWorld.server_onCellCreated( self, x, y )
	BaseWorld.server_onCellCreated( self, x, y )

	g_elevatorManager:sv_loadElevatorsOnWarehouseCell( x, y, self.data.warehouseIndex, self.data.level )

	-- Create path nodes from waypoint nodes
	local pathNodes = {}
	local waypoints = sm.cell.getNodesByTag( x, y, "WAYPOINT" )
	for _, waypoint in ipairs( waypoints ) do
		assert( waypoint.params.connections ~= nil, "Waypoint nodes expected to have 'connections' param" )
		pathNodes[waypoint.params.connections.id] = sm.pathNode.createPathNode( waypoint.position, waypoint.scale.x )
	end

	-- Destructable tape block intersected nodes from being connected
	local destructableTapes = sm.cell.getInteractablesByTag( x, y, "OBSTACLE" )
	for _, tape in ipairs( destructableTapes ) do
		if sm.exists( tape ) then
			local worldPos = tape:getShape():getWorldPosition()
			for _, waypoint in ipairs( waypoints ) do
				if ( worldPos - waypoint.position ):length2() < 2.0 then
					local params = {
						blockedNode = pathNodes[waypoint.params.connections.id],
						connections = {}
					}
					for _,value in ipairs( waypoint.params.connections.otherIds ) do
						if (type(value) == "table") then
							table.insert( params.connections, pathNodes[value.id] )
						else
							table.insert( params.connections, pathNodes[value] )
						end
					end
					tape:setParams( params )
					pathNodes[waypoint.params.connections.id] = nil
				end
			end
		end
	end

	local cell = { x = x, y = y, worldId = self.world.id, isPoi = false, isWarehouse = true, warehouseLevel = self.data.level }

	local loot_warehouserewardchest = {
		{ uuid = obj_outfitpackage_common,	quantity = 1 },
		{ uuid = obj_outfitpackage_rare,	quantity = 1 },
		{ uuid = obj_outfitpackage_epic,	quantity = 1 },
		{ uuid = obj_consumable_component, 	quantity = 10 },
		{ uuid = obj_seed_broccoli, 		quantity = 5 },
		{ uuid = obj_seed_pineapple, 		quantity = 5 },
	}

	-- Warehouse reward chest
	local chests = sm.cell.getInteractablesByUuid( x, y, obj_container_smallchest )
	for _,chest in ipairs( chests ) do
		local container = chest:getContainer()

		sm.container.beginTransaction()
		for i,loot in ipairs( loot_warehouserewardchest ) do
			sm.container.setItem( container, i - 1, loot.uuid, loot.quantity )
		end
		sm.container.endTransaction()
	end

	-- Warehouse file cabinet
	local filecabinets = sm.cell.getInteractablesByUuid( x, y, obj_interactive_filecabinet )
	for _, filecabinet in ipairs( filecabinets ) do
		local container = filecabinet:getContainer()
		local lootList = SelectLoot( "loot_warehouse_filecabinet", 3 )
		sm.container.beginTransaction()
		for i, loot in ipairs( lootList ) do
			sm.container.setItem( container, i - 1, loot.uuid, loot.quantity )
		end
		sm.container.endTransaction()
	end

	-- Warehouse locker
	local lockers = sm.cell.getInteractablesByUuid( x, y, obj_interactive_locker )
	for _, locker in ipairs( lockers ) do
		local container = locker:getContainer()
		local lootList = SelectLoot( "loot_warehouse_locker", 4 )
		sm.container.beginTransaction()
		for i, loot in ipairs( lootList ) do
			sm.container.setItem( container, i - 1, loot.uuid, loot.quantity )
		end
		sm.container.endTransaction()
	end

	-- Connect path nodes
	for _, waypoint in ipairs( waypoints ) do
		for index, value in ipairs( waypoint.params.connections.otherIds ) do
			if (type(value) == "table") then
				if pathNodes[waypoint.params.connections.id] ~= nil and pathNodes[value.id] ~= nil then
					pathNodes[waypoint.params.connections.id]:connect( pathNodes[value.id], value.actions, value.conditions )
				else
					--assert(false, "This shouldnt occur in a warehouse world")
				end
			else
				if pathNodes[waypoint.params.connections.id] ~= nil and pathNodes[value] ~= nil then
					pathNodes[waypoint.params.connections.id]:connect( pathNodes[value] )
				else
					--assert(false, "This shouldnt never occur!")
				end
			end
		end
	end

	-- Create units from tapebot nodes
	local tapebots = sm.cell.getNodesByTag( x, y, "TAPEBOT" )
	local tapebotCount = 20
	local redTapebotCount = self.data.level == self.data.maxLevels and 5 or 0
	assert( redTapebotCount <= tapebotCount )
	tapebots = shuffle( tapebots )
	for idx, tapebot in ipairs( tapebots ) do
		if idx <= tapebotCount then
			local spawnDirection = tapebot.rotation * sm.vec3.new( 0, 0, 1 )
			local yaw = math.atan2( spawnDirection.y, spawnDirection.x ) - math.pi/2
			local params = { tetherPoint = tapebot.position }
			if tapebot.params then
				append( params, tapebot.params )
			end

			if idx <= redTapebotCount then
				sm.unit.createUnit( unit_tapebot_red, tapebot.position, yaw, params )
			else
				sm.unit.createUnit( g_tapebots[math.random( 1, #g_tapebots )], tapebot.position, yaw, params )
			end
		end
	end
	

	-- Tell the level encryptors which warehouse they're part of
	local setParamsOnEncryptors = function( uuid )
		local encryptors = sm.cell.getInteractablesByUuid( x, y, uuid )
		for _, e in ipairs( encryptors ) do
			print( "WarehouseWorld: " .. tostring( uuid ) .. " found!" )
			local params = {
				warehouseIndex = self.data.warehouseIndex,
			}
			e:setParams( params )
		end
	end
	setParamsOnEncryptors( obj_interactive_encryptor_destruction )
	setParamsOnEncryptors( obj_interactive_encryptor_connection )

	-- Find out what restrictions SurvivalGame thinks this warehouse world should have
	local params = { world = self.world, warehouseIndex = self.data.warehouseIndex }
	sm.event.sendToGame( "sv_e_requestWarehouseRestrictions", params )

end

function WarehouseWorld.server_onCellLoaded( self, x, y )
	BaseWorld.server_onCellLoaded( self, x, y )

	-- local cell = { x = x, y = y, worldId = self.world.id, isPoi = false, isWarehouse = true, warehouseLevel = self.data.level }

	-- RespawnFromNodeOnCellReloaded( cell, "LOOTCRATE" )
	-- RespawnFromNodeOnCellReloaded( cell, "EPICLOOTCRATE" )

	-- Find out what restrictions SurvivalGame thinks this warehouse world should have
	local params = { world = self.world, warehouseIndex = self.data.warehouseIndex }
	sm.event.sendToGame( "sv_e_requestWarehouseRestrictions", params )
end

function WarehouseWorld.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, target, projectileUuid )
	BaseWorld.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, target, projectileUuid )















end

function WarehouseWorld.server_onMelee( self, hitPos, attacker, target, damage, power, hitDirection, hitNormal )
	BaseWorld.server_onMelee( self, hitPos, attacker, target, damage, power, hitDirection, hitNormal )















end

function WarehouseWorld.server_updateRestrictions( self, restrictions )
	-- local worldBodies = sm.body.getAllBodies()
	-- for _, body in ipairs( worldBodies ) do
	-- 	if body.destructable then -- We dont want to decrypt bodies which is indestructable ie. elevator body and elevator doors
	-- 		local restrictionState = false
	-- 		local restrictionSwitch = switch {
	-- 			["destructable"] = function( x ) --[[print( x, restrictionState )]] body.destructable = restrictionState end,
	-- 			["buildable"] = function( x ) --[[print( x, restrictionState) ]]body.buildable = restrictionState end,
	-- 			["paintable"] = function( x ) --[[print( x, restrictionState) ]]body.paintable = restrictionState end,
	-- 			["connectable"] = function( x ) --[[print( x, restrictionState) ]]body.connectable = restrictionState end,
	-- 			["liftable"] = function( x ) --[[print( x, restrictionState) ]]body.liftable = restrictionState end,
	-- 			["erasable"] = function( x ) --[[print( x, restrictionState) ]]body.erasable = restrictionState end,
	-- 			["usable"] = function( x ) --[[print( x, restrictionState) ]]body.usable = restrictionState end,
	-- 			default = function( x ) print( x, "is not a valid encryption name.") end
	-- 		}
	-- 		for _, restrictionSetting in pairs( restrictions ) do
	-- 			restrictionState = restrictionSetting.state
	-- 			restrictionSwitch:case( restrictionSetting.name )
	-- 		end
	-- 	end
	-- end
end

