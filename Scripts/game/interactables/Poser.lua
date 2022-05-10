Poser = class()
Poser.poseWeightCount = 1

function Poser.client_onCreate( self )
	if self.data then
		self.poseTime = self.data.poseTime
		self.poseInverted = self.data.poseInverted
	end
	self.poseProgress = 0
end

function Poser.client_onUpdate( self, dt )
	if self.poseProgress < 1.0 then
		self.poseProgress = self.poseProgress + dt / self.poseTime
		self.poseProgress = math.min( self.poseProgress, 1.0 )
		local poseWeight = self.poseInverted and ( 1.0 - self.poseProgress ) or self.poseProgress
		self.interactable:setPoseWeight( 0, poseWeight )
	end
end
