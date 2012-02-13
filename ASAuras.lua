ASAuras = {}
local auraframes = {}
local testmode = 0
local activeTalentGroup = 0

ASAuras = CreateFrame("Frame", nil, UIParent)
ASAuras:RegisterEvent("ADDON_LOADED")
ASAuras:RegisterEvent("PLAYER_REGEN_DISABLED")
ASAuras:RegisterEvent("PLAYER_REGEN_ENABLED")
ASAuras:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
ASAuras:SetScript("OnEvent", function(self,event, ...)
	ASAuras[event](self, event, ... )
end) 

function ASAuras:ADDON_LOADED(...)
	if (ASAuras_DB == nil) then ASAuras_DB = {}; end 
	SLASH_ASAuras1 = "/aura"
	SlashCmdList["ASAuras"] = function(message)
		ASAuras:Command(message);
	end
	
	activeTalentGroup = GetActiveTalentGroup(false,false)
end

function ASAuras:ACTIVE_TALENT_GROUP_CHANGED(...)
	activeTalentGroup = GetActiveTalentGroup(false,false)
end

function ASAuras:Command(message)
	local command, parameter, target
	if (strfind(message, " ")) then
		command = strlower(strsub(message,1,strfind(message," ")-1))
		parameter = strsub(message,strfind(message," ")+1,strlen(message))
	else
		command = strlower(message)
	end
	if (strfind(command, "test")) then
		if (testmode == 0) then
			print "ASAuras TestMode Started!"
			-- Show all configured Auras so they can be moved
			ASAuras:TestMode()
			testmode = 1
		else
			print "ASAuras TestMode Ended!"
			for index, auraframe in pairs(auraframes) do
				auraframe:Hide()
				auraframe.elapsed = 0
				auraframe:SetScript("OnUpdate", nil )
			end
			testmode = 0
		end
	elseif (strfind(command, "add")) then
		-- Add a new Buff / Debuff
		spellId = tonumber(strsub(parameter,1,strfind(parameter," ")-1))
		target = strsub(parameter,strfind(parameter," ")+1,strlen(parameter))
		spec = strsub(parameter,strfind(parameter," ")+2,strlen(parameter))
		-- TODO Hier stimmt die Parameter Auswertung nicht !!!
		if (ASAuras_DB[spellId]~=nil) then
			-- We already have that in our Database !!!
			print("Spell is already monitored!")
		else
			ASAuras_DB[spellId]={}
			ASAuras_DB[spellId].target=target
			if spec == "mainspec" then
				ASAuras_DB[spellId].spec=1
			elseif spec == "offspec" then
				ASAuras_DB[spellId].spec=2
			else
				ASAuras_DB[spellId].spec=3
			end
			ASAuras_DB[spellId].xOffset=0
			ASAuras_DB[spellId].yOffset=0
			ASAuras_DB[spellId].width = 40
			ASAuras_DB[spellId].height = 40
		end
	elseif (strfind(command, "del")) then
		-- Delete a configured Buff / Debuff
		spellId = tonumber(parameter)
		if (ASAuras_DB[spellId]~=nil) then
			ASAuras_DB[spellId]=nil
		else
			print("This Spell is not monitored!")
		end
	else
		print("ASAuras Usage: /aura")
		print("add <SpellId> <player/target/focus/cd> <mainspec/offspec/both>")
		print("del <SpellId>")
		print("test")
	end
end

function ASAuras:PLAYER_REGEN_DISABLED(...)
	ASAuras:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	ASAuras:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	ASAuras:RegisterEvent("PLAYER_TARGET_CHANGED")
	ASAuras:RegisterEvent("PLAYER_FOCUS_CHANGED")
	ASAuras:SetScript("OnEvent", function(self, event, ...)
		ASAuras[event](self, event, ...)
	end)
	for index, auraframe in pairs(auraframes) do
		if auraframe.target ~= "cd" then
			auraframe:SetScript("OnUpdate", function(self, elapsed)
				ASAuras:UpdateAura(auraframe, elapsed)
			end)
		end
		-- Check if we got the Aura on us and if yes show the frame
		if auraframe.target ~= "cd" and (auraframe.spec == activeTalentGroup or auraframe.spec == 3 ) then
			if UnitAura("player",GetSpellInfo(auraframe.spellId)) then
			auraframe:Show()
			end
		elseif (auraframe.spec == activeTalentGroup or auraframe.spec == 3 ) then
			-- This is a spell CD we watch out for. So display it if it is available
			local start, duration = GetSpellCooldown(auraframe.spellId)
			if start == 0 and duration < 1.5 then
				auraframe:Show()
			end
		end
	end
