dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")

HideoutVacuum = class()

function HideoutVacuum.client_onCreate( self )
	self.vacuumTime = self.interactable:getAnimDuration( "dropoff_activate" )
	self.vacuumElapsed = 0.0
	self.interactable:setAnimEnabled( "dropoff_activate", true )
	self.wasActive = false
	self.vacuumEffect = sm.effect.createEffect( "Hideout - PumpSuction", self.shape.interactable, "suction3_jnt" )
end

function HideoutVacuum.client_onUpdate( self, dt )
	if self.shape.interactable.active then
		self.vacuumElapsed = math.min( self.vacuumElapsed + dt, self.vacuumTime )
		if not self.wasActive then
			self.vacuumEffect:start()
		end
	else
		self.vacuumElapsed = 0.0
	end
	self.interactable:setAnimProgress( "dropoff_activate", self.vacuumElapsed / self.vacuumTime )
	self.wasActive = self.shape.interactable.active
end
