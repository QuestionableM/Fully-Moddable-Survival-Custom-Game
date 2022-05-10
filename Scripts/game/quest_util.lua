
function FindInventoryChange( changes, uidItem )
	for _, change in ipairs( changes ) do
		if change.uuid == uidItem then
			return change.difference
		end
	end
	return 0
end
