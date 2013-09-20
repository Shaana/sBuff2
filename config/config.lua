--[[
Copyright (c) 2008-2013 Shaana <shaana@student.ethz.ch>
This file is part of sBuff2.

sBuff2 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

sBuff2 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with sBuff2.  If not, see <http://www.gnu.org/licenses/>.
--]]

local addon, namespace = ...

local config = {}
namespace.config = config

local attribute = {}
namespace.attribute = attribute

--Note:	only squre buttons are supported currently

--TODO allow inheritance from multiple configs simultaneously (that might be quiet complicated)

---config section
config["default"] = {
	--attribute part
	["horizontal_spacing"] = 10,
	["vertical_spacing"] = 28,
	["grow_direction"] = "LEFTDOWN",

	["wrap_after"] = 12,
	["sort_method"] = "TIME",
	["sort_direction"] = "-",
	
	--rest
	["size"] = {64, 64}, --width, height
	
	["border_texture"] = "Interface\\AddOns\\sBuff2\\media\\Border64",
	["border_texture_size"] = {64, 64},
	["border_inset"] = 4, --depends on texture

	["gloss_texture"] = "Interface\\AddOns\\sBuff2\\media\\Gloss64",
	["gloss_texture_size"] = {64, 64},
	["gloss_color"] = {0.2, 0.2, 0.2, 1},
	
	["count_font"] = {"Interface\\AddOns\\sBuff2\\media\\skurri.TTF", 22, "OUTLINE"},
	["count_color"] = {1,1,1,1},
	["count_x_offset"] = -6,
	["count_y_offset"] = 8,
	
	["expiration_font"] = {"Interface\\AddOns\\sBuff2\\media\\skurri.TTF", 18, "OUTLINE"},
	["expiration_color"] = {1,1,1,1},
	["expiration_x_offset"] = 2,
	["expiration_y_offset"] = 0,
	
	["update_format"] = {2,60,3600,86400}, --{msec, sec, min, hour}, e.g time_remaning < sec --> show seconds
	["update_frequency"] = {0.05,0.2,20,60,300},
	
	["display_vehicle_aura"] = false, --true/false display vehicle auras when in a vehicle instead of unit aura
	
}

config["buff"] = {
	["__index"] = config["default"],
	["helpful"] = true, --simple true/false to check if it's a buff or debuff header
	["anchor"] = {"TOPRIGHT", UIParent, "TOPRIGHT", -250, -15}, --{"CENTER", UIParent, "CENTER", 0, 0},
	["border_color"] = {0.4, 0.4, 0.4, 1},
	["includeWeapons"] = 1, --only has effect for buff headers
	["max_wraps"] = 3,
}

config["debuff"] = {
	["__index"] = config["default"],
	["helpful"] = false, --simple true/false to check if it's a buff or debuff header
	["anchor"] = {"TOPRIGHT", UIParent, "TOPRIGHT", -250, -266}, --{"CENTER", UIParent, "CENTER", 0, -200},
	["border_color"] = {0.8, 0, 0, 1},
	--["update_frequency"] = {0.1,0.5,30,60,61}, -- every 0.1s if below 2s, every 0.5s if below 60s, every 30s if below 3600, every 60s if below 86400
	["max_wraps"] = 5,
}


--TODO make independent configs (dont inherit from default)
--[[
--48px buttons
config["default_48"] = {
	["__index"] = config["default"],
	
	["horizontal_spacing"] = 10 + 64,
	["vertical_spacing"] = 28 + 64,
	
	["size"] = {48, 48},
	
	["border_texture"] = "Interface\\AddOns\\sBuff2\\media\\Border48",
	["border_texture_size"] = {64, 64},
	["border_inset"] = 3,
	
	["gloss_texture"] = "Interface\\AddOns\\sBuff2\\media\\Gloss48",
	["gloss_texture_size"] = {64, 64},

	["count_font"] = {"Interface\\AddOns\\sBuff2\\media\\skurri.TTF", 16, "OUTLINE"},
	["count_x_offset"] = -5,
	["count_y_offset"] = 8,
	
	["expiration_font"] = {"Interface\\AddOns\\sBuff2\\media\\skurri.TTF", 14, "OUTLINE"},
	["expiration_x_offset"] = 2,
	["expiration_y_offset"] = 0,
}

config["buff_48"] = {
	["__index"] = config["default_48"],
	--["anchor"] = {"TOPRIGHT", UIParent, "TOPRIGHT", -250, -15}, --TODO
}

config["debuff_48"] = {
	["__index"] = config["default_48"],
	--["anchor"] = {"TOPRIGHT", UIParent, "TOPRIGHT", -250, -266}, --TODO
}


--32px buttons
config["default_32"] = {
	["__index"] = config["default"],
	["size"] = {32, 32},
}

config["buff_32"] = {
	["__index"] = config["default_32"],
}

config["debuff_32"] = {
	["__index"] = config["default_32"],
}


--]]


--inheritance for the config
for k,_ in pairs(config) do 
	setmetatable(config[k], config[k])
end











