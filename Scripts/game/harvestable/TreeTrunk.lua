-- TreeTrunk.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"

TreeTrunk = class( nil )

local SelfdestructTickTime = 40 * 22
local TrunkHealth = 100
local DamagerPerHit = math.ceil( TrunkHealth / TREE_TRUNK_HITS )

-- Server

function TreeTrunk.server_onCreate( self )
	self:sv_init()
	
	if self.params then
		if self.params.inheritedDamage then
			self:sv_onHit( self.params.inheritedDamage )
		end
		if self.params.pristine then
			self.sv.fallen = false
		end
	end
	
	self.network:setClientData( { fallen = self.sv.fallen, pristine = ( self.sv.fallen == false ) } )
end

function TreeTrunk.sv_init( self )
	
	self.sv = {}
	self.sv.health = TrunkHealth
	
	self.sv.fallen = true
	
	self.sv.effect = {}
	self.sv.effect.startHealth = TrunkHealth
	
	if self.data then
		if self.data.crown then
			self.sv.crown = true
			self.sv.selfdestructTicksLeft = SelfdestructTickTime
			self.sv.previousPosition = self.shape.worldPosition
			self.sv.windDirection = sm.vec3.new( 1, 0, 0)
			local randomAngle = math.random( 0, 360 )
			self.sv.windDirection = self.sv.windDirection:rotate( randomAngle, sm.vec3.new( 0, 0, 1 ) )
			self.sv.needNudge = false
			self.sv.hasNudged = false
		end
	end
end

function TreeTrunk.server_onFixedUpdate( self, timeStep )
	if self.sv.crown and not self.sv.fallen then
		local currentPosition = self.shape.worldPosition
		local currentVelocity = ( currentPosition - self.sv.previousPosition ) / timeStep
		self.sv.previousPosition = currentPosition
			
		if self.sv.needNudge then
			self.sv.hasNudged = true
			local flatVelocity = currentVelocity
			flatVelocity.z = 0
			if flatVelocity:length() >= FLT_EPSILON then
				sm.physics.applyImpulse( self.shape, flatVelocity:normalize() * self.shape:getBody().mass * 0.05, true )
			end
		end
		
		if currentVelocity:length() < 2 then
			if not self.sv.hasNudged then
				self.sv.needNudge = true
			end
			sm.physics.applyImpulse( self.shape, self.sv.windDirection * self.shape:getBody().mass * 0.01, true )
		else
			self.sv.needNudge = false
		end
		
		self.sv.selfdestructTicksLeft = self.sv.selfdestructTicksLeft - 1
		if self.sv.selfdestructTicksLeft == 0 then
			--self:sv_onHit( 100 )
			self.sv.fallen = true
			self.network:setClientData( { fallen = self.sv.fallen } )
		end
		
		local crownDir = self.shape.worldRotation * sm.vec3.new( 0 , 1, 0 )
		local fallenDeg = math.deg( math.acos( sm.vec3.new( 0, 0, 1 ):dot( crownDir ) ) )
		if fallenDeg > 80 and self.sv.selfdestructTicksLeft > 20 then
			self.sv.selfdestructTicksLeft = 20
		end
	end
end

function TreeTrunk.server_onMelee( self, position, attacker, damage, power, hitDirection )
	if not self.sv.fallen then
		self.sv.fallen = true
		self.network:setClientData( { fallen = self.sv.fallen } )
	end
	if self.data then
		if self.data.treeType == "small" or self.data.treeType == "medium" then
			self:sv_onHit( DamagerPerHit )
			if self.sv.health > 0 then
				self:sv_triggerCreak( position )
			end
		elseif self.data.treeType == "large" then
			if type( attacker ) == "Player" then
				self.network:sendToClient( attacker, "cl_n_onMessage", "#{ALERT_TREE_TOO_BIG}" )
			end
			if g_survivalDev or type( attacker ) == "Unit" then
				self:sv_onHit( DamagerPerHit )
			end
		end
	end
end

function TreeTrunk.sv_onHit( self, damage )
	if self.sv.health > 0 then
		self.sv.health = self.sv.health - damage
		if self.sv.health <= 0 then
			local worldPosition = self.shape.worldPosition
			if self.data then
				if self.data.treeType and not self.data.stump then
					if self.data.treeType == "small" then
						local shapeOffset = sm.item.getShapeOffset( obj_harvest_log_s01 )
						local rotation = self.shape.worldRotation
						sm.shape.createPart( obj_harvest_log_s01, worldPosition - rotation * shapeOffset, rotation )
						sm.effect.playEffect( "Tree - BreakTrunk Birch", worldPosition, nil, self.shape.worldRotation )
					elseif self.data.treeType == "medium" then
						local shapeOffset = sm.item.getShapeOffset( obj_harvest_log_m01 )
						local halfOffset = sm.vec3.new( shapeOffset.x, 0, 0 )
						local rotation = self.shape.worldRotation
						local halfTurn = sm.vec3.getRotation( sm.vec3.new( 1, 0, 0 ), sm.vec3.new( -1, 0, 0 ) )
						sm.shape.createPart( obj_harvest_log_m01, worldPosition - rotation * shapeOffset + rotation * halfOffset, rotation )
						sm.shape.createPart( obj_harvest_log_m01, worldPosition - ( rotation * halfTurn ) * shapeOffset - rotation * halfOffset, rotation * halfTurn )
						sm.effect.playEffect( "Tree - BreakTrunk Spruce", worldPosition, nil, self.shape.worldRotation )
					elseif self.data.treeType == "large" then
						local shapeOffset = sm.item.getShapeOffset( obj_harvest_log_l01 )
						local halfOffset = sm.vec3.new( shapeOffset.x, 0, 0 )
						local rotation = self.shape.worldRotation
						local halfTurn = sm.vec3.getRotation( sm.vec3.new( 1, 0, 0 ), sm.vec3.new( -1, 0, 0 ) )
						sm.shape.createPart( obj_harvest_log_l01, worldPosition - rotation * shapeOffset + rotation * halfOffset, rotation )
						sm.shape.createPart( obj_harvest_log_l01, worldPosition - ( rotation * halfTurn ) * shapeOffset - rotation * halfOffset, rotation * halfTurn )
						sm.effect.playEffect( "Tree - BreakTrunk Pine", worldPosition, nil, self.shape.worldRotation )
					end
				end
			end
			
			sm.shape.destroyPart(self.shape)
		end
	end
