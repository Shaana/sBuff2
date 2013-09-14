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

local attribute = {}
namespace.attribute = attribute

local config = namespace.config


---Attributes section (advanced)
--do NOT touch this if you're not certain what you're doing!
local x, y = config["default"]["horizontal_spacing"], config["default"]["vertical_spacing"]

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
	["minWidth"] = 100,
	["minHeight"] = 100,
}

attribute["buff"] = {
	["__index"] = attribute["default"],
	["unit"] = "player",
	["xOffset"] = grow_direction[1],
	["yOffset"] = grow_direction[2],
	["wrapAfter"] = 12,
	["maxWraps"] = 3,
	["wrapXOffset"] =  grow_direction[3],
	["wrapYOffset"] = grow_direction[4],
	["sortMethod"] = "TIME",
	["sortDir"] = "-",
	["filter"] = "HELPFUL",
	["template"] = "ShaanaBuffButtonTemplate", --never name your template BuffButtonTemplate (Blizzard calls it that way)
	["point"] = config["buff"]["anchor"][1], --really only the point
	--only buff 
	["includeWeapons"] = 1,
  	["weaponTemplate"] = "ShaanaTempEnchantButtonTemplate",
}

attribute["debuff"] = {
	["__index"] = attribute["default"],
	["unit"] = "player",
	["xOffset"] = grow_direction[1],
	["yOffset"] = grow_direction[2],
	["wrapAfter"] = 12,
	["maxWraps"] = 5,
	["wrapXOffset"] =  grow_direction[3],
	["wrapYOffset"] = grow_direction[4],
	["sortMethod"] = "TIME",
	["sortDir"] = "-",
	["filter"] = "HARMFUL",
	["template"] = "ShaanaDebuffButtonTemplate",
	["point"] = config["debuff"]["anchor"][1],
	
}


--Note:	inheritance for attribute is directly coded into set_attribute(frame, attribute)