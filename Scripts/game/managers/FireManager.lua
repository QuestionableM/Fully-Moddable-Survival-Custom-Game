dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_units.lua")
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )
dofile("$SURVIVAL_DATA/Scripts/util.lua")

FireManager = class( nil )

--Server to client
NETWORK_MSG_ADD_FIRE = 10000
NETWORK_MSG_REMOVE_FIRE = 10001
NETWORK_MSG_REMOVE_FIRE_CELL = 10002
NETWORK_MSG_UPDATE_FIRE_HEALTH = 10003
--Client to server
NETWORK_MSG_REQUEST_FIRE = 10004

FIRE_SIZE = 	{
					sm.vec3.new( 0.4, 0.4, 0.4 ),
					sm.vec3.new( 0.7, 0.7, 1.7 ),
					sm.vec3.new( 1.75, 1.75, 3.5 )
				}

-- Server side
function FireManager.sv_onCreate( self, sender )
	self.sv = {}
	self.sv.sender = sender
	self.sv.fireCells = {}
	self.sv.triggerCells = {}
	self.sv.conIdCells = {}
	self.sv.world = sender.world

	-- Quest fires
	self.sv.namedFires = {}
	g_dousedNamedFires = g_dousedNamedFires or sm.storage.load( STORAGE_CHANNEL_DOUSED_NAMED_FIRES ) or {}
end

function FireManager.sv_handleMsg( self, msg )
	if msg.type == NETWORK_MSG_REQUEST_FIRE then
		self:sv_loadCellForClient( msg.cellKey )
		return true
	end
	return false
end

