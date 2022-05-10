-- Bed.lua --

Bed = class( nil )

function Bed.server_onDestroy( self )
	if self.loaded then
		g_respawnManager:sv_destroyBed( self.shape )
		self.loaded = false
	end
end

function Bed.server_onUnload( self )
	if self.loaded then
		g_respawnManager:sv_updateBed( self.shape )
		self.loaded = false
	end
end

function Bed.sv_activateBed( self, character )
	g_respawnManager:sv_registerBed( self.shape, character )
end

function Bed.server_onCreate( self )
	self.loaded = true
end

function Bed.server_onFixedUpdate( self )
	local prevWorld = self.currentWorld
	self.currentWorld = self.shape.body:getWorld()
	if prevWorld ~= nil and self.currentWorld ~= prevWorld then
		g_respawnManager:sv_updateBed( self.shape )
	end
end

-- Client

function Bed.client_onInteract( self, character, state )
	if state == true then
		if self.shape.body:getWorld().id > 1 then
			sm.gui.displayAlertText( "#{INFO_HOME_NOT_STORED}" )
		else
			self.network:sendToServer( "sv_activateBed", character )
			self:cl_seat()
			sm.gui.displayAlertText( "#{INFO_HOME_STORED}" )
		end
	end
end

function Bed.cl_seat( self )
	if sm.localPlayer.getPlayer() and sm.localPlayer.getPlayer():getCharacter() then
		self.interactable:setSeatCharacter( sm.localPlayer.getPlayer():getCharacter() )
	end
end

function Bed.client_onAction( self, controllerAction, state )
	local consumeAction = true
	if state == true then
		if controllerAction == sm.interactable.actions.use or controllerAction == sm.interactable.actions.jump then
			self:cl_seat()
		else
			consumeAction = false
		end
	else
		consumeAction = false
	end
	return consumeAction
end