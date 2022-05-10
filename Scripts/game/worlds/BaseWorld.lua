dofile( "$SURVIVAL_DATA/Scripts/game/managers/FireManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/WaterManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/PesticideManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_constants.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_spawns.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/QuestEntityManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$GAME_DATA/Scripts/game/managers/EventManager.lua" )

BaseWorld = class( nil )

function BaseWorld.server_onCreate( self )
	self.fireManager = FireManager()
	self.fireManager:sv_onCreate( self )

	self.waterManager = WaterManager()
	self.waterManager:sv_onCreate( self )

	self.pesticideManager = PesticideManager()
	self.pesticideManager:sv_onCreate()
end

function BaseWorld.client_onCreate( self )
	if self.fireManager == nil then
		assert( not sm.isHost )
		self.fireManager = FireManager()
	end
	self.fireManager:cl_onCreate( self )

	if self.waterManager == nil then
		assert( not sm.isHost )
		self.waterManager = WaterManager()
	end
	self.waterManager:cl_onCreate()

	if self.pesticideManager == nil then
		assert( not sm.isHost )
		self.pesticideManager = PesticideManager()
	end
	self.pesticideManager:cl_onCreate()
end

function BaseWorld.server_onFixedUpdate( self )
	self.fireManager:sv_onFixedUpdate()
	self.waterManager:sv_onFixedUpdate()
	self.pesticideManager:sv_onWorldFixedUpdate( self )
end

function BaseWorld.client_onFixedUpdate( self )
	self.waterManager:cl_onFixedUpdate()
end

function BaseWorld.client_onUpdate( self, dt )
	g_effectManager:cl_onWorldUpdate( self )
end

function BaseWorld.sv_n_fireMsg( self, msg )
	self.fireManager:sv_handleMsg( msg )
end

function BaseWorld.cl_n_fireMsg( self, msg )
	self.fireManager:cl_handleMsg( msg )
end

function BaseWorld.cl_n_pesticideMsg( self, msg )
	self.pesticideManager[msg.fn]( self.pesticideManager, msg )
end







function BaseWorld.sv_e_spawnUnit( self, params )
	for i = 1, params.amount do
		sm.unit.createUnit( params.uuid, params.position, params.yaw )
	end
end








function BaseWorld.sv_spawnHarvestable( self, params )
	local harvestable = sm.harvestable.createHarvestable( params.uuid, params.position, params.quat )
	if params.harvestableParams then
		harvestable:setParams( params.harvestableParams )
	end
end

function BaseWorld.sv_loadLootOnCell( self, x, y, tags )
	--print("--- placing loot crates on cell " .. x .. ":" .. y .. " ---")



end

function BaseWorld.server_onCellCreated( self, x, y )
	local tags = sm.cell.getTags( x, y )
	local cell = { x = x, y = y, worldId = self.world.id, isStartArea = valueExists( tags, "STARTAREA" ), isPoi = valueExists( tags, "POI" ) }

	g_elevatorManager:sv_onCellLoaded( self, x, y )
	QuestEntityManager.Sv_OnWorldCellLoaded( self, x, y )

	SpawnFromUuidOnCellLoaded( cell, obj_survivalobject_ruinchest )
	SpawnFromUuidOnCellLoaded( cell, obj_survivalobject_farmerball )

	SpawnFromNodeOnCellLoaded( cell, "SEED_SPAWN" )
	--SpawnFromNodeOnCellLoaded( cell, "GAS_SPAWN" )

	SpawnFromNodeOnCellLoaded( cell, "LOOTCRATE" )
	SpawnFromNodeOnCellLoaded( cell, "EPICLOOTCRATE" )

	SpawnFromNodeOnCellLoaded( cell, "HAYBOT" )
	SpawnFromNodeOnCellLoaded( cell, "TOTEBOT_GREEN" )
	SpawnFromNodeOnCellLoaded( cell, "WOC" )
	SpawnFromNodeOnCellLoaded( cell, "GLOWGORP" )




	self.fireManager:sv_onCellLoaded( x, y )
	self.waterManager:sv_onCellLoaded( x, y )

	-- Randomize stacks
	local stackedList = sm.cell.getInteractablesByAnyUuid( x, y, {
		obj_consumable_gas, obj_consumable_battery,
		obj_consumable_fertilizer, obj_consumable_chemical,
		obj_consumable_inkammo,
		obj_consumable_soilbag,
		obj_plantables_potato,
		obj_seed_banana, obj_seed_blueberry, obj_seed_orange, obj_seed_pineapple,
		obj_seed_carrot, obj_seed_redbeet, obj_seed_tomato, obj_seed_broccoli,
		obj_seed_potato
	} )
	local stackFn = {
		[tostring(obj_consumable_fertilizer)] = randomStackAmount20,
		[tostring(obj_consumable_inkammo)] = function() return randomStackAmount( 32, 48, 64 ) end,
		[tostring(obj_consumable_soilbag)] = randomStackAmountAvg2,
		[tostring(obj_plantables_potato)] = randomStackAmountAvg10,
	}
	for _,stacked in ipairs( stackedList ) do
		local fn = stackFn[tostring( stacked.shape.uuid )]
		if fn then
			stacked.shape.stackedAmount = fn()
		else
			stacked.shape.stackedAmount = randomStackAmount5()
		end
	end




