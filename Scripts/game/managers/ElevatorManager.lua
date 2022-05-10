dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

ElevatorManager = class( nil )

local ELEVATOR_TRAVEL_TICKS = 680
local ELEVATOR_MOVEWALLS_TICK = ELEVATOR_TRAVEL_TICKS - 60
local ELEVATOR_TRANSFER_TICK = 120
local ELEVATOR_START_FADE = ELEVATOR_TRANSFER_TICK + 40 -- Sometime before transfer
local ELEVATOR_END_FADE = 40 -- Before doors open
 
local ELEVATOR_FADE_TIMEOUT = ELEVATOR_START_FADE * ( 1.0 / 40.0 ) + 5.0
local ELEVATOR_FADE_DURATION = 0.45

function ElevatorManager.sv_onCreate( self )
	--print( "ElevatorManager.onCreate()" )

	-- Game script managed global elevator table
	self.elevators = sm.storage.load( STORAGE_CHANNEL_ELEVATORS )
	if self.elevators then
		--print( "Loaded elevators:" )
		--print( self.elevators )
	else
		self.elevators = {}
		self:sv_saveElevators()
	end

	self.activeElevators = {}
	self.interactableToElevator = {}

	self.loadedCells = {}
	self.cellLoadRequests = {}
end

local CellTagToWarehouseFloors = { ["WAREHOUSE2"] = 2, ["WAREHOUSE3"] = 3, ["WAREHOUSE4"] = 4, ["POI_TEST"] = 1 }

