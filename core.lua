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
		bars = {
			type = "group",
			childGroups = "select",
			name = L["Bars"],
			args = {}
		},
		createBar = {
			type = "execute",
			name = L["Create new bar"],
			func = function()
				mod:CreateBar()
			end			
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
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("SexyCooldown", options.args.bars)
	optFrame = ACD3:AddToBlizOptions("SexyCooldown")
	
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

function mod:CreateBar(name, settings)
	settings = settings or deepcopy(mod.barDefaults)
	local frame = setmetatable(CreateFrame("Frame"), self.barMeta)
	if not name then
		name = "Bar" .. self.db.profile.barSerial
		self.db.profile.barSerial = self.db.profile.barSerial + 1
	end
	frame.name = name
	self.db.profile.bars[name] = true
	frame.db = self.db:RegisterNamespace(name, mod.barDefaults)
	options.args.bars.args[name] = self:GetOptionsTable(frame)
	frame:Init()
	tinsert(frames, frame)
	return frame
end

function mod:Setup()
	local count = 0
	for k, v in pairs(self.db.profile.bars) do
		self:CreateBar(k, v)
		count = count + 1
	end
	if count == 0 then
		self:CreateBar()
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
			local start, duration = GetInventoryItemCooldown("player", i)
			if start > 0 and duration > 3 then
				local link = GetInventoryItemLink("player",i)
				self:AddCooldown("item", link, start, duration)
			end
		end
		for i = 0, 4 do
			local slots = GetContainerNumSlots(i)
			for j = 1, slots do
				local start, duration = GetContainerItemCooldown(i,j)
				if start > 0 and duration > 3 then
					local link = GetContainerItemLink(i,j)
					self:AddCooldown("item", link, start, duration)
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
	cacheSpellsForBook(spells.PLAYER, "BOOKTYPE_PET")
end
