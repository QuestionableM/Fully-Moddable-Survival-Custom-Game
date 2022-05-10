dofile( "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_constants.lua" )

Elevator = class()
Elevator.maxParentCount = 255
Elevator.maxChildCount = 255
Elevator.connectionInput = sm.interactable.connectionType.logic
Elevator.connectionOutput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power

















































































function Elevator.client_onCreate( self )
	self.cl = {}
	self.cl.moveEffect = sm.effect.createEffect( "ElevatorWall", self.interactable )
	self.cl.musicEffect = sm.effect.createEffect( "ElevatorMusic", self.interactable )
	self.cl.ambianceEffect = sm.effect.createEffect( "ElevatorAmbiance", self.interactable )
	self.cl.musicEffect:start()
	self.cl.ambianceEffect:start()
end























function Elevator.server_onCreate( self )
	print( "Elevator.server_onCreate" )
	self.saved = self.storage:load()
	self.sv = {}
	print( "Saved:" )
	print( self.saved )
	print( "Params:" )
	print( self.params )
	assert( ( self.saved == nil ) ~= ( self.params == nil ) )
	if self.saved == nil then
		print( "Creating elevator "..self.params.name )
		self.saved = self.params
		self:findOrCreatePortal()
		self.storage:save( self.saved )
	else
		print( "Loaded elevator "..self.saved.name )
		if self.saved.portal then
			g_elevatorManager:sv_registerElevator( self.interactable, self.saved.portal )
		end
	end
















end

function Elevator.server_onDestroy( self )
	print( "Destroyed elevator "..self.interactable.id )






	g_elevatorManager:sv_removeElevator( self.interactable )
end


function Elevator.server_onRefresh( self )
	print( "Refresh elevator "..self.interactable.id )
end


function Elevator.sv_getInputs( self )
	local elevatorButton, elvatorCallButton, keycardReader
	for _, parent in ipairs( self.interactable:getParents() ) do
		local uid = parent.shape.shapeUuid
		if uid == obj_survivalobject_elevatorbutton then
			elevatorButton = parent
		elseif uid == obj_survivalobject_elevatorcallbutton then
			elvatorCallButton = parent
		elseif uid == obj_survivalobject_cardreader then
			keycardReader = parent
		end
	end
	return elevatorButton, elvatorCallButton, keycardReader
end

function Elevator.server_onFixedUpdate( self )
	-- Roof exit hookup
	if self.saved.portal == nil and self.saved.level == nil and self.saved.name == "ELEVATOR_EXIT" then
		-- No world hook was found when the elevator was created. Keep looking for the exit elevator...
		self.saved.portal = self:findPortal( self.saved.name.." "..self.saved.x..","..self.saved.y )
		if self.saved.portal then
			self.storage:save( self.saved )
		end
	end

	-- Inputs
	local elevatorPanelButton, elvatorCallButton, keycardReader = self:sv_getInputs()
	assert( elevatorPanelButton, "Elevator missing elevator panel button" )
	assert( elvatorCallButton, "Elevator missing elevator call button" )

	-- Is elevator locked
	local isLocked = keycardReader and not keycardReader:isActive()
	if not isLocked then

		local destination, ticksToDestination = g_elevatorManager:sv_getElevatorDestination( self.interactable )
		assert( destination )
		assert( ticksToDestination )
		local elevatorHome = g_elevatorManager:sv_getElevatorHome( self.interactable )
		assert( elevatorHome )

		elvatorCallButton:getPublicData().destination = destination
		elvatorCallButton:getPublicData().ticksToDestination = ticksToDestination
		elvatorCallButton:getPublicData().elevatorHome = elevatorHome
	end

	-- Elevator button is pressed
	if elevatorPanelButton:isActive() then
		self:sv_panelButtonPressed()
		elevatorPanelButton:setActive( false )
	end

	-- Elevator call button is pressed
	if elvatorCallButton:isActive() then

		if not isLocked then -- No locked keycard reader and button is pressed
			self:sv_callButtonPressed()
		elseif keycardReader then
			keycardReader:getPublicData().showError = true
		end
		elvatorCallButton:setActive( false )
	end
