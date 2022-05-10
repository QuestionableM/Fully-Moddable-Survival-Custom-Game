dofile("$SURVIVAL_DATA/Scripts/blueprint_util.lua")

BuilderGuide = class( nil )

-- Server

function BuilderGuide.server_onCreate( self )
	self.sv = {}
	self.sv.rebuildTick = sm.game.getCurrentTick()
end

function BuilderGuide.server_onFixedUpdate( self )
	local bodies = sm.body.getCreationBodies( self.shape:getBody() );

	if #bodies ~= self.sv.lastBodyCount or self.shape:getBody():getId() ~= self.sv.lastBodyId then
		self:sv_checkBuilderGuide()
		self.sv.lastBodyCount = #bodies
	else
		for _, body in ipairs( bodies ) do
			if body:hasChanged( self.sv.rebuildTick ) then
				self:sv_checkBuilderGuide()
				self.sv.lastBodyCount = #bodies
				break
			end
		end
	end
end

function BuilderGuide.sv_checkBuilderGuide( self )
	self.sv.lastBodyId = self.shape:getBody():getId()
	if self.shape:getBody():getId() ~= self.sv.lastBodyId and self.sv.builderGuide then
		self.sv.builderGuide:destroy()
		self.sv.builderGuide = nil
	end

	if self.sv.builderGuide == nil then
		local ignoreBlockUuid = self.data.ignoreBlockUuid ~= nil and self.data.ignoreBlockUuid ~= false
		self.sv.builderGuide = sm.builderGuide.createBuilderGuide( self.data.filepath, self.shape, ignoreBlockUuid )
	end

	self.sv.builderGuide:update()
	self.sv.rebuildTick = sm.game.getCurrentTick()

	local data = { isComplete = self.sv.builderGuide:isComplete(), currentStageIndex = self.sv.builderGuide:getCurrentStageIndex() }
	self.network:setClientData( data )

	data.interactable = self.interactable
	QuestManager.Sv_OnEvent( "event.quest_builder_guide.update", data )
end

-- Client

function BuilderGuide.client_onClientDataUpdate( self, data )
	if data.isComplete then
		if not self.cl.serverWasComplete then
			self.cl.serverWasComplete = true
		end
	else
		local stageCompleted = data.currentStageIndex;
		if self.cl.serverLastStage ~= stageCompleted or self.cl.serverWasComplete then
			self.cl.serverLastStage = stageCompleted
		end

		self.cl.serverWasComplete = false
	end
end

function BuilderGuide.cl_n_updateState( self )

	if self.cl.builderGuideVis then
		self.cl.builderGuideVis:destroy()
		self.cl.builderGuideVis = nil
	end

	self:cl_rebuildVisualization()
end

function BuilderGuide.cl_rebuildVisualization( self )

	if self.shape:getBody():getId() ~= self.cl.lastBodyId and self.cl.builderGuideVis then
		self.cl.builderGuideVis:destroy()
		self.cl.builderGuideVis = nil
	end

	if self.cl.builderGuideVis then
		self.cl.builderGuideVis:updateBuilderGuide();
	else
		self.cl.lastBodyId = self.shape:getBody():getId()
		local ignoreBlockUuid = self.data.ignoreBlockUuid ~= nil and self.data.ignoreBlockUuid ~= false
		self.cl.builderGuideVis = sm.visualization.createBuilderGuide( self.data.filepath, self.shape, ignoreBlockUuid, "Builderguide - Stagecomplete" );
	end

	self.cl.rebuildTick = sm.game.getCurrentTick()
end

function BuilderGuide.client_onCreate( self )
	self.cl = {}
	self.cl.serverWasComplete = false
	self.cl.serverLastStage = 0
	self.cl.rebuildTick = sm.game.getCurrentTick()
	self:cl_rebuildVisualization();

	self.cl.backgroundEffect = sm.effect.createEffect( "Builderguide - Background", self.interactable )
end

function BuilderGuide.client_onRefresh( self )
	self:cl_rebuildVisualization();
end

function BuilderGuide.client_onDestroy( self )
	if self.cl.builderGuideVis then
		self.cl.builderGuideVis:destroy()
		self.cl.builderGuideVis = nil
	end
	self.cl.backgroundEffect:destroy()
end

function BuilderGuide.client_onFixedUpdate( self )
	if self.shape.body:isOnLift() then
		local bodies = sm.body.getCreationBodies( self.shape:getBody() );

		if #bodies ~= self.cl.lastBodyCount or self.shape:getBody():getId() ~= self.cl.lastBodyId then
			self:cl_rebuildVisualization()
			self.cl.lastBodyCount = #bodies
		else
			for _, body in ipairs( bodies ) do
				if body:hasChanged( self.cl.rebuildTick ) then
						self:cl_rebuildVisualization()
						self.cl.lastBodyCount = #bodies
					break
				end
			end
		end

		if self.cl.serverWasComplete then
			if self.cl.backgroundEffect:isPlaying() then
				sm.effect.playHostedEffect( "Builderguide - Buildcomplete", self.interactable )
				self.cl.backgroundEffect:stop()
			end
		else
			if not self.cl.backgroundEffect:isPlaying() then
				sm.effect.playHostedEffect( "Builderguide - Active", self.interactable )
				self.cl.backgroundEffect:start()
			end
		end
	else
		if self.cl.backgroundEffect:isPlaying() then
			sm.effect.playHostedEffect( "Builderguide - Deactivate", self.interactable )
			self.cl.backgroundEffect:stop()
		end
		if self.cl.builderGuideVis then
			self.cl.builderGuideVis:destroy()
			self.cl.builderGuideVis = nil
		end
	end
end