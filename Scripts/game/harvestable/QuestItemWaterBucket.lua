QuestItemWaterBucket = class( nil )

function QuestItemWaterBucket.server_onCreate( self )
end

function QuestItemWaterBucket.client_onCreate( self )
end

function QuestItemWaterBucket.client_canInteract( self )
	sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Attack", true ), "#{INTERACTION_PICK_UP}" )
	return true
end

function QuestItemWaterBucket.server_canErase( self )
	return true
end

function QuestItemWaterBucket.client_canErase( self )
	return true
end

function QuestItemWaterBucket.server_onRemoved( self, player )
	if not self.removed and sm.exists( self.harvestable ) then
		if sm.container.beginTransaction() then
			sm.container.collect( player:getInventory(), obj_tool_bucket_empty, 1, true )
			if sm.container.endTransaction() then
				self.harvestable:destroy()
				self.removed = true
			end
		end
	end
end