end























function BaseWorld.client_onCellLoaded( self, x, y )
	self.fireManager:cl_onCellLoaded( x, y )
	self.waterManager:cl_onCellLoaded( x, y )
	g_effectManager:cl_onWorldCellLoaded( self, x, y )
	QuestEntityManager.Cl_OnWorldCellLoaded( self, x, y )
end

function BaseWorld.server_onCellLoaded( self, x, y )
	local tags = sm.cell.getTags( x, y )
	local cell = { x = x, y = y, worldId = self.world.id, isStartArea = valueExists( tags, "STARTAREA" ), isPoi = valueExists( tags, "POI" ) }

	g_elevatorManager:sv_onCellLoaded( self, x, y )
	QuestEntityManager.Sv_OnWorldCellLoaded( self, x, y )
	self.fireManager:sv_onCellReloaded( x, y )
	self.waterManager:sv_onCellReloaded( x, y )

	if not cell.isStartArea then

		RespawnFromUuidOnCellReloaded( cell, obj_survivalobject_ruinchest )
		RespawnFromUuidOnCellReloaded( cell, obj_survivalobject_farmerball )

		RespawnFromNodeOnCellReloaded( cell, "SEED_SPAWN" )
		--RespawnFromNodeOnCellReloaded( cell, "GAS_SPAWN" )

		RespawnFromNodeOnCellReloaded( cell, "LOOTCRATE")
		RespawnFromNodeOnCellReloaded( cell, "EPICLOOTCRATE" )

		RespawnFromNodeOnCellReloaded( cell, "HAYBOT" )
		RespawnFromNodeOnCellReloaded( cell, "TOTEBOT_GREEN" )
		RespawnFromNodeOnCellReloaded( cell, "WOC" )
		RespawnFromNodeOnCellReloaded( cell, "GLOWGORP" )



	end
end

function BaseWorld.server_onCellUnloaded( self, x, y )
	g_elevatorManager:sv_onCellUnloaded( self, x, y )
	QuestEntityManager.Sv_OnWorldCellUnloaded( self, x, y )
	self.fireManager:sv_onCellUnloaded( x, y )
	self.waterManager:sv_onCellUnloaded( x, y )
end

function BaseWorld.client_onCellUnloaded( self, x, y )
	g_effectManager:cl_onWorldCellUnloaded( self, x, y )
	QuestEntityManager.Cl_OnWorldCellUnloaded( self, x, y )
	self.waterManager:cl_onCellUnloaded( x, y )
end

function BaseWorld.sv_e_markBag( self, params )
	self.network:sendToClient( params.player, "cl_n_markBag", params )
end

function BaseWorld.cl_n_markBag( self, params )
	g_respawnManager:cl_markBag( params )
end

function BaseWorld.sv_e_unmarkBag( self, params )
	self.network:sendToClient( params.player, "cl_n_unmarkBag", params )
end

function BaseWorld.cl_n_unmarkBag( self, params )
	g_respawnManager:cl_unmarkBag( params )
end

-- Beacons
function BaseWorld.sv_e_createBeacon( self, params )
	if params.player and sm.exists( params.player ) then
		self.network:sendToClient( params.player, "cl_n_createBeacon", params )
	else
		self.network:sendToClients( "cl_n_createBeacon", params )
	end
end

function BaseWorld.cl_n_createBeacon( self, params )
	g_beaconManager:cl_createBeacon( params )
end

function BaseWorld.sv_e_destroyBeacon( self, params )
	if params.player and sm.exists( params.player ) then
		self.network:sendToClient( params.player, "cl_n_destroyBeacon", params )
	else
		self.network:sendToClients( "cl_n_destroyBeacon", params )
	end
end

function BaseWorld.cl_n_destroyBeacon( self, params )
	g_beaconManager:cl_destroyBeacon( params )
