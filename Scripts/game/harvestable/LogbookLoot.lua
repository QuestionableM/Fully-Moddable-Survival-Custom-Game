-- LogbookLoot.lua --

LogbookLoot = class( nil )

function LogbookLoot.server_onCreate( self )
	sm.harvestable.destroy( self.harvestable )
end
