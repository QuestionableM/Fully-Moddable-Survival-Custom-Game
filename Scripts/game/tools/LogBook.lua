dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/game/managers/BeaconManager.lua"
dofile "$SURVIVAL_DATA/Scripts/game/managers/QuestManager.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_logs.lua"

local renderables =   {"$SURVIVAL_DATA/Character/Char_Tools/Char_logbook/char_logbook.rend" }
local renderablesTp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_logbook.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_logbook/char_logbook_tp_animlist.rend"}
local renderablesFp = {"$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_logbook.rend", "$SURVIVAL_DATA/Character/Char_Tools/Char_logbook/char_logbook_fp_animlist.rend"}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

local LogBookVersion = 1

LogBook = class()

function LogBook.sv_getSaved( self )
	return self.storage:load() or { version = LogBookVersion, mapActiveBeacons = {}, mapReadLogs = {} }
end

function LogBook.server_onCreate( self )
	QuestManager.Sv_SubscribeEvent( QuestEvent.QuestCompleted, self.tool, "sv_e_onQuestCompleted" )
end

function LogBook:sv_e_onQuestCompleted( data )
	if data.params.questName == "quest_tutorial" then
		self.network:sendToClient( self.tool:getOwner(), "cl_n_addLog", log_mechanicstation )
	end
end

function LogBook.sv_n_requestInitData( self, _, player )
	local clientData = self:sv_getSaved()
	-- Load locations for waypoints
	clientData.locations = sm.storage.load( STORAGE_CHANNEL_LOCATIONS )

	clientData.logs = {}
	clientData.logs[#clientData.logs + 1] = log_crashedship
	if QuestManager.Sv_IsQuestComplete( "quest_tutorial" ) then
		clientData.logs[#clientData.logs + 1] = log_mechanicstation
	end

	self.network:sendToClient( player, "cl_n_initData", clientData )
end

function LogBook.sv_n_activeBeacon( self, beacon )
	local saved = self:sv_getSaved()
	saved.mapActiveBeacons[beacon.id] = beacon.active
	self.storage:save( saved )
end

function LogBook.sv_n_readLog( self, uuid )
	local saved = self:sv_getSaved()
	saved.mapReadLogs[uuid] = true
	self.storage:save( saved )
end

--------------------------------------------------------------------------------

function LogBook.client_onCreate( self )
	self.cl = {}

	if self.tool:isLocal() then
		self.cl.gui = sm.gui.createLogbookGui()
		self.cl.gui:setOnCloseCallback( "cl_onGuiClosed" )
		self.cl.gui:setGridButtonCallback( "BeaconButtonActive", "cl_onBeaconActiveClicked" )
		self.cl.gui:setGridButtonCallback( "LogItemActivate", "cl_onLogItemClicked" )

		self.cl.mapReadLogs = {}
		self.cl.logs = {}

		self.cl.updateLogGui = false
		self.cl.waypointGui = sm.gui.createWorldIconGui( 66, 66, "$GAME_DATA/Gui/Layouts/Hud/Hud_WorldIcon.layout", false )
		self.cl.notificationSound = sm.effect.createEffect2D( "Gui - LogbookNotification" )
		self.cl.seatedEquiped = false

		self.cl.gui:setButtonCallback( "WaypointButton", "cl_onWaypointClicked" )

		self.network:sendToServer( "sv_n_requestInitData" )
	end

	self:client_onRefresh()
end

function LogBook.client_onRefresh( self )
	self:cl_loadAnimations()
end

function LogBook.cl_n_initData( self, data )
	self.cl.locations = data.locations
	self.cl.mapReadLogs = data.mapReadLogs
	self.cl.logs = data.logs

	for id, active in pairs( data.mapActiveBeacons ) do
		g_beaconManager:cl_setBeaconVisible( id, active )
	end

	local anyUnread = false
	for _, uuid in ipairs( self.cl.logs ) do
		local read = self.cl.mapReadLogs[uuid] or false
		if read == false then
			anyUnread = true
			break
		end
	end
	if g_survivalHud then
		g_survivalHud:setVisible( "LogbookNotification", anyUnread )
	end
end

function LogBook.cl_n_addLog( self, uuid )
	if valueExists( self.cl.logs, uuid ) then
		return
	end

	self.cl.logs[#self.cl.logs + 1] = uuid
	self.cl.updateLogGui = true

	if not self.cl.notificationSound:isPlaying() then
		self.cl.notificationSound:start()
	end
	if g_survivalHud then
		g_survivalHud:setVisible( "LogbookNotification", true )
	end
end

function LogBook.client_onUpdate( self, dt )

	if self.cl.seatedEquiped or self.cl.equipped and self.tool:isLocal() then
		self:cl_updateBeaconGui()
		self:cl_updateLogGui()
	end

	-- First person animation
	local isCrouching = self.tool:isCrouching()

	if self.tool:isLocal() then
		updateFpAnimations( self.fpAnimations, self.cl.equipped, dt )
	end

	if not self.cl.equipped then
		if self.cl.wantsEquip then
			self.cl.wantsEquip = false
			self.cl.equipped = true
		end
		return
	end

	local crouchWeight = isCrouching and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight
	local totalWeight = 0.0

	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )

			if animation.looping == true then
				if animation.time >= animation.info.duration then
					animation.time = animation.time - animation.info.duration
				end
			end
			if animation.time >= animation.info.duration - self.cl.blendTime and not animation.looping then
				if ( name == "putdown" ) then
					self.cl.equipped = false
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.tpAnimations, animation.nextAnimation, 0.001 )
				end
			end
		else
			animation.weight = math.max( animation.weight - ( self.tpAnimations.blendSpeed * dt ), 0.0 )
		end

		totalWeight = totalWeight + animation.weight
	end

	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs( self.tpAnimations.animations ) do

		local weight = animation.weight / totalWeight
		if name == "idle" then
			self.tool:updateMovementAnimation( animation.time, weight )
		elseif animation.crouch then
			self.tool:updateAnimation( animation.info.name, animation.time, weight * normalWeight )
			self.tool:updateAnimation( animation.crouch.name, animation.time, weight * crouchWeight )
		else
			self.tool:updateAnimation( animation.info.name, animation.time, weight )
		end
	end

end

function LogBook.client_canEquip( _ )
	return true --QuestManager.Cl_IsQuestComplete( quest_pickup_logbook )
end

function LogBook.client_onEquip( self )
	self.cl.wantsEquip = true
	self.cl.seatedEquiped = false

	local currentRenderablesTp = {}
	concat(currentRenderablesTp, renderablesTp)
	concat(currentRenderablesTp, renderables)

	local currentRenderablesFp = {}
	concat(currentRenderablesFp, renderablesFp)
	concat(currentRenderablesFp, renderables)

	self.tool:setTpRenderables( currentRenderablesTp )

	if self.tool:isLocal() then
		self.tool:setFpRenderables( currentRenderablesFp )

		self:cl_updateBeaconGui()
		self:cl_updateLogGui( true )
		self.cl.gui:open()
	end

	self:cl_loadAnimations()
	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )

	if self.tool:isLocal() then
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end

