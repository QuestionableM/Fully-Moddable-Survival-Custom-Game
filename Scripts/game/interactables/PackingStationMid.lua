PackingStationMid = class( nil )

PackingStationMid.ProcessingTime = 6.6 -- Matched current animation

-- Sevrer

function PackingStationMid.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}

		if not self.params then
			sm.log.info("Patching missing PackingStationMid params")
			local x, y = getCell( self.shape:getWorldPosition().x, self.shape:getWorldPosition().y )
			self.params = {}
			self.params.packingStation = {}
			self.params.packingStation.screens = {}
			concat( self.params.packingStation.screens, FindInteractablesWithinCell( tostring( obj_packingstation_screen_fruit ), x, y ) )
			concat( self.params.packingStation.screens, FindInteractablesWithinCell( tostring( obj_packingstation_screen_veggie ), x, y ) )
			self.params.packingStation.front = FindFirstInteractableWithinCell( tostring( obj_packingstation_front ), x, y )
			self.params.packingStation.crateload = FindFirstInteractableWithinCell( tostring( obj_packingstation_crateload ), x, y )
		end

		self.sv.saved.screens = self.params.packingStation.screens
		self.sv.saved.front = self.params.packingStation.front
		self.sv.saved.crateload = self.params.packingStation.crateload
		self.storage:save( self.sv.saved )
	end

	assert( self.sv.saved.screens )
	assert( self.sv.saved.front )
	assert( self.sv.saved.crateload )

	self.sv.state = "idle"
	self.sv.processingTimer = 0
	self.sv.processingShape = nil
end

function PackingStationMid.server_onFixedUpdate( self, timeStep )	
	if self.sv.state == "idle" then
		for _, screen in pairs( self.sv.saved.screens ) do
			local screenData = screen:getPublicData()
			if screenData and screenData.state and screenData.state == "waiting_for_pickup" and screenData.shape then
				screenData.state = "picked_up"
				screen:setPublicData( screenData )

				self.sv.state = "processing"
				self.sv.processingTimer = 0
				self.sv.processingShape = screenData.shape
						
				self.sv.saved.front:setPublicData( { shape = self.sv.processingShape } )
				self.sv.saved.crateload:setPublicData( { activate = true } )
				self.network:sendToClients( "cl_n_startAnimation", { effect = screenData.effect } )

				break
			end
		end
	elseif self.sv.state == "processing" then
		self.sv.processingTimer = self.sv.processingTimer + timeStep
		
		if self.sv.processingTimer >= PackingStationMid.ProcessingTime then

			self.sv.processingTimer = 0
			self.sv.processingShape = nil
			self.sv.state = "idle"
		end
	end
end

-- Client

function PackingStationMid.cl_n_startAnimation( self, data ) 
	self.cl.running = true
	self.cl.animTimer = 0

	if self.cl.currentEffect ~= nil then
		self.cl.currentEffect:stop()
	end
	
	if self.cl.effectCache[data.effect] == nil then
		self.cl.effectCache[data.effect] = sm.effect.createEffect( data.effect, self.interactable, "package_jnt" )
	end
	self.cl.currentEffect = self.cl.effectCache[data.effect]
	self.cl.currentEffect:setScale( sm.vec3.new( 0.25, 0.25, 0.25 ) )
	self.cl.currentEffect:start()
	sm.effect.playEffect( "Packingstation - ActivateSound", self.shape.worldPosition )

	self.cl.activateEffect:start()
end

function PackingStationMid.client_onCreate( self )
	print("PackingStationMid.client_onCreate")
	self.cl = {}
	self.cl.currentAnim = "packingstation_activate"
	self.cl.currentDuration = self.interactable:getAnimDuration(self.cl.currentAnim)
	self.cl.animTimer = 0
	self.cl.running = false
	self.cl.effectCache = {}
	self.cl.activateEffect = sm.effect.createEffect( "Packingstation - Activate", self.interactable )
end

function PackingStationMid.client_onUpdate( self, dt )
	if self.cl.running == true then
		self.cl.animTimer = self.cl.animTimer+dt
		if self.cl.animTimer > self.cl.currentDuration then
			self.cl.animTimer = 0
			self.cl.running = false;
			self.cl.currentEffect:stop()
			self.cl.activateEffect:stop()
			self.cl.currentEffect = nil
		end
	
		self.interactable:setAnimEnabled( self.cl.currentAnim, true )
		self.interactable:setAnimProgress( self.cl.currentAnim, self.cl.animTimer / self.cl.currentDuration )
	end
end