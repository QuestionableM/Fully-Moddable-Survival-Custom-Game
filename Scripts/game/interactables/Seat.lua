-- Seat.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_units.lua")

Seat = class()
Seat.maxChildCount = 10
Seat.connectionOutput = sm.interactable.connectionType.seated
Seat.colorNormal = sm.color.new( 0x00ff80ff )
Seat.colorHighlight = sm.color.new( 0x6affb6ff )

Seat.Levels = {
	[tostring(obj_scrap_seat)] = { maxConnections = 2 },
	[tostring(obj_interactive_seat_01)] = { maxConnections = 2, upgrade = obj_interactive_seat_02, cost = 1, title = "#{LEVEL} 1" },
	[tostring(obj_interactive_seat_02)] = { maxConnections = 4, upgrade = obj_interactive_seat_03, cost = 1, title = "#{LEVEL} 2" },
	[tostring(obj_interactive_seat_03)] = { maxConnections = 6, upgrade = obj_interactive_seat_04, cost = 1, title = "#{LEVEL} 3" },
	[tostring(obj_interactive_seat_04)] = { maxConnections = 8, upgrade = obj_interactive_seat_05, cost = 1, title = "#{LEVEL} 4" },
	[tostring(obj_interactive_seat_05)] = { maxConnections = 10, title = "#{LEVEL} 5"},
}

--[[ Server ]]

function Seat.server_onCreate( self )

end

function Seat.server_onFixedUpdate( self )
	self.interactable:setActive( self.interactable:getSeatCharacter() ~= nil )
end

function Seat.sv_n_tryUpgrade( self, player )
	local level = self.Levels[tostring( self.shape:getShapeUuid() )]
	if level and level.upgrade then
		local function fnUpgrade()
			local nextLevel = self.Levels[tostring( level.upgrade )]
			assert( nextLevel )
			self.network:sendToClients( "cl_n_onUpgrade", level.upgrade )

			self.shape:replaceShape( level.upgrade )
		end

		if sm.game.getEnableUpgrade() then
			local inventory = player:getInventory()

			if sm.container.totalQuantity( inventory, obj_consumable_component ) >= level.cost then

				if sm.container.beginTransaction() then
					sm.container.spend( inventory, obj_consumable_component, level.cost, true )

					if sm.container.endTransaction() then
						fnUpgrade()
					end
				end
			else
				print( "Cannot afford upgrade" )
			end
		end

	end
end

--[[ Client ]]

function Seat.client_onCreate( self )
	self.cl = {}
	self.cl.seatedCharacter = nil
end

function Seat.client_onDestroy( self )
	if self.gui then
		self.gui:destroy()
		self.gui = nil
	end
end

function Seat.client_onUpdate( self, dt )

	-- Update gui upon character change in seat
	local seatedCharacter = self.interactable:getSeatCharacter()
	if self.cl.seatedCharacter ~= seatedCharacter then
		if seatedCharacter and seatedCharacter:getPlayer() and seatedCharacter:getPlayer():getId() == sm.localPlayer.getId() then
			self.gui = sm.gui.createSeatGui()
			self.gui:open()
		else
			if self.gui then
				self.gui:destroy()
				self.gui = nil
			end
		end
		self.cl.seatedCharacter = seatedCharacter
	end

	-- Update gui upon toolbar updates
	if self.gui then

		local interactables = self.interactable:getSeatInteractables()
		for i=1, 10 do
			local value = interactables[i]
			if value and value:getConnectionInputType() == sm.interactable.connectionType.seated then
				self.gui:setGridItem( "ButtonGrid", i-1, {
					["itemId"] = tostring(value:getShape():getShapeUuid()),
					["active"] = value:isActive()
				})
			else
				self.gui:setGridItem( "ButtonGrid", i-1, nil)
			end
		end
	end

end

function Seat.cl_seat( self )
	if sm.localPlayer.getPlayer() and sm.localPlayer.getPlayer():getCharacter() then
		self.interactable:setSeatCharacter( sm.localPlayer.getPlayer():getCharacter() )
	end
end

