
Horn = class()
Horn.maxParentCount = 1
Horn.maxChildCount = 0
Horn.connectionInput = sm.interactable.connectionType.logic
Horn.connectionOutput = sm.interactable.connectionType.none
Horn.poseWeightCount = 1

function Horn.server_onCreate( self )
	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = { sliderPos = 5 }
	end

	self.storage:save( self.saved )
	self.dirtySliderPos = false
	self.network:setClientData(	{ sliderPos = self.saved.sliderPos} )
end

function Horn.sv_setSlider( self, newSliderPos )
	self.saved.sliderPos = newSliderPos
	self.dirtySliderPos = true;
	self.network:sendToClients( "cl_setSlider", newSliderPos );
end

function Horn.server_onFixedUpdate( self, timeStep )

	if self.dirtySliderPos then
		self.storage:save( self.saved )
		self.dirtySliderPos = false
		self.network:setClientData(	{ sliderPos = self.saved.sliderPos } )
	end

end

function Horn.client_onCreate( self  )
	self.cl = {}
	self.effect = sm.effect.createEffect( "Horn - Honk", self.interactable )

	self.timer = 0.2
	self.animWeight = 0
	self.animationSpeed = 8.0
	self.parentActive = false

	self.currentSliderPos = 5;
	self.sliderRange = 11;
end

function Horn.client_onFixedUpdate( self, dt )
	local b_parentIsActive = self:inputActive()

	if b_parentIsActive and not self.parentActive then
		self.effect:start()
	elseif not b_parentIsActive and self.parentActive then
		self.effect:stopBreakSustain()
	end
	if b_parentIsActive then
		self.timer = 0.2
	end
	self.parentActive = b_parentIsActive
	

	if self.timer > 0 then
		self.timer = self.timer-dt
		self.animWeight = self.animWeight + self.animationSpeed*dt
	else
		self.animWeight = self.animWeight - self.animationSpeed*dt
	end

	self.animWeight = clamp( self.animWeight, 0, 1 )
	self.interactable:setPoseWeight( 0, self.animWeight )

end

function Horn.client_onClientDataUpdate( self, params )
	if self.cl.guiInterface then
		if self.cl.guiInterface:isActive() then
			self.cl.guiInterface:setSliderPosition( "Slider", params.sliderPos )
		end
	end
	self.currentSliderPos = params.sliderPos
	local newPitch = self.currentSliderPos / ( self.sliderRange-1 )
	self.effect:setParameter("pitch", newPitch)
end

function Horn.inputActive( self )
	local parent = self.interactable:getSingleParent();

	if parent then
		if parent:hasOutputType( sm.interactable.connectionType.logic ) then
			return parent:isActive()
		end
	end
	return false
end



--GUI

function Horn.client_onInteract( self, character, state )
	if state == true then
		self.cl.guiInterface = sm.gui.createGuiFromLayout( "$GAME_DATA/Gui/Layouts/Interactable/Interactable_Horn.layout" )
		self.cl.guiInterface:createHorizontalSlider( "Slider", self.sliderRange, self.currentSliderPos, "cl_updateSliderValue" )
		self.cl.guiInterface:setOnCloseCallback( "cl_onClose" )
		self.cl.guiInterface:setIconImage( "Icon", obj_interactive_horn )
		self.cl.guiInterface:open()
	end
end
	
function Horn.cl_onClose( self )
	if self.cl.guiInterface then
		self.cl.guiInterface:close()
		self.cl.guiInterface:destroy()
		self.cl.guiInterface = nil
	end
end

function Horn.cl_updateSliderValue( self, newSliderPos )
	self.network:sendToServer( "sv_setSlider", newSliderPos )
	
end

function Horn.cl_setSlider( self, newSliderPos )
	if self.cl.guiInterface then
		self.cl.guiInterface:setSliderPosition( "Slider", newSliderPos )
	end
	self.currentSliderPos = newSliderPos

	local newPitch = self.currentSliderPos / ( self.sliderRange-1 )
	self.effect:setParameter( "pitch", newPitch )
end
