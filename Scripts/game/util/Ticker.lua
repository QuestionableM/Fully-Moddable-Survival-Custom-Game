Ticker = class( nil )

function Ticker.init( self )
	self.tickers = {}
end

function Ticker.addState( self, state )
	if state.tick then
		self.tickers[#self.tickers + 1] = state
	end
end

function Ticker.tick( self )
	for _, t in ipairs( self.tickers ) do
		t:tick()
	end
end
