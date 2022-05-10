dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")

-- Client only
EffectManager = class( nil )

function EffectManager.cl_onCreate( self )
	self.worldCellEffects = {}
	self.worldNamedEffects = {}

	self.namedEffectStates = {}
	self.namedCinematicStates = {}
	self.currentCinematicEffect = nil

	self.worldEffectNodes = {}
	self.worldEffectsNextIds = {}
	self.worldSphereGroups = {}

end

function EffectManager.createEffect( self, world, effectNode )
	local effect = sm.effect.createEffect( effectNode.node.params.effect.name )

	effect:setWorld( world )
	
	effect:setPosition( effectNode.node.position )
	effect:setRotation( effectNode.node.rotation )
	effect:setScale( effectNode.node.scale )
	if effectNode.node.params.effect.params  then
		for k,v in kvpairs( effectNode.node.params.effect.params ) do
			effect:setParameter(k, v)
		end
	end

	if effectNode.timeOfDay then
		effect:setTimeOfDay( true, effectNode.timeOfDay[1], effectNode.timeOfDay[2], effectNode.timeOfDay[3] )
	end

	if effectNode.autoPlay then
		effect:setAutoPlay( true )
	end

	effectNode.effect = effect
	if effectNode.node.name then
		self.worldNamedEffects[world.id][effectNode.name].effect = effect
	end
end

