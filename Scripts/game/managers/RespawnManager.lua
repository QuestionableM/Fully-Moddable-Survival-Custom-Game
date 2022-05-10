dofile("$CONTENT_DATA/Scripts/game/survival_constants.lua")
dofile "$CONTENT_DATA/Scripts/game/survival_shapes.lua"

-- Server side
RespawnManager = class( nil )

local BagVersion = 2

function RespawnManager.sv_onCreate( self, overworld )
	self.sv = {}

	self.sv.playerBeds = sm.storage.load( STORAGE_CHANNEL_BEDS )
	if self.sv.playerBeds then
		print( "Loaded player beds:" )
		print( self.sv.playerBeds )
	else
		self.sv.playerBeds = {}
		self:sv_saveBeds()
	end

	self.sv.permanentPlayerBeds = sm.storage.load( STORAGE_CHANNEL_PERMANENT_BEDS )
	if self.sv.permanentPlayerBeds then
		print( "Loaded permanent player beds:" )
		print( self.sv.permanentPlayerBeds )
	else
		self.sv.permanentPlayerBeds = {}
		self:sv_savePermanentBeds()
	end

	self.sv.spawners = sm.storage.load( STORAGE_CHANNEL_SPAWNERS )
	if self.sv.spawners then
		print( "Loaded spawners:" )
		print( self.sv.spawners )
	else
		self.sv.spawners = {}
		self.sv.spawners.all = {}
		self.sv.spawners.latest = {}
		self:sv_saveSpawners()
	end

	self.sv.savedBags = sm.storage.load( STORAGE_CHANNEL_BAGS )
	if self.sv.savedBags then
		local savedBagVersion = self.sv.savedBags.version and self.sv.savedBags.version or 1
		print( "Loaded bags with version", savedBagVersion, ":" )
		print( self.sv.savedBags )

		if savedBagVersion == 1 then
			local updatedSavedBags = { version = BagVersion, players = {} }
			for playerIdKey, playerBag in pairs( self.sv.savedBags ) do
				updatedSavedBags.players[playerIdKey] = {}
				updatedSavedBags.players[playerIdKey][1] = playerBag
			end
			self.sv.savedBags = updatedSavedBags
		end
		if savedBagVersion ~= BagVersion then
			print( "Upgraded bags to version", BagVersion, ":" )
			print( self.sv.savedBags )
		end
	else
		self.sv.savedBags = { version = BagVersion, players = {} }
		self:sv_saveBags()
	end
	self.sv.latestSpawnIndex = 1
	self.sv.overworld = overworld
end

function RespawnManager.cl_onCreate( self )
	self.cl = {}
	self.cl.bags = {}
end

function RespawnManager.sv_saveBeds( self )
	sm.storage.save( STORAGE_CHANNEL_BEDS, self.sv.playerBeds )
end

function RespawnManager.sv_savePermanentBeds( self )
	sm.storage.save( STORAGE_CHANNEL_PERMANENT_BEDS, self.sv.permanentPlayerBeds )
end

function RespawnManager.sv_saveSpawners( self )
	sm.storage.save( STORAGE_CHANNEL_SPAWNERS, self.sv.spawners )
end

function RespawnManager.sv_saveBags( self )
	sm.storage.save( STORAGE_CHANNEL_BAGS, self.sv.savedBags )
end

-- Game environment
function RespawnManager.sv_onSpawnCharacter( self, player )
	local playerBags = self.sv.savedBags.players[tostring( player.id )]
	if playerBags then
		for _, bag in ipairs( playerBags ) do
			if not sm.exists( bag.shape ) and sm.exists( bag.world ) and bag.world == player.character:getWorld() then
				sm.event.sendToGame( "sv_e_markBag", bag )
			end
		end
	end
end

