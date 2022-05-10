-- Seat.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/interactables/Seat.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")

DriverSeat = class( Seat )
DriverSeat.maxChildCount = 20
DriverSeat.connectionOutput = sm.interactable.connectionType.seated + sm.interactable.connectionType.power + sm.interactable.connectionType.bearing
DriverSeat.colorNormal = sm.color.new( 0x80ff00ff )
DriverSeat.colorHighlight = sm.color.new( 0xb4ff68ff )

local SpeedPerStep = 1 / math.rad( 27 ) / 3

DriverSeat.Levels = {
	[tostring(obj_scrap_driverseat)] = { maxConnections = 4, allowAdjustingJoints = false },
	[tostring(obj_interactive_driverseat_01)] = { maxConnections = 6, allowAdjustingJoints = false, upgrade = obj_interactive_driverseat_02, cost = 1, title = "#{LEVEL} 1" },
	[tostring(obj_interactive_driverseat_02)] = { maxConnections = 8, allowAdjustingJoints = false, upgrade = obj_interactive_driverseat_03, cost = 2, title = "#{LEVEL} 2" },
	[tostring(obj_interactive_driverseat_03)] = { maxConnections = 12, allowAdjustingJoints = false, upgrade = obj_interactive_driverseat_04, cost = 3, title = "#{LEVEL} 3" },
	[tostring(obj_interactive_driverseat_04)] = { maxConnections = 16, allowAdjustingJoints = false, upgrade = obj_interactive_driverseat_05, cost = 5, title = "#{LEVEL} 4" },
	[tostring(obj_interactive_driverseat_05)] = { maxConnections = 20, allowAdjustingJoints = true, title = "#{LEVEL} 5" },
}

function DriverSeat.server_onCreate( self )
	Seat:server_onCreate( self )
end

function DriverSeat.server_onFixedUpdate( self )
	Seat.server_onFixedUpdate( self )
	if self.interactable:isActive() then
		self.interactable:setPower( self.interactable:getSteeringPower() )
	else
		self.interactable:setPower( 0 )
		self.interactable:setSteeringFlag( 0 )
	end
end

function DriverSeat.client_onInteract( self, character, state )
	if state then
		self:cl_seat()
		if self.shape.interactable:getSeatCharacter() ~= nil then
			sm.gui.displayAlertText( "#{ALERT_DRIVERS_SEAT_OCCUPIED}", 4.0 )
		elseif self.shape.body:isOnLift() then
			sm.gui.displayAlertText( "#{ALERT_DRIVERS_SEAT_ON_LIFT}", 8.0 )
		end
	end
end

function DriverSeat.client_canInteractThroughJoint( self )
	if not self.shape.body.connectable then
		return false
	end
	local level = self.Levels[tostring( self.shape:getShapeUuid() )]
	return level.allowAdjustingJoints
end

function DriverSeat.client_onInteractThroughJoint( self, character, state, joint )
	local level = self.Levels[tostring( self.shape:getShapeUuid() )]

	if level.allowAdjustingJoints then
		self.cl.bearingGui = sm.gui.createSteeringBearingGui()
		self.cl.bearingGui:open()
		self.cl.bearingGui:setOnCloseCallback( "cl_onGuiClosed" )

		self.cl.currentJoint = joint

		self.cl.bearingGui:setSliderCallback("LeftAngle", "cl_onLeftAngleChanged")
		self.cl.bearingGui:setSliderData("LeftAngle", 120, self.interactable:getSteeringJointLeftAngleLimit( joint ) - 1 )

		self.cl.bearingGui:setSliderCallback("RightAngle", "cl_onRightAngleChanged")
		self.cl.bearingGui:setSliderData("RightAngle", 120, self.interactable:getSteeringJointRightAngleLimit( joint ) - 1 )

		local leftSpeedValue = self.interactable:getSteeringJointLeftAngleSpeed( joint ) / SpeedPerStep
		local rightSpeedValue = self.interactable:getSteeringJointRightAngleSpeed( joint ) / SpeedPerStep

		self.cl.bearingGui:setSliderCallback("LeftSpeed", "cl_onLeftSpeedChanged")
		self.cl.bearingGui:setSliderData("LeftSpeed", 10, leftSpeedValue - 1)

		self.cl.bearingGui:setSliderCallback("RightSpeed", "cl_onRightSpeedChanged")
		self.cl.bearingGui:setSliderData("RightSpeed", 10, rightSpeedValue - 1)

		local unlocked = self.interactable:getSteeringJointUnlocked( joint )

		if unlocked then
			self.cl.bearingGui:setButtonState( "Off", true )
		else
			self.cl.bearingGui:setButtonState( "On", true )
		end

		self.cl.bearingGui:setButtonCallback( "On", "cl_onLockButtonClicked" )
		self.cl.bearingGui:setButtonCallback( "Off", "cl_onLockButtonClicked" )

		--print("Character "..character:getId().." interacted with joint "..joint:getId())
	else
		print("Joint settings only allowed on level 5!")
	end
