local L = LibStub("AceLocale-3.0"):GetLocale("SexyCooldown")
local ACD3 = LibStub("AceConfigDialog-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local mod = SexyCooldown
local _G = getfenv(0)

local GetInventoryItemCooldown = _G.GetInventoryItemCooldown
local GetInventoryItemLink = _G.GetInventoryItemLink
local GetContainerItemCooldown = _G.GetContainerItemCooldown
local GetContainerItemLink = _G.GetContainerItemLink
local GetSpellCooldown = _G.GetSpellCooldown

local activeFilters = {}
local defaults = {
	profile = {
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
			guiHidden = true,
			args = {
				instructions = {
					type = "description",
					name = L["Select an options sub-category to get started."]
				}
			}
		},
		bars = {
			type = "group",
			childGroups = "select",
			name = L["Bars"],
			args = {
				createBar = {
					type = "execute",
					name = L["Create new bar"],
					func = function()
						local bar = mod:CreateBar()
						mod:ShowBarOptions(bar)
					end,
					order = 101
				},
			}
		},
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

local configFrame

function mod:OnInitialize()
	self:UpdateBarDB()
	
	self.db = LibStub("AceDB-3.0"):New("SexyCooldownDB", defaults)
	self.db.global.dbVersion = 3
	
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("SexyCooldown", options)
	
	ACD3:AddToBlizOptions("SexyCooldown", nil, nil, "defaultArgs")
	configFrame = ACD3:AddToBlizOptions("SexyCooldown", L["Bars"], "SexyCooldown", "bars")
	ACD3:AddToBlizOptions("SexyCooldown", L["Profiles"], "SexyCooldown", "profiles")
	self:Setup()
	self.bars = frames
end

function mod:Config(bar)
	InterfaceOptionsFrame:Hide()
	ACD3:SetDefaultSize("SexyCooldown", 680, 550)
	ACD3:Open("SexyCooldown")
	if bar then
		self:ShowBarOptions(bar)
	end
end

function mod:ShowBarOptions(bar)
	ACD3:SelectGroup("SexyCooldown", "bars", bar.optionsKey)
end

function mod:OnEnable()	
	self.db.RegisterCallback(self, "OnProfileChanged", "ReloadAddon")
	self.db.RegisterCallback(self, "OnProfileCopied", "ReloadAddon")
	self.db.RegisterCallback(self, "OnProfileReset", "ReloadAddon")
end

local oldframes = {}
function mod:ReloadAddon()
	for _, v in ipairs(frames) do
		local frame = tremove(frames)
		frame:Expire()
		tinsert(oldframes, frame)
	end
	
	self:Setup()
	self:RefreshCooldowns()
end

local filterToMod = {}
function mod.RegisterFilter(module, filter, name, description)
	filterToMod[filter] = module
	local modname = module:GetName():gsub(" ", "_")
	mod.eventArgs[modname] = mod.eventArgs[modname] or {
		type = "group",
		inline = true,
		name = module:GetName(),
		args = {}
	}
	mod.eventArgs[modname].args[filter] = {
		type = "toggle",
		name = name,
		desc = description
	}
end

function mod:RegisterBarForFilter(filter)
	activeFilters[filter] = (activeFilters[filter] or 0) + 1	
end

function mod:UnregisterBarForFilter(filter)
	if activeFilters[filter] then
		activeFilters[filter] = activeFilters[filter] - 1	
	else
		error(("%s is not a registered filter type"):format(filter))
	end
end

-- Todo
function mod:IsFilterRegistered(filter)
	do return true end
	return activeFilters[filter] and activeFilters[filter] > 0
end

-- For 0.6.2 to 0.6.3
function mod:UpdateBarDB()
	if not SexyCooldownDB.global or not SexyCooldownDB.global.dbVersion or SexyCooldownDB.global.dbVersion < 2 then
		if SexyCooldownDB.namespaces then
			for namespace, settings in pairs(SexyCooldownDB.namespaces) do
				for profile, key in pairs(settings.profileKeys) do
					local barSettings = settings.profiles[key]
					if #SexyCooldownDB.profiles[key].bars == 0 then
						SexyCooldownDB.profiles[key].bars = {}
					end
					tinsert(SexyCooldownDB.profiles[key].bars, barSettings)
				end
			end
		end
		for profile, settings in pairs(SexyCooldownDB.profiles) do
			settings.barSerial = nil
		end
		SexyCooldownDB.namespaces = nil
		SexyCooldownDB.global = SexyCooldownDB.global or {}
		SexyCooldownDB.global.dbVersion = 2
	end	
end

local function bindToMetaTable(target, source)
	setmetatable(target, {__index = source})
	for k, v in pairs(target) do
		if type(v) == "table" and source[k] then
			bindToMetaTable(v, source[k])
		end
	end
end

local barOptionsCount = 0
function mod:CreateBar(settings, defaultName)
	settings = settings or deepcopy(mod.barDefaults)
	local frame = setmetatable(CreateFrame("Frame", nil, UIParent), self.barMeta)
	local name = settings.bar.name or defaultName
	if not name then
		name = "Bar " .. (#self.db.profile.bars + 1)
		settings.bar.name = name
	end
	settings.bar.name = name
	local existing = false
	for k, v in ipairs(self.db.profile.bars) do
		if v == settings then
			frame.id = k
			existing = true
			break
		end
	end
	if not existing then
		tinsert(self.db.profile.bars, settings)
		frame.id = #self.db.profile.bars
	end	
	bindToMetaTable(settings, mod.barDefaults)
	frame.settings = settings
	frame.optionsTable = self:GetOptionsTable(frame)
	frame.optionsKey = "baroptions" .. barOptionsCount
	options.args.bars.args[frame.optionsKey] = frame.optionsTable
	barOptionsCount = barOptionsCount + 1
	frame:Init()
	tinsert(frames, frame)
	return frame
end

function mod:UpdateFrameName(frame)
	frame.optionsTable.name = frame.settings.bar.name
	self:ShowBarOptions(frame)
	ACD3:ConfigTableChanged(nil, "SexyCooldown")
end

-- FIXME
function mod:DestroyBar(frame)
	for k, v in ipairs(self.db.profile.bars) do
		if frame.settings == v then
			tremove(self.db.profile.bars, k)
		end
	end
	options.args.bars.args[frame.optionsKey] = nil
	
	for k, v in ipairs(frames) do
		self:ShowBarOptions(v)
		break
	end
	ACD3:ConfigTableChanged(nil, "SexyCooldown")
	frame:Expire()
end

function mod:Setup()
	for k, v in ipairs(self.db.profile.bars) do
		self:CreateBar(v, "Bar " .. k)
	end
	if #self.db.profile.bars == 0 then
		self:CreateBar()
	end
end

function mod:Refresh(filter)
	if filter then
		if filterToMod[filter].Refresh then
			filterToMod[filter]:Refresh()
		end
	else
		for k, v in self:IterateModules() do
			if v.Refresh then v:Refresh() end
		end
	end
end

function mod:AddItem(uid, name, icon, start, duration, filter, callback, ...)
	for _, frame in ipairs(frames) do
		frame:CreateCooldown(uid, name, icon, start, duration, filter, callback, ...)
	end
end

function mod:RemoveItem(uid)
	for _, frame in ipairs(frames) do
		frame:ExpireCooldown(uid)
	end
end

function mod:CastFailure(uid)
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

function mod.SHOW_HYPERLINK(frame, link)
	GameTooltip:SetHyperlink(link)
end