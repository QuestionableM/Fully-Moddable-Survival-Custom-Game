dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_units.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")

PesticideManager = class( nil )

local PesticideLifeTicks = 40 * 12.0

-- Server side
function PesticideManager.sv_onCreate( self )
	self.sv = {}
	self.sv.pesticideIdx = 1
	self.sv.pesticideObjs = {}
end

function PesticideManager.sv_onWorldFixedUpdate( self, worldSelf )
	for pesticideId, pesticideObj in pairs( self.sv.pesticideObjs ) do
		pesticideObj.ticks = pesticideObj.ticks - 1
		if pesticideObj.ticks <= 0 then
			self:sv_removePesticide( worldSelf, pesticideId )
		end
	end
end


function PesticideManager.sv_addPesticide( self, worldSelf, position, rotation )

	local pesticideId = tostring( self.sv.pesticideIdx )
	self.sv.pesticideIdx = self.sv.pesticideIdx + 1

	local areaTrigger = sm.areaTrigger.createBox( PESTICIDE_SIZE * 0.5, position, rotation, sm.areaTrigger.filter.character, { pesticideId = pesticideId } )
	areaTrigger:bindOnStay( "trigger_onStayPesticide", self )

	local pesticideObj = {
		areaTrigger = areaTrigger,
		ticks = PesticideLifeTicks
	}
	self.sv.pesticideObjs[pesticideId] = pesticideObj

	worldSelf.network:sendToClients( "cl_n_pesticideMsg", { fn = "cl_n_addPesticide", pesticideId = pesticideId, position = position, rotation = rotation } )
end

function PesticideManager.sv_removePesticide( self, worldSelf, pesticideId )
	local pesticideObj = self.sv.pesticideObjs[pesticideId]
	if pesticideObj ~= nil then
		sm.areaTrigger.destroy( pesticideObj.areaTrigger )
		self.sv.pesticideObjs[pesticideId] = nil

		worldSelf.network:sendToClients( "cl_n_pesticideMsg", { fn = "cl_n_removePesticide", pesticideId = pesticideId } )
	end
end

function PesticideManager.trigger_onStayPesticide( self, trigger, results )
	for _, result in ipairs( results ) do
		if sm.exists( result ) then
			if type( result ) == "Character" then
				if result:isPlayer() then
					sm.event.sendToPlayer( result:getPlayer(), "sv_e_onStayPesticide" )
				end
			end
		end
	end
end

-- Client side
function PesticideManager.cl_onCreate( self )
	self.cl = {}
	self.cl.pesticideObjs = {}
end

function PesticideManager.cl_n_addPesticide( self, msg )
	local pesticideObj = {
		effect = sm.effect.createEffect( "Pesticide - Cloud" )
	}
	pesticideObj.effect:setPosition( msg.position )
	pesticideObj.effect:setRotation( msg.rotation )
	pesticideObj.effect:start()
	self.cl.pesticideObjs[msg.pesticideId] = pesticideObj
end

function PesticideManager.cl_n_removePesticide( self, msg )
	local pesticideObj = self.cl.pesticideObjs[msg.pesticideId]
	if pesticideObj ~= nil then
		pesticideObj.effect:stop()
		pesticideObj.effect:destroy()
		self.cl.pesticideObjs[msg.pesticideId] = nil
	end
end