end

function DriverSeat.client_onAction( self, controllerAction, state )
	if state == true then
		if controllerAction == sm.interactable.actions.forward then
			self.interactable:setSteeringFlag( sm.interactable.steering.forward )
		elseif controllerAction == sm.interactable.actions.backward then
			self.interactable:setSteeringFlag( sm.interactable.steering.backward )
		elseif controllerAction == sm.interactable.actions.left then
			self.interactable:setSteeringFlag( sm.interactable.steering.left )
		elseif controllerAction == sm.interactable.actions.right then
			self.interactable:setSteeringFlag( sm.interactable.steering.right )
		else
			return Seat.client_onAction( self, controllerAction, state )
		end
	else
		if controllerAction == sm.interactable.actions.forward then
			self.interactable:unsetSteeringFlag( sm.interactable.steering.forward )
		elseif controllerAction == sm.interactable.actions.backward then
			self.interactable:unsetSteeringFlag( sm.interactable.steering.backward )
		elseif controllerAction == sm.interactable.actions.left then
			self.interactable:unsetSteeringFlag( sm.interactable.steering.left )
		elseif controllerAction == sm.interactable.actions.right then
			self.interactable:unsetSteeringFlag( sm.interactable.steering.right )
		else
			return Seat.client_onAction( self, controllerAction, state )
		end
	end
	return true
end

function DriverSeat.client_getAvailableChildConnectionCount( self, connectionType )

	local level = self.Levels[tostring( self.shape:getShapeUuid() )]
	assert( level )

	local filter = sm.interactable.connectionType.seated + sm.interactable.connectionType.bearing + sm.interactable.connectionType.power
	local currentConnectionCount = #self.interactable:getChildren( filter )

	if bit.band( connectionType, filter ) then
		local availableChildCount = level.maxConnections or 255
		return availableChildCount - currentConnectionCount
	end
	return 0
end

function DriverSeat.client_onCreate( self )
	Seat.client_onCreate( self )
	self.animWeight = 0.5
	self.interactable:setAnimEnabled("j_ratt", true)

	self.cl = {}
	self.cl.updateDelay = 0.0
	self.cl.updateSettings = {}
end


function DriverSeat.client_onFixedUpdate( self, timeStep )
	if self.cl.updateDelay > 0.0 then
		self.cl.updateDelay = math.max( 0.0, self.cl.updateDelay - timeStep )

		if self.cl.updateDelay == 0 then
			self:cl_applyBearingSettings()
			self.cl.updateSettings = {}
			self.cl.updateGuiCooldown = 0.2
		end
	else
		if self.cl.updateGuiCooldown then
			self.cl.updateGuiCooldown = self.cl.updateGuiCooldown - timeStep
			if self.cl.updateGuiCooldown <= 0 then
				self.cl.updateGuiCooldown = nil
			end
		end
		if not self.cl.updateGuiCooldown then
			self:cl_updateBearingGuiValues()
		end
	end
end

function DriverSeat.client_onUpdate( self, dt )
	Seat.client_onUpdate( self, dt )

	local steeringAngle = self.interactable:getSteeringAngle();
	local angle = self.animWeight * 2.0 - 1.0 -- Convert anim weight 0,1 to angle -1,1

	if angle < steeringAngle then
		angle = min( angle + 4.2441*dt, steeringAngle )
	elseif angle > steeringAngle then
		angle = max( angle - 4.2441*dt, steeringAngle )
	end

	self.animWeight = angle * 0.5 + 0.5; -- Convert back to 0,1
	self.interactable:setAnimProgress("j_ratt", self.animWeight)
end

function DriverSeat.cl_onLeftAngleChanged( self, sliderName, sliderPos )
	self.cl.updateSettings.leftAngle = sliderPos + 1
	self.cl.updateDelay = 0.1
end

