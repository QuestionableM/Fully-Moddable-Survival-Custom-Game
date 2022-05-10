-- GlowstickRemains.lua --
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"

GlowstickRemains = class( nil )

function GlowstickRemains.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.ticksLeftInWorld = math.max( getTicksUntilDayCycleFraction( 6 / 24 ), getTicksUntilDayCycleFraction( 18 / 24 ) )
		self.sv.saved.lastTickUpdate = sm.game.getCurrentTick()
		self.storage:save( self.sv.saved )
	end
end

function GlowstickRemains.server_onUnload( self )
	self.storage:save( self.sv.saved )
end

function GlowstickRemains.server_onReceiveUpdate( self )
	local currentTick = sm.game.getCurrentTick()
	local ticks = currentTick - self.sv.saved.lastTickUpdate
	ticks = math.max( ticks, 0 )
	self.sv.saved.lastTickUpdate = currentTick

	-- Destroy the remains if it has existed for too long
	self.sv.saved.ticksLeftInWorld = self.sv.saved.ticksLeftInWorld - ticks
	if self.sv.saved.ticksLeftInWorld <= 0 then
		if not self.sv.removed then
			self.sv.removed = true
			sm.harvestable.destroy( self.harvestable )
		end
	else
		self.storage:save( self.sv.saved )
	end
end

function GlowstickRemains.server_canErase( self ) return true end
function GlowstickRemains.client_canErase( self ) return true end

function GlowstickRemains.server_onRemoved( self, player )
	if not self.sv.removed then
		self.sv.removed = true
		sm.harvestable.destroy( self.harvestable )
		sm.effect.playEffect( "GlowstickProjectile - Bounce",  self.harvestable.worldPosition, nil, self.harvestable.worldRotation )
	end
end

function GlowstickRemains.client_onCreate( self )
	self.cl = {}
	self.cl.glowEffect = sm.effect.createEffect( "GlowstickProjectile - Hit" )
	self.cl.glowEffect:setPosition( self.harvestable.worldPosition )
	self.cl.glowEffect:setRotation( self.harvestable.worldRotation )
	self.cl.glowEffect:start()
end

function GlowstickRemains.client_onDestroy( self )
	self.cl.glowEffect:stop()
	self.cl.glowEffect:destroy()
end

function GlowstickRemains.client_onInteract( self, state ) end

function GlowstickRemains.client_canInteract( self )
	sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Attack", true ), "#{INTERACTION_DESTROY}" )
	return false
end
