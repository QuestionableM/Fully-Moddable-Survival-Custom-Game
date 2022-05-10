DebugObject = class()
DebugObject.maxChildCount = 0
DebugObject.maxParentCount = 0
DebugObject.connectionInput = sm.interactable.connectionType.none
DebugObject.connectionOutput = sm.interactable.connectionType.none
DebugObject.fireDelay = 40 --ticks (1 seconds)

function DebugObject.server_onCreate( self )
end

function DebugObject.client_onCreate( self )
	self.gui = sm.gui.widget.load( "MotorGui.layout", true )
	self.button = self.gui:find( "Button" )
	self.button:bindOnClick( "onClick" )
end

function DebugObject.client_onInteract( self, state )
	self.gui.visible = true
end

function DebugObject.onClick( self, widget )
	print( "OnClick!" )
	print( widget )
end
