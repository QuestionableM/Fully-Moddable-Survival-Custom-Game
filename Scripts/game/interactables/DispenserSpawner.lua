DispenserSpawner = class()

function DispenserSpawner.client_onCreate( self )
	self.duration = self.interactable:getAnimDuration( "spawn" )
	self.time = 0
	self.anim = false
end

function DispenserSpawner.client_onRefresh( self )
	self.duration = self.interactable:getAnimDuration( "spawn" )
	self.time = 0
	self.anim = false
	self.interactable:setAnimEnabled( "spawn", false )
	self.interactable:setAnimProgress( "spawn", 0 )
end

function DispenserSpawner.server_onFixedUpdate( self, timeStep )
	-- Update active state
	if self.interactable.active then
		self.network:sendToClients( "cl_n_spawn" )
		self.interactable.active = false
	end
end

function DispenserSpawner.cl_n_spawn( self )
	self.interactable:setAnimEnabled( "spawn", true )
	self.interactable:setAnimProgress( "spawn", 0 )
	self.time = 0
	self.anim = true
	sm.effect.playEffect( "DispenserbotSpawner - Spawn", self.shape.worldPosition, nil, self.shape.worldRotation )
end

function DispenserSpawner.client_onUpdate( self, dt )

	if self.anim then
		self.time = self.time + dt
		if self.time > self.duration then
			self.time = 0
			self.anim = false
			self.interactable:setAnimEnabled( "spawn", false )
		else
			self.interactable:setAnimProgress( "spawn", self.time / self.duration )
		end
	end
end







