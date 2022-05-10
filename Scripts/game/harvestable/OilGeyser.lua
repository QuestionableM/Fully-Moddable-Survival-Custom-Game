-- OilGeyser.lua --
dofile "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua"

OilGeyser = class( nil )

function OilGeyser.client_onInteract( self, state )
	self.network:sendToServer( "sv_n_harvest" )
end

function OilGeyser.client_canInteract( self )
	sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Attack", true ), "#{INTERACTION_PICK_UP}" )
	return true
end

function OilGeyser.server_canErase( self ) return true end
function OilGeyser.client_canErase( self ) return true end

function OilGeyser.server_onRemoved( self, player )
	self:sv_n_harvest( nil, player )
end

function OilGeyser.client_onCreate( self )
	self.cl = {}
	self.cl.activeGeyser = sm.effect.createEffect( "Oilgeyser - OilgeyserLoop" )
	self.cl.activeGeyser:setPosition( self.harvestable.worldPosition )
	self.cl.activeGeyser:setRotation( self.harvestable.worldRotation )
	self.cl.activeGeyser:start()
	self.cl.activeGeyserAmbience = sm.effect.createEffect( "Oilgeyser - OilgeyserAmbience" )
	self.cl.activeGeyserAmbience:setPosition( self.harvestable.worldPosition )
	self.cl.activeGeyserAmbience:setRotation( self.harvestable.worldRotation )
	self.cl.activeGeyserAmbience:start()
end

function OilGeyser.cl_n_onInventoryFull( self )
	sm.gui.displayAlertText( "#{INFO_INVENTORY_FULL}", 4 )
end

function OilGeyser.sv_n_harvest( self, params, player )
	if not self.harvested and sm.exists( self.harvestable ) then
		if SurvivalGame then
			local container = player:getInventory()
			local quantity = randomStackAmount( 1, 2, 4 )
			if sm.container.beginTransaction() then
				sm.container.collect( container, obj_resource_crudeoil, quantity )
				if sm.container.endTransaction() then
					sm.event.sendToPlayer( player, "sv_e_onLoot", { uuid = obj_resource_crudeoil, quantity = quantity, pos = self.harvestable.worldPosition } )
					sm.effect.playEffect( "Oilgeyser - Picked", self.harvestable.worldPosition )
					sm.harvestable.createHarvestable( hvs_farmables_growing_oilgeyser, self.harvestable.worldPosition, self.harvestable.worldRotation )
					sm.harvestable.destroy( self.harvestable )
					self.harvested = true
				else
					self.network:sendToClient( player, "cl_n_onInventoryFull" )
				end
			end
		else
			sm.effect.playEffect( "Oilgeyser - Picked", self.harvestable.worldPosition )
			sm.harvestable.createHarvestable( hvs_farmables_growing_oilgeyser, self.harvestable.worldPosition, self.harvestable.worldRotation )
			sm.harvestable.destroy( self.harvestable )
			self.harvested = true
		end
	end
end

function OilGeyser.client_onDestroy( self )
	self.cl.activeGeyser:destroy()
	self.cl.activeGeyserAmbience:destroy()
end
