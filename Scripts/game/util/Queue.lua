Queue = class( nil )

function Queue.push( self, value )
	if self.back == nil then
		self.back = 1
		self.front = 1
		self.array = {}
	end
	self.array[self.back] = value
	self.back = self.back + 1
end

function Queue.pop( self )
	if self.front == self.back then
		return nil
	end
	local value = self.array[self.front]
	self.array[self.front] = nil
	self.front = self.front + 1
	return value
end

function Queue.peek( self )
	if self.front == self.back then
		return nil
	end
	local value = self.array[self.front]
	return value
end

function Queue.empty( self )
	return self.front == self.back
end

function Queue.size( self )
	return self.back and self.back - self.front or 0
end
