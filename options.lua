local mod = SexyCooldown
local L = LibStub("AceLocale-3.0"):GetLocale("SexyCooldown")
local LSM = LibStub("LibSharedMedia-3.0")

local outlines = {[""] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline"}

mod.baseOptions = {
	type = "group",
	args = {}
}

mod.barDefaults = {
	profile = {
		x = 0,
		y = -200,
		time_max = 180,
		time_compression = 0.4,
		bar = {
			font = "Fritz Quadrata TT",
			fontsize = 8,
			texture = "Glaze",
			border = "Blizzard Tooltip",
			borderInset = 2,
			borderColor = { r = 0.3019607843137255, g = 0.5215686274509804, b = 1, a = 1 },
			backgroundColor = { r = 0.2, g = 0.2705882352941176, b = 0.6784313725490196, a = 1 },
			fontColor = { r = 1, g = 1, b = 1, a = 1 },
			width = 500,
			height = 24,
			minDuration = 3
		},
		icon = {
			font = "Fritz Quadrata TT",
			fontsize = 8,
			border = "Blizzard Tooltip",
			borderColor = { r = 1, g = 1, b = 1, a = 1 },
			fontColor = { r = 1, g = 1, b = 1, a = 1 },
			sizeOffset = 2,
			borderInset = 2,
			showText = true,
			splashScale = 4,
			splashSpeed = 0.5
		}		
	}
}

function mod:GetOptionsTable(frame)
	local db = frame.db.profile
	
	local options = {
		time_compression = {
			type = "range",
			name = L["Time Compression"],
			desc = L["Time display scaling factor"],
			min = 0.05,
			max = 1.0,
			step = 0.05,
			bigStep = 0.05
		},
		time_max = {
			type = "range",
			name = L["Max Time"],
			desc = L["Max time to display, in seconds"],
			min = 30,
			max = 600,
			step = 1,
			bigStep = 30
		},
		icon = {
			type = "group",
			name = L["Icons"],
			args = {
				fontHeader = {
					name = L["Cooldown Text"],
					type = "header",
					order = 120
				},
				showText = {
					type = "toggle",
					name = L["Show Cooldown Text"],
					desc = L["Show Cooldown Text"],
					order = 120,
					width = "full"
				},				
				font = {
					type = "select",
					name = L["Font"],
					desc = L["Font"],
					dialogControl = 'LSM30_Font',
					values = LSM:HashTable("font"),
					disabled = function(info)
						return not db.icon.showText
					end,
					order = 121
				},
				fontsize = {
					type = "range",
					name = L["Font size"],
					desc = L["Font size"],
					min = 4,
					max = 30,
					step = 1,
					bigStep = 1,
					disabled = function(info)
						return not db.icon.showText
					end,
					order = 123,
					width = "full"
				},
				fontColor = {
					type = "color",
					name = L["Font color"],
					desc = L["Font color"],
					hasAlpha = true,
					disabled = function(info)
						return not db.icon.showText
					end,
					order = 123
				},				
				outline = {
					type = "select",
					name = L["Font Outline"],
					desc = L["Font Outline"],
					values = outlines,
					disabled = function(info)
						return not db.icon.showText
					end,
					order = 122
				},				
				borderheader = {
					type = "header",
					name = L["Borders"],
					order = 50
				},
				border = {
					type = "select",
					name = L["Border"],
					desc = L["Border"],
					dialogControl = 'LSM30_Border',
					values = LSM:HashTable("border"),
					order = 51
				},
				borderColor = {
					type = "color",
					name = L["Border color"],
					desc = L["Border color"],
					hasAlpha = true,
					order = 52
				},				
				bordersize = {
					type = "range",
					name = L["Border size"],
					desc = L["Border size"],
					min = 4,
					max = 24,
					step = 1,
					bigStep = 1,
					width = "full"
				},
				borderInset = {
					type = "range",
					name = L["Border inset"],
					desc = L["Border inset"],
					min = -5,
					max = 25,
					step = 1,
					bigStep = 1,
					width = "full"
				},		
				generalheader = {
					type = "header",
					name = L["General options"],
					order = 1
				},
				sizeOffset = {
					type = "range",
					name = L["Size"],
					desc = L["Size"],
					min = -15,
					max = 15,
					step = 1,
					bigStep = 1,
					order = 10
				},
				splashScale = {
					type = "range",
					name = L["Splash scale"],
					desc = L["How big (or small) icons will 'splash' when their cooldown is done"],
					min = 0,
					max = 15,
					step = 0.25,
					bigStep = 0.25,
					order = 15
				},
				splashSpeed = {
					type = "range",
					name = L["Splash speed"],
					desc = L["How quickly to play the splash animation once a cooldown is done"],
					min = 0.05,
					max = 1.0,
					step = 0.05,
					bigStep = 0.05,
					order = 16
				},
			}
		},
		bar = {
			type = "group",
			name = L["Bar"],
			args = {
				lock = {
					type = "toggle",
					name = L["Lock"],
					desc = L["Lock this bar to prevent resizing or moving"],
					order = 1					
				},
				height = {
					type = "range",
					name = L["Height"],
					desc = L["Height"],
					min = 5,
					max = 100,
					step = 1,
					bigStep = 1,
				},
				width = {
					type = "range",
					name = L["Width"],
					desc = L["Width"],
					min = 50,
					max = 2000,
					step = 1,
					bigStep = 25		
				},				
				font = {
					type = "select",
					name = L["Font"],
					desc = L["Font"],
					dialogControl = 'LSM30_Font',
					values = LSM:HashTable("font")
				},
				border = {
					type = "select",
					name = L["Border"],
					desc = L["Border"],
					dialogControl = 'LSM30_Border',
					values = LSM:HashTable("border")
				},
				fontsize = {
					type = "range",
					name = L["Font size"],
					desc = L["Font size"],
					min = 4,
					max = 30,
					step = 1,
					bigStep = 1
				},
				outline = {
					type = "select",
					name = L["Font Outline"],
					desc = L["Font Outline"],
					values = outlines
				},
				texture = {
					type = "select",
					name = L["Background"],
					desc = L["Background"],
					dialogControl = 'LSM30_Statusbar',
					values = LSM:HashTable("statusbar")
				},
				backgroundColor = {
					type = "color",
					name = L["Background color"],
					desc = L["Background color"],
					hasAlpha = true
				},
				borderColor = {
					type = "color",
					name = L["Border color"],
					desc = L["Border color"],
					hasAlpha = true		
				},
				fontColor = {
					type = "color",
					name = L["Font color"],
					desc = L["Font color"],
					hasAlpha = true		
				},
				borderSize = {
					type = "range",
					name = L["Border size"],
					desc = L["Border size"],
					min = 4,
					max = 24,
					step = 1,
					bigStep = 1
				},
				borderInset = {
					type = "range",
					name = L["Border insets"],
					desc = L["Border insets"],
					min = 0,
					max = 16,
					step = 1,
					bigStep = 1		
				},
				flexible = {
					type = "toggle",
					name = L["Flexible"],
					desc = L["Collapse the bar to the length of your longest active cooldown."]				
				},
				minDuration = {
					type = "range",
					name = L["Minimum duration"],
					desc = L["Cooldowns shorter than this will not be shown."],
					min = 3,
					max = 60,
					step = 1,
					bigStep = 1
				}
			}
		}
	}

	return {
		type = "group",
		name = frame.name,
		arg = frame,
		get = function(info)
			local obj = db
			for i = 2, #info do
				obj = obj[info[i]]
			end
			if type(obj) == "table" then
				return obj.r, obj.g, obj.b, obj.a
			else
				return obj
			end
		end,
		set = function(info, ...)
			local obj = db
			for i = 2, #info - 1 do
				obj = obj[info[i]]
			end
			if select("#", ...) == 1 then
				obj[info[#info]] = ...
			else
				local t = obj[info[#info]]
				t.r, t.g, t.b, t.a = ...
			end
			frame:UpdateLook()
		end,
		args = options
	}
end