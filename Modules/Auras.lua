local mod = SexyCooldown:NewModule("Buffs and Debuffs", "AceEvent-3.0", "AceBucket-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SexyCooldown")

function mod:OnInitialize()	
	SexyCooldown.RegisterFilter(self, "DEBUFFS_ON_ME",
		L["Debuffs on me"],
		L["Show the duration of debuffs on me on this bar"])
	SexyCooldown.RegisterFilter(self, "MY_DEBUFFS", 
		L["My target debuffs"], 
		L["Show the duration of my debuffs on my target on this bar"])
	SexyCooldown.RegisterFilter(self, "MY_FOCUS_DEBUFFS", 
		L["Focus debuffs"], 
		L["Show the duration of my debuffs on my focus on this bar"])
	SexyCooldown.RegisterFilter(self, "MY_TARGET_BUFFS", 
		L["My target buffs"], 
		L["Show the duration of my buffs on my target on this bar"])
	SexyCooldown.RegisterFilter(self, "MY_FOCUS_BUFFS", 
		L["Focus buffs"], 
		L["Show the duration of my buffs on my focus on this bar"])
	SexyCooldown.RegisterFilter(self, "BUFFS_ON_ME", 
		L["Buffs on me"], 
		L["Show the duration of buffs on me on this bar"])
end

function mod:OnEnable()
	self:RegisterBucketEvent("UNIT_AURA", 0.1, "UNIT_AURA")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "Refresh")
	self:Refresh()
end

function mod:Refresh()
	self:UpdateUnit("player")
	self:UpdateUnit("target")
	self:UpdateUnit("focus")
end

local function showBuffHyperlink(frame, unit, id, filter)
	GameTooltip:SetUnitAura(unit, id, filter)
end

function mod:UNIT_AURA(units)
	for unit in pairs(units) do
		self:UpdateUnit(unit)
	end
end

do
	local tmp = {}
	local existingBuffs = {}

	local function check(unit, uidstr, filter, func, funcFilter, filterSource)
		local buffs = existingBuffs[unit]
		local name, rank, icon, count, debuffType, duration, expirationTime, source, index
		index = 1
		while true do
			name, rank, icon, count, debuffType, duration, expirationTime, source = func(unit, index)
			if not name then break end
			local filterValid = filterSource == nil or filterSource and source and UnitIsUnit(filterSource, source)
			
			if duration > 0 and filterValid then
				local uid = unit .. uidstr .. name
				SexyCooldown:AddItem(uid, name, icon, expirationTime - duration, duration, filter, showBuffHyperlink, unit, index, funcFilter)
				buffs[uid] = true
				tmp[uid] = nil
			end
			index = index + 1			
		end
	end

	function mod:UpdateUnit(unit)
		wipe(tmp)
		existingBuffs[unit] = existingBuffs[unit] or {}	
		local buffs = existingBuffs[unit]
		for k, v in pairs(buffs) do
			tmp[k] = v
		end
		wipe(buffs)
		
		local name, rank, icon, count, debuffType, duration, expirationTime, source, index
		if unit == "player" then
			check(unit, ":buff:", "BUFFS_ON_ME", UnitBuff, "HELPFUL")
			check(unit, ":debuff:", "DEBUFFS_ON_ME", UnitDebuff, "HARMFUL")
		elseif unit == "target" then
			check(unit, ":buff:", "MY_TARGET_BUFFS", UnitBuff, "HELPFUL", "player")
			check(unit, ":debuff:", "MY_DEBUFFS", UnitDebuff, "HARMFUL", "player")
		elseif unit == "focus" then
			check(unit, ":buff:", "MY_TARGET_BUFFS", UnitBuff, "HELPFUL", "player")
			check(unit, ":debuff:", "MY_FOCUS_DEBUFFS", UnitDebuff, "HARMFUL", "player")
		end
		
		for k, v in pairs(tmp) do
			SexyCooldown:RemoveItem(k)
		end
	end
end