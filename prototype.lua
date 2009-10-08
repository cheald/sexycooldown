local mod = SexyCooldown
local math_pow = _G.math.pow
local string_format = _G.string.format
local math_floor = _G.math.floor
local math_fmod = _G.math.fmod
local math_min = _G.math.min

local function getPos(val, valMax, base)
	return math_pow(val, base) / math_pow(valMax, base)
end
local LSM = LibStub("LibSharedMedia-3.0")

local GetTime = _G.GetTime
local dummyFrame = CreateFrame("Frame")
local cooldownPrototype = setmetatable({}, {__index = dummyFrame})
local cooldownMeta = {__index = cooldownPrototype}
local barPrototype = setmetatable({}, {__index = dummyFrame})
mod.barMeta = {__index = barPrototype}

barPrototype.framePool = {}
barPrototype.stringPool = {}

local totals = {}
local loops = {}
local function bench(key, action)
	local t = GetTime()
	totals[key] = totals[key] or 0
	if action == "start" then
		loops[key] = t
	else
		totals[key] = totals[key] + (t - loops[key])
	end
end

local function report()
	for k, v in pairs(totals) do
		print(k, ":", v)
	end
end
mod.bench, mod.report = bench, report

------------------------------------------------------
-- Bar prototype
------------------------------------------------------

function barPrototype:Init()
	self:SetFrameStrata("HIGH")
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
		self.w = self.settings.bar.width
		self.h = self.settings.bar.height
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
	
	self.fade = self:CreateAnimationGroup()
	self.fadeAlpha = self.fade:CreateAnimation()

	self.fadeAlpha.parent = self
	self.fadeAlpha:SetScript("OnPlay", function(self)
		self.start = self.parent:GetAlpha()
		if self.parent.active then
			self.endTime = 1
		else
			self.endTime = self.parent.settings.bar.inactiveAlpha
		end
	end)
	self.fadeAlpha:SetScript("OnUpdate", function(self)		
		local new = self.start + ((self.endTime - self.start) * self:GetProgress())
		self.parent:SetAlpha(new)
	end)	
	
	self:UpdateBarLook()
end

