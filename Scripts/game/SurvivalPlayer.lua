dofile( "$GAME_DATA/Scripts/game/BasePlayer.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/QuestManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/survival_camera.lua" )
dofile( "$CONTENT_DATA/Scripts/game/survival_constants.lua" )
dofile( "$CONTENT_DATA/Scripts/game/util/Timer.lua" )
dofile( "$CONTENT_DATA/Scripts/util.lua" )
dofile( "$CONTENT_DATA/Scripts/game/quest_util.lua" )


SurvivalPlayer = class( BasePlayer )


local StatsTickRate = 40

local PerSecond = StatsTickRate / 40
local PerMinute = StatsTickRate / ( 40 * 60 )

local FoodRecoveryThreshold = 5 -- Recover hp when food is above this value
local FastFoodRecoveryThreshold = 50 -- Recover hp fast when food is above this value
local HpRecovery = 50 * PerMinute
local FastHpRecovery = 75 * PerMinute
local FoodCostPerHpRecovery = 0.2
local FastFoodCostPerHpRecovery = 0.2

local FoodCostPerStamina = 0.02
local WaterCostPerStamina = 0.1
local SprintStaminaCost = 0.7 / 40 -- Per tick while sprinting
local CarryStaminaCost = 1.4 / 40 -- Per tick while carrying

local FoodLostPerSecond = 100 / 3.5 / 24 / 60
local WaterLostPerSecond = 100 / 2.5 / 24 / 60

local BreathLostPerTick = ( 100 / 60 ) / 40

local FatigueDamageHp = 1 * PerSecond
local FatigueDamageWater = 2 * PerSecond
local DrownDamage = 5
local DrownDamageCooldown = 40

local RespawnTimeout = 60 * 40

local RespawnFadeDuration = 0.45
local RespawnEndFadeDuration = 0.45

local RespawnFadeTimeout = 5.0
local RespawnDelay = RespawnFadeDuration * 40
local RespawnEndDelay = 1.0 * 40

local BaguetteSteps = 9

function SurvivalPlayer.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	self.sv.saved = self.sv.saved or {}
	self.sv.saved.stats = self.sv.saved.stats or {
		hp = 100, maxhp = 100,
		food = 100, maxfood = 100,
		water = 100, maxwater = 100,
		breath = 100, maxbreath = 100
	}
	if self.sv.saved.isConscious == nil then self.sv.saved.isConscious = true end
	if self.sv.saved.hasRevivalItem == nil then self.sv.saved.hasRevivalItem = false end
	if self.sv.saved.isNewPlayer == nil then self.sv.saved.isNewPlayer = true end
	if self.sv.saved.inChemical == nil then self.sv.saved.inChemical = false end
	if self.sv.saved.inOil == nil then self.sv.saved.inOil = false end
	if self.sv.saved.tutorialsWatched == nil then self.sv.saved.tutorialsWatched = {} end
	self.storage:save( self.sv.saved )

	self:sv_init()
	self.network:setClientData( self.sv.saved )
end

function SurvivalPlayer.server_onRefresh( self )
	self:sv_init()
	self.network:setClientData( self.sv.saved )
end

function SurvivalPlayer.sv_init( self )
	BasePlayer.sv_init( self )
	self.sv.staminaSpend = 0

	self.sv.statsTimer = Timer()
	self.sv.statsTimer:start( StatsTickRate )

	self.sv.drownTimer = Timer()
	self.sv.drownTimer:stop()

	self.sv.spawnparams = {}
end

function SurvivalPlayer.client_onCreate( self )
	BasePlayer.client_onCreate( self )
	self.cl = self.cl or {}
	if self.player == sm.localPlayer.getPlayer() then
		if g_survivalHud then
			g_survivalHud:open()
		end

		self.cl.hungryEffect = sm.effect.createEffect( "Mechanic - StatusHungry" )
		self.cl.thirstyEffect = sm.effect.createEffect( "Mechanic - StatusThirsty" )
		self.cl.underwaterEffect = sm.effect.createEffect( "Mechanic - StatusUnderwater" )
		self.cl.followCutscene = 0.0
		self.cl.tutorialsWatched = {}
	end

	self:cl_init()
end

function SurvivalPlayer.client_onRefresh( self )
	self:cl_init()

	sm.gui.hideGui( false )
	sm.camera.setCameraState( sm.camera.state.default )
	sm.localPlayer.setLockedControls( false )
end

function SurvivalPlayer.cl_init( self )
	self.useCutsceneCamera = false
	self.progress = 0
	self.nodeIndex = 1
	self.currentCutscene = {}

	self.cl.revivalChewCount = 0
end

