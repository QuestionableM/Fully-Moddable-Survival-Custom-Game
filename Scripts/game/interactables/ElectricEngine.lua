-- ElectricEngine.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_items.lua")

ElectricEngine = class()
ElectricEngine.maxParentCount = 2
ElectricEngine.maxChildCount = 255
ElectricEngine.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power + sm.interactable.connectionType.electricity
ElectricEngine.connectionOutput = sm.interactable.connectionType.bearing
ElectricEngine.colorNormal = sm.color.new( 0xff8000ff )
ElectricEngine.colorHighlight = sm.color.new( 0xff9f3aff )
ElectricEngine.poseWeightCount = 1

local PoweringUpFactor = 0.75

local Gears = {
	{ power = 1000, velocity = math.rad( 0 ) },
	{ power = 1000, velocity = math.rad( 30 ) },
	{ power = 1000, velocity = math.rad( 60 ) },
	{ power = 1000, velocity = math.rad( 90 ) },
	{ power = 1000, velocity = math.rad( 150 ) }, -- 1
	{ power = 1000, velocity = math.rad( 240 ) },
	{ power = 1000, velocity = math.rad( 390 ) }, -- 2
	{ power = 1000, velocity = math.rad( 630 ) },
	{ power = 1000, velocity = math.rad( 1020 ) }, -- 3
	{ power = 1000, velocity = math.rad( 1650 ) },
	{ power = 1000, velocity = math.rad( 2670 ) }, -- 4
	{ power = 1000, velocity = math.rad( 4320 ) },
	{ power = 1000, velocity = math.rad( 6990 ) }, -- 5
}

local EngineLevels = {
	[tostring(obj_interactive_electricengine_01)] = {
		gears = Gears,
		effect = "ElectricEngine - Level 1",
		upgrade = tostring(obj_interactive_electricengine_02),
		cost = 4,
		title = "#{LEVEL} 1",
		gearCount = 5,
		bearingCount = 2,
		pointsPerBattery = 4000
	},
	[tostring(obj_interactive_electricengine_02)] = {
		gears = Gears,
		effect = "ElectricEngine - Level 2",
		upgrade = tostring(obj_interactive_electricengine_03),
		cost = 6,
		title = "#{LEVEL} 2",
		gearCount = 7,
		bearingCount = 4,
		pointsPerBattery = 6000
	},
	[tostring(obj_interactive_electricengine_03)] = {
		gears = Gears,
		effect = "ElectricEngine - Level 3",
		upgrade = tostring(obj_interactive_electricengine_04),
		cost = 8,
		title = "#{LEVEL} 3",
		gearCount = 9,
		bearingCount = 6,
		pointsPerBattery = 9000
	},
	[tostring(obj_interactive_electricengine_04)] = {
		gears = Gears,
		effect = "ElectricEngine - Level 4",
		upgrade = tostring(obj_interactive_electricengine_05),
		cost = 10,
		title = "#{LEVEL} 4",
		gearCount = 11,
		bearingCount = 8,
		pointsPerBattery = 12000
	},
	[tostring(obj_interactive_electricengine_05)] = {
		gears = Gears,
		effect = "ElectricEngine - Level 5",
		title = "#{LEVEL} 5",
		gearCount = #Gears,
		bearingCount = 10,
		pointsPerBattery = 20000
	}
}

--[[ Server ]]

function ElectricEngine.server_onCreate( self )
	local container = self.shape.interactable:getContainer( 0 )
	if not container then
		container = self.shape:getInteractable():addContainer( 0, 1, 10 )
	end
	container:setFilters( { obj_consumable_battery } )

	local level = EngineLevels[tostring( self.shape:getShapeUuid() )]
	assert(level)
	self.level = level
	self:server_init()
end

function ElectricEngine.server_onRefresh( self )
	self:server_init()
end

function ElectricEngine.server_init( self )

	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = {}
	end
	if self.saved.gearIdx == nil then
		self.saved.gearIdx = 1
	end
	if self.saved.batteryPoints == nil then
		self.saved.batteryPoints = 0
	end

	self.power = 0
	self.motorVelocity = 0
	self.motorImpulse = 0
	self.batteryPoints = self.saved.batteryPoints
	self.hasBattery = false
	self.dirtyStorageTable = false
	self.dirtyClientTable = false

	self:sv_setGear( self.saved.gearIdx )
