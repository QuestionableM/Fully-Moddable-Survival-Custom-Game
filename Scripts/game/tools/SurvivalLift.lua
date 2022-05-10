dofile "$GAME_DATA/Scripts/game/Lift.lua"

SurvivalLift = class( Lift )

function SurvivalLift.client_onCreate( self )
	self:client_init()
	if self.tool:isLocal() then
		self.prevCarry = false
		self.carry = false
	end
end

function SurvivalLift.client_onUpdate( self, dt )
	if self.tool:isLocal() then
		self.prevCarry = self.carry
		self.carry = self.selectedBodies and #self.selectedBodies > 0 and self.equipped
		if self.carry ~= self.prevCarry then
			self.network:sendToServer( "sv_n_setCarryingState", self.carry )
		end
		self.tool:setBlockSprint( self.carry )
	end
end

local CarryTickThreshold = 30
local StaminaCost = 1.4 / 40 -- Per tick while carrying

function SurvivalLift.server_onCreate( self )
	self.sv = {}
	self.sv.carry = false
	self.sv.carryTicks = 0
end

function SurvivalLift.sv_n_setCarryingState( self, state )
	self.sv.carry = state
end

function SurvivalLift.server_onFixedUpdate( self, timeStep )
	if self.sv.carry then
		self.sv.carryTicks = self.sv.carryTicks + 1
		if self.sv.carryTicks >= CarryTickThreshold then
			self.sv.carryTicks = self.sv.carryTicks - CarryTickThreshold
			local owner = self.tool:getOwner()
			if owner then
				sm.event.sendToPlayer( owner, "sv_e_staminaSpend", StaminaCost * CarryTickThreshold )
			end
		end
	end
end