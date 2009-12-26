local mod = SexyCooldown:NewModule("Raid Debuffs", "AceEvent-3.0", "AceBucket-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SexyCooldown")

-- We only need one ID per skill - it's translated into a name.
local debuffs = {
	RAID_DEBUFF_BLEED = {
		47465,		-- Rend
		12867,		-- Deep Wounds
		48676,		-- Garrote
		48672,		-- Rupture
		48568,		-- Lacerate
		49803,		-- Pounce
		49800,		-- Rip
		48574,		-- Rake
		53582,		-- Savage Rend
	},
	RAID_DEBUFF_MAJOR_ARMOR = {
		47467,		-- Sunder Armor
		48669,		-- Expose Armor
	},
	RAID_DEBUFF_SPELL_HIT = {
		33193,		-- Misery
		770,		-- Faerie Fire. We assume that non-feral FF is always improved. Ugly as hell, but not much in the way of alternative options.
	}
}
local translatedDebuffs = {}
local classes = {
	RAID_DEBUFF_BLEED = ("|cffff0000%s|r"):format(L["Bleed"]),
	RAID_DEBUFF_MAJOR_ARMOR = ("|cffe2aa68%s|r"):format(L["Major Armor"]),
	RAID_DEBUFF_SPELL_HIT = ("|cff68d2e2%s|r"):format(L["Spell Hit"])
}

function mod:OnInitialize()	
	SexyCooldown.RegisterFilter(self, "RAID_DEBUFF_BLEED", 
		L["Bleeds on Target"], 		
		L["Show the duration of bleeds on the target"])
	SexyCooldown.RegisterFilter(self, "RAID_DEBUFF_MAJOR_ARMOR",
		L["Major Armor Debuffs"],
		L["Show the duration of major armor debuffs on the target"])
	SexyCooldown.RegisterFilter(self, "RAID_DEBUFF_SPELL_HIT",
		L["Spell Hit Debuffs"],
		L["Show the duration of +spell hit debuffs on the target"])
		
	for k, v in pairs(debuffs) do
		for _, spellID in ipairs(v) do
			local name, _, icon = GetSpellInfo(spellID)
			translatedDebuffs[name .. ":" .. icon] = k
		end
	end
end

function mod:OnEnable()
	self:RegisterBucketEvent("UNIT_AURA", 0.1, "UNIT_AURA")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "Refresh")
	self:Refresh()
end

function mod:Refresh()
	self:UpdateUnit("target")
end

local function showBuffHyperlink(frame, unit, id, filter, class)
	GameTooltip:SetUnitAura(unit, id, filter)
	GameTooltip:AddLine(class)
end

function mod:UNIT_AURA(units)
	for unit in pairs(units) do
		self:UpdateUnit(unit)
	end
end

do
	local removeBuffs = {}
	local existingBuffs = {}
	local slotDebuffs = {}
	local slotDebuffTimes = {}

	function mod:UpdateUnit(unit)
		if unit ~= "target" then return end
		wipe(removeBuffs)
		for k, v in pairs(existingBuffs) do
			removeBuffs[k] = v
		end
		wipe(existingBuffs)
		wipe(slotDebuffs)
		wipe(slotDebuffTimes)
		
		local index = 1
		while true do
			local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitAura(unit, index, "HARMFUL")
			if not name then break end
			local s = name .. ":" .. icon
			local debuffSlot = translatedDebuffs[s]
			if debuffSlot then
				local uid = debuffSlot .. ":" .. s
				if expirationTime > (slotDebuffTimes[debuffSlot] or 0) then
					if slotDebuffs[debuffSlot] then
						local oldUID = slotDebuffs[debuffSlot]
						existingBuffs[oldUID] = nil
						removeBuffs[oldUID] = true
					end
					slotDebuffTimes[debuffSlot] = expirationTime
					slotDebuffs[debuffSlot] = uid
					SexyCooldown:AddItem(uid, name, icon, expirationTime - duration, duration, count, debuffSlot, showBuffHyperlink, unit, index, "HARMFUL", classes[debuffSlot])
					existingBuffs[uid] = true
					removeBuffs[uid] = nil
				end
			end
			index = index + 1
		end
		
		for k, v in pairs(removeBuffs) do
			SexyCooldown:RemoveItem(k)
		end
	end
end