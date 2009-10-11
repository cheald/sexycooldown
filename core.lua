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
						mod:ShowBarOptions(bar.name)
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
	self.db = LibStub("AceDB-3.0"):New("SexyCooldownDB", defaults)
	
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("SexyCooldown", options)
	
	ACD3:AddToBlizOptions("SexyCooldown", nil, nil, "defaultArgs")
	configFrame = ACD3:AddToBlizOptions("SexyCooldown", L["Bars"], "SexyCooldown", "bars")
	ACD3:AddToBlizOptions("SexyCooldown", L["Profiles"], "SexyCooldown", "profiles")
	self:Setup()
	self.bars = frames
end

function mod:Config(barName)
	InterfaceOptionsFrame:Hide()
	ACD3:SetDefaultSize("SexyCooldown", 680, 550)
	ACD3:Open("SexyCooldown")
	if barName then
		ACD3:SelectGroup("SexyCooldown", "bars", barName)
	end
end

function mod:ShowBarOptions(barName)
	ACD3:SelectGroup("SexyCooldown", "bars", barName)
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
	tinsert(frames, frame)
	return frame
end

function mod:DestroyBar(frame)
	local name = frame.name
	self.db.profile.bars[name] = nil
	options.args.bars.args[name] = nil
	for k, v in pairs(self.db.profile.bars) do
		self:ShowBarOptions(k)
		break
	end
	ACD3:ConfigTableChanged(nil, "SexyCooldown")
	frame:Expire()
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