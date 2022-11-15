local medibeams = {}

-- function medigunTick()
	-- for medigunhandle, botentity in pairs(medibeams) do
		-- local medigun = Entity(medigunhandle)
		-- local player = medigun.m_hOwner

		-- --medigun.m_hHealingTarget = botentity --keep beam force attached
	
		-- if player.m_bUsingActionSlot == 1 and medigun:GetAttributeValue("canteen specialist") then
		-- --if player presses h and has can spec while healing a bot, remove cond on bot
			-- botentity:RemoveCond(TF_COND_INVULNERABLE_USER_BUFF)
			-- botentity:RemoveCond(TF_COND_CRITBOOSTED_USER_BUFF)
		-- end
		
		-- if not botentity:IsAlive() then --bot was killed
			-- player:SetAttributeValue("no_attack", 1)
			-- timer.Simple(.1, function()
				-- player:SetAttributeValue("no_attack", nil)
			-- end)
			-- ResetMedigun(medigun, medigunhandle)
		-- elseif not data.isConnected then --in very first tick, m_bHealing is false so can't check it
			-- data.isConnected = true
			-- if medigun.m_bAttacking == 0 or medigun.m_bHolstered == 1 or player:InCond(TF_COND_TAUNTING) == 1 then
				-- ResetMedigun(medigun, medigunhandle)
			-- end
		-- else
			-- if medigun.m_bHealing == 0 or medigun.m_bHolstered == 1 or player:InCond(TF_COND_TAUNTING) == 1 then
				-- ResetMedigun(medigun, medigunhandle)
			-- end
		-- end
	-- end
-- end

--remove vaccinator ubers from bots
local chargeDeployedCallback = AddEventCallback("player_chargedeployed", function(eventTable)
	local medic = ents.GetPlayerByUserId(eventTable.userid)
	local target = ents.GetPlayerByUserId(eventTable.targetid)
	local medigun = medic:GetPlayerItemBySlot(1)
	
	if medigun:GetItemName() == "The Vaccinator" and target and target.m_iTeamNum == 3 then
		timer.Simple(.1, function()
			target:RemoveCond(TF_COND_MEDIGUN_UBER_BULLET_RESIST + medigun.m_nChargeResistType)
		end)
	end
end)