end

function BaseWorld.sv_e_unloadBeacon( self, params )
	if params.player and sm.exists( params.player ) then
		self.network:sendToClient( params.player, "cl_n_unloadBeacon", params )
	else
		self.network:sendToClients( "cl_n_unloadBeacon", params )
	end
end

function BaseWorld.cl_n_unloadBeacon( self, params )
	g_beaconManager:cl_unloadBeacon( params )
end

function BaseWorld.server_onProjectileFire( self, firePos, fireVelocity, _, attacker, projectileUuid )
	if isAnyOf( projectileUuid, g_potatoProjectiles ) then
		local units = sm.unit.getAllUnits()
		for i, unit in ipairs( units ) do
			if InSameWorld( self.world, unit ) then
				sm.event.sendToUnit( unit, "sv_e_worldEvent", { eventName = "projectileFire", firePos = firePos, fireVelocity = fireVelocity, projectileUuid = projectileUuid, attacker = attacker })
			end
		end
	end
end

function BaseWorld.server_onInteractableCreated( self, interactable )
	g_unitManager:sv_onInteractableCreated( interactable )
	QuestEntityManager.Sv_OnInteractableCreated( interactable )
end

function BaseWorld.server_onInteractableDestroyed( self, interactable )
	g_unitManager:sv_onInteractableDestroyed( interactable )
	QuestEntityManager.Sv_OnInteractableDestroyed( interactable )
end

function BaseWorld.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, target, projectileUuid )

	-- Spawn loot from projectiles with loot user data
	if userData and userData.lootUid then
		local normal = -hitVelocity:normalize()
		local zSignOffset = math.min( sign( normal.z ), 0 ) * 0.5
		local offset = sm.vec3.new( 0, 0, zSignOffset )
		local lootHarvestable = sm.harvestable.createHarvestable( hvs_loot, hitPos + offset, sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, 1 ) ) )
		lootHarvestable:setParams( { uuid = userData.lootUid, quantity = userData.lootQuantity, epic = userData.epic  } )
	end

	-- Notify units about projectile hit
	if isAnyOf( projectileUuid, g_potatoProjectiles ) then
		local units = sm.unit.getAllUnits()
		for i, unit in ipairs( units ) do
			if InSameWorld( self.world, unit ) then
				sm.event.sendToUnit( unit, "sv_e_worldEvent", { eventName = "projectileHit", hitPos = hitPos, hitTime = hitTime, hitVelocity = hitVelocity, attacker = attacker, damage = damage })
			end
		end
	end

	if projectileUuid == projectile_pesticide then
		local forward = sm.vec3.new( 0, 1, 0 )
		local randomDir = forward:rotateZ( math.random( 0, 359 ) )
		local effectPos = hitPos
		local success, result = sm.physics.raycast( hitPos + sm.vec3.new( 0, 0, 0.1 ), hitPos - sm.vec3.new( 0, 0, PESTICIDE_SIZE.z * 0.5 ), nil, sm.physics.filter.static + sm.physics.filter.dynamicBody )
		if success then
			effectPos = result.pointWorld + sm.vec3.new( 0, 0, PESTICIDE_SIZE.z * 0.5 )
		end
		self.pesticideManager:sv_addPesticide( self, effectPos, sm.vec3.getRotation( forward, randomDir ) )
	end

	if projectileUuid == projectile_glowstick then
		sm.harvestable.createHarvestable( hvs_remains_glowstick, hitPos, sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), hitVelocity:normalize() ) )
	end

	if projectileUuid == projectile_explosivetape then
		sm.physics.explode( hitPos, 7, 2.0, 6.0, 25.0, "RedTapeBot - ExplosivesHit" )
	end









end

function BaseWorld.server_onMelee( self, hitPos, attacker, target, damage, power, hitDirection, hitNormal )
	-- print("Melee hit in Overworld!")
	-- print(hitPos)
	-- print(attacker)
	-- print(damage)
	-- print(target)

	if attacker and sm.exists( attacker ) and target and sm.exists( target ) then
		if type( target ) == "Shape" and type( attacker) == "Unit" then
			local targetPlayer = nil
			if target.interactable and target.interactable:hasSeat() then
				local targetCharacter = target.interactable:getSeatCharacter()
				if targetCharacter then
					targetPlayer = targetCharacter:getPlayer()
				end
			end
			if targetPlayer then
				sm.event.sendToPlayer( targetPlayer, "sv_e_receiveDamage", { damage = damage } )
			end




		end
	end
end

