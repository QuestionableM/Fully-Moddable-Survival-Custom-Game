dofile "$SURVIVAL_DATA/Scripts/game/survival_loot.lua"

BrokenBeeHive = class()

local GrowTickTime = DAYCYCLE_TIME_TICKS * 2.5

-- Server
function BrokenBeeHive.server_onCreate( self )
	self.sv = self.storage:load()
	if self.sv == nil then
		self.sv = {}
		self.sv.lastTickUpdate = sm.game.getCurrentTick()
		self.sv.growTicks = 0
	end
end

function BrokenBeeHive.server_onReceiveUpdate( self )
	self:sv_performUpdate()
end

function BrokenBeeHive.sv_performUpdate( self )
	local currentTick = sm.game.getCurrentTick()
	local ticks = currentTick - self.sv.lastTickUpdate
	ticks = math.max( ticks, 0 )
	self.sv.lastTickUpdate = currentTick
	self:sv_updateTicks( ticks )

	self.storage:save( self.sv )
end

function BrokenBeeHive.sv_updateTicks( self, ticks )
	if not self.sv.repairedHive and sm.exists( self.harvestable ) then
		self.sv.growTicks = math.min( self.sv.growTicks + ticks, GrowTickTime )
		local growFraction = self.sv.growTicks / GrowTickTime
		if growFraction >= 1.0 then
			sm.harvestable.createHarvestable( hvs_farmables_beehive, self.harvestable.worldPosition, self.harvestable.worldRotation )
			sm.harvestable.destroy( self.harvestable )
			self.sv.repairedHive = true
			return
		end
	end
end

-- Client
function BrokenBeeHive.client_onCreate( self )
	self.cl = {}
	self.cl.swarmEffect = sm.effect.createEffect( "beehive - beeswarm" )
	self.cl.swarmEffect:setPosition( self.harvestable.worldPosition )
	self.cl.swarmEffect:setRotation( self.harvestable.worldRotation )
	self.cl.swarmEffect:start()
end

function BrokenBeeHive.client_onDestroy( self )
	self.cl.swarmEffect:stop()
end