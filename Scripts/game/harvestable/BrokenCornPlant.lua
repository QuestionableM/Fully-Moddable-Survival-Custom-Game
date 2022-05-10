dofile "$SURVIVAL_DATA/Scripts/game/survival_loot.lua"

BrokenCornPlant = class()

local GrowTickTime = DAYCYCLE_TIME_TICKS * 2.5

-- Server
function BrokenCornPlant.server_onCreate( self )
	self.sv = self.storage:load()
	if self.sv == nil then
		self.sv = {}
		self.sv.lastTickUpdate = sm.game.getCurrentTick()
		self.sv.growTicks = 0
	end
end

function BrokenCornPlant.server_onReceiveUpdate( self )
	self:sv_performUpdate()
end

function BrokenCornPlant.sv_performUpdate( self )
	local currentTick = sm.game.getCurrentTick()
	local ticks = currentTick - self.sv.lastTickUpdate
	ticks = math.max( ticks, 0 )
	self.sv.lastTickUpdate = currentTick
	self:sv_updateTicks( ticks )

	self.storage:save( self.sv )
end

function BrokenCornPlant.sv_updateTicks( self, ticks )
	if not self.sv.repairedCorn and sm.exists( self.harvestable ) then
		self.sv.growTicks = math.min( self.sv.growTicks + ticks, GrowTickTime )
		local growFraction = self.sv.growTicks / GrowTickTime
		if growFraction >= 1.0 then
			sm.harvestable.createHarvestable( hvs_farmables_cornplant, self.harvestable.worldPosition, self.harvestable.worldRotation )
			sm.harvestable.destroy( self.harvestable )
			self.sv.repairedCorn = true
			return
		end
	end
end