end


function ASAuras:PLAYER_REGEN_ENABLED(...)
	ASAuras:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	ASAuras:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
	ASAuras:UnregisterEvent("PLAYER_TARGET_CHANGED")
	ASAuras:UnregisterEvent("PLAYER_FOCUS_CHANGED")
	for index, auraframe in pairs(auraframes) do
		auraframe:Hide()
		auraframe.elapsed = 0
		auraframe:SetScript("OnUpdate", nil )
		auraframe.countdown:SetText("")
		auraframe.stacks:SetText("")
	end
end

function ASAuras:SPELL_UPDATE_COOLDOWN(...)
	-- One of our spells is usable again
	-- Loop through all our configured SpellIds
	for spellId, aura in pairs(ASAuras_DB) do
		if aura.target == "cd" then
			local start, duration = GetSpellCooldown(spellId)
			if start > 0 and duration > 1.5 then
				if auraframes[spellId] then
					auraframes[spellId]:Hide()
				end
			else
				if auraframes[spellId] and (aura.spec == activeTalentGroup or aura.spec == 3 ) then
					auraframes[spellId]:Show()
				else
					if aura.spec == activeTalentGroup or aura.spec == 3 then
						ASAuras:CreateFrame(nil,spellId)
					end
				end
			end
		end
	end
end

function ASAuras:PLAYER_TARGET_CHANGED(...)
	for index, auraframe in pairs(auraframes) do
		if auraframe.target == "target" then
			-- Check if we maybe have the debuff on the new target ?
			if UnitDebuff("target",GetSpellInfo(auraframe.spellId),nil,"PLAYER") or UnitBuff("target",GetSpellInfo(auraframe.spellId)) then
				-- Force the update
				auraframe.dstGUID = UnitGUID("target")
				auraframe.elapsed = 0.2
			else
				-- Hide it
				auraframe:Hide()
				auraframe.elapsed = 0
				auraframe:SetScript("OnUpdate", nil)
				auraframe.countdown:SetText("")
				auraframe.stacks:SetText("")
			end
		end
	end
end

function ASAuras:PLAYER_FOCUS_CHANGED(...)
	for index, auraframe in pairs(auraframes) do
		if auraframe.target == "focus" then
			-- Check if we maybe have the debuff on the new target ?
			if UnitDebuff("focus",GetSpellInfo(auraframe.spellId),nil,"PLAYER") or UnitBuff("focus",GetSpellInfo(auraframe.spellId)) then
				-- Force the update
				auraframe.dstGUID = UnitGUID("target")
				auraframe.elapsed = 0.2
			else
				-- Hide it
				auraframe:Hide()
				auraframe.elapsed = 0
				auraframe:SetScript("OnUpdate", nil)
				auraframe.countdown:SetText("")
				auraframe.stacks:SetText("")
			end
		end
	end
end

function ASAuras:COMBAT_LOG_EVENT_UNFILTERED(log_event, timestamp, event, hideCaster, srcGUID, srcName, srcFlags, srcFlags2, dstGUID, dstName, dstFlags, destFlags2, ...)
	if (event=="SPELL_AURA_APPLIED") then
		local spellId, spellName, spellSchool = select(1, ...)
		if ASAuras_DB[spellId] then
			if UnitGUID("player") == dstGUID and ASAuras_DB[spellId].target == "player" then -- Buff or Debuff on the Player
				ASAuras:AuraApplied(dstGUID,spellId)
			elseif UnitGUID("target") == dstGUID and ASAuras_DB[spellId].target == "target" then -- Buff or Debuff on the Target
				ASAuras:AuraApplied(dstGUID,spellId)
			elseif UnitGUID("focus") == dstGUID and ASAuras_DB[spellId].target == "focus" then -- Buff or Debuff on the Focus
				ASAuras:AuraApplied(dstGUID,spellId)
			end
		end
	end
	if (event=="SPELL_AURA_REMOVED") then
		local spellId, spellName, spellSchool = select(1, ...)
		if ASAuras_DB[spellId] and auraframes[spellId] then
			ASAuras:AuraRemoved(dstGUID,spellId)
		end
	end
end

function ASAuras:GetUnitByGUID(guid)
	local unit
	if guid == UnitGUID("target") then
		unit = "target"
	elseif guid == UnitGUID("focus") then
		unit = "focus"
	elseif guid == UnitGUID("player") then
		unit = "player"
	end
	return unit
end