function SurvivalPlayer.client_onClientDataUpdate( self, data )
	BasePlayer.client_onClientDataUpdate( self, data )
	if sm.localPlayer.getPlayer() == self.player then

		if self.cl.stats == nil then self.cl.stats = data.stats end -- First time copy to avoid nil errors

		if g_survivalHud then
			g_survivalHud:setSliderData( "Health", data.stats.maxhp * 10 + 1, data.stats.hp * 10 )
			g_survivalHud:setSliderData( "Food", data.stats.maxfood * 10 + 1, data.stats.food * 10 )
			g_survivalHud:setSliderData( "Water", data.stats.maxwater * 10 + 1, data.stats.water * 10 )
			g_survivalHud:setSliderData( "Breath", data.stats.maxbreath * 10 + 1, data.stats.breath * 10 )
		end

		if self.cl.hasRevivalItem ~= data.hasRevivalItem then
			self.cl.revivalChewCount = 0
		end

		if self.player.character then
			local charParam = self.player:isMale() and 1 or 2
			self.cl.underwaterEffect:setParameter( "char", charParam )
			self.cl.hungryEffect:setParameter( "char", charParam )
			self.cl.thirstyEffect:setParameter( "char", charParam )

			if data.stats.breath <= 15 and not self.cl.underwaterEffect:isPlaying() and data.isConscious then
				self.cl.underwaterEffect:start()
			elseif ( data.stats.breath > 15 or not data.isConscious ) and self.cl.underwaterEffect:isPlaying() then
				self.cl.underwaterEffect:stop()
			end
			if data.stats.food <= 5 and not self.cl.hungryEffect:isPlaying() and data.isConscious then
				self.cl.hungryEffect:start()
			elseif ( data.stats.food > 5 or not data.isConscious ) and self.cl.hungryEffect:isPlaying() then
				self.cl.hungryEffect:stop()
			end
			if data.stats.water <= 5 and not self.cl.thirstyEffect:isPlaying() and data.isConscious then
				self.cl.thirstyEffect:start()
			elseif ( data.stats.water > 5 or not data.isConscious ) and self.cl.thirstyEffect:isPlaying() then
				self.cl.thirstyEffect:stop()
			end
		end

		if data.stats.food <= 5 and self.cl.stats.food > 5 then
			sm.gui.displayAlertText( "#{ALERT_HUNGER}", 5 )
		end
		if data.stats.water <= 5 and self.cl.stats.water > 5 then
			sm.gui.displayAlertText( "#{ALERT_THIRST}", 5 )
		end

		if data.stats.hp < self.cl.stats.hp and data.stats.breath == 0 then
			sm.gui.displayAlertText( "#{DAMAGE_BREATH}", 1 )
		elseif data.stats.hp < self.cl.stats.hp and data.stats.food == 0 then
			sm.gui.displayAlertText( "#{DAMAGE_HUNGER}", 1 )
		elseif data.stats.hp < self.cl.stats.hp and data.stats.water == 0 then
			sm.gui.displayAlertText( "#{DAMAGE_THIRST}", 1 )
		end

		self.cl.stats = data.stats
		self.cl.isConscious = data.isConscious
		self.cl.hasRevivalItem = data.hasRevivalItem

		sm.localPlayer.setBlockSprinting( data.stats.food == 0 or data.stats.water == 0 )

		for tutorialKey, _ in pairs( data.tutorialsWatched ) do
			-- Merge saved tutorials and avoid resetting client tutorials
			self.cl.tutorialsWatched[tutorialKey] = true
		end
		if not g_disableTutorialHints then
			if not self.cl.tutorialsWatched["hunger"] then
				if data.stats.water < 60 or data.stats.food < 60 then
					if not self.cl.tutorialGui then
						self.cl.tutorialGui = sm.gui.createGuiFromLayout( "$GAME_DATA/Gui/Layouts/Tutorial/PopUp_Tutorial.layout", true, { isHud = true, isInteractive = false, needsCursor = false } )
						self.cl.tutorialGui:setText( "TextTitle", "#{TUTORIAL_HUNGER_AND_THIRST_TITLE}" )
						self.cl.tutorialGui:setText( "TextMessage", "#{TUTORIAL_HUNGER_AND_THIRST_MESSAGE}" )
						local dismissText = string.format( sm.gui.translateLocalizationTags( "#{TUTORIAL_DISMISS}" ), sm.gui.getKeyBinding( "Use" ) )
						self.cl.tutorialGui:setText( "TextDismiss", dismissText )
						self.cl.tutorialGui:setImage( "ImageTutorial", "gui_tutorial_image_hunger.png" )
						self.cl.tutorialGui:setOnCloseCallback( "cl_onCloseTutorialHungerGui" )
						self.cl.tutorialGui:open()
					end
				end
			end
		end
	end
end

function SurvivalPlayer.cl_e_tryPickupItemTutorial( self )
	if not g_disableTutorialHints then
		if not self.cl.tutorialsWatched["pickupitem"] then
			if not self.cl.tutorialGui then
				self.cl.tutorialGui = sm.gui.createGuiFromLayout( "$GAME_DATA/Gui/Layouts/Tutorial/PopUp_Tutorial.layout", true, { isHud = true, isInteractive = false, needsCursor = false } )
				self.cl.tutorialGui:setText( "TextTitle", "#{TUTORIAL_PICKUP_ITEM_TITLE}" )
				self.cl.tutorialGui:setText( "TextMessage", "#{TUTORIAL_PICKUP_ITEM_MESSAGE}" )
				local dismissText = string.format( sm.gui.translateLocalizationTags( "#{TUTORIAL_DISMISS}" ), sm.gui.getKeyBinding( "Use" ) )
				self.cl.tutorialGui:setText( "TextDismiss", dismissText )
				self.cl.tutorialGui:setImage( "ImageTutorial", "gui_tutorial_image_pickup_items.png" )
				self.cl.tutorialGui:setOnCloseCallback( "cl_onCloseTutorialPickupItemGui" )
				self.cl.tutorialGui:open()
			end
		end
	end
end

function SurvivalPlayer.cl_onCloseTutorialHungerGui( self )
	self.cl.tutorialsWatched["hunger"] = true
	self.network:sendToServer( "sv_e_watchedTutorial", { tutorialKey = "hunger" } )
	self.cl.tutorialGui = nil
