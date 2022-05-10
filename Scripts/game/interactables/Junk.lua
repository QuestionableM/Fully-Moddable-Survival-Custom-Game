dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

Junk = class()
Junk.maxChildCount = 0
Junk.maxParentCount = 0
Junk.connectionInput = sm.interactable.connectionType.none
Junk.connectionOutput = sm.interactable.connectionType.none
Junk.destructionCountdown = 40 --ticks (default 1 seconds)

function Junk.server_onCreate( self )
	self.minExist = 1
	self.maxExist = 1
	self.type = "junk"
	
	if self.data then
		self.minExist = self.data.minExist
		self.maxExist = self.data.maxExist
		self.type = self.data.type
	end
	
	self.destructionCountdown = math.random( 40 * self.minExist, 40 * self.maxExist )
	if self.type == "shooter" then
		self.shotsLeft = math.random( 1, 3 )
		self.fireDelayMin = 18 --ticks
		self.fireDelayMax = 36 --ticks
		self.fireDelay = self.fireDelayMax
		self.fireDelayProgress = 0
		self.minForce = 125
		self.maxForce = 135
		self.spreadDeg = 5.0
		if self.params and self.params.projectileUuid then
			self.projectileUuid = self.params.projectileUuid
		else
			self.projectileUuid = projectile_tape
		end
		if self.params and self.params.projectileUuid then
			self.projectileDamage = self.params.projectileDamage
		else
			self.projectileDamage = 20
		end
	end
	
end

function Junk.client_onCreate( self )
	if self.data then
		if self.data.type == "shooter" then
			self.shootEffect = sm.effect.createEffect( "TapeBot - Shoot", self.interactable )
		end
	end
end

-- (Event) Called upon game tick. (40 times a second)
function Junk.server_onFixedUpdate( self, timeStep )

	if self.type == "shooter" and self.projectileUuid then
		if self.shotsLeft > 0 then
			self.fireDelayProgress = self.fireDelayProgress + 1
			if self.fireDelayProgress >= self.fireDelay then
				self.fireDelayProgress = 0
				self.fireDelay = math.random( self.fireDelayMin, self.fireDelayMax )
				
				local firePos = sm.vec3.new( 0.0, 0.0, 0.375 )
				local fireForce = math.random( self.minForce, self.maxForce )

				-- Add random spread
				local dir = sm.noise.gunSpread( sm.vec3.new( 0.0, 0.0, 1.0 ), self.spreadDeg )

				-- Fire projectile from the shape
				sm.projectile.shapeProjectileAttack( self.projectileUuid, self.projectileDamage, firePos, dir * fireForce, self.shape )
				self.shotsLeft = self.shotsLeft - 1

				self.network:sendToClients( "client_onShoot" )
				local impulse = dir * -6 * self.shape.mass
				sm.physics.applyImpulse( self.shape, impulse )
			end
		end
	end


	self.destructionCountdown = self.destructionCountdown - 1
	if self.destructionCountdown <= 0 then
		self.shape:destroyShape()
	end
	
end

-- Called from server upon the gun shooting
function Junk.client_onShoot( self )
	if self.shootEffect then
		local rot = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), self.shape.up )
		self.shootEffect:start()
	end
end

