local mod = SexyCooldown
local function getPos(val, valMax, base)
	return math.pow(val, base) / math.pow(valMax, base)
end
local LSM = LibStub("LibSharedMedia-3.0")

local dummyFrame = CreateFrame("Frame")
local cooldownPrototype = setmetatable({}, {__index = dummyFrame})
local cooldownMeta = {__index = cooldownPrototype}
local barPrototype = setmetatable({}, {__index = dummyFrame})
mod.barMeta = {__index = barPrototype}

barPrototype.framePool = {}
barPrototype.stringPool = {}

------------------------------------------------------
-- Bar prototype
------------------------------------------------------

function barPrototype:Init()
	self:SetFrameStrata("MEDIUM")
	self.settings = self.db.profile
	self.usedFrames = {}
	self.cooldowns = {}
	self.allFrames = {}
	self.durations = {}
	self:SetBackdrop(mod.backdrop)
	self:SetPoint("CENTER", UIParent, "CENTER", self.settings.x, self.settings.y)	
	-- self:SetPoint("CENTER", UIParent, "CENTER")	
	
	self:SetScript("OnMouseDown", function(self)
		if not self.db.profile.bar.lock then
			self:StartMoving()
		end
	end)
	self:SetScript("OnMouseUp", function(self)
		self:StopMovingOrSizing()
		local x, y = self:GetCenter()
		local ox, oy = UIParent:GetCenter()
		local scale = UIParent:GetScale()
		x, y = x / scale, y / scale
		self.settings.x = (x - ox) * scale
		self.settings.y = (y - oy) * scale
	end)
	self:SetScript("OnSizeChanged", function()
		self.settings.bar.width = self:GetWidth()
		self.settings.bar.height = self:GetHeight()
		self:UpdateLook()
	end)
	self:EnableMouse(true)
	self:SetMovable(true)
	self:SetResizable(true)
	self:SetMinResize(20, 10)
	
	local grip = CreateFrame("Frame", nil, self)
	grip:EnableMouse(true)
	local tex = grip.tex or grip:CreateTexture()
	grip.tex = tex
	tex:SetTexture([[Interface\BUTTONS\UI-AutoCastableOverlay]])
	tex:SetTexCoord(0.619, 0.760, 0.612, 0.762)
	tex:SetDesaturated(true)
	tex:ClearAllPoints()
	tex:SetAllPoints()

	grip:SetWidth(6)
	grip:SetHeight(6)
	grip:SetScript("OnMouseDown", function(self)
		self:GetParent():StartSizing()
	end)
	grip:SetScript("OnMouseUp", function(self)
		self:GetParent():StopMovingOrSizing()
		self:GetParent().settings.bar.width = self:GetParent():GetWidth()
		self:GetParent().settings.bar.height = self:GetParent():GetHeight()
	end)

	grip:ClearAllPoints()
	grip:SetPoint("BOTTOMRIGHT")
	grip:SetScript("OnEnter", function(self)
		self.tex:SetDesaturated(false)
	end)
	grip:SetScript("OnLeave", function(self)
		self.tex:SetDesaturated(true)
	end)
	self.grip = grip
	
	self:UpdateBarLook()
end

