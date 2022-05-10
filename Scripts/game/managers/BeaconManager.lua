dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

BEACON_COLORS = {
	sm.color.new( "4F6CFF" ),
	sm.color.new( "AF7DFF" ),
	sm.color.new( "00FFFF" ),
	sm.color.new( "90FF78" ),
	sm.color.new( "FFD046" ),
	sm.color.new( "FFFFC0" ),
	sm.color.new( "FF6619" ),
	sm.color.new( "FF3737" )
}

-- Server side
BeaconManager = class( nil )

local BeaconVersion = 1

function BeaconManager.sv_onCreate( self )
	self.sv = {}

	self.sv.saved = sm.storage.load( STORAGE_CHANNEL_BEACONS )
	if self.sv.saved then
		print( "Loaded beacons with version", self.sv.saved.version, ":" )
		print( self.sv.saved )
	else
		self.sv.saved = { version = BeaconVersion, beacons = {} }
		self:sv_saveBeacons()
	end
end

function BeaconManager.sv_saveBeacons( self )
	sm.storage.save( STORAGE_CHANNEL_BEACONS, self.sv.saved )
end

-- Game environment
function BeaconManager.sv_onSpawnCharacter( self, player )
	for _, beacon in pairs( self.sv.saved.beacons ) do
		if beacon.world == player.character:getWorld() then
			local params = { player = player, beacon = beacon }
			if sm.exists( beacon.shape ) then
				sm.event.sendToGame( "sv_e_createBeacon", params )
			else
				sm.event.sendToGame( "sv_e_unloadBeacon", params )
			end
		end
	end
end

-- Interactable environment
function BeaconManager.sv_createBeacon( self, shape, iconData )
	-- Add beacon data
	local beacon = {}
	beacon.world = shape.body:getWorld()
	beacon.shape = shape
	beacon.position = shape.worldPosition
	beacon.iconData = iconData

	self.sv.saved.beacons[tostring( beacon.shape.id )] = beacon

	self:sv_saveBeacons()

	-- Inform clients
	local params = { beacon = beacon }
	sm.event.sendToGame( "sv_e_createBeacon", params )
end

-- Interactable environment
function BeaconManager.sv_destroyBeacon( self, shape )
	local beacon = self.sv.saved.beacons[tostring( shape.id )]
	if beacon then
		-- Inform clients
		local params = { beacon = beacon }
		sm.event.sendToGame( "sv_e_destroyBeacon", params )
	end
	-- Remove beacon data
	self.sv.saved.beacons[tostring( shape.id )] = nil
	self:sv_saveBeacons()
end

-- Interactable environment
function BeaconManager.sv_unloadBeacon( self, shape )

	local beacon = self.sv.saved.beacons[tostring( shape.id )]
	if beacon then
		-- Update beacon data
		local updatedBeacon = beacon
		updatedBeacon.world = shape.body:getWorld()
		updatedBeacon.position = shape.worldPosition
		self.sv.saved.beacons[tostring( shape.id )] = updatedBeacon
		self:sv_saveBeacons()

		-- Inform clients
		local params = { beacon = updatedBeacon }
		sm.event.sendToGame( "sv_e_unloadBeacon", params )
	end
end

-- Client side

function BeaconManager.cl_onCreate( self )
	self.cl = {}
	self.cl.beacons = {}
	self.cl.beaconSettings = {}
end

-- World environment
function BeaconManager.cl_createBeacon( self, params )
	local settings = self:cl_getBeaconSettings( params.beacon.shape:getId() )
	self:cl_addUpdateBeacon( params.beacon, true, settings )
end

-- World environment
function BeaconManager.cl_destroyBeacon( self, params )
	local guiBeacon = self.cl.beacons[tostring( params.beacon.shape.id )]
	if guiBeacon then
		guiBeacon.gui:close()
		guiBeacon.gui:destroy()
	end
	self.cl.beacons[tostring( params.beacon.shape.id )] = nil
end

-- World environment
function BeaconManager.cl_unloadBeacon( self, params )
	local settings = self:cl_getBeaconSettings( params.beacon.shape:getId() )
	self:cl_addUpdateBeacon( params.beacon, false, settings )
end

-- World environment helper function: cl_createBeacon and cl_unloadBeacon
function BeaconManager.cl_addUpdateBeacon( self, beacon, hosted, settings )
	local guiBeacon = self.cl.beacons[tostring( beacon.shape.id )]
	if guiBeacon == nil then
		-- New beacon
		guiBeacon = {}
		guiBeacon.gui = sm.gui.createWorldIconGui( 44, 44, "$GAME_DATA/Gui/Layouts/Hud/Hud_BeaconIcon.layout", false )
	end

	-- Setup gui
	guiBeacon.gui:setItemIcon( "Icon", "BeaconIconMap", "BeaconIconMap", tostring( beacon.iconData.iconIndex ) )
	local beaconColor = BEACON_COLORS[beacon.iconData.colorIndex]
	guiBeacon.gui:setColor( "Icon", beaconColor )
	if hosted and sm.exists( beacon.shape ) then
		guiBeacon.gui:setHost( beacon.shape )
	else
		guiBeacon.gui:setWorldPosition( beacon.position )
	end
	guiBeacon.gui:setRequireLineOfSight( false )
	guiBeacon.gui:setMaxRenderDistance(10000)
	if settings.visible then
		guiBeacon.gui:open()
	else
		guiBeacon.gui:close()
	end

	-- Create beacon data
	guiBeacon.world = beacon.world
	guiBeacon.shape = beacon.shape
	guiBeacon.position = beacon.position
	guiBeacon.iconData = beacon.iconData

	self.cl.beacons[tostring( guiBeacon.shape.id )] = guiBeacon
end

function BeaconManager.cl_getBeacons( self )
	return self.cl.beacons
end

function BeaconManager.cl_getBeaconSettings( self, id )
	local settings = self.cl.beaconSettings[tostring( id )]
	if settings then
		return settings
	end
	local defaultSettings = {}
	defaultSettings.visible = true
	return defaultSettings
end

function BeaconManager.cl_setBeaconVisible( self, id, visible )
	local settings = self:cl_getBeaconSettings(id)
	settings.visible = visible
	self.cl.beaconSettings[tostring( id )] = settings

	local guiBeacon = self.cl.beacons[tostring( id )]
	if guiBeacon then
		if visible then
			guiBeacon.gui:open()
		else
			guiBeacon.gui:close()
		end
	end
end