function BoughtMedibeam(damage, activator)
	local connectTrace = {
		start = activator, -- Start position vector. Can also be set to entity, in this case the trace will start from entity eyes position
		endpos = nil, -- End position vector. If nil, the trace will be fired in `angles` direction with `distance` length
		distance = 450, -- Used if endpos is nil
		angles = Vector(0,0,0), -- Used if endpos is nil
		mask = MASK_SOLID, -- Solid type mask, see MASK_* globals
		collisiongroup = TFCOLLISION_GROUP_OBJECT_SOLIDTOPLAYERMOVEMENT, -- Pretend the trace to be fired by an entity belonging to this group. See COLLISION_GROUP_* globals
		mins = Vector(0,0,0), -- Extends the size of the trace in negative direction
		maxs = Vector(0,0,0), -- Extends the size of the trace in positive direction
		filter = filterEnts -- Entity to ignore. Can be a single entity, table of entities, or a function with a single entity parameter
	}

	local handle = activator:GetHandleIndex()
	local medigun = activator:GetPlayerItemBySlot(1)
	local medigunhandle = medigun:GetHandleIndex()
	local isQuickFix = false
	local name = activator:GetPlayerName()
	local DAMAGE_PER_HIT = damage --30

	if medigun:GetItemName() == "The Quick-Fix" then
		isQuickFix = true
	end
	
	print(activator:GetPlayerName() .. " bought")
	RemoveMedibeamCallbacks(activator) --might not be necesary
	
	activator:WeaponSwitchSlot(1)
	
	activator:AddCallback(ON_EQUIP_ITEM, function(_, item)
		--remove previous medigun handle if new medigun
		if item:GetClassname() == "tf_weapon_medigun" and item ~= medigun then
			--print("weapon swap")
			RemoveMedibeamCallbacks(activator)
			if timers[name] then --healing a friendly
				timer.Stop(timers[name])
				timers[name] = nil
			end
		end
	end)
	
	activator:AddCallback(ON_REMOVE, function()
		--player disconnect
		medibeams[medigunhandle] = nil
		if timers[name] then
			timer.Stop(timers[name])
			timers[name] = nil
		end
	end)
	
	activator:AddCallback(ON_KEY_PRESSED, function(_, key)
		if medigun.m_bHolstered == 0 and key == IN_ATTACK then
			print("current time " .. TickCount() .. " pressed")
			local targetedEntity = 0
			
			if timers[medigunhandle] then --reset the damage timer if it was already ticking
				timer.Stop(timers[medigunhandle])
				timers[medigunhandle] = nil
			end
			
			if timers[handle] then
				timer.Stop(timers[handle])
				timers[handle] = nil
			end
						
			-- if medibeams[medigunhandle] then --if we were already connected to bot (click to heal), disconnect before doing anything else
				-- ResetMedigun(medigun, medigunhandle)
				-- print("current time " .. CurTime() .. " " .. TickCount() .. " cleared medigun")
			-- end
			
			if medigun.m_hHealingTarget and medigun.m_hHealingTarget.m_iTeamNum == 2 then
				medibeams[medigunhandle] = nil
				--if real player, let game do its thing
			else
				targetedEntity = EyeTrace(activator, connectTrace) --initial trace on click
			
				if targetedEntity and targetedEntity:IsPlayer() and targetedEntity.m_iTeamNum == 3 then
					ConnectMedigun(activator, isQuickFix, DAMAGE_PER_HIT, medigun, medigunhandle, targetedEntity)	
					
				else --if trace doesn't hit, start hold timer
					if not timers[name] then
						timers[name] = timer.Create(.014, function() --run a trace every .1s until we hit something or key is released
							if medigun.m_bHolstered == 0 and medigun.m_bAttacking == 1 
								and activator.m_bRageDraining == 0 and activator:InCond(TF_COND_TAUNTING) == 0 then
								--print("hold timer")
								
								if medigun.m_hHealingTarget and medigun.m_hHealingTarget.m_iTeamNum == 2 then --healing a friendly
									print(activator:GetPlayerName() .. " " .. TickCount() .. " started healing, stopping tick")
									timer.Stop(timers[name])
									timers[name] = nil
								else 
									local targetedEntity = EyeTrace(activator, connectTrace)
								
									if targetedEntity and targetedEntity:IsPlayer() and targetedEntity.m_iTeamNum == 3 then 
										--hit a blu bot
										print(activator:GetPlayerName() .. " " .. TickCount() .. " started damaging, stopping tick")
										timer.Stop(timers[name])
										timers[name] = nil
										ConnectMedigun(activator, isQuickFix, DAMAGE_PER_HIT, medigun, medigunhandle, targetedEntity)
									end
								end
							else --if shield is draining or medigun is holstered, stop looking for a target
								print(activator:GetPlayerName() .. " " .. TickCount() .. " released, stopping")
								timer.Stop(timers[name])
								timers[name] = nil
							end
						end, 0)
					end
				end
			end
		end
		
		if key == IN_RELOAD and medigun.m_bHolstered == 0 then
			if medigun:GetItemName() == "The Vaccinator" and medibeams[medigunhandle] then
				--if vacc, remove the passive effect on bot
				--chargeresisttype is 0-2
				medibeams[medigunhandle].entity:RemoveCond(TF_COND_MEDIGUN_SMALL_BULLET_RESIST + medigun.m_nChargeResistType)
			end
		end
	end)
	
	-- activator:AddCallback(ON_KEY_RELEASED, function(_, key)
		-- if key == IN_ATTACK then
			-- if timers[name] then --if hold timer was still running, stop it
				-- timer.Stop(timers[name])
				-- timers[name] = nil
			-- end
		-- end
	-- end)
