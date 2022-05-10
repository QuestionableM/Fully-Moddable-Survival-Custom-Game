-- LootHarvestable.lua --
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"

LootHarvestable = class( nil )

function LootHarvestable.server_onCreate( self )
	self.sv = {}

	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.uuid = sm.uuid.getNil()
		self.sv.saved.quantity = 0
		if self.params then
			self.sv.saved.uuid = self.params.uuid
			self.sv.saved.quantity = self.params.quantity
			self.sv.saved.epic = self.params.epic
		end
		self.sv.saved.ticksLeftInWorld = 144000 -- 1 hour until removed
		self.sv.saved.lastTickUpdate = sm.game.getCurrentTick()

		self.storage:save( self.sv.saved )
	end
	
	self.network:setClientData( { uuid = self.sv.saved.uuid, quantity = self.sv.saved.quantity, epic = self.sv.saved.epic } )
	self.harvestable.publicData = { uuid = self.sv.saved.uuid, quantity = self.sv.saved.quantity, vacuumable = true }
end

function LootHarvestable.server_onUnload( self )
	self.storage:save( self.sv.saved )
end

function LootHarvestable.server_onReceiveUpdate( self )
	local currentTick = sm.game.getCurrentTick()
	local ticks = currentTick - self.sv.saved.lastTickUpdate
	ticks = math.max( ticks, 0 )
	self.sv.saved.lastTickUpdate = currentTick
	
	-- Destroy the loot if it has existed for too long
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

function LootHarvestable.server_canErase( self ) return true end
function LootHarvestable.client_canErase( self ) return true end

function LootHarvestable.server_onRemoved( self, player )
	print("server_onRemoved", player)
	self:sv_n_harvest( nil, player )
end

function LootHarvestable.cl_n_onInventoryFull( self )
	sm.gui.displayAlertText( "#{INFO_INVENTORY_FULL}", 4 )
end

function LootHarvestable.sv_n_harvest( self, params, player )
	print("sv_n_harvest", player)
	if not self.sv.removed then
		-- Give the represented items to the interacting player and destroy the harvestable
		local container = player:getInventory()
		if sm.container.beginTransaction() then
			sm.container.collect( container, self.sv.saved.uuid, self.sv.saved.quantity )
			if sm.container.endTransaction() then
				self.sv.removed = true
				self.harvestable.publicData.harvested = true
				sm.event.sendToPlayer( player, "sv_e_onLoot", { uuid = self.sv.saved.uuid, quantity = self.sv.saved.quantity, pos = self.harvestable:getPosition() } )
				sm.harvestable.destroy( self.harvestable )
			else
				self.network:sendToClient( player, "cl_n_onInventoryFull" )
			end
		end
	end
end

function LootHarvestable.client_onCreate( self )
	
	-- Create the loot renderable effect with a random starting rotation
	self.cl = {}
	self.cl.rotation = math.random() * math.pi * 2
	
	
end

function LootHarvestable.client_onClientDataUpdate( self, params )

	-- Set the effect renderable
	self.cl.uuid = params.uuid
	self.cl.quantity = params.quantity
	self.cl.epic = params.epic
	local scale = 0.25
	local effectUuid = self.cl.uuid
	if sm.item.isTool( self.cl.uuid ) then
		effectUuid = GetToolProxyItem( params.uuid )
	end

	if  params.uuid == obj_outfitpackage_common then
		self.cl.itemEffect = sm.effect.createEffect( "Loot - OutfitCommonGlowItem" )
		self.cl.itemEffect:setPosition( self.harvestable:getPosition() + sm.vec3.new( 0, 0, 0.575 ) )
	elseif params.uuid == obj_outfitpackage_rare then
		self.cl.itemEffect = sm.effect.createEffect( "Loot - OutfitRareGlowItem" )
		self.cl.itemEffect:setPosition( self.harvestable:getPosition() + sm.vec3.new( 0, 0, 0.575 ) )
	elseif params.uuid == obj_outfitpackage_epic then
		self.cl.itemEffect = sm.effect.createEffect( "Loot - OutfitEpicGlowItem" )
		self.cl.itemEffect:setPosition( self.harvestable:getPosition() + sm.vec3.new( 0, 0, 0.575 ) )	
	else
		if effectUuid then
			local size = sm.item.getShapeSize( effectUuid )
			local max = math.max( math.max( size.x, size.y ), size.z )
			scale = 0.225 / max + ( size:length() - 1.4422496 ) * 0.015625
			if scale * size:length() > 1.0 then
				scale = 1.0 / size:length()
			end
		end

		if self.cl.epic then
			self.cl.itemEffect = sm.effect.createEffect( "EpicLoot - GlowItem" )
		else
			self.cl.itemEffect = sm.effect.createEffect( "Loot - GlowItem" )
		end
		self.cl.itemEffect:setPosition( self.harvestable:getPosition() + sm.vec3.new( 0, 0, 0.375 ) )

	end
	local forward = sm.vec3.new( 0, 1, 0 )
	self.cl.itemEffect:setRotation( sm.vec3.getRotation( forward, forward:rotateZ( self.cl.rotation ) ) )
	if effectUuid then
		self.cl.itemEffect:setParameter( "uuid", effectUuid )
		self.cl.itemEffect:setParameter( "Color", sm.shape.getShapeTypeColor( effectUuid ) )
	end
	
	-- Set the effect scale and offset

	self.cl.itemEffect:setScale( sm.vec3.new( scale, scale, scale ) )
	
	
	self.cl.itemEffect:start()
	
end

function LootHarvestable.client_onDestroy( self )
	self.cl.itemEffect:stop()
end

function LootHarvestable.client_onUpdate( self, dt )
	
	-- Slowly rotate the effect
	local rotationSpeed = 0.1875 -- Revolutions per second
	self.cl.rotation = self.cl.rotation + math.pi * 2 * dt * rotationSpeed
	while self.cl.rotation > math.pi * 2 do
		self.cl.rotation = self.cl.rotation - math.pi * 2
	end
	self.cl.rotation = math.max( math.min( self.cl.rotation, math.pi * 2 ), 0 )
	local forward = sm.vec3.new( 0, 1, 0 )
	self.cl.itemEffect:setRotation( sm.vec3.getRotation( forward, forward:rotateZ( self.cl.rotation ) ) )
	
end

function LootHarvestable.client_onInteract( self, state )
	self.network:sendToServer( "sv_n_harvest" )
end


function LootHarvestable.client_canInteract( self )
	sm.gui.setCenterIcon( "Use" )
	local keyBindingText =  sm.gui.getKeyBinding( "Attack", true )
	sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_PICK_UP} [" .. sm.shape.getShapeTitle( self.cl.uuid ) .. "]"..( self.cl.quantity > 1 and (" x " .. self.cl.quantity) or "" ) )	
	return true
end
