-- Shared
dofile( "$SURVIVAL_DATA/Scripts/game/util/Curve.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

PackingStationScreen = class( nil )
PackingStationScreen.poseWeightCount = 2

local veggie_dataset = {
	{ projectileUuid = projectile_broccoli, fullAmount = 10, shape = obj_crates_broccoli, effect = "Packingstation - Brocolicrate" },
	{ projectileUuid = projectile_carrot, fullAmount = 10, shape = obj_crates_carrot, effect = "Packingstation - Carrotcrate" },
	{ projectileUuid = projectile_redbeet, fullAmount = 10, shape = obj_crates_redbeet, effect = "Packingstation - Redbeetcrate" },
	{ projectileUuid = projectile_tomato, fullAmount = 10, shape = obj_crates_tomato, effect = "Packingstation - Tomatocrate" }
}

local fruit_dataset = {
	{ projectileUuid = projectile_banana, fullAmount = 10, shape = obj_crates_banana, effect = "Packingstation - Bananacrate" },
	{ projectileUuid = projectile_blueberry, fullAmount = 10, shape = obj_crates_blueberry, effect = "Packingstation - Blueberrycrate" },
	{ projectileUuid = projectile_orange, fullAmount = 10, shape = obj_crates_orange, effect = "Packingstation - Orange" },
	{ projectileUuid = projectile_pineapple, fullAmount = 10, shape = obj_crates_pineapple, effect = "Packingstation - Pineapplecrate" }
}

PackingStationScreen.Datasets = { VEGGIE = veggie_dataset, FRUIT = fruit_dataset }

function PackingStationScreen.createAreaTrigger( self )
	if self.areaTrigger then return end

	local size = sm.vec3.new( 0.75, 0.75, 1.0 )
	local filter = sm.areaTrigger.filter.staticBody + sm.areaTrigger.filter.dynamicBody

	self.areaTrigger = sm.areaTrigger.createAttachedBox( self.interactable, size, sm.vec3.new( 0.0, -2.3, 1.5 ), sm.quat.identity(), filter )
end

-- Server

function PackingStationScreen.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then

		if not self.params then
			sm.log.info("Patching missing PackingStationScreen params")
			local x, y = getCell( self.shape:getWorldPosition().x, self.shape:getWorldPosition().y )
			self.params = {}
			self.params.packingStation = {}
			self.params.packingStation.mid = FindFirstInteractableWithinCell( tostring( obj_packingstation_mid ), x, y )
			local screens = {}
			concat( screens, FindInteractablesWithinCell( tostring( obj_packingstation_screen_fruit ), x, y ) )
			concat( screens, FindInteractablesWithinCell( tostring( obj_packingstation_screen_veggie ), x, y ) )
			for idx, interactable in ipairs( screens ) do
				if self.shape:getId() == interactable:getShape():getId() then
					self.params.index = idx
				end
			end
		end

		self.sv.saved = {}
		self.sv.saved.index = self.params.index
		self.sv.saved.mid = self.params.packingStation.mid
		self.sv.saved.count = 0
		self.storage:save( self.sv.saved )
	end

	self.sv.publicData = {}
	self.sv.publicData.externalOpen = false

	self:createAreaTrigger();
	self.areaTrigger:bindOnProjectile( "sv_t_onProjectile" )
	self:sv_updateClientData( self.sv.saved.count, self.sv.publicData.externalOpen )
end

function PackingStationScreen.sv_updateClientData( self, count, externalOpen )
	self.sv.saved.count = count

	self.storage:save( self.sv.saved )

	local dataset = PackingStationScreen.Datasets[self.data.type][self.sv.saved.index]

	local publicData = {
		state = "filling",
		count = count,
		fullAmount = dataset.fullAmount,
		shape = dataset.shape,
		effect = dataset.effect,
		externalOpen = externalOpen
	}

	if self.sv.saved.count >= dataset.fullAmount then
		publicData.state = "waiting_for_pickup"
	end

	self.sv.publicData = publicData;
	self.interactable:setPublicData( self.sv.publicData )
	self.network:setClientData( { index = self.sv.saved.index, count = self.sv.saved.count, externalOpen = externalOpen } )
end

function PackingStationScreen.sv_t_onProjectile( self, trigger, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	if sm.vec3.dot(self.shape.up,hitVelocity:normalize()) > -0.5 then
		return false
	end

	local dataset = PackingStationScreen.Datasets[self.data.type][self.sv.saved.index]

	if self.sv.saved.count >= dataset.fullAmount then
		return false
	end

	if dataset.projectileUuid == projectileUuid then
		self:sv_updateClientData( self.sv.saved.count + 1, self.sv.publicData.externalOpen )
	end

	return false; -- client callback will absorb the projectile
end

function PackingStationScreen.server_onFixedUpdate( self )

	local dataset = PackingStationScreen.Datasets[self.data.type][self.sv.saved.index]

	local areaTriggerCenter = self.areaTrigger:getWorldMin() + (self.areaTrigger:getWorldMax() - self.areaTrigger:getWorldMin()) * 0.5
	local externalOpen = false
	if self.sv.saved.count < dataset.fullAmount then
		for _,result in ipairs(  self.areaTrigger:getContents() ) do
			if sm.exists( result ) then
				if type( result ) == "Body" then
					for _,shape in ipairs( result:getShapes() ) do
						if shape:getShapeUuid() == obj_pneumatic_pump and not shape.interactable:isActive() then
							if (shape:getWorldPosition() - areaTriggerCenter):length() < 1.5 then
								local publicData = shape:getInteractable():getPublicData()
								assert(publicData)

								publicData.packingStationTick = sm.game.getCurrentTick()
								publicData.packingStationProjectileUuid = dataset.projectileUuid

								if publicData.requestExternalOpen then
									externalOpen = true
								end
							end
						end
					end
				end
			end
		end
	end


	local data = self.interactable:getPublicData();
	local state = "filling"
	if data and data.state then
		state = data.state
	end

	local dirty = false
	local count = self.sv.saved.count

	if self.sv.publicData.externalOpen ~= externalOpen then
		dirty = true
	end

	if self.sv.saved.count >= dataset.fullAmount and state and state == "picked_up" then
		dirty = true
		count = 0
	end

	if dirty then
		self:sv_updateClientData( count, externalOpen )
	end

end

-- Client

function PackingStationScreen.client_onCreate( self )
	self.cl = {}
	self.cl.index = 0
	self.cl.count = 0
	self.cl.displayCount = 0
	self.cl.currentDisplayCount = 0
	self.cl.glow = 0
	self.cl.open = false
	self.cl.pumpCurvePose0 = Curve()
	self.cl.pumpCurvePose1 = Curve()
	self.cl.pumpCurvePose0:init({{v=0.0, t=0.0},{v=1.0, t=0.05},{v=0.0, t=0.15},{v=0.0, t=0.2},{v=0.0, t=0.45}})
	self.cl.pumpCurvePose1:init({{v=0.0, t=0.0},{v=0.0, t=0.05},{v=0.0, t=0.15},{v=0.65, t=0.2},{v=0.0, t=0.45}})
	self.cl.pumpTimer = 0.0
	self.cl.interfaceTimer = 0.0

	self:createAreaTrigger();
	self.areaTrigger:bindOnProjectile( "cl_t_onProjectile" )
end

function PackingStationScreen.cl_t_onProjectile( self, trigger, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )

	if sm.vec3.dot(self.shape.up,hitVelocity:normalize()) > -0.5 then
		return false
	end

	local dataset = PackingStationScreen.Datasets[self.data.type][self.cl.index]
	if self.cl.count >= dataset.fullAmount then
		return false
	end

	if dataset.projectileUuid == projectileUuid then
		self.cl.pumpTimer = 0.0
		sm.effect.playEffect( "Packingstation - Load", self.shape.worldPosition )
		return true; -- absorb
	end

	return false;
end

function PackingStationScreen.client_onClientDataUpdate( self, data )
	self.cl.index = data.index
	self.cl.open = data.externalOpen
	self:cl_updateCount( data.count )
end

function PackingStationScreen.cl_updateCount( self, count )
	local dataset = PackingStationScreen.Datasets[self.data.type][self.cl.index]

	self.cl.count = count
	self.cl.displayCount = math.floor( ( count / dataset.fullAmount ) * 7 )
	if self.cl.displayCount == 0 and count ~= 0 then self.cl.displayCount = 1 end

	if self.cl.displayCount ~= 0 then
		self.cl.glow = 0.2;
	end
end

function PackingStationScreen.client_onUpdate( self, dt )

	local dataset = PackingStationScreen.Datasets[self.data.type][self.cl.index]

	local glowTarget = self.cl.displayCount > 0 and 1 or 0
	local glowSpeed = self.cl.displayCount > 0 and 0.6 or 0.8

	if self.cl.count >= dataset.fullAmount then
		glowTarget = 0.3 + math.abs( math.sin( sm.game.getCurrentTick() * 0.05 ) ) * 0.7
		glowSpeed = 0.9
	end
	self.cl.glow = easeIn( self.cl.glow, glowTarget, dt, glowSpeed );

	self.interactable:setGlowMultiplier( self.cl.glow );

	if self.cl.displayCount == 0 then
		self.cl.currentDisplayCount = easeIn( self.cl.currentDisplayCount, self.cl.displayCount, dt, 0.9 )
	else
		self.cl.currentDisplayCount = easeIn( self.cl.currentDisplayCount, self.cl.displayCount, dt, 0.7 )
	end
	self.interactable:setUvFrameIndex( ( ( 7 - round( self.cl.currentDisplayCount ) ) * 4 ) + ( self.cl.index - 1 ) )

	if self.cl.pumpTimer < self.cl.pumpCurvePose1:duration() then
		self.cl.pumpTimer = self.cl.pumpTimer + dt
	end

	if self.cl.open then
		if self.cl.interfaceTimer < 1.0 then
			self.cl.interfaceTimer = self.cl.interfaceTimer + dt * 5
		end

	else
		if self.cl.interfaceTimer > 0.0 then
			self.cl.interfaceTimer = self.cl.interfaceTimer - dt * 5
		end
	end

	self.interactable:setPoseWeight( 0, self.cl.pumpCurvePose0:getValue( self.cl.pumpTimer ) + self.cl.interfaceTimer )
	self.interactable:setPoseWeight( 1, self.cl.pumpCurvePose1:getValue( self.cl.pumpTimer ) )
end
