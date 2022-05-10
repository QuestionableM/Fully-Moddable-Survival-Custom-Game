-- GrowingHarvestable.lua --
dofile "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua"

GrowingHarvestable = class( nil )
GrowingHarvestable.poseWeightCount = 2
GrowingHarvestable.SoilFrames = 10
GrowingHarvestable.WaterRetentionTickTime = 40 * DAYCYCLE_TIME * 1.5
GrowingHarvestable.TimeStep = 0.025

-- Server
function GrowingHarvestable.server_onCreate( self )
	
	self.sv = self.storage:load()
	if self.sv == nil then
		self.sv = {}
		self.sv.waterTicks = 0.0
		self.sv.fertilizer = false
		self.sv.lastTickUpdate = sm.game.getCurrentTick()
		self.sv.growTicks = 0
	end
	if self.params then
		if self.params.waterTicks then
			self.sv.waterTicks = self.params.waterTicks
		end
		if self.params.fertilizer then
			self.sv.fertilizer = self.params.fertilizer
		end
	end
	
	if self.data then
		if self.data.daysToGrow then
			self.sv.growTickTime = 40 * DAYCYCLE_TIME * self.data.daysToGrow -- growTime from days to ticks
		end
		if self.data.harvestable then
			self.sv.matureUid = sm.uuid.new( self.data.harvestable )
		end
	end
	
	self:sv_performUpdate()
end

function GrowingHarvestable.server_onReceiveUpdate( self )
	self:sv_performUpdate()
end

function GrowingHarvestable.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
	if not self.sv.harvested and sm.exists( self.harvestable ) then
		sm.effect.playEffect( "Plants - Destroyed", sm.harvestable.getPosition( self.harvestable ) )
		sm.harvestable.createHarvestable( hvs_soil, sm.harvestable.getPosition( self.harvestable ), sm.harvestable.getRotation( self.harvestable ) )
		sm.harvestable.destroy( self.harvestable )
		self.sv.harvested = true
	end
end

function GrowingHarvestable.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	if projectileUuid == projectile_water then
		self:sv_performUpdate() -- Catch up to current time
		self.sv.waterTicks = self.WaterRetentionTickTime
		self:sv_performUpdate() -- Save and synch water
	elseif projectileUuid == projectile_fertilizer then
		self:sv_performUpdate() -- Catch up to current time
		self.sv.fertilizer = true
		self:sv_performUpdate() -- Save and synch fertilizer






	elseif type( attacker ) == "Unit" then
		if not self.sv.harvested and sm.exists( self.harvestable ) then
			sm.effect.playEffect( "Plants - Destroyed", sm.harvestable.getPosition( self.harvestable ) )
			sm.harvestable.createHarvestable( hvs_soil, sm.harvestable.getPosition( self.harvestable ), sm.harvestable.getRotation( self.harvestable ) )
			sm.harvestable.destroy( self.harvestable )
			self.sv.harvested = true
		end
	end
end

function GrowingHarvestable.sv_performUpdate( self )
	local currentTick = sm.game.getCurrentTick()
	local ticks = currentTick - self.sv.lastTickUpdate
	ticks = math.max( ticks, 0 )
	self.sv.lastTickUpdate = currentTick
	self:sv_updateTicks( ticks )
	
	self.storage:save( self.sv )
end

function GrowingHarvestable.sv_updateTicks( self, ticks )
	if not self.sv.harvested and sm.exists( self.harvestable ) then
		if self.sv.waterTicks > 0 then
			self.sv.growTicks = math.min( self.sv.growTicks + ticks * ( self.sv.fertilizer and 2 or 1 ), self.sv.growTickTime )
		end
		self.sv.waterTicks = math.max( self.sv.waterTicks - ticks, 0 )
		
		local growFraction = self.sv.growTicks / self.sv.growTickTime
		if growFraction >= 1.0 then
			sm.effect.playEffect( "Plants - Done", sm.harvestable.getPosition( self.harvestable ) )
			local worldPos = sm.harvestable.getPosition( self.harvestable )
			local worldRot = sm.harvestable.getRotation( self.harvestable )
			if self.sv.matureUid then
				sm.harvestable.createHarvestable( self.sv.matureUid, worldPos, worldRot )
			end
			sm.harvestable.destroy( self.harvestable )
			self.sv.harvested = true
			return
		end
		
		self.storage:save( self.sv )
		self.network:setClientData( { waterTicks = self.sv.waterTicks, fertilizer = self.sv.fertilizer, growTicks = self.sv.growTicks } )
	end
end

function GrowingHarvestable.sv_e_fertilize( self, params )
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

-- Client
function GrowingHarvestable.client_onCreate( self )
	if self.cl == nil then
		self.cl = {}
		self.cl.waterTicks = 0
		self.cl.fertilizer = false
		self.cl.growTicks = 0
	end
	
	if self.data then
		if self.data.daysToGrow then
			self.cl.growTickTime = 40 * DAYCYCLE_TIME * self.data.daysToGrow -- growTime from days to ticks
		end
	end
	
	self.cl.fakeTickElapsedTime = 0
	self.cl.fertilizerEffect = sm.effect.createEffect( "Plants - Fertilizer" )
	self.cl.fertilizerEffect:setPosition( sm.harvestable.getPosition( self.harvestable ) )

	self.harvestable.clientPublicData = {}
end

function GrowingHarvestable.client_onDestroy( self )
	self.cl.fertilizerEffect:stop()
end

function GrowingHarvestable.client_onUpdate( self, dt )

	self.cl.fakeTickElapsedTime = self.cl.fakeTickElapsedTime + dt
	while self.cl.fakeTickElapsedTime > self.TimeStep do
		self.cl.fakeTickElapsedTime = self.cl.fakeTickElapsedTime - self.TimeStep
		if self.cl.waterTicks > 0 then
			self.cl.growTicks = math.min( self.cl.growTicks + ( self.cl.fertilizer and 2 or 1 ), self.cl.growTickTime )
		end
		self.cl.waterTicks = math.max( self.cl.waterTicks - 1, 0 )
	end
	
	local waterFraction = self.cl.waterTicks / self.WaterRetentionTickTime
	
	-- Visual uv scroll wetness
	local soilFrameIndex = math.ceil( waterFraction * ( self.SoilFrames - 1 ) )
	self.harvestable:setUvFrameIndex( soilFrameIndex )
	
	-- Visual growth progress
	local growFraction = self.cl.growTicks / self.cl.growTickTime
	--Blend from 1.0 to 0.0 over the course of 0 to 0.5 of the growth progress
	local firstWeight = 1.0 - math.min( math.max( growFraction * 2, 0 ), 1 )
	--Blend from 0.0 to 1.0 over the course of 0.5 to 1.0 of the growth progress
	local secondWeight = math.min( math.max( growFraction - 0.5, 0 ), 0.5 ) * 2
	self.harvestable:setPoseWeight( 0, firstWeight )
	self.harvestable:setPoseWeight( 1, secondWeight )
	
	-- Fertilizer effect
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

function GrowingHarvestable.client_onClientDataUpdate( self, clientData )
	if self.cl == nil then
		self.cl = {}
	end
	self.cl.waterTicks = clientData.waterTicks
	self.cl.fertilizer = clientData.fertilizer
	self.cl.growTicks = clientData.growTicks
	
	self.cl.fakeTickElapsedTime = 0
	self.harvestable.clientPublicData.fertilizer = self.cl.fertilizer
end