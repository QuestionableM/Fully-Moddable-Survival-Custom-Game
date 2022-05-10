-- WoodHarvestable.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")

WoodHarvestable = class( nil )

local TrunkHealth = 100
local DamagerPerHit = math.ceil( TrunkHealth / TREE_TRUNK_HITS )

function WoodHarvestable.server_onCreate( self )
	self:sv_init()
end

function WoodHarvestable.server_onRefresh( self )
	self:sv_init()
end

function WoodHarvestable.sv_init( self )
	self.treeParts = nil
end

function WoodHarvestable.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
	if self.data then
		if self.data.type == "small" or self.data.type == "medium" then
			self:sv_onHit( DamagerPerHit, hitPos )
		elseif self.data.type == "large" then
			if type( attacker ) == "Player" then
				self.network:sendToClient( attacker, "cl_n_onMessage", "#{ALERT_TREE_TOO_BIG}" )
			end

			if g_survivalDev then
				self:sv_onHit( DamagerPerHit, hitPos )
			end
		end
	end
end

function WoodHarvestable.client_onMelee( self, hitPos, attacker, damage, power, hitDirection, hitNormal )
	if type( attacker ) == "Player" then
		local rotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), hitNormal )
		if self.data and self.data.type == "small" then
			sm.effect.playEffect( "Tree - BirchHit", hitPos, nil, rotation )
		else
			sm.effect.playEffect( "Tree - DefaultHit", hitPos, nil, rotation )
		end
	end
end

function WoodHarvestable.sv_onHit( self, damage, position )	
	
	if not sm.exists( self.harvestable ) or self.destroyed then
		return
	end
	
	if self.treeParts == nil then
		-- Create a table of tree parts that can remember damage to the tree
		self.treeParts = {}
		if self.data then
			if self.data.blueprint then
				local blueprintObject = sm.json.open( self.data.blueprint )
				for _, body in pairs( blueprintObject.bodies ) do
					for i, shape in pairs( body.childs ) do
						local localPosition = sm.vec3.new( shape.pos.x, shape.pos.y, shape.pos.z )
						local harvestablePosition = sm.harvestable.getPosition( self.harvestable )
						local harvestableRotation = sm.harvestable.getRotation( self.harvestable )
						local shapeUuid = sm.uuid.new( shape.shapeId )
						local shapeOffset = sm.item.getShapeOffset( shapeUuid )
						local worldPosition = harvestablePosition + harvestableRotation * ( localPosition * 0.25 ) + harvestableRotation * sm.vec3.new( 0, shapeOffset.y, 0 )
						if i == 1 and body.childs[2]  then
							-- Find center of stump
							local upperShape = body.childs[2]
							local upperLocalPosition = sm.vec3.new( shape.pos.x, shape.pos.y, shape.pos.z )
							worldPosition = harvestablePosition + harvestableRotation * upperLocalPosition * 0.25 + harvestableRotation * sm.vec3.new( 0, -1, 0 )
						end
						self.treeParts[#self.treeParts+1] = { shapeUuid = shapeUuid, centerPosition = worldPosition, damage = 0 }
					end			
				end
			end
		end
	end
	
	local harvestablePosition = sm.harvestable.getPosition( self.harvestable )
	local harvestableRotation = sm.harvestable.getRotation( self.harvestable )
	
	local rattlePosition = harvestablePosition
	if self.data and self.data.crownHeight then
		rattlePosition = harvestablePosition + ( harvestableRotation * sm.vec3.new( 0, 1, 0 ) ) * self.data.crownHeight
	end
	sm.effect.playEffect( "Tree - LeafRattle", rattlePosition )

	-- Find the tree part that was closest to the attack
	local closestHitIdx = nil
	local closestHitDistance = math.huge
	for i, treePart in ipairs( self.treeParts ) do	
		if position then
			local distance = ( treePart.centerPosition - position ):length()
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
	
	-- Tally damage for the tree part
	if closestHitIdx then
		self.treeParts[closestHitIdx].damage = self.treeParts[closestHitIdx].damage + damage
		-- Destroy the harvestable and turn it into parts
		local color = self.harvestable:getColor()
		if self.treeParts[closestHitIdx].damage >= TrunkHealth then
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
							for i, treePart in ipairs( self.treeParts ) do	
								if currentShape:getShapeUuid() == treePart.shapeUuid then
									currentShape.interactable:setParams( { inheritedDamage = treePart.damage, pristine = true } )
								end
							end
						end
					end
				end
			end
			
			self.destroyed = true
			sm.effect.playEffect( "Tree - LogAppear", harvestablePosition )
			sm.harvestable.destroy(self.harvestable)
		else
			self:sv_triggerCreak( self.treeParts[closestHitIdx] )
		end
	end
	
end

function WoodHarvestable.sv_triggerCreak( self, treePart )
	local creakLevel = 1 + math.modf( treePart.damage / DamagerPerHit )
	sm.effect.playEffect( "Tree - Creak", treePart.centerPosition, nil, nil, nil, { tree_creaking = creakLevel } )
end

function WoodHarvestable.cl_n_onMessage( self, msg )
	sm.gui.displayAlertText( msg, 2 )
end

function WoodHarvestable.server_onExplosion( self, center, destructionLevel )
	self:sv_onHit( destructionLevel * DamagerPerHit, center )
end

function WoodHarvestable.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	if type( other ) == "Shape" and sm.exists( other ) then
		if other.shapeUuid == obj_powertools_sawblade then
			local angularVelocity = other.body.angularVelocity
			if angularVelocity:length() > SPINNER_ANGULAR_THRESHOLD then
				local damage = math.min( 2.5, angularVelocity:length() )
				self:sv_onHit( damage, collisionPosition )
			end
		end
	end
end

function WoodHarvestable.client_onCreate( self )
	self.cl = {}
	local crownPosition = self.harvestable.worldPosition
	if self.data and self.data.crownHeight then
		crownPosition = self.harvestable.worldPosition + ( self.harvestable.worldRotation * sm.vec3.new( 0, 1, 0 ) ) * self.data.crownHeight
	end
	self.harvestable.clientPublicData = { crownPosition = crownPosition }
end

function WoodHarvestable.client_onDestroy( self )
	if self.cl.birdsEffect then
		self.cl.birdsEffect:destroy()
		self.cl.birdsEffect = nil
	end
end

function WoodHarvestable.client_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )

	local impactVelocity = ( selfPointVelocity - otherPointVelocity ):length()

	if impactVelocity > 0.1 and sm.exists( self.harvestable ) then
		local harvestablePosition = sm.harvestable.getPosition( self.harvestable )
		local harvestableRotation = sm.harvestable.getRotation( self.harvestable )			
		local treeUp = sm.vec3.new( 0, 1, 0 )
		
		local rattlePosition = harvestablePosition
		
		if self.data and self.data.crownHeight then
			rattlePosition = harvestablePosition + ( harvestableRotation * treeUp ) * self.data.crownHeight
		end
		
		sm.effect.playEffect( "Tree - LeafRattle", rattlePosition, nil, nil, nil, { Velocity_max_50 = impactVelocity } )
	end
end