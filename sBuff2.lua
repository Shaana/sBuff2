--sBuff is a simple standalone World of Warcraft addon to display player buffs/debuffs.
--By using Blizzard's SecureAuraHeaderTemplate it allows to remove buffs with RightClicks even during combat.
 
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

local config = namespace.config
local attribute = namespace.attribute
local class = namespace.class

--template = [STRING] -- the XML template to use for the unit buttons. If the created widgets should be something other than Buttons, append the Widget name after a comma.
--might be possible to make special sort order ?

local function init()
	--Debug functions, only uncomment them if you changed the config.lua
	--and want to make sure it's working.
	--core.check_config_integrity()
	--core.check_attribute_integrity()

	header_buff = class.header:new("sBuff_HeaderBuffs", config["buff"], attribute["buff"])
	header_debuff = class.header:new("sBuff_HeaderDebuffs", config["debuff"], attribute["debuff"])

	--header_buff_taget = class.header:new("sBuff_HeaderBuffs", config["buff_target"], attribute["buff_target"])
	--header_buff:SetScale(0.55)
	--header_debuff:SetScale(0.55)
	
	--hide blizz frames
	BuffFrame:UnregisterAllEvents()
	BuffFrame:Hide()
	TemporaryEnchantFrame:Hide()
	ConsolidatedBuffs:Hide()
end

--[[
local test_frame = CreateFrame("Frame", nil, UIParent)

test_frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
test_frame:RegisterEvent("UPDATE_WEB_TICKET")
test_frame:RegisterEvent("UPDATE_TICKET")
test_frame:RegisterEvent("UNIT_AURA")
test_frame:RegisterEvent("PLAYER_ENTERING_WORLD")

--test_frame:RegisterAllEvents()

test_frame:SetScript("OnEvent", function(...) print(...) end)
--]]
init()