end

function SurvivalPlayer.cl_onCloseTutorialPickupItemGui( self )
	self.cl.tutorialsWatched["pickupitem"] = true
	self.network:sendToServer( "sv_e_watchedTutorial", { tutorialKey = "pickupitem" } )
	self.cl.tutorialGui = nil
end

function SurvivalPlayer.sv_e_watchedTutorial( self, params, player )
	self.sv.saved.tutorialsWatched[params.tutorialKey] = true
	self.storage:save( self.sv.saved )
	self.network:setClientData( self.sv.saved )
end

function SurvivalPlayer.cl_localPlayerUpdate( self, dt )
	BasePlayer.cl_localPlayerUpdate( self, dt )
	self:cl_updateCamera( dt )

	local character = self.player:getCharacter()
	if character and not self.cl.isConscious then
		local keyBindingText =  sm.gui.getKeyBinding( "Use", true )
		if self.cl.hasRevivalItem then
			if self.cl.revivalChewCount < BaguetteSteps then
				sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_EAT} ("..self.cl.revivalChewCount.."/10)" )
			else
				sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_REVIVE}" )
			end
		else
			sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_RESPAWN}" )
		end
	end

	if character then
		self.cl.underwaterEffect:setPosition( character.worldPosition )
		self.cl.hungryEffect:setPosition( character.worldPosition )
		self.cl.thirstyEffect:setPosition( character.worldPosition )
	end
end

function SurvivalPlayer.client_onInteract( self, character, state )
	if state == true then

		--self:cl_startCutscene( { effectName = "DollyZoomCutscene", worldPosition = character.worldPosition, worldRotation = sm.quat.identity() } )
		--self:cl_startCutscene( camera_test )
		--self:cl_startCutscene( camera_test_joint )
		--self:cl_startCutscene( camera_wakeup_ground )
		--self:cl_startCutscene( camera_approach_crash )
		--self:cl_startCutscene( camera_wakeup_crash )
		--self:cl_startCutscene( camera_wakeup_bed )

		if self.cl.tutorialGui and self.cl.tutorialGui:isActive() then
			self.cl.tutorialGui:close()
		end

		if not self.cl.isConscious then
			if self.cl.hasRevivalItem then
				if self.cl.revivalChewCount >= BaguetteSteps then
					self.network:sendToServer( "sv_n_revive" )
				end
				self.cl.revivalChewCount = self.cl.revivalChewCount + 1
				self.network:sendToServer( "sv_onEvent", { type = "character", data = "chew" } )
			else
				self.network:sendToServer( "sv_n_tryRespawn" )
			end
		end
	end
end

