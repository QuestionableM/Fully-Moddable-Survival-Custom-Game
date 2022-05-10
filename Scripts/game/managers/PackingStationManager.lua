PackingStationManager = class( nil )

-- Server side
function PackingStationManager.sv_onCreate( self )
end

function PackingStationManager.sv_onCellLoaded( self, x, y )
 
	local concat = function(a, b)
		for _, v in pairs(b) do
			a[#a+1] = v;
		end
	end
	local forEach = function(a, fn)
		for i, v in pairs(a) do
			fn(i, v)
		end
	end

	local fronts = sm.cell.getInteractablesByUuid( x, y, obj_packingstation_front )
	if #fronts == 0 then return end
	local mids = sm.cell.getInteractablesByUuid( x, y, obj_packingstation_mid )
	if #mids == 0 then return end
	local screens = {}
	concat( screens, sm.cell.getInteractablesByUuid( x, y, obj_packingstation_screen_fruit ) )
	concat( screens, sm.cell.getInteractablesByUuid( x, y, obj_packingstation_screen_veggie ) )
	if #screens == 0 then return end

	local packingStation = {}
	packingStation.front = fronts[1];
	packingStation.mid = mids[1];
	packingStation.screens = screens;
	packingStation.crateload = sm.cell.getInteractablesByUuid( x, y, obj_packingstation_crateload )[1];

	packingStation.front:setParams({ packingStation = packingStation })
	packingStation.mid:setParams({ packingStation = packingStation })
	forEach(packingStation.screens, function(i, screen)  screen:setParams({ packingStation = packingStation, index = i }) end )

	if packingStation.crateload then
		packingStation.crateload:setParams({ packingStation = packingStation })
	end
	
end