end

function TreeTrunk.server_onExplosion( self, center, destructionLevel )
	self:sv_onHit( destructionLevel * DamagerPerHit, center )
end

function TreeTrunk.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )	
	
	if type( other ) == "Shape" and sm.exists( other ) then
		if other.shapeUuid == obj_powertools_sawblade then
			local angularVelocity = other.body.angularVelocity
			if angularVelocity:length() > SPINNER_ANGULAR_THRESHOLD then
				local damage = 2.5
				self:sv_onHit( damage, collisionPosition )
			end
		end
	end
	
	if not self.sv.fallen then
		if selfPointVelocity:length() > 5.0 or other == nil then
			self.sv.fallen = true
			self.network:setClientData( { fallen = self.sv.fallen } )
		end
	end

end

function TreeTrunk.sv_triggerCreak( self, position )
	
	if self.shape.body:isStatic() then
		local lostHp = self.sv.effect.startHealth - self.sv.health
		local creakLevel = 1 + math.modf( lostHp / DamagerPerHit )
	
		sm.effect.playEffect( "Tree - Creak", position, nil, nil, nil, { tree_creaking = creakLevel } )
	end
end

-- Client

function TreeTrunk.client_onCreate( self )
	self:cl_init()
end

function TreeTrunk.cl_init( self ) 
	self.cl = {}
	self.cl.pristine = false
	self.cl.crown = false
	
	if self.data then
		if self.data.hideSubmeshes then
			self.interactable:setSubMeshVisible( "submesh0_bark", true )
			self.interactable:setSubMeshVisible( "submesh0_leaves", true )
			self.interactable:setSubMeshVisible( "submesh0_innerwood", true )
			self.interactable:setSubMeshVisible( "submesh1_bark", false )
			self.interactable:setSubMeshVisible( "submesh1_innerwood", false )
		end
		if self.data.crown then
			self.cl.crown = true
			self.cl.previousClientPosition = self.shape.worldPosition
			self.cl.fallEffect = sm.effect.createEffect( "Tree - Falling", self.interactable )
		end
	end
end

function TreeTrunk.client_onFixedUpdate( self, dt )
	if self.cl.crown then
		local currentPosition = self.shape.worldPosition
		local currentVelocity = ( currentPosition - self.cl.previousClientPosition ) / dt
		local velocityLength = currentVelocity:length()
		
		self.cl.previousClientPosition = currentPosition
		
		if self.cl.fallEffect and self.cl.pristine then
			self.cl.fallEffect:setParameter( "velocity_tree", velocityLength )
		
			if velocityLength > 0 then
				if not self.cl.fallEffect:isPlaying() then
					self.cl.fallEffect:start()
				end
			end
		end
	end
end

function TreeTrunk.client_onMelee( self, hitPos, attacker, damage, power, hitDirection, hitNormal )
	if type( attacker ) == "Player" then
		local rotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), hitNormal )
		if self.data and self.data.treeType == "small" then
			sm.effect.playEffect( "Tree - BirchHit", hitPos, nil, rotation )
		else
			sm.effect.playEffect( "Tree - DefaultHit", hitPos, nil, rotation )
		end
	end
end

function TreeTrunk.client_onClientDataUpdate( self, clientData )
	
	if clientData.pristine then
		self.cl.pristine = true
	end
	
	if clientData.fallen then
		if self.data then
			if self.data.fallenEffects then
				if self.cl.pristine then
					for _, effect in ipairs( self.data.fallenEffects ) do
						local offsetPosition = sm.vec3.new( effect.offsetPosition.x, effect.offsetPosition.y, effect.offsetPosition.z )
						local worldPosition = self.shape.worldPosition + self.shape.worldRotation * offsetPosition
						sm.effect.playEffect( effect.effectName, worldPosition, nil, self.shape.worldRotation, nil, { Color = self.shape:getColor() } )
					end
					self.cl.pristine = false
				end
			end
				
			if self.data.hideSubmeshes then
				if clientData.fallen then
					self.interactable:setSubMeshVisible( "submesh0_bark", false )
					self.interactable:setSubMeshVisible( "submesh0_leaves", false )
					self.interactable:setSubMeshVisible( "submesh0_innerwood", false )
					self.interactable:setSubMeshVisible( "submesh1_bark", true )
					self.interactable:setSubMeshVisible( "submesh1_innerwood", true )
				end
			end
		end
	end
end

function TreeTrunk.cl_n_onMessage( self, msg )
	sm.gui.displayAlertText( msg, 2 )
end
