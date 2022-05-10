dofile("$SURVIVAL_DATA/Scripts/game/survival_loot.lua")

BeeHive = class()

function BeeHive.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	self:sv_onHit()
end

function BeeHive.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
	self:sv_onHit()
end

function BeeHive.server_onExplosion( self, center, destructionLevel )
	self:sv_onHit()
end

function BeeHive.sv_onHit( self )
	if not self.destroyed and sm.exists( self.harvestable ) then

		if SurvivalGame then
			local lootList = {}
			local slots = math.random( 2, 4 )
			for i = 1, slots do
				lootList[i] = { uuid = obj_resource_beewax, quantity = 1 }
			end
			SpawnLoot( self.harvestable, lootList )
		end

		sm.effect.playEffect( "beehive - destruct", self.harvestable.worldPosition, nil, self.harvestable.worldRotation )
		sm.harvestable.createHarvestable( hvs_farmables_beehive_broken, self.harvestable.worldPosition, self.harvestable.worldRotation )
		
		self.harvestable:destroy()
		self.destroyed = true
	end
end
function BeeHive.client_onCreate( self )
	self.cl = {}
	self.cl.swarmEffect = sm.effect.createEffect( "beehive - beeswarm" )
	self.cl.swarmEffect:setPosition( self.harvestable.worldPosition )
	self.cl.swarmEffect:setRotation( self.harvestable.worldRotation )
	self.cl.swarmEffect:start()
end

function BeeHive.client_onDestroy( self )
	self.cl.swarmEffect:stop()
	self.cl.swarmEffect:destroy()
end