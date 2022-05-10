-- Debug printing
DEBUG_AI_STATES = false

-- Namespace storage channels
STORAGE_CHANNEL_WAREHOUSES = 10
STORAGE_CHANNEL_ELEVATORS = 11
STORAGE_CHANNEL_FIRE = 12
STORAGE_CHANNEL_SPAWNERS = 13
STORAGE_CHANNEL_WAYPOINT_WAITLIST = 14
STORAGE_CHANNEL_BEDS = 15
STORAGE_CHANNEL_TIME = 16
STORAGE_CHANNEL_UNIT_MANAGER = 17
STORAGE_CHANNEL_SEED_SPAWNS = 18
STORAGE_CHANNEL_BAGS = 19
STORAGE_CHANNEL_CROP_ATTACK_CELLS = 20
STORAGE_CHANNEL_HAYBOT_SPAWNS = 21
STORAGE_CHANNEL_TOTEBOT_GREEN_SPAWNS = 22
STORAGE_CHANNEL_TAPEBOT_SPAWNS = 23
STORAGE_CHANNEL_FARMBOT_SPAWNS = 24
STORAGE_CHANNEL_WOC_SPAWNS = 25
STORAGE_CHANNEL_GLOWGORP_SPAWNS = 26
STORAGE_CHANNEL_LOOTCRATE_SPAWNS = 27
STORAGE_CHANNEL_RUINCHEST_SPAWNS = 28
STORAGE_CHANNEL_GAS_SPAWNS = 29
STORAGE_CHANNEL_FARMERBALL_SPAWNS = 30
STORAGE_CHANNEL_EPICLOOTCRATE_SPAWNS = 31
STORAGE_CHANNEL_FOREIGN_CONNECTIONS = 32
STORAGE_CHANNEL_WAYPOINT_CELLS = 33
STORAGE_CHANNEL_PERMANENT_BEDS = 34
STORAGE_CHANNEL_BEACONS = 35
--STORAGE_CHANNEL_QUESTS = 36 -- Deprecated, quests are stored in the QuestManager
STORAGE_CHANNEL_LOCATIONS = 37 -- Written by world generation
--STORAGE_CHANNEL_CELL_TILE_STORAGE_KEYS = 38
STORAGE_CHANNEL_KINEMATIC_STATE = 39
STORAGE_CHANNEL_COMPLEX_AIRLOCK = 40
STORAGE_CHANNEL_UNDERGOUND_LEVELS = 41
STORAGE_CHANNEL_CABLEBOT_SPAWNS = 42
STORAGE_CHANNEL_DOUSED_NAMED_FIRES = 43
STORAGE_CHANNEL_QUESTMANAGER = 44

UUID5_NAMESPACE_BASE = sm.uuid.new( "5cb5d80f-ed9b-4854-9bb4-5496193c560a" )
UUID5_NAMESPACE_KINEMATIC_STATE = sm.uuid.generateNamed( UUID5_NAMESPACE_BASE, "kinematic_state" )



-- Select player spawn point
START_AREA_SPAWN_POINT = sm.vec3.new( -2336, -2592, 16 )
TERRAIN_DEV_SPAWN_POINT = sm.vec3.new( 0.0, 0.0, 100.0 )








SURVIVAL_DEV_SPAWN_POINT = START_AREA_SPAWN_POINT


DAYCYCLE_TIME = 1440.0 -- seconds (24 minutes)
DAYCYCLE_TIME_TICKS = DAYCYCLE_TIME * 40

function DaysInTicks( days ) return days * DAYCYCLE_TIME_TICKS end

