QuestManager = class( nil )
QuestManager.isSaveObject = true

QuestEvent = {
	QuestActivated = "event.generic.quest_activated", -- data.params: { questName = ? }
	QuestCompleted = "event.generic.quest_completed", -- data.params: { questName = ? }
	QuestAbandoned = "event.generic.quest_abandoned", -- data.params: { questName = ? }
	InventoryChanges = "event.generic.inventory_changes", -- data.params: { container = ?, changes = { { uuid = ?, difference = ? [, instance = ?] } }, ... }
	InteractableCreated = "event.generic.interactable_created", -- data.params: { interactable = ? }
	InteractableDestroyed = "event.generic.interactable_destroyed", -- data.params: { interactable = ? }
	WaypointLoaded = "event.generic.waypoint_loaded", -- { data.params: waypoint = ?, world = ? }
	AreaTriggerEnter = "event.generic.areaTrigger_enter", -- { data.params: name = ?, results = { ? } }
	AreaTriggerExit = "event.generic.areaTrigger_exit", -- { data.params: name = ?, results = { ? } }
	PlayerJoined = "event.generic.player_joined", -- data.params: { questName = ? }
	PlayerLeft = "event.generic.player_left", -- data.params: { questName = ? }
}

local function LoadQuestSet( path, questTable )
	if sm.json.fileExists( path ) then
		local questSet = sm.json.open( path )
		if questSet and questSet.scriptableObjectList then
			for _, questEntries in pairs( questSet.scriptableObjectList ) do
				if questEntries.name and questEntries.uuid then
					questTable[questEntries.name] = sm.uuid.new( questEntries.uuid )
				end
			end
		end
	else
		sm.log.error("Failed to load quest set " .. path .. " file did not exist.")
	end
end

function QuestManager.server_onCreate( self )
	assert( g_questManager == nil )

	g_questManager = self
	self.sv = {}
	self.sv.saved = self.storage:load()
	if not self.sv.saved then
		self.sv.saved = {}
		self.sv.saved.activeQuests = {}
		self.sv.saved.completedQuests = {}
		self.storage:save( self.sv.saved )
	else
		self.network:setClientData( self.sv.saved )
	end
	self.sv.eventSubs = {}
	self.sv.quests = {}

	LoadQuestSet( "$CONTENT_DATA/ScriptableObjects/scriptableObjectSets/sob_quests.sobset", self.sv.quests )



end

function QuestManager.server_onDestroy( self )
	g_questManager = nil
	if self.sv.activeQuests then
		for _, quest in pairs( self.sv.activeQuests ) do
			quest:destroy()
			quest = nil
		end
	end
end

function QuestManager.client_onCreate( self )
	if not sm.isHost then
		g_questManager = self
	end
	self.cl = {}
	self.cl.completedQuests = {}
	self.cl.activeQuests = {}

	self.cl.trackerHud = sm.gui.createGuiFromLayout( "$GAME_DATA/Gui/Layouts/Quest/Quest_Tracker.layout", true, { isHud = true, isInteractive = false, needsCursor = false } )
	self.cl.trackerHud:open()

	self.cl.questTrackerDirty = true
end

function QuestManager.client_onDestroy( self )
	g_questManager = nil
	self.cl.trackerHud:close()
	self.cl.trackerHud:destroy()
	self.cl.trackerHud = nil
end

function QuestManager.Sv_ActivateQuest( questName )
	print( "QuestManager - ActivateQuest:", questName )
	sm.event.sendToScriptableObject( g_questManager.scriptableObject, "sv_e_activateQuest", questName )
end

function QuestManager.Sv_TryActivateQuest( questName )
	if not QuestManager.Sv_IsQuestActive( questName ) and not QuestManager.Sv_IsQuestComplete( questName ) then
		QuestManager.Sv_ActivateQuest( questName )
	end
end