function ASAuras:AuraApplied(dstGUID,spellId)
	if ( auraframes == nil ) then
		if ASAuras_DB[spellId].spec == activeTalentGroup or ASAuras_DB[spellId].spec == 3 then
			ASAuras:CreateFrame(dstGUID,spellId)
		end
	else
		-- Check if there is a frame for that buff already that has just been hidden
		-- If not create it and show it
		if auraframes[spellId] then
			if (auraframes[spellId]:IsVisible() == nil) then
				auraframes[spellId].dstGUID = dstGUID
				auraframes[spellId]:Show()
				auraframes[spellId]:SetSize(ASAuras_DB[spellId].width,ASAuras_DB[spellId].height)
				auraframes[spellId].background:SetSize(ASAuras_DB[spellId].width,ASAuras_DB[spellId].height)
				auraframes[spellId]:SetAlpha(1)
			else
				auraframes[spellId].dstGUID = dstGUID
			end
		else
			if ASAuras_DB[spellId].spec == activeTalentGroup or ASAuras_DB[spellId].spec == 3 then
				ASAuras:CreateFrame(dstGUID,spellId)
			end
		end
	end
	auraframes[spellId]:SetScript("OnUpdate", function(self, elapsed)
		ASAuras:UpdateAura(auraframes[spellId], elapsed)
	end)
end

function ASAuras:AuraRemoved(dstGUID,spellId)
	auraframes[spellId]:Hide()
	auraframes[spellId].elapsed = 0
	auraframes[spellId]:SetScript("OnUpdate", nil)
	auraframes[spellId].countdown:SetText("")
	auraframes[spellId].stacks:SetText("")
	auraframes[spellId]:SetSize(ASAuras_DB[spellId].width,ASAuras_DB[spellId].height)
	auraframes[spellId].background:SetSize(ASAuras_DB[spellId].width,ASAuras_DB[spellId].height)
	auraframes[spellId]:SetAlpha(1)
end

function ASAuras:CreateFrame(dstGUID,spellId)
	local aura = ASAuras_DB[spellId]
	local auraframe = CreateFrame("FRAME","ASAura"..spellId, UIParent)
	local auraframeBG = auraframe:CreateTexture(nil,"BACKGROUND")
	local countdown = auraframe:CreateFontString("$parentText", "ARTWORK", "GameFontNormal")
	local stacks = auraframe:CreateFontString("$parentText", "ARTWORK", "GameFontNormal")
	auraframeBG:SetTexture(select(3, GetSpellInfo(spellId)))
	auraframeBG:SetPoint("CENTER",auraframe,"CENTER")
	auraframeBG:SetHeight(ASAuras_DB[spellId].height)
	auraframeBG:SetWidth(ASAuras_DB[spellId].width)
	auraframe:SetWidth(ASAuras_DB[spellId].width)
	auraframe:SetHeight(ASAuras_DB[spellId].height)
	auraframe:SetPoint("CENTER",UIParent,"CENTER",aura.xOffset,aura.yOffset)
	countdown:SetFont("Fonts\\ARIALN.TTF",12)
	countdown:SetPoint("TOP",auraframe,"BOTTOM",0,-5)
	countdown:SetTextColor(1,1,1,1)
	stacks:SetFont("Fonts\\ARIALN.TTF",15,"OUTLINE")
	stacks:SetPoint("CENTER",auraframe,"CENTER")
	stacks:SetTextColor(1,1,1,1)
	auraframe.countdown = countdown
	auraframe.stacks = stacks
	auraframe.background = auraframeBG
	auraframe.elapsed = 0
	auraframe.spellId = spellId
	auraframe.oldyOffset = 0
	auraframe.oldxOffset = 0
	auraframe.target = ASAuras_DB[spellId].target
	auraframe.dstGUID = dstGUID
	auraframes[spellId] = {}
	auraframes[spellId] = auraframe
	if aura.target == "cd" then
		auraframe.countdown:SetText("")
	end
end