-- Interactable environment
function RespawnManager.sv_markBag( self, shape, player )
	if player and shape and sm.exists( shape ) then
		local bag = {}
		bag.world = shape.body:getWorld()
		bag.shape = shape
		bag.position = shape.worldPosition
		bag.player = player

		local playerBags = self.sv.savedBags.players[tostring( player.id )]
		if playerBags == nil then
			playerBags = {}
		end
		playerBags[#playerBags+1] = bag
		self.sv.savedBags.players[tostring( player.id )] = playerBags
		self:sv_saveBags()

		sm.event.sendToGame( "sv_e_markBag", bag )
	end
end

-- Interactable environment
function RespawnManager.sv_unmarkBag( self, shape )

	local updatedSavedBags = { version = BagVersion, players = {} }
	for playerIdKey, playerBags in pairs( self.sv.savedBags.players ) do
		local updatedPlayerBags = {}
		for _, bag in ipairs( playerBags ) do
			if bag.shape == shape then
				sm.event.sendToGame( "sv_e_unmarkBag", bag )
			else
				updatedPlayerBags[#updatedPlayerBags+1] = bag
			end
		end
		updatedSavedBags.players[playerIdKey] = updatedPlayerBags
	end
	self.sv.savedBags = updatedSavedBags
	self:sv_saveBags()

end

-- World environment
function RespawnManager.cl_markBag( self, bag )

	for _, guiBag in pairs( self.cl.bags ) do
		if guiBag.shape == bag.shape then
			-- Skip, this bag is already marked
			return
		end
	end

	local guiBag = {}
	guiBag.gui = sm.gui.createWorldIconGui( 32, 32, "$GAME_DATA/Gui/Layouts/Hud/Hud_WorldIcon.layout", false )
	guiBag.gui:setImage( "Icon", "gui_icon_kobag.png" )
	guiBag.gui:setWorldPosition( bag.position )
	guiBag.gui:setRequireLineOfSight( false )
	guiBag.gui:open()
	guiBag.gui:setMaxRenderDistance(10000)
	guiBag.shape = bag.shape
	guiBag.player = bag.player

	self.cl.bags[#self.cl.bags+1] = guiBag
end

-- World environment
function RespawnManager.cl_unmarkBag( self, bag )

	local updatedGuiBags = {}
	for _, guiBag in pairs( self.cl.bags ) do
		if guiBag.shape == bag.shape then
			guiBag.gui:close()
			guiBag.gui:destroy()
		else
			updatedGuiBags[#updatedGuiBags+1] = guiBag
		end
	end
	self.cl.bags = updatedGuiBags
end

function RespawnManager.sv_addSpawners( self, nodes )
	for i, node in ipairs( nodes ) do
		self.sv.spawners.all[#self.sv.spawners+1] = node
	end
	self:sv_saveSpawners()
end

function RespawnManager.sv_setLatestSpawners( self, nodes )
	self.sv.spawners.latest = nodes
	self.sv.latestSpawnIndex = 1
	self:sv_saveSpawners()
end

function RespawnManager.sv_destroyBed( self, shape )

	local updatedPlayerBeds = {}
	local playersUsingBed = {}
	for playerBedKey, playerBed in pairs( self.sv.playerBeds ) do
		if sm.exists( playerBed.player ) then
			playersUsingBed[#playersUsingBed+1] = playerBed.player
		end
		if playerBed.shape and playerBed.shape == shape then
			updatedPlayerBeds[playerBedKey] = nil
		else
			updatedPlayerBeds[playerBedKey] = playerBed
		end
	end
	self.sv.playerBeds = updatedPlayerBeds
	self:sv_saveBeds()

	for _, player in ipairs( playersUsingBed ) do
		local playerBed = self:sv_getPlayerBed( player )
		local nearStart = true
		if playerBed then
			nearStart = ( playerBed.position - START_AREA_SPAWN_POINT ):length() <= CELL_SIZE

			if nearStart then
				sm.event.sendToPlayer( playerBed.player, "sv_e_onMsg", "#{INFO_HOME_CRASH_SITE}" )
			else
				sm.event.sendToPlayer( playerBed.player, "sv_e_onMsg", "#{INFO_HOME_MECHANIC_STATION}" )
			end
		end
	end
end

function RespawnManager.sv_registerBed( self, shape, character )

	if character:isPlayer() then
		local playerBed = {}
		playerBed.world = shape.body:getWorld()
		playerBed.shape = shape
		playerBed.position = shape.worldPosition
		playerBed.rotation = shape.worldRotation
		playerBed.player = character:getPlayer()

		if shape.uuid == obj_spaceship_shipbed and shape.body:isStatic() and not shape.body.convertableToDynamic then
			self.sv.permanentPlayerBeds[tostring( character:getPlayer().id )] = playerBed
			self:sv_savePermanentBeds()
		else
			self.sv.playerBeds[tostring( character:getPlayer().id )] = playerBed
			self:sv_saveBeds()
		end
	end

end

function RespawnManager.sv_updateBed( self, shape )
	local playerBedsThatLeftOverworld = {}
	local updatedPlayerBeds = {}
	for playerBedKey, playerBed in pairs( self.sv.playerBeds ) do
		if playerBed.shape and sm.exists( playerBed.shape ) and playerBed.shape == shape then
			playerBed.position = shape.worldPosition
			playerBed.rotation = shape.worldRotation
			playerBed.world = shape.body:getWorld()
			if playerBed.world ~= self.sv.overworld then
				playerBedsThatLeftOverworld[#playerBedsThatLeftOverworld+1] = playerBed
			end
		end
		updatedPlayerBeds[playerBedKey] = playerBed
	end
	self.sv.playerBeds = updatedPlayerBeds
	self:sv_saveBeds()

	for _, oldPlayerBed in ipairs( playerBedsThatLeftOverworld ) do
		if sm.exists( oldPlayerBed.player ) then
			local playerBed = self:sv_getPlayerBed( oldPlayerBed.player )
			local nearStart = true
			if playerBed then
				nearStart = ( playerBed.position - START_AREA_SPAWN_POINT ):length() <= CELL_SIZE
			end
			if nearStart then
				sm.event.sendToPlayer( oldPlayerBed.player, "sv_e_onMsg", "#{INFO_HOME_CRASH_SITE}" )
			else
				sm.event.sendToPlayer( oldPlayerBed.player, "sv_e_onMsg", "#{INFO_HOME_MECHANIC_STATION}" )
			end
		end
	end
end

function RespawnManager.sv_getPlayerBed( self, player )
	-- Find placed bed
	local playerBed = self.sv.playerBeds[tostring( player.id )]
	if playerBed then
		if playerBed.shape and sm.exists( playerBed.shape ) then
			if playerBed.shape.body:getWorld() ~= self.sv.overworld then
				playerBed = nil
			end
		elseif playerBed.world ~= self.sv.overworld then
			playerBed = nil
		end
	end

	if playerBed == nil then
		-- Find permanent bed
		playerBed = self.sv.permanentPlayerBeds[tostring( player.id )]
	end

	return playerBed
end

function RespawnManager.sv_getSpawner( self, character )

	local spawnPosition = g_survivalDev and SURVIVAL_DEV_SPAWN_POINT or START_AREA_SPAWN_POINT
	local spawnRotation = sm.quat.identity()

	if character:getWorld() == self.sv.overworld then
		-- Find the closest saved spawner
		local closestSpawnerDistance = nil
		local closestSpawner = nil
		for _, spawner in pairs( self.sv.spawners.all ) do
			local spawnerDistance = ( spawner.position - character.worldPosition ):length()
			if closestSpawnerDistance == nil then
				closestSpawnerDistance = spawnerDistance
				closestSpawner = spawner
			else
				if spawnerDistance < closestSpawnerDistance  then
					closestSpawnerDistance = spawnerDistance
					closestSpawner = spawner
				end
			end
		end

		if closestSpawner ~= nil then
			spawnPosition = closestSpawner.position
			spawnRotation = closestSpawner.rotation
		end
	elseif #self.sv.spawners.latest > 0 then
		-- Use the latest nearby nodes
		local spawner = self.sv.spawners.latest[self.sv.latestSpawnIndex]
		self.sv.latestSpawnIndex = ( self.sv.latestSpawnIndex % #self.sv.spawners.latest ) + 1
		spawnPosition = spawner.position
		spawnRotation = spawner.rotation
	end

	return spawnPosition, spawnRotation
end

-- Game environment helper function
function RespawnManager.sv_requestRespawnCharacter( self, player )
	local spawnPosition = g_survivalDev and SURVIVAL_DEV_SPAWN_POINT or START_AREA_SPAWN_POINT
	local respawnWorld = self.sv.overworld

	-- Load respawn cell
	local playerBed = self:sv_getPlayerBed( player )
	if playerBed then
		-- Load the bed's position if it exists, otherwise use its last known position.
		spawnPosition = SURVIVAL_DEV_SPAWN_POINT
		if playerBed.shape and sm.exists( playerBed.shape ) then
			spawnPosition = playerBed.shape.worldPosition
			respawnWorld = playerBed.shape.body:getWorld()
		else
			spawnPosition = playerBed.position
			respawnWorld = playerBed.world
		end
	else
		spawnPosition, _ = self:sv_getSpawner( player.character )
	end

	if not sm.exists( respawnWorld ) then
		sm.world.loadWorld( respawnWorld )
	end
	respawnWorld:loadCell( math.floor( spawnPosition.x / 64 ), math.floor( spawnPosition.y / 64 ), player, "sv_loadedRespawnCell" ) -- Callback received by the Game script
end

-- Game environment helper function
function RespawnManager.sv_respawnCharacter( self, player, world )
	local spawnPosition = g_survivalDev and SURVIVAL_DEV_SPAWN_POINT or START_AREA_SPAWN_POINT
	local spawnRotation = sm.quat.identity()

	local playerBed = self:sv_getPlayerBed( player )
	if playerBed then
		-- Spawn at the bed's position if it exists, otherwise use its last known position.
		if playerBed.shape and sm.exists( playerBed.shape ) then
			spawnPosition = playerBed.shape.worldPosition
			spawnRotation = playerBed.shape.worldRotation
		else
			spawnPosition = playerBed.position
			spawnRotation = playerBed.rotation
		end
	else
		spawnPosition, spawnRotation = self:sv_getSpawner( player.character )
	end

	spawnPosition = spawnPosition + sm.vec3.new( 0, 0, player.character:getHeight() * 0.5 )
	local yaw = 0
	local pitch = 0
	local spawnDirection = spawnRotation * sm.vec3.new( 0, 0, 1 )
	yaw = math.atan2( spawnDirection.y, spawnDirection.x ) - math.pi/2
	local newCharacter = sm.character.createCharacter( player, world, spawnPosition, yaw, pitch )
	player:setCharacter( newCharacter )

end

-- Player environment helper function
function RespawnManager.sv_performItemLoss( self, player )
	local shape = nil
	if player then
		local inventory = player:getInventory()
		local size = inventory:getSize()
		local lostItems = {}
		for i = 0, size do
			local item = inventory:getItem( i )
			if not sm.item.isTool( item.uuid ) and item.uuid ~= sm.uuid.getNil() then
				item.slot = i
				lostItems[#lostItems+1] = item
			end
		end

		if #lostItems > 0 then
			shape = sm.shape.createPart( obj_survivalobject_kobag, player.character.worldPosition, sm.quat.identity(), true, true )
			shape.interactable:setParams( { owner = player } )
			local lostContainer = shape.interactable:addContainer( 0, #lostItems )
			if sm.container.beginTransaction() then
				for i, item in ipairs( lostItems ) do
					sm.container.spendFromSlot( inventory, item.slot, item.uuid, item.quantity, true )
					sm.container.collectToSlot( lostContainer, i-1, item.uuid, item.quantity, true )
				end
				if sm.container.endTransaction() then
					return shape
				end
			end
		end
	end
	return nil
end
