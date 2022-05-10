dofile( "$SURVIVAL_DATA/Scripts/game/managers/QuestManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/quest_util.lua" )

TutorialQuest = class()
TutorialQuest.isSaveObject = true

local Stages = {
	go_crashsite = 1,
	find_bucket = 2,
	fill_bucket = 3,
	return_to_ship = 4,
	putout_fire = 5,
	find_ruin = 6,
	find_battery = 7,
	activate_ship = 8,
	pickup_intel = 9,
}

local FireNames = { "quest_tutorial.fire01", "quest_tutorial.fire02", "quest_tutorial.fire03" }

function TutorialQuest.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.stage = Stages.find_bucket
		self.sv.saved.stageData = {}
		self.sv.saved.stageData.dousedFires = {}
		self.sv.saved.completedStages = {}
	end

	QuestManager.Sv_SubscribeEvent( QuestEvent.InventoryChanges, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( "event.quest_tutorial.fire_doused", self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( "event.quest_tutorial.power_restored", self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( "event.quest_tutorial.intel_aquired", self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.AreaTriggerEnter, self.scriptableObject, "sv_e_onQuestEvent" )
	QuestManager.Sv_SubscribeEvent( QuestEvent.AreaTriggerExit, self.scriptableObject, "sv_e_onQuestEvent" )

	sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_onQuestEvent", {} )
	self:sv_saveAndSync()
end

function TutorialQuest.sv_saveAndSync( self )
	self.storage:save( self.sv.saved )
	self.network:setClientData( { stage = self.sv.saved.stage, stageData = self.sv.saved.stageData } )
end

function TutorialQuest.sv_getDousedFires( self )
	local dousedFires = {}
	for _, name in ipairs( FireNames ) do
		if g_dousedNamedFires[name] then
			dousedFires[#dousedFires + 1] = name
		end
	end
	return dousedFires
end

function TutorialQuest.sv_e_onQuestEvent( self, data )
	--[[ Event ]]
	if data.event == QuestEvent.InventoryChanges then
		-- Find bucket
		if FindInventoryChange( data.params.changes, obj_tool_bucket_empty ) > 0 then
			self.sv.saved.completedStages[Stages.find_bucket] = true
		end
		-- Fill bucket
		if FindInventoryChange( data.params.changes, obj_tool_bucket_water ) > 0 then
			self.sv.saved.completedStages[Stages.find_bucket] = true
			self.sv.saved.completedStages[Stages.fill_bucket] = true
		end
		-- Find master battery
		if FindInventoryChange( data.params.changes, obj_survivalobject_powercore ) > 0 then
			self.sv.saved.completedStages[Stages.find_battery] = true
		end
	elseif data.event == QuestEvent.AreaTriggerEnter or data.event == QuestEvent.AreaTriggerExit then
		-- Go to ship or ruin
		self.sv.saved.completedStages[Stages.return_to_ship] = QuestEntityManager.Sv_NamedAreaTriggerContainsPlayer( "quest_tutorial.area_ship" )
		self.sv.saved.completedStages[Stages.find_ruin] = QuestEntityManager.Sv_NamedAreaTriggerContainsPlayer( "quest_tutorial.area_ruin" )
	elseif data.event == "event.quest_tutorial.fire_doused" then
		-- Put out fire
		self.sv.saved.stageData.dousedFires = self:sv_getDousedFires()
		self.sv.saved.completedStages[Stages.putout_fire] = #self.sv.saved.stageData.dousedFires == #FireNames
	elseif data.event == "event.quest_tutorial.power_restored" then
		-- Activate ship
		self.sv.saved.completedStages[Stages.activate_ship] = true
	elseif data.event == "event.quest_tutorial.intel_aquired" then
		-- Pickup intel
		self.sv.saved.completedStages[Stages.pickup_intel] = true
		QuestManager.Sv_TryActivateQuest( "quest_mechanicstation" )
	end

	-- Detect player at the crashsite for the first time
	if not self.sv.saved.completedStages[Stages.go_crashsite] then
		self.sv.saved.completedStages[Stages.go_crashsite] = QuestEntityManager.Sv_NamedAreaTriggerContainsPlayer( "quest_tutorial.area_ship" )
	end

	-- Detect already doused fires
	if not self.sv.saved.completedStages[Stages.putout_fire] then
		self.sv.saved.stageData.dousedFires = self:sv_getDousedFires()
		self.sv.saved.completedStages[Stages.putout_fire] = #self.sv.saved.stageData.dousedFires == #FireNames
	end

	-- Detect already active ship
	if not self.sv.saved.completedStages[Stages.activate_ship] then
		local powercoreSockets = QuestEntityManager.Sv_GetInteractablesWithUuid( obj_survivalobject_powercoresocket )
		for _, powercoreSocket in pairs( powercoreSockets ) do
			if sm.exists( powercoreSocket ) and powercoreSocket.active and powercoreSocket.publicData and powercoreSocket.publicData.area == "ship" then
				self.sv.saved.completedStages[Stages.activate_ship] = true
			end
		end
	end

	--[[ Quest progress ]]
	-- Determine quest stage
	if not self.sv.saved.completedStages[Stages.go_crashsite] then
		self.sv.saved.stage = Stages.go_crashsite
	elseif not self.sv.saved.completedStages[Stages.activate_ship] then
		if not self.sv.saved.completedStages[Stages.putout_fire] then
			if not self.sv.saved.completedStages[Stages.find_bucket] then
				self.sv.saved.stage = Stages.find_bucket
			elseif not self.sv.saved.completedStages[Stages.fill_bucket] then
				self.sv.saved.stage = Stages.fill_bucket
			elseif not self.sv.saved.completedStages[Stages.return_to_ship] then
				self.sv.saved.stage = Stages.return_to_ship
			else
				self.sv.saved.stage = Stages.putout_fire
			end
		elseif not self.sv.saved.completedStages[Stages.find_battery] then
			if not self.sv.saved.completedStages[Stages.find_ruin] then
				self.sv.saved.stage = Stages.find_ruin
			else
				self.sv.saved.stage = Stages.find_battery
			end
		else
			self.sv.saved.stage = Stages.activate_ship
		end
	elseif not self.sv.saved.completedStages[Stages.pickup_intel] then
		self.sv.saved.stage = Stages.pickup_intel
	end

	-- Complete quest
	if self.sv.saved.completedStages[Stages.pickup_intel] then
		self.sv.saved.stage = nil
		QuestManager.Sv_UnsubscribeAllEvents( self.scriptableObject )
		QuestManager.Sv_CompleteQuest( "quest_tutorial" )
	end

	self:sv_saveAndSync()
end


function TutorialQuest.client_onCreate( self )
	self.cl = {}
	self.scriptableObject.clientPublicData = {}
	self.scriptableObject.clientPublicData.progressString = ""
end

function TutorialQuest.client_onRefresh( self )
end

function TutorialQuest.client_onClientDataUpdate( self, data )
	if data.stage ~= self.cl.stage then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_water", false )
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_bucket", false )
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_spaceship", false )
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_fire01", false )
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_fire02", false )
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_fire03", false )
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_ruin", false )
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_battery", false )
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_socket", false )
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_intel", false )
	end
	self.cl.stage = data.stage

	if data.stage == Stages.find_bucket then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_bucket", true )
	elseif data.stage == Stages.fill_bucket then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_water", true )
	elseif data.stage == Stages.return_to_ship then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_spaceship", true )
	elseif data.stage == Stages.putout_fire then
		if isAnyOf( "quest_tutorial.fire01", data.stageData.dousedFires ) then
			QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_fire01", false )
		else
			QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_fire01", true )
		end
		if isAnyOf( "quest_tutorial.fire02", data.stageData.dousedFires ) then
			QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_fire02", false )
		else
			QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_fire02", true )
		end
		if isAnyOf( "quest_tutorial.fire03", data.stageData.dousedFires ) then
			QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_fire03", false )
		else
			QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_fire03", true )
		end
	elseif data.stage == Stages.find_ruin then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_ruin", true )

	elseif data.stage == Stages.find_battery then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_battery", true )

	elseif data.stage == Stages.activate_ship then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_socket", true )

	elseif data.stage == Stages.pickup_intel then
		QuestEntityManager.Cl_SetNamedQuestMarkerVisible( "quest_tutorial.marker_intel", true )
	end

	self:cl_updateProgress( data.stage, data.stageData )
end

function TutorialQuest.cl_updateProgress( self, stage, stageData )
	if stage == Stages.go_crashsite then
		self.scriptableObject.clientPublicData.progressString = "#{Q_TUTORIAL_GO_CRASHSITE}"
	elseif stage == Stages.find_bucket then
		self.scriptableObject.clientPublicData.progressString = "#{Q_TUTORIAL_FIND_BUCKET}"
	elseif stage == Stages.fill_bucket then
		self.scriptableObject.clientPublicData.progressString = "#{Q_TUTORIAL_FILL_BUCKET}"
	elseif isAnyOf( stage, { Stages.return_to_ship, Stages.putout_fire } ) then
		self.scriptableObject.clientPublicData.progressString = "#{Q_TUTORIAL_PUTOUT_FIRE}"..#stageData.dousedFires.."/"..#FireNames
	elseif isAnyOf( stage, { Stages.find_ruin, Stages.find_battery } ) then
		self.scriptableObject.clientPublicData.progressString = "#{Q_TUTORIAL_FIND_BATTERY}"
	elseif stage == Stages.activate_ship then
		self.scriptableObject.clientPublicData.progressString = "#{Q_TUTORIAL_ACTIVATE_SHIP}"
	elseif stage == Stages.pickup_intel then
		self.scriptableObject.clientPublicData.progressString = "#{Q_TUTORIAL_DOWNLOAD_INTEL}"
	else
		self.scriptableObject.clientPublicData.progressString = ""
	end
	QuestManager.Cl_UpdateQuestTracker()
end
