-- HarvestableSoil.lua --
dofile "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

HarvestableSoil = class( nil )
HarvestableSoil.SoilFrames = 10
HarvestableSoil.WaterRetentionTickTime = 40 * DAYCYCLE_TIME * 1.5
HarvestableSoil.TimeStep = 0.025

-- Server
function HarvestableSoil.server_onCreate( self )
	
	self.sv = self.storage:load()
	if self.sv == nil then
		self.sv = {}
		self.sv.waterTicks = 0
		self.sv.fertilizer = false
		self.sv.lastTickUpdate = sm.game.getCurrentTick()
	end
	if self.params then
		if self.params.waterTicks then
			self.sv.waterTicks = self.params.waterTicks
		end
		if self.params.fertilizer then
			self.sv.fertilizer = self.params.fertilizer
		end
	end
	
	self:sv_performUpdate()
end

function HarvestableSoil.server_onReceiveUpdate( self )
	self:sv_performUpdate()
end

function HarvestableSoil.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	if projectileUuid == projectile_water then
		self:sv_performUpdate() -- Catch up to current time
		self.sv.waterTicks = self.WaterRetentionTickTime
		self:sv_performUpdate() -- Save and synch water
	elseif projectileUuid == projectile_fertilizer then
		self:sv_performUpdate() -- Catch up to current time
		self.sv.fertilizer = true
		self:sv_performUpdate() -- Save and synch fertilizer
	elseif projectileUuid == projectile_potato then
		self:sv_plant( { plantedHarvestableUuid = hvs_growing_potato } )
	elseif projectileUuid == projectile_seed then
		self:sv_plant( { plantedHarvestableUuid = userData.hvs } )
	end
end

function HarvestableSoil.sv_performUpdate( self )
	local currentTick = sm.game.getCurrentTick()
	local ticks = currentTick - self.sv.lastTickUpdate
	ticks = math.max( ticks, 0 )
	self.sv.lastTickUpdate = currentTick
	self:sv_updateTicks( ticks )
	
	self.storage:save( self.sv )
end

function HarvestableSoil.sv_updateTicks( self, ticks )
	self.sv.waterTicks = math.max( self.sv.waterTicks - ticks, 0 )
	self.storage:save( self.sv )
	self.network:setClientData( { waterTicks = self.sv.waterTicks, fertilizer = self.sv.fertilizer } )
end

function HarvestableSoil.sv_e_plant( self, params )
	if not self.sv.planted and sm.exists( self.harvestable ) then
		if sm.container.beginTransaction() then
			sm.container.spendFromSlot( params.playerInventory, params.slot, params.plantableUuid, 1, true )
			if sm.container.endTransaction() then
				self:sv_plant( { plantedHarvestableUuid = params.plantedHarvestableUuid } )
			end
		end
	end
end

function HarvestableSoil.sv_plant( self, params )
	if not self.sv.planted and sm.exists( self.harvestable ) then
		local plantedHarvestable = sm.harvestable.createHarvestable( params.plantedHarvestableUuid, sm.harvestable.getPosition( self.harvestable ), sm.harvestable.getRotation( self.harvestable ) )
		plantedHarvestable:setParams( { waterTicks = self.sv.waterTicks, fertilizer = self.sv.fertilizer } )
		sm.effect.playEffect( "Plants - Planted", sm.harvestable.getPosition( self.harvestable ) )
		sm.harvestable.destroy( self.harvestable )
		self.sv.planted = true
	end
end

function HarvestableSoil.sv_e_fertilize( self, params )
	if not self.sv.fertilizer then
		if sm.container.beginTransaction() then
			sm.container.spendFromSlot( params.playerInventory, params.slot, obj_consumable_fertilizer, 1, true )
			if sm.container.endTransaction() then
				self:sv_performUpdate() -- Catch up to current time
				self.sv.fertilizer = true
				self:sv_performUpdate() -- Save and synch fertilizer
			end
		end
	end
end

function HarvestableSoil.server_canErase( self ) return true end
function HarvestableSoil.client_canErase( self ) return true end

function HarvestableSoil.server_onRemoved( self, player )
	if not self.harvested and sm.exists( self.harvestable ) then
		local container = player:getInventory()
		if sm.container.beginTransaction() then
			sm.container.collect( container, obj_consumable_soilbag, 1 )
			if sm.container.endTransaction() then
				self.harvestable:destroy()
				self.harvested = true
			else
				self.network:sendToClient( player, "cl_n_onInventoryFull" )
			end
		end
	end
end

function HarvestableSoil.cl_n_onInventoryFull( self )
	sm.gui.displayAlertText( "#{INFO_INVENTORY_FULL}", 4 )
end


-- Client
function HarvestableSoil.client_onCreate( self )
	if self.cl == nil then
		self.cl = {}
		self.cl.waterTicks = 0
		self.cl.fertilizer = false
	end
	
	self.cl.fakeTickElapsedTime = 0
	self.cl.fertilizerEffect = sm.effect.createEffect( "Plants - Fertilizer" )
	self.cl.fertilizerEffect:setPosition( sm.harvestable.getPosition( self.harvestable ) )
	
	self.harvestable.clientPublicData = {}
end

function HarvestableSoil.client_onDestroy( self )
	self.cl.fertilizerEffect:stop()
end

function HarvestableSoil.client_onUpdate( self, dt )

	self.cl.fakeTickElapsedTime = self.cl.fakeTickElapsedTime + dt
	while self.cl.fakeTickElapsedTime > self.TimeStep do
		self.cl.fakeTickElapsedTime = self.cl.fakeTickElapsedTime - self.TimeStep
		self.cl.waterTicks = math.max( self.cl.waterTicks - 1, 0 )
	end
	
	local waterFraction = self.cl.waterTicks / self.WaterRetentionTickTime
	
	-- Visual uv scroll wetness
	local soilFrameIndex = math.ceil( waterFraction * ( self.SoilFrames - 1 ) )
	self.harvestable:setUvFrameIndex( soilFrameIndex )
	
	if self.cl.fertilizer then
		if not self.cl.fertilizerEffect:isPlaying() then
			self.cl.fertilizerEffect:start()
		end
	else
		if self.cl.fertilizerEffect:isPlaying() then
			self.cl.fertilizerEffect:stop()
		end
	end
	
end

function HarvestableSoil.client_onClientDataUpdate( self, clientData )
	if self.cl == nil then
		self.cl = {}
	end
	self.cl.waterTicks = clientData.waterTicks
	self.cl.fertilizer = clientData.fertilizer

	self.cl.fakeTickElapsedTime = 0
	self.harvestable.clientPublicData.fertilizer = self.cl.fertilizer
end