do
	local framelevelSerial = 1
	local delta = 0
	local throttle = 1 / 30
	function barPrototype:OnUpdate(t)
		delta = delta + t		
		if delta < throttle then return end
		throttle = throttle - delta		
		for k, frame in pairs(self.cooldowns) do		
			frame:UpdateTime()
		end
	end
	
	local backdrop = {
		edgeFile = [[Interface\GLUES\COMMON\TextPanel-Border.blp]],
		insets = {left = 2, top = 2, right = 2, bottom = 2},
		edgeSize = 8,
		tile = true					
	}	
	function barPrototype:UpdateSingleIconLook(icon)
		backdrop.edgeFile = LSM:Fetch("border", self.settings.icon.border) or backdrop.edgeFile
		backdrop.edgeSize = self.settings.icon.borderSize or backdrop.edgeSize
		
		icon.tex:SetPoint("TOPLEFT", icon, "TOPLEFT", self.settings.icon.borderInset, -self.settings.icon.borderInset)
		icon.tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -self.settings.icon.borderInset, self.settings.icon.borderInset)
		
		icon.overlay:SetBackdrop(backdrop)
		local c = self.settings.icon.borderColor
		icon.overlay:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
		
		self:UpdateLabel(icon.fs, self.settings.icon)		
		icon:SetWidth(self:GetHeight() + self.settings.icon.sizeOffset)
		icon:SetHeight(self:GetHeight() + self.settings.icon.sizeOffset)
		
		if self.settings.icon.showText then
			icon.fs:Show()
		else
			icon.fs:Hide()
		end
	end
	
	function barPrototype:CreateCooldown(typ, id, startTime, duration, icon)
		local hyperlink = ("%s:%s"):format(typ, id)
		local f = self.cooldowns[hyperlink]
		if not f then
			f = tremove(self.framePool)
			if not f then
				f = setmetatable(CreateFrame("Frame"), cooldownMeta)
				f:SetFrameStrata("MEDIUM")
				f.tex = f:CreateTexture()

				f.overlay = CreateFrame("Frame", nil, f)
				f.overlay:SetAllPoints()
				f.overlay:SetFrameStrata("MEDIUM")
				f.overlay.tex = f.overlay:CreateTexture()
				f.overlay.tex:SetAllPoints()
				
				f.fs = f.overlay:CreateFontString(nil, nil, "SystemFont_Outline_Small")
				f.fs:SetPoint("BOTTOMRIGHT", f.overlay, "BOTTOMRIGHT", -1, 2)
				f:SetScript("OnEnter", f.ShowTooltip)
				f:SetScript("OnLeave", f.HideTooltip)
				f:EnableMouse(true)
				tinsert(self.allFrames, f)
			end
			f.parent = self
			self:UpdateSingleIconLook(f)
			tinsert(self.usedFrames, f)
		end
		f.icon = icon
		f.startTime = startTime
		f.duration = duration
		f.useTooltip = typ == "spell" or typ == "item"
		f:SetFrameLevel(framelevelSerial)
		f.overlay:SetFrameLevel(framelevelSerial+1)
		framelevelSerial = framelevelSerial + 2
		f.hyperlink = hyperlink
		self.cooldowns[f.hyperlink] = f
		self.durations[f.hyperlink] = duration
		self:SetMaxDuration()
		f:SetCooldown(typ, id, startTime + duration)
		self:SetScript("OnUpdate", self.OnUpdate)
		f:Show()
	end
end

function barPrototype:SetMaxDuration()
	if not self.settings.bar.flexible then return end
	local max = 0
	for k, v in pairs(self.durations) do
		max = v > max and v or max
	end
	if max < 30 then max = 30 end
	if max ~= self:GetTimeMax() then
		self.max_duration = max
		self:SetLabels()
	end
end

function barPrototype:GetTimeMax()
	local t = self.settings.bar.flexible and self.max_duration or self.settings.time_max
	return t
end

function barPrototype:CreateLabel()
	local s = tremove(self.stringPool) or self:CreateFontString(nil, "OVERLAY", "SystemFont_Outline_Small")
	tinsert(self.usedStrings, s)
	s:Show()
	return s
end

function barPrototype:SetLabel(val)
	local l = self:CreateLabel(self)
	local pos = getPos(val, self:GetTimeMax(), self.settings.time_compression) * (self.settings.bar.width - self.settings.bar.height)
	l:SetPoint("CENTER", self, "LEFT", pos, 0)
	if val > 3600 then
		val = ("%2.0fh"):format(val / 3600)
	elseif val > 60 then
		val = ("%2.0fm"):format(val / 60)
	end	
	l:SetText(val)
end

local stock = {1, 10, 30}
function barPrototype:SetLabels()
	self.usedStrings = self.usedStrings or {}
	
	while #self.usedStrings > 0 do
		local l = tremove(self.usedStrings)
		l:Hide()
		tinsert(self.stringPool, l)
	end
	
	local minutes = math.floor(self:GetTimeMax() / 60)
	for i = 5, minutes, 5 do
		self:SetLabel(i * 60)
	end
	
	if minutes > 5 and math.fmod(minutes, 5) ~= 0 then
		self:SetLabel(minutes * 60)
	end
	
	for i = 1, math.min(minutes, 5) do
		self:SetLabel(i * 60)
	end

	for _, val in ipairs(stock) do
		self:SetLabel(val)
	end
end

