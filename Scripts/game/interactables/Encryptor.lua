dofile("$SURVIVAL_DATA/Scripts/util.lua")
dofile"$SURVIVAL_DATA/Scripts/game/survival_survivalobjects.lua"

Encryptor = class()
Encryptor.maxChildCount = 255
Encryptor.maxParentCount = 0
Encryptor.connectionInput = sm.interactable.connectionType.none
Encryptor.connectionOutput = sm.interactable.connectionType.logic

function Encryptor.server_onCreate( self )

	self.encryptions = {}
	if self.data then
		self.encryptions = self.data.encryptions
	end
	
	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = {}
		self.interactable.active = true
		self.prevActiveState = true
		self.saved.state = true
		self.saved.params = self.params
		self.storage:save( self.saved )
	else
		self.interactable.active = self.saved.state
		self.prevActiveState = self.saved.state

		if self.saved.params == nil then
			self.saved.params = self.params
			self.storage:save( self.saved )
		end
	end

	--self:server_updateRestrictions( not self.saved.state )
	
	self.loaded = true
end

function Encryptor.server_onUnload( self )
	self.loaded = false
end

function Encryptor.server_onDestroy( self )
	if self.loaded then
		--self:server_updateRestrictions( true )
			
		-- If the encryptor was loaded as part of a warehouse then it will sync the encryption state to all floors
		if self.saved.params then
			local restrictions = {}
			for i, encryption in ipairs( self.encryptions ) do
				restrictions[encryption] = { name = encryption, state = true }
			end
			
			local params = { warehouseIndex = self.saved.params.warehouseIndex, restrictions = restrictions }
			sm.event.sendToGame( "sv_e_setWarehouseRestrictions", params )
		end
		
		self.loaded = false
	end
end

function Encryptor.client_onInteract( self, character, state )
	if state == true then
		self.network:sendToServer( "server_switchActiveState", ( not self.interactable.active ) )
	end
	
	
end

function Encryptor.server_onFixedUpdate( self, timeStep )
	if self.interactable.active ~= self.prevActiveState then
		self.prevActiveState = self.interactable.active
		--self:server_updateRestrictions( not self.interactable.active )
		
		-- If the encryptor was loaded as part of a warehouse then it will sync the encryption state to all floors
		if self.saved.params then
			local restrictions = {}
			for i, encryption in ipairs( self.encryptions ) do
				restrictions[encryption] = { name = encryption, state = not self.interactable.active }
			end
			
			local params = { warehouseIndex = self.saved.params.warehouseIndex, restrictions = restrictions }
			sm.event.sendToGame( "sv_e_setWarehouseRestrictions", params )
		end
	end
end

function Encryptor.server_switchActiveState( self, requestedState )
	self.interactable.active = requestedState
	self.saved.state = requestedState
	self.storage:save( self.saved )
end

function Encryptor.server_updateRestrictions( self, encryptionActive )
	local body = self.shape:getBody()
	restrictionSwitch = switch {
		["destructable"] = function( x ) --[[print( x, encryptionActive )]] body.destructable = encryptionActive end,
		["buildable"] = function( x ) --[[print( x, encryptionActive)]] body.buildable = encryptionActive end,
		["paintable"] = function( x ) --[[print( x, encryptionActive)]] body.paintable = encryptionActive end,
		["connectable"] = function( x ) --[[print( x, encryptionActive)]] body.connectable = encryptionActive end,
		["liftable"] = function( x ) --[[print( x, encryptionActive)]] body.liftable = encryptionActive end,
		["erasable"] = function( x ) --[[print( x, encryptionActive)]] body.erasable = encryptionActive end,
		["usable"] = function( x ) --[[print( x, encryptionActive)]] body.usable = encryptionActive end,
		default = function( x ) print( x, "is not a valid encryption name.") end
	}	
	for i, encryption in ipairs( self.encryptions ) do
		restrictionSwitch:case( encryption )
	end

	local shapeUuid = self.shape:getShapeUuid()
	if shapeUuid == obj_interactive_encryptor_connection then
		if encryptionActive then
			sm.effect.playEffect( "Encryptor - Deactivation", self.shape.worldPosition, nil, self.shape.worldRotation )
		else
			sm.effect.playEffect( "Encryptor - Activation", self.shape.worldPosition, nil, self.shape.worldRotation )
		end
	elseif shapeUuid == obj_interactive_encryptor_destruction then
		if encryptionActive then
			sm.effect.playEffect( "Barrier - Deactivation", self.shape.worldPosition, nil, self.shape.worldRotation )
		else
			sm.effect.playEffect( "Barrier - Activation", self.shape.worldPosition, nil, self.shape.worldRotation )
		end
	end
end