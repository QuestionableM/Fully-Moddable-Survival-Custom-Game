dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")

Obstacle = class()
Obstacle.poseWeightCount = 2

function Obstacle.server_onCreate( self )
	
	self.stats = { hp = 1, maxhp = 1 }
	self.destroyEffect = nil
	self.projectileDamage = 0
	self.sledgehammerDamage = 0
	self.explosionDamage = 0
	
	if self.data then
		self.stats = { hp = self.data.hp, maxhp = self.data.maxhp }
		self.destroyEffect = self.data.destroyEffect
		self.projectileDamage = self.data.projectileDamage
		self.sledgehammerDamage = self.data.sledgehammerDamage
		self.explosionDamage = self.data.explosionDamage
		if self.data.type then
			self.obstacleType = self.data.type
		end
	end
	
	local params = self.storage:load()
	
	if params ~= nil then
		self.params = params
	else
		self.storage:save( self.params )
	end

	--print( self.params )
end

function Obstacle.client_onCreate( self )
	if self.data then
		if self.data.type then
			self.obstacleType = self.data.type
			if self.obstacleType == "doorwaytape" then
				self.poseTime = 0.5
				self.poseSpeed = 8
				self.poseProgress = self.poseTime * self.poseSpeed
				self.poseMaxProgress = self.poseTime * self.poseSpeed
				self.poseDirectionForward = true
			end
		end
	end
end

function Obstacle.client_onUpdate( self, dt )
	
	if self.obstacleType == "doorwaytape" then
		if self.poseProgress < self.poseMaxProgress then
			
			local poseWeight = math.sin( self.poseProgress * math.pi )
			
			local poseWeight0 = math.max( 0, poseWeight ) --Interval between 0 and 1
			local poseWeight1 = math.abs( math.min( 0, poseWeight ) ) --Interval between 0 and -1, math.abs to apply positive pose values
			local poseScale = 1.0 - ( self.poseProgress / self.poseMaxProgress ) --Scale the poses from 1 to 0 as time goes on
			
			if self.poseDirectionForward then
				self.interactable:setPoseWeight( 0, poseWeight0 * poseScale )
				self.interactable:setPoseWeight( 1, poseWeight1 * poseScale )
			else
				self.interactable:setPoseWeight( 1, poseWeight0 * poseScale )
				self.interactable:setPoseWeight( 0, poseWeight1 * poseScale )
			end
			
			self.poseProgress = self.poseProgress + dt * self.poseSpeed

		else
			self.interactable:setPoseWeight( 0, 0.0 )
			self.interactable:setPoseWeight( 1, 0.0 )
		end
	end
end

-- Called from server upon getting triggered by a hit
function Obstacle.client_hitActivation( self, hitPos )
	if self.obstacleType == "doorwaytape" then
		self.poseDirectionForward = false
		local hitDirection = ( self.shape.worldPosition - hitPos ):normalize()
		if self.shape.up:dot( hitDirection ) > 0 then
			self.poseDirectionForward = true
		end
		self.poseProgress = 0
	end
end

function Obstacle.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	print("'Obstacle' took projectile damage")
	self:server_takeDamage( self.projectileDamage )
	self.network:sendToClients( "client_hitActivation", hitPos )
end

function Obstacle.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
	print("'Obstacle' took melee damage")
	self:server_takeDamage( self.sledgehammerDamage )
	self.network:sendToClients( "client_hitActivation", hitPos )
end

function Obstacle.server_onExplosion( self, center, destructionLevel )
	print("'Obstacle' took explosion damage")
	self:server_takeDamage( self.explosionDamage )
	self.network:sendToClients( "client_hitActivation", center )
end

function Obstacle.server_takeDamage( self, damage )
	
	if self.stats.hp > 0 then
		self.stats.hp = self.stats.hp - damage
		self.stats.hp = math.max( self.stats.hp, 0 )
		print( "'Obstacle' received:", damage, "damage.", self.stats.hp, "/", self.stats.maxhp, "HP" )
		if self.stats.hp <= 0 then
		
			if self.params then
				for _,otherNode in ipairs( self.params.connections ) do
					self.params.blockedNode:connect( otherNode )
					otherNode:connect( self.params.blockedNode )
				end
			end
			
			if self.destroyEffect then
				sm.effect.playEffect( self.destroyEffect, self.shape.worldPosition, sm.vec3.new( 0, 0, 0 ), self.shape.worldRotation )
			end
			
			if self.obstacleType == "doorwaytape" then
				-- Spawn destroyed doorway tape
				self.shape.body:createPart( obj_destructable_tape_doorwaytape01_destroyed, self.shape.localPosition, self.shape.zAxis, self.shape.xAxis, true )
			end
			
			self.shape:destroyShape()
		end
	end
end
