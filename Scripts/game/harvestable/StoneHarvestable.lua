-- StoneHarvestable.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")

StoneHarvestable = class( nil )
StoneHarvestable.ChunkHealth = 100
StoneHarvestable.DamagerPerHit = 25

function StoneHarvestable.server_onCreate( self )
	self:sv_init()
end

function StoneHarvestable.server_onRefresh( self ) 
	self:sv_init()
end

function StoneHarvestable.sv_init( self )
	self.stoneParts = nil
end

function StoneHarvestable.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
	if type( attacker ) == "Player" then
		self.network:sendToClient( attacker, "cl_n_onMessage", "#{ALERT_STONE_TOO_BIG}" )
	end
	if g_survivalDev then
		self:sv_onHit( self.DamagerPerHit, hitPos )
	end
end

function StoneHarvestable.sv_onHit( self, damage, position )
	
	if not sm.exists( self.harvestable ) then
		return
	end
	
	local harvestablePosition = sm.harvestable.getPosition( self.harvestable )
	local harvestableRotation = sm.harvestable.getRotation( self.harvestable )
	
	if self.stoneParts == nil then
		-- Create a table of stone parts that can remember damage to the stone
		self.stoneParts = {}
		if self.data then
			if self.data.blueprint then
				local blueprintObject = sm.json.open( self.data.blueprint )
				for _, body in pairs( blueprintObject.bodies ) do
					for _, shape in pairs( body.childs ) do
						local localPosition = sm.vec3.new( shape.pos.x, shape.pos.y, shape.pos.z )
						local shapeUuid = sm.uuid.new( shape.shapeId )
						local shapeOffset = sm.item.getShapeOffset( shapeUuid )
						
						local zAxis = sm.vec3.new( 	( shape.zaxis == 1 and 1 or 0 ) + ( shape.zaxis == -1 and -1 or 0 ), 
													( shape.zaxis == 2 and 1 or 0 ) + ( shape.zaxis == -2 and -1 or 0 ), 
													( shape.zaxis == 3 and 1 or 0 ) + ( shape.zaxis == -3 and -1 or 0 ) )
						local xAxis = sm.vec3.new( 	( shape.xaxis == 1 and 1 or 0 ) + ( shape.xaxis == -1 and -1 or 0 ), 
													( shape.xaxis == 2 and 1 or 0 ) + ( shape.xaxis == -2 and -1 or 0 ), 
													( shape.xaxis == 3 and 1 or 0 ) + ( shape.xaxis == -3 and -1 or 0 ) )
						local yAxis = zAxis:cross( xAxis )
						local rotatedShapeOffset = sm.vec3.new( xAxis.x * shapeOffset.x + yAxis.x * shapeOffset.y + zAxis.x * shapeOffset.z,
																xAxis.y * shapeOffset.x + yAxis.y * shapeOffset.y + zAxis.y * shapeOffset.z,
																xAxis.z * shapeOffset.x + yAxis.z * shapeOffset.y + zAxis.z * shapeOffset.z	)

						local worldPosition = harvestablePosition + harvestableRotation * ( localPosition * 0.25 ) + harvestableRotation * rotatedShapeOffset
						self.stoneParts[#self.stoneParts+1] = { shapeUuid = shapeUuid, centerPosition = worldPosition, damage = 0 }
					end
				end
			end
		end
	end

	-- Find the stone part that was closest to the attack
	local closestHitIdx = nil
	local closestHitDistance = math.huge
	for i, stonePart in ipairs( self.stoneParts ) do	
		if position then
			local distance = ( stonePart.centerPosition - position ):length()
			if closestHitIdx then
				if distance < closestHitDistance then
					closestHitIdx = i
					closestHitDistance = distance
				end
			else
				closestHitIdx = i
				closestHitDistance = distance
			end
		end
	end
	
	-- Tally damage for the stone part
	if closestHitIdx then
		self.stoneParts[closestHitIdx].damage = self.stoneParts[closestHitIdx].damage + damage
		-- Destroy the harvestable and turn it into parts
		local color = self.harvestable:getColor()
		if self.stoneParts[closestHitIdx].damage >= self.ChunkHealth then
			if self.data then
				if self.data.blueprint then
					local placementOffset = sm.vec3.new( -0.5, -0.5, -0.5 )
					if self.data.offset then
						placementOffset = sm.vec3.new( self.data.offset.x, self.data.offset.y, self.data.offset.z )
					end
					placementOffset = harvestableRotation * placementOffset
					local bodies = sm.creation.importFromFile( nil, self.data.blueprint, harvestablePosition + placementOffset, harvestableRotation )
					
					-- Parts inherit damage from the harvestable
					for _, currentBody in ipairs( bodies ) do
						local shapes = currentBody:getShapes()
						for _, currentShape in ipairs( shapes ) do
							currentShape:setColor( color )
						end
					end
					
					-- Inherit damage
					local stoneBody = bodies[1]
					if stoneBody then
						for i, stonePart in ipairs( self.stoneParts ) do
							local closestShape = getClosestShape( stoneBody, stonePart.centerPosition )
							if closestShape then
								if closestShape:getShapeUuid() == stonePart.shapeUuid then
									closestShape.interactable:setParams( { inheritedDamage = stonePart.damage } )
								end
							end
						end
					end
					
				end
			end
			sm.harvestable.destroy(self.harvestable)
		end
	end
	
end

function StoneHarvestable.cl_n_onMessage( self, msg )
	sm.gui.displayAlertText( msg, 2 )
end

function StoneHarvestable.server_onExplosion( self, center, destructionLevel )
	self:sv_onHit( 100.0, center )
end

function StoneHarvestable.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	if type( other ) == "Shape" and sm.exists( other ) then
		if other.shapeUuid == obj_powertools_drill then
			local angularVelocity = other.body.angularVelocity
			if angularVelocity:length() > SPINNER_ANGULAR_THRESHOLD then
				local damage = math.min( 2.5, angularVelocity:length() )
				self:sv_onHit( damage, collisionPosition )
			end
		end
	end
end

function StoneHarvestable.sv_e_plasmaDrill( self, params )
	self:sv_onHit( 2.5, params.position )
end