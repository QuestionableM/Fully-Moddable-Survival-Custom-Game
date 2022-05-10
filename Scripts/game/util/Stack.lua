Stack = class( nil )

function Stack.init( self )
	self.stack = {}
end

function Stack.push( self, item )
	self.stack[#self.stack + 1] = item
end

function Stack.pop( self )
	return table.remove( self.stack, #self.stack )
end