function QuestManager.Sv_AbandonQuest( questName )
	print( "QuestManager - AbandonQuest:", questName )
	sm.event.sendToScriptableObject( g_questManager.scriptableObject, "sv_e_abandonQuest", questName )
end

function QuestManager.Sv_TryAbandonQuest( questName )
	if QuestManager.Sv_IsQuestActive( questName ) then
		QuestManager.Sv_AbandonQuest( questName )
	end
end

function QuestManager.Sv_CompleteQuest( questName )
	print( "QuestManager - CompleteQuest:", questName )
	sm.event.sendToScriptableObject( g_questManager.scriptableObject, "sv_e_completeQuest", questName )
end

function QuestManager.Sv_IsQuestActive( questName )
	return g_questManager:sv_isQuestActive( questName )
end

function QuestManager.Sv_IsQuestComplete( questName )
	return g_questManager:sv_isQuestComplete( questName )
end

function QuestManager.Sv_GetQuest( questName )
	return g_questManager:sv_getQuest( questName )
end

function QuestManager.Sv_SubscribeEvent( event, subscriber, methodName )
	g_questManager:sv_subscribeEvent( event, subscriber, methodName )
end

function QuestManager.Sv_UnsubscribeEvent( event, subscriber )
	g_questManager:sv_unsubscribeEvent( event, subscriber )
end

function QuestManager.Sv_UnsubscribeAllEvents( subscriber )
	g_questManager:sv_unsubscribeAllEvents( subscriber )
end

function QuestManager.Sv_OnEvent( event, params )
	if g_questManager then
		g_questManager:sv_onEvent( event, params )
	end
end

function QuestManager.Cl_IsQuestActive( questName )
	return g_questManager:cl_isQuestActive( questName )
end

function QuestManager.Cl_IsQuestComplete( questName )
	return g_questManager:cl_isQuestComplete( questName )
end

function QuestManager.Cl_GetQuest( questName )
	return g_questManager:cl_getQuest( questName )
end

function QuestManager.Cl_UpdateQuestTracker()
	g_questManager.cl.questTrackerDirty = true
end

function QuestManager.sv_e_activateQuest( self, questName )
	local questUuid = self.sv.quests[questName]
	if questUuid ~= nil then
		self.sv.saved.activeQuests[questName] = sm.scriptableObject.createScriptableObject( questUuid )
		self.storage:save( self.sv.saved )
		self.network:setClientData( self.sv.saved )
		self:sv_onEvent( QuestEvent.QuestActivated, { questName = questName } )
	else
		sm.log.error( questName .. " did not exist!" )
	end
end

function QuestManager.sv_e_abandonQuest( self, questName )
	local quest = self.sv.saved.activeQuests[questName]
	if quest then
		QuestManager.Sv_UnsubscribeAllEvents( quest )
		self.sv.saved.activeQuests[questName]:destroy()
		self.sv.saved.activeQuests[questName] = nil
		self.storage:save( self.sv.saved )
		self.network:setClientData( self.sv.saved )
		self:sv_onEvent( QuestEvent.QuestAbandoned, { questName = questName } )
	end
end

function QuestManager.sv_e_completeQuest( self, questName )
	local completedQuest = self.sv.saved.activeQuests[questName]
	if completedQuest then
		self.network:sendToClients( "cl_n_questCompleted", questName )
		self.sv.saved.completedQuests[questName] = true
		self.sv.saved.activeQuests[questName]:destroy()
		self.sv.saved.activeQuests[questName] = nil
		self.storage:save( self.sv.saved )
		self.network:setClientData( self.sv.saved )
		self:sv_onEvent( QuestEvent.QuestCompleted, { questName = questName } )
	end
end

