PackingStationCrateLoad = class( nil )

function PackingStationCrateLoad.server_onCreate( self )
end

function PackingStationCrateLoad.server_onFixedUpdate( self, timeStep )
	local data = self.interactable:getPublicData()
	if data and data.activate == true then
		self.network:sendToClients( "cl_n_startAnimation", {} )
		self.interactable:setPublicData({})
	end
end

-- Client

function PackingStationCrateLoad.cl_n_startAnimation( self, data )
	self.cl.animTimer = 0
	self.cl.running = true
end

function PackingStationCrateLoad.client_onCreate( self )
	self.cl = {}
	self.cl.currentAnim = "packingstation_activate"
	self.cl.currentDuration = self.interactable:getAnimDuration(self.cl.currentAnim)
	self.cl.animTimer = 0
	self.cl.running = false
end

function PackingStationCrateLoad.client_onUpdate( self, dt )
	if self.cl.running == true then
		self.cl.animTimer = self.cl.animTimer+dt
		if self.cl.animTimer > self.cl.currentDuration then
			self.cl.animTimer = 0
			self.cl.running = false;
		end
	
		self.interactable:setAnimEnabled( self.cl.currentAnim, true )
		self.interactable:setAnimProgress( self.cl.currentAnim, self.cl.animTimer / self.cl.currentDuration )
	end
end