DAYCYCLE_DAWN = 6 / 24
DAYCYCLE_SOUND_TIMES = { 0, 3 / 24, 6 / 24, 18 / 24, 21 / 24, 1 }
DAYCYCLE_SOUND_VALUES = { 1, 1, 0, 0, 1, 1 }
assert( #DAYCYCLE_SOUND_TIMES == #DAYCYCLE_SOUND_VALUES )

DAYCYCLE_LIGHTING_TIMES = { 0, 3 / 24, 6 / 24, 18 / 24, 21 / 24, 1 }
DAYCYCLE_LIGHTING_VALUES = { 0, 0, 0.5, 0.5, 1, 1 }
assert( #DAYCYCLE_LIGHTING_TIMES == #DAYCYCLE_LIGHTING_VALUES )

AMBUSHES = {
	{
		time = 20.5 / 24,
		magnitude = 1
	},
	{
		time = 21 / 24,
		magnitude = 1
	},
	{
		time = 21.5 / 24,
		magnitude = 1
	},
	{
		time = 22 / 24,
		magnitude = 2,
		wave = 1 -- 1st wave
	},
	{
		time = 22.5 / 24,
		magnitude = 1
	},
	{
		time = 23 / 24,
		magnitude = 1
	},
	{
		time = 23.5 / 24,
		magnitude = 1
	},
	{
		time = 0 / 24,
		magnitude = 3,
		wave = 2 -- 2st wave
	},
	{
		time = 0.5 / 24,
		magnitude = 1
	},
	{
		time = 1 / 24,
		magnitude = 1
	},
	{
		time = 1.5 / 24,
		magnitude = 1
	},
	{
		time = 2 / 24,
		magnitude = 4,
		wave = 3 -- 3rd wave
	},
	{
		time = 2.5 / 24,
		magnitude = 1
	},
	{
		time = 3 / 24,
		magnitude = 1
	}
}

CELL_SIZE = 64.0

PIPE_TRAVEL_TICK_TIME = 8.0

AUDIO_MASS_DIVIDE_RATIO = 76800

AIR_TICK_TIME_TO_TUMBLE = 20
DEFAULT_TUMBLE_TICK_TIME = 40
DEFAULT_CRUSH_TICK_TIME = 8

MAX_CHARACTER_KNOCKBACK_VELOCITY = 50.0

CUTSCENE_FADE_IN_TIME = 0.5 -- Seconds
CUTSCENE_FADE_OUT_TIME = 1.0 -- Seconds

-- Ordered HexStr colors selectable from the paint-tool
PAINT_COLORS =
{
	"eeeeeeff", "f5f071ff", "cbf66fff", "68ff88ff", "7eededff", "4c6fe3ff", "ae79f0ff", "ee7bf0ff", "f06767ff", "eeaf5cff",
	"7f7f7fff", "e2db13ff", "a0ea00ff", "19e753ff", "2ce6e6ff", "0a3ee2ff", "7514edff", "cf11d2ff", "d02525ff", "df7f00ff",
	"4a4a4aff", "817c00ff", "577d07ff", "0e8031ff", "118787ff", "0f2e91ff", "500aa6ff", "720a74ff", "7c0000ff", "673b00ff",
	"222222ff", "323000ff", "375000ff", "064023ff", "0a4444ff", "0a1d5aff", "35086cff", "520653ff", "560202ff", "472800ff"
}

-- Units
RAIDER_AMBUSH_RADIUS = 24.0

-- Collision
SMALL_TUMBLE_TICK_TIME = 1.0 * 40
MEDIUM_TUMBLE_TICK_TIME = 2.5 * 40
LARGE_TUMBLE_TICK_TIME = 5.0 * 40

SPINNER_ANGULAR_THRESHOLD = 3.5
PLASMA_ANGULAR_THRESHOLD = 50.0

-- Harvestable
TREE_TRUNK_HITS = 3
TREE_LOG_HITS = 2

-- Manager
PESTICIDE_SIZE = sm.vec3.new( 5.0, 5.0, 3.0 )

-- Math
FLT_EPSILON = 1.192092896e-07
DBL_EPSILON = 2.2204460492503131e-016

-- Colors
WHITE = sm.color.new( "ffffff" )
BLACK = sm.color.new( "000000" )
RED = sm.color.new( "ff0000" )
GREEN = sm.color.new( "00ff00" )
BLUE = sm.color.new( "0000ff" )
CYAN = sm.color.new( "00ffff" )
MAGENTA = sm.color.new( "ff00ff" )
YELLOW = sm.color.new( "ffff00" )

-- Physics
GRAVITY = 10.0















