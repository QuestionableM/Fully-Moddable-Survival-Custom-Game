dofile("$SURVIVAL_DATA/Scripts/game/survival_loot.lua")

GrowingOilGeyser = class()

local GrowTickTime = DAYCYCLE_TIME_TICKS * 2.5

-- Server
function GrowingOilGeyser.server_onCreate( self )
	self.sv = self.storage:load()
	if self.sv == nil then
		self.sv = {}
		self.sv.lastTickUpdate = sm.game.getCurrentTick()
		self.sv.growTicks = 0
	end
end

function GrowingOilGeyser.server_onReceiveUpdate( self )
	self:sv_performUpdate()
end

function GrowingOilGeyser.sv_performUpdate( self )
	local currentTick = sm.game.getCurrentTick()
	local ticks = currentTick - self.sv.lastTickUpdate
	ticks = math.max( ticks, 0 )
	self.sv.lastTickUpdate = currentTick
	self:sv_updateTicks( ticks )
	
	self.storage:save( self.sv )
end

function GrowingOilGeyser.sv_updateTicks( self, ticks )
	if not self.sv.regrown and sm.exists( self.harvestable ) then
		self.sv.growTicks = math.min( self.sv.growTicks + ticks, GrowTickTime )
		local growFraction = self.sv.growTicks / GrowTickTime
		if growFraction >= 1.0 then
			sm.harvestable.createHarvestable( hvs_farmables_oilgeyser, self.harvestable.worldPosition, self.harvestable.worldRotation )
			sm.harvestable.destroy( self.harvestable )
			self.sv.regrown = true
		end
	end
end

function GrowingOilGeyser.client_onCreate( self )
	self.cl = {}
	self.cl.activeGeyser = sm.effect.createEffect( "Oilgeyser - OilgeyserPickedLoop" )
	self.cl.activeGeyser:setPosition( self.harvestable.worldPosition )
	self.cl.activeGeyser:setRotation( self.harvestable.worldRotation )
	self.cl.activeGeyser:start()
end

function GrowingOilGeyser.client_onDestroy( self )
	self.cl.activeGeyser:stop()
	self.cl.activeGeyser:destroy()
end