function BaseWorld.server_onCollision( self, objectA, objectB, collisionPosition, objectAPointVelocity, objectBPointVelocity, collisionNormal )
	g_unitManager:sv_onWorldCollision( self, objectA, objectB, collisionPosition, objectAPointVelocity, objectBPointVelocity, collisionNormal )
end

function BaseWorld.sv_e_onChatCommand( self, params )

	if params[1] == "/starterkit" then
		local chest = sm.shape.createPart( obj_container_smallchest, params.player.character.worldPosition + sm.vec3.new( 0, 0, 2 ), sm.quat.identity() )
		chest.color = sm.color.new( 1, 0.5, 0 )
		local container = chest.interactable:getContainer()

		sm.container.beginTransaction()
		sm.container.collect( container, blk_scrapwood, 100 )
		sm.container.collect( container, jnt_bearing, 6 )
		sm.container.collect( container, obj_scrap_smallwheel, 4 )
		sm.container.collect( container, obj_scrap_driverseat, 1 )
		sm.container.collect( container, tool_connect, 1 )
		sm.container.collect( container, obj_scrap_gasengine, 1 )
		sm.container.collect( container, obj_consumable_gas, 10 )
		sm.container.endTransaction()

	elseif params[1] == "/mechanicstartkit" then
		local chest = sm.shape.createPart( obj_container_smallchest, params.player.character.worldPosition + sm.vec3.new( 0, 0, 2 ), sm.quat.identity() )
		chest.color = sm.color.new( 0, 0, 0 )
		local container = chest.interactable:getContainer()

		sm.container.beginTransaction()
		sm.container.collect( container, obj_consumable_sunshake, 5 )

		sm.container.collect( container, blk_scrapwood, 256 )
		sm.container.collect( container, blk_scrapwood, 256 )
		sm.container.collect( container, blk_scrapmetal, 256 )
		sm.container.collect( container, blk_glass, 20 )

		sm.container.collect( container, obj_consumable_component, 10 )
		sm.container.collect( container, obj_consumable_gas, 20 )
		sm.container.collect( container, obj_resource_circuitboard, 10 )
		sm.container.collect( container, obj_resource_circuitboard, 10 )
		sm.container.collect( container, obj_consumable_chemical, 20 )
		sm.container.collect( container, obj_resource_corn, 20 )
		sm.container.collect( container, obj_resource_flower, 20 )

		sm.container.collect( container, obj_consumable_soilbag, 15 )
		sm.container.collect( container, obj_plantables_carrot, 10 )
		sm.container.collect( container, obj_plantables_tomato, 10 )
		sm.container.collect( container, obj_seed_tomato, 20 )
		sm.container.collect( container, obj_seed_carrot, 20 )
		sm.container.collect( container, obj_seed_redbeet, 10 )
		sm.container.endTransaction()
	elseif params[1] == "/tutorialstartkit" then
		local chest = sm.shape.createPart( obj_container_smallchest, params.player.character.worldPosition + sm.vec3.new( 0, 0, 2 ), sm.quat.identity() )
		chest.color = sm.color.new( 1, 1, 1 )
		local container = chest.interactable:getContainer()

		sm.container.beginTransaction()
		sm.container.collect( container, sm.uuid.new( "e83a22c5-8783-413f-a199-46bc30ca8dac"), 1 ) -- Tutorial part
		sm.container.collect( container, blk_scrapwood, 38 )
		sm.container.collect( container, jnt_bearing, 6 )
		sm.container.collect( container, obj_scrap_smallwheel, 4 )
		sm.container.collect( container, obj_scrap_driverseat, 1 )
		sm.container.collect( container, obj_scrap_gasengine, 1 )

		sm.container.collect( container, tool_connect, 1 )
		sm.container.collect( container, obj_consumable_gas, 4 )

		sm.container.endTransaction()

	elseif params[1] == "/pipekit" then
		local chest = sm.shape.createPart( obj_container_smallchest, params.player.character.worldPosition + sm.vec3.new( 0, 0, 2 ), sm.quat.identity() )
		chest.color = sm.color.new( 0, 0, 1 )
		local container = chest.interactable:getContainer()

		sm.container.beginTransaction()
		sm.container.collect( container, obj_pneumatic_pump, 1 )
		sm.container.collect( container, obj_pneumatic_pipe_03, 10 )
		sm.container.collect( container, obj_pneumatic_pipe_bend, 5 )
		sm.container.endTransaction()

	elseif params[1] == "/foodkit" then
		local chest = sm.shape.createPart( obj_container_smallchest, params.player.character.worldPosition + sm.vec3.new( 0, 0, 2 ), sm.quat.identity() )
		chest.color = sm.color.new( 1, 1, 0 )
		local container = chest.interactable:getContainer()

		sm.container.beginTransaction()
		sm.container.collect( container, obj_plantables_banana, 10 )
		sm.container.collect( container, obj_plantables_blueberry, 10 )
		sm.container.collect( container, obj_plantables_orange, 10 )
		sm.container.collect( container, obj_plantables_pineapple, 10 )
		sm.container.collect( container, obj_plantables_carrot, 10 )
		sm.container.collect( container, obj_plantables_redbeet, 10 )
		sm.container.collect( container, obj_plantables_tomato, 10 )
		sm.container.collect( container, obj_plantables_broccoli, 10 )
		sm.container.collect( container, obj_consumable_sunshake, 5 )
		sm.container.collect( container, obj_consumable_carrotburger, 5 )
		sm.container.collect( container, obj_consumable_pizzaburger, 5 )
		sm.container.collect( container, obj_consumable_longsandwich, 5 )
		sm.container.collect( container, obj_consumable_milk, 5 )
		sm.container.collect( container, obj_resource_steak, 5 )
		sm.container.endTransaction()

	elseif params[1] == "/seedkit" then
		local chest = sm.shape.createPart( obj_container_smallchest, params.player.character.worldPosition + sm.vec3.new( 0, 0, 2 ), sm.quat.identity() )
		chest.color = sm.color.new( 0, 1, 0 )
		local container = chest.interactable:getContainer()

		sm.container.beginTransaction()
		sm.container.collect( container, obj_seed_banana, 20 )
		sm.container.collect( container, obj_seed_blueberry, 20 )
		sm.container.collect( container, obj_seed_orange, 20 )
		sm.container.collect( container, obj_seed_pineapple, 20 )
		sm.container.collect( container, obj_seed_carrot, 20 )
		sm.container.collect( container, obj_seed_redbeet, 20 )
		sm.container.collect( container, obj_seed_tomato, 20 )
		sm.container.collect( container, obj_seed_broccoli, 20 )
		sm.container.collect( container, obj_seed_potato, 20 )
		sm.container.collect( container, obj_consumable_soilbag, 50 )
		sm.container.endTransaction()

	elseif params[1] == "/clearpathnodes" then
		sm.pathfinder.clearWorld()

	elseif params[1] == "/enablepathpotatoes" then
		if params[2] ~= nil then
			self.enablePathPotatoes = params[2]
		end
		if self.enablePathPotatoes then
			sm.gui.chatMessage( "enablepathpotatoes is on" )
		else
			sm.gui.chatMessage( "enablepathpotatoes is off" )
		end

	elseif params[1] == "/aggroall" then
		local units = sm.unit.getAllUnits()
		for _, unit in ipairs( units ) do
			sm.event.sendToUnit( unit, "sv_e_receiveTarget", { targetCharacter = params.player.character } )
		end
		sm.gui.chatMessage( "Units in overworld are aware of PLAYER" .. tostring( params.player.id ) .. " position." )

	elseif params[1] == "/settilebool" or params[1] == "/settilefloat" or params[1] == "/settilestring" then
		if g_eventManager then
			local x = math.floor( params.player.character.worldPosition.x / 64 )
			local y = math.floor( params.player.character.worldPosition.y / 64 )

			local tileStorageKey = g_eventManager:sv_getTileStorageKey( self.world.id, x, y )

			if tileStorageKey then
				g_eventManager:sv_setValue( tileStorageKey, params[2], params[3] )
				sm.gui.chatMessage( "Set tile "..tileStorageKey.." value '"..params[2].."' to "..tostring( params[3] ) )
			else
				sm.log.error( "No tile storage key found!" )
			end
		end
		
	elseif params[1] == "/printtilevalues" then
		if g_eventManager then
			local x = math.floor( params.player.character.worldPosition.x / 64 )
			local y = math.floor( params.player.character.worldPosition.y / 64 )

			local tileStorageKey = g_eventManager:sv_getTileStorageKey( self.world.id, x, y )

			if tileStorageKey then
				local tileStorage = g_eventManager:sv_getTileStorage( tileStorageKey )
				print( "Tile storage values:" )
				print( tileStorage )
				sm.gui.chatMessage( "Tile values printed to console" )
			else
				sm.log.error( "No tile storage key found!" )
			end
		end

	elseif params[1] == "/killall" then
		local units = sm.unit.getAllUnits()
		for _, unit in ipairs( units ) do
			unit:destroy()
		end
	end
end