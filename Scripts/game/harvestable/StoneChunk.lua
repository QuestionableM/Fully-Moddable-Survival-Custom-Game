-- StoneChunk.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")

StoneChunk = class( nil )
StoneChunk.DamagerPerHit = 25

function StoneChunk.server_onCreate( self )
	self:sv_init()
	
	if self.params then
		if self.params.inheritedDamage then
			self:sv_onHit( self.params.inheritedDamage )
		end
	end
end

function StoneChunk.server_onRefresh( self ) 
	self:sv_init()
end

function StoneChunk.sv_init( self ) 
	self.health = 100
end

function StoneChunk.server_onMelee( self, position, attacker, damage, power, hitDirection )
	if self.data then
		if self.data.chunkSize <= 2 then
			self:sv_onHit( self.DamagerPerHit )
		else
			if type( attacker ) == "Player" then
				self.network:sendToClient( attacker, "cl_n_onMessage", "#{ALERT_STONE_TOO_BIG}" )
			end
			if g_survivalDev then
				self:sv_onHit( self.DamagerPerHit )
			end
		end
	end
end

function StoneChunk.cl_n_onMessage( self, msg )
	sm.gui.displayAlertText( msg, 2 )
end

function StoneChunk.sv_onHit( self, damage )

	if self.health > 0 then
		self.health = self.health - damage
		if self.health <= 0 then
			local worldPosition = sm.shape.getWorldPosition(self.shape)
			if self.data then
				if self.data.chunkSize then
					if self.data.chunkSize == 1 then
						local harvest = math.random( 3 ) == 1 and obj_harvest_metal2 or obj_harvest_stone
						local shapeOffset = sm.item.getShapeOffset( harvest )
						local rotation = self.shape.worldRotation
						sm.shape.createPart( harvest, worldPosition - rotation * shapeOffset, rotation )
						sm.effect.playEffect( "Stone - BreakChunk small", worldPosition, nil, self.shape.worldRotation, nil, { size = self.shape:getMass() / AUDIO_MASS_DIVIDE_RATIO } )
					elseif self.data.chunkSize == 2 then
						local shapeOffset = sm.item.getShapeOffset( obj_harvest_stonechunk01 )
						local halfOffset = sm.vec3.new( 0, 0, shapeOffset.z )
						local rotation = self.shape.worldRotation
						local halfTurn = sm.vec3.getRotation( sm.vec3.new( 1, 0, 0 ), sm.vec3.new( -1, 0, 0 ) )
						sm.shape.createPart( obj_harvest_stonechunk01, worldPosition - rotation * shapeOffset + rotation * halfOffset, rotation )
						sm.shape.createPart( obj_harvest_stonechunk01, worldPosition - ( rotation * halfTurn ) * shapeOffset - rotation * halfOffset, rotation * halfTurn )
						sm.effect.playEffect( "Stone - BreakChunk small", worldPosition, nil, self.shape.worldRotation, nil, { size = self.shape:getMass() / AUDIO_MASS_DIVIDE_RATIO } )
					elseif self.data.chunkSize == 3 then
						local shapeOffset = sm.item.getShapeOffset( obj_harvest_stonechunk02 ) -- Same dimensions on both chunks
						local halfOffset = sm.vec3.new( shapeOffset.x, 0, 0 )
						local rotation = self.shape.worldRotation
						local halfTurn = sm.vec3.getRotation( sm.vec3.new( 1, 0, 0 ), sm.vec3.new( -1, 0, 0 ) )
						sm.shape.createPart( obj_harvest_stonechunk02, worldPosition - rotation * shapeOffset + rotation * halfOffset, rotation )
						sm.shape.createPart( obj_harvest_stonechunk03, worldPosition - ( rotation * halfTurn ) * shapeOffset - rotation * halfOffset, rotation * halfTurn )
						sm.effect.playEffect( "Stone - BreakChunk", worldPosition, nil, self.shape.worldRotation, nil, { size = self.shape:getMass() / AUDIO_MASS_DIVIDE_RATIO } )
					end
				end
			end
			
			sm.shape.destroyPart( self.shape )
		end
	end
end

function StoneChunk.server_onExplosion( self, center, destructionLevel )
	self:sv_onHit( 100.0 )
end

function StoneChunk.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	if type( other ) == "Shape" and sm.exists( other ) then
		if other.shapeUuid == obj_powertools_drill then
			local angularVelocity = other.body.angularVelocity
			if angularVelocity:length() > SPINNER_ANGULAR_THRESHOLD then
				local damage = 2.5
				if self.data.chunkSize then
					if self.data.chunkSize == 1 then
						damage = 5
					elseif self.data.chunkSize == 2 then
						damage = 4
					end
				end
				self:sv_onHit( damage )
			end
		end
	end
end

function StoneChunk.sv_e_plasmaDrill( self )
	local damage = 2.5
	if self.data.chunkSize then
		if self.data.chunkSize == 1 then
			damage = 5
		elseif self.data.chunkSize == 2 then
			damage = 4
		end
	end
	self:sv_onHit( damage )
end