function EffectManager.cl_onWorldCellLoaded( self, worldSelf, x, y )
	--print("--- placing effects on cell " .. x .. ":" .. y .. " world "  .. worldSelf.world.id .. " ---")

	local nodes = sm.cell.getNodesByTags( x, y, { "EFFECT", "~FIRE" } )
	if #nodes > 0 then
		local worldId = worldSelf.world.id
			
		if( self.worldSphereGroups[worldId] == nil ) then
			self.worldSphereGroups[worldId] = sm.cullSphereGroup.newCullSphereGroup()
		end

		self.worldCellEffects[worldId] = self.worldCellEffects[worldId] or {}
		self.worldCellEffects[worldId][CellKey( x, y )] = {}
		local effects = self.worldCellEffects[worldId][CellKey( x, y )]
		for _,node in ipairs( nodes ) do
			if node.params and node.params.effect then

				local effectNode = {
					effect = nil,
					node = node,
					timeOfDay = node.params.effect.timeOfDay,
					autoPlay = node.params.effect.autoPlay == nil or node.params.effect.autoPlay == true,
					name = node.params.name,
				}

				effects[#effects + 1] = effectNode
				
				-- EffectNode with name are always created and not culled
				if effectNode.name then
					self.worldNamedEffects[worldId] = self.worldNamedEffects[worldId] or {}
					if self.worldNamedEffects[worldId][effectNode.name] == nil then
						self:createEffect( worldSelf.world, effectNode )
						self.worldNamedEffects[worldId][effectNode.name] = { effect = effectNode.effect, position = node.position }
					else
						sm.log.warning("Duplicate Named Effect found " .. effectNode.name )
					end
				else
					if self.worldEffectNodes[worldId] == nil  then
						self.worldEffectNodes[worldId] = {}
					end
					
					if self.worldEffectsNextIds[worldId] then
						effectNode.id = self.worldEffectsNextIds[worldId]
						self.worldEffectsNextIds[worldId] = self.worldEffectsNextIds[worldId] + 1
						self.worldEffectNodes[worldId][effectNode.id] = effectNode
					else
						effectNode.id = 1
						self.worldEffectsNextIds[worldId] = 2
						self.worldEffectNodes[worldId][effectNode.id] = effectNode
					end

					local tableParams = {}
					if effectNode.node.params.effect.params  then
						for k,v in kvpairs( effectNode.node.params.effect.params ) do
							tableParams[k]=v
						end
					end
					local effectCullSize = sm.effect.estimateSize( node.params.effect.name, tableParams )

					self.worldSphereGroups[worldId]:addSphere( effectNode.id, node.position, effectCullSize )
				end
			end
		end
	end
end

function EffectManager.cl_onWorldCellUnloaded( self, worldSelf, x, y )
	--print("--- removing effects on cell " .. x .. ":" .. y .. " ---")

	local worldId = worldSelf.world.id
	local effects = self.worldCellEffects[worldId] and self.worldCellEffects[worldId][CellKey( x, y )] or nil
	if effects then
		for _, effectNode in ipairs( effects ) do

			if effectNode.name then
				self.worldNamedEffects[worldId][effectNode.name] = nil
			else
				self.worldSphereGroups[worldId]:removeSphere( effectNode.id )
				self.worldEffectNodes[worldId][effectNode.id] = nil
			end

			if effectNode.effect then
				effectNode.effect:destroy()
				effectNode.effect = nil
			end
		end
		self.worldCellEffects[worldId][CellKey( x, y )] = nil
	end
end

function EffectManager.cl_onWorldUpdate( self, worldSelf )
	--print(worldSelf.world)
	self:cl_handleNamedWorldEffects( worldSelf )
	local worldId = worldSelf.world.id

	if self.worldSphereGroups[worldId] == nil  then
		self.worldSphereGroups[worldId] = sm.cullSphereGroup.newCullSphereGroup()
	end

	local rangeMult = sm.render.isOutdoor() and 0.1 or 0.3
	local cullInRange = sm.render.getDrawDistance() * rangeMult
	local cullOutRange = sm.render.getDrawDistance() * rangeMult + 0.5
	
	local character = sm.localPlayer.getPlayer():getCharacter()

	if sm.exists( character ) and character:getWorld() == worldSelf.world then

		local pos = character:getWorldPosition()
		local remove, add = self.worldSphereGroups[worldId]:getDelta( pos, cullInRange, cullOutRange )
		for _, value in ipairs( remove ) do
			if self.worldEffectNodes[worldId][value].effect then
				self.worldEffectNodes[worldId][value].effect:destroy()
				self.worldEffectNodes[worldId][value].effect = nil
			end
		end
		for _, value in ipairs( add ) do
			self:createEffect( worldSelf.world, self.worldEffectNodes[worldId][value] )
		end
	else
		local remove = self.worldSphereGroups[worldId]:leave()
		for _, value in ipairs( remove ) do
			if self.worldEffectNodes[worldId][value].effect then
				self.worldEffectNodes[worldId][value].effect:destroy()
				self.worldEffectNodes[worldId][value].effect = nil
			else
				sm.log.warning("Destroy effect without effect")
			end
		end
	end	
end

function EffectManager.cl_getWorldNamedEffect( self, worldSelf, name )
	local namedEffects = self.worldNamedEffects[worldSelf.world.id]
	if namedEffects then
		return namedEffects[name]
	end
	return nil
end

local EffectState = {
	PLAY = 1,
	STOP = 2,
	RESTART = 3,
}

local CinematicState = {
	START = 1,
	PLAYING = 2,
	CANCEL = 3,
}

function EffectManager.cl_startNamedEffect( self, name )
	local state = self.namedEffectStates[name]
	if state == nil then
		self.namedEffectStates[name] = EffectState.PLAY
	elseif state == EffectState.STOP then
		self.namedEffectStates[name] = EffectState.RESTART
	end
end

function EffectManager.cl_stopNamedEffect( self, name )
	local state = self.namedEffectStates[name]
	if state and state ~= EffectState.STOP then
		self.namedEffectStates[name] = EffectState.STOP
	end
end

function EffectManager.cl_playNamedCinematic( self, name, callbacks )
	self.namedCinematicStates[name] = { state = CinematicState.START, callbacks = callbacks }
end

function EffectManager.cl_cancelAllCinematics( self )
	for _, cinematic in pairs( self.namedCinematicStates ) do
		cinematic.state = CinematicState.CANCEL
	end
end

local function StartNamedEffect( effect, name )
	if effect and not effect:isPlaying() then
		effect:start()
		print( "EffectManager - Started named effect:", name )
	end
end

local function StopNamedEffect( effect, name )
	if effect and effect:isPlaying() then
		effect:stop()
		print( "EffectManager - Stopped named effect:", name )
	end
end

-- Called from every active world
function EffectManager.cl_handleNamedWorldEffects( self, worldSelf )
	for name, state in pairs( self.namedEffectStates ) do
		local ne = self:cl_getWorldNamedEffect( worldSelf, name )
		if ne and ne.effect then -- Exists in this world
			if state == EffectState.PLAY then
				StartNamedEffect( ne.effect, name )
			elseif state == EffectState.STOP then
				StopNamedEffect( ne.effect, name )
				self.namedEffectStates[name] = nil
			elseif state == EffectState.RESTART then
				StopNamedEffect( ne.effect, name )
				StartNamedEffect( ne.effect, name )
				self.namedEffectStates[name] = EffectState.PLAY
			end
		end
	end

	local activeCameraEffects = {}

	for name, cinematic in pairs( self.namedCinematicStates ) do
		local ne = self:cl_getWorldNamedEffect( worldSelf, name )
		if ne and ne.effect then -- Exists in this world
			if cinematic.state == CinematicState.START and sm.localPlayer.getPlayer().character then
				if cinematic.callbacks then
					for _, cb in ipairs( cinematic.callbacks ) do
						ne.effect:bindEventCallback( cb.fn, cb.params, cb.ref )
					end
				end
				StartNamedEffect( ne.effect, name )
				cinematic.state = CinematicState.PLAYING
			end

			if cinematic.state == CinematicState.PLAYING then
				if ne.effect:isDone() then
					ne.effect:clearEventCallbacks()
					self.namedCinematicStates[name] = nil
				else
					local myCharacter = sm.localPlayer.getPlayer().character
					if myCharacter and ne.effect:hasActiveCamera() and sm.world.getCurrentWorld() == myCharacter:getWorld() then
						activeCameraEffects[#activeCameraEffects + 1] = { effect = ne.effect, distance = ( myCharacter.worldPosition - ne.position ):length() }
					end
				end
			elseif cinematic.state == CinematicState.CANCEL then
				StopNamedEffect( ne.effect, name )
				ne.effect:clearEventCallbacks()
				self.namedCinematicStates[name] = nil
			end
		end
	end

	local closestCameraEffect
	local closestCameraEffectDistance = math.huge

	for _, cameraEffect in ipairs( activeCameraEffects ) do
		if cameraEffect.distance < closestCameraEffectDistance then
			closestCameraEffect = cameraEffect.effect
			closestCameraEffectDistance = cameraEffect.distance
		end
	end

	local cutsceneCameraData
	if closestCameraEffect then
		cutsceneCameraData = {}
		cutsceneCameraData.hideGui = true
		cutsceneCameraData.cameraState = sm.camera.state.cutsceneTP
		cutsceneCameraData.cameraPosition = closestCameraEffect:getCameraPosition()
		cutsceneCameraData.cameraRotation = closestCameraEffect:getCameraRotation()
		cutsceneCameraData.cameraFov = closestCameraEffect:getCameraFov()
		cutsceneCameraData.lockedControls = true
	end
	local player = sm.localPlayer.getPlayer()
	player.clientPublicData.cutsceneCameraData = cutsceneCameraData

	self.currentCinematicEffect = closestCameraEffect
end
