
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

KeyTool = class()

function KeyTool.client_onEquippedUpdate( self, primaryState, secondaryState )

	local success, result = sm.localPlayer.getRaycast( 7.5 )
	if success and result.type == "body" then
		local targetShape = result:getShape()
		if isAnyOf( targetShape:getShapeUuid(), { obj_survivalobject_powercoresocket, obj_survivalobject_cardreader } ) then
			if primaryState == sm.tool.interactState.start then
				local params = { targetShape = targetShape, keyId = sm.localPlayer.getActiveItem() }
				self.network:sendToServer( "sv_n_use", params )
			end
			return true, false
		end
	end

	return false, false

end

function KeyTool.client_onEquip( self ) end

function KeyTool.client_onUnequip( self ) end

function KeyTool.sv_n_use( self, params, player )
	if params.targetShape.interactable then
		params.player = player
		sm.event.sendToInteractable( params.targetShape.interactable, "sv_e_unlock", params )
	end
end