do
	local framelevelSerial = 1
	local delta = 0
	local throttle = 1 / 33
	function barPrototype:OnUpdate(t)
		delta = delta + t		
		if delta < throttle then return end
		delta = delta - throttle
		for _, frame in ipairs(self.usedFrames) do		
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
		
		icon.finishScale:SetScale(self.settings.icon.splashScale, self.settings.icon.splashScale)
		icon.finishScale:SetDuration(self.settings.icon.splashSpeed)
		icon.animationOpacity:SetDuration(self.settings.icon.splashSpeed)
	end
	
	local function onClick(self, button)
		if button == "RightButton" then
			self:Blacklist()
		end
	end
	
	function barPrototype:Activate()
		if self.active then return end
		self.active = true		
		local alpha = self:GetAlpha()
		if alpha ~= 1 then
			self.fade:Stop()
			self.fadeAlpha:SetDuration(0.3)
			self.fade:Play()
		end
	end
	
	function barPrototype:Deactivate()
		if not self.active then return end
		self.active = false
		local alpha = self:GetAlpha()
		if alpha ~= self.settings.bar.inactiveAlpha then
			self.fade:Stop()
			self.fadeAlpha:SetDuration(0.33)
			self.fade:Play()
		end
	end
	
	function barPrototype:CreateCooldown(name, typ, id, startTime, duration, icon)
		if duration < self.settings.bar.minDuration or duration - (GetTime() - startTime) + 0.5 < self.settings.bar.minDuration then return end
		if duration > self.settings.bar.maxDuration and self.settings.bar.maxDuration ~= 0 then return end
		
		local hyperlink = ("%s:%s"):format(typ, id)
		if self.settings.blacklist[hyperlink] then return end
		
		local f = self.cooldowns[hyperlink]
		if not f then
			f = tremove(self.framePool)
			if not f then
				f = setmetatable(CreateFrame("Frame"), cooldownMeta)				
				f:SetFrameStrata("HIGH")
				f.tex = f:CreateTexture()
				
				f:SetScript("OnMouseUp", onClick)

				f.overlay = CreateFrame("Frame", nil, f)
				f.overlay:SetAllPoints()
				f.overlay:SetFrameStrata("HIGH")
				f.overlay.tex = f.overlay:CreateTexture()
				f.overlay.tex:SetAllPoints()
				
				f.fs = f.overlay:CreateFontString(nil, nil, "SystemFont_Outline_Small")
				f.fs:SetPoint("BOTTOMRIGHT", f.overlay, "BOTTOMRIGHT", -1, 2)
				f:SetScript("OnEnter", f.ShowTooltip)
				f:SetScript("OnLeave", f.HideTooltip)
				f:EnableMouse(true)
				
				f.finish = f:CreateAnimationGroup()
				f.finish:SetScript("OnPlay", function(self)
					f.overlay:Hide()
				end)
				f.finish:SetScript("OnFinished", function(self)
					f:Hide()
					f.overlay:Show()
				end)
				
				f.finishScale = f.finish:CreateAnimation("Scale")
				
				f.animationOpacity = f.finish:CreateAnimation("Alpha")
				f.animationOpacity:SetChange(-1)				
				
				f.pulse = f:CreateAnimationGroup()
				f.pulse:SetLooping("BOUNCE")
				f.pulseAlpha = f.pulse:CreateAnimation("Alpha")
				f.pulseAlpha:SetChange(-0.9)
				f.pulseAlpha:SetDuration(1)
				f.pulseAlpha:SetEndDelay(0.2)
				f.pulseAlpha:SetStartDelay(0.2)
				
				f.throb = f:CreateAnimationGroup()
				f.throbSize = f.throb:CreateAnimation("Scale")
				f.throbSize:SetSmoothing("NONE")
				f.throbSize:SetScale(1.8, 1.8)
				f.throbSize:SetDuration(0.1)
				f.throbAlpha = f.throb:CreateAnimation("Alpha")
				f.throbAlpha:SetChange(1)
				f.throbAlpha:SetDuration(0.3)
				f.throb:SetScript("OnPlay", function()
					f.overlay:Hide()
				end)
				f.throb:SetScript("OnFinished", function()
					f.overlay:Show()
				end)
				
				tinsert(self.allFrames, f)
			end
			
			f.name = name
			f.icon = icon
			
			f.finish:Stop()
			f.throb:Stop()
			f.pulse:Stop()
			f.overlay:Show()
			
			f:SetFrameLevel(framelevelSerial)
			f.overlay:SetFrameLevel(framelevelSerial + 1)
			framelevelSerial = framelevelSerial + 2
			f.useTooltip = typ == "spell" or typ == "item"
			f.hyperlink = hyperlink
			self.cooldowns[f.hyperlink] = f
			self.durations[f.hyperlink] = duration
			
			f.endTime = startTime + duration
			for k, v in pairs(self.cooldowns) do
				if v ~= f and math.abs(v.endTime - f.endTime) < 5 then
					if f:GetFrameLevel() > v:GetFrameLevel() then
						f.pulse:Play()
					else
						v.pulse:Play()
					end
				end
			end
			f:SetParent(self)
			f.parent = self						
			self:UpdateSingleIconLook(f)
			tinsert(self.usedFrames, f)
			self:Activate()
		end
		f.startTime = startTime
		f.duration = duration
		self:SetMaxDuration()
		f:SetCooldown(typ, id, startTime + duration)
		f:Show()
		self:SetScript("OnUpdate", self.OnUpdate)
		f:Show()
	end
	
	function barPrototype:CastFailure(typ, id)
		local hyperlink = typ .. ":" .. id
		for _, v in ipairs(self.usedFrames) do
			if v.hyperlink == hyperlink and v.endTime - GetTime() > 0.3 then
				v.throb:Play()
			end
		end
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
	
	local minutes = math_floor(self:GetTimeMax() / 60)
	for i = 5, minutes, 5 do
		self:SetLabel(i * 60)
	end
	
	if minutes > 5 and math_fmod(minutes, 5) ~= 0 then
		self:SetLabel(minutes * 60)
	end
	
	for i = 1, math_min(minutes, 5) do
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
	
	if not self.active then
		self:SetAlpha(self.settings.bar.inactiveAlpha)
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
function cooldownPrototype:SetCooldown(typ, id)
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
	
function cooldownPrototype:Expire(noanimate)
	local parent = self.parent
	for k, v in ipairs(parent.usedFrames) do
		if v == self then
			tinsert(parent.framePool, tremove(parent.usedFrames, k))
			break
		end
	end
	if #parent.usedFrames == 0 then
		parent:SetScript("OnUpdate", nil)
		parent:Deactivate()
	end
	
	self.pulse:Stop()
	if noanimate then
		self:Hide()
	else
		self.finish:Play()
	end
	parent.cooldowns[self.hyperlink] = nil
	parent.durations[self.hyperlink] = nil
end
	
function cooldownPrototype:UpdateTime()
	local parent = self.parent
	local timeMax = parent:GetTimeMax()
	local remaining = self.endTime - GetTime()
	local iRemaining = math_floor(remaining)
	local text
	if iRemaining ~= self.lastRemaining or iRemaining < 10 then
		if remaining > 60 then
			local minutes = math_floor(remaining / 60)
			local seconds = math_fmod(remaining, 60)
			text = string_format("%2.0f:%02.0f", minutes, seconds)
		elseif remaining <= 10 then
			self.pulse:Stop()
			text = string_format("%2.1f", remaining)
		else
			text = string_format("%2.0f", remaining)
		end
		if self.fs.lastText ~= text then
			self.fs:SetText(text)
			self.fs.lastText = text
		end
		self.lastRemaining = iRemaining
	end
	
	if remaining > timeMax then
		remaining = timeMax
	end
	if remaining <= 0 then
		remaining = 0.00001
		self:Expire()
	end
	
	local pos = getPos(remaining, timeMax, parent.settings.time_compression) * (parent.w - parent.h)
	self:SetPoint("CENTER", parent, "LEFT", pos, 0)
end

function cooldownPrototype:Blacklist()
	self.parent.db.profile.blacklist[self.hyperlink] = self.name
	self:Expire(true)
end
