local medibeams = {}

function medigunTick()
	for medigunhandle, botentity in pairs(medibeams) do
		local medigun = Entity(medigunhandle)
		local player = medigun.m_hOwner
		medigun.m_hHealingTarget = botentity --keep beam force attached
		
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
		elseif medigun.m_bAttacking == 0 or medigun.m_bHolstered == 1 or player:InCond(TF_COND_TAUNTING) == 1 then
			ResetMedigun(medigun, medigunhandle)
		end
	end
end

local chargeDeployedCallback = AddEventCallback("player_chargedeployed", function(eventTable)
	local medic = ents.GetPlayerByUserId(eventTable.userid)
	local target = ents.GetPlayerByUserId(eventTable.targetid)
	local medigun = medic:GetPlayerItemBySlot(1)
	
	if medigun:GetItemName() == "The Vaccinator" and target.m_iTeamNum == 3 then
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
	local isQuickFix = 0
	local name = activator:GetPlayerName()
	local DAMAGE_PER_HIT = damage --30

	if medigun:GetItemName() == "The Quick-Fix" then
		isQuickFix = true
	else
		isQuickFix = false
	end
	
	print(activator:GetPlayerName() .. " bought")
	RemoveMedibeamCallbacks(activator) --might not be necesary
	
	activator:AddCallback(ON_EQUIP_ITEM, function(_, item)
		--remove previous medigun handle if new medigun
		if item:GetClassname() == "tf_weapon_medigun" and item ~= medigun then
			--print("weapon swap")
			RemoveMedibeamCallbacks(activator)
			if timers[name] then --healing a friendly
				timer.Stop(timers[name])
				timers[name] = nil
			else 
		end
	end)
	
	activator:AddCallback(ON_REMOVE, function()
		--player disconnect
		medibeams[medigunhandle] = nil
		if timers[activator:GetPlayerName()] then
			timer.Stop(timers[name])
			timers[name] = nil
		end
	end)
	
	-- local player_healedcallback = AddEventCallback("player_healed", function(eventTable)
		-- print("player_healed")
		-- --for k, v in pairs(eventTable) do
		-- --	print(k .. " " .. v)
		-- --end
	-- end)
	
	activator:AddCallback(ON_KEY_PRESSED, function(_, key)
		if medigun.m_bHolstered == 0 and key == IN_ATTACK then
			local targetedEntity = 0
			
			if timers[medigunhandle] then --reset the damage timer if it was already ticking
				timer.Stop(timers[medigunhandle])
				timers[medigunhandle] = nil
			end
						
			--if medibeams[medigunhandle] ~= nil then --if we were already connected to bot (click to heal), disconnect before doing anything else
				ResetMedigun(medigun, medigunhandle)
			--end
			
			-- for _, player in pairs(ents.GetAllPlayers()) do
				-- if player.m_iTeamNum == 2 then
					-- print(player:GetPlayerName())
					-- for i = 1, #player.m_ConditionData do --length of condition data
						-- if player.m_ConditionData[i] ~= nil then
							-- print(player.m_ConditionData[i])
						-- end
					-- end
				-- end
			-- end
			
			if medigun.m_hHealingTarget then
				--if real player, let game do its thing
			else
				targetedEntity = EyeTrace(activator, connectTrace) --initial trace on click
			
				if targetedEntity and targetedEntity:IsPlayer() and targetedEntity.m_iTeamNum == 3 then
					ConnectMedigun(activator, isQuickFix, DAMAGE_PER_HIT, medigun, medigunhandle, targetedEntity)	
				else --if trace doesn't hit, start hold timer
				
					timers[name] = timer.Create(.1, function() --run a trace every .1s until we hit something or key is released
						print("hold timer")
						if medigun.m_bHolstered == 0 and activator.m_bRageDraining == 0 then --if shield not draining						
							if medigun.m_hHealingTarget then --healing a friendly
								timer.Stop(timers[name])
								timers[name] = nil
							else 
								targetedEntity = EyeTrace(activator, connectTrace)
							
								if targetedEntity and targetedEntity:IsPlayer() and targetedEntity.m_iTeamNum == 3 then 
									--hit a blu bot
									timer.Stop(timers[name])
									timers[name] = nil
									ConnectMedigun(activator, isQuickFix, DAMAGE_PER_HIT, medigun, medigunhandle, targetedEntity)
								end
							end
						else --if shield is draining or medigun is holstered, stop looking for a target
							timer.Stop(timers[name])
							timers[name] = nil
						end
					end, 0)
				end
			end
		end
		
		if key == IN_RELOAD and medigun.m_bHolstered == 0 then
			if medigun:GetItemName() == "The Vaccinator" and medibeams[medigunhandle] then
			--if vacc, remove the passive effect on bot
			--chargeresisttype is 0-2
				medibeams[medigunhandle]:RemoveCond(TF_COND_MEDIGUN_SMALL_BULLET_RESIST + medigun.m_nChargeResistType)
			end
		end
	end)
	
	activator:AddCallback(ON_KEY_RELEASED, function(_, key)
		if key == IN_ATTACK then
			if timers[name] then --if hold timer was still running, stop it
				timer.Stop(timers[name])
				timers[name] = nil
			end
		end
	end)
end

function EyeTrace(player, connectTrace) --trace from player's eyes to something in range 
	local tracetable = {}
	local filterEnts = ents.FindAllByClass("entity_medigun_shield") 
	table.insert(filterEnts, player) --need to filter out player if using filter
	
	local function getEyeAngles(player) --from royal, gets accurate eye angles
		local pitch = player["m_angEyeAngles[0]"]
		local yaw = player["m_angEyeAngles[1]"]

		return Vector(pitch, yaw, 0)
	end
	
	connectTrace.filter = filterEnts
	connectTrace.angles = getEyeAngles(player)
	--print("--")
	
	--print("healing " .. tostring(medigun.m_hHealingTarget))
	if not util.IsLagCompensationActive() then
		util.StartLagCompensation(player)
		tracetable = util.Trace(connectTrace)
		util.FinishLagCompensation(player)
	end
	
	return tracetable.Entity
	--print("targeted " .. tostring(targetedEntity))
end

function ConnectMedigun(player, isQuickFix, damage, medigun, medigunhandle, targetedEntity)
--print(activator:GetPlayerName() .. " clicked " .. tostring(targetedEntity))
	local ATTRIBUTENAME = "charged airblast"
	local healrate = 1 + medigun:GetAttributeValueByClass("healing_mastery", 0) * .25
	if isQuickFix then --m a g i c n u m b e r s
		healrate = healrate * 1.4
	end

	medigun.m_hLastHealingTarget = nil --no cross team flashing
	medibeams[medigunhandle] = targetedEntity

	timers[medigunhandle] = timer.Create(.25, function()
		local playerorigin = player:GetAbsOrigin()
		local targetorigin = targetedEntity:GetAbsOrigin()
		local dist = playerorigin:Distance(targetorigin)
		
		if dist < 540 and player.m_bRageDraining == 0 then --only damage if player is in range + not shielding
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
			if isQuickFix and medigun.m_bChargeRelease == 1 then
				damageInfo.Damage = damage * healrate * (.75 + .25 * medigun:GetAttributeValue(ATTRIBUTENAME))
			elseif medigun:GetItemName() == "The Kritzkrieg" and medigun.m_bChargeRelease == 1 then
				damageInfo.Damage = damage * 2
			end
			targetedEntity:TakeDamage(damageInfo)
		else
			ResetMedigun(medigun, medigunhandle) --need to force disconnect here due to hold to heal
		end
	end, 0)
end

function ResetMedigun(medigun, medigunhandle) --reset medigun to defaultish state once we lose target
	medibeams[medigunhandle] = nil
	medigun.m_hHealingTarget = nil
	medigun.m_hLastHealingTarget = nil --might not be necessary
	if timers[medigunhandle] then
		timer.Stop(timers[medigunhandle])
		timers[medigunhandle] = nil
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