function Seat.client_canInteract( self, character )
	if character:getCharacterType() == unit_mechanic and not character:isTumbling() then
		return true
	end
	return false
end

function Seat.client_onInteract( self, character, state )
	if state then
		self:cl_seat()
		if self.shape.interactable:getSeatCharacter() ~= nil then
			sm.gui.displayAlertText( "#{ALERT_DRIVERS_SEAT_OCCUPIED}", 4.0 )
		end
	end
end

function Seat.client_canTinker( self, character )
	if not self.shape.usable then
		return false
	end
	local level = self.Levels[tostring( self.shape:getShapeUuid() )]
	if level and level.title then
		return true
	end
	return false
end

function Seat.client_onTinker( self, character, state )
	if state then
		self.upgradeGui = sm.gui.createSeatUpgradeGui()
		self.upgradeGui:open()

		self.upgradeGui:setIconImage( "Icon", self.shape:getShapeUuid() )
		self.upgradeGui:setButtonCallback( "Upgrade", "cl_onUpgradeClicked" )

		local level = self.Levels[ tostring( self.shape:getShapeUuid() ) ]

		if level then
			if level.upgrade then
				self.upgradeGui:setIconImage( "UpgradeIcon", level.upgrade )

				local nextLevel = self.Levels[ tostring( level.upgrade ) ]
				local infoData = { Connections = nextLevel.maxConnections - level.maxConnections }

				if nextLevel.allowAdjustingJoints ~= nil then
					if nextLevel.allowAdjustingJoints == true then
						infoData.Settings = "#{UNLOCKED}"
					end
				end
				self.upgradeGui:setData( "UpgradeInfo", infoData )
			else
				self.upgradeGui:setVisible( "UpgradeIcon", false )
			end

			self.upgradeGui:setText( "SubTitle", level.title )

			if sm.game.getEnableUpgrade() and level.cost then
				local inventory = sm.localPlayer.getPlayer():getInventory()
				local availableKits = sm.container.totalQuantity( inventory, obj_consumable_component )
				local upgradeData = { cost = level.cost, available = availableKits }
				self.upgradeGui:setData( "Upgrade", upgradeData )
				self.upgradeGui:setVisible( "Upgrade", true )
			else
				self.upgradeGui:setVisible( "Upgrade", false )
			end
		end
	end
end

function Seat.cl_onUpgradeClicked( self, buttonName )
	self.network:sendToServer("sv_n_tryUpgrade", sm.localPlayer.getPlayer() )
end

function Seat.cl_n_onUpgrade( self, upgrade )
	local level = self.Levels[tostring( upgrade )]

	if self.upgradeGui and self.upgradeGui:isActive() then
		self.upgradeGui:setIconImage( "Icon", upgrade )

		if sm.game.getEnableUpgrade() and level.cost then
			local inventory = sm.localPlayer.getPlayer():getInventory()
			local availableKits = sm.container.totalQuantity( inventory, obj_consumable_component )
			local upgradeData = { cost = level.cost, available = availableKits }
			self.upgradeGui:setData( "Upgrade", upgradeData )
			self.upgradeGui:setVisible( "Upgrade", true )
		else
			self.upgradeGui:setVisible( "Upgrade", false )
		end

		self.upgradeGui:setText( "SubTitle", level.title )

		if level.upgrade then
			self.upgradeGui:setIconImage( "UpgradeIcon", level.upgrade )

			local nextLevel = self.Levels[ tostring( level.upgrade ) ]
			local infoData = { Connections = nextLevel.maxConnections - level.maxConnections }

			if nextLevel.allowAdjustingJoints ~= nil then
				if nextLevel.allowAdjustingJoints == true then
					infoData.Settings = "#{UNLOCKED}"
				end
			end
			self.upgradeGui:setData( "UpgradeInfo", infoData )
		else
			self.upgradeGui:setVisible( "UpgradeIcon", false )
		end
	end

	sm.effect.playHostedEffect( "Part - Upgrade", self.interactable )
end