function SurvivalPlayer.server_onFixedUpdate( self, dt )
	BasePlayer.server_onFixedUpdate( self, dt )

	if g_survivalDev and not self.sv.saved.isConscious and not self.sv.saved.hasRevivalItem then
		if sm.container.canSpend( self.player:getInventory(), obj_consumable_longsandwich, 1 ) then
			if sm.container.beginTransaction() then
				sm.container.spend( self.player:getInventory(), obj_consumable_longsandwich, 1, true )
				if sm.container.endTransaction() then
					self.sv.saved.hasRevivalItem = true
					self.player:sendCharacterEvent( "baguette" )
					self.network:setClientData( self.sv.saved )
				end
			end
		end
	end

	-- Delays the respawn so clients have time to fade to black
	if self.sv.respawnDelayTimer then
		self.sv.respawnDelayTimer:tick()
		if self.sv.respawnDelayTimer:done() then
			self:sv_e_respawn()
			self.sv.respawnDelayTimer = nil
		end
	end

	-- End of respawn sequence
	if self.sv.respawnEndTimer then
		self.sv.respawnEndTimer:tick()
		if self.sv.respawnEndTimer:done() then
			self.network:sendToClient( self.player, "cl_n_endFadeToBlack", { duration = RespawnEndFadeDuration } )
			self.sv.respawnEndTimer = nil;
		end
	end

	-- If respawn failed, restore the character
	if self.sv.respawnTimeoutTimer then
		self.sv.respawnTimeoutTimer:tick()
		if self.sv.respawnTimeoutTimer:done() then
			self:sv_e_onSpawnCharacter()
		end
	end

	local character = self.player:getCharacter()
	-- Update breathing
	if character then
		if character:isDiving() then
			self.sv.saved.stats.breath = math.max( self.sv.saved.stats.breath - BreathLostPerTick, 0 )
			if self.sv.saved.stats.breath == 0 then
				self.sv.drownTimer:tick()
				if self.sv.drownTimer:done() then
					if self.sv.saved.isConscious then
						print( "'SurvivalPlayer' is drowning!" )
						self:sv_takeDamage( DrownDamage, "drown" )
					end
					self.sv.drownTimer:start( DrownDamageCooldown )
				end
			end
		else
			self.sv.saved.stats.breath = self.sv.saved.stats.maxbreath
			self.sv.drownTimer:start( DrownDamageCooldown )
		end

		-- Spend stamina on sprinting
		if character:isSprinting() then
			self.sv.staminaSpend = self.sv.staminaSpend + SprintStaminaCost
		end

		-- Spend stamina on carrying
		if not self.player:getCarry():isEmpty() then
			self.sv.staminaSpend = self.sv.staminaSpend + CarryStaminaCost
		end
	end

	-- Update stamina, food and water stats
	if character and self.sv.saved.isConscious and not g_godMode then
		self.sv.statsTimer:tick()
		if self.sv.statsTimer:done() then
			self.sv.statsTimer:start( StatsTickRate )

			-- Recover health from food
			if self.sv.saved.stats.food > FoodRecoveryThreshold then
				local fastRecoveryFraction = 0

				-- Fast recovery when food is above fast threshold
				if self.sv.saved.stats.food > FastFoodRecoveryThreshold then
					local recoverableHp = math.min( self.sv.saved.stats.maxhp - self.sv.saved.stats.hp, FastHpRecovery )
					local foodSpend = math.min( recoverableHp * FastFoodCostPerHpRecovery, math.max( self.sv.saved.stats.food - FastFoodRecoveryThreshold, 0 ) )
					local recoveredHp = foodSpend / FastFoodCostPerHpRecovery

					self.sv.saved.stats.hp = math.min( self.sv.saved.stats.hp + recoveredHp, self.sv.saved.stats.maxhp )
					self.sv.saved.stats.food = self.sv.saved.stats.food - foodSpend
					fastRecoveryFraction = ( recoveredHp ) / FastHpRecovery
				end

				-- Normal recovery
				local recoverableHp = math.min( self.sv.saved.stats.maxhp - self.sv.saved.stats.hp, HpRecovery * ( 1 - fastRecoveryFraction ) )
				local foodSpend = math.min( recoverableHp * FoodCostPerHpRecovery, math.max( self.sv.saved.stats.food - FoodRecoveryThreshold, 0 ) )
				local recoveredHp = foodSpend / FoodCostPerHpRecovery

				self.sv.saved.stats.hp = math.min( self.sv.saved.stats.hp + recoveredHp, self.sv.saved.stats.maxhp )
				self.sv.saved.stats.food = self.sv.saved.stats.food - foodSpend
			end

			-- Spend water and food on stamina usage
			self.sv.saved.stats.water = math.max( self.sv.saved.stats.water - self.sv.staminaSpend * WaterCostPerStamina, 0 )
			self.sv.saved.stats.food = math.max( self.sv.saved.stats.food - self.sv.staminaSpend * FoodCostPerStamina, 0 )
			self.sv.staminaSpend = 0

			-- Decrease food and water with time
			self.sv.saved.stats.food = math.max( self.sv.saved.stats.food - FoodLostPerSecond, 0 )
			self.sv.saved.stats.water = math.max( self.sv.saved.stats.water - WaterLostPerSecond, 0 )

			local fatigueDamageFromHp = false
			if self.sv.saved.stats.food <= 0 then
				self:sv_takeDamage( FatigueDamageHp, "fatigue" )
				fatigueDamageFromHp = true
			end
			if self.sv.saved.stats.water <= 0 then
				if not fatigueDamageFromHp then
					self:sv_takeDamage( FatigueDamageWater, "fatigue" )
				end
			end

			self.storage:save( self.sv.saved )
			self.network:setClientData( self.sv.saved )
		end
	end
end

function SurvivalPlayer.server_onInventoryChanges( self, container, changes )
	QuestManager.Sv_OnEvent( QuestEvent.InventoryChanges, { container = container, changes = changes } )

	local obj_interactive_builderguide = sm.uuid.new( "e83a22c5-8783-413f-a199-46bc30ca8dac" )
	if not g_survivalDev then
		if FindInventoryChange( changes, obj_interactive_builderguide ) > 0 then
			self.network:sendToClient( self.player, "cl_n_onMessage", { message = "#{ALERT_BUILDERGUIDE_NOT_ON_LIFT}", displayTime = 3 } )
			QuestManager.Sv_TryActivateQuest( "quest_builder_guide" )
		end
		--if FindInventoryChange( changes, blk_scrapwood ) > 0 then
		--	QuestManager.Sv_TryActivateQuest( "quest_acquire_test" )
		--end
	end
end

function SurvivalPlayer.sv_e_staminaSpend( self, stamina )
	if not g_godMode then
		if stamina > 0 then
			self.sv.staminaSpend = self.sv.staminaSpend + stamina
		end
	end
end

function SurvivalPlayer.sv_takeDamage( self, damage, source )
	if damage > 0 then
		damage = damage * GetDifficultySettings().playerTakeDamageMultiplier
		local character = self.player:getCharacter()
		local lockingInteractable = character:getLockingInteractable()
		if lockingInteractable and lockingInteractable:hasSeat() then
			lockingInteractable:setSeatCharacter( character )
		end

		if not g_godMode and self.sv.damageCooldown:done() then
			if self.sv.saved.isConscious then
				self.sv.saved.stats.hp = math.max( self.sv.saved.stats.hp - damage, 0 )

				print( "'SurvivalPlayer' took:", damage, "damage.", self.sv.saved.stats.hp, "/", self.sv.saved.stats.maxhp, "HP" )

				if source then
					self.network:sendToClients( "cl_n_onEvent", { event = source, pos = character:getWorldPosition(), damage = damage * 0.01 } )
				else
					self.player:sendCharacterEvent( "hit" )
				end

				if self.sv.saved.stats.hp <= 0 then
					print( "'SurvivalPlayer' knocked out!" )
					self.sv.respawnInteractionAttempted = false
					self.sv.saved.isConscious = false
					character:setTumbling( true )
					character:setDowned( true )
				end

				self.storage:save( self.sv.saved )
				self.network:setClientData( self.sv.saved )
			end
		else
			print( "'SurvivalPlayer' resisted", damage, "damage" )
		end
	end
