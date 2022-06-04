dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/quest_util.lua" )

MechanicStationQuest = class()
MechanicStationQuest.isSaveObject = true

local Stages = {
	to_station = 1,
	find_battery = 2,
	activate_station = 3
}

function MechanicStationQuest.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.stage = Stages.to_station
		self.sv.saved.completedStages = {}
	end

	QuestManager.Sv_SubscribeEvent( QuestEvent.InventoryChanges, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.AreaTriggerEnter, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( "event.quest_mechanicstation.power_restored", self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.InteractableCreated, self.scriptableObject, "sv_e_onQuestEvent" )

	sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_onQuestEvent", {} )
	self:sv_saveAndSync()
end

function MechanicStationQuest.sv_saveAndSync( self )
	self.storage:save( self.sv.saved )
	self.network:setClientData( { stage = self.sv.saved.stage } )
end

function MechanicStationQuest.sv_e_onQuestEvent( self, data )
	--[[ Event ]]
	if data.event == QuestEvent.InventoryChanges then
		-- Find master battery
		if FindInventoryChange( data.params.changes, obj_survivalobject_powercore ) > 0 then
			self.sv.saved.completedStages[Stages.find_battery] = true
		end
	elseif data.event == "event.quest_mechanicstation.power_restored" then
		-- Activate mechanic station
		self.sv.saved.completedStages[Stages.activate_station] = true
	end

	-- Detect player at the mechanic station for the first time
	if not self.sv.saved.completedStages[Stages.to_station] then
		if QuestEntityManager.Sv_NamedAreaTriggerContainsPlayer( "quest_mechanicstation.area_mechanicstation" ) then
			self.sv.saved.completedStages[Stages.to_station] = true
			QuestManager.Sv_TryAbandonQuest( "quest_builder_guide" )
		end
	end

	-- Detect already active mechanic station
	if not self.sv.saved.completedStages[Stages.activate_station] then
		local powercoreSockets = QuestEntityManager.Sv_GetInteractablesWithUuid( obj_survivalobject_powercoresocket )
		for _, powercoreSocket in pairs( powercoreSockets ) do
			if sm.exists( powercoreSocket ) and powercoreSocket.active and powercoreSocket.publicData and powercoreSocket.publicData.area == "mechanicstation" then
				self.sv.saved.completedStages[Stages.activate_station] = true
			end
		end
	end

	--[[ Quest progress ]]
	-- Determine quest stage
	if not self.sv.saved.completedStages[Stages.to_station] then
		self.sv.saved.stage = Stages.to_station
	elseif not self.sv.saved.completedStages[Stages.find_battery] and not self.sv.saved.completedStages[Stages.activate_station] then
		self.sv.saved.stage = Stages.find_battery
	elseif not self.sv.saved.completedStages[Stages.activate_station] then
		self.sv.saved.stage = Stages.activate_station
	end

	-- Complete quest
	if self.sv.saved.completedStages[Stages.to_station] and
		self.sv.saved.completedStages[Stages.activate_station] then
		self.sv.saved.stage = nil
		QuestManager.Sv_UnsubscribeAllEvents( self.scriptableObject )
		QuestManager.Sv_CompleteQuest( "quest_mechanicstation" )
	end

	self:sv_saveAndSync()
end


function MechanicStationQuest.client_onCreate( self )
	self.cl = {}
	self.scriptableObject.clientPublicData = {}
	self.scriptableObject.clientPublicData.progressString = ""
	self.scriptableObject.clientPublicData.isMainQuest = true
	self.scriptableObject.clientPublicData.title = "#{Q_MECHANICSTATION_TITLE}"
end

function MechanicStationQuest.client_onRefresh( self )
end

function MechanicStationQuest.client_onClientDataUpdate( self, data )
	if data.stage ~= self.cl.stage then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_mechanicstation.marker_battery", false )
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_mechanicstation.marker_socket", false )
	end

	self.cl.stage = data.stage

	if data.stage == Stages.find_battery then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_mechanicstation.marker_battery", true )

	elseif data.stage == Stages.activate_station then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_mechanicstation.marker_socket", true )

	end

	self:cl_updateProgress( data.stage )
end

function MechanicStationQuest.cl_updateProgress( self, stage )
	if stage == Stages.to_station then
		self.scriptableObject.clientPublicData.progressString = "#{Q_MECHANICSTATION_GO_STATION}"
	elseif isAnyOf( stage, { Stages.find_battery, Stages.activate_station } ) then
		self.scriptableObject.clientPublicData.progressString = "#{Q_MECHANICSTATION_ACTIVATE_STATION}"
	else
		self.scriptableObject.clientPublicData.progressString = ""
	end
	QuestManager.Cl_UpdateQuestTracker()
end