function Seat.client_onAction( self, controllerAction, state )
	local consumeAction = true
	if state == true then
		if controllerAction == sm.interactable.actions.use or controllerAction == sm.interactable.actions.jump then
			self:cl_seat()
		elseif controllerAction == sm.interactable.actions.item0 or controllerAction == sm.interactable.actions.create then
			self.interactable:pressSeatInteractable( 0 )
		elseif controllerAction == sm.interactable.actions.item1 or controllerAction == sm.interactable.actions.attack then
			self.interactable:pressSeatInteractable( 1 )
		elseif controllerAction == sm.interactable.actions.create then
			self.interactable:pressSeatInteractable( 1 )
		elseif controllerAction == sm.interactable.actions.item2 then
			self.interactable:pressSeatInteractable( 2 )
		elseif controllerAction == sm.interactable.actions.item3 then
			self.interactable:pressSeatInteractable( 3 )
		elseif controllerAction == sm.interactable.actions.item4 then
			self.interactable:pressSeatInteractable( 4 )
		elseif controllerAction == sm.interactable.actions.item5 then
			self.interactable:pressSeatInteractable( 5 )
		elseif controllerAction == sm.interactable.actions.item6 then
			self.interactable:pressSeatInteractable( 6 )
		elseif controllerAction == sm.interactable.actions.item7 then
			self.interactable:pressSeatInteractable( 7 )
		elseif controllerAction == sm.interactable.actions.item8 then
			self.interactable:pressSeatInteractable( 8 )
		elseif controllerAction == sm.interactable.actions.item9 then
			self.interactable:pressSeatInteractable( 9 )
		else
			consumeAction = false
		end
	else
		if controllerAction == sm.interactable.actions.item0 or controllerAction == sm.interactable.actions.create then
			self.interactable:releaseSeatInteractable( 0 )
		elseif controllerAction == sm.interactable.actions.item1 or controllerAction == sm.interactable.actions.attack then
			self.interactable:releaseSeatInteractable( 1 )
		elseif controllerAction == sm.interactable.actions.item2 then
			self.interactable:releaseSeatInteractable( 2 )
		elseif controllerAction == sm.interactable.actions.item3 then
			self.interactable:releaseSeatInteractable( 3 )
		elseif controllerAction == sm.interactable.actions.item4 then
			self.interactable:releaseSeatInteractable( 4 )
		elseif controllerAction == sm.interactable.actions.item5 then
			self.interactable:releaseSeatInteractable( 5 )
		elseif controllerAction == sm.interactable.actions.item6 then
			self.interactable:releaseSeatInteractable( 6 )
		elseif controllerAction == sm.interactable.actions.item7 then
			self.interactable:releaseSeatInteractable( 7 )
		elseif controllerAction == sm.interactable.actions.item8 then
			self.interactable:releaseSeatInteractable( 8 )
		elseif controllerAction == sm.interactable.actions.item9 then
			self.interactable:releaseSeatInteractable( 9 )
		else
			consumeAction = false
		end
	end
	return consumeAction
end

function Seat.client_getAvailableChildConnectionCount( self, connectionType )
	local level = self.Levels[tostring( self.shape:getShapeUuid() )]
	assert(level)
	local maxButtonCount = level.maxConnections or 255
	return maxButtonCount - #self.interactable:getChildren( sm.interactable.connectionType.seated )
end

Saddle = class( Seat )
Saddle.Levels = {
	[tostring(obj_interactive_saddle_01)] = { maxConnections = 3, upgrade = obj_interactive_saddle_02, cost = 1, title = "#{LEVEL} 1" },
	[tostring(obj_interactive_saddle_02)] = { maxConnections = 4, upgrade = obj_interactive_saddle_03, cost = 1, title = "#{LEVEL} 2" },
	[tostring(obj_interactive_saddle_03)] = { maxConnections = 6, upgrade = obj_interactive_saddle_04, cost = 1, title = "#{LEVEL} 3" },
	[tostring(obj_interactive_saddle_04)] = { maxConnections = 8, upgrade = obj_interactive_saddle_05, cost = 1, title = "#{LEVEL} 4" },
	[tostring(obj_interactive_saddle_05)] = { maxConnections = 10, title = "#{LEVEL} 5" },
}