end

function SurvivalPlayer.sv_n_revive( self )
	local character = self.player:getCharacter()
	if not self.sv.saved.isConscious and self.sv.saved.hasRevivalItem and not self.sv.spawnparams.respawn then
		print( "SurvivalPlayer", self.player.id, "revived" )
		self.sv.saved.stats.hp = self.sv.saved.stats.maxhp
		self.sv.saved.stats.food = self.sv.saved.stats.maxfood
		self.sv.saved.stats.water = self.sv.saved.stats.maxwater
		self.sv.saved.isConscious = true
		self.sv.saved.hasRevivalItem = false
		self.storage:save( self.sv.saved )
		self.network:setClientData( self.sv.saved )
		self.network:sendToClient( self.player, "cl_n_onEffect", { name = "Eat - EatFinish", host = self.player.character } )
		if character then
			character:setTumbling( false )
			character:setDowned( false )
		end
		self.sv.damageCooldown:start( 40 )
		self.player:sendCharacterEvent( "revive" )
	end
end

function SurvivalPlayer.sv_e_respawn( self )
	if self.sv.spawnparams.respawn then
		if not self.sv.respawnTimeoutTimer then
			self.sv.respawnTimeoutTimer = Timer()
			self.sv.respawnTimeoutTimer:start( RespawnTimeout )
		end
		return
	end
	if not self.sv.saved.isConscious then
		g_respawnManager:sv_performItemLoss( self.player )
		self.sv.spawnparams.respawn = true

		sm.event.sendToGame( "sv_e_respawn", { player = self.player } )
	else
		print( "SurvivalPlayer must be unconscious to respawn" )
	end
end

function SurvivalPlayer.sv_n_tryRespawn( self )
	if not self.sv.saved.isConscious and not self.sv.respawnDelayTimer and not self.sv.respawnInteractionAttempted then
		self.sv.respawnInteractionAttempted = true
		self.sv.respawnEndTimer = nil;
		self.network:sendToClient( self.player, "cl_n_startFadeToBlack", { duration = RespawnFadeDuration, timeout = RespawnFadeTimeout } )
		
		self.sv.respawnDelayTimer = Timer()
		self.sv.respawnDelayTimer:start( RespawnDelay )
	end
end

function SurvivalPlayer.sv_e_onSpawnCharacter( self )
	if self.sv.saved.isNewPlayer then
		-- Intro cutscene for new player
		if not g_survivalDev then
			--self:sv_e_startLocalCutscene( "camera_approach_crash" )
		end
	elseif self.sv.spawnparams.respawn then
		local playerBed = g_respawnManager:sv_getPlayerBed( self.player )
		if playerBed and playerBed.shape and sm.exists( playerBed.shape ) and playerBed.shape.body:getWorld() == self.player.character:getWorld() then
			-- Attempt to seat the respawned character in a bed
			self.network:sendToClient( self.player, "cl_seatCharacter", { shape = playerBed.shape  } )
		else
			-- Respawned without a bed
			--self:sv_e_startLocalCutscene( "camera_wakeup_ground" )
		end

		self.sv.respawnEndTimer = Timer()
		self.sv.respawnEndTimer:start( RespawnEndDelay )
	
	end

	if self.sv.saved.isNewPlayer or self.sv.spawnparams.respawn then
		print( "SurvivalPlayer", self.player.id, "spawned" )
		if self.sv.saved.isNewPlayer then
			self.sv.saved.stats.hp = self.sv.saved.stats.maxhp
			self.sv.saved.stats.food = self.sv.saved.stats.maxfood
			self.sv.saved.stats.water = self.sv.saved.stats.maxwater
		else
			self.sv.saved.stats.hp = 30
			self.sv.saved.stats.food = 30
			self.sv.saved.stats.water = 30
		end
		self.sv.saved.isConscious = true
		self.sv.saved.hasRevivalItem = false
		self.sv.saved.isNewPlayer = false
		self.storage:save( self.sv.saved )
		self.network:setClientData( self.sv.saved )

		self.player.character:setTumbling( false )
		self.player.character:setDowned( false )
		self.sv.damageCooldown:start( 40 )
	else
		-- SurvivalPlayer rejoined the game
		if self.sv.saved.stats.hp <= 0 or not self.sv.saved.isConscious then
			self.player.character:setTumbling( true )
			self.player.character:setDowned( true )
		end
	end

	self.sv.respawnInteractionAttempted = false
	self.sv.respawnDelayTimer = nil
	self.sv.respawnTimeoutTimer = nil
	self.sv.spawnparams = {}

	sm.event.sendToGame( "sv_e_onSpawnPlayerCharacter", self.player )
end

function SurvivalPlayer.cl_seatCharacter( self, params )
	if sm.exists( params.shape ) then
		params.shape.interactable:setSeatCharacter( self.player.character )
	end
end

function SurvivalPlayer.sv_e_debug( self, params )
	if params.hp then
		self.sv.saved.stats.hp = params.hp
	end
	if params.water then
		self.sv.saved.stats.water = params.water
	end
	if params.food then
		self.sv.saved.stats.food = params.food
	end
	self.storage:save( self.sv.saved )
	self.network:setClientData( self.sv.saved )
end

