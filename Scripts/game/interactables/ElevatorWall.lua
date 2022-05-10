ElevatorWall = class()
ElevatorWall.maxParentCount = 1
ElevatorWall.maxChildCount = 0
ElevatorWall.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
ElevatorWall.connectionOutput = sm.interactable.connectionType.none
ElevatorWall.poseWeightCount = 1

function ElevatorWall.client_onCreate( self )
	self.pose = 0.0
end

function ElevatorWall.client_onUpdate( self, dt )
	local parent = self.interactable:getSingleParent()
	local power = parent:getPower()
	self.pose = ( self.pose + dt * 0.2 * power ) % 1.0
	self.interactable:setPoseWeight( 0, self.pose )
end
