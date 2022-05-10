Curve = class( nil )

function Curve.init( self, points )
	self.points = points
	table.sort(self.points, function (a, b) return a.t < b.t end )
end

function Curve.getValue( self, t )
	for i = 1,#self.points do
		local b = self.points[i]
		if t < b.t then
			if i == 1 then
				return b.v
			end
			local a = self.points[i-1]
			return lerp(a.v, b.v, ( t - a.t ) / ( b.t - a.t ) )
		end
	end
	return self.points[#self.points].v
end


function Curve.duration( self )
	return self.points[#self.points].t
end