function barPrototype:UpdateLabel(label, store)
	local f, s, m = label:GetFont() 
	local font = LSM:Fetch("font", store.font or f)
	local size = store.fontsize or s
	local outline = store.outline or m
	label:SetFont(font, size, outline)	
	local c = store.fontColor
	label:SetTextColor(c.r, c.g, c.b, c.a)
end

function barPrototype:SetBarFont()
	for k, v in ipairs(self.stringPool) do
		self:UpdateLabel(v, self.settings.bar)
	end
	
	for k, v in ipairs(self.usedStrings) do
		self:UpdateLabel(v, self.settings.bar)
	end
end

do
	local backdrop = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		insets = {left = 2, top = 2, right = 2, bottom = 2},
		edgeSize = 8,
		tile = false
	}
	function barPrototype:UpdateBarBackdrop()
		backdrop.bgFile = LSM:Fetch("statusbar", self.settings.bar.texture) or backdrop.bgFile
		backdrop.edgeFile = LSM:Fetch("border", self.settings.bar.border) or backdrop.border
		backdrop.edgeSize = self.settings.bar.borderSize or backdrop.edgeSize
		backdrop.insets.left = self.settings.bar.borderInset or backdrop.insets.left
		backdrop.insets.top = self.settings.bar.borderInset or backdrop.insets.top
		backdrop.insets.right = self.settings.bar.borderInset or backdrop.insets.right
		backdrop.insets.bottom = self.settings.bar.borderInset or backdrop.insets.bottom
		self:SetBackdrop(backdrop)
		local c = self.settings.bar.backgroundColor
		self:SetBackdropColor(c.r, c.g, c.b, c.a)
		c = self.settings.bar.borderColor
		self:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
	end
end

function barPrototype:UpdateBarLook()
	self:SetWidth(self.settings.bar.width)
	self:SetHeight(self.settings.bar.height)
	self:SetLabels()
	self:SetBarFont()
	self:UpdateBarBackdrop()
	if self.settings.bar.lock then
		self.grip:Hide()
	else
		self.grip:Show()
	end
end

function barPrototype:UpdateIconLook()
	for _, icon in ipairs(self.allFrames) do
		self:UpdateSingleIconLook(icon)
	end
end

function barPrototype:UpdateLook()
	self:UpdateBarLook()
	self:UpdateIconLook()
end

------------------------------------------------------
-- Button prototype
------------------------------------------------------
function cooldownPrototype:SetCooldown(typ, id, endTime)
	local icon = self.icon
	if not icon then
		local _
		if typ == "spell" then
			_, _, icon = GetSpellInfo(id)
		elseif typ == "item" then
			_, _, _, _, _, _, _, _, _, icon = GetItemInfo(id)
		end
	end
	if icon then
		self.tex:SetTexture(icon)
		self.tex:SetTexCoord(0.06, 0.94, 0.05, 0.94)
	end
	self.endTime = endTime
end

function cooldownPrototype:ShowTooltip()
	if not self.hyperlink or not self.useTooltip then 
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
	GameTooltip:SetHyperlink(self.hyperlink)
	GameTooltip:Show()
end

function cooldownPrototype:HideTooltip()
	GameTooltip:Hide()
end
	
function cooldownPrototype:Expire()
	local parent = self.parent
	for k, v in ipairs(parent.usedFrames) do
		if v == self then
			tinsert(parent.framePool, tremove(parent.usedFrames, k))
			break
		end
	end
	if #parent.usedFrames == 0 then
		parent:SetScript("OnUpdate", nil)
	end
	parent.cooldowns[self.hyperlink] = nil
	parent.durations[self.hyperlink] = nil
end
	
function cooldownPrototype:UpdateTime()
	local parent = self.parent
	local remaining = self.endTime - GetTime()
	local text
	if remaining > 60 then
		local minutes = math.floor(remaining / 60)
		local seconds = math.fmod(remaining, 60)
		text = ("%2.0f:%02.0f"):format(minutes, seconds)
	elseif remaining <= 10 then
		text = ("%2.1f"):format(remaining)
	else
		text = ("%2.0f"):format(remaining)
	end
	self.fs:SetText(text)
	if remaining > parent:GetTimeMax() then
		remaining = parent:GetTimeMax()
	end
	local pos = getPos(remaining, parent:GetTimeMax(), parent.settings.time_compression) * (parent:GetWidth() - parent:GetHeight())
	self:SetPoint("CENTER", parent, "LEFT", pos, 0)
	
	if remaining < 0 then
		self:Expire()
	end
end