function ElevatorManager.sv_loadElevatorsOnOverworldCell( self, x, y, cellTags )
	--print("--- passing data to elevators on cell " .. x .. ":" .. y .. " ---")

	local exits = {}
	local nodes = sm.cell.getNodesByTag( x, y, "ELEVATOR_EXIT_HINT" )
	for i,n in ipairs( nodes ) do
		local vector = n.rotation * ( sm.vec3.new( 0, 1, 0 ) * n.scale )
		local x1, y1 = getCell( n.position.x + vector.x, n.position.y + vector.y )
		exits[i] = { x = x1, y = y1 }
	end

	local setParamsOnElevators = function( tags, exits )
		local elevators = sm.cell.getInteractablesByTags( x, y, tags )
		for _,e in ipairs( elevators ) do
			print( "ElevatorCell: "..tags[1].."_"..tags[2].." found!" )
			local maxLevels = 0
			local foundFloorTag = false
			local foundTestTag = false
			for _, tag in ipairs( cellTags ) do
				if CellTagToWarehouseFloors[tag] then
					maxLevels = CellTagToWarehouseFloors[tag]
					foundFloorTag = true
					foundTestTag = tag == "POI_TEST"
					break
				end
			end
			assert( tags[2] ~= "ENTRANCE" or #exits > 0, "Elevator on ("..x..", "..y..") does not have an exit hint" )
			--assert( tags[2] ~= "ENTRANCE" or maxLevels ~= 0, "Elevator is not placed on a warehouse tile" )
			if foundFloorTag == false then
				maxLevels = 4
			end

			local params = {
				name = tags[1].."_"..tags[2],
				x = x,
				y = y,
				exits = exits,
				maxLevels = maxLevels,
				test = foundTestTag
			}
			e:setParams( params )
		end
	end

	setParamsOnElevators( { "ELEVATOR", "ENTRANCE" }, exits )
	setParamsOnElevators( { "ELEVATOR", "EXIT" } )
end

function ElevatorManager.sv_loadElevatorsOnWarehouseCell( self, x, y, warehouseIndex, level )
	local setParamsOnElevators = function( tags )
		local elevators = sm.cell.getInteractablesByTags( x, y, tags )
		for _,e in ipairs( elevators ) do
			local params = {
				name = tags[1].."_"..tags[2],
				warehouseIndex = warehouseIndex,
				level = level
			}
			e:setParams( params )
		end
	end

	setParamsOnElevators( { "ELEVATOR", "ENTRANCE" } )
	setParamsOnElevators( { "ELEVATOR", "UP" } )
	setParamsOnElevators( { "ELEVATOR", "DOWN" } )
	setParamsOnElevators( { "ELEVATOR", "EXIT" } )
end

function ElevatorManager.sv_saveElevators( self )
	print( "ElevatorManager.sv_saveElevators" )
	sm.storage.save( STORAGE_CHANNEL_ELEVATORS, self.elevators )
	--print( "Saved elevators:" )
	--print( self.elevators )
end

local function CellKey( world, x, y )
	if world:isIndoor() then
		return world.id
	end
	return world.id..":("..x..","..y..")"
end

function ElevatorManager.sv_onCellLoaded( self, worldSelf, x, y )
	--print( "ElevatorManager.sv_onCellLoaded", worldSelf.world, x, y )
	self.loadedCells[CellKey( worldSelf.world, x, y )] = true
end

function ElevatorManager.sv_onCellReloaded( self, worldSelf, x, y )
	--print( "ElevatorManager.sv_onCellLoaded", worldSelf.world, x, y )
	self.loadedCells[CellKey( worldSelf.world, x, y )] = true
end

function ElevatorManager.sv_onCellUnloaded( self, worldSelf, x, y )
	--print( "ElevatorManager.sv_onCellUnloaded", worldSelf.world, x, y )
	self.loadedCells[CellKey( worldSelf.world, x, y )] = nil
end

function ElevatorManager.sv_onFixedUpdate( self )
	local save = false
	for _,elevator in pairs( self.activeElevators ) do
		-- Transfer
		if elevator.ticksToDestination == ELEVATOR_TRANSFER_TICK then
			print( "Transfering to", elevator.destination )
			local playerInElevator = false

			local contents = elevator.destination == "b" and elevator.portal:getContentsA() or elevator.portal:getContentsB()

			if contents then
				for _,object in ipairs( contents ) do
					if type( object ) == "Character" and sm.exists( object ) then
						local player = object:getPlayer()
						if player then
							playerInElevator = true
						end
					end
				end
			end
			print( "playerInElevator", playerInElevator )
			if playerInElevator then
				local world
				local position
				if elevator.destination == "b" then
					world = elevator.portal:getWorldB()
					position = elevator.portal:getPositionB()
				else--if elevator.destination == "a" then
					world = elevator.portal:getWorldA()
					position = elevator.portal:getPositionA()
				end
				local x = math.floor( position.x / 64 )
				local y = math.floor( position.y / 64 )

				if world and sm.exists( world ) and self.loadedCells[CellKey( world, x, y )] then
					if elevator.destination == "b" then
						elevator.portal:transferAToB()
					else--if elevator.destination == "a" then
						elevator.portal:transferBToA()
					end
				else
					sm.log.info( "A player wants to transfer to '"..elevator.destination.."' but destination is not ready, added 1 second" )
					elevator.ticksToDestination = elevator.ticksToDestination + 40
				end
			end

			save = true
		end

		-- Open doors
		if elevator.ticksToDestination == 0 then
			if elevator.a and sm.exists( elevator.a ) then
				elevator.a.active = elevator.destination == "a"
				elevator.a:setPower( 0 )
			end
			if elevator.b and sm.exists( elevator.b ) then
				elevator.b.active = elevator.destination == "b"
				elevator.b:setPower( 0 )
			end
		else -- Elevator is moving
			assert( elevator.ticksToDestination > 0 )

			-- Countdown
			elevator.ticksToDestination = elevator.ticksToDestination - 1
			if elevator.ticksToDestination == 0 then
				save = true
			end

			-- Close doors
			if elevator.a and sm.exists( elevator.a ) then
				elevator.a.active = false
				if elevator.ticksToDestination == ELEVATOR_MOVEWALLS_TICK then
					elevator.a:setPower( elevator.destination == "a" and -1 or 1 )
				end
			end
			if elevator.b and sm.exists( elevator.b ) then
				elevator.b.active = false
				if elevator.ticksToDestination == ELEVATOR_MOVEWALLS_TICK then
					elevator.b:setPower( elevator.destination == "b" and 1 or -1 )
				end
			end

			-- Start Fade
			if elevator.ticksToDestination == ELEVATOR_START_FADE then
				if elevator.destination == "b" then
					if elevator.portal:getWorldB() then
						self:sv_sendFadeToBlackEvent( elevator.portal:getContentsA(), true )
					end
				end
				if elevator.destination == "a" then
					if elevator.portal:getWorldA() then
						self:sv_sendFadeToBlackEvent( elevator.portal:getContentsB(), true )
					end
				end
			end

			-- Transfer
			if elevator.ticksToDestination > ELEVATOR_TRANSFER_TICK then
				-- Prepare for A to B transfer
				if elevator.destination == "b" then
					if elevator.portal:getWorldB() then
						self:sv_prepareCell( elevator.portal:getWorldB(), elevator.portal:getPositionB(), elevator.portal:getContentsA() )
					end
				end

				-- Prepare for B to A transfer
				if elevator.destination == "a" then
					if elevator.portal:getWorldA() then
						self:sv_prepareCell( elevator.portal:getWorldA(), elevator.portal:getPositionA(), elevator.portal:getContentsB() )
					end
				end
			end

			-- End Fade
			if elevator.ticksToDestination == ELEVATOR_END_FADE then
				if elevator.destination == "a" then
					if elevator.portal:getWorldB() then
						self:sv_sendFadeToBlackEvent( elevator.portal:getContentsA(), false )
					end
				end
				if elevator.destination == "b" then
					if elevator.portal:getWorldA() then
						self:sv_sendFadeToBlackEvent( elevator.portal:getContentsB(), false )
					end
				end
			end
		end
	end
	if save then
		self:sv_saveElevators()
	end
end

function ElevatorManager.sv_sendFadeToBlackEvent( self, contents, start )
	if contents == nil then
		return
	end
	for _,object in ipairs( contents ) do
		if type( object ) == "Character" and sm.exists( object ) then
			local player = object:getPlayer()
			if player then
				if start then
					sm.event.sendToPlayer( player, "sv_startFadeToBlack", { duration = ELEVATOR_FADE_DURATION, timeout = ELEVATOR_FADE_TIMEOUT } )
				else
					sm.event.sendToPlayer( player, "sv_endFadeToBlack", { duration = ELEVATOR_FADE_DURATION } )
				end
			end
		end
	end
end

function ElevatorManager.sv_prepareCell( self, world, position, contents )
	if contents == nil then
		return
	end

	local x = math.floor( position.x / 64 )
	local y = math.floor( position.y / 64 )

	for _,object in ipairs( contents ) do
		if type( object ) == "Character" and sm.exists( object ) then
			local player = object:getPlayer()
			if player then
				if not sm.exists( world ) then
					sm.world.loadWorld( world )
				end
				local key = CellKey( world, x, y )
				if not self.loadedCells[key] then
					if not self.cellLoadRequests[player.id] then
						self.cellLoadRequests[player.id] = {}
					end
					if not self.cellLoadRequests[player.id][key] then
						printf( "Loading cell %s:(%s,%s) for player %s (ElevatorManager.sv_prepareCell)", world.id, x, y, player.id )
						world:loadCell( x, y, player, "sv_cellLoaded", nil, self )
						self.cellLoadRequests[player.id][key] = true
					end
				end
			end
		end
	end
end

function ElevatorManager.sv_loadBForPlayersInElevator( self, portal, world, x, y )
	for _,object in ipairs( portal:getContentsA() ) do
		if type( object ) == "Character" then
			local player = object:getPlayer()
			if player then
				printf( "Loading cell %s:(%s,%s) for player %s (ElevatorManager.sv_loadBForPlayersInElevator)", world.id, x, y, player.id )
				world:loadCell( x, y, player, "sv_cellLoaded", nil, self )
			end
		end
	end
end

function ElevatorManager.sv_cellLoaded( self, world, x, y, player )
	printf( "Cell loaded %s:(%s,%s) for player %s (ElevatorManager.sv_cellLoaded)", world.id, x, y, player.id )
	if self.cellLoadRequests[player.id] then
		self.cellLoadRequests[player.id][CellKey( world, x, y )] = nil
	end
end

function ElevatorManager.sv_onPlayerLeft( self, player )
	if self.cellLoadRequests[player.id] then
		self.cellLoadRequests[player.id] = nil
	end
end

-- Shape context

function ElevatorManager.sv_registerElevator( self, interactable, portal )
	print( "ElevatorManager.sv_registerElevator" )
	local elevator = self.elevators[portal.id]
	if elevator then
		-- Exists, check if A (load) otherwise, set as B
		assert( elevator.a )
		if elevator.a ~= interactable then
			assert( elevator.b == nil or elevator.b == interactable )
			elevator.b = interactable
		end
	else
		-- Does not exist, create and set as A
		elevator = {}
		elevator.portal = portal
		elevator.destination = "b"
		elevator.ticksToDestination = 0 -- At destination
		elevator.a = interactable
		self.elevators[portal.id] = elevator
	end

	self:sv_saveElevators()
	addToArrayIfNotExists( self.activeElevators, elevator )
	self.interactableToElevator[interactable.id] = elevator
end


function ElevatorManager.sv_removeElevator( self, interactable )
	local elevator = self.interactableToElevator[interactable.id]
	if elevator == nil then
		return
	end

	self.interactableToElevator[interactable.id] = nil
	local remove = true
	for _,e in pairs( self.interactableToElevator ) do
		if e == elevator then
			remove = false
			break
		end
	end
	if remove then
		--print( "Removed elevator from active elevators:" )
		--print( elevator )
		removeFromArray( self.activeElevators, function( value ) return value == elevator; end )
	end
end

function ElevatorManager.sv_getElevatorDestination( self, interactable )
	local elevator = self.interactableToElevator[interactable.id]
	assert( elevator, "Attempt to get an non existing elevator for interactable"..interactable.id )

	return elevator.destination, elevator.ticksToDestination
end

function ElevatorManager.sv_getElevatorHome( self, interactable )
	local elevator = self.interactableToElevator[interactable.id]
	assert( elevator, "Attempt to get an non existing elevator for interactable"..interactable.id )

	if interactable == elevator.b then
		return "b"
	end
	return "a"
end

function ElevatorManager.sv_call( self, interactable )
	local elevator = self.interactableToElevator[interactable.id]
	assert( elevator )

	if elevator.ticksToDestination == 0 then -- Not on the move
		print( "Elevator CALL!" )
		if elevator.destination == "b" and interactable == elevator.a then
			elevator.destination = "a"
			elevator.ticksToDestination = ELEVATOR_TRAVEL_TICKS
		elseif elevator.destination == "a" and interactable == elevator.b then
			elevator.destination = "b"
			elevator.ticksToDestination = ELEVATOR_TRAVEL_TICKS
		end
	end
end


function ElevatorManager.sv_go( self, interactable )
	print( "Elevator GO!" )
	local elevator = self.interactableToElevator[interactable.id]
	assert( elevator )

	if elevator.ticksToDestination == 0 then -- Not on the move
		if elevator.destination == "a" and interactable == elevator.a then
			-- A to B
			elevator.destination = "b"
			elevator.ticksToDestination = ELEVATOR_TRAVEL_TICKS

		elseif elevator.destination == "b" and interactable == elevator.b then
			-- B to A
			elevator.destination = "a"
			elevator.ticksToDestination = ELEVATOR_TRAVEL_TICKS

		elseif interactable == elevator.a then
			-- A to B failsafe
			print( "Elevator is not here. A to B failsafe activated!" )
			if elevator.portal:getWorldB() then
				sm.event.sendToGame( "sv_e_elevatorEvent", { fn = "sv_failsafeLoadCellAToB", portal = elevator.portal } )
			else
				print( "Elevator has no World B yet" )
			end
			
		elseif interactable == elevator.b then
			-- B to A failsafe
			print( "Elevator is not here. B to A failsafe activated!" )
			if elevator.portal:getWorldA() then
				sm.event.sendToGame( "sv_e_elevatorEvent", { fn = "sv_failsafeLoadCellBToA", portal = elevator.portal } )
			else
				print( "Elevator has no World A yet" )
			end
		end
	end
end

function ElevatorManager.sv_failsafeLoadCellAToB( self, params )
	local contents = params.portal:getContentsA()
	if contents then
		for _,object in ipairs( contents ) do
			if type( object ) == "Character" and sm.exists( object ) then
				local player = object:getPlayer()
				if player then
					local world = params.portal:getWorldB()
					if not sm.exists( world ) then
						sm.world.loadWorld( world )
					end
					local position = params.portal:getPositionB()
					local x = math.floor( position.x / 64 )
					local y = math.floor( position.y / 64 )
					printf( "Loading cell %s:(%s,%s) for player %s (ElevatorManager.sv_failsafeLoadCellAToB)", world.id, x, y, player.id )
					world:loadCell( x, y, player, "sv_transferAToB", params.portal, self )
				end
			end
		end
	end
end

function ElevatorManager.sv_failsafeLoadCellBToA( self, params )
	local contents = params.portal:getContentsB()
	if contents then
		for _,object in ipairs( contents ) do
			if type( object ) == "Character" and sm.exists( object ) then
				local player = object:getPlayer()
				if player then
					local world = params.portal:getWorldA()
					if not sm.exists( world ) then
						sm.world.loadWorld( world )
					end
					local position = params.portal:getPositionA()
					local x = math.floor( position.x / 64 )
					local y = math.floor( position.y / 64 )
					printf( "Loading cell %s:(%s,%s) for player %s (ElevatorManager.sv_failsafeLoadCellBToA)", world.id, x, y, player.id )
					world:loadCell( x, y, player, "sv_transferBToA", params.portal, self )
				end
			end
		end
	end
end

function ElevatorManager.sv_transferAToB( self, world, x, y, player, portal )
	print( "ElevatorManager.sv_transferAToB" )
	print( portal )
	portal:transferAToB()
end

function ElevatorManager.sv_transferBToA( self, world, x, y, player, portal )
	print( "ElevatorManager.sv_transferBToA" )
	print( portal )
	portal:transferBToA()
end
