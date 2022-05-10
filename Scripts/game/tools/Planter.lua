
dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua"

Planter = class()

local renderables = {}

local renderablesTp = {}
local renderablesFp = {}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

Planter.MayaFrameDuration = 1.0/30.0


function Planter.client_onCreate( self )
	self:cl_init()
end

function Planter.client_onRefresh( self )
	self:cl_init()
end

function Planter.cl_init( self )
	self:cl_loadAnimations()
end

function Planter.cl_loadAnimations( self )
	
	self.blendTime = 0.2
	self.blendSpeed = 10.0
	--self.tpAnimations = createTpAnimations(
	--	self.tool,
	--	{
	--
	--	}
	--)
	--
	--
	--setTpAnimation( self.tpAnimations, "idle", 5.0 )
	--
	--if self.tool:isLocal() then
	--	self.fpAnimations = createFpAnimations(
	--		self.tool,
	--		{
	--		
	--		}
	--	)
	--	setFpAnimation( self.fpAnimations, "idle", 0.0 )
	--end

end

function Planter.client_onUpdate( self, dt )
	
end

function Planter.client_onEquippedUpdate( self, primaryState, secondaryState )

	-- Detect soil
	local soilHarvestable = nil
	local success, result = sm.localPlayer.getRaycast( 7.5 )
	if result.type == "harvestable" then
		local harvestable = result:getHarvestable()
		if harvestable:getUuid() == hvs_soil then
			soilHarvestable = harvestable
			
			sm.gui.setCenterIcon( "Use" )
			local keyBindingText =  sm.gui.getKeyBinding( "Create", true )
			sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_PLANT}" )
		end
	end
	
	-- Plant harvestable
	if soilHarvestable then
		if primaryState == sm.tool.interactState.start then
			local activeItem = sm.localPlayer.getActiveItem()
			local plantable = sm.item.getPlantable( activeItem )
			if plantable then
				local params = { targetSoil = soilHarvestable, plantableUuid = activeItem, plantedHarvestableUuid = sm.uuid.new( plantable.harvestable ), playerInventory = sm.localPlayer.getInventory(), slot = sm.localPlayer.getSelectedHotbarSlot() }
				self.network:sendToServer( "sv_n_plant", params )
			end
		end
	end
	
	return soilHarvestable ~= nil, false
	
end

function Planter.client_onEquip( self )
	self.equipped = true
	self:cl_init()
end

function Planter.client_onUnequip( self )
	self.equipped = false
end

function Planter.sv_n_plant( self, params )
	if params.targetSoil then
		sm.event.sendToHarvestable( params.targetSoil, "sv_e_plant", params )
	end
end