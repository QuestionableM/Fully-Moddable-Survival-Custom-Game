-- PigmentFlower.lua --
dofile( "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

PigmentFlower = class( nil )

function PigmentFlower.client_onInteract( self, state )
	self.network:sendToServer( "sv_n_harvest" )
end

function PigmentFlower.client_canInteract( self )
	sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Attack", true ), "#{INTERACTION_PICK_UP}" )
	return true
end

function PigmentFlower.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
	if not self.harvested and sm.exists( self.harvestable ) then
		sm.effect.playEffect( "Pigmentflower - Picked", self.harvestable.worldPosition )

		if SurvivalGame then
			local harvest = {
				lootUid = obj_resource_flower,
				lootQuantity = 1
			}
			local pos = self.harvestable:getPosition() + sm.vec3.new( 0, 0, 0.5 )
			sm.projectile.harvestableCustomProjectileAttack( harvest, projectile_loot, 0, pos, sm.noise.gunSpread( sm.vec3.new( 0, 0, 1 ), 20 ) * 5, self.harvestable, 0 )
		end
		sm.harvestable.createHarvestable( hvs_farmables_growing_pigmentflower, self.harvestable.worldPosition, self.harvestable.worldRotation )
		sm.harvestable.destroy( self.harvestable )
		self.harvested = true
	end
end

function PigmentFlower.server_canErase( self ) return true end
function PigmentFlower.client_canErase( self ) return true end

function PigmentFlower.server_onRemoved( self, player )
	self:sv_n_harvest( nil, player )
end

function PigmentFlower.cl_n_onInventoryFull( self )
	sm.gui.displayAlertText( "#{INFO_INVENTORY_FULL}", 4 )
end

function PigmentFlower.sv_n_harvest( self, params, player )
	if not self.harvested and sm.exists( self.harvestable ) then
		if SurvivalGame then
			local container = player:getInventory()
			if sm.container.beginTransaction() then
				sm.container.collect( container, obj_resource_flower, 1 )
				if sm.container.endTransaction() then
					sm.event.sendToPlayer( player, "sv_e_onLoot", { uuid = obj_resource_flower, pos = self.harvestable.worldPosition } )
					sm.effect.playEffect( "Pigmentflower - Picked", self.harvestable.worldPosition )
					sm.harvestable.createHarvestable( hvs_farmables_growing_pigmentflower, self.harvestable.worldPosition, self.harvestable.worldRotation )
					sm.harvestable.destroy( self.harvestable )
					self.harvested = true
				else
					self.network:sendToClient( player, "cl_n_onInventoryFull" )
				end
			end
		else
			sm.effect.playEffect( "Pigmentflower - Picked", self.harvestable.worldPosition )
			sm.harvestable.createHarvestable( hvs_farmables_growing_pigmentflower, self.harvestable.worldPosition, self.harvestable.worldRotation )
			sm.harvestable.destroy( self.harvestable )
			self.harvested = true
		end
	end
end