end

function ElectricEngine.sv_setGear( self, gearIdx )
	self.saved.gearIdx = gearIdx
	self.dirtyStorageTable = true
	self.dirtyClientTable = true
end

function ElectricEngine.sv_updateFuelStatus( self, batteryContainer )

	if self.saved.batteryPoints ~= self.batteryPoints then
		self.saved.batteryPoints = self.batteryPoints
		self.dirtyStorageTable = true
	end

	local hasBattery = ( self.batteryPoints > 0 ) or sm.container.canSpend( batteryContainer, obj_consumable_battery, 1 )
	if self.hasBattery ~= hasBattery then
		self.hasBattery = hasBattery
		self.dirtyClientTable = true
	end

end

function ElectricEngine.controlEngine( self, direction, active, timeStep, gearIdx )
	direction = clamp( direction, -1, 1 )
	if direction > 0 then
		self.power = self.power + timeStep * PoweringUpFactor
	elseif direction < 0 then
		self.power = self.power - timeStep * PoweringUpFactor
	else
		if sign( self.power ) > 0 then
			self.power = math.max( self.power - timeStep * PoweringUpFactor, 0 )
		else
			self.power = math.min( self.power + timeStep * PoweringUpFactor, 0 )
		end
	end
	self.power = clamp( self.power, -1, 1 )

	self.motorVelocity = self.power * self.level.gears[gearIdx].velocity
	self.motorImpulse = self.level.gears[gearIdx].power * ( active and 1 or 2 )
end

function ElectricEngine.getInputs( self )

	local parents = self.interactable:getParents()
	local active = true
	local direction = 1
	local batteryContainer = nil
	local hasInput = false
	if parents[2] then
		if parents[2]:hasOutputType( sm.interactable.connectionType.logic ) then
			active = parents[2]:isActive()
			direction = active and 1 or 0
			hasInput = true
		end
		if parents[2]:hasOutputType( sm.interactable.connectionType.power ) then
			active = parents[2]:isActive()
			direction = parents[2]:getPower()
			hasInput = true
		end
		if parents[2]:hasOutputType( sm.interactable.connectionType.electricity ) then
			batteryContainer = parents[2]:getContainer( 0 )
		end
	end
	if parents[1] then
		if parents[1]:hasOutputType( sm.interactable.connectionType.logic ) then
			active = parents[1]:isActive()
			direction = active and 1 or 0
			hasInput = true
		end
		if parents[1]:hasOutputType( sm.interactable.connectionType.power ) then
			active = parents[1]:isActive()
			direction = parents[1]:getPower()
			hasInput = true
		end
		if parents[1]:hasOutputType( sm.interactable.connectionType.electricity ) then
			batteryContainer = parents[1]:getContainer( 0 )
		end
	end

	return active, direction, batteryContainer, hasInput

end

