dofile("$SURVIVAL_DATA/Scripts/game/survival_loot.lua")

LootCrate = class()

function LootCrate.server_onCreate( self )
	self.saved = self.storage:load()
	if self.saved == nil and self.params then
		self.saved = {}
		self.saved.lootTable = self.params.lootTable
		self.storage:save( self.saved )
	end
end

function LootCrate.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	self:sv_onHit()
end

function LootCrate.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
	self:sv_onHit( hitDirection * 5 )
end

function LootCrate.server_onExplosion( self, center, destructionLevel )
	self:sv_onHit()
end

function LootCrate.sv_onHit( self, velocity )
	if not self.destroyed and sm.exists( self.harvestable ) then
		if self.data.destroyEffect then
			sm.effect.playEffect( self.data.destroyEffect, self.harvestable.worldPosition, nil, self.harvestable.worldRotation, nil, { startVelocity = velocity } )
		end
		if self.data.staticDestroyEffect then
			sm.effect.playEffect( self.data.staticDestroyEffect, self.harvestable.worldPosition, nil, self.harvestable.worldRotation )
		end
		print( self.saved )
		local lootTable = self.saved and self.saved.lootTable or nil
		
		if lootTable == nil then
			lootTable = "loot_crate_standard" --Error fallback
		end

		local lootList = SelectLoot( lootTable )
		SpawnLoot( self.harvestable, lootList )

		self.destroyed = true
		self.harvestable:destroy()
	end
end
