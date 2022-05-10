-- TreeLog.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")

TreeLog = class( nil )

local LogHealth = 100
local DamagerPerHit = math.ceil( LogHealth / TREE_LOG_HITS )

function TreeLog.server_onCreate( self )
	self:server_init()
end

function TreeLog.server_onRefresh( self )
	self:server_init()
end

function TreeLog.server_init( self )
	self.health = LogHealth
end

function TreeLog.server_onMelee( self, position, attacker, damage, power, hitDirection )
	self:sv_onHit( DamagerPerHit )
end

function TreeLog.sv_onHit( self, damage )
	if self.health > 0 then
		self.health = self.health - damage
		if self.health <= 0 then
			local worldPosition = self.shape.worldPosition
			if self.data then
				if self.data.treeType then
					if self.data.treeType == "small" then
						local shapeOffset = sm.item.getShapeOffset( obj_harvest_wood )
						local rotation = sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), self.shape.at )
						sm.shape.createPart( obj_harvest_wood, worldPosition - rotation * shapeOffset, rotation )
						sm.effect.playEffect( "Tree - BreakTrunk Birch", worldPosition, nil, self.shape.worldRotation )
					elseif self.data.treeType == "medium" then
						local shapeOffset = sm.item.getShapeOffset( obj_harvest_wood )
						local rotation = sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), self.shape.at )
						sm.shape.createPart( obj_harvest_wood, worldPosition - rotation * shapeOffset, rotation )
						sm.effect.playEffect( "Tree - BreakTrunk SpruceHalf", worldPosition, nil, self.shape.worldRotation )
					elseif self.data.treeType == "large" then
						
						if self.data.size then
							if self.data.size == "half" then
								local shapeOffsetA = sm.item.getShapeOffset( obj_harvest_log_l02a )
								local halfOffsetA = sm.vec3.new( 0, 0, shapeOffsetA.z )
								local shapeOffsetB = sm.item.getShapeOffset( obj_harvest_log_l02b )
								local halfOffsetB = sm.vec3.new( 0, 0, shapeOffsetB.z )
								local rotation = self.shape.worldRotation
								local halfTurn = sm.vec3.getRotation( sm.vec3.new( 1, 0, 0 ), sm.vec3.new( 0, 0, -1 ) )
								sm.shape.createPart( obj_harvest_log_l02a, worldPosition - rotation * shapeOffsetA + rotation * halfOffsetA, rotation )
								sm.shape.createPart( obj_harvest_log_l02b, worldPosition - ( rotation * halfTurn ) * shapeOffsetB - rotation * halfOffsetB, rotation * halfTurn )
								sm.effect.playEffect( "Tree - BreakTrunk PineHalf", worldPosition, nil, self.shape.worldRotation )
							elseif self.data.size == "quarter" then
								local shapeOffset = sm.item.getShapeOffset( obj_harvest_wood2 )
								local rotation = sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), self.shape.at )
								sm.shape.createPart( obj_harvest_wood2, worldPosition - rotation * shapeOffset, rotation )
								sm.effect.playEffect( "Tree - BreakTrunk PineQuarter", worldPosition, nil, self.shape.worldRotation )
							end
						end
					end
				end
			end
			
			sm.shape.destroyPart(self.shape)
		end
	end
end

function TreeLog.server_onExplosion( self, center, destructionLevel )
	self:sv_onHit( destructionLevel * DamagerPerHit )
end

function TreeLog.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	
	if type( other ) == "Shape" and sm.exists( other ) then
		if other.shapeUuid == obj_powertools_sawblade then
			local angularVelocity = other.body.angularVelocity
			if angularVelocity:length() > SPINNER_ANGULAR_THRESHOLD then
				local damage = 5
				if self.data.size and self.data.size == "half" then
					damage = 4
				end
				self:sv_onHit( damage )
			end
		end
	end
	
end

function TreeLog.client_onMelee( self, hitPos, attacker, damage, power, hitDirection, hitNormal )
	if type( attacker ) == "Player" then
		local rotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), hitNormal )
		if self.data and self.data.treeType == "small" then
			sm.effect.playEffect( "Tree - BirchHit", hitPos, nil, rotation )
		else
			sm.effect.playEffect( "Tree - DefaultHit", hitPos, nil, rotation )
		end
	end
end