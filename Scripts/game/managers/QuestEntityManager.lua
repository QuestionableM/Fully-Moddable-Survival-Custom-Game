dofile("$CONTENT_DATA/Scripts/game/survival_constants.lua")

QuestEntityManager = class( nil )

local QuestInteractables =
{
	obj_survivalobject_powercoresocket
}

--[[ Server ]]
function QuestEntityManager.server_onCreate( self )
	g_questEntityManager = self
	self.sv = {}
	self.sv.worldCellAreaTriggers = {}
	self.sv.namedAreaTriggers = {}
	self.sv.namedAreaTriggersById = {}
	self.sv.bindRequests = {}

	self.sv.worldCellWaypoints = {}
	self.sv.namedWaypoints = {}

	self.sv.interactablesByUuid = {}
	self.sv.interactablesById = {}
end

--[[ Manager ]]
function QuestEntityManager.Sv_OnWorldCellLoaded( worldSelf, x, y )
	if g_questEntityManager then
		g_questEntityManager:sv_onWorldCellLoaded( worldSelf, x, y )
	end
end

function QuestEntityManager.sv_onWorldCellLoaded( self, worldSelf, x, y )
	local worldId = worldSelf.world.id
	local cellKey = CellKey( x, y )

	-- AreaTrigger
	local areaTriggerNodes = sm.cell.getNodesByTag( x, y, "AREATRIGGER" )
	self.sv.worldCellAreaTriggers[worldId] = self.sv.worldCellAreaTriggers[worldId] or {}
	self.sv.worldCellAreaTriggers[worldId][cellKey] = {}
	local areaTriggers = self.sv.worldCellAreaTriggers[worldId][cellKey]
	for _, node in ipairs( areaTriggerNodes ) do
		if node.params.name then
			-- Create the areatrigger
			local areaTrigger = sm.areaTrigger.createBox( node.scale * 0.5, node.position, node.rotation )
			self.sv.bindRequests[#self.sv.bindRequests+1] = areaTrigger
			local areaTriggerData = {
				areaTrigger = areaTrigger,
				name = node.params.name
			}
			areaTriggers[#areaTriggers+1] = areaTriggerData
			self.sv.namedAreaTriggers[areaTriggerData.name] = areaTriggerData
			self.sv.namedAreaTriggersById[areaTrigger.id] = areaTriggerData
		end
	end
	if #self.sv.bindRequests > 0 then
		sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_bindCallbacks" )
	end

	-- Waypoint
	local waypointNodes = sm.cell.getNodesByTag( x, y, "WAYPOINT" )
	self.sv.worldCellWaypoints[worldId] = self.sv.worldCellWaypoints[worldId] or {}
	self.sv.worldCellWaypoints[worldId][cellKey] = {}
	local waypoints = self.sv.worldCellWaypoints[worldId][cellKey]
	for _, node in ipairs( waypointNodes ) do
		if node.params.name then
			local waypointData = {
				position = node.position,
				rotation = node.rotation,
				name = node.params.name,
				world = worldSelf.world
			}
			waypoints[#waypoints+1] = waypointData
			self.sv.namedWaypoints[waypointData.name] = waypointData
			QuestManager.Sv_OnEvent( QuestEvent.WaypointLoaded, { name = node.params.name } )
		end
	end
end

function QuestEntityManager.sv_e_bindCallbacks( self )
	-- Bind triggers within the manager
	for _, areaTrigger in ipairs( self.sv.bindRequests ) do
		if sm.exists( areaTrigger ) then
			areaTrigger:bindOnEnter( "trigger_onEnter" )
			areaTrigger:bindOnExit( "trigger_onExit" )
		end
	end
	self.sv.bindRequests = {}
end

function QuestEntityManager.Sv_OnWorldCellUnloaded( worldSelf, x, y )
	if g_questEntityManager then
		g_questEntityManager:sv_onWorldCellUnloaded( worldSelf, x, y )
	end
end

function QuestEntityManager.sv_onWorldCellUnloaded( self, worldSelf, x, y )
	local worldId = worldSelf.world.id
	local cellKey = CellKey( x, y )

	-- AreaTrigger
	local areaTriggers = self.sv.worldCellAreaTriggers[worldId] and self.sv.worldCellAreaTriggers[worldId][cellKey] or nil
	if areaTriggers then
		for _, areaTriggerData in ipairs( areaTriggers ) do
			self.sv.namedAreaTriggers[areaTriggerData.name] = nil
			self.sv.namedAreaTriggersById[areaTriggerData.areaTrigger.id] = nil
			if sm.exists( areaTriggerData.areaTrigger ) then
				sm.areaTrigger.destroy( areaTriggerData.areaTrigger )
			end
		end
		self.sv.worldCellAreaTriggers[worldId][cellKey] = nil
	end

	-- Waypoint
	local waypoints = self.sv.worldCellWaypoints[worldId] and self.sv.worldCellWaypoints[worldId][cellKey] or nil
	if waypoints then
		for _, waypointData in ipairs( waypoints ) do
			self.sv.namedAreaTriggers[waypointData.name] = nil
		end
		self.sv.worldCellWaypoints[worldId][cellKey] = nil
	end
end

--[[ Areatrigger ]]
function QuestEntityManager.Sv_GetNamedAreaTrigger( name )
	if g_questEntityManager then
		return g_questEntityManager:sv_getNamedAreaTrigger( name )
	end
	return nil
end

function QuestEntityManager.sv_getNamedAreaTrigger( self, name )
	return self.sv.namedAreaTriggers[name]
end

function QuestEntityManager.Sv_NamedAreaTriggerContainsPlayer( name )
	if g_questEntityManager then
		return g_questEntityManager:sv_namedAreaTriggerContainsPlayer( name )
	end
	return false
end

function QuestEntityManager.sv_namedAreaTriggerContainsPlayer( self, name )
	local triggerData = self.sv.namedAreaTriggers[name]
	if triggerData then
		local contents = triggerData.areaTrigger:getContents()
		for _, content in ipairs( contents ) do
			if type( content ) == "Character" then
				if content:isPlayer() then
					return true
				end
			end
		end
	end
	return false
end

function QuestEntityManager.trigger_onEnter( self, trigger, results )
	local areaTriggerNode = self.sv.namedAreaTriggersById[trigger.id]
	if areaTriggerNode then
		QuestManager.Sv_OnEvent( QuestEvent.AreaTriggerEnter, { name = areaTriggerNode.name, results = results } )
	end
end

function QuestEntityManager.trigger_onExit( self, trigger, results )
	local areaTriggerNode = self.sv.namedAreaTriggersById[trigger.id]
	if areaTriggerNode then
		QuestManager.Sv_OnEvent( QuestEvent.AreaTriggerExit, { name = areaTriggerNode.name, results = results } )
	end
end

--[[ Waypoint ]]
function QuestEntityManager.Sv_GetNamedWaypoint( name )
	if g_questEntityManager then
		return g_questEntityManager:sv_getNamedWaypoint( name )
	end
	return nil
end

function QuestEntityManager.sv_getNamedWaypoint( self, name )
	return self.sv.namedWaypoints[name]
end

--[[ Interactable ]]
function QuestEntityManager.Sv_OnInteractableCreated( interactable )
	QuestManager.Sv_OnEvent( QuestEvent.InteractableCreated, { interactable = interactable } )
	if g_questEntityManager then
		g_questEntityManager:sv_onInteractableCreated( interactable )
	end
end

function QuestEntityManager.sv_onInteractableCreated( self, interactable )
	if interactable.shape then
		if isAnyOf( interactable.shape.uuid, QuestInteractables ) then
			local stringUuid = tostring( interactable.shape.uuid )
			self.sv.interactablesByUuid[stringUuid] = self.sv.interactablesByUuid[stringUuid] or {}
			self.sv.interactablesByUuid[stringUuid][interactable.id] = interactable
			self.sv.interactablesById[interactable.id] = { uuid = interactable.shape.uuid, interactable = interactable }
		end
	end
end

function QuestEntityManager.Sv_OnInteractableDestroyed( interactable )
	QuestManager.Sv_OnEvent( QuestEvent.InteractableDestroyed, { interactable = interactable } )
	if g_questEntityManager then
		g_questEntityManager:sv_onInteractableDestroyed( interactable )
	end
end

function QuestEntityManager.sv_onInteractableDestroyed( self, interactable )
	local interactableData = self.sv.interactablesById[interactable.id]
	if interactableData then
		local stringUuid = tostring( interactableData.uuid )
		if self.sv.interactablesByUuid[stringUuid] then
			self.sv.interactablesByUuid[stringUuid][interactable.id] = nil
		end
	end
	self.sv.interactablesById[interactable.id] = nil
end

function QuestEntityManager.Sv_GetInteractablesWithUuid( uuid )
	if g_questEntityManager then
		return g_questEntityManager:sv_getInteractablesWithUuid( uuid )
	end
	return {}
end

function QuestEntityManager.sv_getInteractablesWithUuid( self, uuid )
	return self.sv.interactablesByUuid[tostring( uuid )] or {}
end



--[[ Client ]]
function QuestEntityManager.client_onCreate( self )
	g_questEntityManagerClient = self
	self.cl = {}
	self.cl.worldCellQuestMarkers = {}
	self.cl.namedQuestMarkers = {}
	self.cl.activeQuestMarkers = {}
end

--[[ Manager ]]
function QuestEntityManager.Cl_OnWorldCellLoaded( worldSelf, x, y )
	if g_questEntityManagerClient then
		g_questEntityManagerClient:cl_onWorldCellLoaded( worldSelf, x, y )
	end
end

function QuestEntityManager.cl_onWorldCellLoaded( self, worldSelf, x, y )
	local worldId = worldSelf.world.id
	local cellKey = CellKey( x, y )

	-- QuestMarker
	local questMarkerNodes = sm.cell.getNodesByTag( x, y, "QUESTMARKER" )
	self.cl.worldCellQuestMarkers[worldId] = self.cl.worldCellQuestMarkers[worldId] or {}
	self.cl.worldCellQuestMarkers[worldId][cellKey] = {}
	local questMarkers = self.cl.worldCellQuestMarkers[worldId][cellKey]
	for _, node in ipairs( questMarkerNodes ) do
		if node.params.name then
			local questMarkerGui = sm.gui.createWorldIconGui( 60, 60, "$GAME_DATA/Gui/Layouts/Hud/Hud_WorldIcon.layout", false )
			questMarkerGui:setImage( "Icon", "icon_questmarker.png" )
			questMarkerGui:setWorldPosition( node.position )
			questMarkerGui:setRequireLineOfSight( false )
			questMarkerGui:setMaxRenderDistance( 10000 )
			if self.cl.activeQuestMarkers[node.params.name] then
				questMarkerGui:open()
			end
			local questMarkerData = {
				position = node.position,
				name = node.params.name,
				world = worldSelf.world,
				questMarkerGui = questMarkerGui
			}
			questMarkers[#questMarkers+1] = questMarkerData
			self.cl.namedQuestMarkers[questMarkerData.name] = questMarkerData
		end
	end
end

function QuestEntityManager.Cl_OnWorldCellUnloaded( worldSelf, x, y )
	if g_questEntityManagerClient then
		g_questEntityManagerClient:cl_onWorldCellUnloaded( worldSelf, x, y )
	end
end

function QuestEntityManager.cl_onWorldCellUnloaded( self, worldSelf, x, y )
	local worldId = worldSelf.world.id
	local cellKey = CellKey( x, y )

	-- QuestMarker
	local questMarkers = self.cl.worldCellQuestMarkers[worldId] and self.cl.worldCellQuestMarkers[worldId][cellKey] or nil
	if questMarkers then
		for _, questMarkerData in ipairs( questMarkers ) do
			local questMarkerData = self.cl.namedQuestMarkers[questMarkerData.name]
			if questMarkerData and questMarkerData.questMarkerGui then
				questMarkerData.questMarkerGui:destroy()
			end
			self.cl.namedQuestMarkers[questMarkerData.name] = nil
		end
		self.cl.worldCellQuestMarkers[worldId][cellKey] = nil
	end
end

--[[ QuestMarker ]]
function QuestEntityManager.Cl_GetNamedQuestMarker( name )
	if g_questEntityManagerClient then
		return g_questEntityManagerClient:cl_getNamedQuestMarker( name )
	end
	return nil
end

function QuestEntityManager.cl_getNamedQuestMarker( self, name )
	return self.cl.namedQuestMarkers[name]
end

function QuestEntityManager.Cl_SetNamedQuestMarkerVisible( name, state )
	if g_questEntityManagerClient then
		g_questEntityManagerClient:cl_setNamedQuestMarkerVisible( name, state )
	end
end

function QuestEntityManager.cl_setNamedQuestMarkerVisible( self, name, state )
	if state == true then
		self.cl.activeQuestMarkers[name] = state
	else
		self.cl.activeQuestMarkers[name] = nil
	end

	local questMarkerData = QuestEntityManager.Cl_GetNamedQuestMarker( name )
	if questMarkerData and questMarkerData.questMarkerGui then
		if not questMarkerData.questMarkerGui:isActive() and self.cl.activeQuestMarkers[name] then
			questMarkerData.questMarkerGui:open()
		elseif questMarkerData.questMarkerGui:isActive() and not self.cl.activeQuestMarkers[name] then
			questMarkerData.questMarkerGui:close()
		end
	end
end