end

function LogBook.client_equipWhileSeated( self )
	if not self.cl.seatedEquiped then
		self:cl_updateBeaconGui()
		self:cl_updateLogGui( true )
		self.cl.gui:open()
		self.cl.seatedEquiped = true
	end
end

function LogBook.client_onUnequip( self )
	self.cl.wantsEquip = false
	self.cl.seatedEquiped = false
	if sm.exists( self.tool ) then
		setTpAnimation( self.tpAnimations, "useExit" )
		if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" and self.fpAnimations.currentAnimation ~= "useExit" then
			swapFpAnimation( self.fpAnimations, "equip", "useExit", 0.2 )
		end
	end
end

function LogBook.cl_loadAnimations( self )
	-- TP
	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			idle = { "logbook_use_idle", { looping = true } },
			sprint = { "logbook_sprint" },
			pickup = { "logbook_pickup", { nextAnimation = "useInto" } },
			putdown = { "logbook_putdown" },
			useInto = { "logbook_use_into", { nextAnimation = "idle" } },
			useExit = { "logbook_use_exit", { nextAnimation = "putdown" } }
		}
	)

	local movementAnimations = {
		idle = "logbook_use_idle",
		idleRelaxed = "logbook_idle_relaxed",

		runFwd = "logbook_run_fwd",
		runBwd = "logbook_run_bwd",
		sprint = "logbook_sprint",

		jump = "logbook_jump",
		jumpUp = "logbook_jump_up",
		jumpDown = "logbook_jump_down",

		land = "logbook_jump_land",
		landFwd = "logbook_jump_land_fwd",
		landBwd = "logbook_jump_land_bwd",

		crouchIdle = "logbook_crouch_idle",
		crouchFwd = "logbook_crouch_fwd",
		crouchBwd = "logbook_crouch_bwd"
	}

	for name, animation in pairs( movementAnimations ) do
		self.tool:setMovementAnimation( name, animation )
	end

	if self.tool:isLocal() then
		-- FP
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				idle = { "logbook_use_idle", { looping = true } },
				equip = { "logbook_pickup", { nextAnimation = "useInto" } },
				unequip = { "logbook_putdown" },
				useInto = { "logbook_use_into", { nextAnimation = "idle" } },
				useExit = { "logbook_use_exit", { nextAnimation = "unequip" } }
			}
		)
	end

	setTpAnimation( self.tpAnimations, "idle", 5.0 )
	self.cl.blendTime = 0.2

