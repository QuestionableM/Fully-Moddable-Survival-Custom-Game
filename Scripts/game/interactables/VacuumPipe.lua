VacuumPipe = class()
function VacuumPipe.client_onFixedUpdate( self )
	self.shape:getInteractable():setUvFrameIndex( 0 )
	self.shape:getInteractable():setGlowMultiplier( 1.0 )
end
