--sBuff2 is a simple standalone World of Warcraft addon to display player buffs/debuffs.
--By using Blizzard's SecureAuraHeaderTemplate it allows to remove buffs with RightClicks even during combat.
 
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

local config = namespace.config
local attribute = namespace.attribute
local class = namespace.class

local function init()

	header_buff = class.header:new("sBuff_HeaderBuffs", config["buff"], attribute["buff"])
	header_debuff = class.header:new("sBuff_HeaderDebuffs", config["debuff"], attribute["debuff"])
	
	--TODO
	--header_buff = class.header:new("sBuff_HeaderBuffs", config["buff48"], attribute["buff48"])
	--header_debuff = class.header:new("sBuff_HeaderDebuffs", config["debuff48"], attribute["debuff48"])
	
	--TODO add suppot for all units
	--header_buff_taget = class.header:new("sBuff_HeaderBuffs", config["buff_target"], attribute["buff_target"])
	
	--hide blizz frames
	BuffFrame:UnregisterAllEvents()
	BuffFrame:Hide()
	TemporaryEnchantFrame:Hide()
	ConsolidatedBuffs:Hide()
end

init()
