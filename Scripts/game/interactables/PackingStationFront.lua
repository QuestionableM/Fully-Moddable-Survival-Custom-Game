PackingStationFront = class( nil )

PackingStationFront.FireTime = 4.25 -- Matched current animation

function PackingStationFront.server_onCreate( self )
	self.sv = {}
	self.sv.fireTimer = 0
	self.sv.shapeQueue = {}
end

function PackingStationFront.server_onFixedUpdate( self, timeStep )
	local data = self.interactable:getPublicData()
	if data and data.shape then
		local shape = data.shape;
		self.interactable:setPublicData({})
		self.sv.shapeQueue[#self.sv.shapeQueue+1] = shape
	end

	if #self.sv.shapeQueue > 0 then

		if self.sv.fireTimer == 0 then
			self.network:sendToClients( "cl_n_startAnimation", {} )
		end

		self.sv.fireTimer = self.sv.fireTimer+timeStep

		if self.sv.fireTimer > PackingStationFront.FireTime then
			local shape = self.sv.shapeQueue[1]
			local direction = ( self.shape.at * 0.3 ) + ( self.shape.up * 0.5 );
			local spawnPos = self.shape:getWorldPosition() + direction
			local newShape = sm.shape.createPart( shape, spawnPos, self.shape:getWorldRotation(), true, true )

			sm.physics.applyImpulse( newShape, direction:normalize() * newShape:getMass() * 10, true )

			self.sv.fireTimer = 0
			table.remove( self.sv.shapeQueue, 1 ) -- pop front
		end
	end
end

-- Client

function PackingStationFront.cl_n_startAnimation( self, data ) 
	self.cl.running = true
	self.cl.rollerEffect:start()
	self.cl.fired = false
	self.cl.animTimer = 0.0
end

function PackingStationFront.client_onCreate( self )
	self.cl = {}
	self.cl.currentAnim = "packingstation_activate"
	self.cl.currentDuration = self.interactable:getAnimDuration(self.cl.currentAnim)
	self.cl.animTimer = 0
	self.cl.running = false
	self.cl.fired = false
	self.cl.shootEffect = sm.effect.createEffect( "Packingstation - Shoot", self.interactable, "out_pejnt" )
	self.cl.rollerEffect = sm.effect.createEffect( "Packingstation - Roller", self.interactable, "out_pejnt" )

end

function PackingStationFront.client_onUpdate( self, dt )
	if self.cl.running == true then
		self.cl.animTimer = self.cl.animTimer+dt

		if self.cl.fired == false and self.cl.animTimer > PackingStationFront.FireTime then
			self.cl.shootEffect:start()
			self.cl.rollerEffect:stop()
			self.cl.fired = true
		end

		if self.cl.animTimer > self.cl.currentDuration then
			self.cl.animTimer = 0
			self.cl.running = false
			self.cl.shootEffect:stop()
		end
	
		self.interactable:setAnimEnabled( self.cl.currentAnim, true )
		self.interactable:setAnimProgress( self.cl.currentAnim, self.cl.animTimer / self.cl.currentDuration )
	end
end