function DriverSeat.cl_onRightAngleChanged( self, sliderName, sliderPos )
	self.cl.updateSettings.rightAngle = sliderPos + 1
	self.cl.updateDelay = 0.1
end

function DriverSeat.cl_onLeftSpeedChanged( self, sliderName, sliderPos )
	self.cl.updateSettings.leftSpeed = ( sliderPos + 1 ) * SpeedPerStep
	self.cl.updateDelay = 0.1
end

function DriverSeat.cl_onRightSpeedChanged( self, sliderName, sliderPos )
	self.cl.updateSettings.rightSpeed = ( sliderPos + 1 ) * SpeedPerStep
	self.cl.updateDelay = 0.1
end

function DriverSeat.cl_onLockButtonClicked( self, buttonName )
	self.cl.updateSettings.unlocked = buttonName == "Off"
	self.cl.updateDelay = 0.1
end

function DriverSeat.cl_onGuiClosed( self )
	if self.cl.updateDelay > 0.0 then
		self:cl_applyBearingSettings()
		self.cl.updateSettings = {}
		self.cl.updateDelay = 0.0
		self.cl.currentJoint = nil
	end
	self.cl.bearingGui:destroy()
	self.cl.bearingGui = nil
end

function DriverSeat.cl_applyBearingSettings( self )

	assert( self.cl.currentJoint )

	if self.cl.updateSettings.leftAngle then
		self.interactable:setSteeringJointLeftAngleLimit( self.cl.currentJoint, self.cl.updateSettings.leftAngle )
	end

	if self.cl.updateSettings.rightAngle then
		self.interactable:setSteeringJointRightAngleLimit( self.cl.currentJoint, self.cl.updateSettings.rightAngle )
	end

	if self.cl.updateSettings.leftSpeed then
		self.interactable:setSteeringJointLeftAngleSpeed( self.cl.currentJoint, self.cl.updateSettings.leftSpeed )
	end

	if self.cl.updateSettings.rightSpeed then
		self.interactable:setSteeringJointRightAngleSpeed( self.cl.currentJoint, self.cl.updateSettings.rightSpeed )
	end

	if self.cl.updateSettings.unlocked ~= nil then
		self.interactable:setSteeringJointUnlocked( self.cl.currentJoint, self.cl.updateSettings.unlocked )
	end
end

function DriverSeat.cl_updateBearingGuiValues( self )
	if self.cl.bearingGui and self.cl.bearingGui:isActive() then

		local leftSpeed, rightSpeed, leftAngle, rightAngle, unlocked = self.interactable:getSteeringJointSettings( self.cl.currentJoint )

		if leftSpeed and rightSpeed and leftAngle and rightAngle and unlocked ~= nil then
			self.cl.bearingGui:setSliderPosition( "LeftAngle", leftAngle - 1 )
			self.cl.bearingGui:setSliderPosition( "RightAngle", rightAngle - 1 )
			self.cl.bearingGui:setSliderPosition( "LeftSpeed", ( leftSpeed / SpeedPerStep ) - 1 )
			self.cl.bearingGui:setSliderPosition( "RightSpeed", ( rightSpeed / SpeedPerStep ) - 1 )

			if unlocked then
				self.cl.bearingGui:setButtonState( "Off", true )
			else
				self.cl.bearingGui:setButtonState( "On", true )
			end
		end
	end
end

DriverSaddle = class( DriverSeat )
DriverSaddle.Levels = {
	[tostring(obj_interactive_driversaddle_01)] = { maxConnections = 6, allowAdjustingJoints = false, upgrade = obj_interactive_driversaddle_02, cost = 1, title = "#{LEVEL} 1" },
	[tostring(obj_interactive_driversaddle_02)] = { maxConnections = 8, allowAdjustingJoints = false, upgrade = obj_interactive_driversaddle_03, cost = 2, title = "#{LEVEL} 2" },
	[tostring(obj_interactive_driversaddle_03)] = { maxConnections = 12, allowAdjustingJoints = false, upgrade = obj_interactive_driversaddle_04, cost = 3, title = "#{LEVEL} 3" },
	[tostring(obj_interactive_driversaddle_04)] = { maxConnections = 16, allowAdjustingJoints = false, upgrade = obj_interactive_driversaddle_05, cost = 5, title = "#{LEVEL} 4" },
	[tostring(obj_interactive_driversaddle_05)] = { maxConnections = 20, allowAdjustingJoints = true, title = "#{LEVEL} 5" },
}