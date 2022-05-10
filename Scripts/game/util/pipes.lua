dofile( "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua" )

ContainerUuids = {
	obj_container_gas,
	obj_container_battery,
	obj_container_water,
	obj_container_seed,
	obj_container_fertilizer,
	obj_container_ammo,
	obj_container_chest,
	obj_container_chemical,
	obj_craftbot_refinery,
}

PipeUuids = {
	obj_pneumatic_pipe_01,
	obj_pneumatic_pipe_02,
	obj_pneumatic_pipe_03,
	obj_pneumatic_pipe_04,
	obj_pneumatic_pipe_05,
	obj_pneumatic_pipe_bend
}
for _,v in ipairs( ContainerUuids ) do assert( v ) end
for _,v in ipairs( PipeUuids ) do assert( v ) end

PipeState = { off = 1, invalid = 2, connected = 3, valid = 4 }

local PipeTravelTime = math.max( PIPE_TRAVEL_TICK_TIME / 40.0, 0.025 )

function RecursePipedShapeGraph( parent, setMarkedShapes, fnOnVertex )
	setMarkedShapes[parent.shape:getId()] = true
	for _, pipedShape in ipairs( parent.shape:getPipedNeighbours() ) do
		if setMarkedShapes[pipedShape:getId()] == nil then

			-- Set up new vertex in graph
			local vertex = {
				shape = pipedShape,
				childs = {},
				distance = parent.distance + 1,
				shapesOnPath = shallowcopy( parent.shapesOnPath ),
			}
			table.insert( vertex.shapesOnPath, pipedShape )
			table.insert( parent.childs, vertex )

			-- Callback to allow for custom traversal behaviours
			local recurse = true
			if fnOnVertex then
				recurse = fnOnVertex( vertex, parent )
			end

			if recurse then
				RecursePipedShapeGraph( vertex, setMarkedShapes, fnOnVertex )
			end
		end
	end
end

function ConstructPipedShapeGraph( shape, fnOnVertex )
	local setMarkedShapes = {}
	local root = { childs = {}, shape = shape, shapesOnPath = {}, distance = 0 }
	RecursePipedShapeGraph( root, setMarkedShapes, fnOnVertex )
end

function FindContainerToCollectTo( containers, itemUid, amount )
	for _, container in ipairs( containers ) do
		if sm.container.canCollect( container.shape:getInteractable():getContainer(), itemUid, amount ) then
			return container
		end
	end
end

function FindContainerToSpendFrom( containers, itemUid, amount )
	for _, container in ipairs( containers ) do
		if sm.container.canSpend( container.shape:getInteractable():getContainer(), itemUid, amount ) then
			return container
		end
	end
end

PipeStateOverrideTable = {
	[PipeState.off] = {
		[PipeState.off] = false,
		[PipeState.invalid] = true,
		[PipeState.connected] = true,
		[PipeState.valid] = true,
	},
	[PipeState.invalid] = {
		[PipeState.off] = false,
		[PipeState.invalid] = false,
		[PipeState.connected] = false,
		[PipeState.valid] = false,
	},
	[PipeState.connected] = {
		[PipeState.off] = false,
		[PipeState.invalid] = true,
		[PipeState.connected] = false,
		[PipeState.valid] = true,
	},
	[PipeState.valid] = {
		[PipeState.off] = false,
		[PipeState.invalid] = true,
		[PipeState.connected] = false,
		[PipeState.valid] = false,
	},
}

function LightUpPipes( arrayPipes, fnOverride )
	for  _, pipe in ipairs( arrayPipes ) do
		local shape = pipe.shape
		local state = pipe.state
		if sm.exists( shape ) then
			local pipeGlow = 1.0

			if fnOverride then
				state, pipeGlow = fnOverride( pipe )
			end

			local currentUvFrameIndex = shape:getInteractable():getUvFrameIndex() + 1
			if PipeStateOverrideTable[currentUvFrameIndex][state] then
				shape:getInteractable():setUvFrameIndex( state - 1 )
				shape:getInteractable():setGlowMultiplier( pipeGlow )
			end
		end
	end
end

PipeEffectNode = class()

function PipeEffectNode.shapeExists( self )
	return self.shape:shapeExists()
end

function PipeEffectNode.getWorldPosition( self )
	return self.shape:transformLocalPoint( self.point )
end

PipeEffectPlayer = class()

function PipeEffectPlayer.onCreate( self )
	self.effectTasks = {}
end

function PipeEffectPlayer.pushShapeEffectTask( self, shapeList, item )

	assert( item )
	local effect = sm.effect.createEffect( "ShapeRenderable" )
	local bounds = sm.item.getShapeSize( item )
	assert( bounds )
	effect:setParameter( "uuid", item )
	effect:setPosition( shapeList[1]:getWorldPosition() )
	effect:setScale( sm.vec3.new( sm.construction.constants.subdivideRatio, sm.construction.constants.subdivideRatio, sm.construction.constants.subdivideRatio ) / bounds )

	self:pushEffectTask( shapeList, effect )
end

function PipeEffectPlayer.pushEffectTask( self, shapeList, effect )
	table.insert( self.effectTasks, { shapeList = shapeList, effect = effect, progress = 0 })
end

function PipeEffectPlayer.update( self, dt )
	for idx, task in reverse_ipairs( self.effectTasks ) do

		if task.progress == 0 then
			task.effect:start()
		end

		if task.progress > 0 and task.progress < 1 and #task.shapeList > 1 then
			local span = ( 1.0 / ( #task.shapeList - 1 ) )

			local b = math.ceil( task.progress / span ) + 1
			local a = b - 1
			local t = ( task.progress - ( a - 1 ) * span ) / span
			--print( "A: "..a.." B: "..b.." t: "..t)

			assert(a ~= 0 and a <= #task.shapeList)
			assert(b ~= 0 and b <= #task.shapeList)

			local nodeA = task.shapeList[a]
			local nodeB = task.shapeList[b]

			if pcall( function() nodeA:shapeExists() end ) and pcall( function() nodeB:shapeExists() end ) then
				local lerpedPosition = ( nodeA:getWorldPosition() * ( 1 - t ) ) + ( nodeB:getWorldPosition() * t )
				task.effect:setPosition( lerpedPosition )
			else
				task.progress = 1 -- End the effect
			end
		end

		task.progress = task.progress + dt / PipeTravelTime

		if task.progress >= 1 then
			task.effect:stop()
			table.remove( self.effectTasks, idx )
		end
	end
end