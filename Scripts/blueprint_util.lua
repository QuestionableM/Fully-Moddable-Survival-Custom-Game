function vectorToAxis( vAxis )
	if vAxis == sm.vec3.new(1,0,0) then return 1 end
	if vAxis == sm.vec3.new(0,1,0) then return 2 end
	if vAxis == sm.vec3.new(0,0,1) then return 3 end
	if vAxis == sm.vec3.new(-1,0,0) then return -1 end
	if vAxis == sm.vec3.new(0,-1,0) then return -2 end
	if vAxis == sm.vec3.new(0,0,-1) then return -3 end
	return 0
end

function axisToVector( axis )
	if axis == 1 then return sm.vec3.new(1,0,0) end
	if axis == 2 then return sm.vec3.new(0,1,0) end
	if axis == 3 then return sm.vec3.new(0,0,1) end
	if axis == -1 then return sm.vec3.new(-1,0,0) end
	if axis == -2 then return sm.vec3.new(0,-1,0) end
	if axis == -3 then return sm.vec3.new(0,0,-1) end
	return sm.vec3.new(0,0,0)
end

function rotateAxis( axis, qRot )
	return vectorToAxis( qRot * axisToVector( axis ) )
end

function tableToVec3( tbl )
	return sm.vec3.new( tbl.x, tbl.y, tbl.z )
end

function rotateBounds( tblBounds, xaxis, zaxis )
	local bounds = tableToVec3( tblBounds )
	local xAxis = axisToVector( xaxis )
	local zAxis = axisToVector( zaxis )
	local yAxis = sm.vec3.cross( zAxis, xAxis )
	return sm.vec3.new(	xAxis.x*bounds.x + yAxis.x*bounds.y + zAxis.x*bounds.z,
						xAxis.y*bounds.x + yAxis.y*bounds.y + zAxis.y*bounds.z,
						xAxis.z*bounds.x + yAxis.z*bounds.y + zAxis.z*bounds.z )
end

function transformPos( pos, vTranslate, qRot )
	local v = ( qRot * ( sm.vec3.new( pos.x, pos.y, pos.z ) + vTranslate ) )
	return { x = v.x, y = v.y, z = v.z }
end

function transformJointPos( pos, vTranslate, qRot )
	local v = ( qRot * ( sm.vec3.new( pos.x + 0.5, pos.y + 0.5, pos.z + 0.5 ) + vTranslate ) )
	return { x = v.x - 0.5, y = v.y - 0.5, z = v.z - 0.5 }
end

function equalPos( a, b )
	return a.x == b.x and a.y == b.y and a.z == b.z
end

function transformBlueprint( tblBlueprint, vTranslate, qRot )
	if tblBlueprint.joints then
		for _, joint in ipairs( tblBlueprint.joints ) do
			joint.xaxisA = rotateAxis( joint.xaxisA, qRot )
			joint.xaxisB = rotateAxis( joint.xaxisB, qRot )

			joint.zaxisA = rotateAxis( joint.zaxisA, qRot )
			joint.zaxisB = rotateAxis( joint.zaxisB, qRot )

			joint.posA = transformJointPos( joint.posA, vTranslate, qRot )
			joint.posB = transformJointPos( joint.posB, vTranslate, qRot )
		end
	end

	if tblBlueprint.bodies then
		for _, body in ipairs( tblBlueprint.bodies ) do
			if body.childs then
				for _, child in ipairs( body.childs ) do
					child.xaxis = rotateAxis( child.xaxis, qRot )
					child.zaxis = rotateAxis( child.zaxis, qRot )
					child.pos = transformPos( child.pos, vTranslate, qRot )
				end
			end
		end
	end
end

function removePartFromBlueprint( tblBlueprint, sShapeUuid )
	if tblBlueprint.bodies then
		for _, body in ipairs( tblBlueprint.bodies ) do
			for i = #body.childs, 1, -1 do
				if body.childs[i].shapeId == sShapeUuid then
					table.remove( body.childs, i )
					return true;
				end
			end
		end
	end
	return false
end