end

function LogBook.cl_updateBeaconGui( self )
	local player = self.tool:getOwner()
	assert(player)
	local character = player:getCharacter()
	if not character then
		return
	end
	local characterPos = character:getWorldPosition()
	local beacons = g_beaconManager:cl_getBeacons()

	local uiData = {}
	for _, beacon in pairs( beacons ) do
		local beaconPosition = beacon.position
		if sm.exists( beacon.shape ) then
			beaconPosition = beacon.shape.worldPosition
		end
		local distance = math.floor( ( characterPos - beaconPosition ):length() )
		local settings = g_beaconManager:cl_getBeaconSettings( beacon.shape:getId() )

		table.insert( uiData, { id = beacon.shape:getId(), iconIndex = beacon.iconData.iconIndex,
			iconColor = BEACON_COLORS[beacon.iconData.colorIndex]:getHexStr(), distance = distance, active = settings.visible } )
	end

	table.sort( uiData, function(a, b)
		return a.distance < b.distance
	end)

	self.cl.gui:setData( "Beacons", uiData )
end

function LogBook.cl_updateLogGui( self, forceUpdate )
	if self.cl.updateLogGui or forceUpdate then

		local anyUnread = false
		local uiData = {}
		for _, uuid in ipairs( self.cl.logs ) do
			local read = self.cl.mapReadLogs[uuid] or false
			if read == false then
				anyUnread = true
			end
			uiData[#uiData + 1] = { uuid = uuid, read = read }
		end

		if g_survivalHud then
			g_survivalHud:setVisible( "LogbookNotification", anyUnread )
		end

		self.cl.gui:setData( "Logs", uiData )
		self.cl.updateLogGui = false
	end
end

function LogBook.cl_onBeaconActiveClicked( self, _, _, beacon )
	g_beaconManager:cl_setBeaconVisible( beacon.id, not beacon.active )

	self.network:sendToServer( "sv_n_activeBeacon", { id = beacon.id, active = not beacon.active } )
end

function LogBook.cl_setWaypoint( self, position, world, icon )
	self.cl.waypointGui:setWorldPosition( position, world )
	self.cl.waypointGui:setItemIcon( "Icon", "WaypointIconMap", "WaypointIconMap", icon or "mechanicstation" )
	self.cl.waypointGui:setRequireLineOfSight( false )
	self.cl.waypointGui:setMaxRenderDistance( 10000 )
	self.cl.waypointGui:open()
	self.cl.icon = icon
end

function LogBook.cl_hideWaypoint( self )
	self.cl.waypointGui:close()
	self.cl.icon = nil
end

function LogBook.cl_onLogItemClicked( self, _, _, log )
	self.cl.log = log

	if log and log.uuid then
		self.cl.gui:setVisible( "WaypointButtonIcon", self.cl.icon == self.cl.log.icon )
	end

	if log and log.uuid and not self.cl.mapReadLogs[log.uuid] then
		self.cl.mapReadLogs[log.uuid] = true
		self.cl.updateLogGui = true

		self.network:sendToServer( "sv_n_readLog", log.uuid )
	end
end

function LogBook.cl_onWaypointClicked( self, _ )
	if self.cl.log and self.cl.log.location then

		if self.cl.icon == self.cl.log.icon then
			self:cl_hideWaypoint()
			self.cl.gui:setVisible( "WaypointButtonIcon", false )
		else
			local location
			if self.cl.locations then
				location = self.cl.locations[self.cl.log.location]
			end

			if location then
				self:cl_setWaypoint( location.pos, location.world, self.cl.log.icon )
				self.cl.gui:setVisible( "WaypointButtonIcon", true )
			end
		end
	end
end

function LogBook.cl_onGuiClosed( self )
	sm.tool.forceTool( nil )
	self.cl.seatedEquiped = false
end