function SurvivalPlayer.sv_e_eat( self, edibleParams )
	if edibleParams.hpGain then
		self:sv_restoreHealth( edibleParams.hpGain )
	end
	if edibleParams.foodGain then
		self:sv_restoreFood( edibleParams.foodGain )

		self.network:sendToClient( self.player, "cl_n_onEffect", { name = "Eat - EatFinish", host = self.player.character } )
	end
	if edibleParams.waterGain then
		self:sv_restoreWater( edibleParams.waterGain )
		-- self.network:sendToClient( self.player, "cl_n_onEffect", { name = "Eat - DrinkFinish", host = self.player.character } )
	end
	self.storage:save( self.sv.saved )
	self.network:setClientData( self.sv.saved )
end

function SurvivalPlayer.sv_e_feed( self, params )
	if not self.sv.saved.isConscious and not self.sv.saved.hasRevivalItem then
		if sm.container.beginTransaction() then
			sm.container.spend( params.playerInventory, params.foodUuid, 1, true )
			if sm.container.endTransaction() then
				self.sv.saved.hasRevivalItem = true
				self.player:sendCharacterEvent( "baguette" )
				self.network:setClientData( self.sv.saved )
			end
		end
	end
end

function SurvivalPlayer.sv_restoreHealth( self, health )
	if self.sv.saved.isConscious then
		self.sv.saved.stats.hp = self.sv.saved.stats.hp + health
		self.sv.saved.stats.hp = math.min( self.sv.saved.stats.hp, self.sv.saved.stats.maxhp )
		print( "'SurvivalPlayer' restored:", health, "health.", self.sv.saved.stats.hp, "/", self.sv.saved.stats.maxhp, "HP" )
	end
end

function SurvivalPlayer.sv_restoreFood( self, food )
	if self.sv.saved.isConscious then
		food = food * ( 0.8 + ( self.sv.saved.stats.maxfood - self.sv.saved.stats.food ) / self.sv.saved.stats.maxfood * 0.2 )
		self.sv.saved.stats.food = self.sv.saved.stats.food + food
		self.sv.saved.stats.food = math.min( self.sv.saved.stats.food, self.sv.saved.stats.maxfood )
		print( "'SurvivalPlayer' restored:", food, "food.", self.sv.saved.stats.food, "/", self.sv.saved.stats.maxfood, "FOOD" )
	end
end

function SurvivalPlayer.sv_restoreWater( self, water )
	if self.sv.saved.isConscious then
		water = water * ( 0.8 + ( self.sv.saved.stats.maxwater - self.sv.saved.stats.water ) / self.sv.saved.stats.maxwater * 0.2 )
		self.sv.saved.stats.water = self.sv.saved.stats.water + water
		self.sv.saved.stats.water = math.min( self.sv.saved.stats.water, self.sv.saved.stats.maxwater )
		print( "'SurvivalPlayer' restored:", water, "water.", self.sv.saved.stats.water, "/", self.sv.saved.stats.maxwater, "WATER" )
	end
end

function SurvivalPlayer.server_onShapeRemoved( self, removedShapes )
	local numParts = 0
	local numBlocks = 0
	local numJoints = 0



	for _, removedShapeType in ipairs( removedShapes ) do
		if removedShapeType.type == "block"  then
			numBlocks = numBlocks + removedShapeType.amount
		elseif removedShapeType.type == "part"  then
			numParts = numParts + removedShapeType.amount
		elseif removedShapeType.type == "joint"  then
			numJoints = numJoints + removedShapeType.amount




		end
	end

	local staminaSpend = numParts + numJoints + math.sqrt( numBlocks )
	--self:sv_e_staminaSpend( staminaSpend )
end


-- Camera
function SurvivalPlayer.cl_updateCamera( self, dt )
	if self.cl.cutsceneEffect then

		local cutscenePos = self.cl.cutsceneEffect:getCameraPosition()
		local cutsceneRotation = self.cl.cutsceneEffect:getCameraRotation()
		local cutsceneFOV = self.cl.cutsceneEffect:getCameraFov()
		if cutscenePos == nil then cutscenePos = sm.camera.getPosition() end
		if cutsceneRotation == nil then cutsceneRotation = sm.camera.getRotation() end
		if cutsceneFOV == nil then cutsceneFOV = sm.camera.getFov() end

		if self.cl.cutsceneEffect:isPlaying() then
			self.cl.followCutscene = math.min( self.cl.followCutscene + dt / CUTSCENE_FADE_IN_TIME, 1.0 )
		else
			self.cl.followCutscene = math.max( self.cl.followCutscene - dt / CUTSCENE_FADE_OUT_TIME, 0.0 )
		end

		local lerpedCameraPosition = sm.vec3.lerp( sm.camera.getDefaultPosition(), cutscenePos, self.cl.followCutscene )
		local lerpedCameraRotation = sm.quat.slerp( sm.camera.getDefaultRotation(), cutsceneRotation, self.cl.followCutscene )
		local lerpedCameraFOV = lerp( sm.camera.getDefaultFov(), cutsceneFOV, self.cl.followCutscene )
		print(self.cl.followCutscene)
		sm.camera.setPosition( lerpedCameraPosition )
		sm.camera.setRotation( lerpedCameraRotation )
		sm.camera.setFov( lerpedCameraFOV )

		if self.cl.followCutscene <= 0.0 and not self.cl.cutsceneEffect:isPlaying() then
			sm.gui.hideGui( false )
			sm.camera.setCameraState( sm.camera.state.default )
			--sm.localPlayer.setLockedControls( false )
			self.cl.cutsceneEffect:destroy()
			self.cl.cutsceneEffect = nil
		end
	else
		self.cl.followCutscene = 0.0
	end