end


function Elevator.client_onUpdate( self, deltaTime )
	if self.interactable.power == 0 then
		if self.cl.moveEffect:isPlaying() == true then
			self.cl.moveEffect:stop()
		end
	else
		if self.cl.moveEffect:isPlaying() == false then
			self.cl.moveEffect:start()
		end
	end
end

function Elevator.sv_callButtonPressed( self )
	print( "Elevator call button was pressed" )
	g_elevatorManager:sv_call( self.interactable )
end


function Elevator.sv_panelButtonPressed( self )
	--print( "Elevator panel button was pressed" )
	if self.saved.portal == nil then
		print( "Elevator has no destination yet" )
		return
	end

	if self.saved.portal:hasOpeningA() and self.saved.portal:hasOpeningB() then
		g_elevatorManager:sv_go( self.interactable )
	else
		self:sv_createElevatorDestination()
		g_elevatorManager:sv_go( self.interactable )
	end
end



function Elevator.sv_createElevatorDestination( self )
	assert( self.saved.portal:hasOpeningA(), "Portal has no opening" )
	if not self.destinationCreated then
		local playerInElevator = false
		print( "Contents A:" )
		print( self.saved.portal:getContentsA() )

		for _,object in ipairs( self.saved.portal:getContentsA() ) do
			if type( object ) == "Character" then
				local player = object:getPlayer()
				if player then
					playerInElevator = true
					break
				end
			end
		end

		if playerInElevator then
			sm.event.sendToGame( "sv_e_createElevatorDestination", self.saved )
			self.destinationCreated = true
		else
			--There is no player in the elevator
			--Close the door and pretend to go away
		end
	end
end


function Elevator.createPortal( self, name )
	local position = self.shape.worldPosition + self.shape.worldRotation * sm.vec3.new( 0, 1.875, 0 )
	local size = sm.vec3.new( 1.75, 1.75, 3.0 ) - sm.vec3.new( 0.05, 0.05, 0.05 )
	local portal = sm.portal.createPortal( size )

	print( "Created portal "..name.." "..portal.id )
	g_elevatorManager:sv_registerElevator( self.interactable, portal )
	portal:setOpeningA( position, self.shape.worldRotation )

	return portal
end


function Elevator.findPortal( self, name )
	local position = self.shape.worldPosition + self.shape.worldRotation * sm.vec3.new( 0, 1.875, 0 )
	--print( "Looking for portal '"..name.."' in world "..sm.world.getCurrentWorld().id )
	local portal = sm.portal.popWorldPortalHook( name )
	if portal then
		print( "Portal "..portal.id.." found" )
		g_elevatorManager:sv_registerElevator( self.interactable, portal )
		portal:setOpeningB( position, self.shape.worldRotation )
	end
	return portal
end


function Elevator.findOrCreatePortal( self )
	if self.saved.level then
		-- Indoor
		if self.saved.name == "ELEVATOR_ENTRANCE" or self.saved.name == "ELEVATOR_DOWN" then
			print( "Looking for portal '"..self.saved.name.."' in world "..sm.world.getCurrentWorld().id )
			self.saved.portal = self:findPortal( self.saved.name )
		elseif self.saved.name == "ELEVATOR_UP" or self.saved.name == "ELEVATOR_EXIT" then
			self.saved.portal = self:createPortal( self.saved.name )
		end
	else
		-- Outdoor
		if self.saved.name == "ELEVATOR_ENTRANCE"  then
			self.saved.portal = self:createPortal( self.saved.name )
		elseif self.saved.name == "ELEVATOR_EXIT" then
			local name = self.saved.name.." "..self.saved.x..","..self.saved.y
			print( "Looking for portal '"..self.saved.name.."' in world "..sm.world.getCurrentWorld().id )
			self.saved.portal = self:findPortal( name )
			if self.saved.portal == nil then
				print( "No portal found" )
			end
		end
	end
end
