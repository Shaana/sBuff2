--[[
Copyright (c) 2008-2013 Shaana <shaana@student.ethz.ch>
This file is part of sBuff.

sBuff is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

sBuff is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with sBuff.  If not, see <http://www.gnu.org/licenses/>.
--]]

local addon, namespace = ...

local config = {}
namespace.config = config

--protype
local attribute = {}
namespace.attribute = attribute

---config section
config["core"] = {
	["font"] = {"Interface\\AddOns\\sBuff2\\media\\skurri.TTF", 18, "OUTLINE"},
}

config["default"] = {
	["__index"] = config["core"],
	["horizontal_spacing"] = 10,
	["vertical_spacing"] = 28,
	["height"] = 64, --even needed?
	["width"] = 64, --even needed?
	["grow_direction"] = "LEFTDOWN",
	["border_texture"] = "Interface\\AddOns\\sBuff2\\media\\BorderThin",
	["gloss_texture"] = "Interface\\AddOns\\sBuff2\\media\\GlossThin",
	["gloss_color"] = {0.2, 0.2, 0.2, 1},
	["count_font"] = {"Interface\\AddOns\\sBuff2\\media\\skurri.TTF", 22, "OUTLINE"}, --config["core"]["font"], --if nil, use default font
	["count_color"] = {1,1,1,1},
	["expiration_font"] = config["core"]["font"], --if nil, use default font
	["expiration_color"] = {1,1,1,1},
	["count_x_offset"] = -6,
	["count_y_offset"] = 8,
	["expiration_x_offxet"] = 2,
	["expiration_y_offset"] = 0,
}

config["buff"] = {
	["__index"] = config["default"],
	["anchor"] = {"TOPRIGHT", UIParent, "TOPRIGHT", -250, -15}, --{"CENTER", UIParent, "CENTER", 0, 0},
	["border_color"] = {0.4, 0.4, 0.4, 1},
	["update_frequency"] = 1,

}

config["debuff"] = {
	["__index"] = config["default"],
	["anchor"] = {"TOPRIGHT", UIParent, "TOPRIGHT", -250, -266}, --{"CENTER", UIParent, "CENTER", 0, -200},
	["border_color"] = {0.8, 0, 0, 1},
	["update_frequency"] = 0.5,
}

--inheritance for the config
for k,_ in pairs(config) do 
	setmetatable(config[k], config[k])
end

---Attributes section (advanced)
--do NOT touch this if you're not certain what you're doing!
local x, y = config["default"]["horizontal_spacing"] + config["default"]["width"], config["default"]["vertical_spacing"] + config["default"]["height"]

--xOffset, yOffset, wrapXOffset, wrapYOffset
local directions = {	
	["LEFTUP"]		= {-x, 0, 0, y},
	["LEFTDOWN"]	= {-x, 0, 0, -y},
	["RIGHTUP"]		= {x, 0, 0, y},
	["RIGHTDOWN"]	= {x, 0, 0, -y},
	["UPLEFT"]		= {0, y, -x, 0},
	["UPRIGHT"]		= {0, y, x, 0},
	["DOWNLEFT"]	= {0, -y, -x, 0},
	["DOWNRIGHT"]	= {0, -y, x, 0},										
} 

local grow_direction = directions[config["default"]["grow_direction"]] -- or directions["LEFTDOWN"]

-- for further information on attributes check http://wowprogramming.com/utils/xmlbrowser/live/FrameXML/SecureGroupHeaders.lua
attribute["default"] = {
	["unit"] = "player",
	["minWidth"] = 100,
	["minHeight"] = 100,
	["xOffset"] = grow_direction[1],
	["yOffset"] = grow_direction[2],
	["wrapAfter"] = 12,
	["wrapXOffset"] =  grow_direction[3],
	["wrapYOffset"] = grow_direction[4],
	["sortMethod"] = "TIME",
	["sortDir"] = "-",
}

attribute["buff"] = {
	["__index"] = attribute["default"],
	["filter"] = "HELPFUL",
	["template"] = "ShaanaBuffButtonTemplate", --never name your template BuffButtonTemplate (Blizzard calls it that way)
	["point"] = config["buff"]["anchor"][1], --really only the point
	["maxWraps"] = 3,
	["includeWeapons"] = 1,
  	["weaponTemplate"] = "ShaanaTempEnchantButtonTemplate", --same as for all buffs
}

attribute["debuff"] = {
	["__index"] = attribute["default"],
	["filter"] = "HARMFUL",
	["template"] = "ShaanaDebuffButtonTemplate",
	["point"] = config["debuff"]["anchor"][1],
	["maxWraps"] = 5,
}

--inheritance for attribute is directly coded into set_attribute(frame, attribute)
--currently i can only inherit options from tables