end

function SurvivalPlayer.cl_startCutscene( self, params )
	self.cl.cutsceneEffect = sm.effect.createEffect( params.effectName )
	if params.worldPosition then
		self.cl.cutsceneEffect:setPosition( params.worldPosition )
	end
	if params.worldRotation then
		self.cl.cutsceneEffect:setRotation( params.worldRotation )
	end
	self.cl.cutsceneEffect:start()
	sm.gui.hideGui( true )
	sm.camera.setCameraState( sm.camera.state.cutsceneTP )
	--sm.localPlayer.setLockedControls( true )

	--local camPos = self.cl.cutsceneEffect:getCameraPosition()
	--local camDir = self.cl.cutsceneEffect:getCameraDirection()
	--if camPos and camDir then
	--	sm.camera.setPosition( camPos )
	--	if camDir:length() > FLT_EPSILON then
	--		sm.camera.setDirection( camDir )
	--	end
	--end
end

function SurvivalPlayer.sv_e_startCutscene( self, params )
	self.network:sendToClient( self.player, "cl_startCutscene", params )
end

function SurvivalPlayer.client_onCancel( self )
	BasePlayer.client_onCancel( self )
	g_effectManager:cl_cancelAllCinematics()
end

--[[
function SurvivalPlayer.cl_updateCamera( self, dt )

	if self.useCutsceneCamera then
		local cameraPath = self.currentCutscene.cameraPath
		local cameraAttached = self.currentCutscene.cameraAttached
		if #cameraPath > 1 then
			if cameraPath[self.nodeIndex+1] then
				local prevNode = cameraPath[self.nodeIndex]
				local nextNode = cameraPath[self.nodeIndex+1]

				local prevPosition = prevNode.position
				local nextPosition = nextNode.position
				local prevDirection = prevNode.direction
				local nextDirection = nextNode.direction

				if prevNode.type == "playerSpace" then
					prevPosition = sm.camera.getDefaultPosition()
				end
				if nextNode.type == "playerSpace" then
					nextPosition = nextNode.position + sm.camera.getDefaultPosition()
					-- Set player to look in the same direction as the player node
					if cameraPath[self.nodeIndex].direction then
						sm.localPlayer.setDirection( cameraPath[self.nodeIndex+1].direction )
					end
				end

				if nextNode.lerpTime > 0 then
					self.progress = self.progress + dt / nextNode.lerpTime
				else
					self.progress = 1
				end

				if self.progress >= 1 then

					-- Trigger events in the next node
					if nextNode.events then
						for _, eventParams in pairs( nextNode.events ) do
							if eventParams.type == "character" then
								eventParams.character = self.player.character
							end
							self.network:sendToServer( "sv_onEvent", eventParams )
						end
					end

					self.nodeIndex = self.nodeIndex + 1
					local upcomingNextNode = cameraPath[self.nodeIndex+1]
					if upcomingNextNode then
						self.progress = ( self.progress - 1.0 ) * nextNode.lerpTime / upcomingNextNode.lerpTime
						self.progress = math.max( math.min( self.progress, 1.0 ), 0 )
						prevPosition = nextNode.position
						nextPosition = upcomingNextNode.position
						prevDirection = nextNode.direction
						nextDirection = upcomingNextNode.direction
						if nextNode.type == "playerSpace" then
							prevPosition = sm.camera.getDefaultPosition()
						end
						if upcomingNextNode.type == "playerSpace" then
							nextPosition = nextPosition +  sm.camera.getDefaultPosition()
							-- Set player to look in the same direction as the player node
							if cameraPath[self.nodeIndex].direction then
								sm.localPlayer.setDirection( cameraPath[self.nodeIndex+1].direction )
							end
						end
					else
						--Finished the cutscene
						self.progress = 0
						self.nodeIndex = 1
						if self.currentCutscene.nextCutscene then
							self:cl_startCutscene( camera_cutscenes[self.currentCutscene.nextCutscene] )
						else
							self.useCutsceneCamera = false
							sm.gui.hideGui( false )
							sm.camera.setCameraState( sm.camera.state.default )
							sm.localPlayer.setLockedControls( false )
						end
					end
				end

				local camPos = sm.vec3.lerp( prevPosition, nextPosition, self.progress )
				local camDir = sm.vec3.lerp( prevDirection, nextDirection, self.progress )

				sm.camera.setPosition( camPos )
				sm.camera.setDirection( camDir )
			end
		elseif cameraAttached then

			if self.progress >= 1 then
				--Finished the cutscene
				self.progress = 0
				self.nodeIndex = 1
				if self.currentCutscene.nextCutscene then
					self:cl_startCutscene( camera_cutscenes[self.currentCutscene.nextCutscene] )
				else
					self.useCutsceneCamera = false
					sm.gui.hideGui( false )
					sm.camera.setCameraState( sm.camera.state.default )
					sm.localPlayer.setLockedControls( false )
				end
			else
				local character = self.player:getCharacter()
				if character then
					sm.camera.setCameraState( sm.camera.state.cutsceneFP )
					local camPos = character:getTpBonePos( cameraAttached.jointName )
					local camDir = character:getTpBoneRot( cameraAttached.jointName ) * cameraAttached.initialDirection

					sm.camera.setPosition( camPos )
					sm.camera.setDirection( camDir )
				end
			end
			self.progress = self.progress + dt / cameraAttached.attachTime

		else
			self:cl_startCutscene( nil )
		end
	end

end


function SurvivalPlayer.cl_startCutscene( self, cutsceneInfo )
	if cutsceneInfo then
		self.useCutsceneCamera = true
		sm.gui.hideGui( true )
		sm.camera.setCameraState( cutsceneInfo.cameraState )
		if cutsceneInfo.cameraPullback then
			sm.camera.setCameraPullback( cutsceneInfo.cameraPullback.standing, cutsceneInfo.cameraPullback.seated )
		end

		sm.localPlayer.setLockedControls( true )

		if self.useCutsceneCamera then
			-- Set camera nodes to follow
			self.currentCutscene = {}
			self.currentCutscene.cameraAttached = cutsceneInfo.attached
			local cameraPath = {}
			local characterPosition = sm.vec3.new( 0, 0, 0 )
			local characterDirection = sm.vec3.new( 0, 1, 0 )
			local character = self.player.character
			if character then
				characterPosition = character.worldPosition + sm.vec3.new( 0, 0, character:getHeight() * 0.5 )
				characterDirection = character:getDirection()
			else
				characterPosition = sm.localPlayer.getRaycastStart()
				characterDirection = sm.localPlayer.getDirection()
			end

			-- Get character heading
			characterDirection.z = 0
			if characterDirection:length() >= FLT_EPSILON then
				characterDirection = characterDirection:normalize()
			else
				characterDirection = sm.vec3.new( 0, 1, 0 )
			end

			-- Prepare a world direction and positon for each camera node
			if cutsceneInfo.nodes then
				for _, node in pairs( cutsceneInfo.nodes ) do
					local updatedNode = {}
					if node.type == "localSpace" then
						local right = characterDirection:cross( sm.vec3.new( 0, 0, 1 ) )
						local pitchedDirection = sm.vec3.rotate( characterDirection, math.rad( node.pitch ), right )
						updatedNode.direction = sm.vec3.rotateZ( pitchedDirection, -math.rad( node.yaw ) )
						updatedNode.position = characterPosition + sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), characterDirection ) * node.position
					elseif node.type == "playerSpace" then
						local right = sm.localPlayer.getDirection():cross( sm.vec3.new( 0, 0, 1 ) )
						local pitchedDirection = sm.vec3.rotate( sm.localPlayer.getDirection(), math.rad( node.pitch ), right )
						updatedNode.direction = sm.vec3.rotateZ( pitchedDirection, -math.rad( node.yaw ) )

						--updatedNode.position = sm.camera.getDefaultPosition() + sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.localPlayer.getDirection() ) * node.position
						updatedNode.position = sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.localPlayer.getDirection() ) * node.position
					else
						updatedNode.position = node.position
						updatedNode.direction = node.direction
					end
					updatedNode.type = node.type
					updatedNode.lerpTime = node.lerpTime
					updatedNode.events = node.events
					cameraPath[#cameraPath+1] = updatedNode
				end
			end

			if #cameraPath > 0 then
				-- Trigger events in the first node
				if cameraPath[1] then
					if cameraPath[1].events then
						for _, eventParams in pairs( cameraPath[1].events ) do
							if eventParams.type == "character" then
								eventParams.character = self.player.character
							end
							self.network:sendToServer( "sv_onEvent", eventParams )
						end
					end
				end
			elseif self.currentCutscene.cameraAttached then
				-- Trigger events
				if self.currentCutscene.cameraAttached.events then
					for _, eventParams in pairs( self.currentCutscene.cameraAttached.events ) do
						if eventParams.type == "character" then
							eventParams.character = self.player.character
						end
						self.network:sendToServer( "sv_onEvent", eventParams )
					end
				end
			end

			self.currentCutscene.cameraPath = cameraPath
			self.currentCutscene.nextCutscene = cutsceneInfo.nextCutscene
			self.currentCutscene.canSkip = cutsceneInfo.canSkip
		end
	else
		self.useCutsceneCamera = false
		sm.gui.hideGui( false )
		sm.camera.setCameraState( sm.camera.state.default )
		sm.localPlayer.setLockedControls( false )
		self.progress = 0
		self.nodeIndex = 1
	end
end

function SurvivalPlayer.cl_startLocalCutscene( self, params )
	if params.player == sm.localPlayer.getPlayer() then
		self:cl_startCutscene( camera_cutscenes[params.cutsceneInfoName] )
	end
end

function SurvivalPlayer.sv_e_startLocalCutscene( self, cutsceneInfoName )
	local params = { player = self.player, cutsceneInfoName = cutsceneInfoName }
	self.network:sendToClients( "cl_startLocalCutscene", params )
end

function SurvivalPlayer.client_onCancel( self )

	if self.useCutsceneCamera and self.currentCutscene.canSkip then
		if self.currentCutscene.nextCutscene then
			self:cl_startCutscene( camera_cutscenes[self.currentCutscene.nextCutscene] )
		else
			self.useCutsceneCamera = false
			sm.gui.hideGui( false )
			sm.camera.setCameraState( sm.camera.state.default )
			sm.localPlayer.setLockedControls( false )
			self.progress = 0
			self.nodeIndex = 1
		end
	end
	
end
]]