function ASAuras:UpdateAura(auraframe, elapsed)
	auraframe.elapsed = auraframe.elapsed + elapsed
	if ( auraframe.elapsed >= 0.1 ) then
		-- Do something :P
		local timeremaining = 0
		if (testmode==0) then
			local unit = ASAuras:GetUnitByGUID(auraframe.dstGUID)
			if unit ~= nil then
				if UnitDebuff(unit,GetSpellInfo(auraframe.spellId),nil,"PLAYER") then
					timeremaining = select(7,UnitDebuff(unit,GetSpellInfo(auraframe.spellId),nil,"PLAYER")) - GetTime()
					stacks = select(4,UnitDebuff(unit,GetSpellInfo(auraframe.spellId),nil,"PLAYER"))
				elseif UnitDebuff(unit,GetSpellInfo(auraframe.spellId)) then
					timeremaining = select(7,UnitDebuff(unit,GetSpellInfo(auraframe.spellId))) - GetTime()
					stacks = select(4,UnitDebuff(unit,GetSpellInfo(auraframe.spellId)))
				elseif UnitBuff(unit,GetSpellInfo(auraframe.spellId)) then
					timeremaining = select(7,UnitAura(unit,GetSpellInfo(auraframe.spellId))) - GetTime()
					stacks = select(4,UnitAura(unit,GetSpellInfo(auraframe.spellId)))
				end
				auraframe.countdown:SetText(string.format("%.1f",timeremaining))
				if (stacks ~= nil and stacks>0) then
					auraframe.stacks:SetText(string.format("%d",stacks))
				else
					auraframe.stacks:SetText("")
				end
				if auraframe.target ~= "cd" then
					if timeremaining <= 2 then
						auraframe:SetAlpha(1/timeremaining)
						local width, height = auraframe:GetSize()
						auraframe:SetSize(width+5,height+5)
						auraframe.background:SetSize(width+5,height+5)
					elseif auraframe:GetWidth() ~= ASAuras_DB[auraframe.spellId].width then
						auraframe:SetSize(ASAuras_DB[auraframe.spellId].width,ASAuras_DB[auraframe.spellId].height)
						auraframe.background:SetSize(ASAuras_DB[auraframe.spellId].width,ASAuras_DB[auraframe.spellId].height)
						auraframe:SetAlpha(1)
					end
				end
			end
		else
			auraframe.countdown:SetText(string.format("%.1f","100"))
			auraframe.stacks:SetText(string.format("%d","10"))
			auraframe.background:SetHeight(auraframe:GetHeight())
			auraframe.background:SetWidth(auraframe:GetWidth())
		end
		
		-- Reset elapsed timer
		auraframe.elapsed = 0
	end
end

function ASAuras:TestMode()
	for spellId, aura in pairs(ASAuras_DB) do
		if auraframes[spellId] then
			if (auraframes[spellId]:IsVisible() == nil) then
				auraframes[spellId]:Show()
			end
		else
			ASAuras:CreateFrame(nil,spellId)
		end
	end
	for spellId, auraframe in pairs(auraframes) do
		if auraframe.target ~= "cd" then
			auraframe:SetScript("OnUpdate", function(self, elapsed)
				ASAuras:UpdateAura(auraframe, elapsed)
			end);
		end
		auraframe:SetMovable(true)
		auraframe:EnableMouse(true)
		auraframe:SetResizable(true)
		auraframe:RegisterForDrag("LeftButton")
		auraframe:SetScript("OnDragStart", function(this)
			auraframe.oldxOffset = this:GetLeft()
			auraframe.oldyOffset = this:GetTop()
			this:StartMoving()
		end)
		auraframe:SetScript("OnDragStop", function(this)
			this:StopMovingOrSizing()
			ASAuras_DB[auraframe.spellId].yOffset = ASAuras_DB[auraframe.spellId].yOffset + this:GetTop() - auraframe.oldyOffset
			ASAuras_DB[auraframe.spellId].xOffset = ASAuras_DB[auraframe.spellId].xOffset + this:GetLeft() - auraframe.oldxOffset
		end)
		auraframe.Grip = CreateFrame("Button", "AuraResize"..auraframe.spellId, auraframe)
		auraframe.Grip:SetNormalTexture("Interface\\AddOns\\ASAuras\\ResizeGrip")
		auraframe.Grip:SetHighlightTexture("Interface\\AddOns\\ASAuras\\ResizeGrip")
		auraframe.Grip:SetWidth(16)
		auraframe.Grip:SetHeight(16)
		auraframe.Grip:EnableMouse(true)
		auraframe.Grip:SetPoint("BOTTOMRIGHT", auraframe, 1, 1)
		auraframe.Grip:SetScript("OnMouseDown", function(this)
			auraframe:StartSizing("BOTTOMRIGHT")
		end)
				
		auraframe.Grip:SetScript("OnMouseUp", function(this)
			auraframe:SetScript("OnSizeChanged", nil)
			auraframe:StopMovingOrSizing()
			ASAuras_DB[auraframe.spellId].height = auraframe:GetHeight()
			ASAuras_DB[auraframe.spellId].width = auraframe:GetWidth()
		end)
	end
end