function QuestManager.sv_onEvent( self, event, params )
	--print( "QuestManager - Event:", event, "params:", params )
	--print( "Subscribers:", self.sv.eventSubs[event] )
	if self.sv.eventSubs[event] ~= nil then
		for _, subCallback in ipairs( self.sv.eventSubs[event] ) do
			local sub = subCallback[1]
			local callbackName = subCallback[2]
			local data = { event = event, params = params }

			if not sm.exists( sub ) then
				sm.log.warning( "Tried to send callback to subscriber which does not exist: " .. tostring( sub ) )
				return
			end
			local t = type( sub )
			if t == "Harvestable" then
				sm.event.sendToHarvestable( sub, callbackName, data )
			elseif t == "ScriptableObject" then
				sm.event.sendToScriptableObject( sub, callbackName, data )
			elseif t == "Character" then
				sm.event.sendToCharacter( sub, callbackName, data )
			elseif t == "Tool" then
				sm.event.sendToTool( sub, callbackName, data )
			else
				sm.log.error( "Tried to send event to non-supported type in QuestCallbackHelper" )
			end
		end
	end
end

function QuestManager.sv_subscribeEvent( self, event, subscriber, callbackName )
	if self.sv.eventSubs[event] == nil then
		self.sv.eventSubs[event] = { { subscriber, callbackName } }
	else
		for _, subscriberCallback in ipairs( self.sv.eventSubs[event] ) do
			local sub = subscriberCallback[1]
			if sub == subscriber then
				print( "QuestManager - Already subscribed to event:", event, subscriber )
				return
			end
		end
		local numSubs = #self.sv.eventSubs[event]
		self.sv.eventSubs[event][numSubs + 1] = { subscriber, callbackName }
	end
end

function QuestManager.sv_unsubscribeEvent( self, event, subscriber )
	if self.sv.eventSubs[event] ~= nil then
		removeFromArray( self.sv.eventSubs[event], function( subscriberCallback )
			local sub = subscriberCallback[1]
			--if sub == subscriber then
			--	print( "QuestManager - Unsubscribed from event:", event, subscriber )
			--end
			return sub == subscriber
		end )
	end
end

function QuestManager.sv_unsubscribeAllEvents( self, subscriber )
	for event, _ in pairs( self.sv.eventSubs ) do
		self:sv_unsubscribeEvent( event, subscriber )
	end
end

function QuestManager.sv_isQuestActive( self, questName )
	return self.sv.saved.activeQuests[questName] ~= nil
end

function QuestManager.sv_isQuestComplete( self, questName )
	return self.sv.saved.completedQuests[questName] ~= nil
end

function QuestManager.sv_getQuest( self, questName )
	return self.sv.saved.activeQuests[questName]
end

function QuestManager.cl_updateQuestTracker( self )
	if not self.cl.trackerHud then
		return
	end
	local questTrackerText = ""
	for questName, object in pairs( self.cl.activeQuests ) do
		if sm.exists( object ) then
			if object.clientPublicData and object.clientPublicData.progressString then
				questTrackerText = questTrackerText..object.clientPublicData.progressString
			else
				questTrackerText = questTrackerText..questName.." is missing objectives"
			end
		end

		questTrackerText = questTrackerText.."\n\n"
	end
	self.cl.trackerHud:setText( "QuestTrackerTextBox", questTrackerText )
	self.cl.questTrackerDirty = false
end

function QuestManager.client_onUpdate( self, dt )
	if self.cl.questTrackerDirty then
		self:cl_updateQuestTracker()
	end
end

function QuestManager.client_onRefresh( self )
end

function QuestManager.client_onClientDataUpdate( self, data )
	self.cl.activeQuests = data.activeQuests
	self.cl.completedQuests = data.completedQuests
	self.cl.questTrackerDirty = true
end

function QuestManager.cl_isQuestActive( self, questName )
	return self.cl.activeQuests[questName] ~= nil
end

function QuestManager.cl_isQuestComplete( self, questName )
	return self.cl.completedQuests[questName] ~= nil
end

function QuestManager.cl_getQuest( self, questName )
	return self.cl.activeQuests[questName]
end

function QuestManager.cl_n_questCompleted( self, questName )
	sm.gui.displayAlertText( "Quest completed!" )
end
