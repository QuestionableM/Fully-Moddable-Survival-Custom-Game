ElevatorFan = class()
ElevatorFan.maxParentCount = 1
ElevatorFan.maxChildCount = 0
ElevatorFan.connectionInput = sm.interactable.connectionType.logic
ElevatorFan.connectionOutput = sm.interactable.connectionType.none
ElevatorFan.poseWeightCount = 1

function ElevatorFan.client_onCreate( self )
	self.progress = 0.0
end

function ElevatorFan.client_onUpdate( self, dt )
	self.progress = ( self.progress + dt ) % 1.0
	--self.interactable:setAnimEnabled( "animation_name", true )
	--self.interactable:setAnimProgress( "animation_name", self.progress )
end
