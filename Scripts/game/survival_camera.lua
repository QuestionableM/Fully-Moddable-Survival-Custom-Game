

--type: 		Whether the position and direction is set in localSpace or worldSpace
--lerpTime:		The time it takes to fully reach lerp into this position
--yaw and pitch is set in localSpace, direction is used in worldSpace
--cameraState	sm.camera.state.default, sm.camera.state.forcedFP, sm.camera.state.forcedTP

camera_wakeup_bed = 
{
	cameraState = sm.camera.state.cutsceneFP,
	cameraPullback = { standing = 0, seated = 0 },
	canSkip = false,
	nodes =
	{
		{
			type = "localSpace",
			position = sm.vec3.new( 0, -1, -0.75 ),
			pitch = 80,
			yaw = 90,
			lerpTime = 1
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, -1, -0.75 ),
			pitch = 80,
			yaw = 90,
			lerpTime = 0.5
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, -1, -0.375 ),
			pitch = -10,
			yaw = 90,
			lerpTime = 1
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, -1, -0.375 ),
			pitch = -10,
			yaw = 90,
			lerpTime = 0.5
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, -1, -0.375 ),
			pitch = -20,
			yaw = 0,
			lerpTime = 0.5
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, -0.5, -0.25 ),
			pitch = -40,
			yaw = 0,
			lerpTime = 0.25
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, 0 ),
			pitch = 0,
			yaw = 0,
			lerpTime = 0.5
		}
	}
}

camera_wakeup_ground = 
{
	cameraState = sm.camera.state.cutsceneFP,
	cameraPullback = { standing = 0, seated = 0 },
	canSkip = false,
	nodes =
	{
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, -1.0 ),
			pitch = 80,
			yaw = 0,
			lerpTime = 1,
			events =
			{
				{
					type = "character",
					data = "wakeup"
				}
			}
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, -1.0 ),
			pitch = 80,
			yaw = 0,
			lerpTime = 0.5
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, -0.375 ),
			pitch = -10,
			yaw = 0,
			lerpTime = 1
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, -0.2 ),
			pitch = -20,
			yaw = 0,
			lerpTime = 0.25
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, 0 ),
			pitch = -10,
			yaw = 0,
			lerpTime = 0.25
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, 0 ),
			pitch = 0,
			yaw = 0,
			lerpTime = 0.25
		}
		
	}
}

camera_wakeup_crash = 
{
	cameraState = sm.camera.state.cutsceneFP,
	cameraPullback = { standing = 0, seated = 0 },
	canSkip = false,
	nodes =
	{
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, -1.2 ),
			pitch = 0,
			yaw = 0,
			lerpTime = 1,
			events =
			{
				{
					type = "character",
					data = "wakeup"
				}
			}
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, -1.2 ),
			pitch = 0,
			yaw = 0,
			lerpTime = 1
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, -1.0 ),
			pitch = -70,
			yaw = 0,
			lerpTime = 1.25
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, -1.1 ),
			pitch = -80,
			yaw = 0,
			lerpTime = 0.125
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, -1.0 ),
			pitch = -70,
			yaw = 0,
			lerpTime = 0.125
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, -0.5 ),
			pitch = -20,
			yaw = 0,
			lerpTime = 0.5
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, -0.6 ),
			pitch = -20,
			yaw = 0,
			lerpTime = 0.25
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, -0.2 ),
			pitch = -20,
			yaw = 0,
			lerpTime = 0.25
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, 0 ),
			pitch = -10,
			yaw = 0,
			lerpTime = 0.25
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, 0 ),
			pitch = 0,
			yaw = 0,
			lerpTime = 0.25
		}
	}
}

camera_approach_crash = 
{
	cameraState = sm.camera.state.cutsceneTP,
	nextCutscene = "camera_wakeup_crash",
	canSkip = true,
	nodes =
	{
		{
			type = "localSpace",
			position = sm.vec3.new( -2, -4, 0.5 ),
			pitch = -20,
			yaw = 45,
			lerpTime = 1,
			events =
			{
				{
					type = "character",
					data = "downed"
				}
			}
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, -4, 0.5 ),
			pitch = -20,
			yaw = 0,
			lerpTime = 2.5
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 2, -4, 0.5 ),
			pitch = -20,
			yaw = -45,
			lerpTime = 2.0
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 2, -4, 0.5 ),
			pitch = -20,
			yaw = -45,
			lerpTime = 0.5
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, -1.5, 1 ),
			pitch = -45,
			yaw = 0,
			lerpTime = 1
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, 1.5 ),
			pitch = -75,
			yaw = 0,
			lerpTime = 1.0
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, 1.5 ),
			pitch = -75,
			yaw = 0,
			lerpTime = 0.25
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, 0.8 ),
			pitch = -55,
			yaw = 0,
			lerpTime = 0.25
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, 0, 0.2 ),
			pitch = 0,
			yaw = 0,
			lerpTime = 0.25
		}

	}
}

camera_test = 
{
	cameraState = sm.camera.state.cutsceneTP,
	--cameraPullback = { standing = 0, seated = 0 },
	nodes =
	{
		{
			type = "playerSpace",
			position = sm.vec3.new( 0, 0, 0 ),
			pitch = 0,
			yaw = 0,
			lerpTime = 0.0
		},
		{
			type = "localSpace",
			position = sm.vec3.new( -1, -1, 0 ),
			pitch = 0,
			yaw = 45,
			lerpTime = 0.5
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, -math.pi*0.5, 0 ),
			pitch = 0,
			yaw = 0,
			lerpTime = 0.25
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 1, -1, 0 ),
			pitch = 0,
			yaw = -45,
			lerpTime = 0.25
		},
		{
			type = "localSpace",
			position = sm.vec3.new( math.pi*0.5, 0, 0 ),
			pitch = 0,
			yaw = -90,
			lerpTime = 0.25
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 1, 1, 0 ),
			pitch = 0,
			yaw = -135,
			lerpTime = 0.25,
			events =
			{
				{
					type = "character",
					data = "downed"
				}
			}
		},
		{
			type = "localSpace",
			position = sm.vec3.new( 0, math.pi*0.5, 0 ),
			pitch = 0,
			yaw = -180,
			lerpTime = 0.25
		},
		{
			type = "localSpace",
			position = sm.vec3.new( -1, 1, 0 ),
			pitch = 0,
			yaw = -225,
			lerpTime = 0.25
		},
		{
			type = "localSpace",
			position = sm.vec3.new( -math.pi*0.5, 0, 0 ),
			pitch = 0,
			yaw = -270,
			lerpTime = 0.25
		},
		{
			type = "localSpace",
			position = sm.vec3.new( -1, -1, 0 ),
			pitch = 0,
			yaw = -315,
			lerpTime = 0.25
		},
		{
			type = "playerSpace",
			position = sm.vec3.new( 0, 0, 0 ),
			pitch = 0,
			yaw = -315,
			lerpTime = 0.5
		}

	}
}

camera_test_joint = 
{
	cameraState = sm.camera.state.cutsceneFP,
	attached =
	{
		jointName = "jnt_camera",
		attachTime = 1.0,
		initialDirection = sm.vec3.new( 0, 0, 1 ),
		events =
		{
			{
				type = "character",
				data = "awake"
			}
		}
	}
}

camera_cutscenes = 
{ 
	camera_wakeup_bed = camera_wakeup_bed,
	camera_wakeup_ground = camera_wakeup_ground,
	camera_wakeup_crash = camera_wakeup_crash,
	camera_approach_crash = camera_approach_crash,
	camera_test = camera_test,
	camera_test_joint = camera_test_joint
}