end

function EyeTrace(player, connectTrace, targetedEntity) --trace from player's eyes to something in range 
	local tracetable = {}
	local filterEnts = ents.FindAllByClass("entity_medigun_shield") 
	
	local function getEyeAngles(player) --from royal, gets accurate eye angles
		local pitch = player["m_angEyeAngles[0]"]
		local yaw = player["m_angEyeAngles[1]"]

		return Vector(pitch, yaw, 0)
	end
	
	if targetedEntity then
		for _, p in pairs(ents.GetAllPlayers()) do --if we have a target already and checking connection to it
			if p ~= targetedEntity then --then filter out every player but the targeted bot
				table.insert(filterEnts, p)
			end
		end
		--connectTrace.endpos = targetedEntity:GetAbsOrigin() + Vector(0, 0, 70)
		--70 is avg of eye heights, might be a bit over on short classes and bit under on tall classes
	else
		table.insert(filterEnts, player) --need to filter out player if using filter
	end
	
	connectTrace.filter = filterEnts
	connectTrace.angles = getEyeAngles(player)
	
	if not util.IsLagCompensationActive() then
		util.StartLagCompensation(player)
		tracetable = util.Trace(connectTrace)
		util.FinishLagCompensation(player)
	end
	
	return tracetable.Entity
end

function ConnectMedigun(player, isQuickFix, damage, medigun, medigunhandle, targetedEntity)
	local connectTrace = {
		start = player, -- Start position vector. Can also be set to entity, in this case the trace will start from entity eyes position
		endpos = nil, -- End position vector. If nil, the trace will be fired in `angles` direction with `distance` length
		distance = 540, -- Used if endpos is nil
		angles = Vector(0,0,0), -- Used if endpos is nil
		mask = MASK_SOLID, -- Solid type mask, see MASK_* globals
		collisiongroup = TFCOLLISION_GROUP_OBJECT_SOLIDTOPLAYERMOVEMENT, -- Pretend the trace to be fired by an entity belonging to this group. See COLLISION_GROUP_* globals
		mins = Vector(0,0,0), -- Extends the size of the trace in negative direction
		maxs = Vector(0,0,0), -- Extends the size of the trace in positive direction
		filter = filterEnts -- Entity to ignore. Can be a single entity, table of entities, or a function with a single entity parameter
	}
	local healrate = 1 + medigun:GetAttributeValueByClass("healing_mastery", 0) * .25
	if isQuickFix then --m a g i c n u m b e r s
		healrate = healrate * 1.4
	end
	local damageInfo = {
		Attacker = player,
		Inflictor = nil,
		Weapon = medigun,
		Damage = damage * healrate,
		DamageType = DMG_ENERGYBEAM,
		DamageCustom = TF_DMG_CUSTOM_MERASMUS_ZAP,
		DamagePosition = targetorigin,
		DamageForce = Vector(0, 0, 0),
		ReportedPosition = targetorigin
	}
	local ATTRIBUTENAME = "charged airblast"
	
	print("current time " .. " " .. TickCount() .. " connecting")
	
	medigun.m_hLastHealingTarget = nil --no cross team flashing
	--medibeams[medigunhandle] = targetedEntity
	CheckMedigun(medigunhandle, targetedEntity)
	
	--damage bot every .25s 
	timers[medigunhandle] = timer.Create(.25, function()
		local playerorigin = player:GetAbsOrigin()
		local targetorigin = targetedEntity:GetAbsOrigin()
		local dist = playerorigin:Distance(targetorigin)
		
		if dist < 540 and player.m_bRageDraining == 0 then --only damage if player is in range + not shielding
			local tracedEntity = EyeTrace(player, connectTrace, targetedEntity)
			--print("traced to " .. tostring(tracedEntity) .. ", targeted " .. tostring(targetedEntity))
			
			--if tracedEntity == targetedEntity then --unobstructed view of bot?
				if isQuickFix and medigun.m_bChargeRelease == 1 then
					damageInfo.Damage = damage * healrate * (.75 + .25 * medigun:GetAttributeValue(ATTRIBUTENAME))
				elseif medigun:GetItemName() == "The Kritzkrieg" and medigun.m_bChargeRelease == 1 then
					damageInfo.Damage = damage * 2
				end
				targetedEntity:TakeDamage(damageInfo)
			--else
			--	ResetMedigun(medigun, medigunhandle) --otherwise disconnect
			--end
		else
			ResetMedigun(medigun, medigunhandle) --need to force disconnect here due to hold to heal
		end
	end, 0)
