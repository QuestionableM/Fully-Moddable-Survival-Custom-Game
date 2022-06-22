-- LostItems.lua --

LostItems = class( nil )

function LostItems.server_onCreate( self )
	local container = self.shape.interactable:getContainer( 0 )
	if container then
		container.allowSpend = true
		container.allowCollect = false
	end
	
	self.sv = {}
	self.sv.loaded = true
	
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
	end
	if self.params then
		if self.params.owner then
			self.sv.saved.owner = self.params.owner
		end
	end
	self.storage:save( self.sv.saved )
	self.network:setClientData( self.sv.saved )

	g_respawnManager:sv_unmarkBag( self.shape )
end

function LostItems.server_onUnload( self )
	if self.sv.loaded then
		g_respawnManager:sv_markBag( self.shape, self.sv.saved.owner )
		self.sv.loaded = false
	end
end

function LostItems.server_onDestroy( self )
	if self.sv.loaded then
		g_respawnManager:sv_unmarkBag( self.shape )
		self.sv.loaded = false
	end
end

function LostItems.client_onCreate( self )
	if self.cl == nil then
		self.cl = {}
	end
end

function LostItems.client_onDestroy( self )
	if self.cl.iconGui then
		self.cl.iconGui:close()
		self.cl.iconGui:destroy()
	end
	if self.cl.containerGui then
		if sm.exists( self.cl.containerGui ) then
			self.cl.containerGui:close()
			self.cl.containerGui:destroy()
		end
	end
end

function LostItems.client_onClientDataUpdate( self, clientData )
	if self.cl == nil then
		self.cl = {}
	end
	self.cl.owner = clientData.owner
	
	if sm.localPlayer.getPlayer() == self.cl.owner then
		self.cl.iconGui = sm.gui.createWorldIconGui( 32, 32, "$GAME_DATA/Gui/Layouts/Hud/Hud_WorldIcon.layout", false )
		self.cl.iconGui:setImage( "Icon", "icon_lostitem_large.png" )
		self.cl.iconGui:setHost( self.shape )
		self.cl.iconGui:setRequireLineOfSight( false )
		self.cl.iconGui:open()
		self.cl.iconGui:setMaxRenderDistance( 10000 )
	end
end

function LostItems.server_onFixedUpdate( self )
	local container = self.shape.interactable:getContainer( 0 )
	if container == nil or container:isEmpty() then
		sm.shape.destroyShape( self.shape )
	end
end

function LostItems.client_onInteract( self, character, state )
	if state == true then
		local container = self.shape.interactable:getContainer( 0 )
		if container then
			self.cl.containerGui = sm.gui.createContainerGui( true )
			self.cl.containerGui:setText( "UpperName", "#{CHEST_TITLE_LOST_ITEMS}" )
			self.cl.containerGui:setVisible( "ChestIcon", false )
			self.cl.containerGui:setVisible( "LostItemsIcon", true )
			self.cl.containerGui:setVisible( "TakeAll", true )
			self.cl.containerGui:setContainer( "UpperGrid", container );
			self.cl.containerGui:setText( "LowerName", "#{INVENTORY_TITLE}" )
			self.cl.containerGui:setContainer( "LowerGrid", sm.localPlayer.getInventory() )
			self.cl.containerGui:open()
		end
	end
end

function LostItems.cl_markBag( self )
	self.cl.iconGui = sm.gui.createWorldIconGui( 32, 32, "$GAME_DATA/Gui/Layouts/Hud/Hud_WorldIcon.layout", false )
	self.cl.iconGui:setImage( "Icon", "gui_icon_kobag.png" )
	self.cl.iconGui:setHost( self.shape )
	self.cl.iconGui:setRequireLineOfSight( false )
	self.cl.iconGui:open()
end
