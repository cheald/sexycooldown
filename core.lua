local L = LibStub("AceLocale-3.0"):GetLocale("SexyCooldown")
local ACD3 = LibStub("AceConfigDialog-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local LibICD = LibStub("LibInternalCooldowns-1.0")
local mod = SexyCooldown
local _G = getfenv(0)
local optFrame

local spells = { PLAYER = {}, PET = {} }
local defaults = {
	profile = {
		barSerial = 1,
		bars = {}
	}
}
local frames = {}

local options = {
	type = "group",
	inline = true,
	childGroups = "tab",
	args = {
		defaultArgs = {
			type = "group",
			name = "Default Args",
			args = {
				instructions = {
					type = "description",
					name = L["Select an options sub-category to get started."]
				}
				-- createBar = {
					-- type = "execute",
					-- name = L["Create new bar"],
					-- func = function()
						-- mod:CreateBar()
					-- end			
				-- }
			}
		},
		bars = {
			type = "group",
			childGroups = "select",
			name = L["Bars"],
			args = {}
		}
	}
}

local function deepcopy(from)
	local to = {}
	for k,v in pairs(from) do
		if type(v) == "table" then
			to[k] = deepcopy(v)
		else
			to[k] = v
		end
	end
	return to
end

local lastPlayerSpell, lastPetSpell = {}, {}

function mod:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("SexyCooldownDB", defaults)
	
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("SexyCooldown", options)
	
	ACD3:AddToBlizOptions("SexyCooldown", nil, nil, "defaultArgs")
	ACD3:AddToBlizOptions("SexyCooldown", L["Bars"], "SexyCooldown", "bars")
	ACD3:AddToBlizOptions("SexyCooldown", L["Profiles"], "SexyCooldown", "profiles")
	
	self:Setup()
end

function mod:Config()
	InterfaceOptionsFrame:Hide()
	ACD3:SetDefaultSize("SexyCooldown", 650, 550)
	ACD3:Open("SexyCooldown")
end

function mod:OnEnable()
	self:CacheSpells()
	self:RegisterEvent("BAG_UPDATE_COOLDOWN")
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	self:RegisterEvent("SPELLS_CHANGED", "CacheSpells")	
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self:SPELL_UPDATE_COOLDOWN()
	self:BAG_UPDATE_COOLDOWN()
	
	self:RegisterEvent("UNIT_SPELLCAST_FAILED")
	
	self.db.RegisterCallback(self, "OnProfileChanged", "ReloadAddon")
	self.db.RegisterCallback(self, "OnProfileCopied", "ReloadAddon")
	self.db.RegisterCallback(self, "OnProfileReset", "ReloadAddon")
	
	LibICD.RegisterCallback(self, "InternalCooldowns_Proc")
	LibICD.RegisterCallback(self, "InternalCooldowns_TalentProc")	
end

function mod:OnDisable()
	LibICD.UnregisterCallback(self, "InternalCooldowns_Proc")
	LibICD.UnregisterCallback(self, "InternalCooldowns_TalentProc")	
end

function mod:InternalCooldowns_TalentProc(callback, spellID, start, duration)
	local name = GetSpellInfo(spellID)
	self:AddCooldown(name, "spell", spellID, start, duration)
end

function mod:InternalCooldowns_Proc(callback, itemID, spellID, start, duration)
	local texture = select(10, GetItemInfo(itemID))
	local name = GetItemInfo(itemID)
	self:AddCooldown(name, "spell", spellID, start, duration, texture)
end

local oldframes = {}
function mod:ReloadAddon()
	for _, v in ipairs(frames) do
		local frame = tremove(frames)
		frame:Expire()
		tinsert(oldframes, frame)
	end
	
	self:Setup()
	self:SPELL_UPDATE_COOLDOWN()
	self:BAG_UPDATE_COOLDOWN()
end

function mod:CreateBar(name, settings)
	settings = settings or deepcopy(mod.barDefaults)
	local frame = setmetatable(CreateFrame("Frame", nil, UIParent), self.barMeta)
	if not name then
		name = "Bar" .. self.db.profile.barSerial
		self.db.profile.barSerial = self.db.profile.barSerial + 1
	end
	frame.name = name
	self.db.profile.bars[name] = true
	frame.db = self.db:GetNamespace(name, true) or self.db:RegisterNamespace(name, mod.barDefaults)
	options.args.bars.args[name] = self:GetOptionsTable(frame)
	frame:Init()
	return frame
end

function mod:Setup()
	local count = 0
	for k, v in pairs(self.db.profile.bars) do
		tinsert(frames, self:CreateBar(k, v))
		count = count + 1
	end
	if count == 0 then
		tinsert(frames, self:CreateBar())
	end
end

function mod:AddCooldown(name, cdType, item, start, duration, icon)
	local id 
	if cdType == "item" then
		id = tonumber(item)
		if not id or id == 0 then
			id = tonumber(item:match("item:(%d+)"))
		end
	elseif cdType == "spell" then
		id = item
	end
	if id == 0 then
		error("Invalid item type or ID specified for :AddCooldown")
	end
	for _, frame in ipairs(frames) do
		frame:CreateCooldown(name, cdType, id, start, duration, icon)
	end
end

function mod:UNIT_SPELLCAST_FAILED(event, unit, spell, rank)
	if unit == "player" and spells.PLAYER[spell] then
		for _, frame in ipairs(frames) do
			frame:CastFailure("spell", spells.PLAYER[spell])
		end
	elseif unit == "pet" and spells.PET[spell] then
		for _, frame in ipairs(frames) do
			frame:CastFailure("spell", spells.PET[spell])
		end
	end
end

local GetInventoryItemCooldown = _G.GetInventoryItemCooldown
local GetInventoryItemLink = _G.GetInventoryItemLink
local GetContainerItemCooldown = _G.GetContainerItemCooldown
local GetContainerItemLink = _G.GetContainerItemLink
local GetSpellCooldown = _G.GetSpellCooldown
do
	function mod:BAG_UPDATE_COOLDOWN()
		for i = 1, 18 do
			local start, duration, active = GetInventoryItemCooldown("player", i)
			if active == 1 and start > 0 and duration > 3 then
				local link = GetInventoryItemLink("player",i)
				local id = link:match("item:(%d+)")
				local name = GetItemInfo(id)
				if link then
					self:AddCooldown(name, "item", id, start, duration)
				end
			end
		end
		for i = 0, 4 do
			local slots = GetContainerNumSlots(i)
			for j = 1, slots do
				local start, duration, active = GetContainerItemCooldown(i,j)
				if active == 1 and start > 0 and duration > 3 then
					local link = GetContainerItemLink(i,j)
					if link then
						local id = link:match("item:(%d+)")
						local name = GetItemInfo(id)
						self:AddCooldown(name, "item", id, start, duration)
					end
				end
			end
		end
	end
end

do
	function mod:SPELL_UPDATE_COOLDOWN()
		local start, duration, active, id
		local added = false
		
		for _, name in ipairs(lastPlayerSpell) do
			start, duration, active = GetSpellCooldown(name)
			if active == 1 and start > 0 and duration > 3 then
				self:AddCooldown(name, "spell", spells.PLAYER[name], start, duration)
				added = true
				break
			end
		end
		
		if not added then
			for name, id in pairs(spells.PLAYER) do
				start, duration, active = GetSpellCooldown(name)
				if active == 1 and start > 0 and duration > 3 then
					self:AddCooldown(name, "spell", id, start, duration)
				end
			end
		end
		
		if UnitExists("pet") then
			added = false
			for _, name in ipairs(lastPetSpell) do
				start, duration, active = GetSpellCooldown(name)
				if active == 1 and start > 0 and duration > 3 then
					self:AddCooldown(name, "spell", spells.PET[name], start, duration)
					added = true
					break
				end
			end		
			if not added then
				for name, id in pairs(spells.PET) do
					start, duration, active = GetSpellCooldown(name)
					if active == 1 and start > 0 and duration > 3 then
						self:AddCooldown(name, "spell", id, start, duration)
					end
				end
			end
		end
	end
	
	function mod:UNIT_SPELLCAST_SUCCEEDED(event, unit, spell)
		if unit == "player" then
			tinsert(lastPlayerSpell, 1, spell)
			if #lastPlayerSpell > 5 then tremove(lastPlayerSpell) end
		elseif unit == "pet" then
			tinsert(lastPetSpell, 1, spell)
			if #lastPetSpell > 5 then tremove(lastPetSpell) end
		end
	end
end

local function cacheSpellsForBook(t, book)
	wipe(t)
	for i = 1, 500 do
		local name = GetSpellName(i, book)
		if not name then break end
		
		local _, _ = GetSpellCooldown(i, book)
		local id = tonumber(GetSpellLink(i, book):match("spell:(%d+)"))
		t[name] = id
	end
end

function mod:CacheSpells()
	cacheSpellsForBook(spells.PLAYER, "BOOKTYPE_SPELL")
	cacheSpellsForBook(spells.PET, "BOOKTYPE_PET")
end