end

--check if medigun should still be attached to bot
function CheckMedigun(medigunhandle, botentity)
	local medigun = Entity(medigunhandle)
	local player = medigun.m_hOwner
	local handle = player:GetHandleIndex()

	medigun.m_hHealingTarget = botentity
	
	timers[handle] = timer.Create(.014, function()
		print("current time " .. TickCount() .. " check timer")
	
		if player.m_bUsingActionSlot == 1 and medigun:GetAttributeValue("canteen specialist") then
		--if player presses h and has can spec while healing a bot, remove cond on bot
			botentity:RemoveCond(TF_COND_INVULNERABLE_USER_BUFF)
			botentity:RemoveCond(TF_COND_CRITBOOSTED_USER_BUFF)
		end
		
		if not botentity:IsAlive() then --bot was killed
			ResetMedigun(medigun, medigunhandle)
			player:SetAttributeValue("no_attack", 1)
			timer.Simple(.1, function()
				player:SetAttributeValue("no_attack", nil)
			end)
		--elseif firstTick then --in very first tick, m_bHealing is false so can't check it
		elseif medigun.m_bHealing == 0 or medigun.m_bHolstered == 1 or player:InCond(TF_COND_TAUNTING) == 1 then
			ResetMedigun(medigun, medigunhandle)
		elseif medigun.m_hHealingTarget ~= botentity then
			print("target mismatch, stopping")
			if timers[medigunhandle] then
				timer.Stop(timers[medigunhandle])
				timers[medigunhandle] = nil
			end
			if timers[handle] then
				timer.Stop(timers[handle])
				timers[handle] = nil
			end
		end
		
		medigun.m_hHealingTarget = botentity --keep beam force attached
	end, 0)
end

--reset medigun to defaultish state once we lose target
function ResetMedigun(medigun, medigunhandle)
	local player = medigun.m_hOwner
	medibeams[medigunhandle] = nil
	medigun.m_hHealingTarget = nil
	medigun.m_hLastHealingTarget = nil --might not be necessary
	medigun.m_bAttacking = 0
	if timers[medigunhandle] then
		timer.Stop(timers[medigunhandle])
		timers[medigunhandle] = nil
	end
	if timers[player:GetHandleIndex()] then
		timer.Stop(timers[player:GetHandleIndex()])
		timers[player:GetHandleIndex()] = nil
	end
end

--if player refunds upgrade/unequips?
function RefundedMedibeam(_, activator)
	if IsValid(activator) then
		print("refunded")
		local medigun = activator:GetPlayerItemBySlot(1)
		local medigunhandle = medigun:GetHandleIndex()
		ResetMedigun(medigun, medigunhandle)
		RemoveMedibeamCallbacks(activator)
	end
end

function RemoveMedibeamCallbacks(player)
	player:RemoveAllCallbacks(ON_EQUIP_ITEM)
	player:RemoveAllCallbacks(ON_REMOVE)
	player:RemoveAllCallbacks(ON_KEY_PRESSED)
	player:RemoveAllCallbacks(ON_KEY_RELEASED)
end