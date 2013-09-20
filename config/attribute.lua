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

local attribute = {}
namespace.attribute = attribute

local config = namespace.config

local function make_offset(config)
	assert(type(config) == "table")
	
	local x, y = config["size"][1] + config["horizontal_spacing"], config["size"][1] + config["vertical_spacing"]
	
	--TODO we always make the whole table ... that's not necessary
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
	return directions[config["grow_direction"]]
end


buff_offset = make_offset(config["buff"])
debuff_offset = make_offset(config["debuff"])

-- for further information on attributes check http://wowprogramming.com/utils/xmlbrowser/live/FrameXML/SecureGroupHeaders.lua
attribute["default"] = {
	["minWidth"] = 100,
	["minHeight"] = 100,
	["separateOwn"] = 0, -- indicate whether buffs you cast yourself should be separated before (1) or after (-1) others. If 0 or nil, no separation is done.
	["unit"] = "player", --currently we support player only anyway
}

attribute["buff"] = {
	["__index"] = attribute["default"],
	["xOffset"] = buff_offset[1],
	["yOffset"] = buff_offset[2],
	["wrapAfter"] = config["buff"]["wrap_after"],
	["maxWraps"] = config["buff"]["max_wraps"],
	["wrapXOffset"] =  buff_offset[3],
	["wrapYOffset"] = buff_offset[4],
	["sortMethod"] = config["buff"]["sort_method"],
	["sortDir"] = config["buff"]["sort_direction"], 
	["filter"] = "HELPFUL",
	["template"] = "ShaanaBuffButtonTemplate", --never name your template BuffButtonTemplate (Blizzard calls it that way)
	["point"] = config["buff"]["anchor"][1], --really only the point
	--TempEnchant stuff
	["includeWeapons"] = config["buff"]["includeWeapons"],
  	["weaponTemplate"] = "ShaanaTempEnchantButtonTemplate",
}

attribute["debuff"] = {
	["__index"] = attribute["default"],
	["xOffset"] = debuff_offset[1],
	["yOffset"] = debuff_offset[2],
	["wrapAfter"] = config["debuff"]["wrap_after"],
	["maxWraps"] = config["debuff"]["max_wraps"],
	["wrapXOffset"] =  debuff_offset[3],
	["wrapYOffset"] = debuff_offset[4],
	["sortMethod"] = config["debuff"]["sort_method"],
	["sortDir"] = config["debuff"]["sort_direction"],
	["filter"] = "HARMFUL",
	["template"] = "ShaanaDebuffButtonTemplate",
	["point"] = config["debuff"]["anchor"][1],
	
}


--Note:	inheritance for attribute is directly coded into set_attribute(frame, attribute)