function ElectricEngine.server_onFixedUpdate( self, timeStep )

	-- Check engine connections
	local hadInput = self.hasInput == nil and true or self.hasInput --Pretend to have had input if nil to avoid starting engines at load
	local active, direction, batteryContainer, hasInput = self:getInputs()
	self.hasInput = hasInput
	local useCreativeBattery = not sm.game.getEnableFuelConsumption() and batteryContainer == nil

	-- Check fuel container
	if not batteryContainer or batteryContainer:isEmpty() then
		batteryContainer = self.shape.interactable:getContainer( 0 )
	end

	-- Check bearings
	local bearings = {}
	local joints = self.interactable:getJoints()
	for _, joint in ipairs( joints ) do
		if joint:getType() == "bearing" then
			bearings[#bearings+1] = joint
		end
	end

	-- Update motor gear when a steering is added
	if not hadInput and hasInput then
		if self.saved.gearIdx == 1 then
			self:sv_setGear( 2 )
		end
	end

	-- Consume fuel for fuel points
	local canSpend = false
	if self.batteryPoints <= 0 then
		canSpend = sm.container.canSpend( batteryContainer, obj_consumable_battery, 1 )
	end

	-- Control engine
	if self.batteryPoints > 0 or canSpend or useCreativeBattery then

		if hasInput == false then
			self:controlEngine( 1, true, timeStep, self.saved.gearIdx )
		else
			self:controlEngine( direction, active, timeStep, self.saved.gearIdx )
		end

		if not useCreativeBattery then
			-- Consume fuel points
			local appliedImpulseCost = 0.015625
			local batteryCost = 0
			for _, bearing in ipairs( bearings ) do
				if bearing.appliedImpulse * bearing.angularVelocity < 0 then -- No added fuel cost if the bearing is decelerating
					batteryCost = batteryCost + math.abs( bearing.appliedImpulse ) * appliedImpulseCost
				end
			end
			batteryCost = math.min( batteryCost, math.sqrt( batteryCost / 7.5 ) * 7.5 )

			self.batteryPoints = self.batteryPoints - batteryCost

			if self.batteryPoints <= 0 and batteryCost > 0 then
				sm.container.beginTransaction()
				sm.container.spend( batteryContainer, obj_consumable_battery, 1, true )
				if sm.container.endTransaction() then
					self.batteryPoints = self.batteryPoints + self.level.pointsPerBattery
				end
			end
		end

	else
		self:controlEngine( 0, false, timeStep, self.saved.gearIdx )
	end

	-- Update rotational joints
	for _, bearing in ipairs( bearings ) do
		bearing:setMotorVelocity( self.motorVelocity, self.motorImpulse )
	end

	self:sv_updateFuelStatus( batteryContainer )

	-- Storage table dirty
	if self.dirtyStorageTable then
		self.storage:save( self.saved )
		self.dirtyStorageTable = false
	end

	-- Client table dirty
	if self.dirtyClientTable then
		self.network:setClientData( { gearIdx = self.saved.gearIdx, engineHasFuel = self.hasBattery or useCreativeBattery } )
		self.dirtyClientTable = false
	end
end

--[[ Client ]]

function ElectricEngine.client_onCreate( self )
	local level = EngineLevels[tostring( self.shape:getShapeUuid() )]
	self.level = level
	self.client_gearIdx = 1
	self.effect = sm.effect.createEffect( level.effect, self.interactable )
	self.engineHasFuel = false
	self.power = 0
	self.bearingImpulses = {}
end

function ElectricEngine.client_onClientDataUpdate( self, params )

	if self.gui then
		if self.gui:isActive() and params.gearIdx ~= self.client_gearIdx then
			self.gui:setSliderPosition("Setting", params.gearIdx - 1 )
		end
	end

	self.client_gearIdx = params.gearIdx
	self.interactable:setPoseWeight( 0, params.gearIdx / #self.level.gears )

	if self.engineHasFuel and not params.engineHasFuel then
		local character = sm.localPlayer.getPlayer().character
		if character then
			if ( self.shape.worldPosition - character.worldPosition ):length2() < 100 then
				sm.gui.displayAlertText( "#{INFO_OUT_OF_ENERGY}" )
			end
		end
	end

	self.engineHasFuel = params.engineHasFuel
end

function ElectricEngine.client_onDestroy( self )
	self.effect:destroy()

	if self.gui then
		self.gui:close()
		self.gui:destroy()
		self.gui = nil
	end
end

function ElectricEngine.client_onFixedUpdate( self, timeStep )

	local active, direction, externalFuelTank, hasInput = self:getInputs()

	if self.gui then
		self.gui:setVisible( "FuelContainer", externalFuelTank ~= nil )
	end

	if sm.isHost then
		return
	end

	-- Check bearings
	local bearings = {}
	local joints = self.interactable:getJoints()
	for _, joint in ipairs( joints ) do
		if joint:getType() == "bearing" then
			bearings[#bearings+1] = joint
		end
	end

	-- Control engine
	if self.engineHasFuel then
		if hasInput == false then
			self:controlEngine( 1, true, timeStep, self.client_gearIdx )
		else
			self:controlEngine( direction, active, timeStep, self.client_gearIdx )
		end
	else
		self:controlEngine( 0, false, timeStep, self.client_gearIdx )
	end

	-- Update rotational joints
	for _, bearing in ipairs( bearings ) do
		bearing:setMotorVelocity( self.motorVelocity, self.motorImpulse )
	end
end

function ElectricEngine.client_onUpdate( self, dt )

	local active, direction = self:getInputs()

	self:cl_updateEffect( direction, active )
end

function ElectricEngine.client_onInteract( self, character, state )
	if state == true then
		self.gui = sm.gui.createEngineGui()

		self.gui:setText( "Name", "#{CONTROLLER_ENGINE_ELECTRIC_TITLE}" )
		self.gui:setText( "Interaction", "#{CONTROLLER_ENGINE_INSTRUCTION}" )
		self.gui:setOnCloseCallback( "cl_onGuiClosed" )
		self.gui:setSliderCallback( "Setting", "cl_onSliderChange" )
		self.gui:setSliderData( "Setting", #self.level.gears, self.client_gearIdx - 1 )
		self.gui:setIconImage( "Icon", self.shape:getShapeUuid() )
		self.gui:setButtonCallback( "Upgrade", "cl_onUpgradeClicked" )

		local batteryContainer = self.shape.interactable:getContainer( 0 )

		if batteryContainer then
			self.gui:setContainer( "Fuel", batteryContainer )
		end

		local _, _, externaFuelContainer, _ = self:getInputs()
		if externaFuelContainer then
			self.gui:setVisible( "FuelContainer", true )
		end

		if not sm.game.getEnableFuelConsumption() then
			self.gui:setVisible( "BackgroundBattery", false )
			self.gui:setVisible( "FuelGrid", false )
		end

		self.gui:open()

		if self.level then
			if self.level.upgrade then
				local nextLevel = EngineLevels[ self.level.upgrade ]
				self.gui:setData( "UpgradeInfo", { Gears = nextLevel.gearCount - self.level.gearCount, Bearings = nextLevel.bearingCount - self.level.bearingCount, Efficiency = 1 } )
				self.gui:setIconImage( "UpgradeIcon", sm.uuid.new( self.level.upgrade ) )
			else
				self.gui:setVisible( "UpgradeIcon", false )
				self.gui:setData( "UpgradeInfo", nil )
			end

			self.gui:setText( "SubTitle", self.level.title )
			self.gui:setSliderRangeLimit( "Setting", self.level.gearCount )

			if sm.game.getEnableUpgrade() and self.level.cost then
				local inventory = sm.localPlayer.getPlayer():getInventory()
				local availableKits = sm.container.totalQuantity( inventory, obj_consumable_component )
				local upgradeData = { cost = self.level.cost, available = availableKits }
				self.gui:setData( "Upgrade", upgradeData )
			else
				self.gui:setVisible( "Upgrade", false )
			end
		end

	end
end

function ElectricEngine.client_getAvailableParentConnectionCount( self, connectionType )
	if bit.band( connectionType, bit.bor( sm.interactable.connectionType.logic, sm.interactable.connectionType.power ) ) ~= 0 then
		return 1 - #self.interactable:getParents( bit.bor( sm.interactable.connectionType.logic, sm.interactable.connectionType.power ) )
	end
	if bit.band( connectionType, sm.interactable.connectionType.electricity ) ~= 0 then
		return 1 - #self.interactable:getParents( sm.interactable.connectionType.electricity )
	end
	return 0
end

function ElectricEngine.client_getAvailableChildConnectionCount( self, connectionType )
	if connectionType ~= sm.interactable.connectionType.bearing then
		return 0
	end
	local maxBearingCount = self.level.bearingCount or 255
	return maxBearingCount - #self.interactable:getChildren( sm.interactable.connectionType.bearing )
end

function ElectricEngine.cl_onGuiClosed( self )
	self.gui:destroy()
	self.gui = nil
end

function ElectricEngine.cl_onSliderChange( self, sliderName, sliderPos )
	self.network:sendToServer( "sv_setGear", sliderPos + 1 )
	self.client_gearIdx = sliderPos + 1
end

function ElectricEngine.cl_onUpgradeClicked( self, buttonName )
	print( "upgrade clicked" )
	self.network:sendToServer("sv_n_tryUpgrade", sm.localPlayer.getPlayer() )
end

function ElectricEngine.cl_updateEffect( self, direction, active )

	local gear = self.level.gears[self.client_gearIdx]

	-- Filter bearings
	local bearings = {}
	local joints = self.interactable:getJoints()
	for _, joint in ipairs( joints ) do
		if joint:getType() == "bearing" then
			bearings[#bearings+1] = joint
		end
	end

	local load = 0.0
	local appliedImpulse = 0.0
	local velocity = 0.0

	if #bearings > 0 then
		for _, currentBearing in ipairs( bearings ) do

			velocity = velocity + ( currentBearing:isReversed() and 1.0 or -1.0 ) * currentBearing:getAngularVelocity() 

			local prevImpulse = self.bearingImpulses[currentBearing:getId()]
			if prevImpulse == nil then				
				self.bearingImpulses[currentBearing:getId()] = 0.0
				prevImpulse = 0.0
			end

			local impulseDiff = math.abs( currentBearing:getAppliedImpulse() ) - prevImpulse
			if impulseDiff > 0  then
				prevImpulse = prevImpulse + math.min( impulseDiff, gear.power / 1.5 )
			else
				prevImpulse = prevImpulse + math.min( impulseDiff, gear.power / 3.0 )
			end

			appliedImpulse = appliedImpulse + prevImpulse
		end

		load = appliedImpulse / #bearings
		velocity = velocity / #bearings
	end

	local onLift = self.shape:getBody():isOnLift()

	if self.effect:isPlaying() == false and #bearings > 0 and not onLift and math.abs( self.motorVelocity ) > 0 then
		self.effect:start()
	elseif self.effect:isPlaying() and ( onLift or #bearings == 0 or self.motorVelocity == 0 ) then
		self.effect:setParameter( "load", 0.5 )
		self.effect:setParameter( "rpm", 0 )
		self.effect:stop()
	end
	
	local maxRPM = (self.client_gearIdx + 1) / #self.level.gears
	local rpm = math.min( ( math.abs( velocity ) / gear.velocity ) * maxRPM, maxRPM )

	if self.effect:isPlaying() then
		self.effect:setParameter( "rpm", rpm )
		self.effect:setParameter( "load", load * 0.5 + 0.5 )
	end

end

function ElectricEngine.sv_n_tryUpgrade( self, _, player )

	if self.level and self.level.upgrade then
		local function fnUpgrade()
			local nextLevel = EngineLevels[self.level.upgrade]
			assert( nextLevel )
		
			self.network:sendToClients( "cl_n_onUpgrade", self.level.upgrade )

			self.shape:replaceShape( sm.uuid.new( self.level.upgrade ) )
			self.level = nextLevel
		end

		if sm.game.getEnableUpgrade() then
			local inventory = player:getInventory()

			if sm.container.totalQuantity( inventory, obj_consumable_component ) >= self.level.cost then

				if sm.container.beginTransaction() then
					sm.container.spend( inventory, obj_consumable_component, self.level.cost, true )

					if sm.container.endTransaction() then
						fnUpgrade()
					end
				end
			else
				print( "Cannot afford upgrade" )
			end
		end
	else
		print( "Can't be upgraded" )
	end

end

function ElectricEngine.cl_n_onUpgrade( self, upgrade )
	local nextLevel = EngineLevels[upgrade]

	if self.gui and self.gui:isActive() then
		self.gui:setIconImage( "Icon", sm.uuid.new( upgrade ) )

		if sm.game.getEnableUpgrade() and nextLevel.cost then
			local inventory = sm.localPlayer.getPlayer():getInventory()
			local availableKits = sm.container.totalQuantity( inventory, obj_consumable_component )
			local upgradeData = { cost = nextLevel.cost, available = availableKits }
			self.gui:setData( "Upgrade", upgradeData )
		else
			self.gui:setVisible( "Upgrade", false )
		end

		self.gui:setText( "SubTitle", nextLevel.title )
		self.gui:setSliderRangeLimit( "Setting", nextLevel.gearCount )
		if self.level.upgrade then
			self.gui:setData( "UpgradeInfo", { Gears = nextLevel.gearCount - self.level.gearCount, Bearings = nextLevel.bearingCount - self.level.bearingCount, Efficiency = 1 } )
			self.gui:setIconImage( "UpgradeIcon", sm.uuid.new( self.level.upgrade ) )
		else
			self.gui:setVisible( "UpgradeIcon", false )
			self.gui:setData( "UpgradeInfo", nil )
		end
	end

	self.effect = sm.effect.createEffect( nextLevel.effect, self.interactable )
	sm.effect.playHostedEffect( "Part - Upgrade", self.interactable )

	self.level = nextLevel
end