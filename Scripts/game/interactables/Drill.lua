-- Drill.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")

Drill = class( nil )

function Drill.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	local otherType = type( other )
	if ( otherType == "Harvestable" or otherType == "Shape" ) and sm.exists( other ) then
		local angularVelocity = self.shape.body.angularVelocity
		if angularVelocity:length() > SPINNER_ANGULAR_THRESHOLD then
			sm.physics.applyImpulse( self.shape, sm.vec3.new( 0, self.shape.mass * 0.25, 0 ), false )
		end
	end
end

function Drill.client_onCreate( self )
	self.drillEffect = sm.effect.createEffect( "Drill - StoneDrill", self.interactable )
	self.stoneEffect = sm.effect.createEffect( "Stone - Stress" )
	self.remainingDrillTicks = 0
	self.remainingImpactTicks = 0
end

function Drill.client_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	local angularVelocity = self.shape.body.angularVelocity
	if angularVelocity:length() > SPINNER_ANGULAR_THRESHOLD then
		local otherType = type( other )
		local mass = 250
		local materialId = 0
		if ( otherType == "Harvestable" or otherType == "Shape" ) and sm.exists( other ) then
			materialId = other.materialId
			if otherType == "Shape" then
				mass = other.mass
			end
		end
	
		if not sm.isHost then
			sm.physics.applyImpulse( self.shape, sm.vec3.new( 0, self.shape.mass * 0.25, 0 ), false )
		end
		direction = ( selfPointVelocity + otherPointVelocity ):normalize()

		self.stoneEffect:setPosition( collisionPosition )
		self.stoneEffect:setParameter( "size", mass / AUDIO_MASS_DIVIDE_RATIO )
		self.stoneEffect:setParameter( "velocity_max_50", angularVelocity:length() )
		self:cl_triggerEffect( collisionPosition, direction, materialId )
	end
end

-- Client

function Drill.cl_triggerEffect( self, position, direction, materialId )
	local rotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), direction )
	sm.effect.playEffect( "Drill - Debris", position, nil, rotation, nil, { drill_material = materialId } )
	
	self.remainingImpactTicks = 60
	if materialId == 6 then -- Drilling stone
		self.remainingDrillTicks = 5
	end
end

function Drill.client_onFixedUpdate( self, deltaTime )

	local velocity = self.shape:getBody():getAngularVelocity():length()
	if self.remainingImpactTicks > 0 then
		self.drillEffect:setParameter( "impact", 1 )		
		self.remainingImpactTicks = self.remainingImpactTicks - 1
	else
		self.drillEffect:setParameter( "impact", 0 )
	end

	if self.remainingDrillTicks > 0 then
		if not self.stoneEffect:isPlaying() then
			self.stoneEffect:start()
		end
		self.remainingDrillTicks = self.remainingDrillTicks - 1
	else
		if self.stoneEffect:isPlaying() then
			self.stoneEffect:stop()
		end
	end
	
	local effectVelocity = clamp( velocity, 0, 50 ) / 50
	self.drillEffect:setParameter( "velocity", effectVelocity )
	
	if velocity > 0 then
		if self.drillEffect:isPlaying() == false then
			self.drillEffect:start()
		end
	else
		if self.drillEffect:isPlaying() == true then
			self.drillEffect:stop()
		end
	end
	
end