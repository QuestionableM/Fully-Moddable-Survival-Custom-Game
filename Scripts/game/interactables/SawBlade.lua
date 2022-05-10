-- SawBlade.lua --

SawBlade = class( nil )

function SawBlade.client_onCreate( self )
	self.sawEffect = sm.effect.createEffect( "Saw - SawBlade", self.interactable )
	self.remainingImpactTicks = 0
end

function SawBlade.client_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	local otherType = type( other )
	local materialId = 0
	if ( otherType == "Harvestable" or otherType == "Shape" ) and sm.exists( other ) then
		materialId = other.materialId
	end
		
	local angularVelocity = self.shape.body.angularVelocity
	if angularVelocity:length() > SPINNER_ANGULAR_THRESHOLD then
		local direction = ( selfPointVelocity + otherPointVelocity ):normalize()
		self:cl_triggerEffect( collisionPosition, direction, materialId )
	end
end

-- Client

function SawBlade.cl_triggerEffect( self, position, direction, materialId )
	local rotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), direction )
	sm.effect.playEffect( "Saw - Debris", position, nil, rotation, nil, { saw_material = materialId } )
	
	self.remainingImpactTicks = 60
end

function SawBlade.client_onFixedUpdate( self, deltaTime )

	local velocity = self.shape:getBody():getAngularVelocity():length()
	if self.remainingImpactTicks > 0 then
		self.sawEffect:setParameter( "impact", 1 )		
		self.remainingImpactTicks = self.remainingImpactTicks - 1
	else
		self.sawEffect:setParameter( "impact", 0 )
	end
	
	local effectVelocity = clamp( velocity, 0, 50 ) / 50
	self.sawEffect:setParameter( "velocity", effectVelocity )
	
	if velocity > 0 then
		if self.sawEffect:isPlaying() == false then
			self.sawEffect:start()
		end
	else
		if self.sawEffect:isPlaying() == true then
			self.sawEffect:stop()
		end
	end
	
end