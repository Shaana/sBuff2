--[[
Copyright (c) 2008-2012 Shaana <shaana@student.ethz.ch>
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

local core = {}
namespace.core = core

local class = {}
namespace.class = class

local header = {}
class.header = header

local button = {}
class.button = button

--Note: 'button' is always refering to an object created by the class.button:new(...) method, 
--while 'button_frame' is refering to object returned by header:GetAttributed("child"..i)


--TODO implement a good way to change the update_frequency depending on time_remaining on the aura/temp_enchant

--TODO maybe add if not self:IsShown() condition to updating shit.

--TODO maybe change everything, so it would allow headers for different units ?
--TODO test (argent tournement horses) buffs while in a vehicle ? --> maybe remove the unit ~= vehicle confidition in OnEvent ?

--TODO nothing was ever tested, so test it

--TODO might be worth it to bring most of the wow api we use alot into the local namespace
-- local UnitAura = UnitAura ...

--TODO there is more lua api ....
local assert, error, type, select, pairs = assert, error, type, select, pairs


local test = {
	--{start, end} when to change display 
	{2,0}, 			--milisecs (steps, 0.05 probably)
	{60,2},			--seconds (steps, 1 secs ?)
	{3600,60}, 		--minutes (
	{86400,3600},	--hours (steps 1 hour) ?
	{31536000,86400},--overkill
}
--we could write this shorter as {2,60,3600,86400}






local function _inherit(object, class)	
	assert(type(class) == "table")
	for k,v in pairs(class) do
		object[k] = v
	end
end

local function _set_attribute(header, attribute)
	assert(type(attribute) == "table")
	
	--inheritance
	if type(attribute.__index) == "table" then
		_set_attribute(header, attribute.__index)
	end
	for k,v in pairs(attribute) do
		if k ~= "__index" then
			header:SetAttribute(k,v)
		end
	end
end

local function set_attribute(header,attribute)
	--temporary disable SecureAuraHeader_OnAttributeChanged
	local old_ignore = header:GetAttribute("_ignore")
	
	header:SetAttribute("_ignore", "attributeChanges")
	_set_attribute(header, attribute)
	header:SetAttribute("_ignore", old_ignore)
end

function header.new(self, name, config, attribute, helpful)
	local object = CreateFrame("Frame", name, UIParent, "SecureAuraHeaderTemplate")
	
	--[[GetInventorySlotInfo(weapon_slot[i])
	--inherit functions from two objects (listed in parent table)
	local parent = {self, getmetatable(object).__index}
	setmetatable(object, self)
	self.__index = function(t,k)
		for i=1, #parent do
			local v = parent[i][k]
			if v then
				return v
			end
		end
	end
	--]]
	
	--Note: tempering with the metatable causes the the secure template to break.
	--Therefore we inherit the options with a function. (basically creating links to each of the class functions)
	_inherit(object, header)
	
	object.config = config
	object.attribute = attribute
	object.helpful = helpful --simple true/false to check if its the buff or debuff header
	object.button = {} --here we gonna but the list of buttons created by the button class

	set_attribute(object, attribute)

	object:SetPoint(unpack(config["anchor"]))
	object:SetScale(1) --keep this always 1 to make pixel perfection work
	
	--this will run SecureAuraHeader_Update(header)
	object:Show()

	object:RegisterEvent("PLAYER_ENTERING_WORLD")
	--[[
	--basically need for temp enchants
	if self.helpful then
		object:RegisterEvent("INVENTORY_CHANGED")
	end
	
	--]]
	
	object:HookScript("OnEvent", self.update)

	return object
end

local weapon_slot = {{"MainHandSlot", 16}, {"SecondaryHandSlot", 17}}

function header.update(self, event, unit)
	--print("update_header")
	--TODO make it more understandable
	if unit ~= "player" and unit ~= "vehicle" and event ~= "PLAYER_ENTERING_WORLD" then return end
	--WHY does this getting displayed twice ?
	print(event)
	local max_aura = self:GetAttribute("wrapAfter") * self:GetAttribute("maxWraps")

	--TODO change where we same the buttons i+2 sucks, especially for debuff header
	for i=1, max_aura do
		local child = self:GetAttribute("child"..i)
		if child and child:IsShown() then
			--create button object if needed
			if not self.button[i+2] then 
				self.button[i+2] = class.button:new(self, child)
			end
			--update
			self.button[i+2]:update_aura()
		end
	end
	
	--TODO test what happens when you apply a temp buff, see if it works properly
	
	--only buff header needs to update weapon enchants
	if self.helpful then
		for i=1, 2 do
			local child = self:GetAttribute("tempEnchant"..i)
			if child and child:IsShown() then
				if not self.button[i] then 
					self.button[i] = class.button:new(self, child)
					--self.button[i].temp_enchant["slot"] = weapon_slot[i]
					self.button[i].temp_enchant["weapon_slot"] = i --TODO find better name ...
					self.button[i].temp_enchant["slot_id"] = weapon_slot[i][2]
				end
				--update
				self.button[i]:update_temp_enchant(i)
			end
		end
	end

end

---button class

function button.new(self, header, child) --child given by interating over children from the header
	local object = child

	--Note: tempering with the metatable causes the the secure template to break. (Lots of errors while in combat due to protected functions,
	--unable to remove certain buffs (f.e Shadowform)
	--Therefore we inherit the options with a function. (basically creating links to each of the class functions)
	_inherit(object, button)

	object.header = header

	--TODO add pixel perfection here
	
	--icon
	object.icon = CreateFrame("Frame", nil, child)
	object.icon:SetAllPoints(child)
	object.icon:SetFrameLevel(1)
	
	--TODO local i, j = s.borderThickness, s.borderThickness/button:GetSize()
	local i,j = 3, 3/64 --random
	object.icon.texture = object.icon:CreateTexture(nil, "BACKGROUND")
	object.icon.texture:SetPoint("TOPLEFT", i, -i)
	object.icon.texture:SetPoint("BOTTOMRIGHT", -i, i)
	object.icon.texture:SetTexCoord(j, 1-j, j, 1-j)
	
	--border
	object.border = CreateFrame("Frame", nil, child)
	object.border:SetAllPoints(child)
	object.border:SetFrameLevel(2)

	object.border.texture = object.border:CreateTexture(nil, "BORDER")
	object.border.texture:SetAllPoints(child)
	object.border.texture:SetTexture(header.config["border_texture"])
	object.border.texture:SetVertexColor(unpack(header.config["border_color"]))

	--gloss
	object.gloss = CreateFrame("Frame", nil, child)
	object.gloss:SetAllPoints(child)
	object.gloss:SetFrameLevel(3)
	
	object.gloss.texture = object.gloss:CreateTexture(nil, "BORDER")
	object.gloss.texture:SetAllPoints(child)
	object.gloss.texture:SetTexture(header.config["gloss_texture"])
	object.gloss.texture:SetVertexColor(unpack(header.config["gloss_color"]))
	
	--count text
	object.count = child:CreateFontString(nil, "OVERLAY")
	--object.count:SetFontObject(GameFontNormal) --TODO what does this line do exactly ?
	object.count:SetTextColor(unpack(header.config["count_color"]))
	object.count:SetFont(unpack(header.config["count_font"]))
	object.count:SetPoint("BOTTOMRIGHT", child, "BOTTOMRIGHT", header.config["count_x_offset"], header.config["count_y_offset"])
	
	--expiration text
	object.expiration = child:CreateFontString(nil, "OVERLAY")
	--object.expiration:SetFontObject(GameFontNormalSmall) --TODO what does this line do exactly ? --probably not even needed?
	object.expiration:SetTextColor(unpack(header.config["expiration_color"]))
	object.expiration:SetFont(unpack(header.config["expiration_font"]))
	object.expiration:SetPoint("TOP", child, "BOTTOM", header.config["expiration_x_offset"], header.config["expiration_y_offset"])
	
	object.aura = {} --here we put the aura information. done in button.update
	object.temp_enchant = {} --or if its an temp enchant, then we put the info in here
	
	object.last_update = 0
	
	object.active_tooltip = false
	
	return object
end


local aura_keys = {"name", "rank", "icon", "count", "dispel_type", "duration", "expire", "caster", "is_stealable", "should_consolidate", "spell_id", "can_apply_aura", "is_boss_debuff", "value_1", "value_2", "value_3"}

local function _update_aura_table(aura, ...)
	for i=1, #aura_keys do
		aura[aura_keys[i]] = select(i, ...)
	end
end

--TODO test output
local function si_value(value)
	if value >= 1e6 then
		return ("%.0f m"):format(value)
	elseif value >= 1e3 then
		return ("%.0f k"):format(value)
	else
		return value
	end
end

--update the button, only here UnitAura is called
--TODO might rename to update_aura ?, so we can create update_temp_enchant as well ?
--local temp_aura = {}

function button.update_aura(self)
	local temp_aura = {}
	_update_aura_table(temp_aura, UnitAura("player", self:GetID(), self.header:GetAttribute("filter")))
	
	--if not temp_aura["name"] then
	print(temp_aura["name"],self.aura["name"])
	--end
	
	_update_aura_table(self.aura, UnitAura("player", self:GetID(), self.header:GetAttribute("filter")))
	
	--TODO UnitAura sometimes returns nil when chaning zones
	--OR a new buff gain in that zone caueses to break things
	--if not self.aura["name"] then return end
	--this fix doesnt work like that, cause i need to stop the update before the aura table is overwritten
	--[[1x sBuff2-2.0 beta1\core.lua:354: attempt to perform arithmetic on field "expire" (a nil value)
	sBuff2-2.0 beta1\core.lua:354: in function <sBuff2\core.lua:339>
	--]]
	--how ? the field a nil value ? cause actually unitaura should always return a number (test) it though
	
	--information needed for the tooltip
	self.aura["caster_name"] = UnitName(self.aura["caster"])
	self.aura["caster_class"] = select(2, UnitClass(self.aura["caster"]))
	self.aura["caster_class_color"] = RAID_CLASS_COLORS[self.aura["caster_class"]]
	
	--icon
	self.icon.texture:SetTexture(self.aura["icon"])

	--count
	if self.aura["count"] > 0 then
		self.count:SetText(self.aura["count"])
	else
		--handle special spells
		--TODO might better do this by spell_id
		if self.aura["name"] == "Necrotic Strike" and self.aura["value_1"] then
			--use the stack count to display the amount healing absorbed by Necrotic Strike
			self.count:SetText(si_value(self.aura["value_1"]))
			--TODO replace with si_value function
		else
			--usually we just 'hide' it, by setting it to ""
			self.count:SetText("")
		end
	end
	
	--expiration
	if self.aura["duration"] > 0 then
		self.last_update = self.header.config["update_frequency"] --force the first update right away
		self:SetScript("OnUpdate", self.update_aura_expiration)
	else
		--print("removed update:", self.aura["name"])
		self:SetScript("OnUpdate", nil) --TODO is this actually getting removed from children that are being hidden, when an aura expired ? dont think so ...
		self.expiration:SetText("")
	end

end

function button.update_temp_enchant(self)

	--icon
	self.icon.texture:SetTexture(GetInventoryItemTexture("player", self.temp_enchant["slot_id"]))
	
	--i is either 1 or 2 (main, off)
	local has_enchant, time_remaining, count = select(1 + (self.temp_enchant["weapon_slot"]-1)*3, GetWeaponEnchantInfo())

	if not has_enchant then
		--DEBUG
		print("error in button.update_temp_enchant(self,i), this error should never occure")
	end
	
	--count
	if count and count > 0 then
		self.count:SetText(count)
	else
		self.count:SetText("")
	end

	--expiration
	if time_remaining and time_remaining > 0 then
		self.last_update = 1 --TODO change with proper value
		self:SetScript("OnUpdate", self.update_temp_enchant_expiration)
	else
		--print("removed update:", self.aura["name"])
		--TODO not sure if this works to properly remove the script, cause we wont even enter the function.
		--if there is no enchant
		self:SetScript("OnUpdate", nil)
		self.expiration:SetText("")
	end

end

local function format_time(time, show_msec, show_sec, show_min, show_hour)
	if time < (show_msec or 2) then
		return ("%.1f s"):format(time)
	elseif time < (show_sec or 60) then
		return ("%.0f s"):format(time)
	elseif time < (show_min or 3600) then --60*60
		return ("%.0f m"):format(time/60)
	elseif time < (show_hour or 86400) then --60*60*24
		return ("%.0f h"):format(time/3600)
	else
		return ("%.0f d"):format(time/86400)
	end
end

--OnUpdate, update time remaining ....
function button.update_aura_expiration(self, elapsed)
	--Note, here self is NOT the button object, but rather the button.child object
	--we can access the button object via button.child.button (linked in button.new)
	--self = self.button

	if self.last_update < self.header.config["update_frequency"] then
		self.last_update = self.last_update + elapsed
		return
	end
	
	self.last_update = 0 --i think its pretty important that its right here, so we won't have a problem with twice same function getting called in the smae milisec
	
	--TODO change update_frequency based on time_remaining ?
	
	--Note: GetTime() is a 'local' function, doesn't actually ask the server for time
	self.expiration:SetText(format_time(self.aura["expire"] - GetTime()))
	
	--TODO remove OnUpdate script here when time remaining < 0 ? really really think this through first 
	--... might cause problems on the long run
	--self.expiration:SetText("0 s")
	
	if self.active_tooltip then
		self:update_aura_tooltip()
	--TODO maybe call update_tooltip here ?
	--right/smart to do it here ?
	end
	
end

function button.update_temp_enchant_expiration(self, elapsed)
	--Note, here self is NOT the button object, but rather the button.child object
	--we can access the button object via button.child.button (linked in button.new)
	--self = self.button
	if self.last_update < 1 then	
		self.last_update = self.last_update + elapsed
		return
	end
	self.last_update = 0

	local time_remaining = select(2 + (self.temp_enchant["weapon_slot"]-1)*3, GetWeaponEnchantInfo())
	
	if time_remaining then
		self.expiration:SetText(format_time(time_remaining*0.001))
	else
		--DEBUG
		print("error in update_temp_enchant_expiration, no time_remaining", time_remaining)
	end
	
	if self.active_tooltip then
		self:update_temp_enchant_tooltip()
		--TODO maybe call update_tooltip here ?
		--right/smart to do it here ?
	end
	
	--TODO maybe call update_tooltip here ?
end


--TODO might wanna call the update_expiration function to make sure the tooltip is in sync with the expiration time
--however this might cause troubles again.
function button.update_aura_tooltip(self)
	--print("update_tooltip_aura")
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetFrameLevel(self:GetFrameLevel() + 3)
	GameTooltip:SetUnitAura("player", self:GetID(), self.header:GetAttribute("filter")) --replace player with self.header:GetAttribute(unit)
	GameTooltip:AddLine(self.aura["caster_name"], self.aura["caster_class_color"].r, self.aura["caster_class_color"].b, self.aura["caster_class_color"].g, true)
	GameTooltip:Show()
end

function button.update_temp_enchant_tooltip(self)
	--print("update_tooltip_temp_enchant")
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetFrameLevel(self:GetFrameLevel() + 3)
	GameTooltip:SetInventoryItem("player", self.temp_enchant["slot_id"])
	GameTooltip:Show()
end



--check for config integrety
--TODO replace this with some proper check function

local function check_config_integrity()
	--make this function set default values as well ?
	--if attribute "includeWeapons", 1 given, we expect  "weaponTemplate", buffTemplate as well
	--__attribte expected for the coresponding table
	--anchor expected
end
core.check_config_integrity = check_config_integrity


local function check_attribute_integrity()



end
core.check_attribute_integrity = check_attribute_integrity