function FireManager.sv_onFixedUpdate( self )
	for _, fireObjs in pairs( self.sv.fireCells ) do
		for _, fireObj in pairs( fireObjs ) do
			local updatedHitCooldowns = {}
			for _, hitCooldown in pairs( fireObj.hitCooldowns ) do
				hitCooldown.ticks = hitCooldown.ticks - 1
				if hitCooldown.ticks > 0 then
					updatedHitCooldowns[#updatedHitCooldowns+1] = hitCooldown
				end
			end
			fireObj.hitCooldowns = updatedHitCooldowns
		end
	end
end

function FireManager.sv_onCellLoaded( self, x, y )
	--print("--- loading fire objs on cell " .. x .. ":" .. y .. " ---")
	local cellKey = CellKey(x, y)
	local nodes = sm.cell.getNodesByTag( x, y, "FIRE" )
	--print(#nodes)
	if #nodes > 0 then

		self.sv.fireCells[cellKey] = {}
		self.sv.triggerCells[cellKey] = {}
		self.sv.conIdCells[cellKey] = {}

		for idx, node in ipairs( nodes ) do
			local health = 1
			local scale = node.scale
			if node.params.effect and node.params.effect.params then
				for k,v in kvpairs( node.params.effect.params ) do
					if k == "health" then
						health = v
						scale = FIRE_SIZE[health]
					end
				end
			end
			self:sv_addFire( cellKey, idx, node.position, node.rotation, scale, node.params.effect.name, node.params.connections, health, node.params.name )
		end
		sm.storage.save( { STORAGE_CHANNEL_FIRE, self.sv.world.id, cellKey }, self.sv.fireCells[cellKey] )
	end
end

function FireManager.sv_onCellUnloaded( self, x, y )
	--print("--- unloading fire objs on cell " .. x .. ":" .. y .. " ---")
	local cellKey = CellKey(x, y)
	if self.sv.fireCells[cellKey] ~= nil then

		for fireId, fireObj in pairs( self.sv.fireCells[cellKey] ) do
			if fireObj and fireObj.name then
				--print( "Unloaded named fire: ", fireObj.name )
				self.sv.namedFires[fireObj.name] = nil
			end
		end

		for fireId, areaTrigger in pairs( self.sv.triggerCells[cellKey] ) do
			if areaTrigger and sm.exists( areaTrigger ) then
				sm.areaTrigger.destroy( areaTrigger )
			end
		end

		self.sv.fireCells[cellKey] = nil
		self.sv.triggerCells[cellKey] = nil
		self.sv.conIdCells[cellKey] = nil

		self.sv.sender.network:sendToClients( "cl_n_fireMsg", { type = NETWORK_MSG_REMOVE_FIRE_CELL, cellKey = cellKey } )
	end
end

function FireManager.sv_onCellReloaded( self, x, y )
	--print("--- reloading fire objs on cell " .. x .. ":" .. y .. " ---")
	local cellKey = CellKey(x, y)

	local fireCell = sm.storage.load( { STORAGE_CHANNEL_FIRE, self.sv.world.id, cellKey } )
	if fireCell ~= nil then
		self.sv.fireCells[cellKey] = {}
		self.sv.triggerCells[cellKey] = {}
		self.sv.conIdCells[cellKey] = {}
		for fireId, fireObj in pairs( fireCell ) do
			self:sv_addFire( cellKey, fireId, fireObj.position, fireObj.rotation, fireObj.scale, fireObj.effect, fireObj.connections, fireObj.hp, fireObj.name )
		end
	end
end

function FireManager.sv_loadCellForClient( self, cellKey )
	self.sv.sender.network:sendToClients( "cl_n_fireMsg", { type = NETWORK_MSG_REMOVE_FIRE_CELL, cellKey = cellKey } )
	local fireCell = sm.storage.load( { STORAGE_CHANNEL_FIRE, self.sv.world.id, cellKey } )
	if fireCell ~= nil then
		for fireId, fireObj in pairs( fireCell ) do
			self.sv.sender.network:sendToClients( "cl_n_fireMsg", { type = NETWORK_MSG_ADD_FIRE, cellKey = cellKey, fireId = fireId, position = fireObj.position, rotation = fireObj.rotation, effect = fireObj.effect, health = fireObj.hp } )
		end
	end
end

function FireManager.sv_addFire( self, cellKey, fireId, position, rotation, scale, effect, connections, health, name )

	local fireObj = {
		hitCooldowns = {},
		hp = health,
		startHp = health,
		position = position,
		rotation = rotation,
		scale = scale,
		effect = effect,
		connections = connections,
		name = name
	}
	self.sv.fireCells[cellKey][fireId] = fireObj

	-- Optional: map connection ids to fire ids
	if connections ~= nil then
		self.sv.conIdCells[cellKey][connections.id] = fireId
	end
	if name ~= nil then
		--print( "Added named fire: ", name )
		self.sv.namedFires[name] = fireObj
	end

	local areaTrigger = sm.areaTrigger.createBox( scale * 0.5, position, rotation, sm.areaTrigger.filter.character, { cellKey = cellKey, fireId = fireId } )
	areaTrigger:bindOnEnter( "trigger_onEnterFire", self )
	areaTrigger:bindOnStay( "trigger_onStayFire", self )
	areaTrigger:bindOnProjectile( "trigger_onProjectile", self )
	self.sv.triggerCells[cellKey][fireId] = areaTrigger

	self.sv.sender.network:sendToClients( "cl_n_fireMsg", { type = NETWORK_MSG_ADD_FIRE, cellKey = cellKey, fireId = fireId, position = position, rotation = rotation, effect = effect, health = health } )
end

function FireManager.sv_removeFire( self, cellKey, fireId, removedFires )
	local fireObj = self.sv.fireCells[cellKey][fireId]
	if fireObj ~= nil then
		removedFires[fireId] = fireObj
		
		if fireObj.name ~= nil then
			--print( "Removed named fire: ", fireObj.name )
			self.sv.namedFires[fireObj.name] = nil
		end

		if fireObj.connections ~= nil then
			for _,conId in ipairs( fireObj.connections.otherIds ) do
				local otherFireId = self.sv.conIdCells[cellKey][conId]
				if not removedFires[otherFireId] then
					self:sv_removeFire( cellKey, otherFireId, removedFires )
				end
			end
		end

		self.sv.fireCells[cellKey][fireId] = nil

		sm.areaTrigger.destroy(self.sv.triggerCells[cellKey][fireId])
		self.sv.triggerCells[cellKey][fireId] = nil

		self.sv.sender.network:sendToClients( "cl_n_fireMsg", { type = NETWORK_MSG_REMOVE_FIRE, cellKey = cellKey, fireId = fireId } )
		sm.storage.save( { STORAGE_CHANNEL_FIRE, self.sv.world.id, cellKey }, self.sv.fireCells[cellKey] )
	end
end

function FireManager.trigger_onEnterFire( self, trigger, results )
	for _,result in ipairs( results ) do
		if sm.exists( result ) then
			if type( result ) == "Character" then
				local characterType = result:getCharacterType()
				if characterType == unit_mechanic or characterType == unit_woc or characterType == unit_worm  then
					local diff = (result:getWorldPosition() - trigger:getWorldPosition()):normalize()
					diff.z = 0
					sm.physics.applyImpulse( result, diff * 1000, true )
					if result:isPlayer() then
						sm.event.sendToPlayer( result:getPlayer(), "sv_e_onEnterFire" )
					end
				end
			end
		end
	end
end

function FireManager.trigger_onStayFire( self, trigger, results )
	for _,result in ipairs( results ) do
		if sm.exists( result ) then
			if type( result ) == "Character" then
				if result:isPlayer() then
					sm.event.sendToPlayer( result:getPlayer(), "sv_e_onStayFire" )
				end
			end
		end
	end
end

function FireManager.trigger_onProjectile( self, trigger, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	if ( projectileUuid == projectile_water or g_survivalDev ) and sm.exists(trigger) then
		local ud = trigger:getUserData()
		local fireObj = self.sv.fireCells[ud.cellKey][ud.fireId]
		if fireObj ~= nil then

			for _, hitCooldown in ipairs( fireObj.hitCooldowns ) do
				if hitCooldown.shooter == attacker then
					-- Ignore projectile hit during hit cooldown
					return
				end
			end
			if attacker and sm.exists( attacker ) then
				fireObj.hitCooldowns[#fireObj.hitCooldowns+1] = { shooter = attacker, ticks = 20 }
			end

			self:sv_updateHealth( ud.cellKey, ud.fireId, fireObj.hp - 1 )
			sm.effect.playEffect( "Steam - quench", hitPos )
			return true
		end
	end
	return false
end

function FireManager.sv_updateHealth( self, cellKey, fireId, health )
	local fireObj = self.sv.fireCells[cellKey][fireId]
	if fireObj ~= nil then
		fireObj.hp = health
		if fireObj.hp <= 0 then
			local removedFires = {}
			self:sv_removeFire( cellKey, fireId, removedFires )
			for _, f in pairs( removedFires ) do
				if f.name ~= nil then
					--print( "Doused named fire: ", f.name )
					g_dousedNamedFires[f.name] = true
					QuestManager.Sv_OnEvent( "event.quest_tutorial.fire_doused", { name = f.name } )
					sm.storage.save( STORAGE_CHANNEL_DOUSED_NAMED_FIRES, g_dousedNamedFires )
				end
			end
		else
			self.sv.sender.network:sendToClients( "cl_n_fireMsg", {
				type = NETWORK_MSG_UPDATE_FIRE_HEALTH,
				cellKey = cellKey,
				fireId = fireId,
				health = fireObj.hp,
				healthFraction = fireObj.hp / fireObj.startHp
			} )
			fireObj.scale = FIRE_SIZE[health]
			self.sv.triggerCells[cellKey][fireId]:setSize( fireObj.scale )
			sm.storage.save( { STORAGE_CHANNEL_FIRE, self.sv.world.id, cellKey }, self.sv.fireCells[cellKey] )
		end
	end
end

-- Client side
function FireManager.cl_onCreate( self, sender )
	self.cl = {}
	self.cl.sender = sender
	self.cl.fireCells = {}
end

function FireManager.cl_onCellLoaded( self, x, y )
	self.cl.sender.network:sendToServer( "sv_n_fireMsg", { type = NETWORK_MSG_REQUEST_FIRE, cellKey = CellKey( x, y ) } )
end

function FireManager.cl_handleMsg( self, msg )
	if msg.type == NETWORK_MSG_ADD_FIRE then
		self:cl_addFire( msg.cellKey, msg.fireId, msg.position, msg.rotation, msg.effect, msg.health )
		return true
	elseif msg.type == NETWORK_MSG_REMOVE_FIRE then
		self:cl_removeFire( msg.cellKey, msg.fireId )
		return true
	elseif msg.type == NETWORK_MSG_REMOVE_FIRE_CELL then
		self:cl_removeFireCell( msg.cellKey )
		return true
	elseif msg.type == NETWORK_MSG_UPDATE_FIRE_HEALTH then
		self:cl_updateHealth(  msg.cellKey, msg.fireId, msg.health, msg.healthFraction )
		return true
	end
	return false
end

function FireManager.cl_addFire( self, cellKey, fireId, position, rotation, effect, health )
	if self.cl.fireCells[cellKey] == nil then
		self.cl.fireCells[cellKey] = {}
	end

	local fireObj = {
		effect = sm.effect.createEffect( effect )
	}
	fireObj.effect:setPosition( position )
	fireObj.effect:setRotation( rotation )
	fireObj.effect:setParameter( "health", health )
	fireObj.effect:start()

	if effect == "Fire -medium01" or effect == "ShipFire - medium01" then
		fireObj.putout = {
			effectName = "Fire -medium01_putout"
		}
	elseif effect == "Fire - large01" or effect == "ShipFire - large01" then
		fireObj.putout = {
			effectName = "Fire - large01_putout"
		}
	end
	if fireObj.putout then
		fireObj.putout.position = position
		fireObj.putout.rotation = rotation
	end

	self.cl.fireCells[cellKey][fireId] = fireObj
end

function FireManager.cl_removeFire( self, cellKey, fireId )
	local fireObj = self.cl.fireCells[cellKey][fireId]
	fireObj.effect:stop()
	if fireObj.putout then
		sm.effect.playEffect( fireObj.putout.effectName, fireObj.putout.position, sm.vec3.zero(), fireObj.putout.rotation )
	end
	self.cl.fireCells[cellKey][fireId] = nil
end

function FireManager.cl_removeFireCell( self, cellKey )
	if self.cl.fireCells[cellKey] ~= nil then
		for fireId, fireObj in pairs( self.cl.fireCells[cellKey] ) do
			if fireObj.effect and sm.exists( fireObj.effect ) then
				fireObj.effect:stop()
				fireObj.effect:destroy()
			end
		end
	end
	self.cl.fireCells[cellKey] = nil
end

function FireManager.cl_updateHealth( self, cellKey, fireId, health, healthFraction )
	self.cl.fireCells[cellKey][fireId].effect:setParameter( "health", health )
	self.cl.fireCells[cellKey][fireId].effect:setParameter( "fire_intensity", healthFraction )
end
