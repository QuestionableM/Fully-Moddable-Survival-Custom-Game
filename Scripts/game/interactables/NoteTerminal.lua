-- NoteTerminal.lua --
dofile( "$SURVIVAL_DATA/Scripts/game/managers/QuestManager.lua" )

NoteTerminal = class( nil )
NoteTerminal.maxParentCount = 1
NoteTerminal.maxChildCount = 0
NoteTerminal.colorNormal = sm.color.new( 0xdeadbeef )
NoteTerminal.colorHighlight = sm.color.new( 0xdeadbeef )
NoteTerminal.connectionInput = sm.interactable.connectionType.logic
NoteTerminal.connectionOutput = sm.interactable.connectionType.none
NoteTerminal.poseWeightCount = 1

local UnfoldSpeed = 5

-- Client

function NoteTerminal.client_onCreate( self )
	self.cl = {}
	self.cl.unfoldWeight = 0
	self.cl.activeEffect = sm.effect.createEffect( "NoteTerminal - Active", self.interactable )
end

function NoteTerminal.client_canInteract( self )
	local parent = self.interactable:getSingleParent()
	if parent and parent.active then
		return not QuestManager.Cl_IsQuestComplete( "quest_tutorial" )
	end
	sm.gui.setInteractionText( "#{INFO_REQUIRES_POWER}" )
	return false
end

function NoteTerminal.sv_n_interact( self )
	local parent = self.interactable:getSingleParent()
	if parent and parent.active then
		QuestManager.Sv_OnEvent( "event.quest_tutorial.intel_aquired" )
	end
end

function NoteTerminal.client_onInteract( self, character, state )
	if state == true then
		self.network:sendToServer( "sv_n_interact" )
		sm.effect.playHostedEffect( "NoteTerminal - Interact", self.interactable )
	end
end

function NoteTerminal.client_onUpdate( self, deltaTime )
	local parent = self.interactable:getSingleParent()
	if parent and parent.active then
		if self.cl.unfoldWeight < 1.0 then
			self.cl.unfoldWeight = math.min( self.cl.unfoldWeight + deltaTime * UnfoldSpeed, 1.0 )
			self.interactable:setPoseWeight( 0, self.cl.unfoldWeight )
		end
	else
		if self.cl.unfoldWeight > 0.0 then
			self.cl.unfoldWeight = math.max( self.cl.unfoldWeight - deltaTime * UnfoldSpeed, 0.0 )
			self.interactable:setPoseWeight( 0, self.cl.unfoldWeight )
		end
	end

	local playActiveEffect = parent and parent.active and not QuestManager.Cl_IsQuestComplete( "quest_tutorial" )
	if playActiveEffect and not self.cl.activeEffect:isPlaying() then
		self.cl.activeEffect:start()
	elseif not playActiveEffect and self.cl.activeEffect:isPlaying() then
		self.cl.activeEffect:stop()
	end
end